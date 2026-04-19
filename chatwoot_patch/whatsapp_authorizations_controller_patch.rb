# frozen_string_literal: true
#
# WABA-PRO Phase 1: Allow signup_mode + feature_type on the embedded signup endpoint.
#
# The upstream controller restricts permitted params to code/business_id/waba_id/phone_number_id.
# We extend it to also pass through signup_mode ('cloud'|'coex') and feature_type so
# Whatsapp::EmbeddedSignupService can branch its behaviour.

Rails.application.config.after_initialize do
  next unless defined?(Api::V1::Accounts::Whatsapp::AuthorizationsController)

  module ::WabaPro
    module EmbeddedSignupController
      private

      def process_embedded_signup
        service = Whatsapp::EmbeddedSignupService.new(
          account: Current.account,
          params: params.permit(:code, :business_id, :waba_id, :phone_number_id,
                                :signup_mode, :feature_type).to_h.symbolize_keys,
          inbox_id: params[:inbox_id]
        )
        service.perform
      end
    end
  end

  Api::V1::Accounts::Whatsapp::AuthorizationsController.prepend(::WabaPro::EmbeddedSignupController)
  Rails.logger.info('[WABA-PRO] AuthorizationsController prepended (signup_mode/feature_type allowed)')
end
