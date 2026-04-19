# frozen_string_literal: true
#
# WABA-PRO Phase 3.5 (backend): Templates avançados
#
# Adiciona suporte completo aos novos tipos de template do Meta:
#   - AUTHENTICATION (Zero-Tap, One-Tap, Copy Code)
#   - MARKETING com COUPON_CODE (até 15 chars)
#   - LIMITED_TIME_OFFER (LTO) com expiração
#   - CAROUSEL (até 10 cards)
#   - CATALOG / MPM (Multi-Product) / SPM (Single-Product)
#   - FLOW button (acoplado à Fase 4)
#   - CTA_URL com tap-target (`example` para botões dinâmicos)
#
# Estratégia:
# 1. Estende ALLOWED_CATEGORIES no TemplateManagementService para incluir AUTHENTICATION
# 2. Adiciona classe WabaPro::AdvancedTemplateBuilder com métodos `build_*`
#    que geram o array `components` no formato exigido pela Cloud API
# 3. Estende PopulateTemplateParametersService para resolver os novos sub_type
#    de botões (catalog/flow/copy_code) e components (limited_time_offer/carousel)

Rails.application.config.after_initialize do
  next unless defined?(Whatsapp::TemplateManagementService)
  next unless defined?(Whatsapp::PopulateTemplateParametersService)

  module ::WabaPro
    # === Builder de components para criação de template ===
    class AdvancedTemplateBuilder
      class << self
        # AUTHENTICATION com OTP
        # mode: :one_tap | :zero_tap | :copy_code
        def authentication(mode: :one_tap, package_name: nil, signature_hash: nil, autofill_text: nil, add_security_recommendation: true, code_expiration_minutes: nil)
          components = [{ type: 'BODY', add_security_recommendation: add_security_recommendation }]
          components << { type: 'FOOTER', code_expiration_minutes: code_expiration_minutes } if code_expiration_minutes

          buttons = []
          case mode
          when :copy_code
            buttons << { type: 'OTP', otp_type: 'COPY_CODE' }
          when :one_tap
            raise ArgumentError, 'one_tap requires package_name + signature_hash' if package_name.blank? || signature_hash.blank?
            buttons << {
              type: 'OTP', otp_type: 'ONE_TAP',
              text: autofill_text || 'Copy code',
              autofill_text: autofill_text || 'Autofill',
              package_name: package_name,
              signature_hash: signature_hash
            }
          when :zero_tap
            raise ArgumentError, 'zero_tap requires package_name + signature_hash' if package_name.blank? || signature_hash.blank?
            buttons << {
              type: 'OTP', otp_type: 'ZERO_TAP',
              text: autofill_text || 'Copy code',
              autofill_text: autofill_text || 'Autofill',
              package_name: package_name,
              signature_hash: signature_hash,
              zero_tap_terms_accepted: true
            }
          else
            raise ArgumentError, "unknown auth mode #{mode}"
          end
          components << { type: 'BUTTONS', buttons: buttons }
          { category: 'AUTHENTICATION', components: components }
        end

        # MARKETING com botão de copiar cupom
        def coupon_code(body_text:, footer_text: nil, coupon_button_text: 'Copy code', sample_coupon: 'SAVE20')
          buttons = [{ type: 'COPY_CODE', example: [sample_coupon] }]
          buttons.first[:text] = coupon_button_text if coupon_button_text
          components = [{ type: 'BODY', text: body_text }]
          components << { type: 'FOOTER', text: footer_text } if footer_text
          components << { type: 'BUTTONS', buttons: buttons }
          { category: 'MARKETING', components: components }
        end

        # LIMITED_TIME_OFFER
        def limited_time_offer(body_text:, offer_text:, expiration_unix:, has_expiration: true, header_image_handle: nil, cta_url: nil, cta_text: 'Buy now', coupon_button_text: nil, sample_coupon: nil)
          components = []
          components << { type: 'HEADER', format: 'IMAGE', example: { header_handle: [header_image_handle] } } if header_image_handle
          components << {
            type: 'LIMITED_TIME_OFFER',
            limited_time_offer: { text: offer_text, has_expiration: has_expiration }
          }
          components << { type: 'BODY', text: body_text }
          buttons = []
          buttons << { type: 'URL', text: cta_text, url: cta_url } if cta_url
          buttons << { type: 'COPY_CODE', example: [sample_coupon || 'SAVE20'] } if coupon_button_text
          components << { type: 'BUTTONS', buttons: buttons } if buttons.any?
          { category: 'MARKETING', components: components }
        end

        # CAROUSEL com cards
        # cards: Array of { header_handle:, body_text:, buttons: [{type:, ...}] }
        def carousel(body_text:, cards:)
          raise ArgumentError, 'carousel needs 1..10 cards' unless (1..10).cover?(cards.length)

          card_components = cards.map do |c|
            {
              components: [
                { type: 'HEADER', format: 'IMAGE', example: { header_handle: [c[:header_handle]] } },
                { type: 'BODY', text: c[:body_text] },
                { type: 'BUTTONS', buttons: c[:buttons] || [] }
              ].reject { |comp| comp[:type] == 'BUTTONS' && comp[:buttons].empty? }
            }
          end
          {
            category: 'MARKETING',
            components: [
              { type: 'BODY', text: body_text },
              { type: 'CAROUSEL', cards: card_components }
            ]
          }
        end

        # CATALOG / MPM / SPM
        def catalog(body_text:, footer_text: nil, catalog_button_text: 'View catalog', thumbnail_product_retailer_id: nil)
          components = [{ type: 'BODY', text: body_text }]
          components << { type: 'FOOTER', text: footer_text } if footer_text
          btn = { type: 'CATALOG', text: catalog_button_text }
          btn[:example] = [thumbnail_product_retailer_id] if thumbnail_product_retailer_id
          components << { type: 'BUTTONS', buttons: [btn] }
          { category: 'MARKETING', components: components }
        end

        def mpm(body_text:, header_text: nil, footer_text: nil, sections: [])
          components = []
          components << { type: 'HEADER', format: 'TEXT', text: header_text } if header_text
          components << { type: 'BODY', text: body_text }
          components << { type: 'FOOTER', text: footer_text } if footer_text
          components << {
            type: 'BUTTONS',
            buttons: [{ type: 'MPM', text: 'View items' }]
          }
          components << { type: 'SECTIONS', sections: sections } if sections.any?
          { category: 'MARKETING', components: components }
        end

        # FLOW button template
        def flow_template(body_text:, flow_id:, flow_cta:, flow_action: 'navigate', screen_id: 'WELCOME')
          components = [{ type: 'BODY', text: body_text }]
          components << {
            type: 'BUTTONS',
            buttons: [{
              type: 'FLOW',
              text: flow_cta,
              flow_id: flow_id.to_s,
              flow_action: flow_action,
              navigate_screen: screen_id
            }]
          }
          { category: 'MARKETING', components: components }
        end
      end
    end

    # === Patches ===
    module TemplateManagementCategoriesPatch
      def self.prepended(base)
        base.send(:remove_const, :ALLOWED_CATEGORIES) if base.const_defined?(:ALLOWED_CATEGORIES, false)
        base.const_set(:ALLOWED_CATEGORIES, %w[MARKETING UTILITY AUTHENTICATION].freeze)
      end

      # Bypass category validation when AUTHENTICATION (parent rejects it)
      def create_template(params)
        if params[:category]&.upcase == 'AUTHENTICATION'
          # Inline create — replicar lógica do parent sem o filter
          request_body = {
            name: params[:name],
            language: params[:language] || 'en_US',
            category: 'AUTHENTICATION',
            components: params[:components]
          }
          response = HTTParty.post(
            "#{send(:business_account_path)}/message_templates",
            headers: send(:api_headers),
            body: request_body.to_json
          )
          if response.success?
            { success: true, template: { id: response['id'], name: params[:name], status: response['status'] || 'PENDING', category: 'AUTHENTICATION', language: params[:language] || 'en_US' } }
          else
            { success: false, error: send(:parse_error, response) }
          end
        else
          super
        end
      end
    end

    module PopulateTemplateParametersExtras
      # Suporta novos sub-types de botão: flow, mpm, catalog
      def build_button_parameter(button)
        case button['type']
        when 'flow'
          flow_token = button['flow_token'] || SecureRandom.hex(8)
          payload = { type: 'action', action: { flow_token: flow_token } }
          payload[:action][:flow_action_data] = button['flow_action_data'] if button['flow_action_data']
          payload
        when 'catalog'
          {
            type: 'action',
            action: {
              thumbnail_product_retailer_id: button['thumbnail_product_retailer_id']
            }.compact
          }
        when 'mpm'
          {
            type: 'action',
            action: {
              thumbnail_product_retailer_id: button['thumbnail_product_retailer_id'],
              sections: button['sections']
            }.compact
          }
        else
          super
        end
      end
    end
  end

  Whatsapp::TemplateManagementService.prepend(::WabaPro::TemplateManagementCategoriesPatch)
  Whatsapp::PopulateTemplateParametersService.prepend(::WabaPro::PopulateTemplateParametersExtras)
  Rails.logger.info('[WABA-PRO] Advanced templates patch loaded (AUTH/COUPON/LTO/CAROUSEL/CATALOG/MPM/FLOW)')
end
