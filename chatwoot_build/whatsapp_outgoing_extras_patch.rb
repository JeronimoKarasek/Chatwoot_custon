# frozen_string_literal: true
#
# WABA-PRO Phase 3: Mensageria avançada — Outgoing.
#
# Adiciona métodos públicos no Whatsapp::Providers::WhatsappCloudService:
#   - send_reaction(phone_number, target_message_source_id, emoji)
#   - send_location(phone_number, latitude, longitude, name: nil, address: nil)
#   - send_contacts(phone_number, contacts_array)
#   - send_typing_indicator(message_source_id)
#   - block_users(wa_ids)  /  unblock_users(wa_ids)
#
# Estes métodos batem direto na Cloud API. Servem para:
#   1) chamadas via Rails console / scripts
#   2) integrações futuras (UI, automações, bots)
#   3) testes E2E
#
# Não modifica o pipeline atual (send_message etc), portanto seguro.

Rails.application.config.after_initialize do
  next unless defined?(Whatsapp::Providers::WhatsappCloudService)
  next unless defined?(Whatsapp::FacebookApiClient)

  module ::WabaPro
    module CloudServiceOutgoingExtras
      # Send a reaction emoji (or remove it by passing emoji: '' or nil)
      def send_reaction(phone_number, target_message_source_id, emoji)
        body = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: phone_number,
          type: 'reaction',
          reaction: {
            message_id: target_message_source_id.to_s,
            emoji: emoji.to_s
          }
        }
        __waba_post_message(body)
      end

      # Send a static location pin
      def send_location(phone_number, latitude:, longitude:, name: nil, address: nil)
        location = { latitude: latitude.to_f, longitude: longitude.to_f }
        location[:name] = name if name.present?
        location[:address] = address if address.present?

        body = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: phone_number,
          type: 'location',
          location: location
        }
        __waba_post_message(body)
      end

      # Send vCard-style contacts. Each contact: { name: { formatted_name: 'X', first_name: 'X' }, phones: [{ phone: '+...' }] }
      def send_contacts(phone_number, contacts)
        body = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: phone_number,
          type: 'contacts',
          contacts: Array(contacts)
        }
        __waba_post_message(body)
      end

      # Show typing indicator (Meta 2025-04). Requires an inbound message_id to ack.
      def send_typing_indicator(message_source_id)
        client = Whatsapp::FacebookApiClient.new(whatsapp_channel.provider_config['api_key'])
        client.send_typing_indicator(whatsapp_channel.provider_config['phone_number_id'], message_source_id)
      end

      # Block / unblock users. wa_ids: array of E.164-without-plus strings or array of phone numbers.
      def block_users(wa_ids)
        client = Whatsapp::FacebookApiClient.new(whatsapp_channel.provider_config['api_key'])
        client.block_users(whatsapp_channel.provider_config['phone_number_id'], wa_ids)
      end

      def unblock_users(wa_ids)
        client = Whatsapp::FacebookApiClient.new(whatsapp_channel.provider_config['api_key'])
        client.unblock_users(whatsapp_channel.provider_config['phone_number_id'], wa_ids)
      end

      private

      def __waba_post_message(body)
        response = HTTParty.post(
          "#{send(:phone_id_path)}/messages",
          headers: api_headers,
          body: body.to_json
        )
        unless response.success?
          err = response.parsed_response&.dig('error', 'message') || response.body
          raise "WABA send failed: #{err}"
        end
        response.parsed_response
      end
    end
  end

  Whatsapp::Providers::WhatsappCloudService.prepend(::WabaPro::CloudServiceOutgoingExtras)
  Rails.logger.info('[WABA-PRO] Outgoing extras patch loaded (reaction, location, contacts, typing, block)')
end
