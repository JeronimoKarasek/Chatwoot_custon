#!/bin/bash
# Patch settings.routes.js to add WhatsApp Templates route

ROUTES_FILE="/app/app/javascript/dashboard/routes/dashboard/settings/settings.routes.js"

# Add import line after the last import (captain)
sed -i "/import captain from '\.\/captain\/captain\.routes';/a import whatsappTemplates from './whatsapp-templates/whatsappTemplates.routes';" "$ROUTES_FILE"

# Add route spread after ...captain.routes
sed -i '/\.\.\.captain\.routes,/a\    ...whatsappTemplates.routes,' "$ROUTES_FILE"

echo "Settings routes patched successfully"
