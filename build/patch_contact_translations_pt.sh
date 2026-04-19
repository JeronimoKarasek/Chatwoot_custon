#!/bin/sh
# Patch PT_BR contact.json to add NEW_CONTACT i18n keys for ContactSelector
FILE="/app/app/javascript/dashboard/i18n/locale/pt_BR/contact.json"

ruby -rjson -e '
  d = JSON.parse(File.read("'"$FILE"'"))
  cs = d["COMPOSE_NEW_CONVERSATION"]["FORM"]["CONTACT_SELECTOR"]
  cs["NEW_CONTACT"] = {
    "NAME_PLACEHOLDER" => "Nome do contato",
    "PHONE_PLACEHOLDER" => "+5511999999999",
    "CONFIRM" => "Criar contato",
    "CANCEL" => "Cancelar",
    "TOOLTIP" => "Criar novo contato",
    "SEARCH_INSTEAD" => "Buscar existente",
    "ERROR_NAME" => "Nome é obrigatório",
    "ERROR_PHONE" => "Telefone válido com código do país é obrigatório (ex: +5511...)",
    "ERROR_CREATION" => "Falha ao criar contato. O telefone pode já existir."
  }
  File.write("'"$FILE"'", JSON.pretty_generate(d))
'
echo "Patched PT_BR contact.json with NEW_CONTACT keys"
