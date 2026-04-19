#!/bin/sh
# Patch suspended account translations for EN and PT_BR
node -e "
const fs = require('fs');

// Patch EN
const enPath = '/app/app/javascript/dashboard/i18n/locale/en/settings.json';
const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
if (!en.APP_GLOBAL) en.APP_GLOBAL = {};
if (!en.APP_GLOBAL.ACCOUNT_SUSPENDED) en.APP_GLOBAL.ACCOUNT_SUSPENDED = {};
en.APP_GLOBAL.ACCOUNT_SUSPENDED.PAYMENT_MESSAGE = 'Your account is suspended due to non-payment. Please regularize your situation by clicking the button below.';
en.APP_GLOBAL.ACCOUNT_SUSPENDED.PAYMENT_BUTTON = 'Regularize Payment';
fs.writeFileSync(enPath, JSON.stringify(en, null, 2));
console.log('[patch] EN suspended translations patched');

// Patch PT_BR
const ptPath = '/app/app/javascript/dashboard/i18n/locale/pt_BR/settings.json';
const pt = JSON.parse(fs.readFileSync(ptPath, 'utf8'));
if (!pt.APP_GLOBAL) pt.APP_GLOBAL = {};
if (!pt.APP_GLOBAL.ACCOUNT_SUSPENDED) pt.APP_GLOBAL.ACCOUNT_SUSPENDED = {};
pt.APP_GLOBAL.ACCOUNT_SUSPENDED.PAYMENT_MESSAGE = 'Sua conta está suspensa por falta de pagamento. Regularize sua situação clicando no botão abaixo.';
pt.APP_GLOBAL.ACCOUNT_SUSPENDED.PAYMENT_BUTTON = 'Regularizar Pagamento';
fs.writeFileSync(ptPath, JSON.stringify(pt, null, 2));
console.log('[patch] PT_BR suspended translations patched');
"
