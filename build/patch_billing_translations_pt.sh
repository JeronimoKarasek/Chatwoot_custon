#!/bin/sh
# Patch PT_BR settings.json to add FarolChat billing keys
node -e "
const fs = require('fs');
const path = '/app/app/javascript/dashboard/i18n/locale/pt_BR/settings.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

// Add FAROLCHAT billing keys
if (data.BILLING_SETTINGS) {
  data.BILLING_SETTINGS.FAROLCHAT = {
    MANAGE_TITLE: 'Gerenciar Assinatura',
    MANAGE_DESCRIPTION: 'Ajuste a quantidade de usuários e conexões da sua conta. As alterações são sincronizadas com o Stripe automaticamente.',
    AGENTS_LABEL: 'Usuários (Agentes)',
    INBOXES_LABEL: 'Conexões (Caixas de Entrada)',
    IN_USE_OF: 'em uso de',
    RELEASED: 'liberados',
    RELEASED_F: 'liberadas',
    AGENT_PRICE: 'R\$ 29,00/mês por agente',
    INBOX_PRICE: 'R\$ 49,90/mês por conexão',
    MONTHLY_TOTAL: 'Total mensal estimado:',
    SAVE_CHANGES: 'Salvar Alterações',
    SAVING: 'Salvando...',
    GO_TO_PAYMENT: 'Ir para Pagamento',
    UNDO: 'Desfazer',
  };

  // Update description
  data.BILLING_SETTINGS.DESCRIPTION = 'Gerencie sua assinatura aqui, ajuste usuários e conexões para seu time.';
  data.BILLING_SETTINGS.TITLE = 'Cobrança';
}

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log('[patch] PT_BR settings.json billing keys patched');
"
