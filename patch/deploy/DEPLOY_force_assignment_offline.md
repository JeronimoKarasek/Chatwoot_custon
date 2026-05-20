# Deploy — ForceAssignmentOfflinePatch

> **Objetivo**: habilitar atribuição automática round-robin (1 a 1 uniforme) entre **todos os colaboradores** da inbox, **inclusive offline**, quando a flag `additional_attributes.assign_offline_agents=true` estiver setada na inbox.

## ⚠️ Cuidados importantes

1. **Ordem dos initializers** — `force_assignment_offline_patch.rb` precisa carregar **APÓS** `auto_assignment_fix_patch.rb`. O `stack-chatwoot.yaml` já está com a ordem correta (linhas 36-39 e 162-168 do arquivo).
2. **Compatível com bind-mount** — não exige rebuild de imagem Docker. Só copiar o `.rb` para `/opt/chatwoot_patch/` no host.
3. **Reversível** — para desligar, basta:
   - reverter o `stack-chatwoot.yaml` ou
   - definir `additional_attributes.assign_offline_agents=false` na inbox (default).

## Passo 1 — Copiar o novo patch para o host (sem restart)

```bash
# No servidor FarolChat
cd /opt/chatwoot_patch

# Backup do stack atual (segurança)
cp stack-chatwoot.yaml stack-chatwoot.yaml.bak_$(date +%Y%m%d_%H%M%S)

# Copiar do repositório:
cp /caminho/para/chatwoot_patch/force_assignment_offline_patch.rb /opt/chatwoot_patch/
cp /caminho/para/chatwoot_patch/stack-chatwoot.yaml             /opt/chatwoot_patch/

# Verificar permissões
chmod 0644 /opt/chatwoot_patch/force_assignment_offline_patch.rb

# Sanity check de sintaxe Ruby
docker run --rm -v /opt/chatwoot_patch/force_assignment_offline_patch.rb:/tmp/patch.rb:ro ruby:3.4 ruby -c /tmp/patch.rb
# Esperado: "Syntax OK"
```

## Passo 2 — Redeploy ordenado do stack

> **Por que isso é seguro com a ordem dos patches:** o Docker Swarm carrega os mounts na ordem definida no `volumes:` do compose. Como o initializer `force_assignment_offline_patch.rb` aparece **logo depois** do `auto_assignment_fix_patch.rb` no YAML, o Rails carrega na ordem alfabética dos arquivos em `config/initializers/`:
>
> ```
> auto_assignment_fix_patch.rb   ← carrega 1º (alfabético)
> force_assignment_offline_patch.rb ← carrega 2º (alfabético)
> ```
>
> Ambos estão num bloco `after_initialize` que respeita a ordem de definição.

```bash
# Aplica o stack (substitua <nome-stack> pelo nome real, ex: 'chatwoot')
docker stack deploy -c /opt/chatwoot_patch/stack-chatwoot.yaml <nome-stack>

# Acompanhar serviços convergindo
watch -n2 'docker service ls --filter name=<nome-stack>'
# Aguarde até REPLICAS mostrar 1/1 (app) e 3/3 (sidekiq)
```

## Passo 3 — Verificar carregamento dos patches

```bash
APP_CT=$(docker ps --filter 'name=<nome-stack>_chatwoot_app' --format '{{.Names}}' | head -1)
docker logs "$APP_CT" 2>&1 | grep -E 'AutoAssignmentFixPatch|ForceAssignmentOfflinePatch' | tail -20
```

**Saída esperada:**
```
AutoAssignmentFixPatch: Loading...
AutoAssignmentFixPatch: Added 3s delay to AssignmentJob (fixes transaction race condition)
[ForceAssignmentOfflinePatch] Loading...
[ForceAssignmentOfflinePatch] Inboxes::BulkAutoAssignmentJob patched
[ForceAssignmentOfflinePatch] Loaded. Toggle via inbox.additional_attributes["assign_offline_agents"]=true
```

Repita para um dos sidekiqs:
```bash
SK_CT=$(docker ps --filter 'name=<nome-stack>_chatwoot_sidekiq' --format '{{.Names}}' | head -1)
docker logs "$SK_CT" 2>&1 | grep ForceAssignmentOfflinePatch
```

## Passo 4 — Ativar a flag por inbox (controle de admin)

Copie o helper para dentro do app e use os comandos:

```bash
docker cp /caminho/para/patch/deploy/toggle_assign_offline.rb "$APP_CT":/tmp/

# Listar status atual de todas inboxes da conta 37:
docker exec -i "$APP_CT" bundle exec rails runner \
  "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.list(account_id: 37)"

# Ativar nas inboxes problemáticas que você quer rodízio incluindo offline:
docker exec -i "$APP_CT" bundle exec rails runner \
  "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.enable_many([727, 696, 737, 742, 747])"

# Verificar que ficou ativo:
docker exec -i "$APP_CT" bundle exec rails runner \
  "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.list(account_id: 37)"

# Para desativar uma específica:
docker exec -i "$APP_CT" bundle exec rails runner \
  "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.disable(inbox_id: 727)"
```

## Passo 5 — Validar comportamento em produção

### 5.1 Teste manual: nova conversa entra

1. Envie uma nova mensagem para um número da inbox #727 (Vitoria)
2. Acompanhe o log do sidekiq:
   ```bash
   docker service logs <nome-stack>_chatwoot_sidekiq --tail 50 --follow 2>&1 | grep -E '727|AgentAssignment'
   ```
3. **Esperado**: conversa é atribuída a um dos colaboradores da inbox, mesmo que offline.

### 5.2 Teste manual: redistribuição em lote (BulkAutoAssignmentJob)

```bash
docker exec -i "$APP_CT" bundle exec rails runner '
  inbox = Inbox.find(727)
  puts "Conversas sem assignee antes: #{inbox.conversations.where(assignee_id: nil).where(status: [:open, :pending]).count}"
  Inboxes::BulkAutoAssignmentJob.new.perform(inbox_id: 727)
  puts "Conversas sem assignee depois: #{inbox.conversations.where(assignee_id: nil).where(status: [:open, :pending]).count}"
'
```

## Rollback (caso algo dê errado)

### Rollback rápido (não reinicia containers) — desliga a feature mantendo o patch carregado

```bash
docker exec -i "$APP_CT" bundle exec rails runner \
  "load '/tmp/toggle_assign_offline.rb'; ToggleAssignOffline.disable_many([727, 696, 737, 742, 747])"
```

Sem a flag ligada, o patch **não altera comportamento nenhum** — volta ao fluxo nativo.

### Rollback total — remove o patch

```bash
# 1) Restaurar stack original
cp /opt/chatwoot_patch/stack-chatwoot.yaml.bak_<timestamp> /opt/chatwoot_patch/stack-chatwoot.yaml

# 2) Remover o arquivo do initializer
rm /opt/chatwoot_patch/force_assignment_offline_patch.rb

# 3) Redeploy
docker stack deploy -c /opt/chatwoot_patch/stack-chatwoot.yaml <nome-stack>
```

## FAQ

**P: O patch quebra o auto-assign atual de quem está usando a UI?**
R: Não. Sem a flag setada (default), o patch só observa e delega 100% para o fluxo original.

**P: O round-robin vai distribuir uniformemente?**
R: Sim. Reaproveitamos `RoundRobin::ManageService` do Chatwoot, que usa um contador no Redis por inbox.

**P: Agentes com `auto_assignable=false` (admins/supervisores) entram no rodízio?**
R: Não, continua sendo respeitado.

**P: E o `max_assignment_limit`/capacidade do agente?**
R: O patch tem um filtro de capacidade similar ao do core. Agentes com fila cheia são pulados.

**P: Conversa atribuída a agente offline — ele recebe alguma notificação?**
R: Sim, segue o fluxo nativo do Chatwoot: email + push (se configurados). Quando logar, a conversa estará na fila dele.
