# frozen_string_literal: true
#
# WABA-PRO Phase 2: Quality monitor + campaign lockdown.
#
# - Listens to all WABA webhook fields (Phase 1 expanded subscription) and:
#     1. Updates Channel::Whatsapp.provider_config with current quality / tier / status
#     2. Appends a bounded event history (last 50) for the health dashboard
#     3. Triggers campaign-only lockdown when a downgrade is detected
#
# - Lockdown SCOPE: ONLY WhatsApp campaigns of the affected channel.
#   Conversations, single template sends, free-form messages — everything else
#   keeps working normally. This is the user's explicit decision.
#
# - Unlock: manual (Rails console / future UI) or automatic when phone quality
#   is back to GREEN AND no template is currently PAUSED/DISABLED for that channel.

Rails.application.config.after_initialize do
  next unless defined?(Webhooks::WhatsappEventsJob)
  next unless defined?(Channel::Whatsapp)
  next unless defined?(Campaign)

  # ---------------------------------------------------------------------------
  # Service: applies lockdown to all whatsapp campaigns of a channel
  # ---------------------------------------------------------------------------
  module ::WabaPro
    class CampaignLockdownService
      MAX_EVENTS = 50

      def initialize(channel)
        @channel = channel
      end

      # Apply lockdown: disable all enabled WhatsApp campaigns of this channel's inbox.
      def lock!(reason:, severity: 'high', source_event: nil)
        scope = active_campaigns_scope
        return 0 if scope.empty?

        affected = 0
        scope.find_each do |campaign|
          rules = (campaign.trigger_rules || {}).dup
          # Skip if already locked by us (idempotent)
          next if rules['paused_by_lockdown'] == true

          rules['paused_by_lockdown'] = true
          rules['lockdown_reason'] = reason
          rules['lockdown_at'] = Time.current.iso8601
          rules['lockdown_severity'] = severity
          rules['previous_enabled'] = campaign.enabled

          campaign.update_columns(
            enabled: false,
            trigger_rules: rules,
            updated_at: Time.current
          )
          affected += 1
        end

        update_channel_lockdown_state!(reason, severity, source_event, affected)
        notify_admins(reason, severity, affected)
        Rails.logger.warn("[WABA-PRO][Lockdown] Channel ##{@channel.id} (#{@channel.phone_number}) " \
                         "locked #{affected} campaigns. Reason: #{reason}")
        affected
      end

      # Release lockdown: re-enable any campaign we paused.
      def unlock!(reason: 'manual', source_event: nil)
        scope = paused_by_lockdown_scope
        affected = 0
        scope.find_each do |campaign|
          rules = (campaign.trigger_rules || {}).dup
          previous_enabled = rules.delete('previous_enabled')
          rules.delete('paused_by_lockdown')
          rules.delete('lockdown_reason')
          rules.delete('lockdown_at')
          rules.delete('lockdown_severity')

          campaign.update_columns(
            enabled: previous_enabled.nil? ? true : previous_enabled,
            trigger_rules: rules,
            updated_at: Time.current
          )
          affected += 1
        end

        clear_channel_lockdown_state!(reason, source_event, affected)
        Rails.logger.info("[WABA-PRO][Lockdown] Channel ##{@channel.id} (#{@channel.phone_number}) " \
                         "unlocked #{affected} campaigns. Reason: #{reason}")
        affected
      end

      def locked?
        @channel.provider_config['campaigns_locked_at'].present?
      end

      private

      def active_campaigns_scope
        return Campaign.none unless @channel.inbox

        Campaign.where(inbox_id: @channel.inbox.id, enabled: true)
                .where.not(campaign_status: Campaign.campaign_statuses[:completed])
      end

      def paused_by_lockdown_scope
        return Campaign.none unless @channel.inbox

        Campaign.where(inbox_id: @channel.inbox.id)
                .where("trigger_rules->>'paused_by_lockdown' = 'true'")
      end

      def update_channel_lockdown_state!(reason, severity, source_event, affected)
        cfg = @channel.provider_config.dup
        cfg['campaigns_locked_at'] = Time.current.iso8601
        cfg['campaigns_lock_reason'] = reason
        cfg['campaigns_lock_severity'] = severity
        cfg['campaigns_lock_source'] = source_event&.slice('field', 'event_type', 'rating', 'value')
        cfg['campaigns_lock_affected_count'] = affected
        @channel.update_column(:provider_config, cfg)
      end

      def clear_channel_lockdown_state!(reason, source_event, affected)
        cfg = @channel.provider_config.dup
        cfg['campaigns_locked_at'] = nil
        cfg['campaigns_lock_reason'] = nil
        cfg['campaigns_lock_severity'] = nil
        cfg['campaigns_lock_source'] = nil
        cfg['campaigns_lock_affected_count'] = nil
        cfg['campaigns_last_unlock_at'] = Time.current.iso8601
        cfg['campaigns_last_unlock_reason'] = reason
        @channel.update_column(:provider_config, cfg)
      end

      def notify_admins(reason, severity, affected)
        return unless @channel.account.respond_to?(:administrators)

        title = "WhatsApp #{@channel.phone_number}: campanhas pausadas (#{severity})"
        body = "Motivo: #{reason}. Campanhas afetadas: #{affected}."
        @channel.account.administrators.find_each do |admin|
          # Best-effort: use Notification if available, otherwise log only.
          if defined?(Notification)
            Notification.create!(
              account: @channel.account,
              user: admin,
              notification_type: 'system',
              primary_actor: @channel,
              push_message_title: title,
              meta: { description: body }
            )
          end
        rescue StandardError => e
          Rails.logger.warn("[WABA-PRO][Lockdown] Notify admin ##{admin.id} failed: #{e.message}")
        end
      end
    end

    # -------------------------------------------------------------------------
    # Service: processes a single webhook change and reacts
    # -------------------------------------------------------------------------
    class QualityMonitorService
      DOWNGRADE_QUALITIES = %w[YELLOW RED].freeze
      DOWNGRADE_TEMPLATE_STATUSES = %w[PAUSED DISABLED REJECTED].freeze
      LOW_TEMPLATE_QUALITY = %w[LOW].freeze
      MAX_EVENTS = 50

      def initialize(params)
        @params = params || {}
      end

      def perform
        entries = Array(@params[:entry] || @params['entry'])
        entries.each do |entry|
          changes = Array(entry[:changes] || entry['changes'])
          changes.each { |change| handle_change(change, entry) }
        end
      rescue StandardError => e
        Rails.logger.error("[WABA-PRO][QualityMonitor] error: #{e.class}: #{e.message}")
      end

      private

      def handle_change(change, entry)
        field = change[:field] || change['field']
        value = change[:value] || change['value'] || {}
        return if field.blank?

        # Skip messaging fields (handled by IncomingMessage* services)
        return if %w[messages smb_message_echoes message_echoes].include?(field)

        waba_id = entry[:id] || entry['id']
        channel = find_channel(waba_id, value)
        return if channel.nil?

        record_event!(channel, field, value)
        dispatch(channel, field, value)
      end

      def find_channel(waba_id, value)
        # Try by phone_number_id first (more specific), then by waba_id
        phone_id = value[:phone_number_id] || value['phone_number_id'] ||
                   value.dig(:metadata, :phone_number_id) || value.dig('metadata', 'phone_number_id')
        if phone_id.present?
          c = Channel::Whatsapp.where("provider_config->>'phone_number_id' = ?", phone_id.to_s).first
          return c if c
        end
        if waba_id.present?
          c = Channel::Whatsapp.where("provider_config->>'business_account_id' = ?", waba_id.to_s).first
          return c if c
        end
        nil
      end

      def record_event!(channel, field, value)
        cfg = channel.provider_config.dup
        events = (cfg['quality_events'] || [])
        events.unshift({
          'at' => Time.current.iso8601,
          'field' => field,
          'value' => value.to_h.deep_stringify_keys
        })
        cfg['quality_events'] = events.first(MAX_EVENTS)
        channel.update_column(:provider_config, cfg)
      end

      def dispatch(channel, field, value)
        case field
        when 'phone_number_quality_update'
          handle_phone_quality(channel, value)
        when 'message_template_quality_update'
          handle_template_quality(channel, value)
        when 'message_template_status_update'
          handle_template_status(channel, value)
        when 'template_category_update'
          handle_template_category(channel, value)
        when 'phone_number_name_update'
          handle_phone_name(channel, value)
        when 'business_capability_update', 'account_alerts', 'account_review_update', 'account_update'
          handle_account_event(channel, field, value)
        when 'security'
          handle_security(channel, value)
        else
          # Unknown / not yet handled — just store the event
        end
      end

      def handle_phone_quality(channel, value)
        rating = (value[:current_limit] || value['current_limit'] ||
                  value[:event] || value['event'] ||
                  value[:current_quality] || value['current_quality']).to_s.upcase
        # Some payloads use 'current_quality_score'
        rating = (value[:current_quality_score] || value['current_quality_score']).to_s.upcase if rating.blank?

        update_channel_field(channel, 'quality_rating', rating) if rating.present?

        if DOWNGRADE_QUALITIES.include?(rating)
          CampaignLockdownService.new(channel).lock!(
            reason: "Phone quality downgraded to #{rating}",
            severity: rating == 'RED' ? 'critical' : 'high',
            source_event: { 'field' => 'phone_number_quality_update', 'rating' => rating }
          )
        elsif rating == 'GREEN'
          maybe_auto_unlock(channel, "Phone quality recovered to GREEN")
        end
      end

      def handle_template_quality(channel, value)
        new_quality = (value[:new_quality_score] || value['new_quality_score'] ||
                       value[:current_quality_score] || value['current_quality_score']).to_s.upcase
        template_name = value[:message_template_name] || value['message_template_name']

        return unless LOW_TEMPLATE_QUALITY.include?(new_quality)

        CampaignLockdownService.new(channel).lock!(
          reason: "Template '#{template_name}' quality dropped to #{new_quality}",
          severity: 'high',
          source_event: { 'field' => 'message_template_quality_update', 'template' => template_name, 'quality' => new_quality }
        )
      end

      def handle_template_status(channel, value)
        new_status = (value[:event] || value['event']).to_s.upcase
        template_name = value[:message_template_name] || value['message_template_name']
        reason = value[:reason] || value['reason']

        if DOWNGRADE_TEMPLATE_STATUSES.include?(new_status)
          CampaignLockdownService.new(channel).lock!(
            reason: "Template '#{template_name}' #{new_status}#{" (#{reason})" if reason}",
            severity: new_status == 'DISABLED' ? 'critical' : 'high',
            source_event: { 'field' => 'message_template_status_update', 'template' => template_name, 'status' => new_status }
          )
        end
      end

      def handle_template_category(channel, value)
        # Meta re-categorized a template — just record, no lockdown
        Rails.logger.info("[WABA-PRO][QualityMonitor] Template category update for channel ##{channel.id}: #{value.inspect}")
      end

      def handle_phone_name(channel, value)
        decision = (value[:decision] || value['decision']).to_s.upcase
        update_channel_field(channel, 'name_status', decision) if decision.present?
      end

      def handle_account_event(channel, field, value)
        # Lock for any account-level alert that signals enforcement / restriction
        alert_severity = (value[:alert_severity] || value['alert_severity']).to_s.upcase
        alert_status = (value[:alert_status] || value['alert_status']).to_s.upcase

        critical = %w[CRITICAL HIGH RESTRICTED].include?(alert_severity) ||
                   %w[ACTIVE].include?(alert_status) && %w[CRITICAL HIGH].include?(alert_severity)

        return unless critical

        CampaignLockdownService.new(channel).lock!(
          reason: "Account alert (#{field}): severity=#{alert_severity} status=#{alert_status}",
          severity: 'critical',
          source_event: { 'field' => field, 'alert_severity' => alert_severity, 'alert_status' => alert_status }
        )
      end

      def handle_security(channel, value)
        Rails.logger.warn("[WABA-PRO][QualityMonitor][Security] Channel ##{channel.id}: #{value.inspect}")
      end

      def update_channel_field(channel, key, value)
        cfg = channel.provider_config.dup
        cfg[key] = value
        cfg["#{key}_updated_at"] = Time.current.iso8601
        channel.update_column(:provider_config, cfg)
      end

      def maybe_auto_unlock(channel, reason)
        svc = CampaignLockdownService.new(channel)
        return unless svc.locked?

        # Only unlock if no template is currently in PAUSED/DISABLED/REJECTED state
        # We rely on recent quality_events to make that decision.
        recent_events = (channel.provider_config['quality_events'] || []).first(20)
        bad_template = recent_events.any? do |e|
          e['field'] == 'message_template_status_update' &&
            DOWNGRADE_TEMPLATE_STATUSES.include?((e.dig('value', 'event') || '').to_s.upcase) &&
            Time.parse(e['at']) > 24.hours.ago rescue false
        end
        return if bad_template

        svc.unlock!(reason: reason, source_event: { 'auto' => true })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Patch: route every WABA webhook to the QualityMonitor in addition to
  # the existing message handling.
  # ---------------------------------------------------------------------------
  module ::WabaPro
    module WhatsappEventsJobPatch
      def perform(params = {})
        # Run quality monitor first (best-effort, never raises)
        begin
          ::WabaPro::QualityMonitorService.new(params).perform
        rescue StandardError => e
          Rails.logger.error("[WABA-PRO][QualityMonitor] swallowed: #{e.message}")
        end

        super
      end
    end
  end

  Webhooks::WhatsappEventsJob.prepend(::WabaPro::WhatsappEventsJobPatch)

  # ---------------------------------------------------------------------------
  # Defense in depth: even if a campaign sneaks past lockdown (e.g. trigger
  # bypass), block its execution at the model layer.
  # ---------------------------------------------------------------------------
  module ::WabaPro
    module CampaignLockdownGuard
      def trigger!
        if (trigger_rules || {})['paused_by_lockdown'] == true
          Rails.logger.warn("[WABA-PRO][Lockdown] Skipping Campaign ##{id} — locked: #{trigger_rules['lockdown_reason']}")
          return
        end
        super
      end
    end
  end

  Campaign.prepend(::WabaPro::CampaignLockdownGuard)

  # ---------------------------------------------------------------------------
  # Convenience helpers on Channel::Whatsapp
  # ---------------------------------------------------------------------------
  module ::WabaPro
    module ChannelLockdownHelpers
      def campaigns_locked?
        provider_config['campaigns_locked_at'].present?
      end

      def lock_campaigns!(reason:, severity: 'manual')
        ::WabaPro::CampaignLockdownService.new(self).lock!(reason: reason, severity: severity)
      end

      def unlock_campaigns!(reason: 'manual')
        ::WabaPro::CampaignLockdownService.new(self).unlock!(reason: reason)
      end

      def quality_rating
        provider_config['quality_rating']
      end

      def messaging_limit_tier
        provider_config['messaging_limit_tier']
      end
    end
  end

  Channel::Whatsapp.prepend(::WabaPro::ChannelLockdownHelpers)

  Rails.logger.info('[WABA-PRO] Quality monitor + campaign lockdown patches loaded')
end
