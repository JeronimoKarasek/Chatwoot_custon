# Chatwoot FarolChat — Snapshot pré-compliance Meta

**Snapshot date:** 2026-05-04
**Tag:** pre-compliance baseline (state immediately before remediation for Meta Platform Term 7.e.i.3)

Este repositório guarda o **estado completo dos patches e do build** do Chatwoot custom (`farolchat/chatwoot:4.12.1-waba.2`) imediatamente antes de iniciarmos a remoção/refatoração de componentes para conformidade com as políticas da Meta WhatsApp Business Platform.

## Conteúdo
- `chatwoot_patch/` — todos os bind-mounts atuais (initializers, controllers, frontend, stack YAML).
- `chatwoot_build/` — Dockerfile e arquivos COPY'd na imagem custom.

## Sanitização
Todos os segredos conhecidos foram substituídos por placeholders `*_REDACTED`:
- Supabase DB passwords/users
- Stripe live key + webhook secret
- AWS access key / secret
- Redis password
- SMTP password
- Evolution admin token
- Rails SECRET_KEY_BASE
- WhatsApp App Secret

Antes de reusar qualquer arquivo, restaure os valores reais a partir do cofre de credenciais.

## Próximos passos (compliance Meta)
Ver o plano de remediação na conversa de origem. Componentes a remover/refatorar:
- Integração Evolution API (Baileys / WhatsApp Web não-oficial)
- `auto_template_patch.rb` (auto-reabertura de janela 24h)
- Modo "humano/lento" em `campaign_mass_sending_patch.rb`
- Renomear `whatsapp_quality_lockdown_patch.rb` → `whatsapp_quality_monitor_patch.rb`
