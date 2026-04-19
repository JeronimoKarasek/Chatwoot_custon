#!/bin/sh
# Patch: Add WABA ID and Phone Number ID translation keys to PT_BR locale
# This script modifies the inboxMgmt.json file in-place

INBOX_MGMT_PT="/app/app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json"

node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$INBOX_MGMT_PT', 'utf8'));

// Add new keys to SETTINGS_POPUP
const sp = data.INBOX_MGMT.SETTINGS_POPUP;
sp.WHATSAPP_WABA_ID_TITLE = 'ID da Conta do WhatsApp Business (WABA ID)';
sp.WHATSAPP_WABA_ID_SUBHEADER = 'Este é o ID da sua conta do WhatsApp Business. Atualize para trocar a conta Meta vinculada sem perder as conversas.';
sp.WHATSAPP_WABA_ID_PLACEHOLDER = 'Digite o novo WABA ID aqui';
sp.WHATSAPP_WABA_ID_BUTTON = 'Atualizar';
sp.WHATSAPP_PHONE_NUMBER_ID_TITLE = 'ID do Número de Telefone';
sp.WHATSAPP_PHONE_NUMBER_ID_SUBHEADER = 'Este é o ID do número de telefone registrado no WhatsApp Business. Atualize para trocar o número vinculado sem perder as conversas.';
sp.WHATSAPP_PHONE_NUMBER_ID_PLACEHOLDER = 'Digite o novo Phone Number ID aqui';
sp.WHATSAPP_PHONE_NUMBER_ID_BUTTON = 'Atualizar';

fs.writeFileSync('$INBOX_MGMT_PT', JSON.stringify(data, null, 2));
console.log('PT_BR translations patched successfully');
"
