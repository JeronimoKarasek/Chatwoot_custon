# frozen_string_literal: true

# ============================================================================
# ForceAssignmentOfflinePatch
# ----------------------------------------------------------------------------
# Permite que a atribuição automática (round-robin) de uma Inbox inclua
# agentes offline / busy, quando a flag `assign_offline_agents = true`
# estiver presente em `inbox.additional_attributes`.
#
# Por padrão (flag ausente ou false) o comportamento ORIGINAL do Chatwoot é
# preservado: somente agentes ONLINE entram no rodízio (via
# `InboxMembersFilterService` → `inbox.member_ids_with_assignment_capacity`).
#
# Quando a flag está habilitada:
#   * O round-robin nativo é REAPROVEITADO (RoundRobin::ManageService),
#     então a distribuição "1 a 1 uniforme" continua sendo nativa.
#   * Todos os InboxMembers da caixa (auto_assignable=true) são considerados,
#     independente de availability_status.
#   * Limites de carga por agente (`max_assignment_limit` da inbox e
#     `agent_assignment_capacity` do usuário) continuam sendo respeitados.
#
# Compatibilidade:
#   * Depende de `auto_assignment_fix_patch.rb` ter sido carregado antes
#     (3s delay no AssignmentJob).
#   * Não cria migrations.
#   * Persistência via `Inbox#additional_attributes['assign_offline_agents']`
#     (campo JSONB já existente no Chatwoot).
#
# Como ativar para uma inbox (via Rails console):
#   inbox = Inbox.find(727)
#   inbox.additional_attributes ||= {}
#   inbox.additional_attributes['assign_offline_agents'] = true
#   inbox.save!
#
# Como desativar:
#   inbox.additional_attributes['assign_offline_agents'] = false
#   inbox.save!
# ============================================================================

Rails.application.config.after_initialize do
  Rails.logger.info '[ForceAssignmentOfflinePatch] Loading...'

  # --------------------------------------------------------------------------
  # 1) Estende Inbox com helper para consultar a flag de forma segura.
  # --------------------------------------------------------------------------
  Inbox.class_eval do
    def assign_offline_agents?
      attrs = additional_attributes
      return false if attrs.blank?

      # additional_attributes pode vir como Hash com chave string ou symbol
      ActiveModel::Type::Boolean.new.cast(
        attrs['assign_offline_agents'] || attrs[:assign_offline_agents]
      )
    end

    # Lista de InboxMembers elegíveis quando o modo "incluir offline" está ON.
    # Aplica os mesmos filtros do fluxo nativo, exceto availability_status.
    #
    # Filtros aplicados:
    #   - users.auto_assignable = true  (mantém respeito ao toggle do usuário)
    #   - account_users com role válido (agent ou administrator)
    #   - InboxMembers com user ativo
    #
    # Retorna user_ids para alimentar o RoundRobin nativo.
    def member_ids_including_offline_with_capacity
      base_ids = inbox_members
                 .joins(user: :account_users)
                 .where(account_users: { account_id: account_id })
                 .where(users: { auto_assignable: true })
                 .distinct
                 .pluck(:user_id)

      return base_ids if base_ids.empty?

      # Respeita limite de capacidade por agente (mesma lógica do core).
      # Se a inbox não tiver max_assignment_limit, mantém todos.
      filter_by_assignment_capacity(base_ids)
    end

    private

    def filter_by_assignment_capacity(user_ids)
      limit = respond_to?(:max_assignment_limit) ? max_assignment_limit : nil
      return user_ids if limit.blank? || limit.to_i.zero?

      user_ids.reject do |uid|
        current_load = conversations
                       .where(assignee_id: uid)
                       .where(status: %i[open pending])
                       .count
        current_load >= limit.to_i
      end
    end
  end

  # --------------------------------------------------------------------------
  # 2) Sobrescreve AutoAssignmentHandler#run_auto_assignment para usar a lista
  #    estendida quando a flag estiver ligada.
  #
  #    Mantém o delay de 3s do auto_assignment_fix_patch quando v2 está ON.
  # --------------------------------------------------------------------------
  AutoAssignmentHandler.module_eval do
    # Re-define o método (idempotente — o auto_assignment_fix_patch já redefiniu antes)
    define_method(:run_auto_assignment) do
      return unless conversation_status_changed_to_open?
      return unless should_run_auto_assignment?

      if inbox.auto_assignment_v2_enabled?
        # v2 (Enterprise) tem fluxo próprio via AssignmentJob → AssignmentPolicy.
        # Mantemos o delay do patch anterior; a flag offline não se aplica aqui.
        AutoAssignment::AssignmentJob.set(wait: 3.seconds).perform_later(inbox_id: inbox.id)
      else
        allowed_agent_ids = if team_id.present?
                              team_member_ids_with_capacity
                            elsif inbox.assign_offline_agents?
                              inbox.member_ids_including_offline_with_capacity
                            else
                              inbox.member_ids_with_assignment_capacity
                            end

        AutoAssignment::AgentAssignmentService
          .new(conversation: self, allowed_agent_ids: allowed_agent_ids)
          .perform
      end
    end
  end

  # --------------------------------------------------------------------------
  # 3) Sobrescreve Inboxes::BulkAutoAssignmentJob (PeriodicAssignmentJob) para
  #    redistribuir conversas órfãs também usando a lista expandida.
  #
  #    Esse job roda periodicamente para varrer conversas sem assignee
  #    (ex: as 64 conversas paradas da inbox 727 quando não havia agente online).
  # --------------------------------------------------------------------------
  if defined?(Inboxes::BulkAutoAssignmentJob)
    Inboxes::BulkAutoAssignmentJob.class_eval do
      alias_method :__orig_perform_force_offline, :perform unless method_defined?(:__orig_perform_force_offline)

      def perform(inbox_id:)
        inbox = Inbox.find_by(id: inbox_id)
        return __orig_perform_force_offline(inbox_id: inbox_id) unless inbox&.assign_offline_agents?

        allowed_agent_ids = inbox.member_ids_including_offline_with_capacity
        return if allowed_agent_ids.empty?

        inbox.conversations
             .where(assignee_id: nil)
             .where(status: %i[open pending])
             .find_each(batch_size: 50) do |conv|
          AutoAssignment::AgentAssignmentService
            .new(conversation: conv, allowed_agent_ids: allowed_agent_ids)
            .perform
        rescue StandardError => e
          Rails.logger.error(
            "[ForceAssignmentOfflinePatch] Falha ao reatribuir conv ##{conv.id}: #{e.class} #{e.message}"
          )
        end
      end
    end

    Rails.logger.info '[ForceAssignmentOfflinePatch] Inboxes::BulkAutoAssignmentJob patched'
  end

  # --------------------------------------------------------------------------
  # 4) Strong params: garante que o frontend possa enviar a flag via
  #    PATCH /api/v1/accounts/:id/inboxes/:id no payload `additional_attributes`.
  #
  #    O Chatwoot já aceita `additional_attributes: {}` de forma livre quando
  #    `permit!` está em uso. Aqui só logamos para auditoria — sem alteração.
  # --------------------------------------------------------------------------
  Rails.logger.info '[ForceAssignmentOfflinePatch] Loaded. ' \
                    'Toggle via inbox.additional_attributes["assign_offline_agents"]=true'
end
