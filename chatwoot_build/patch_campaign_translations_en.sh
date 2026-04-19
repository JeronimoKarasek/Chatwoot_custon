#!/bin/sh
# Patch campaign translations for EN - Mass Sending feature

LOCALE_FILE="/app/app/javascript/dashboard/i18n/locale/en/campaign.json"

node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('${LOCALE_FILE}', 'utf8'));

data.CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE_TYPE = {
  LABEL: 'Audience Type',
  CONTACT_LABELS: 'Contact Labels',
  CONVERSATION_LABELS: 'Conversation Labels',
  CSV_IMPORT: 'Import CSV File'
};

data.CAMPAIGN.WHATSAPP.CREATE.FORM.SENDING_SPEED = {
  LABEL: 'Sending Speed',
  NORMAL: 'Normal — 20 numbers/second',
  SLOW: 'Slow — 1 number/second',
  HUMAN: 'Human — 6 numbers/minute'
};

data.CAMPAIGN.WHATSAPP.CREATE.FORM.CSV = {
  LABEL: 'Contact Base (CSV)',
  UPLOAD: 'Click to select CSV file',
  REQUIRED_COLUMNS: 'Required columns: name, phone',
  OPTIONAL_COLUMNS: 'Optional: label, email, company',
  PREVIEW: 'Preview',
  IMPORT_SUCCESS: 'Import completed',
  IMPORT_TOTAL: 'Total',
  IMPORT_CREATED: 'New contacts',
  IMPORT_EXISTING: 'Already existing',
  IMPORT_ERRORS: 'Errors',
  ERROR: 'CSV file is required'
};

data.CAMPAIGN.WHATSAPP.EXECUTE = {
  BUTTON: 'Execute',
  CONFIRM: 'Are you sure you want to start sending?',
  SUCCESS: 'Campaign started successfully!',
  ERROR: 'Error executing campaign',
  ALREADY_RUNNING: 'Campaign is already running',
  ALREADY_COMPLETED: 'Campaign already completed',
  NO_CONTACTS: 'No contacts found'
};

data.CAMPAIGN.WHATSAPP.PROGRESS = {
  SENT: 'sent',
  FAILED: 'failures',
  RUNNING: 'Running...',
  COMPLETED: 'Completed',
  FAILED_STATUS: 'Failed',
  SCHEDULED: 'Scheduled'
};

fs.writeFileSync('${LOCALE_FILE}', JSON.stringify(data, null, 2));
console.log('Campaign EN translations patched successfully');
"
