#!/bin/bash
# Patch routes.rb to add whatsapp_templates resource inside inboxes
ROUTES_FILE="/app/config/routes.rb"

# Add whatsapp_templates resource after sync_templates line
sed -i '/post :sync_templates, on: :member/a\            resources :whatsapp_templates, only: [:index, :create, :update, :destroy], controller: '\''whatsapp_templates'\''' "$ROUTES_FILE"

echo "Routes patched successfully"
