# frozen_string_literal: true
#
# WABA-PRO Phase 1: Embedded Signup v3 + Coexistence support.
#
# Adds support for `signup_mode` parameter:
#   - 'cloud'  : standard Cloud API onboarding (default, existing behavior)
#   - 'coex'   : Coexistence (WhatsApp Business App + Cloud API on same number)
#
# Persists richer metadata in provider_config (waba currency, timezone,
# signup version, app_id, coex status, etc) so Phase 2/3 dashboards can read it.
#
# Backward-compatible: existing callers that don't pass signup_mode keep working.

Rails.application.config.after_initialize do
  next unless defined?(Whatsapp::EmbeddedSignupService)

  module ::WabaPro
    module EmbeddedSignupV3
      def initialize(account:, params:, inbox_id: nil)
        super
        @signup_mode = (params[:signup_mode].presence || 'cloud').to_s
        @signup_feature_type = params[:feature_type].presence ||
                               (@signup_mode == 'coex' ? 'whatsapp_business_app_onboarding' : nil)
        Rails.logger.info("[WABA-PRO][EmbeddedSignup] mode=#{@signup_mode} feature_type=#{@signup_feature_type.inspect}")
      end

      def perform
        validate_parameters!

        access_token = exchange_code_for_token
        phone_info = fetch_phone_info(access_token)
        validate_token_access(access_token)
        waba_details = fetch_waba_details(access_token)

        channel = create_or_reauthorize_channel(access_token, phone_info, waba_details)
        channel.setup_webhooks
        check_channel_health_and_prompt_reauth(channel)
        channel
      rescue StandardError => e
        Rails.logger.error("[WABA-PRO][EmbeddedSignup] failed mode=#{@signup_mode}: #{e.message}")
        raise e
      end

      private

      def fetch_waba_details(access_token)
        Whatsapp::FacebookApiClient.new(access_token).fetch_waba_details(@waba_id)
      rescue StandardError => e
        Rails.logger.warn("[WABA-PRO][EmbeddedSignup] WABA details fetch failed (continuing): #{e.message}")
        {}
      end

      # Override to thread waba_details + signup_mode into ChannelCreationService.
      def create_or_reauthorize_channel(access_token, phone_info, waba_details = {})
        if @inbox_id.present?
          Whatsapp::ReauthorizationService.new(
            account: @account,
            inbox_id: @inbox_id,
            phone_number_id: @phone_number_id,
            business_id: @business_id
          ).perform(access_token, phone_info)
        else
          waba_info = {
            waba_id: @waba_id,
            business_name: phone_info[:business_name],
            business_id: @business_id,
            details: waba_details,
            signup_mode: @signup_mode,
            signup_feature_type: @signup_feature_type,
            signup_version: '3'
          }
          Whatsapp::ChannelCreationService.new(@account, waba_info, phone_info, access_token).perform
        end
      end
    end
  end

  Whatsapp::EmbeddedSignupService.prepend(::WabaPro::EmbeddedSignupV3)
  Rails.logger.info('[WABA-PRO] EmbeddedSignupService prepended with v3+Coex patch')
end
