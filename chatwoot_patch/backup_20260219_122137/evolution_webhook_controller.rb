class Webhooks::EvolutionController < ActionController::API
  # Skip authentication for webhook endpoints
  skip_before_action :verify_authenticity_token, raise: false
  
  def process_payload
    Rails.logger.info "Evolution Webhook received for instance: #{params[:instance_name]}"
    Rails.logger.info "Evolution Webhook payload: #{request.raw_post}"
    
    instance_name = params[:instance_name]
    payload = JSON.parse(request.raw_post) rescue params.to_unsafe_h
    
    # Find inbox by instance_name (stored in provider_config)
    inbox = find_inbox_by_instance(instance_name)
    
    unless inbox
      Rails.logger.warn "Evolution Webhook: No inbox found for instance #{instance_name}"
      return render json: { status: 'ignored', reason: 'inbox_not_found' }, status: :ok
    end
    
    event_type = payload['event'] || detect_event_type(payload)
    
    case event_type
    when 'messages.upsert', 'MESSAGES_UPSERT'
      handle_messages_upsert(inbox, payload)
    when 'messages.update', 'MESSAGES_UPDATE'
      handle_messages_update(inbox, payload)
    when 'connection.update', 'CONNECTION_UPDATE'
      handle_connection_update(inbox, payload)
    when 'qrcode.updated', 'QRCODE_UPDATED'
      handle_qrcode_update(inbox, payload)
    else
      Rails.logger.info "Evolution Webhook: Unhandled event type #{event_type}"
    end
    
    render json: { status: 'ok' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Evolution Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render json: { status: 'error', message: e.message }, status: :ok
  end
  
  private
  
  def find_inbox_by_instance(instance_name)
    Channel::Whatsapp.find_by("provider_config->>'instance_name' = ?", instance_name)&.inbox
  end
  
  def detect_event_type(payload)
    return 'messages.upsert' if payload['data']&.dig('message') || payload['message']
    return 'connection.update' if payload['data']&.dig('state') || payload['state']
    return 'qrcode.updated' if payload['data']&.dig('qrcode') || payload['qrcode']
    'unknown'
  end
  
  def handle_messages_upsert(inbox, payload)
    Rails.logger.info "Evolution: Processing incoming message for inbox #{inbox.id}"
    
    # data contains: key, pushName, message, messageType, messageTimestamp
    data = payload['data'] || payload
    
    Rails.logger.debug "Evolution: Data structure: #{data.keys rescue 'not a hash'}"
    
    # key contains: remoteJid, fromMe, id
    key_data = data['key'] || {}
    
    # Skip if it's an outgoing message from us
    if key_data['fromMe'] == true
      Rails.logger.debug "Evolution: Skipping outgoing message"
      return
    end
    
    remote_jid = key_data['remoteJid']
    unless remote_jid
      Rails.logger.warn "Evolution: No remoteJid found in payload"
      return
    end
    
    # Extract phone number from jid (format: 5511999999999@s.whatsapp.net)
    phone_number = remote_jid.split('@').first
    phone_number = "+#{phone_number}" unless phone_number.start_with?('+')
    
    Rails.logger.debug "Evolution: Phone number: #{phone_number}"
    
    # Get message content from data['message']
    message_content = extract_message_content(data)
    if message_content.blank?
      Rails.logger.warn "Evolution: No message content found"
      return
    end
    
    Rails.logger.debug "Evolution: Message content: #{message_content.truncate(100)}"
    
    # Find or create contact
    contact_inbox = find_or_create_contact_inbox(inbox, phone_number, data)
    unless contact_inbox
      Rails.logger.error "Evolution: Failed to create contact_inbox"
      return
    end
    
    # Find or create conversation
    conversation = find_or_create_conversation(inbox, contact_inbox)
    
    # Create message
    create_incoming_message(conversation, message_content, data)
  end
  
  def extract_message_content(data)
    # data contains: key, pushName, message, messageType, messageTimestamp
    # message contains: conversation, extendedTextMessage, imageMessage, etc.
    msg = data['message'] || {}
    
    Rails.logger.debug "Evolution: Message structure: #{msg.keys rescue 'not a hash'}"
    
    # Text message
    return msg['conversation'] if msg['conversation'].present?
    return msg['extendedTextMessage']&.dig('text') if msg['extendedTextMessage'].present?
    
    # Media messages - return caption or type indicator
    if msg['imageMessage'].present?
      return msg['imageMessage']['caption'] || '[Imagem]'
    end
    if msg['videoMessage'].present?
      return msg['videoMessage']['caption'] || '[Vídeo]'
    end
    if msg['audioMessage'].present?
      return '[Áudio]'
    end
    if msg['documentMessage'].present?
      return msg['documentMessage']['fileName'] || '[Documento]'
    end
    if msg['stickerMessage'].present?
      return '[Sticker]'
    end
    if msg['locationMessage'].present?
      return "[Localização: #{msg['locationMessage']['degreesLatitude']}, #{msg['locationMessage']['degreesLongitude']}]"
    end
    if msg['contactMessage'].present?
      return "[Contato: #{msg['contactMessage']['displayName']}]"
    end
    
    # Button response
    if msg['buttonsResponseMessage'].present?
      return msg['buttonsResponseMessage']['selectedDisplayText']
    end
    
    # List response
    if msg['listResponseMessage'].present?
      return msg['listResponseMessage']['title']
    end
    
    nil
  end
  
  def find_or_create_contact_inbox(inbox, phone_number, message_data)
    # Get contact name from push name
    push_name = message_data['pushName'] || phone_number
    
    contact = inbox.account.contacts.find_by(phone_number: phone_number)
    
    unless contact
      contact = inbox.account.contacts.create!(
        phone_number: phone_number,
        name: push_name,
        account_id: inbox.account_id
      )
    end
    
    contact_inbox = ContactInbox.find_by(inbox_id: inbox.id, contact_id: contact.id)
    
    unless contact_inbox
      contact_inbox = ContactInbox.create!(
        inbox_id: inbox.id,
        contact_id: contact.id,
        source_id: phone_number
      )
    end
    
    contact_inbox
  rescue StandardError => e
    Rails.logger.error "Evolution: Error creating contact: #{e.message}"
    nil
  end
  
  def find_or_create_conversation(inbox, contact_inbox)
    # Find existing open conversation
    conversation = inbox.conversations.where(contact_inbox: contact_inbox)
                       .where.not(status: :resolved)
                       .order(created_at: :desc)
                       .first
    
    # Create new conversation if none exists
    unless conversation
      conversation = inbox.conversations.create!(
        account_id: inbox.account_id,
        contact_id: contact_inbox.contact_id,
        contact_inbox_id: contact_inbox.id,
        status: :open
      )
    end
    
    conversation
  end
  
  def create_incoming_message(conversation, content, data)
    # data contains: key, pushName, message, messageType, messageTimestamp
    message_id = data.dig('key', 'id')
    
    Rails.logger.debug "Evolution: Creating message with source_id: #{message_id}"
    
    # Check for duplicate
    if message_id && conversation.messages.exists?(source_id: message_id)
      Rails.logger.debug "Evolution: Duplicate message, skipping"
      return
    end
    
    message = conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: content,
      message_type: :incoming,
      source_id: message_id,
      sender: conversation.contact
    )
    
    Rails.logger.info "Evolution: Created incoming message #{message.id} for conversation #{conversation.id}"
  rescue StandardError => e
    Rails.logger.error "Evolution: Error creating message: #{e.message}"
  end
  
  def handle_messages_update(inbox, payload)
    Rails.logger.info "Evolution: Message update for inbox #{inbox.id}"
    # Handle message status updates (read, delivered, etc.)
    data = payload['data'] || payload
    
    message_id = data.dig('key', 'id') || data['id']
    status = data['status'] || data.dig('update', 'status')
    
    return unless message_id && status
    
    message = inbox.messages.find_by(source_id: message_id)
    return unless message
    
    case status.to_s.downcase
    when 'read', '4', 'READ'
      message.update(status: :read) if message.respond_to?(:status=)
    when 'delivered', '3', 'DELIVERY_ACK'
      message.update(status: :delivered) if message.respond_to?(:status=)
    when 'sent', '2', 'SERVER_ACK'
      message.update(status: :sent) if message.respond_to?(:status=)
    end
  end
  
  def handle_connection_update(inbox, payload)
    Rails.logger.info "Evolution: Connection update for inbox #{inbox.id}"
    
    data = payload['data'] || payload
    state = data['state'] || data['status']
    
    channel = inbox.channel
    return unless channel
    
    case state.to_s.downcase
    when 'open', 'connected'
      Rails.logger.info "Evolution: Instance connected for inbox #{inbox.id}"
      # Could update provider_config with connection status
    when 'close', 'disconnected', 'qr'
      Rails.logger.warn "Evolution: Instance disconnected for inbox #{inbox.id}"
      # Could send notification to account admins
      notify_disconnection(inbox, state)
    end
  end
  
  def handle_qrcode_update(inbox, payload)
    Rails.logger.info "Evolution: QR code update for inbox #{inbox.id}"
    # This can be used for real-time QR code updates via ActionCable
  end
  
  def notify_disconnection(inbox, state)
    # Create a system message in recent conversations to notify about disconnection
    Rails.logger.warn "Evolution: Sending disconnection notification for inbox #{inbox.name}"
    
    # You could implement email notification or in-app notification here
    # For now, just log it
  end
end
