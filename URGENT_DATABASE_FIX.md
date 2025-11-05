# 🚨 AÇÃO URGENTE: Resolver Erro de Conexão Supabase

## ❌ Problema Atual

Erro ao acessar Chatwoot:
```
We're sorry, but something went wrong.
If you are the application owner check the logs for more information.
```

**Causa:** Conexão com banco de dados Supabase falhando

---

## 🔍 Diagnóstico

### Senhas Testadas (NENHUMA FUNCIONOU):
- ❌ `TqgcYbFD5EKGAQuo` (senha antiga)
- ❌ `fh8eIGFps5xpVE0g` (senha resetada hoje)

### Erro nos Logs:
```
FATAL: Tenant or user not found
```

---

## ✅ SOLUÇÃO: 3 Opções

### 🎯 OPÇÃO 1: Reativar Supabase (RECOMENDADO)

#### Passo 1: Acessar Dashboard
```
https://app.supabase.com/project/vfhzimozqsbdqknkncny
```

#### Passo 2: Verificar Status
- ❌ Se aparecer "Project paused" ou "Inactive"
- ✅ Clique em **"Resume project"** ou **"Restore project"**
- ⏳ Aguarde 2-3 minutos

#### Passo 3: Obter Connection String Oficial
1. No dashboard → **Settings** → **Database**
2. Role até **"Connection string"**
3. Selecione **"URI"** (não "Connection parameters")
4. Mode: **"Session"** (para Chatwoot)
5. **COPIE** a string completa exatamente como aparece
6. **ANOTE** também a senha do database

#### Passo 4: Atualizar Stack
Com a connection string correta do dashboard, atualize sua stack no Portainer

---

### 🔄 OPÇÃO 2: Usar Banco PostgreSQL Local

Se o Supabase continuar com problemas, você pode usar PostgreSQL local:

#### Stack com PostgreSQL Local:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: chatwoot
      POSTGRES_USER: chatwoot
      POSTGRES_PASSWORD: Foco2025Seguro
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - chatwoot
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U chatwoot"]
      interval: 30s
      timeout: 10s
      retries: 5
    ports:
      - "5432:5432"

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
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      # ✅ BANCO LOCAL (mais confiável!)
      DATABASE_URL: postgresql://chatwoot:Foco2025Seguro@postgres:5432/chatwoot?sslmode=disable&prepared_statements=false
      
      # Redis
      REDIS_URL: redis://redis:6379
      
      # 🔴 ATUALIZE ESTAS VARIÁVEIS
      SECRET_KEY_BASE: GERE_COM_OPENSSL_RAND_HEX_64
      FRONTEND_URL: https://chat.seu-dominio.com
      
      # Instalação
      INSTALLATION_NAME: FocoChat
      DEFAULT_LOCALE: pt_BR
      ENABLE_ACCOUNT_SIGNUP: "true"
      
      # Rails
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "true"
      RAILS_SERVE_STATIC_FILES: "true"
      RAILS_MAX_THREADS: "7"
      WEB_CONCURRENCY: "4"
      
      # Enterprise Edition (Todas features desbloqueadas!)
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
      EXECJS_RUNTIME: Disabled
      
      # Bundle
      BUNDLE_WITHOUT: development:test
      BUNDLE_FORCE_RUBY_PLATFORM: "1"
      BUNDLE_PATH: /gems
      
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
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    environment:
      DATABASE_URL: postgresql://chatwoot:Foco2025Seguro@postgres:5432/chatwoot?sslmode=disable&prepared_statements=false
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: USE_A_MESMA_CHAVE_DO_CHATWOOT
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "true"
      CW_EDITION: ee
      SIDEKIQ_CONCURRENCY: "20"
      BUNDLE_WITHOUT: development:test
      BUNDLE_FORCE_RUBY_PLATFORM: "1"
      BUNDLE_PATH: /gems
    volumes:
      - app_storage:/app/storage
    networks:
      - chatwoot

volumes:
  postgres_data:
    driver: local
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

**Vantagens:**
- ✅ Banco roda no mesmo servidor (mais rápido)
- ✅ Sem dependência de serviços externos
- ✅ Mais controle sobre backups
- ✅ Sem risco de pausar

---

### 🔧 OPÇÃO 3: Migrar de Supabase para PostgreSQL Local

Se você já tem dados no Supabase e quer migrar:

```bash
# 1. Fazer backup do Supabase (quando estiver ativo)
pg_dump "postgresql://postgres.vfhzimozqsbdqknkncny:[SENHA]@aws-0-sa-east-1.pooler.supabase.com:5432/postgres" > backup_supabase.sql

# 2. Subir PostgreSQL local (use stack da Opção 2)

# 3. Restaurar backup
docker exec -i <postgres_container> psql -U chatwoot chatwoot < backup_supabase.sql
```

---

## 📋 Checklist de Decisão

### Use Supabase SE:
- [ ] Projeto está ativo e acessível
- [ ] Connection string funciona
- [ ] Você quer banco gerenciado na nuvem
- [ ] Não se importa com dependência externa

### Use PostgreSQL Local SE:
- [ ] Supabase continua com problemas
- [ ] Quer mais controle e performance
- [ ] Prefere banco no mesmo servidor
- [ ] Quer simplicidade no deploy

---

## 🎯 Recomendação

### Para Produção Imediata:
**Use PostgreSQL Local (Opção 2)**
- Mais confiável
- Mais rápido
- Sem dependências externas
- Deploy imediato

### Para Longo Prazo:
**Resolva o Supabase (Opção 1)**
- Backups automáticos
- Escalabilidade
- Gerenciamento facilitado

---

## 🚀 Deploy Rápido com PostgreSQL Local

1. **Copie** a stack da Opção 2 acima
2. **Gere SECRET_KEY_BASE**:
   ```bash
   openssl rand -hex 64
   ```
3. **Atualize** SECRET_KEY_BASE e FRONTEND_URL
4. **Deploy** no Portainer
5. **Aguarde** 3 minutos
6. **Acesse** e configure!

---

## 📞 Me Envie

Para eu te ajudar melhor, me envie:

1. **Status do Supabase:**
   - Está ativo ou pausado?
   - Screenshot se possível

2. **Connection String Oficial:**
   - Do dashboard Supabase (Settings → Database)
   - Copie e cole aqui

3. **Senha Atual:**
   - A senha exibida no dashboard
   - Ou a nova senha após reset

4. **Preferência:**
   - Quer continuar com Supabase?
   - Ou prefere PostgreSQL local?

---

## ⚡ Ação Imediata

**ENQUANTO VERIFICA O SUPABASE:**

Teste a stack com PostgreSQL local (Opção 2) para já ter o Chatwoot funcionando!

Depois, se o Supabase funcionar, você pode migrar de volta.

---

**🎯 Objetivo: Ter Chatwoot funcionando AGORA, com todas features desbloqueadas!**