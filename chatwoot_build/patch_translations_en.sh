#!/bin/sh
# Patch: Add WABA ID and Phone Number ID translation keys to EN locale
# This script modifies the inboxMgmt.json file in-place

INBOX_MGMT_EN="/app/app/javascript/dashboard/i18n/locale/en/inboxMgmt.json"

# Use node to safely modify JSON
node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$INBOX_MGMT_EN', 'utf8'));

// Add new keys to SETTINGS_POPUP
const sp = data.INBOX_MGMT.SETTINGS_POPUP;
sp.WHATSAPP_WABA_ID_TITLE = 'WhatsApp Business Account ID (WABA ID)';
sp.WHATSAPP_WABA_ID_SUBHEADER = 'This is your WhatsApp Business Account ID. Update it to switch the linked Meta account without losing conversations.';
sp.WHATSAPP_WABA_ID_PLACEHOLDER = 'Enter the new WABA ID here';
sp.WHATSAPP_WABA_ID_BUTTON = 'Update';
sp.WHATSAPP_PHONE_NUMBER_ID_TITLE = 'Phone Number ID';
sp.WHATSAPP_PHONE_NUMBER_ID_SUBHEADER = 'This is the phone number ID registered in WhatsApp Business. Update it to switch the linked number without losing conversations.';
sp.WHATSAPP_PHONE_NUMBER_ID_PLACEHOLDER = 'Enter the new Phone Number ID here';
sp.WHATSAPP_PHONE_NUMBER_ID_BUTTON = 'Update';

fs.writeFileSync('$INBOX_MGMT_EN', JSON.stringify(data, null, 2));
console.log('EN translations patched successfully');
"
