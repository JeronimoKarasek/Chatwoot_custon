# frozen_string_literal: true
#
# WABA-PRO Phase 1: Bumps WhatsApp Graph API to v25.0 and expands the
# webhook subscription to ALL quality/lifecycle fields needed by the
# Quality Lockdown (Phase 2). Also adds helper methods used by later phases.
#
# Idempotent monkey-patch over Whatsapp::FacebookApiClient.
# Safe: defaults stay backward-compatible; only the API version default and
# the subscribed_fields list change observably.

Rails.application.config.after_initialize do
  next unless defined?(Whatsapp::FacebookApiClient)

  module ::WabaPro
    module FacebookApiClientV25
      # All WhatsApp Business Account webhook fields we want to receive.
      # Source: developers.facebook.com/docs/graph-api/webhooks/reference/whatsapp-business-account
      WABA_SUBSCRIBED_FIELDS = %w[
        messages
        message_template_status_update
        message_template_quality_update
        message_template_components_update
        template_category_update
        phone_number_quality_update
        phone_number_name_update
        account_alerts
        account_review_update
        account_update
        business_capability_update
        security
        smb_message_echoes
        smb_app_state_sync
        user_preferences
        history
        automatic_events
        calls
      ].freeze

      def initialize(access_token = nil)
        @access_token = access_token
        @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v25.0')
      end

      # Override: subscribe with the full field set instead of just messages.
      def override_waba_callback(waba_id, callback_url, verify_token)
        response = HTTParty.post(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
          headers: __waba_request_headers,
          body: {
            override_callback_uri: callback_url,
            verify_token: verify_token,
            subscribed_fields: WABA_SUBSCRIBED_FIELDS
          }.to_json
        )

        __waba_handle_response(response, 'Webhook callback override failed')
      end

      # NEW: Fetch WABA details (currency, timezone, name, status, etc).
      def fetch_waba_details(waba_id)
        response = HTTParty.get(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{waba_id}",
          query: {
            fields: 'id,name,currency,timezone_id,message_template_namespace,' \
                    'on_behalf_of_business_info,account_review_status,business_verification_status,' \
                    'country,ownership_type,primary_funding_id,is_enabled_for_insights',
            access_token: @access_token
          }
        )
        __waba_handle_response(response, 'WABA details fetch failed')
      end

      # NEW: Fetch a phone number's full details (quality, throughput, name status).
      def fetch_phone_number_details(phone_number_id)
        response = HTTParty.get(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{phone_number_id}",
          query: {
            fields: 'id,display_phone_number,verified_name,name_status,quality_rating,' \
                    'platform_type,throughput,messaging_limit_tier,code_verification_status,' \
                    'is_official_business_account,is_pin_enabled,status',
            access_token: @access_token
          }
        )
        __waba_handle_response(response, 'Phone number details fetch failed')
      end

      # NEW: Read business profile (about/description/email/websites/etc).
      def fetch_business_profile(phone_number_id)
        response = HTTParty.get(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{phone_number_id}/whatsapp_business_profile",
          query: {
            fields: 'about,address,description,email,profile_picture_url,websites,vertical',
            access_token: @access_token
          }
        )
        __waba_handle_response(response, 'Business profile fetch failed')
      end

      # NEW: Two-step verification (lock pin against the number).
      def set_two_step_verification(phone_number_id, pin)
        response = HTTParty.post(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{phone_number_id}",
          headers: __waba_request_headers,
          body: { pin: pin.to_s }.to_json
        )
        __waba_handle_response(response, 'Two-step verification setup failed')
      end

      # NEW: Block / unblock users (Block Users API, 2024-01).
      def block_users(phone_number_id, wa_ids)
        users = Array(wa_ids).map { |id| { user: id.to_s } }
        response = HTTParty.post(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{phone_number_id}/block_users",
          headers: __waba_request_headers,
          body: { messaging_product: 'whatsapp', block_users: users }.to_json
        )
        __waba_handle_response(response, 'Block users failed')
      end

      def unblock_users(phone_number_id, wa_ids)
        users = Array(wa_ids).map { |id| { user: id.to_s } }
        response = HTTParty.delete(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{phone_number_id}/block_users",
          headers: __waba_request_headers,
          body: { messaging_product: 'whatsapp', block_users: users }.to_json
        )
        __waba_handle_response(response, 'Unblock users failed')
      end

      # NEW: Typing indicator (2025-04).
      def send_typing_indicator(phone_number_id, message_id)
        response = HTTParty.post(
          "#{::Whatsapp::FacebookApiClient::BASE_URI}/#{@api_version}/#{phone_number_id}/messages",
          headers: __waba_request_headers,
          body: {
            messaging_product: 'whatsapp',
            status: 'read',
            message_id: message_id.to_s,
            typing_indicator: { type: 'text' }
          }.to_json
        )
        __waba_handle_response(response, 'Typing indicator failed')
      end

      private

      def __waba_request_headers
        {
          'Authorization' => "Bearer #{@access_token}",
          'Content-Type' => 'application/json'
        }
      end

      def __waba_handle_response(response, error_message)
        raise "#{error_message}: #{response.body}" unless response.success?

        response.parsed_response
      end
    end
  end

  Whatsapp::FacebookApiClient.prepend(::WabaPro::FacebookApiClientV25)
  Rails.logger.info('[WABA-PRO] FacebookApiClient prepended with v25 patch')
end
