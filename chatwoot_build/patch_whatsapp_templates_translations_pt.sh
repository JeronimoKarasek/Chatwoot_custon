#!/bin/bash
# Patch Portuguese translations to add WhatsApp Template Management strings

SETTINGS_FILE="/app/app/javascript/dashboard/i18n/locale/pt_BR/settings.json"
TEMPLATES_FILE="/app/app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json"

# Add sidebar label to settings.json
node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
function addKey(obj) {
  for (const k of Object.keys(obj)) {
    if (k === 'SIDEBAR' && typeof obj[k] === 'object') {
      obj[k]['WHATSAPP_TEMPLATES'] = 'Criação de Templates';
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
  HEADER: 'Criação de Templates',
  DESCRIPTION: 'Crie e gerencie modelos de mensagem do WhatsApp para suas caixas de entrada Cloud API. Os modelos precisam ser aprovados pela Meta antes de serem utilizados.',
  SELECT_INBOX: 'Selecione uma caixa de entrada WhatsApp',
  NO_INBOX_SELECTED: 'Selecione uma caixa de entrada WhatsApp Cloud API para gerenciar templates',
  SEARCH_PLACEHOLDER: 'Buscar templates...',
  NO_RESULTS: 'Nenhum template encontrado para os filtros selecionados',
  CREATE_BTN: 'Criar Template',
  FETCH_ERROR: 'Falha ao carregar templates. Tente novamente.',
  CREATE_SUCCESS: 'Template criado com sucesso! Será revisado pela Meta.',
  UPDATE_SUCCESS: 'Template atualizado com sucesso!',
  DELETE_SUCCESS: 'Template excluído com sucesso.',
  DELETE_ERROR: 'Falha ao excluir template. Tente novamente.',
  SAVE_ERROR: 'Falha ao salvar template. Tente novamente.',
  DELETE_CONFIRM: 'Tem certeza que deseja excluir o template \"{name}\"? Se este template foi aprovado, você não poderá reutilizar este nome por 30 dias.',
  STATUS: {
    APPROVED: 'Aprovado',
    PENDING: 'Pendente',
    REJECTED: 'Rejeitado',
    PAUSED: 'Pausado',
    DISABLED: 'Desabilitado',
    IN_APPEAL: 'Em Recurso'
  },
  TABLE: {
    NAME: 'Nome',
    CATEGORY: 'Categoria',
    LANGUAGE: 'Idioma',
    STATUS: 'Status',
    BODY: 'Conteúdo',
    ACTIONS: 'Ações'
  },
  FORM: {
    CREATE_TITLE: 'Criar Template',
    EDIT_TITLE: 'Editar Template',
    NAME: 'Nome do Template',
    NAME_PLACEHOLDER: 'meu_nome_de_template',
    NAME_HINT: 'Apenas letras minúsculas, números e underscores. Máximo 512 caracteres.',
    CATEGORY: 'Categoria',
    LANGUAGE: 'Idioma',
    HEADER: 'Cabeçalho (opcional)',
    HEADER_NONE: 'Sem Cabeçalho',
    HEADER_TEXT: 'Texto',
    HEADER_IMAGE: 'Imagem',
    HEADER_VIDEO: 'Vídeo',
    HEADER_DOCUMENT: 'Documento',
    HEADER_TEXT_PLACEHOLDER: 'Texto do cabeçalho (máx. 60 caracteres)',
    MEDIA_HINT: 'O upload de mídia estará disponível após a criação do template. Por enquanto, o cabeçalho será enviado sem mídia.',
    BODY: 'Corpo da Mensagem',
    BODY_PLACEHOLDER: 'Digite sua mensagem aqui. Use variáveis numeradas, por exemplo 1, 2 e assim por diante.',
    BODY_HINT: 'Use *negrito*, _itálico_, ~tachado~. Adicione variáveis com o botão abaixo.',
    ADD_VARIABLE: 'Adicionar Variável',
    FOOTER: 'Rodapé (opcional)',
    FOOTER_PLACEHOLDER: 'Texto do rodapé (máx. 60 caracteres, sem variáveis)',
    BUTTONS: 'Botões',
    BUTTON_TEXT_PLACEHOLDER: 'Texto do botão (máx. 25 caracteres)',
    COPY_CODE_PLACEHOLDER: 'Código para copiar (máx. 15 caracteres)',
    EXAMPLES_TITLE: 'Exemplos de Variáveis (obrigatório pela Meta)',
    EXAMPLES_HINT: 'A Meta exige valores de exemplo para todas as variáveis durante o envio do template.',
    EXAMPLE_HEADER: 'Exemplo da variável do cabeçalho',
    PREVIEW: 'Pré-visualização',
    PREVIEW_HINT: 'Esta é uma aproximação de como a mensagem aparecerá no WhatsApp.',
    CANCEL: 'Cancelar',
    CREATE_BTN: 'Criar Template',
    UPDATE_BTN: 'Atualizar Template',
    ERRORS: {
      NAME_REQUIRED: 'O nome do template é obrigatório',
      NAME_FORMAT: 'Apenas letras minúsculas, números e underscores são permitidos',
      NAME_TOO_LONG: 'O nome deve ter no máximo 512 caracteres',
      BODY_REQUIRED: 'O texto do corpo é obrigatório',
      BODY_TOO_LONG: 'O corpo deve ter no máximo 1024 caracteres',
      HEADER_TOO_LONG: 'O cabeçalho deve ter no máximo 60 caracteres',
      FOOTER_TOO_LONG: 'O rodapé deve ter no máximo 60 caracteres',
      BUTTON_TEXT_REQUIRED: 'O texto do botão é obrigatório',
      BUTTON_TEXT_TOO_LONG: 'O texto do botão deve ter no máximo 25 caracteres',
      URL_REQUIRED: 'A URL é obrigatória para botões de URL',
      PHONE_REQUIRED: 'O número de telefone é obrigatório',
      EXAMPLE_REQUIRED: 'O valor de exemplo é obrigatório para esta variável'
    }
  }
};
fs.writeFileSync('$TEMPLATES_FILE', JSON.stringify(data, null, 2) + '\n');
"

echo "Portuguese translations patched successfully"
