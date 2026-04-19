#!/bin/sh
# Patch EN settings.json to add FarolChat billing keys
node -e "
const fs = require('fs');
const path = '/app/app/javascript/dashboard/i18n/locale/en/settings.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

// Add FAROLCHAT billing keys
if (data.BILLING_SETTINGS) {
  data.BILLING_SETTINGS.FAROLCHAT = {
    MANAGE_TITLE: 'Manage Subscription',
    MANAGE_DESCRIPTION: 'Adjust the number of users and connections for your account. Changes are synced with Stripe automatically.',
    AGENTS_LABEL: 'Users (Agents)',
    INBOXES_LABEL: 'Connections (Inboxes)',
    IN_USE_OF: 'in use of',
    RELEASED: 'released',
    RELEASED_F: 'released',
    AGENT_PRICE: 'R\$ 29.00/month per agent',
    INBOX_PRICE: 'R\$ 49.90/month per connection',
    MONTHLY_TOTAL: 'Estimated monthly total:',
    SAVE_CHANGES: 'Save Changes',
    SAVING: 'Saving...',
    GO_TO_PAYMENT: 'Go to Payment',
    UNDO: 'Undo',
  };
}

// Update description for FarolChat
data.BILLING_SETTINGS.DESCRIPTION = 'Manage your subscription here, adjust users and connections for your team.';

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log('[patch] EN settings.json billing keys patched');
"
