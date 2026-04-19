class Whatsapp::TemplateManagementService
  WHATSAPP_API_VERSION = 'v14.0'.freeze
  ALLOWED_CATEGORIES = %w[MARKETING UTILITY].freeze

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  def list_templates(params = {})
    url = "#{business_account_path}/message_templates"
    query_params = { limit: params[:limit] || 100 }
    query_params[:name] = params[:name] if params[:name].present?

    all_templates = []
    response = HTTParty.get(url, headers: api_headers, query: query_params)

    return { success: false, error: parse_error(response) } unless response.success?

    all_templates.concat(response['data'] || [])

    # Handle pagination
    while response.dig('paging', 'next').present?
      response = HTTParty.get(response['paging']['next'], headers: api_headers)
      break unless response.success?

      all_templates.concat(response['data'] || [])
    end

    # Filter to allowed categories only
    filtered = all_templates.select { |t| ALLOWED_CATEGORIES.include?(t['category']) }

    { success: true, templates: filtered }
  rescue StandardError => e
    Rails.logger.error "Error listing templates: #{e.message}"
    { success: false, error: e.message }
  end

  def create_template(params)
    category = params[:category]&.upcase
    unless ALLOWED_CATEGORIES.include?(category)
      return { success: false, error: "Category must be one of: #{ALLOWED_CATEGORIES.join(', ')}" }
    end

    request_body = {
      name: params[:name],
      language: params[:language] || 'en_US',
      category: category,
      components: params[:components]
    }

    response = HTTParty.post(
      "#{business_account_path}/message_templates",
      headers: api_headers,
      body: request_body.to_json
    )

    if response.success?
      {
        success: true,
        template: {
          id: response['id'],
          name: params[:name],
          status: response['status'] || 'PENDING',
          category: category,
          language: params[:language] || 'en_US'
        }
      }
    else
      { success: false, error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error "Error creating template: #{e.message}"
    { success: false, error: e.message }
  end

  def update_template(template_id, params)
    request_body = { components: params[:components] }

    response = HTTParty.post(
      "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{template_id}",
      headers: api_headers,
      body: request_body.to_json
    )

    if response.success?
      { success: true, template: { id: template_id } }
    else
      { success: false, error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error "Error updating template: #{e.message}"
    { success: false, error: e.message }
  end

  def delete_template(template_name)
    response = HTTParty.delete(
      "#{business_account_path}/message_templates?name=#{template_name}",
      headers: api_headers
    )

    if response.success?
      { success: true }
    else
      { success: false, error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error "Error deleting template: #{e.message}"
    { success: false, error: e.message }
  end

  def upload_media(file_data, file_type)
    # Step 1: Create upload session
    session_response = HTTParty.post(
      "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{app_id}/uploads",
      headers: api_headers,
      body: {
        file_length: file_data[:size],
        file_type: file_type
      }.to_json
    )

    return { success: false, error: parse_error(session_response) } unless session_response.success?

    upload_session_id = session_response['id']

    # Step 2: Upload file bytes
    upload_response = HTTParty.post(
      "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{upload_session_id}",
      headers: {
        'Authorization' => "OAuth #{@whatsapp_channel.provider_config['api_key']}",
        'file_offset' => '0',
        'Content-Type' => file_type
      },
      body: file_data[:content]
    )

    if upload_response.success?
      { success: true, handle: upload_response['h'] }
    else
      { success: false, error: parse_error(upload_response) }
    end
  rescue StandardError => e
    Rails.logger.error "Error uploading media: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def parse_error(response)
    return 'Unknown error' unless response&.body.present?

    parsed = JSON.parse(response.body)
    error = parsed['error'] || {}
    error['error_user_msg'] || error['message'] || response.body
  rescue JSON::ParserError
    response.body
  end

  def business_account_path
    "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{@whatsapp_channel.provider_config['business_account_id']}"
  end

  def api_headers
    {
      'Authorization' => "Bearer #{@whatsapp_channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end

  def app_id
    @whatsapp_channel.provider_config['app_id'] || ENV.fetch('WHATSAPP_APP_ID', '')
  end
end
