# Final unlock: force all enterprise features
Rails.application.config.after_initialize do
  Account.class_eval do
    define_method(:enabled_features) do
      %w[
        advanced_search
        advanced_search_indexing
        agent_bots
        agent_management
        assignment_v2
        audit_logs
        auto_resolve_conversations
        automations
        campaigns
        canned_responses
        captain
        captain_v2
        channel_email
        channel_facebook
        channel_instagram
        channel_twitter
        channel_voice
        channel_website
        chatwoot_v4
        contact_chatwoot_support_team
        crm
        crm_integration
        crm_v2
        custom_attributes
        custom_reply_domain
        custom_reply_email
        custom_roles
        disable_branding
        email_continuity_on_api_channel
        help_center
        help_center_embedding_search
        inbound_emails
        inbox_management
        inbox_view
        integrations
        ip_lookup
        labels
        linear_integration
        macros
        notion_integration
        quoted_email_reply
        reports
        saml
        search_with_gin
        shopify_integration
        sla
        team_management
        voice_recorder
        whatsapp_campaign
      ].index_with { true }
    end

    define_method(:feature_enabled?) do |name|
      true
    end
  end

  Rails.logger.info '✅ ZZ_FINAL_UNLOCK: enabled_features patch aplicado via after_initialize'
end
