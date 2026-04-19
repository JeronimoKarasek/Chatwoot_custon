#!/bin/sh
# Patch canned response translations for EN - Personal + Audio feature

LOCALE_FILE="/app/app/javascript/dashboard/i18n/locale/en/cannedMgmt.json"

node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('${LOCALE_FILE}', 'utf8'));

// Add tabs
data.CANNED_MGMT.TABS = {
  SHARED: 'Account',
  PERSONAL: 'Personal'
};

// Add personal badge
data.CANNED_MGMT.PERSONAL_BADGE = 'Personal';

// Add 404 for personal
data.CANNED_MGMT.LIST['404_PERSONAL'] = 'You have no personal canned responses yet. Click the button above to create one.';

// Add personal toggle to Add form
data.CANNED_MGMT.ADD.FORM.PERSONAL = {
  LABEL: 'Personal response',
  HELP: 'Only visible to you'
};

// Add response type to Add form
data.CANNED_MGMT.ADD.FORM.RESPONSE_TYPE = {
  LABEL: 'Response type',
  TEXT: 'Text',
  AUDIO: 'Audio'
};

// Add audio section
data.CANNED_MGMT.AUDIO = {
  BADGE: 'Audio',
  LABEL: 'Audio recording',
  CLICK_TO_RECORD: 'Click the button below to start recording your audio',
  START: 'Start recording',
  STOP: 'Stop recording',
  RECORDING: 'Recording in progress...',
  RECORDED: 'Audio recorded successfully!',
  PLAY: 'Play',
  PAUSE: 'Pause',
  RERECORD: 'Record again',
  EXISTING: 'This response has an existing audio recording',
  MIC_ERROR: 'Could not access microphone. Please check your browser permissions.',
  SENDING: 'Sending audio...'
};

fs.writeFileSync('${LOCALE_FILE}', JSON.stringify(data, null, 2));
console.log('EN canned translations patched successfully');
"
