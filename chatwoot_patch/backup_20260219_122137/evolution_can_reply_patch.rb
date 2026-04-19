# frozen_string_literal: true

# Patch para Evolution API - Remove restrições de janela 24h
# Para inbox com provider "evolution", sempre permite responder

Rails.application.config.after_initialize do
  Rails.logger.info "EvolutionCanReplyPatch: Loading..."

  # Patch Conversation#can_reply? para Evolution
  Conversation.class_eval do
    alias_method :original_can_reply?, :can_reply?

    def can_reply?
      # Se é Evolution, sempre pode responder
      if inbox&.channel_type == 'Channel::Whatsapp' && 
         inbox&.channel&.provider == 'evolution'
        Rails.logger.debug "EvolutionCanReplyPatch: Evolution inbox - can_reply=true"
        return true
      end

      # Caso contrário, usa lógica original
      original_can_reply?
    end
  end

  # Patch Channel::Whatsapp para Evolution não verificar janela
  Channel::Whatsapp.class_eval do
    alias_method :original_message_templates_enabled?, :message_templates_enabled? if method_defined?(:message_templates_enabled?)

    def message_templates_enabled?
      # Evolution não usa templates
      return false if provider == 'evolution'
      
      # Outros providers usam lógica original
      respond_to?(:original_message_templates_enabled?) ? original_message_templates_enabled? : true
    end
  end

  # Patch Inbox para Evolution
  Inbox.class_eval do
    # Override para verificar se precisa de template
    def whatsapp_cloud_inbox?
      return false if channel_type == 'Channel::Whatsapp' && channel&.provider == 'evolution'
      channel_type == 'Channel::Whatsapp' && channel&.provider == 'whatsapp_cloud'
    end
    
    # Método para verificar se é Evolution
    def evolution_channel?
      channel_type == 'Channel::Whatsapp' && channel&.provider == 'evolution'
    end
  end

  # Patch InboxSerializer para enviar dados corretos ao frontend
  if defined?(InboxSerializer)
    InboxSerializer.class_eval do
      # Get original attributes method if exists
      alias_method :original_attributes, :attributes if method_defined?(:attributes)
      
      def attributes
        result = original_attributes
        # Para Evolution, garantir que message_templates_enabled seja false
        if object.channel_type == 'Channel::Whatsapp' && object.channel&.provider == 'evolution'
          result[:message_templates_enabled] = false
          result[:whatsapp_cloud] = false
          result[:provider] = 'evolution'
        end
        result
      rescue => e
        Rails.logger.debug "EvolutionCanReplyPatch: InboxSerializer error - #{e.message}"
        original_attributes rescue {}
      end
    end
  end

  Rails.logger.info "EvolutionCanReplyPatch: Loaded - Evolution inboxes always can_reply=true"
end
