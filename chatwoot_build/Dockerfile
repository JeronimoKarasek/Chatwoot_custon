# ================================================
# FarolChat Custom Chatwoot Build
# - WABA ID / Phone Number ID update fields
# - Native billing page with quantity management
# - Suspended account payment button
# - Native inline contact creation in compose modal
# - WhatsApp Template Management (create/edit/delete/duplicate)
# ================================================

FROM chatwoot/chatwoot:v4.12.1 AS builder

USER root

# Link npm binary (exists in node_modules but not in PATH)
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Install pnpm via npm
RUN npm install -g pnpm@10.2.0

# Install node dependencies (needed for Vite build)
WORKDIR /app
RUN pnpm install --frozen-lockfile --ignore-scripts 2>/dev/null || pnpm install --no-frozen-lockfile --ignore-scripts

# === Copy modified Vue source files ===

# WhatsApp Cloud WABA/Phone fields
COPY ConfigurationPage.vue /app/app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/ConfigurationPage.vue

# WABA-PRO: Embedded Signup with Coex/Cloud mode selector (frontend)
COPY whatsapp_signup_utils.js /app/app/javascript/dashboard/routes/dashboard/settings/inbox/channels/whatsapp/utils.js
COPY WhatsappEmbeddedSignup.vue /app/app/javascript/dashboard/routes/dashboard/settings/inbox/channels/WhatsappEmbeddedSignup.vue

# Native billing page
COPY billing_Index.vue /app/app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue
COPY billing_routes.js /app/app/javascript/dashboard/routes/dashboard/settings/billing/billing.routes.js

# Suspended account page with payment button
COPY suspended_Index.vue /app/app/javascript/dashboard/routes/dashboard/suspended/Index.vue

# Native inline contact creation in compose modal
COPY ContactSelector.vue /app/app/javascript/dashboard/components-next/NewConversation/components/ContactSelector.vue
COPY ComposeConversation.vue /app/app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue
COPY composeConversationHelper.js /app/app/javascript/dashboard/components-next/NewConversation/helpers/composeConversationHelper.js

# Mass sending campaign system
COPY WhatsAppCampaignForm.vue /app/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignForm.vue
COPY WhatsAppCampaignDialog.vue /app/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignDialog.vue
COPY WhatsAppCampaignReportDialog.vue /app/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignReportDialog.vue
COPY WhatsAppCampaignsPage.vue /app/app/javascript/dashboard/routes/dashboard/campaigns/pages/WhatsAppCampaignsPage.vue
COPY campaigns_api.js /app/app/javascript/dashboard/api/campaigns.js

# Personal canned responses with audio support
COPY cannedResponse.js /app/app/javascript/dashboard/api/cannedResponse.js
COPY cannedResponseStore.js /app/app/javascript/dashboard/store/modules/cannedResponse.js
COPY canned_Index.vue /app/app/javascript/dashboard/routes/dashboard/settings/canned/Index.vue
COPY canned_AddCanned.vue /app/app/javascript/dashboard/routes/dashboard/settings/canned/AddCanned.vue
COPY canned_EditCanned.vue /app/app/javascript/dashboard/routes/dashboard/settings/canned/EditCanned.vue
COPY CannedResponse_widget.vue /app/app/javascript/dashboard/components/widgets/conversation/CannedResponse.vue
COPY ReplyBox.vue /app/app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue

# WhatsApp Template Management - Vue components
COPY whatsappTemplatesApi.js /app/app/javascript/dashboard/api/whatsappTemplatesApi.js
COPY whatsappTemplatesStore.js /app/app/javascript/dashboard/store/modules/whatsappTemplates.js
COPY whatsappTemplates_routes.js /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/whatsappTemplates.routes.js
COPY whatsappTemplates_Index.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/Index.vue
COPY whatsappTemplates_TemplateStatusBadge.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/components/TemplateStatusBadge.vue
COPY whatsappTemplates_TemplatePreview.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/components/TemplatePreview.vue
COPY whatsappTemplates_TemplateFormDialog.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/components/TemplateFormDialog.vue

# WhatsApp Template Management - Patch settings routes, sidebar, store
COPY patch_settings_routes.sh /tmp/patch_settings_routes.sh
RUN chmod +x /tmp/patch_settings_routes.sh && sh /tmp/patch_settings_routes.sh

COPY patch_sidebar.sh /tmp/patch_sidebar.sh
RUN chmod +x /tmp/patch_sidebar.sh && sh /tmp/patch_sidebar.sh

COPY patch_store_index.sh /tmp/patch_store_index.sh
RUN chmod +x /tmp/patch_store_index.sh && sh /tmp/patch_store_index.sh

# === Patch translations ===

# WABA translations (inboxMgmt)
COPY patch_translations_en.sh /tmp/patch_translations_en.sh
RUN chmod +x /tmp/patch_translations_en.sh && sh /tmp/patch_translations_en.sh

COPY patch_translations_pt.sh /tmp/patch_translations_pt.sh
RUN chmod +x /tmp/patch_translations_pt.sh && sh /tmp/patch_translations_pt.sh

# Billing translations (settings)
COPY patch_billing_translations_en.sh /tmp/patch_billing_translations_en.sh
RUN chmod +x /tmp/patch_billing_translations_en.sh && sh /tmp/patch_billing_translations_en.sh

COPY patch_billing_translations_pt.sh /tmp/patch_billing_translations_pt.sh
RUN chmod +x /tmp/patch_billing_translations_pt.sh && sh /tmp/patch_billing_translations_pt.sh

# Suspended account translations
COPY patch_suspended_translations.sh /tmp/patch_suspended_translations.sh
RUN chmod +x /tmp/patch_suspended_translations.sh && sh /tmp/patch_suspended_translations.sh

# Contact creation translations (contact)
COPY patch_contact_translations_en.sh /tmp/patch_contact_translations_en.sh
RUN chmod +x /tmp/patch_contact_translations_en.sh && sh /tmp/patch_contact_translations_en.sh

COPY patch_contact_translations_pt.sh /tmp/patch_contact_translations_pt.sh
RUN chmod +x /tmp/patch_contact_translations_pt.sh && sh /tmp/patch_contact_translations_pt.sh

# Campaign mass sending translations
COPY patch_campaign_translations_en.sh /tmp/patch_campaign_translations_en.sh
RUN chmod +x /tmp/patch_campaign_translations_en.sh && sh /tmp/patch_campaign_translations_en.sh

COPY patch_campaign_translations_pt.sh /tmp/patch_campaign_translations_pt.sh
RUN chmod +x /tmp/patch_campaign_translations_pt.sh && sh /tmp/patch_campaign_translations_pt.sh

# Canned response personal + audio translations
COPY patch_canned_translations_en.sh /tmp/patch_canned_translations_en.sh
RUN chmod +x /tmp/patch_canned_translations_en.sh && sh /tmp/patch_canned_translations_en.sh

COPY patch_canned_translations_pt.sh /tmp/patch_canned_translations_pt.sh
RUN chmod +x /tmp/patch_canned_translations_pt.sh && sh /tmp/patch_canned_translations_pt.sh

# WhatsApp Template Management translations
COPY patch_whatsapp_templates_translations_en.sh /tmp/patch_whatsapp_templates_translations_en.sh
RUN chmod +x /tmp/patch_whatsapp_templates_translations_en.sh && sh /tmp/patch_whatsapp_templates_translations_en.sh

COPY patch_whatsapp_templates_translations_pt.sh /tmp/patch_whatsapp_templates_translations_pt.sh
RUN chmod +x /tmp/patch_whatsapp_templates_translations_pt.sh && sh /tmp/patch_whatsapp_templates_translations_pt.sh

# === Verify all patches before Vite build ===
RUN echo "=== Verifying patches ===" && \
    grep -q "whatsappTemplates" /app/app/javascript/dashboard/store/index.js && echo "OK: store index patched" || (echo "FAIL: store index NOT patched" && exit 1) && \
    grep -q "whatsappTemplates" /app/app/javascript/dashboard/routes/dashboard/settings/settings.routes.js && echo "OK: settings routes patched" || (echo "FAIL: settings routes NOT patched" && exit 1) && \
    grep -q "WHATSAPP_TEMPLATES" /app/app/javascript/dashboard/components-next/sidebar/Sidebar.vue && echo "OK: sidebar patched" || (echo "FAIL: sidebar NOT patched" && exit 1) && \
    test -f /app/app/javascript/dashboard/store/modules/whatsappTemplates.js && echo "OK: store module file exists" || (echo "FAIL: store module file missing" && exit 1) && \
    test -f /app/app/javascript/dashboard/api/whatsappTemplatesApi.js && echo "OK: API file exists" || (echo "FAIL: API file missing" && exit 1) && \
    echo "=== All patches verified ==="

# === Build Vite assets ===
RUN RAILS_ENV=production NODE_ENV=production bin/vite build
RUN RAILS_ENV=production NODE_ENV=production BUILD_MODE=library bin/vite build

# ================================================
# Final image: start from original, copy new assets
# ================================================
FROM chatwoot/chatwoot:v4.12.1

USER root

# Copy modified Vue source files (for reference/inspection)
COPY ConfigurationPage.vue /app/app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/ConfigurationPage.vue

# WABA-PRO: Embedded Signup with Coex/Cloud mode selector (frontend - source files)
COPY whatsapp_signup_utils.js /app/app/javascript/dashboard/routes/dashboard/settings/inbox/channels/whatsapp/utils.js
COPY WhatsappEmbeddedSignup.vue /app/app/javascript/dashboard/routes/dashboard/settings/inbox/channels/WhatsappEmbeddedSignup.vue

# WABA-PRO: Backend monkey-patches (initializers loaded at boot)
COPY whatsapp_v25_patch.rb /app/config/initializers/whatsapp_v25_patch.rb
COPY whatsapp_embedded_signup_v3_patch.rb /app/config/initializers/whatsapp_embedded_signup_v3_patch.rb
COPY whatsapp_channel_creation_v3_patch.rb /app/config/initializers/whatsapp_channel_creation_v3_patch.rb
COPY whatsapp_authorizations_controller_patch.rb /app/config/initializers/whatsapp_authorizations_controller_patch.rb
COPY whatsapp_quality_lockdown_patch.rb /app/config/initializers/whatsapp_quality_lockdown_patch.rb
COPY whatsapp_incoming_extras_patch.rb /app/config/initializers/whatsapp_incoming_extras_patch.rb
COPY whatsapp_outgoing_extras_patch.rb /app/config/initializers/whatsapp_outgoing_extras_patch.rb
COPY whatsapp_advanced_templates_patch.rb /app/config/initializers/whatsapp_advanced_templates_patch.rb
COPY whatsapp_flows_patch.rb /app/config/initializers/whatsapp_flows_patch.rb
COPY billing_Index.vue /app/app/javascript/dashboard/routes/dashboard/settings/billing/Index.vue
COPY billing_routes.js /app/app/javascript/dashboard/routes/dashboard/settings/billing/billing.routes.js
COPY suspended_Index.vue /app/app/javascript/dashboard/routes/dashboard/suspended/Index.vue
COPY ContactSelector.vue /app/app/javascript/dashboard/components-next/NewConversation/components/ContactSelector.vue
COPY ComposeConversation.vue /app/app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue
COPY composeConversationHelper.js /app/app/javascript/dashboard/components-next/NewConversation/helpers/composeConversationHelper.js

# Mass sending campaign files
COPY WhatsAppCampaignForm.vue /app/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignForm.vue
COPY WhatsAppCampaignDialog.vue /app/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignDialog.vue
COPY WhatsAppCampaignReportDialog.vue /app/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignReportDialog.vue
COPY WhatsAppCampaignsPage.vue /app/app/javascript/dashboard/routes/dashboard/campaigns/pages/WhatsAppCampaignsPage.vue
COPY campaigns_api.js /app/app/javascript/dashboard/api/campaigns.js

# Personal canned responses with audio support
COPY cannedResponse.js /app/app/javascript/dashboard/api/cannedResponse.js
COPY cannedResponseStore.js /app/app/javascript/dashboard/store/modules/cannedResponse.js
COPY canned_Index.vue /app/app/javascript/dashboard/routes/dashboard/settings/canned/Index.vue
COPY canned_AddCanned.vue /app/app/javascript/dashboard/routes/dashboard/settings/canned/AddCanned.vue
COPY canned_EditCanned.vue /app/app/javascript/dashboard/routes/dashboard/settings/canned/EditCanned.vue
COPY CannedResponse_widget.vue /app/app/javascript/dashboard/components/widgets/conversation/CannedResponse.vue
COPY ReplyBox.vue /app/app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue

# WhatsApp Template Management - Backend files
COPY whatsapp_template_management_service.rb /app/app/services/whatsapp/template_management_service.rb
COPY whatsapp_templates_controller.rb /app/app/controllers/api/v1/accounts/whatsapp_templates_controller.rb

# WhatsApp Template Management - Patch backend routes
COPY patch_whatsapp_templates_routes.sh /tmp/patch_whatsapp_templates_routes.sh
RUN chmod +x /tmp/patch_whatsapp_templates_routes.sh && sh /tmp/patch_whatsapp_templates_routes.sh

# WhatsApp Template Management - Frontend files
COPY whatsappTemplatesApi.js /app/app/javascript/dashboard/api/whatsappTemplatesApi.js
COPY whatsappTemplatesStore.js /app/app/javascript/dashboard/store/modules/whatsappTemplates.js
COPY whatsappTemplates_routes.js /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/whatsappTemplates.routes.js
COPY whatsappTemplates_Index.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/Index.vue
COPY whatsappTemplates_TemplateStatusBadge.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/components/TemplateStatusBadge.vue
COPY whatsappTemplates_TemplatePreview.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/components/TemplatePreview.vue
COPY whatsappTemplates_TemplateFormDialog.vue /app/app/javascript/dashboard/routes/dashboard/settings/whatsapp-templates/components/TemplateFormDialog.vue

# Copy rebuilt Vite assets (compiled JS/CSS)
COPY --from=builder /app/public/vite /app/public/vite
COPY --from=builder /app/public/packs /app/public/packs

# Copy patched translation files
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/en/inboxMgmt.json /app/app/javascript/dashboard/i18n/locale/en/inboxMgmt.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json /app/app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/en/settings.json /app/app/javascript/dashboard/i18n/locale/en/settings.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/pt_BR/settings.json /app/app/javascript/dashboard/i18n/locale/pt_BR/settings.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/en/contact.json /app/app/javascript/dashboard/i18n/locale/en/contact.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/pt_BR/contact.json /app/app/javascript/dashboard/i18n/locale/pt_BR/contact.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/en/campaign.json /app/app/javascript/dashboard/i18n/locale/en/campaign.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/pt_BR/campaign.json /app/app/javascript/dashboard/i18n/locale/pt_BR/campaign.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/en/cannedMgmt.json /app/app/javascript/dashboard/i18n/locale/en/cannedMgmt.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/pt_BR/cannedMgmt.json /app/app/javascript/dashboard/i18n/locale/pt_BR/cannedMgmt.json

# WhatsApp Template Management - patched translation files
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json /app/app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json
COPY --from=builder /app/app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json /app/app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json

# Label for identification
LABEL com.farolchat.custom="true"
LABEL com.farolchat.feature="waba-pro-v2-coex-quality-lockdown-flows-templates"
LABEL com.farolchat.build-date="2026-04-22"
LABEL com.farolchat.waba.version="4.12.1-waba.2"
