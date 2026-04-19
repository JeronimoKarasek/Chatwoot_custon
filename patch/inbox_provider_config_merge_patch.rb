# Patch: Merge provider_config on update instead of replacing it
# When the frontend sends a partial provider_config (e.g., only api_key),
# this patch merges the sent keys with the existing provider_config,
# preventing loss of keys like phone_number_id, webhook_verify_token, etc.
#
# Also re-registers the webhook with Facebook when credential keys
# (api_key, business_account_id, phone_number_id) are changed,
# since the default after_commit :setup_webhooks only fires on :create.
#
# Skips validate_provider_config during reauthorization updates so that
# credential fields can be changed without the Facebook API validation
# blocking partial updates (e.g., changing WABA ID before updating API key).

Rails.application.config.after_initialize do
  # Add skip flag to Channel::Whatsapp so we can bypass validate_provider_config
  Channel::Whatsapp.class_eval do
    attr_accessor :skip_provider_config_validation

    # Wrap original validation to respect skip flag
    alias_method :original_validate_provider_config, :validate_provider_config

    def validate_provider_config
      return if skip_provider_config_validation

      original_validate_provider_config
    end
  end

  Api::V1::Accounts::InboxesController.class_eval do
    private

    # Keys that require webhook re-registration when changed
    WEBHOOK_TRIGGER_KEYS = %w[api_key business_account_id phone_number_id].freeze

    # Override reauthorize_and_update_channel to merge provider_config
    def reauthorize_and_update_channel(channel_attributes)
      @inbox.channel.reauthorized! if @inbox.channel.respond_to?(:reauthorized!)

      channel_params = permitted_params(channel_attributes)[:channel]
      return @inbox.channel.update!(channel_params) unless channel_params&.key?(:provider_config)

      # Merge sent provider_config with existing, so partial updates work
      existing_config = @inbox.channel.try(:provider_config) || {}
      sent_config = channel_params[:provider_config].to_h
      merged_config = existing_config.merge(sent_config)

      # Detect if credential keys changed (need webhook re-registration)
      credentials_changed = WEBHOOK_TRIGGER_KEYS.any? do |key|
        sent_config.key?(key) && sent_config[key].present? && sent_config[key] != existing_config[key]
      end

      # Skip Facebook API validation during reauthorization (credentials may be
      # updated partially and the intermediate combination could fail validation)
      @inbox.channel.skip_provider_config_validation = true

      merged_params = channel_params.to_h.merge('provider_config' => merged_config)
      @inbox.channel.update!(merged_params)

      # Re-register webhook with Facebook when credentials change
      if credentials_changed && @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'
        Rails.logger.info "InboxProviderConfigMergePatch: Credentials changed for inbox #{@inbox.id}, re-registering webhook..."
        begin
          @inbox.channel.setup_webhooks
          Rails.logger.info "InboxProviderConfigMergePatch: Webhook re-registered successfully for inbox #{@inbox.id}"
        rescue StandardError => e
          Rails.logger.error "InboxProviderConfigMergePatch: Webhook re-registration failed for inbox #{@inbox.id}: #{e.message}"
        end
      end
    ensure
      @inbox.channel.skip_provider_config_validation = false if @inbox&.channel
    end
  end

  Rails.logger.info 'InboxProviderConfigMergePatch: Loaded — provider_config merge on update + webhook re-registration + skip validation active'
end
