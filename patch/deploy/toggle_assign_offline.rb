# =============================================================================
# Script helper: ativa/desativa "Atribuir mesmo para agentes offline"
# Uso (dentro do container do app):
#
#   # Listar status atual de TODAS as inboxes da conta:
#   docker exec -i <APP_CT> bundle exec rails runner \
#     "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.list(account_id: 37)"
#
#   # Ativar para uma inbox:
#   docker exec -i <APP_CT> bundle exec rails runner \
#     "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.enable(inbox_id: 727)"
#
#   # Desativar para uma inbox:
#   docker exec -i <APP_CT> bundle exec rails runner \
#     "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.disable(inbox_id: 727)"
#
#   # Ativar em LOTE (várias inboxes de uma vez):
#   docker exec -i <APP_CT> bundle exec rails runner \
#     "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.enable_many([727, 696, 737, 742, 747])"
# =============================================================================

module ToggleAssignOffline
  module_function

  def list(account_id:)
    puts format('%-6s | %-40s | %-12s | %-8s | %s', 'ID', 'NOME', 'AUTO_ASSIGN', 'OFFLINE?', 'MEMBROS')
    puts '-' * 100
    Inbox.where(account_id: account_id).order(:id).each do |ib|
      attrs = ib.additional_attributes || {}
      offline = attrs['assign_offline_agents'] || attrs[:assign_offline_agents]
      puts format(
        '%-6s | %-40s | %-12s | %-8s | %s',
        ib.id,
        ib.name.to_s[0, 40],
        ib.enable_auto_assignment ? 'on' : 'off',
        offline ? 'YES' : 'no',
        ib.inbox_members.count
      )
    end
  end

  def enable(inbox_id:)
    update_flag(inbox_id, true)
  end

  def disable(inbox_id:)
    update_flag(inbox_id, false)
  end

  def enable_many(inbox_ids)
    inbox_ids.each { |id| enable(inbox_id: id) }
  end

  def disable_many(inbox_ids)
    inbox_ids.each { |id| disable(inbox_id: id) }
  end

  def update_flag(inbox_id, value)
    ib = Inbox.find_by(id: inbox_id)
    return puts "[ERRO] Inbox ##{inbox_id} não encontrada" unless ib

    attrs = ib.additional_attributes || {}
    attrs['assign_offline_agents'] = value
    ib.update!(additional_attributes: attrs)
    puts "[OK] Inbox ##{ib.id} (#{ib.name}) → assign_offline_agents=#{value}"
  end
end
