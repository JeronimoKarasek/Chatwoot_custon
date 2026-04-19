#!/bin/sh
# Patch store/index.js to register whatsappTemplates store module
set -e

STORE_FILE="/app/app/javascript/dashboard/store/index.js"

node -e "
const fs = require('fs');
let content = fs.readFileSync('$STORE_FILE', 'utf8');

// Add import after captainCustomTools import
const importPattern = /import captainCustomTools from '.\/captain\/customTools';/;
if (!importPattern.test(content)) {
  console.error('ERROR: captainCustomTools import not found in store/index.js');
  process.exit(1);
}
content = content.replace(
  importPattern,
  \"import captainCustomTools from './captain/customTools';\\nimport whatsappTemplates from './modules/whatsappTemplates';\"
);

// Add module to modules object after captainCustomTools,
const modulePattern = /captainCustomTools,/;
if (!modulePattern.test(content)) {
  console.error('ERROR: captainCustomTools module registration not found');
  process.exit(1);
}
content = content.replace(
  modulePattern,
  'captainCustomTools,\\n    whatsappTemplates,'
);

fs.writeFileSync('$STORE_FILE', content, 'utf8');

// Verify
const verify = fs.readFileSync('$STORE_FILE', 'utf8');
if (!verify.includes(\"import whatsappTemplates from './modules/whatsappTemplates'\")) {
  console.error('ERROR: Import not found after patching');
  process.exit(1);
}
if (!verify.includes('whatsappTemplates,')) {
  console.error('ERROR: Module registration not found after patching');
  process.exit(1);
}
console.log('Store index patched successfully - whatsappTemplates import and module registered');
"
