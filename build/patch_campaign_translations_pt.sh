#!/bin/sh
# Patch campaign translations for pt_BR - Mass Sending feature
# This script adds new translation keys for the mass sending campaign feature

LOCALE_FILE="/app/app/javascript/dashboard/i18n/locale/pt_BR/campaign.json"

node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('${LOCALE_FILE}', 'utf8'));

// Add mass sending related translations under WHATSAPP
data.CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE_TYPE = {
  LABEL: 'Tipo de Público',
  CONTACT_LABELS: 'Etiquetas de Contato',
  CONVERSATION_LABELS: 'Etiquetas de Conversa',
  CSV_IMPORT: 'Importar Base CSV'
};

data.CAMPAIGN.WHATSAPP.CREATE.FORM.SENDING_SPEED = {
  LABEL: 'Velocidade de Envio',
  NORMAL: 'Normal — 20 números/segundo',
  SLOW: 'Lento — 1 número/segundo',
  HUMAN: 'Humano — 6 números/minuto'
};

data.CAMPAIGN.WHATSAPP.CREATE.FORM.CSV = {
  LABEL: 'Base de Contatos (CSV)',
  UPLOAD: 'Clique para selecionar arquivo CSV',
  REQUIRED_COLUMNS: 'Colunas obrigatórias: nome, telefone',
  OPTIONAL_COLUMNS: 'Opcionais: etiqueta, email, empresa',
  PREVIEW: 'Pré-visualização',
  IMPORT_SUCCESS: 'Importação concluída',
  IMPORT_TOTAL: 'Total',
  IMPORT_CREATED: 'Novos contatos',
  IMPORT_EXISTING: 'Já existentes',
  IMPORT_ERRORS: 'Erros',
  ERROR: 'Arquivo CSV é obrigatório'
};

data.CAMPAIGN.WHATSAPP.EXECUTE = {
  BUTTON: 'Executar',
  CONFIRM: 'Tem certeza que deseja iniciar o envio?',
  SUCCESS: 'Campanha iniciada com sucesso!',
  ERROR: 'Erro ao executar campanha',
  ALREADY_RUNNING: 'Campanha já está em execução',
  ALREADY_COMPLETED: 'Campanha já foi concluída',
  NO_CONTACTS: 'Nenhum contato encontrado'
};

data.CAMPAIGN.WHATSAPP.PROGRESS = {
  SENT: 'enviados',
  FAILED: 'falhas',
  RUNNING: 'Executando...',
  COMPLETED: 'Concluído',
  FAILED_STATUS: 'Falhou',
  SCHEDULED: 'Agendada'
};

fs.writeFileSync('${LOCALE_FILE}', JSON.stringify(data, null, 2));
console.log('Campaign pt_BR translations patched successfully');
"
