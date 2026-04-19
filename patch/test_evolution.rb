inbox = Inbox.find(501)
account = inbox.account

# Encontrar ou criar contato
phone = '+5519971069771'
contact = Contact.find_by(phone_number: phone, account_id: account.id)
if contact.nil?
  contact = Contact.create!(phone_number: phone, name: 'Teste Evolution', account_id: account.id)
  puts "Contato criado: #{contact.id}"
else
  puts "Contato existente: #{contact.id}"
end

# Criar contact_inbox
ci = ContactInbox.find_or_create_by!(contact_id: contact.id, inbox_id: inbox.id, source_id: phone.gsub('+', ''))
puts "ContactInbox: #{ci.id}"

# Criar conversa
conv = Conversation.find_or_create_by!(contact_id: contact.id, inbox_id: inbox.id, account_id: account.id, contact_inbox_id: ci.id)
puts "Conversa: #{conv.id} | display_id: #{conv.display_id}"

# Enviar mensagem
msg = conv.messages.create!(
  message_type: :outgoing,
  content: 'Teste Evolution API - ' + Time.current.strftime('%H:%M:%S'),
  account_id: account.id,
  inbox_id: inbox.id,
  sender: account.users.first
)
puts "Mensagem #{msg.id} criada"

sleep 8
msg.reload
puts "Status: #{msg.status}"
source = msg.source_id || 'NULL'
puts "source_id: #{source}"
if msg.content_attributes.present?
  puts "Errors: #{msg.content_attributes}"
end
