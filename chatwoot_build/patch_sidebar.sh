#!/bin/bash
# Patch Sidebar.vue to add WhatsApp Templates menu item

SIDEBAR_FILE="/app/app/javascript/dashboard/components-next/sidebar/Sidebar.vue"

node -e "
const fs = require('fs');
let content = fs.readFileSync('$SIDEBAR_FILE', 'utf8');

// Use regex to find the opening brace + name: 'Settings Billing' block
// and insert the new item before it, preserving original indentation
const replaced = content.replace(
  /(\s*)\{\s*\n(\s*)name:\s*'Settings Billing'/,
  function(match, indent, innerIndent) {
    const newItem = indent + '{' + '\n'
      + innerIndent + \"name: 'Settings WhatsApp Templates',\" + '\n'
      + innerIndent + \"label: t('SIDEBAR.WHATSAPP_TEMPLATES'),\" + '\n'
      + innerIndent + \"icon: 'i-lucide-message-square-plus',\" + '\n'
      + innerIndent + \"to: accountScopedRoute('whatsapp_templates_list'),\" + '\n'
      + indent + '},';
    return newItem + '\n' + indent + '{' + '\n' + innerIndent + \"name: 'Settings Billing'\";
  }
);

if (replaced !== content) {
  fs.writeFileSync('$SIDEBAR_FILE', replaced);
  console.log('Sidebar patched successfully');
} else {
  console.log('WARNING: Could not find Settings Billing in Sidebar.vue');
}
"
