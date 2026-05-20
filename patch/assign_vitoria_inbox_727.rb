# =============================================================================
# Script: Atribuir conversas pendentes da Inbox #727 (Vitoria) ao agente 158
# Conta: 37 (Exconsig)
# Execução: docker exec -i <APP_CONTAINER> bundle exec rails runner \
#           /caminho/para/assign_vitoria_inbox_727.rb
#
# IMPORTANTE:
#   - Este script NÃO reinicia nada
#   - Não mexe em patches/initializers
#   - Só faz INSERT/UPDATE no banco via ActiveRecord
#   - Roda dentro de uma transaction; em caso de erro, faz rollback automático
# =============================================================================

USER_ID  = 158
INBOX_ID = 727

puts "=" * 70
puts "FASE 1 — VERIFICAÇÃO (READ-ONLY)"
puts "=" * 70

u  = User.find_by(id: USER_ID)
ib = Inbox.find_by(id: INBOX_ID)

abort "ERRO: User #{USER_ID} não encontrado"  unless u
abort "ERRO: Inbox #{INBOX_ID} não encontrado" unless ib

acc_user = AccountUser.find_by(account_id: ib.account_id, user_id: USER_ID)
abort "ERRO: User #{USER_ID} não pertence à conta #{ib.account_id}" unless acc_user

puts "Agente:  ##{u.id} | #{u.name} | #{u.email}"
puts "Role na conta #{ib.account_id}: #{acc_user.role}"
puts "Inbox:   ##{ib.id} | #{ib.name} | account=#{ib.account_id}"
puts "Membros atuais da inbox: #{ib.inbox_members.count}"
puts "Já é membro? #{InboxMember.exists?(inbox_id: INBOX_ID, user_id: USER_ID)}"

scope = Conversation.where(inbox_id: INBOX_ID, assignee_id: nil)
puts "\nConversas SEM assignee na inbox ##{INBOX_ID}:"
puts "  open:     #{scope.where(status: :open).count}"
puts "  pending:  #{scope.where(status: :pending).count}"
puts "  snoozed:  #{scope.where(status: :snoozed).count}"
puts "  resolved: #{scope.where(status: :resolved).count} (NÃO serão tocadas)"

# Vamos atribuir TODAS as não-resolved sem assignee
to_assign = scope.where.not(status: :resolved)
puts "\n>>> Total a atribuir (open + pending + snoozed): #{to_assign.count}"
puts "=" * 70

# =============================================================================
# FASE 2 — AÇÃO (dentro de transaction)
# Descomente o bloco abaixo APENAS após validar a Fase 1
# =============================================================================

# ActiveRecord::Base.transaction do
#   # 2.1) Adiciona Vitoria como membro permanente da inbox (resolve auto-assign futuro)
#   unless InboxMember.exists?(inbox_id: INBOX_ID, user_id: USER_ID)
#     im = InboxMember.create!(inbox_id: INBOX_ID, user_id: USER_ID)
#     puts "[OK] InboxMember criado: id=#{im.id}"
#   else
#     puts "[SKIP] Já era membro"
#   end
#
#   # 2.2) Atribui as conversas pendentes (open + pending + snoozed, sem assignee)
#   updated = 0
#   to_assign.find_each(batch_size: 50) do |conv|
#     conv.update!(assignee_id: USER_ID)
#     updated += 1
#   end
#   puts "[OK] #{updated} conversas atribuídas ao agente #{USER_ID}"
#
#   # Para abortar e validar antes de commitar de verdade, descomente:
#   # raise ActiveRecord::Rollback, "DRY-RUN: rollback proposital"
# end

puts "\n>>> Fase 2 está COMENTADA. Descomente o bloco para executar de verdade."
