#!/bin/sh
# Patch EN contact.json to add NEW_CONTACT i18n keys for ContactSelector
FILE="/app/app/javascript/dashboard/i18n/locale/en/contact.json"

ruby -rjson -e '
  d = JSON.parse(File.read("'"$FILE"'"))
  cs = d["COMPOSE_NEW_CONVERSATION"]["FORM"]["CONTACT_SELECTOR"]
  cs["NEW_CONTACT"] = {
    "NAME_PLACEHOLDER" => "Contact name",
    "PHONE_PLACEHOLDER" => "+5511999999999",
    "CONFIRM" => "Create contact",
    "CANCEL" => "Cancel",
    "TOOLTIP" => "Create new contact",
    "SEARCH_INSTEAD" => "Search existing",
    "ERROR_NAME" => "Name is required",
    "ERROR_PHONE" => "Valid phone with country code is required (e.g. +5511...)",
    "ERROR_CREATION" => "Failed to create contact. The phone number may already exist."
  }
  File.write("'"$FILE"'", JSON.pretty_generate(d))
'
echo "Patched EN contact.json with NEW_CONTACT keys"
