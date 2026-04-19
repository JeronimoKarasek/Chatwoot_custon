class Api::V1::Accounts::Evolution::AuthorizationsController < Api::V1::Accounts::BaseController
  # Usa autenticacao padrao do BaseController (token ou sessao)

  def create
    Rails.logger.info "Evolution API connection verification called with params: #{params.inspect}"

    # Parâmetros vêm dentro de authorization
    auth_params = params[:authorization] || params

    api_url = auth_params[:api_url].presence || ENV['EVOLUTION_API_URL']
    admin_token = auth_params[:admin_token].presence || ENV['EVOLUTION_ADMIN_TOKEN']
    inbox_name = auth_params[:inbox_name]
    phone_number = auth_params[:phone_number].presence || 'pending'

    if api_url.blank? || admin_token.blank? || inbox_name.blank?
      return render json: {
        error: 'Missing required parameter: inbox_name'
      }, status: :bad_request
    end

    # Generate instance name automatically: {account_id}{inbox_name}
    # Clean inbox_name: remove spaces, special chars, lowercase
    clean_inbox_name = inbox_name.gsub(/[^a-zA-Z0-9]/, '').downcase
    instance_name = "#{current_account.id}#{clean_inbox_name}"

    Rails.logger.info "Evolution API: Generated instance name: #{instance_name}"

    # Extract behavior settings
    behavior_settings = {
      reject_call: auth_params[:reject_call] || false,
      msg_call: auth_params[:msg_call] || '',
      always_online: auth_params[:always_online] || false,
      read_messages: auth_params[:read_messages] || false,
      read_status: auth_params[:read_status] || false,
      groups_ignore: auth_params[:groups_ignore] || true,
      sync_full_history: auth_params[:sync_full_history] || false
    }

    # Extract proxy settings
    proxy_settings = auth_params[:proxy] || {}

    begin
      # First, check if Evolution API is running by hitting the root endpoint
      evolution_status = check_server_status(api_url)

      # Check if instance already exists, delete if it does
      check_and_delete_existing_instance(api_url, admin_token, instance_name)

      # Create new instance with webhook and settings
      instance_data = create_instance(api_url, admin_token, instance_name, phone_number, behavior_settings, proxy_settings)

      # Configure instance settings (separately if needed by Evolution API)
      configure_instance_settings(api_url, instance_data['hash'], instance_name, behavior_settings)

      # Get QR code for the new instance
      qrcode_data = get_qrcode(api_url, instance_data['hash'], instance_name)

      # Create the inbox in Chatwoot
      inbox = create_chatwoot_inbox(inbox_name, phone_number, instance_name, instance_data, api_url, admin_token)

      render json: {
        success: true,
        message: 'Instance and inbox created successfully',
        evolution_info: {
          version: evolution_status['version'],
          client_name: evolution_status['clientName'],
          whatsapp_version: evolution_status['whatsappWebVersion']
        },
        instance: instance_data,
        instance_name: instance_name,
        inbox_id: inbox&.id,
        inbox_name: inbox&.name,
        qrcode: qrcode_data
      }
    rescue StandardError => e
      Rails.logger.error "Evolution API connection error: #{e.message}"
      render json: {
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  private

  def check_server_status(api_url)
    instance_url = "#{api_url.chomp('/')}/"
    Rails.logger.info "Evolution API: Checking server at #{instance_url}"

    uri = URI.parse(instance_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    raise "Server verification failed. Status: #{response.code}, Body: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "Evolution API: Server JSON parse error: #{e.message}"
    raise 'Invalid response from Evolution API server endpoint'
  rescue StandardError => e
    Rails.logger.error "Evolution API: Server connection error: #{e.class} - #{e.message}"
    raise "Failed to verify instance: #{e.message}"
  end

  def create_instance(api_url, admin_token, instance_name, phone_number, behavior_settings, proxy_settings)
    create_url = "#{api_url.chomp('/')}/instance/create"
    Rails.logger.info "Evolution API: Creating instance at #{create_url}"

    # Get webhook URL for Evolution
    webhook_url_value = evolution_webhook_url(instance_name)
    Rails.logger.info "Evolution API: Webhook URL: #{webhook_url_value}"

    request_body = {
      instanceName: instance_name,
      integration: 'WHATSAPP-BAILEYS',
      qrcode: false,
      # Behavior settings
      rejectCall: behavior_settings[:reject_call] == true || behavior_settings[:reject_call] == 'true',
      msgCall: behavior_settings[:msg_call].to_s,
      alwaysOnline: behavior_settings[:always_online] == true || behavior_settings[:always_online] == 'true',
      readMessages: behavior_settings[:read_messages] == true || behavior_settings[:read_messages] == 'true',
      readStatus: behavior_settings[:read_status] == true || behavior_settings[:read_status] == 'true',
      groupsIgnore: behavior_settings[:groups_ignore] == true || behavior_settings[:groups_ignore] == 'true',
      syncFullHistory: behavior_settings[:sync_full_history] == true || behavior_settings[:sync_full_history] == 'true',
      webhook: {
        url: webhook_url_value,
        byEvents: false,
        base64: true,
        headers: {
          'Content-Type': 'application/json'
        },
        events: [
          'QRCODE_UPDATED',
          'MESSAGES_UPSERT',
          'MESSAGES_UPDATE',
          'MESSAGES_DELETE',
          'SEND_MESSAGE',
          'CONNECTION_UPDATE',
          'CONTACTS_UPDATE',
          'CONTACTS_UPSERT',
          'PRESENCE_UPDATE',
          'CHATS_UPDATE',
          'CHATS_DELETE',
          'GROUPS_UPSERT',
          'GROUPS_UPDATE',
          'GROUP_PARTICIPANTS_UPDATE',
          'CALL'
        ]
      }
    }

    # Only include number if it's a real phone number (digits only)
    clean_number = phone_number.to_s.gsub(/[\+\s\-]/, '')
    request_body[:number] = clean_number if clean_number.present? && clean_number.match?(/\A\d+\z/)

    # Add proxy if enabled
    if proxy_settings.present? && (proxy_settings[:enabled] == true || proxy_settings['enabled'] == true)
      request_body[:proxy] = {
        host: proxy_settings[:host] || proxy_settings['host'],
        port: (proxy_settings[:port] || proxy_settings['port']).to_s,
        protocol: proxy_settings[:protocol] || proxy_settings['protocol'] || 'http',
        username: proxy_settings[:username] || proxy_settings['username'],
        password: proxy_settings[:password] || proxy_settings['password']
      }.compact
      Rails.logger.info "Evolution API: Proxy configured: #{request_body[:proxy][:host]}:#{request_body[:proxy][:port]}"
    end

    uri = URI.parse(create_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request['apikey'] = admin_token
    request['Content-Type'] = 'application/json'
    request.body = request_body.to_json

    Rails.logger.info "Evolution API: Create instance request body: #{request.body}"

    response = http.request(request)
    Rails.logger.info "Evolution API: Create instance response code: #{response.code}"
    Rails.logger.info "Evolution API: Create instance response body: #{response.body}"

    raise "Failed to create instance. Status: #{response.code}, Body: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "Evolution API: Create instance JSON parse error: #{e.message}"
    raise 'Invalid response from Evolution API create instance endpoint'
  rescue StandardError => e
    Rails.logger.error "Evolution API: Create instance connection error: #{e.class} - #{e.message}"
    raise "Failed to create instance: #{e.message}"
  end

  def configure_instance_settings(api_url, api_hash, instance_name, behavior_settings)
    settings_url = "#{api_url.chomp('/')}/settings/set/#{instance_name}"
    Rails.logger.info "Evolution API: Configuring settings at #{settings_url}"

    settings_body = {
      rejectCall: behavior_settings[:reject_call] == true || behavior_settings[:reject_call] == 'true',
      msgCall: behavior_settings[:msg_call].to_s,
      groupsIgnore: behavior_settings[:groups_ignore] == true || behavior_settings[:groups_ignore] == 'true',
      alwaysOnline: behavior_settings[:always_online] == true || behavior_settings[:always_online] == 'true',
      readMessages: behavior_settings[:read_messages] == true || behavior_settings[:read_messages] == 'true',
      readStatus: behavior_settings[:read_status] == true || behavior_settings[:read_status] == 'true',
      syncFullHistory: behavior_settings[:sync_full_history] == true || behavior_settings[:sync_full_history] == 'true'
    }

    uri = URI.parse(settings_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['apikey'] = api_hash
    request['Content-Type'] = 'application/json'
    request.body = settings_body.to_json

    Rails.logger.info "Evolution API: Settings request body: #{request.body}"

    response = http.request(request)
    Rails.logger.info "Evolution API: Settings response: #{response.code} - #{response.body}"

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "Evolution API: Settings configured successfully"
    else
      Rails.logger.warn "Evolution API: Settings endpoint returned #{response.code}, continuing anyway"
    end
  rescue StandardError => e
    Rails.logger.warn "Evolution API: Could not configure settings: #{e.message}"
  end

  def check_and_delete_existing_instance(api_url, admin_token, instance_name)
    fetch_instances(api_url, admin_token, instance_name)
    Rails.logger.info "Evolution API: Instance #{instance_name} exists, deleting it"
    delete_instance(api_url, admin_token, instance_name)
    Rails.logger.info "Evolution API: Instance #{instance_name} deleted successfully"
    sleep(2)

    begin
      fetch_instances(api_url, admin_token, instance_name)
      Rails.logger.error "Evolution API: Instance #{instance_name} still exists after deletion attempt"
      raise 'Instance deletion failed - instance still exists'
    rescue StandardError => e
      Rails.logger.info "Evolution API: Verified instance #{instance_name} was deleted (#{e.message})"
    end
  rescue StandardError => e
    Rails.logger.info "Evolution API: Instance #{instance_name} doesn't exist (#{e.message}), proceeding with creation"
  end

  def fetch_instances(api_url, admin_token, instance_name)
    fetch_url = "#{api_url.chomp('/')}/instance/fetchInstances?instanceName=#{instance_name}"

    uri = URI.parse(fetch_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['apikey'] = admin_token
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    raise 'Instance not found' if response.code == '404'
    raise "Failed to fetch instances. Status: #{response.code}, Body: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    raise e.message
  end

  def delete_instance(api_url, admin_token, instance_name)
    delete_url = "#{api_url.chomp('/')}/instance/delete/#{instance_name}"

    uri = URI.parse(delete_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Delete.new(uri)
    request['apikey'] = admin_token
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    raise "Failed to delete instance. Status: #{response.code}, Body: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    raise "Failed to delete instance: #{e.message}"
  end

  def get_qrcode(api_url, api_hash, instance_name)
    qrcode_url = "#{api_url.chomp('/')}/instance/connect/#{instance_name}"
    Rails.logger.info "Evolution API: Getting QR code at #{qrcode_url}"

    uri = URI.parse(qrcode_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Get.new(uri)
    request['apikey'] = api_hash
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    Rails.logger.info "Evolution API: QR code response code: #{response.code}"

    raise "Failed to get QR code. Status: #{response.code}, Body: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    raise "Failed to get QR code: #{e.message}"
  end

  def evolution_webhook_url(instance_name)
    host = ENV['FRONTEND_URL'].presence || "#{request.protocol}#{request.host_with_port}"
    host = host.chomp('/')
    "#{host}/webhooks/evolution/#{instance_name}"
  end

  public

  def status
    instance_name = params[:instance_name]
    api_url = ENV['EVOLUTION_API_URL'].presence || 'https://evochat4.farolchat.com'
    admin_token = ENV['EVOLUTION_ADMIN_TOKEN'].presence || 'ced2320ce2f838b276235e5bf9041832'

    if instance_name.blank?
      return render json: { error: 'instance_name is required' }, status: :bad_request
    end

    if api_url.blank? || admin_token.blank?
      return render json: { error: 'Evolution API not configured', connected: false }, status: :ok
    end

    begin
      status_data = check_instance_status(api_url, admin_token, instance_name)
      render json: status_data
    rescue StandardError => e
      Rails.logger.error "Evolution API status error: #{e.message}"
      render json: { error: e.message, connected: false }, status: :ok
    end
  end

  private

  def check_instance_status(api_url, admin_token, instance_name)
    return { connected: false, state: 'error', error: 'api_url is missing' } if api_url.blank?

    status_url = "#{api_url.chomp('/')}/instance/connectionState/#{instance_name}"
    Rails.logger.info "Evolution API: Checking status at #{status_url}"

    uri = URI.parse(status_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['apikey'] = admin_token
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    Rails.logger.info "Evolution API: Status response code: #{response.code}"

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      state = data.dig('instance', 'state') || data['state']
      {
        connected: state == 'open',
        state: state,
        instance: data['instance']
      }
    else
      { connected: false, state: 'unknown', error: response.body }
    end
  rescue StandardError => e
    Rails.logger.error "Evolution API: Status check failed: #{e.message}"
    { connected: false, state: 'error', error: e.message }
  end

  def create_chatwoot_inbox(inbox_name, phone_number, instance_name, instance_data, api_url, admin_token)
    Rails.logger.info "Creating Chatwoot inbox (Channel::Api): #{inbox_name} for instance: #{instance_name}"

    # Format phone number
    formatted_phone = phone_number.start_with?('+') ? phone_number : "+#{phone_number}"

    # Check if an Evolution Channel::Api already exists for this instance
    existing_channels = Channel::Api.where("additional_attributes->>'instance_name' = ?", instance_name)
    existing_channels.each do |existing_channel|
      existing_inbox = existing_channel.inbox
      if existing_inbox && existing_inbox.account_id == current_account.id
        Rails.logger.info "Inbox already exists for instance #{instance_name}, updating config"
        existing_channel.update!(
          additional_attributes: existing_channel.additional_attributes.merge({
            'api_url' => api_url,
            'admin_token' => admin_token,
            'instance_name' => instance_name,
            'api_hash' => instance_data['hash'],
            'provider_type' => 'evolution',
            'phone_number' => formatted_phone
          })
        )
        return existing_inbox
      end
    end

    # Clean up orphaned channels (channels without inbox) for this instance
    existing_channels.each do |orphan_channel|
      if orphan_channel.inbox.nil?
        Rails.logger.info "Removing orphaned Channel::Api ##{orphan_channel.id} for instance #{instance_name}"
        orphan_channel.destroy
      end
    end

    # Also check legacy Channel::Whatsapp
    legacy_channel = Channel::Whatsapp.find_by(phone_number: formatted_phone) rescue nil
    if legacy_channel
      legacy_inbox = legacy_channel.inbox
      if legacy_inbox && legacy_inbox.account_id == current_account.id
        Rails.logger.info "Legacy WhatsApp inbox found for #{formatted_phone}, will be handled by migration"
      end
    end

    # Create Channel::Api with Evolution config in additional_attributes
    channel = Channel::Api.create!(
      account: current_account,
      additional_attributes: {
        'api_url' => api_url,
        'admin_token' => admin_token,
        'instance_name' => instance_name,
        'api_hash' => instance_data['hash'],
        'provider_type' => 'evolution',
        'phone_number' => formatted_phone
      }
    )

    Rails.logger.info "Created Channel::Api with ID: #{channel.id}"

    # Create the inbox
    inbox = Inbox.create!(
      account: current_account,
      name: inbox_name,
      channel: channel
    )

    Rails.logger.info "Created inbox with ID: #{inbox.id}"

    # Add current user as inbox member (if applicable)
    if current_user.present?
      InboxMember.find_or_create_by!(
        inbox: inbox,
        user: current_user
      )
      Rails.logger.info "Added user #{current_user.id} as inbox member"
    end

    inbox
  rescue StandardError => e
    Rails.logger.error "Failed to create Chatwoot inbox: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    nil
  end
end
