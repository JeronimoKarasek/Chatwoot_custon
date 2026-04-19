# frozen_string_literal: true

# Evolution Inbox Callback - Deleta instância Evolution quando inbox é destruído
# Para Channel::Api com additional_attributes['provider_type'] == 'evolution'

Rails.application.config.after_initialize do
  Rails.logger.info "EvolutionInboxCallback: Loading for Channel::Api..."

  Channel::Api.class_eval do
    before_destroy :delete_evolution_instance, if: :evolution_channel?
    before_save :sanitize_webhook_url_for_evolution, if: :evolution_channel?

    def evolution_channel?
      additional_attributes&.dig('provider_type') == 'evolution'
    end

    private

    # Garante que webhook_url nunca fique nil/"null" em canais Evolution
    # Isso evita o erro "Failed to open TCP connection to null:80"
    def sanitize_webhook_url_for_evolution
      self.webhook_url = '' if webhook_url.nil? || webhook_url == 'null'
    end

    public

    private

    def delete_evolution_instance
      instance_name = additional_attributes&.dig('instance_name')
      api_url = additional_attributes&.dig('api_url') || ENV['EVOLUTION_API_URL']
      api_key = additional_attributes&.dig('api_hash').presence || additional_attributes&.dig('admin_token') || ENV['EVOLUTION_ADMIN_TOKEN']

      if instance_name.blank? || api_url.blank? || api_key.blank?
        Rails.logger.warn "EvolutionInboxCallback: Missing config, skipping delete for #{instance_name}"
        return
      end

      url = "#{api_url.chomp('/')}/instance/delete/#{instance_name}"
      Rails.logger.info "EvolutionInboxCallback: Deleting instance #{instance_name} via #{url}"

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 10
      http.read_timeout = 15

      request = Net::HTTP::Delete.new(uri)
      request['apikey'] = api_key

      response = http.request(request)
      Rails.logger.info "EvolutionInboxCallback: Delete response: #{response.code} #{response.body}"
    rescue StandardError => e
      Rails.logger.error "EvolutionInboxCallback: Error deleting instance: #{e.message}"
      # Não impedir a destruição do canal
    end
  end

  # Patch WebhookJob para nunca executar com URL vazia/null/nil
  # Isso previne o erro "Failed to open TCP connection to null:80" de forma permanente
  WebhookJob.class_eval do
    alias_method :original_webhook_perform, :perform

    def perform(url, payload, webhook_type = :account_webhook)
      if url.blank? || url == 'null'
        Rails.logger.debug "WebhookJob: Skipping webhook with blank/null URL (type=#{webhook_type})"
        return
      end
      original_webhook_perform(url, payload, webhook_type)
    end
  end
  Rails.logger.info "EvolutionInboxCallback: Patched WebhookJob to skip null URLs"

  Rails.logger.info "EvolutionInboxCallback: Loaded successfully"
end
