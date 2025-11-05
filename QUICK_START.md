# 🚀 Guia Rápido - Deploy Chatwoot com Features EE Desbloqueadas

## ✅ O que foi feito?

1. ✅ **Criada nova imagem Docker** com todas as features EE desbloqueadas
2. ✅ **Removidos todos os cadeados** do painel Settings
3. ✅ **Documentado solução** para problemas de conexão Supabase
4. ✅ **Criados scripts automatizados** para deploy e manutenção

---

## 🔓 Features Agora Disponíveis (SEM CADEADOS!)

✅ Captain (AI)  
✅ Custom Branding  
✅ Agent Capacity  
✅ Audit Logs  
✅ Help Center  
✅ SLA Management  
✅ All Channels (WhatsApp, Email, SMS, Instagram, Telegram, Line)  
✅ Advanced Reports  
✅ Automations  
✅ Custom Roles  
✅ Team Management  
✅ Macros  
✅ Canned Responses  
✅ CSAT  
✅ Priority Management  
✅ **E TODAS AS OUTRAS!**

---

## 🎯 Deploy Rápido no Portainer

### 1️⃣ Obter Credenciais Corretas do Supabase

**Importante**: Você precisa das credenciais ATUALIZADAS do Supabase!

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Vá em: **Settings** → **Database**
4. Role até **Connection string** → **URI**
5. Selecione **Session mode**
6. Copie a string completa

**Formato esperado**:
```
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres
```

---

### 2️⃣ Gerar SECRET_KEY_BASE

Execute no terminal:
```bash
openssl rand -hex 64
```

Copie o resultado gerado.

---

### 3️⃣ Stack Completa para Portainer

Copie e cole esta stack no Portainer:

```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - chatwoot
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  chatwoot:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    depends_on:
      redis:
        condition: service_healthy
    environment:
      # ========================================
      # 🔴 ATUALIZE ESTAS VARIÁVEIS OBRIGATÓRIAS
      # ========================================
      
      # Supabase - Cole sua connection string aqui
      DATABASE_URL: postgresql://postgres.SEU_PROJECT_REF:SUA_SENHA@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
      
      # Redis
      REDIS_URL: redis://redis:6379
      
      # Secret Key - Cole o resultado do openssl rand -hex 64
      SECRET_KEY_BASE: COLE_AQUI_SUA_CHAVE_GERADA
      
      # Frontend URL - Seu domínio
      FRONTEND_URL: https://chat.seu-dominio.com
      
      # ========================================
      # ✅ CONFIGURAÇÕES RECOMENDADAS
      # ========================================
      
      # Instalação
      INSTALLATION_NAME: MeuChatwoot
      DEFAULT_LOCALE: pt_BR
      ENABLE_ACCOUNT_SIGNUP: "true"
      
      # Rails
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "true"
      RAILS_SERVE_STATIC_FILES: "true"
      RAILS_MAX_THREADS: "7"
      WEB_CONCURRENCY: "4"
      
      # Enterprise Edition (Já desbloqueado!)
      CW_EDITION: ee
      CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES: "true"
      USE_INBOX_AVATAR_FOR_BOT: "true"
      
      # Features
      DISABLE_AGENT_CONVERSATION_VIEW_OTHER: "false"
      HIDE_ALL_CHATS_FROM_AGENT: "false"
      
      # Performance
      SIDEKIQ_CONCURRENCY: "20"
      RACK_TIMEOUT_SERVICE_TIMEOUT: "0"
      ENABLE_RACK_ATTACK: "false"
      
      # Node
      NODE_ENV: production
      
    ports:
      - "3000:3000"
    volumes:
      - app_storage:/app/storage
      - app_public:/app/public
    networks:
      - chatwoot
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  sidekiq:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    depends_on:
      redis:
        condition: service_healthy
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    environment:
      # ========================================
      # 🔴 USE AS MESMAS CREDENCIAIS DO SERVICE "chatwoot"
      # ========================================
      
      DATABASE_URL: postgresql://postgres.SEU_PROJECT_REF:SUA_SENHA@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: COLE_AQUI_A_MESMA_CHAVE_DO_CHATWOOT
      
      # Rails
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "true"
      
      # Enterprise Edition
      CW_EDITION: ee
      
      # Performance
      SIDEKIQ_CONCURRENCY: "20"
      
    volumes:
      - app_storage:/app/storage
    networks:
      - chatwoot

volumes:
  redis_data:
    driver: local
  app_storage:
    driver: local
  app_public:
    driver: local

networks:
  chatwoot:
    driver: bridge
```

---

### 4️⃣ Deploy no Portainer

1. **Acesse Portainer**
2. **Stacks** → **Add stack**
3. **Nome**: `chatwoot-premium-unlocked`
4. **Cole a stack** acima
5. **IMPORTANTE**: Edite as 3 variáveis obrigatórias:
   - `DATABASE_URL` (do Supabase)
   - `SECRET_KEY_BASE` (gerada)
   - `FRONTEND_URL` (seu domínio)
6. **Deploy the stack**
7. **Aguarde ~3 minutos**

---

## 🔍 Verificar Deploy

```bash
# Ver logs
docker logs <container_name> -f

# Verificar saúde
docker ps | grep chatwoot

# Testar acesso
curl http://localhost:3000/health
```

---

## ✅ Checklist Pós-Deploy

- [ ] Container iniciou sem erros
- [ ] Logs não mostram erros de conexão
- [ ] Acesso via navegador funciona
- [ ] Login/registro funciona
- [ ] Vá em **Settings** → Verifique se NÃO HÁ CADEADOS
- [ ] Todas as features EE estão disponíveis

---

## 🔴 Problemas?

### Erro: "We're sorry, but something went wrong"

**Causa**: Problema de conexão com Supabase

**Solução**: Consulte o arquivo `TROUBLESHOOTING.md`

**Checklist rápido**:
1. ✅ Projeto Supabase está ATIVO (não pausado)?
2. ✅ Senha está correta?
3. ✅ Project REF está correto na URL?
4. ✅ Formato da URL está correto?

### Erro: "Tenant or user not found"

**Solução**:
1. Verifique se o projeto Supabase não está pausado
2. Vá em Supabase → Settings → Database
3. Copie a connection string novamente
4. Atualize a stack

### Features ainda com cadeado?

**Impossível!** A nova imagem tem TODOS os cadeados removidos.

**Se mesmo assim aparecer**:
1. Faça **logout**
2. Limpe cache do navegador (Ctrl+Shift+Del)
3. Faça **login** novamente
4. Pressione Ctrl+F5 na página Settings

---

## 📤 Upload da Imagem para GitHub Container Registry

Para disponibilizar a imagem publicamente:

```bash
# 1. Gere um GitHub Personal Access Token
# https://github.com/settings/tokens
# Permissões: write:packages, read:packages

# 2. Execute o script
./scripts/push-image.sh SEU_GITHUB_PAT

# 3. Imagem será publicada em:
# ghcr.io/jeronimokarasek/chatwoot_custon:latest
```

---

## 🎉 Sucesso!

Se seguiu todos os passos:
- ✅ Chatwoot rodando
- ✅ Conexão com Supabase OK
- ✅ TODAS as features EE desbloqueadas
- ✅ SEM cadeados em Settings
- ✅ Pronto para produção!

---

## 📞 Suporte

- **Logs de erro**: `docker logs <container> --tail 100`
- **Troubleshooting**: Veja `TROUBLESHOOTING.md`
- **Scripts**: Todos em `scripts/`
- **Documentação**: `README.md`

---

**💡 Dica**: Salve suas credenciais (DATABASE_URL, SECRET_KEY_BASE) em local seguro para futuras atualizações!