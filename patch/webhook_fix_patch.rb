# Patch: Fix WebhookJob keyword arguments incompatibility with Ruby 3.4 + Rails 7.1
# Ruby 3.4 strict keyword arg handling breaks ActiveJob deserialization of keyword args
# Solution: Wrap in after_initialize and change keyword args to options hash

Rails.application.config.after_initialize do
  # ============================================================
  # 1. Fix WebhookJob#perform - use options hash instead of kwargs
  # ============================================================
  WebhookJob.class_eval do
    def perform(url, payload, webhook_type = :account_webhook, options = {})
      options = options.symbolize_keys if options.is_a?(Hash)
      secret = options[:secret]
      delivery_id = options[:delivery_id]
      Webhooks::Trigger.execute(url, payload, webhook_type, secret: secret, delivery_id: delivery_id)
    end
  end

  # ============================================================
  # 2. Fix AgentBots::WebhookJob#perform
  # ============================================================
  AgentBots::WebhookJob.class_eval do
    retry_on RestClient::TooManyRequests, RestClient::InternalServerError, wait: 3.seconds, attempts: 3 do |job, error|
      url, payload, webhook_type, opts = job.arguments
      opts = (opts || {}).symbolize_keys
      Webhooks::Trigger.new(
        url, payload, webhook_type || :agent_bot_webhook,
        secret: opts[:secret], delivery_id: opts[:delivery_id]
      ).handle_failure(error)
    end

    def perform(url, payload, webhook_type = :agent_bot_webhook, options = {})
      options = options.symbolize_keys if options.is_a?(Hash)
      secret = options[:secret]
      delivery_id = options[:delivery_id]
      Webhooks::Trigger.execute(url, payload, webhook_type, secret: secret, delivery_id: delivery_id)
    rescue RestClient::TooManyRequests, RestClient::InternalServerError => e
      Rails.logger.warn("[AgentBots::WebhookJob] attempt #{executions} failed #{e.class.name}")
      raise
    end
  end

  # ============================================================
  # 3. Fix WebhookListener - pass options hash instead of kwargs
  # ============================================================
  WebhookListener.class_eval do
    private

    def deliver_account_webhooks(payload, account)
      account.webhooks.account_type.each do |webhook|
        next unless webhook.subscriptions.include?(payload[:event])

        WebhookJob.perform_later(webhook.url, payload, :account_webhook,
                                 { secret: webhook.secret, delivery_id: SecureRandom.uuid })
      end
    end

    def deliver_api_inbox_webhooks(payload, inbox)
      return unless inbox.channel_type == 'Channel::Api'
      return if inbox.channel.webhook_url.blank?

      WebhookJob.perform_later(inbox.channel.webhook_url, payload, :api_inbox_webhook,
                               { secret: inbox.channel.secret, delivery_id: SecureRandom.uuid })
    end
  end

  # ============================================================
  # 4. Fix AgentBotListener - pass options hash instead of kwargs
  # ============================================================
  AgentBotListener.class_eval do
    private

    def process_webhook_bot_event(agent_bot, payload)
      return if agent_bot.outgoing_url.blank?

      AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload, :agent_bot_webhook,
                                          { secret: agent_bot.secret, delivery_id: SecureRandom.uuid })
    end
  end

  Rails.logger.info "[FarolChat] webhook_fix_patch loaded: WebhookJob keyword args fix for Ruby #{RUBY_VERSION}"
end
