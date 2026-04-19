# ============================================================
# FarolChat - Patch: Proteção contra dados órfãos (nil contact_inbox)
# Corrige: undefined method 'source_id' for nil em push_event_data
# Data: 2026-04-19
# ============================================================

Rails.application.config.after_initialize do
  Rails.logger.info '[FarolChat] Carregando patch de proteção contra dados órfãos...'

  # Patch Message#conversation_push_event_data para usar safe navigation
  Message.class_eval do
    def conversation_push_event_data
      {
        assignee_id: conversation.assignee_id,
        unread_count: conversation.unread_incoming_messages.count,
        last_activity_at: conversation.last_activity_at.to_i,
        contact_inbox: { source_id: conversation.contact_inbox&.source_id }
      }
    end
  end

  Rails.logger.info '[FarolChat] ✅ Patch de proteção contra dados órfãos carregado'
end
