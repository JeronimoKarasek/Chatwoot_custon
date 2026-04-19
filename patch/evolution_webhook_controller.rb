require 'net/http'
require 'json'
require 'uri'

class Webhooks::EvolutionController < ActionController::API
  skip_before_action :verify_authenticity_token, raise: false

  def process_payload
    instance_name = params[:instance_name]
    payload = JSON.parse(request.raw_post) rescue params.to_unsafe_h

    event_type = payload['event'] || detect_event_type(payload)
    Rails.logger.info "Evolution Webhook [#{instance_name}] event=#{event_type}"

    inbox = find_inbox_by_instance(instance_name)

    unless inbox
      Rails.logger.warn "Evolution Webhook: No inbox found for instance #{instance_name}"
      return render json: { status: 'ignored', reason: 'inbox_not_found' }, status: :ok
    end

    case event_type
    when 'messages.upsert', 'MESSAGES_UPSERT'
      handle_messages_upsert(inbox, payload)
    when 'chats.update', 'CHATS_UPDATE'
      handle_chats_update(inbox, payload)
    when 'messages.update', 'MESSAGES_UPDATE'
      handle_messages_update(inbox, payload)
    when 'connection.update', 'CONNECTION_UPDATE'
      handle_connection_update(inbox, payload)
    when 'qrcode.updated', 'QRCODE_UPDATED'
      handle_qrcode_update(inbox, payload)
    when 'send.message', 'SEND_MESSAGE'
      handle_send_message_ack(inbox, payload)
    else
      Rails.logger.debug "Evolution Webhook: Unhandled event #{event_type}"
    end

    render json: { status: 'ok' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Evolution Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    render json: { status: 'error', message: e.message }, status: :ok
  end

  private

  def find_inbox_by_instance(instance_name)
    # Find Channel::Api with matching instance_name that has an associated inbox
    channels = Channel::Api.where("additional_attributes->>'instance_name' = ?", instance_name)
    channels.each do |channel|
      return channel.inbox if channel.inbox.present?
    end

    # Fallback: try Channel::Whatsapp
    whatsapp_channel = Channel::Whatsapp.find_by("provider_config->>'instance_name' = ?", instance_name) rescue nil
    return whatsapp_channel.inbox if whatsapp_channel&.inbox.present?

    nil
  end

  def detect_event_type(payload)
    return 'messages.upsert' if payload['data']&.dig('message') || payload['message']
    return 'connection.update' if payload['data']&.dig('state') || payload['state']
    return 'qrcode.updated' if payload['data']&.dig('qrcode') || payload['qrcode']
    'unknown'
  end

  # ── MESSAGES.UPSERT ──────────────────────────────────────────────
  def handle_messages_upsert(inbox, payload)
    data = payload['data'] || payload
    key_data = data['key'] || {}

    if key_data['fromMe'] == true
      Rails.logger.debug "Evolution: Skipping outgoing message (fromMe=true)"
      return
    end

    remote_jid = key_data['remoteJid']
    unless remote_jid
      Rails.logger.warn "Evolution: No remoteJid found in payload"
      return
    end

    if remote_jid.include?('@g.us')
      Rails.logger.debug "Evolution: Skipping group message from #{remote_jid}"
      return
    end

    message_id = key_data['id']

    # Fast-path: skip if message already exists
    if message_id.present? && Message.where(inbox_id: inbox.id, source_id: message_id).exists?
      Rails.logger.debug "Evolution: Duplicate message #{message_id}, skipping"
      return
    end

    phone_number = extract_phone_number(key_data, remote_jid)
    Rails.logger.info "Evolution: Processing message for inbox #{inbox.id} from #{phone_number}"

    message_content = extract_message_content(data)
    attachments_data = extract_attachments(data)

    if message_content.blank? && attachments_data.empty?
      Rails.logger.debug "Evolution: No message content or attachments found, skipping"
      return
    end

    contact_inbox = find_or_create_contact_inbox(inbox, phone_number, data)
    unless contact_inbox
      Rails.logger.error "Evolution: Failed to create contact_inbox"
      return
    end

    conversation = find_or_create_conversation(inbox, contact_inbox)
    create_incoming_message(conversation, message_content, data, attachments_data)
  end

  # ── CHATS.UPDATE (fallback sync for missing messages.upsert) ─────
  def handle_chats_update(inbox, payload)
    data = payload['data']
    data = [data] unless data.is_a?(Array)

    data.each do |chat_data|
      next unless chat_data.is_a?(Hash)
      remote_jid = chat_data['remoteJid'] || chat_data.dig('key', 'remoteJid')
      next unless remote_jid.present?
      next if remote_jid.include?('@g.us')

      Rails.logger.info "Evolution: chats.update sync starting for #{remote_jid}"
      sync_recent_messages(inbox, remote_jid)
    end
  end

  def sync_recent_messages(inbox, remote_jid)
    channel = inbox.channel
    api_url = channel.additional_attributes['api_url']
    api_token = channel.additional_attributes['admin_token'] || channel.additional_attributes['api_hash']
    instance_name = channel.additional_attributes['instance_name']

    unless api_url && api_token && instance_name
      Rails.logger.warn "Evolution: Missing API config for chats.update sync"
      return
    end

    # Call Evolution API to get recent incoming messages for this chat
    uri = URI("#{api_url}/chat/findMessages/#{instance_name}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'apikey' => api_token
    })
    request.body = {
      where: { key: { remoteJid: remote_jid, fromMe: false } },
      limit: 10
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Evolution: findMessages API failed (#{response.code}) for #{remote_jid}"
      return
    end

    result = JSON.parse(response.body)
    records = result.dig('messages', 'records') || result['messages'] || []
    records = [records] unless records.is_a?(Array)

    # Only process messages from the last 15 minutes to avoid re-processing old messages
    min_timestamp = (Time.now - 15.minutes).to_i
    new_count = 0
    skipped_old = 0
    skipped_from_me = 0
    skipped_exists = 0
    skipped_empty = 0
    processed = 0

    records.each do |msg_record|
      next unless msg_record.is_a?(Hash)

      msg_timestamp = (msg_record['messageTimestamp'] || 0).to_i
      if msg_timestamp < min_timestamp
        skipped_old += 1
        next
      end

      key_data = msg_record['key'] || {}
      message_id = key_data['id']
      next unless message_id.present?

      if key_data['fromMe'] == true
        skipped_from_me += 1
        next
      end

      # Fast-path: skip if already exists
      if Message.where(inbox_id: inbox.id, source_id: message_id).exists?
        skipped_exists += 1
        next
      end

      processed += 1

      # Build data structure compatible with the existing helpers
      msg_data = {
        'key' => key_data,
        'pushName' => msg_record['pushName'],
        'message' => msg_record['message'] || {},
        'messageTimestamp' => msg_record['messageTimestamp']
      }
      msg_data['base64'] = msg_record['base64'] if msg_record['base64'].present?

      phone_number = extract_phone_number(key_data, remote_jid)
      message_content = extract_message_content(msg_data)
      attachments_data = extract_attachments(msg_data)

      if message_content.blank? && attachments_data.empty?
        skipped_empty += 1
        next
      end

      contact_inbox = find_or_create_contact_inbox(inbox, phone_number, msg_data)
      next unless contact_inbox

      conversation = find_or_create_conversation(inbox, contact_inbox)
      created = create_incoming_message(conversation, message_content, msg_data, attachments_data)
      new_count += 1 if created
    end

    # ALWAYS log the sync result for debugging
    Rails.logger.info "Evolution: chats.update sync for #{remote_jid}: #{new_count} new, #{skipped_exists} exist, #{skipped_old} old, #{skipped_from_me} fromMe, #{skipped_empty} empty (#{records.size} total records)"
  rescue StandardError => e
    Rails.logger.error "Evolution: chats.update sync error for #{remote_jid}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
  end

  # ── Helpers ──────────────────────────────────────────────────────

  def extract_phone_number(key_data, remote_jid)
    sender_pn = key_data['senderPn']
    if sender_pn.present?
      number = sender_pn.split('@').first
      number = "+#{number}" unless number.start_with?('+')
      return number
    end

    if remote_jid.include?('@lid')
      lid_number = remote_jid.split('@').first
      Rails.logger.warn "Evolution: LID format without senderPn, using LID: #{lid_number}"
      return "+lid_#{lid_number}"
    end

    number = remote_jid.split('@').first
    number = "+#{number}" unless number.start_with?('+')
    number
  end

  def extract_message_content(data)
    msg = data['message'] || {}

    return msg['conversation'] if msg['conversation'].present?
    return msg['extendedTextMessage']&.dig('text') if msg['extendedTextMessage'].present?
    return msg['imageMessage']['caption'].presence if msg['imageMessage'].present?
    return msg['videoMessage']['caption'].presence if msg['videoMessage'].present?
    return msg['documentMessage']['caption'].presence || msg['documentMessage']['fileName'] if msg['documentMessage'].present?
    return nil if msg['audioMessage'].present?
    return nil if msg['stickerMessage'].present?

    if msg['locationMessage'].present?
      lat = msg['locationMessage']['degreesLatitude']
      lng = msg['locationMessage']['degreesLongitude']
      return "Localização: #{lat}, #{lng}"
    end

    return "Contato: #{msg['contactMessage']['displayName']}" if msg['contactMessage'].present?
    return msg['buttonsResponseMessage']['selectedDisplayText'] if msg['buttonsResponseMessage'].present?
    return msg['listResponseMessage']['title'] if msg['listResponseMessage'].present?
    return msg['reactionMessage']['text'] if msg['reactionMessage'].present?

    nil
  end

  def extract_attachments(data)
    msg = data['message'] || {}
    attachments = []

    # Evolution API v2 places base64 as a sibling of imageMessage/audioMessage/etc
    # inside the 'message' object, NOT inside the specific message type nor at data level.
    # Priority: msg['base64'] > data['base64'] > msg[type]['base64']
    msg_base64 = msg['base64']

    if msg['imageMessage'].present?
      b64 = msg_base64 || data.dig('base64') || msg['imageMessage']['base64']
      Rails.logger.info "Evolution: imageMessage base64 source=#{msg_base64.present? ? 'msg' : data.dig('base64').present? ? 'data' : msg['imageMessage']['base64'].present? ? 'imageMessage' : 'none'} len=#{b64&.length}"
      attachments << { type: 'image', mimetype: msg['imageMessage']['mimetype'] || 'image/jpeg',
                       url: msg['imageMessage']['url'], base64: b64,
                       filename: "image_#{Time.now.to_i}.jpg" }
    end

    if msg['videoMessage'].present?
      b64 = msg_base64 || data.dig('base64') || msg['videoMessage']['base64']
      attachments << { type: 'video', mimetype: msg['videoMessage']['mimetype'] || 'video/mp4',
                       url: msg['videoMessage']['url'], base64: b64,
                       filename: "video_#{Time.now.to_i}.mp4" }
    end

    if msg['audioMessage'].present?
      ext = msg['audioMessage']['ptt'] ? 'ogg' : 'mp3'
      b64 = msg_base64 || data.dig('base64') || msg['audioMessage']['base64']
      attachments << { type: 'audio', mimetype: msg['audioMessage']['mimetype'] || "audio/#{ext}",
                       url: msg['audioMessage']['url'], base64: b64,
                       filename: "audio_#{Time.now.to_i}.#{ext}" }
    end

    if msg['documentMessage'].present?
      b64 = msg_base64 || data.dig('base64') || msg['documentMessage']['base64']
      attachments << { type: 'document', mimetype: msg['documentMessage']['mimetype'] || 'application/octet-stream',
                       url: msg['documentMessage']['url'], base64: b64,
                       filename: msg['documentMessage']['fileName'] || "document_#{Time.now.to_i}" }
    end

    if msg['stickerMessage'].present?
      b64 = msg_base64 || data.dig('base64') || msg['stickerMessage']['base64']
      attachments << { type: 'image', mimetype: msg['stickerMessage']['mimetype'] || 'image/webp',
                       url: msg['stickerMessage']['url'], base64: b64,
                       filename: "sticker_#{Time.now.to_i}.webp" }
    end

    attachments
  end

  def find_or_create_contact_inbox(inbox, phone_number, message_data)
    push_name = message_data['pushName'] || phone_number

    contact = inbox.account.contacts.find_by(phone_number: phone_number)
    unless contact
      contact = inbox.account.contacts.create!(
        phone_number: phone_number, name: push_name, account_id: inbox.account_id
      )
    end

    if contact.name == contact.phone_number && push_name != phone_number
      contact.update(name: push_name)
    end

    contact_inbox = ContactInbox.find_by(inbox_id: inbox.id, contact_id: contact.id)
    unless contact_inbox
      sid = phone_number.gsub(/[^\d]/, '')
      sid = SecureRandom.uuid if sid.blank?
      contact_inbox = ContactInbox.create!(
        inbox_id: inbox.id, contact_id: contact.id, source_id: sid
      )
    end

    contact_inbox
  rescue StandardError => e
    Rails.logger.error "Evolution: Error creating contact: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
  end

  def find_or_create_conversation(inbox, contact_inbox)
    conversation = inbox.conversations.where(contact_inbox: contact_inbox)
                       .where(status: [:open, :pending])
                       .order(created_at: :desc).first

    unless conversation
      conversation = inbox.conversations.create!(
        account_id: inbox.account_id, contact_id: contact_inbox.contact_id,
        contact_inbox_id: contact_inbox.id, status: :open
      )
    end

    conversation.update!(status: :open) if conversation.resolved?
    conversation
  end

  def create_incoming_message(conversation, content, data, attachments_data = [])
    message_id = data.dig('key', 'id')

    # Fast-path duplicate check (non-authoritative, just an optimization)
    if message_id && Message.where(inbox_id: conversation.inbox_id, source_id: message_id).exists?
      Rails.logger.debug "Evolution: Duplicate message #{message_id}, skipping"
      return false
    end

    content = '' if content.nil? && attachments_data.any?

    message = conversation.messages.build(
      account_id: conversation.account_id, inbox_id: conversation.inbox_id,
      content: content || '', message_type: :incoming,
      source_id: message_id, sender: conversation.contact
    )

    attachments_data.each { |att_data| process_attachment(message, att_data) }
    message.save!

    Rails.logger.info "Evolution: Created message #{message.id} (source=#{message_id}) for conversation #{conversation.id}"
    true
  rescue ActiveRecord::RecordNotUnique => e
    # Unique index on (inbox_id, source_id) prevented duplicate — this is expected
    Rails.logger.info "Evolution: Duplicate prevented by DB constraint for source_id=#{message_id}"
    false
  rescue StandardError => e
    Rails.logger.error "Evolution: Error creating message: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    false
  end

  def process_attachment(message, att_data)
    return unless att_data[:base64].present? || att_data[:url].present?

    begin
      file_data = nil
      if att_data[:base64].present?
        raw_b64 = att_data[:base64]
        Rails.logger.info "Evolution DEBUG: base64 length=#{raw_b64.length}, first100=#{raw_b64[0..99]}, last20=#{raw_b64[-20..]}"
        # Strip data URI prefix if present (e.g., "data:image/jpeg;base64,...")
        if raw_b64.include?(',')
          raw_b64 = raw_b64.split(',', 2).last
          Rails.logger.info "Evolution DEBUG: stripped data URI prefix, new_length=#{raw_b64.length}"
        end
        file_data = Base64.decode64(raw_b64)
        Rails.logger.info "Evolution DEBUG: decoded size=#{file_data.bytesize}, first_hex=#{file_data[0..15].bytes.map{|b| b.to_s(16).rjust(2,'0')}.join(' ')}"
      elsif att_data[:url].present?
        Rails.logger.info "Evolution DEBUG: using URL fallback: #{att_data[:url][0..100]}"
        response = Net::HTTP.get_response(URI.parse(att_data[:url]))
        file_data = response.body if response.is_a?(Net::HTTPSuccess)
      end

      return unless file_data

      io = StringIO.new(file_data)

      attachment = message.attachments.build(
        account_id: message.account_id, file_type: map_file_type(att_data[:type])
      )
      attachment.file.attach(
        io: io, filename: att_data[:filename], content_type: att_data[:mimetype]
      )
    rescue => e
      Rails.logger.error "Evolution: Error processing attachment: #{e.message}"
    end
  end

  def map_file_type(type)
    case type
    when 'image' then :image
    when 'video' then :video
    when 'audio' then :audio
    else :file
    end
  end

  def handle_messages_update(inbox, payload)
    data = payload['data'] || payload
    message_id = data.dig('key', 'id') || data['id']
    status = data['status'] || data.dig('update', 'status')
    return unless message_id && status

    message = inbox.messages.find_by(source_id: message_id)
    return unless message

    case status.to_s.downcase
    when 'read', '4' then message.update(status: :read) if message.respond_to?(:status=)
    when 'delivered', '3', 'delivery_ack' then message.update(status: :delivered) if message.respond_to?(:status=)
    when 'sent', '2', 'server_ack' then message.update(status: :sent) if message.respond_to?(:status=)
    when 'error', '5' then message.update(status: :failed) if message.respond_to?(:status=)
    end
  end

  def handle_send_message_ack(inbox, payload)
    data = payload['data'] || payload
    message_id = data.dig('key', 'id')
    return unless message_id

    message = inbox.messages.find_by(source_id: message_id)
    return unless message

    message.update(status: :sent) if message.status == 'created'
  rescue => e
    Rails.logger.debug "Evolution: SEND_MESSAGE ack error: #{e.message}"
  end

  def handle_connection_update(inbox, payload)
    data = payload['data'] || payload
    state = data['state'] || data['status']

    case state.to_s.downcase
    when 'open', 'connected'
      Rails.logger.info "Evolution: Instance connected for inbox #{inbox.id}"
    when 'close', 'disconnected', 'qr'
      Rails.logger.warn "Evolution: Instance disconnected for inbox #{inbox.id} (state: #{state})"
    end
  end

  def handle_qrcode_update(inbox, payload)
    Rails.logger.info "Evolution: QR code update for inbox #{inbox.id}"
  end
end
