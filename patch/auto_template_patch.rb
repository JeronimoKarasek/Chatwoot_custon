# frozen_string_literal: true
# Auto Template Patch - Automatically handles 24h window expiration
# Uses prepend pattern for safe method interception

Rails.application.config.after_initialize do
  Rails.logger.info "AutoTemplatePatch: Loading with prepend pattern..."

  REOPEN_TEMPLATE_NAME = ENV.fetch('REOPEN_TEMPLATE_NAME', 'aviso_3')
  WINDOW_HOURS = 24

  # Module to prepend to WhatsappCloudService
  module AutoTemplateInterceptor
    def send_message(phone_number, message)
      return super unless message.is_a?(Message)

      conversation = message.conversation
      return super unless conversation

      # Check if conversation window is open (has incoming message in last 24h)
      window_open = conversation.messages
                                .where(message_type: :incoming)
                                .where('created_at > ?', WINDOW_HOURS.hours.ago)
                                .exists?

      if window_open
        Rails.logger.debug "[AutoTemplate] Window open for conv #{conversation.id}"
        super
      else
        Rails.logger.info "[AutoTemplate] Window CLOSED for conv #{conversation.id} - auto-sending template"
        handle_closed_window_with_template(phone_number, message, conversation)
      end
    rescue StandardError => e
      if e.message.to_s.include?('131047')
        Rails.logger.warn "[AutoTemplate] Got 131047 error, attempting template for msg #{message.id}"
        handle_closed_window_with_template(phone_number, message, message.conversation)
      else
        raise e
      end
    end

    private

    def handle_closed_window_with_template(phone_number, message, conversation)
      channel = conversation.inbox.channel
      templates = channel.message_templates || []
      
      # Find configured or fallback template
      template = templates.find { |t| t['name'] == REOPEN_TEMPLATE_NAME && t['status'] == 'APPROVED' }
      template ||= templates.find { |t| t['status'] == 'APPROVED' && t['category'] == 'UTILITY' }
      
      unless template
        Rails.logger.error "[AutoTemplate] No approved template found for inbox #{conversation.inbox.name}"
        mark_needs_template(message)
        raise "Janela 24h fechada. Nenhum template disponível."
      end

      Rails.logger.info "[AutoTemplate] Using template '#{template['name']}' for conv #{conversation.id}"
      
      # Send template
      result = send_reopen_template(phone_number, template)
      
      if result
        Rails.logger.info "[AutoTemplate] Template sent: #{result}"
        message.update(
          source_id: result,
          status: :sent,
          content_attributes: message.content_attributes.merge(
            'auto_template' => template['name'],
            'original_content' => message.content
          )
        )
        result
      else
        mark_needs_template(message)
        raise "Falha ao enviar template automaticamente."
      end
    end

    def send_reopen_template(phone_number, template)
      url = "#{api_base_path}/messages"
      clean_number = phone_number.to_s.gsub(/\D/, '')
      
      # Get template language
      lang = template['language'] || 'pt_BR'
      
      payload = {
        messaging_product: 'whatsapp',
        to: clean_number,
        type: 'template',
        template: {
          name: template['name'],
          language: { code: lang }
        }
      }
      
      # Add components if template has variables
      components = build_simple_components(template)
      payload[:template][:components] = components if components.any?

      Rails.logger.info "[AutoTemplate] Sending template to #{clean_number}: #{template['name']}"
      
      response = HTTParty.post(
        url,
        headers: api_headers,
        body: payload.to_json,
        timeout: 30
      )

      if response.success?
        response.parsed_response.dig('messages', 0, 'id')
      else
        Rails.logger.error "[AutoTemplate] API error: #{response.code} - #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[AutoTemplate] Send failed: #{e.message}"
      nil
    end

    def build_simple_components(template)
      components = []
      template_components = template['components'] || []
      
      template_components.each do |comp|
        next unless comp['type'] == 'BODY' && comp['text']&.include?('{{')
        
        var_count = comp['text'].scan(/\{\{\d+\}\}/).count
        next if var_count.zero?
        
        params = var_count.times.map { { type: 'text', text: 'Cliente' } }
        components << { type: 'body', parameters: params }
      end
      
      components
    end

    def mark_needs_template(message)
      message.update(
        status: :failed,
        content_attributes: message.content_attributes.merge(
          'external_error' => '131047: Janela 24h fechada. Envie um template.',
          'needs_template' => true
        )
      )
    end
  end

  # Prepend to WhatsappCloudService
  unless Whatsapp::Providers::WhatsappCloudService.ancestors.include?(AutoTemplateInterceptor)
    Whatsapp::Providers::WhatsappCloudService.prepend(AutoTemplateInterceptor)
    Rails.logger.info "AutoTemplatePatch: Prepended to WhatsappCloudService"
  else
    Rails.logger.info "AutoTemplatePatch: Already prepended"
  end

  Rails.logger.info "AutoTemplatePatch: Loaded - Template: '#{REOPEN_TEMPLATE_NAME}'"
end
