#!/bin/bash
# Patch English translations to add WhatsApp Template Management strings

SETTINGS_FILE="/app/app/javascript/dashboard/i18n/locale/en/settings.json"
TEMPLATES_FILE="/app/app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json"

# Add sidebar label to settings.json
node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
// Find SIDEBAR key recursively and add WHATSAPP_TEMPLATES
function addKey(obj) {
  for (const k of Object.keys(obj)) {
    if (k === 'SIDEBAR' && typeof obj[k] === 'object') {
      obj[k]['WHATSAPP_TEMPLATES'] = 'WhatsApp Templates';
      return true;
    }
    if (typeof obj[k] === 'object' && obj[k] !== null) {
      if (addKey(obj[k])) return true;
    }
  }
  return false;
}
addKey(data);
fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(data, null, 2) + '\n');
"

# Extend whatsappTemplates.json with MGMT section
node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$TEMPLATES_FILE', 'utf8'));
data.WHATSAPP_TEMPLATES.MGMT = {
  HEADER: 'WhatsApp Templates',
  DESCRIPTION: 'Create and manage WhatsApp message templates for your Cloud API inboxes. Templates must be approved by Meta before they can be used.',
  SELECT_INBOX: 'Select a WhatsApp inbox',
  NO_INBOX_SELECTED: 'Select a WhatsApp Cloud API inbox to manage templates',
  SEARCH_PLACEHOLDER: 'Search templates...',
  NO_RESULTS: 'No templates match your search criteria',
  CREATE_BTN: 'Create Template',
  FETCH_ERROR: 'Failed to load templates. Please try again.',
  CREATE_SUCCESS: 'Template created successfully! It will be reviewed by Meta.',
  UPDATE_SUCCESS: 'Template updated successfully!',
  DELETE_SUCCESS: 'Template deleted successfully.',
  DELETE_ERROR: 'Failed to delete template. Please try again.',
  SAVE_ERROR: 'Failed to save template. Please try again.',
  DELETE_CONFIRM: 'Are you sure you want to delete template \"{name}\"? If this template was approved, you cannot reuse this name for 30 days.',
  STATUS: {
    APPROVED: 'Approved',
    PENDING: 'Pending',
    REJECTED: 'Rejected',
    PAUSED: 'Paused',
    DISABLED: 'Disabled',
    IN_APPEAL: 'In Appeal'
  },
  TABLE: {
    NAME: 'Name',
    CATEGORY: 'Category',
    LANGUAGE: 'Language',
    STATUS: 'Status',
    BODY: 'Content',
    ACTIONS: 'Actions'
  },
  FORM: {
    CREATE_TITLE: 'Create Template',
    EDIT_TITLE: 'Edit Template',
    NAME: 'Template Name',
    NAME_PLACEHOLDER: 'my_template_name',
    NAME_HINT: 'Only lowercase letters, numbers, and underscores. Max 512 characters.',
    CATEGORY: 'Category',
    LANGUAGE: 'Language',
    HEADER: 'Header (optional)',
    HEADER_NONE: 'No Header',
    HEADER_TEXT: 'Text',
    HEADER_IMAGE: 'Image',
    HEADER_VIDEO: 'Video',
    HEADER_DOCUMENT: 'Document',
    HEADER_TEXT_PLACEHOLDER: 'Header text (max 60 chars)',
    MEDIA_HINT: 'Media upload will be available after template creation. For now, the header will be submitted without media.',
    BODY: 'Body',
    BODY_PLACEHOLDER: 'Type your message here. Use numbered variables, for example 1, 2 and so on.',
    BODY_HINT: 'Use *bold*, _italic_, ~strikethrough~. Add variables with the button below.',
    ADD_VARIABLE: 'Add Variable',
    FOOTER: 'Footer (optional)',
    FOOTER_PLACEHOLDER: 'Footer text (max 60 chars, no variables)',
    BUTTONS: 'Buttons',
    BUTTON_TEXT_PLACEHOLDER: 'Button label (max 25 chars)',
    COPY_CODE_PLACEHOLDER: 'Code to copy (max 15 chars)',
    EXAMPLES_TITLE: 'Variable Examples (required by Meta)',
    EXAMPLES_HINT: 'Meta requires example values for all variables during template submission.',
    EXAMPLE_HEADER: 'Header variable example',
    PREVIEW: 'Preview',
    PREVIEW_HINT: 'This is an approximation of how the message will look on WhatsApp.',
    CANCEL: 'Cancel',
    CREATE_BTN: 'Create Template',
    UPDATE_BTN: 'Update Template',
    ERRORS: {
      NAME_REQUIRED: 'Template name is required',
      NAME_FORMAT: 'Only lowercase letters, numbers and underscores allowed',
      NAME_TOO_LONG: 'Name must be 512 characters or less',
      BODY_REQUIRED: 'Body text is required',
      BODY_TOO_LONG: 'Body must be 1024 characters or less',
      HEADER_TOO_LONG: 'Header must be 60 characters or less',
      FOOTER_TOO_LONG: 'Footer must be 60 characters or less',
      BUTTON_TEXT_REQUIRED: 'Button text is required',
      BUTTON_TEXT_TOO_LONG: 'Button text must be 25 characters or less',
      URL_REQUIRED: 'URL is required for URL buttons',
      PHONE_REQUIRED: 'Phone number is required',
      EXAMPLE_REQUIRED: 'Example value is required for this variable'
    }
  }
};
fs.writeFileSync('$TEMPLATES_FILE', JSON.stringify(data, null, 2) + '\n');
"

echo "English translations patched successfully"
