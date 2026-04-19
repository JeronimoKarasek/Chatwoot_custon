#!/bin/sh
# Patch EN settings.json to add FarolChat billing keys (Asaas)
node -e "
const fs = require('fs');
const path = '/app/app/javascript/dashboard/i18n/locale/en/settings.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

if (data.BILLING_SETTINGS) {
  data.BILLING_SETTINGS.FAROLCHAT = {
    MANAGE_TITLE: 'Manage Subscription',
    MANAGE_DESCRIPTION: 'Adjust the number of users and connections for your account. Changes are synced automatically.',
    AGENTS_LABEL: 'Users (Agents)',
    INBOXES_LABEL: 'Connections (Inboxes)',
    IN_USE_OF: 'in use of',
    RELEASED: 'released',
    RELEASED_F: 'released',
    MONTHLY_TOTAL: 'Estimated monthly total:',
    SAVE_CHANGES: 'Save Changes',
    SAVING: 'Saving...',
    GO_TO_PAYMENT: 'Go to Payment',
    UNDO: 'Undo',
  };
}

data.BILLING_SETTINGS.DESCRIPTION = 'Manage your subscription here, adjust users and connections for your team.';

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log('[patch] EN settings.json billing keys patched (Asaas)');
"
