# 🚀 Deploy Chatwoot Custom - GHCR

## 📋 Pré-requisitos

1. **GitHub Personal Access Token (PAT)** com permissões:
   - `write:packages`
   - `read:packages`
   - `delete:packages` (opcional)

## 🔑 Gerar Token GitHub

1. Acesse: https://github.com/settings/tokens/new
2. Nome sugerido: `chatwoot-ghcr-push`
3. Marque as permissões necessárias (ver acima)
4. Clique em **"Generate token"**
5. **Copie o token** (você só verá ele uma vez!)

## 📦 Push da Imagem para GHCR

### Opção 1: Usando o script (Recomendado)

```bash
# Com token via argumento
./push_to_ghcr.sh 'seu_token_aqui'

# Ou com variável de ambiente
export GITHUB_TOKEN='seu_token_aqui'
./push_to_ghcr.sh
```

### Opção 2: Manual

```bash
# 1. Login no GHCR
echo 'seu_token_aqui' | docker login ghcr.io -u jeronimokarasek --password-stdin

# 2. Tag da imagem
docker tag chatwoot_unlocked:v2 ghcr.io/jeronimokarasek/chatwoot_custon:latest

# 3. Push
docker push ghcr.io/jeronimokarasek/chatwoot_custon:latest
```

## 🔄 Atualizar Serviço Swarm

Após o push bem sucedido:

```bash
docker service update --image ghcr.io/jeronimokarasek/chatwoot_custon:latest chatv44_chatwoot_app --force
```

## ✅ Verificar Deploy

```bash
# Ver logs do serviço
docker service logs chatv44_chatwoot_app --tail 50 -f

# Verificar se o patch foi aplicado
docker ps --filter "name=chatv44_chatwoot_app" --format '{{.ID}}' | head -n 1 | xargs -I {} docker logs {} 2>&1 | grep "ZZ_FINAL_UNLOCK"
```

Você deve ver:
```
✅ ZZ_FINAL_UNLOCK: enabled_features patch aplicado
```

## 🎯 Funcionalidades Desbloqueadas

A imagem `chatwoot_unlocked:v2` inclui:

### 1. **49 Features Enterprise Ativadas**
- ✅ Advanced Search & Indexing
- ✅ Agent Bots & Management
- ✅ Campaigns & Automations
- ✅ CRM Integration (v1 e v2)
- ✅ Help Center & Embedding Search
- ✅ Inbox Management & View
- ✅ Reports & Analytics
- ✅ SAML SSO
- ✅ SLA Management
- ✅ Team Management
- ✅ E muito mais...

### 2. **Patches Aplicados**

#### `/app/config/initializers/zz_final_unlock.rb`
- Força `Account.enabled_features` a retornar todas as 49 features
- Sobrescreve `feature_enabled?` para sempre retornar `true`

#### `/app/app/views/api/v1/models/_user.json.jbuilder`
- Força `role='administrator'` para todos os usuários (linhas 16 e 26)

#### `/app/app/jobs/internal/check_new_versions_job.rb`
- Adiciona guard contra `@instance_info.nil?` para evitar 500 errors

#### `/app/public/brand-assets/`
- SVG wrappers para logos customizados (FOCO.png)

#### `/app/config/initializers/ee_unlock.rb`
- Desbloqueia limites de conta
- Remove verificações de licença
- Força edição Enterprise

## 🌐 Acesso

Após o deploy, acesse:
- **Frontend**: https://chat.premiumleads.com.br/
- **Limpe o cache do navegador** (Ctrl+Shift+Delete) para carregar as novas features

## 📊 Verificação Backend

```bash
# Obter container ID
CONTAINER_ID=$(docker ps --filter "name=chatv44_chatwoot_app" --format '{{.ID}}' | head -n 1)

# Verificar features habilitadas
docker exec $CONTAINER_ID sh -lc "bundle exec rails runner \"
acc = Account.first
puts 'Features Count: ' + acc.enabled_features.keys.count.to_s
puts 'Includes reports: ' + acc.enabled_features.key?('reports').to_s
puts 'Includes inbox_management: ' + acc.enabled_features.key?('inbox_management').to_s
\" | tail -n 5"
```

Resultado esperado:
```
Features Count: 49
Includes reports: true
Includes inbox_management: true
```

## 🐛 Troubleshooting

### Erro: "denied: denied" no login
- Verifique se o token tem a permissão `write:packages`
- Gere um novo token se necessário

### Imagem não atualiza no Swarm
```bash
# Force pull e restart
docker service update --image ghcr.io/jeronimokarasek/chatwoot_custon:latest chatv44_chatwoot_app --force --with-registry-auth
```

### Features não aparecem no frontend
1. Limpe o cache do navegador
2. Verifique se o patch foi aplicado: `docker logs [container] | grep ZZ_FINAL_UNLOCK`
3. Reinicie o serviço: `docker service update --force chatv44_chatwoot_app`

## 📝 Notas

- A imagem é baseada em `ghcr.io/jeronimokarasek/chatwoot_custon:latest`
- Todos os patches são aplicados em tempo de inicialização
- A imagem local é `chatwoot_unlocked:v2`
- Não há necessidade de rebuild da imagem, apenas commit do container

## 🔐 Segurança

⚠️ **IMPORTANTE**: 
- Mantenha seu GitHub Token seguro
- Não commite o token no repositório
- Use variáveis de ambiente ou secrets managers
- Rotacione tokens regularmente
