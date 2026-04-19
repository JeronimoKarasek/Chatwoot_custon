#!/bin/sh
# Patch canned response translations for PT_BR - Personal + Audio feature

LOCALE_FILE="/app/app/javascript/dashboard/i18n/locale/pt_BR/cannedMgmt.json"

node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('${LOCALE_FILE}', 'utf8'));

// Add tabs
data.CANNED_MGMT.TABS = {
  SHARED: 'Da Conta',
  PERSONAL: 'Pessoais'
};

// Add personal badge
data.CANNED_MGMT.PERSONAL_BADGE = 'Pessoal';

// Add 404 for personal
data.CANNED_MGMT.LIST['404_PERSONAL'] = 'Você ainda não tem respostas prontas pessoais. Clique no botão acima para criar uma.';

// Add personal toggle to Add form
data.CANNED_MGMT.ADD.FORM.PERSONAL = {
  LABEL: 'Resposta pessoal',
  HELP: 'Visível apenas para você'
};

// Add response type to Add form
data.CANNED_MGMT.ADD.FORM.RESPONSE_TYPE = {
  LABEL: 'Tipo de resposta',
  TEXT: 'Texto',
  AUDIO: 'Áudio'
};

// Add audio section
data.CANNED_MGMT.AUDIO = {
  BADGE: 'Áudio',
  LABEL: 'Gravação de áudio',
  CLICK_TO_RECORD: 'Clique no botão abaixo para iniciar a gravação do seu áudio',
  START: 'Iniciar gravação',
  STOP: 'Parar gravação',
  RECORDING: 'Gravando...',
  RECORDED: 'Áudio gravado com sucesso!',
  PLAY: 'Ouvir',
  PAUSE: 'Pausar',
  RERECORD: 'Gravar novamente',
  EXISTING: 'Esta resposta possui uma gravação de áudio existente',
  MIC_ERROR: 'Não foi possível acessar o microfone. Verifique as permissões do navegador.',
  SENDING: 'Enviando áudio...'
};

fs.writeFileSync('${LOCALE_FILE}', JSON.stringify(data, null, 2));
console.log('PT_BR canned translations patched successfully');
"
