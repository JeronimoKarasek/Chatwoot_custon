# frozen_string_literal: true
# Evolution API - Delete instance when inbox is destroyed

Rails.application.config.after_initialize do
  # Add callback to Channel::Whatsapp to delete Evolution instance on destroy
  Channel::Whatsapp.class_eval do
    before_destroy :delete_evolution_instance, if: :evolution_provider?

    private

    def evolution_provider?
      provider == 'evolution'
    end

    def delete_evolution_instance
      return unless provider_config.present?
      
      instance_name = provider_config['instance_name']
      api_url = provider_config['api_url'] || ENV['EVOLUTION_API_URL']
      admin_token = provider_config['admin_token'] || ENV['EVOLUTION_ADMIN_TOKEN']

      return if instance_name.blank? || api_url.blank? || admin_token.blank?

      Rails.logger.info "Evolution API: Deleting instance #{instance_name} on inbox destroy"

      begin
        delete_url = "#{api_url.chomp('/')}/instance/delete/#{instance_name}"
        uri = URI.parse(delete_url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Delete.new(uri)
        request['apikey'] = admin_token
        request['Content-Type'] = 'application/json'

        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          Rails.logger.info "Evolution API: Instance #{instance_name} deleted successfully"
        else
          Rails.logger.warn "Evolution API: Failed to delete instance #{instance_name}. Status: #{response.code}, Body: #{response.body}"
        end
      rescue StandardError => e
        Rails.logger.error "Evolution API: Error deleting instance #{instance_name}: #{e.message}"
        # Don't raise - we still want to delete the inbox even if Evolution API fails
      end
    end
  end
end
