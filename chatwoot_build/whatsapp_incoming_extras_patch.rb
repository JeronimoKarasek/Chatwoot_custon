# frozen_string_literal: true
#
# WABA-PRO Phase 3: Mensageria avançada — Incoming.
#
# - REACTIONS: deixam de ser ignoradas. Cada reação vira uma mensagem do tipo
#   `incoming` com prefixo "[Reação]" + emoji + (referência ao texto reagido,
#   se conseguirmos achar). Também grava `content_attributes[:wa_reaction] =
#   { emoji, target_message_source_id }` para que UIs futuras possam renderizar
#   a reação ancorada à mensagem original (sem alterar schema).
#
# - LOCATION e CONTACTS: já são tratados pelo IncomingMessageBaseService.
#   Aqui apenas marcamos `content_attributes` extras quando a localização tem
#   nome/endereço para preservar metadados.
#
# - VOICE TRANSCRIPT: armazena `content_attributes[:wa_voice_transcript]` se
#   o webhook trouxer (Meta lançou em 2025-10).

Rails.application.config.after_initialize do
  next unless defined?(Whatsapp::IncomingMessageBaseService)
  next unless defined?(Whatsapp::IncomingMessageServiceHelpers)

  module ::WabaPro
    module IncomingMessageHelpersPatch
      # Reactions are now PROCESSABLE. Keep ephemeral/unsupported/request_welcome blocked.
      def unprocessable_message_type?(message_type)
        %w[ephemeral unsupported request_welcome].include?(message_type)
      end
    end

    module IncomingMessageBasePatch
      private

      # Override create_regular_message to handle reactions specially.
      def create_regular_message(message)
        if message_type == 'reaction'
          create_reaction_message(message)
        else
          super
          # Voice transcript (2025-10 Meta feature)
          if %w[audio voice].include?(message_type)
            transcript = (messages_data.first[message_type.to_sym] || {})[:transcript] ||
                         (messages_data.first[message_type.to_sym] || {})['transcript']
            if transcript.present? && @message
              attrs = (@message.content_attributes || {}).deep_dup
              attrs[:wa_voice_transcript] = transcript
              @message.content_attributes = attrs
              @message.save!
            end
          end
        end
      end

      def create_reaction_message(message)
        reaction = message[:reaction] || message['reaction'] || {}
        emoji = reaction[:emoji] || reaction['emoji']
        target_id = reaction[:message_id] || reaction['message_id']

        # Build content with target snippet if found
        target_message = target_id.present? ? Message.find_by(source_id: target_id) : nil
        snippet = target_message&.content.to_s.truncate(60)
        content = if emoji.present?
                    snippet.present? ? "#{emoji} (reagiu a: \"#{snippet}\")" : "Reagiu: #{emoji}"
                  else
                    snippet.present? ? "Removeu reação a: \"#{snippet}\"" : 'Removeu reação'
                  end

        @message = @conversation.messages.build(
          content: content,
          account_id: @inbox.account_id,
          inbox_id: @inbox.id,
          message_type: :incoming,
          status: :sent,
          sender: @contact,
          source_id: message[:id].to_s,
          content_attributes: {
            wa_reaction: {
              emoji: emoji,
              target_message_source_id: target_id,
              target_message_id: target_message&.id
            }
          }
        )
        @message.save!
      end
    end
  end

  Whatsapp::IncomingMessageServiceHelpers.prepend(::WabaPro::IncomingMessageHelpersPatch)
  Whatsapp::IncomingMessageBaseService.prepend(::WabaPro::IncomingMessageBasePatch)
  Rails.logger.info('[WABA-PRO] Incoming extras patch loaded (reactions, voice transcript)')
end
