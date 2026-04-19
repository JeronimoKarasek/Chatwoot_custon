# frozen_string_literal: true
#
# WABA-PRO Phase 1: Persists richer WABA metadata in provider_config.
#
# Adds the following keys to Channel::Whatsapp.provider_config:
#   - app_id              : Meta App that onboarded this number
#   - signup_mode         : 'cloud' | 'coex'
#   - signup_version      : '3' (Embedded Signup version used)
#   - signup_feature_type : raw extras.featureType passed to FB.login (or nil)
#   - business_id         : Meta Business Manager id
#   - waba_currency       : ISO currency code returned by /WABA fields
#   - timezone_id         : numeric timezone id (Meta format)
#   - waba_name           : human-friendly WABA name
#   - waba_review_status  : account_review_status
#   - business_verification_status
#   - waba_country        : ISO country code
#   - onboarded_at        : timestamp ISO8601
#
# Backward-compatible: only adds keys; never removes existing ones.

Rails.application.config.after_initialize do
  next unless defined?(Whatsapp::ChannelCreationService)

  module ::WabaPro
    module ChannelCreationV3
      private

      def build_provider_config
        base = super
        details = (@waba_info[:details] || {})
        base.merge(
          'app_id' => GlobalConfigService.load('WHATSAPP_APP_ID', nil),
          'signup_mode' => @waba_info[:signup_mode] || 'cloud',
          'signup_version' => @waba_info[:signup_version] || '3',
          'signup_feature_type' => @waba_info[:signup_feature_type],
          'business_id' => @waba_info[:business_id],
          'waba_currency' => details['currency'],
          'timezone_id' => details['timezone_id'],
          'waba_name' => details['name'],
          'waba_review_status' => details['account_review_status'],
          'business_verification_status' => details['business_verification_status'],
          'waba_country' => details['country'],
          'onboarded_at' => Time.zone.now.iso8601,
          # Phase 2 (Quality Lockdown) initial state — populated by webhooks later
          'quality_rating' => nil,
          'messaging_limit_tier' => nil,
          'coex_status' => @waba_info[:signup_mode] == 'coex' ? 'active' : 'none',
          # Phase 2 lockdown flags (campaigns-only, not message blocking)
          'campaigns_locked_at' => nil,
          'campaigns_lock_reason' => nil
        ).compact
      end
    end
  end

  Whatsapp::ChannelCreationService.prepend(::WabaPro::ChannelCreationV3)
  Rails.logger.info('[WABA-PRO] ChannelCreationService prepended with v3 metadata patch')
end
