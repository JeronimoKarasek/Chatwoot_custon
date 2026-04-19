# frozen_string_literal: true

# Evolution Can Reply Patch
# Channel::Api já tem can_reply=true por padrão.
# Este patch é apenas um safety net mínimo para garantir que
# inboxes Evolution nunca sejam bloqueadas.

Rails.application.config.after_initialize do
  Rails.logger.info "EvolutionCanReplyPatch: Loading (minimal for Channel::Api)..."

  # Garantir que Conversation#can_reply? retorne true para inboxes Evolution/Api
  Conversation.class_eval do
    alias_method :original_can_reply?, :can_reply?

    def can_reply?
      if inbox&.channel_type == 'Channel::Api'
        return true
      end
      original_can_reply?
    end
  end

  Rails.logger.info "EvolutionCanReplyPatch: Loaded successfully"
end
