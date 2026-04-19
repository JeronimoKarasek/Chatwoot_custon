# frozen_string_literal: true

# Evolution Message Sender - Envia mensagens via Evolution API
# Para Channel::Api com additional_attributes['provider_type'] == 'evolution'
# Intercepta SendReplyJob para rotear mensagens pela Evolution API

Rails.application.config.after_initialize do
  Rails.logger.info "EvolutionMessageSender: Loading for Channel::Api..."

  SendReplyJob.class_eval do
    alias_method :original_perform, :perform

    def perform(message_id)
      message = Message.find_by(id: message_id)
      return unless message

      channel = message.inbox&.channel
      if channel.is_a?(Channel::Api) && channel.additional_attributes&.dig('provider_type') == 'evolution'
        # Só envia mensagens outgoing e não-privadas para o cliente
        # Ignora: activity (etiquetas, atribuição de agente), private notes, incoming
        unless message.outgoing? && !message.private?
          Rails.logger.debug "EvolutionMessageSender: Skipping message #{message_id} (type=#{message.message_type}, private=#{message.private?})"
          return
        end
        Rails.logger.info "EvolutionMessageSender: Routing message #{message_id} via Evolution API"
        EvolutionApiDispatcher.send_message(channel, message)
      else
        original_perform(message_id)
      end
    end
  end

  Rails.logger.info "EvolutionMessageSender: Hooked into SendReplyJob"
end

# Módulo separado para envio de mensagens via Evolution API
class EvolutionApiDispatcher
  class << self
    def send_message(channel, message)
      config = channel.additional_attributes || {}
      instance_name = config['instance_name']
      api_url = config['api_url'] || ENV['EVOLUTION_API_URL']
      api_key = config['api_hash'].presence || config['admin_token'] || ENV['EVOLUTION_ADMIN_TOKEN']

      if instance_name.blank? || api_url.blank? || api_key.blank?
        Rails.logger.error "EvolutionMessageSender: Missing config - instance: #{instance_name}, url: #{api_url}, key present: #{api_key.present?}"
        message.update!(status: :failed) rescue nil
        return
      end

      phone = message.conversation&.contact&.phone_number.to_s.gsub(/\D/, '')
      if phone.blank?
        Rails.logger.error "EvolutionMessageSender: No phone number for message #{message.id}"
        message.update!(status: :failed) rescue nil
        return
      end

      jid = "#{phone}@s.whatsapp.net"

      if message.attachments.any?
        send_with_attachments(api_url, api_key, instance_name, phone, jid, message)
      else
        source_id = send_text(api_url, api_key, instance_name, phone, message.content || '')
        update_message(message, source_id)
      end
    rescue StandardError => e
      Rails.logger.error "EvolutionMessageSender: Error sending message #{message.id}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      message.update!(status: :failed) rescue nil
    end

    private

    def send_with_attachments(api_url, api_key, instance_name, phone, jid, message)
      results = []

      message.attachments.each do |attachment|
        result = send_media(api_url, api_key, instance_name, phone, attachment, message)
        results << result
      end

      # Se tem texto e múltiplos anexos, envia texto separado
      if message.content.present? && message.attachments.size > 1
        text_result = send_text(api_url, api_key, instance_name, phone, message.content)
        results << text_result
      end

      source_id = results.compact.first
      update_message(message, source_id)
    end

    def send_text(api_url, api_key, instance_name, phone, text)
      url = "#{api_url.chomp('/')}/message/sendText/#{instance_name}"
      Rails.logger.info "EvolutionMessageSender: Sending text to #{phone} via #{url}"

      body = { number: phone, text: text }
      response = http_post(url, api_key, body)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body) rescue {}
        source_id = data.dig('key', 'id') || data['messageId'] || data['id']
        Rails.logger.info "EvolutionMessageSender: Text sent, source_id: #{source_id}"
        source_id
      else
        Rails.logger.error "EvolutionMessageSender: Text send failed: #{response.code} #{response.body}"
        raise "Evolution API error: #{response.code}"
      end
    end

    def send_media(api_url, api_key, instance_name, phone, attachment, message)
      media_type = detect_media_type(attachment)
      url = "#{api_url.chomp('/')}/message/sendMedia/#{instance_name}"
      Rails.logger.info "EvolutionMessageSender: Sending #{media_type} to #{phone}"

      file_url = attachment.file_url
      unless file_url
        Rails.logger.error "EvolutionMessageSender: No file URL for attachment #{attachment.id}"
        return nil
      end

      unless file_url.start_with?('http')
        frontend_url = ENV['FRONTEND_URL'] || 'https://app.farolchat.com'
        file_url = "#{frontend_url.chomp('/')}#{file_url}"
      end

      body = {
        number: phone,
        mediatype: media_type,
        mimetype: attachment.file&.content_type || 'application/octet-stream',
        caption: %w[image video].include?(media_type) ? (message.content || '') : '',
        media: file_url,
        fileName: attachment.file&.filename.to_s.presence || "file_#{attachment.id}"
      }

      response = http_post(url, api_key, body)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body) rescue {}
        source_id = data.dig('key', 'id') || data['messageId'] || data['id']
        Rails.logger.info "EvolutionMessageSender: Media sent, source_id: #{source_id}"
        source_id
      else
        Rails.logger.error "EvolutionMessageSender: Media send failed: #{response.code} #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "EvolutionMessageSender: Error sending media: #{e.message}"
      nil
    end

    def detect_media_type(attachment)
      ct = attachment.file&.content_type.to_s.downcase
      case ct
      when /^image\// then 'image'
      when /^video\// then 'video'
      when /^audio\//, /^application\/ogg/ then 'audio'
      else 'document'
      end
    end

    def http_post(url, api_key, body)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['apikey'] = api_key
      request['Content-Type'] = 'application/json'
      request.body = body.to_json

      http.request(request)
    end

    def update_message(message, source_id)
      if source_id.present?
        message.update!(source_id: source_id, status: :sent)
        Rails.logger.info "EvolutionMessageSender: Message #{message.id} updated with source_id #{source_id}"
      else
        message.update!(status: :failed) rescue nil
        Rails.logger.error "EvolutionMessageSender: No source_id for message #{message.id}"
      end
    end
  end
end
