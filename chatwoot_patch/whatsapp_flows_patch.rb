# frozen_string_literal: true
#
# WABA-PRO Phase 4: WhatsApp Flows v7 (backend)
#
# Implementa o fluxo encrypted endpoint da Meta:
#   - Per-channel RSA-2048 keypair em provider_config['flows_encryption']
#   - Helper para gerar e re-publicar a public key na Meta (POST /<phone_id>/whatsapp_business_encryption)
#   - Endpoint POST /webhooks/whatsapp/flow/:channel_id que:
#       1) Recebe { encrypted_flow_data, encrypted_aes_key, initial_vector }
#       2) RSA-OAEP-SHA256 decifra a AES key
#       3) AES-128-GCM decifra o payload
#       4) Dispatcha para WabaPro::FlowsRouter (action: ping/INIT/data_exchange/BACK/complete)
#       5) Cifra a resposta com IV invertido + GCM (Meta spec)
#       6) Retorna body base64
#   - Service WabaPro::FlowsService para gerenciar (CRUD) flows na Cloud API
#   - Outgoing: provider_service.send_flow(phone, flow_id, flow_cta, ...)
#
# Storage de Flows: provider_config['flows'] = { <flow_id> => { name, screens, version, state } }

require 'openssl'
require 'base64'

Rails.application.config.after_initialize do
  next unless defined?(Channel::Whatsapp)
  next unless defined?(Whatsapp::Providers::WhatsappCloudService)

  module ::WabaPro
    module FlowEncryption
      module_function

      # Decifra payload vindo do webhook do Flow
      def decrypt(private_key_pem:, encrypted_aes_key_b64:, encrypted_flow_data_b64:, iv_b64:)
        private_key = OpenSSL::PKey::RSA.new(private_key_pem)
        aes_key = private_key.private_decrypt_oaep(Base64.decode64(encrypted_aes_key_b64), '', 'SHA256', 'SHA256')

        flow_data = Base64.decode64(encrypted_flow_data_b64)
        iv = Base64.decode64(iv_b64)

        # Last 16 bytes are the GCM tag
        encrypted_body = flow_data[0...-16]
        auth_tag = flow_data[-16..]

        cipher = OpenSSL::Cipher.new('aes-128-gcm').decrypt
        cipher.key = aes_key
        cipher.iv = iv
        cipher.auth_tag = auth_tag
        cipher.auth_data = ''

        decrypted = cipher.update(encrypted_body) + cipher.final
        { aes_key: aes_key, iv: iv, payload: JSON.parse(decrypted) }
      end

      # Cifra a resposta de volta. Meta exige IV com bits invertidos.
      def encrypt_response(aes_key:, iv:, response_payload:)
        flipped_iv = iv.bytes.map { |b| b ^ 0xff }.pack('C*')
        cipher = OpenSSL::Cipher.new('aes-128-gcm').encrypt
        cipher.key = aes_key
        cipher.iv = flipped_iv
        cipher.auth_data = ''
        encrypted = cipher.update(response_payload.to_json) + cipher.final
        Base64.strict_encode64(encrypted + cipher.auth_tag)
      end
    end

    # ----- Flow router: handler default + customizáveis por flow_id -----
    class FlowsRouter
      @handlers = {}
      class << self
        attr_reader :handlers
        def register(flow_id, &block)
          @handlers[flow_id.to_s] = block
        end

        def dispatch(channel:, flow_id:, payload:)
          handler = @handlers[flow_id.to_s] || method(:default_handler)
          handler.call(channel: channel, payload: payload)
        end

        def default_handler(channel:, payload:)
          action = payload['action']
          case action
          when 'ping'
            { data: { status: 'active' } }
          when 'INIT'
            { screen: payload['screen'] || 'WELCOME', data: {} }
          when 'data_exchange'
            # echo + accept
            { screen: payload['screen'], data: payload['data'] || {} }
          when 'BACK'
            { screen: payload['screen'], data: {} }
          else
            { data: { acknowledged: true } }
          end
        end
      end
    end

    # ----- Service: gerencia flows na Meta + keypair -----
    class FlowsService
      def initialize(channel)
        @channel = channel
      end

      def ensure_keypair!
        cfg = @channel.provider_config || {}
        return cfg['flows_encryption'] if cfg.dig('flows_encryption', 'private_key_pem').present?

        rsa = OpenSSL::PKey::RSA.new(2048)
        encryption = {
          'private_key_pem' => rsa.to_pem,
          'public_key_pem' => rsa.public_key.to_pem,
          'generated_at' => Time.now.utc.iso8601
        }
        cfg['flows_encryption'] = encryption
        @channel.update_column(:provider_config, cfg)
        encryption
      end

      def publish_public_key!
        kp = ensure_keypair!
        response = HTTParty.post(
          "#{api_base}/#{api_version}/#{@channel.provider_config['phone_number_id']}/whatsapp_business_encryption",
          headers: api_headers,
          body: { business_public_key: kp['public_key_pem'] }.to_json
        )
        raise "publish_public_key failed: #{response.body}" unless response.success?

        response.parsed_response
      end

      def list_flows
        response = HTTParty.get(
          "#{api_base}/#{api_version}/#{@channel.provider_config['business_account_id']}/flows",
          headers: api_headers
        )
        response.parsed_response
      end

      def create_flow(name:, categories: ['OTHER'])
        response = HTTParty.post(
          "#{api_base}/#{api_version}/#{@channel.provider_config['business_account_id']}/flows",
          headers: api_headers,
          body: { name: name, categories: categories }.to_json
        )
        raise "create_flow failed: #{response.body}" unless response.success?

        response.parsed_response
      end

      def upload_flow_json(flow_id:, flow_json:)
        # multipart upload via faraday-style; usar HTTParty multipart
        require 'tempfile'
        tf = Tempfile.new(['flow', '.json'])
        tf.write(flow_json.is_a?(String) ? flow_json : flow_json.to_json)
        tf.rewind
        response = HTTParty.post(
          "#{api_base}/#{api_version}/#{flow_id}/assets",
          headers: { 'Authorization' => "Bearer #{@channel.provider_config['api_key']}" },
          multipart: true,
          body: { name: 'flow.json', asset_type: 'FLOW_JSON', file: tf }
        )
        raise "upload_flow_json failed: #{response.body}" unless response.success?

        response.parsed_response
      ensure
        tf&.close!
      end

      def publish_flow(flow_id)
        response = HTTParty.post(
          "#{api_base}/#{api_version}/#{flow_id}/publish",
          headers: api_headers
        )
        raise "publish_flow failed: #{response.body}" unless response.success?

        response.parsed_response
      end

      private

      def api_base
        ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
      end

      def api_version
        GlobalConfigService.load('WHATSAPP_API_VERSION', 'v25.0')
      end

      def api_headers
        { 'Authorization' => "Bearer #{@channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
      end
    end

    # ----- Outgoing: enviar flow como mensagem interactive -----
    module CloudServiceFlowSender
      def send_flow(phone_number, flow_id:, flow_cta:, flow_token: nil, header_text: nil, body_text:, footer_text: nil, mode: 'published', screen: 'WELCOME', flow_action_payload: {})
        body = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: phone_number,
          type: 'interactive',
          interactive: {
            type: 'flow',
            body: { text: body_text },
            action: {
              name: 'flow',
              parameters: {
                flow_message_version: '3',
                flow_token: flow_token || SecureRandom.hex(12),
                flow_id: flow_id.to_s,
                flow_cta: flow_cta,
                flow_action: 'navigate',
                mode: mode,
                flow_action_payload: { screen: screen, data: flow_action_payload }
              }
            }
          }
        }
        body[:interactive][:header] = { type: 'text', text: header_text } if header_text
        body[:interactive][:footer] = { text: footer_text } if footer_text

        response = HTTParty.post(
          "#{send(:phone_id_path)}/messages",
          headers: api_headers,
          body: body.to_json
        )
        raise "send_flow failed: #{response.body}" unless response.success?

        response.parsed_response
      end
    end
  end

  Whatsapp::Providers::WhatsappCloudService.prepend(::WabaPro::CloudServiceFlowSender)

  # ----- Mountar endpoint encrypted -----
  Rails.application.routes.prepend do
    post '/webhooks/whatsapp_flow/:channel_id', to: 'waba_pro/flows_webhook#receive', as: :waba_pro_flow_webhook
  end

  # ----- Controller -----
  unless defined?(::WabaPro::FlowsWebhookController)
    require 'action_controller'

    class ::WabaPro::FlowsWebhookController < ActionController::API
      def receive
        channel = Channel::Whatsapp.find_by(id: params[:channel_id])
        return head :not_found unless channel

        priv = channel.provider_config.dig('flows_encryption', 'private_key_pem')
        return head :precondition_failed if priv.blank?

        body = JSON.parse(request.raw_post)
        decrypted = ::WabaPro::FlowEncryption.decrypt(
          private_key_pem: priv,
          encrypted_aes_key_b64: body['encrypted_aes_key'],
          encrypted_flow_data_b64: body['encrypted_flow_data'],
          iv_b64: body['initial_vector']
        )

        payload = decrypted[:payload]
        flow_id = payload['flow_token'] || payload['flow_id'] || 'default'
        response_payload = ::WabaPro::FlowsRouter.dispatch(channel: channel, flow_id: flow_id, payload: payload)

        encrypted = ::WabaPro::FlowEncryption.encrypt_response(
          aes_key: decrypted[:aes_key],
          iv: decrypted[:iv],
          response_payload: response_payload
        )
        render plain: encrypted, content_type: 'text/plain'
      rescue OpenSSL::PKey::RSAError, OpenSSL::Cipher::CipherError => e
        Rails.logger.warn "[WABA-PRO][Flow] decrypt error: #{e.message}"
        head :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error "[WABA-PRO][Flow] error: #{e.class} #{e.message}"
        head :internal_server_error
      end
    end
  end

  Rails.application.reload_routes! if Rails.application.routes_reloader
  Rails.logger.info('[WABA-PRO] Flows v7 patch loaded (encryption + endpoint + sender)')
end
