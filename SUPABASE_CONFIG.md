# 🔐 Configuração Supabase - Credenciais Corretas

## ✅ Informações do Projeto

**Project Reference**: `vfhzimozqsbdqknkncny`  
**URL do Projeto**: `https://vfhzimozqsbdqknkncny.supabase.co`  
**Região**: `sa-east-1` (São Paulo, AWS)  
**Senha do Database**: `TqgcYbFD5EKGAQuo`

---

## 🔗 Strings de Conexão DATABASE_URL

### ✅ Opção 1: Session Mode (RECOMENDADO para Chatwoot)

```bash
# Use esta no seu docker-compose.yml ou Portainer Stack
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
```

**Características:**
- ✅ Melhor para aplicações como Chatwoot
- ✅ Conexões mantidas durante a sessão
- ✅ Porta: 5432
- ✅ SSL habilitado

---

### 🔄 Opção 2: Transaction Mode (Para alta concorrência)

```bash
# Use se tiver muitas conexões simultâneas
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:6543/postgres?sslmode=require&prepared_statements=false
```

**Características:**
- ⚡ Melhor para muitas conexões rápidas
- 🔄 Pool de transações
- 🔢 Porta: 6543

---

### 🎯 Opção 3: Conexão Direta (Sem pooler)

```bash
# Conexão direta ao banco (sem pooler)
DATABASE_URL=postgresql://postgres:TqgcYbFD5EKGAQuo@db.vfhzimozqsbdqknkncny.supabase.co:5432/postgres?sslmode=require&prepared_statements=false
```

**Características:**
- 📍 Conexão direta ao database
- ⚠️ Limite de conexões menor
- 🔢 Porta: 5432

---

## 🔑 API Keys Supabase

### Anon Key (Pública)
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmaHppbW96cXNiZHFrbmtuY255Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyODUyNzIsImV4cCI6MjA3Nzg2MTI3Mn0.WHNI01KdsXH_DO-B_LFHpUB71O2Ue_0CHKqcSfeiSOg
```

**Uso**: Frontend, aplicações públicas

### Service Role Key (Privada - NÃO EXPOR!)
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmaHppbW96cXNiZHFrbmtuY255Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjI4NTI3MiwiZXhwIjoyMDc3ODYxMjcyfQ.K3nhcO5Or1LQqwFFgW6BcNqxf4ne8Qp9M2cKxLrojUI
```

**Uso**: Backend, operações administrativas  
⚠️ **NUNCA exponha no frontend ou commit no Git!**

---

## 🚀 Stack Portainer PRONTA PARA USO

Copie e cole esta stack no Portainer (já com as credenciais corretas):

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
      # ✅ CONEXÃO SUPABASE (JÁ CONFIGURADA)
      # ========================================
      DATABASE_URL: postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
      
      # ========================================
      # 🔴 ATUALIZE APENAS ESTAS 2 VARIÁVEIS
      # ========================================
      
      # Redis
      REDIS_URL: redis://redis:6379
      
      # Secret Key - Gere uma nova com: openssl rand -hex 64
      SECRET_KEY_BASE: GERE_UMA_CHAVE_AQUI_COM_OPENSSL_RAND
      
      # Frontend URL - Seu domínio
      FRONTEND_URL: https://chat.seu-dominio.com
      
      # ========================================
      # ✅ CONFIGURAÇÕES PRONTAS
      # ========================================
      
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
      redis:
        condition: service_healthy
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    environment:
      # ========================================
      # ✅ MESMAS CREDENCIAIS DO CHATWOOT
      # ========================================
      DATABASE_URL: postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: USE_A_MESMA_CHAVE_DO_CHATWOOT_ACIMA
      
      # Rails
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "true"
      
      # Enterprise Edition
      CW_EDITION: ee
      
      # Performance
      SIDEKIQ_CONCURRENCY: "20"
      
      # Bundle
      BUNDLE_WITHOUT: development:test
      BUNDLE_FORCE_RUBY_PLATFORM: "1"
      BUNDLE_PATH: /gems
      
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

## 🎯 Checklist de Deploy

### 1. Gerar SECRET_KEY_BASE
```bash
openssl rand -hex 64
```
Copie o resultado e substitua na stack acima.

### 2. Atualizar FRONTEND_URL
Substitua `https://chat.seu-dominio.com` pelo seu domínio real.

### 3. Deploy no Portainer
1. Copie a stack acima
2. Portainer → Stacks → Add stack
3. Nome: `chatwoot-premium-unlocked`
4. Cole a stack
5. Atualize SECRET_KEY_BASE e FRONTEND_URL
6. Deploy!

### 4. Aguardar Inicialização
- ⏳ ~2-3 minutos para inicializar
- 📊 Monitore logs: `docker logs <container> -f`

### 5. Verificar
- ✅ Acesse http://seu-servidor:3000
- ✅ Faça login/registro
- ✅ Vá em Settings
- ✅ **NENHUM CADEADO!** Todas features disponíveis!

---

## 🔍 Teste de Conexão

### Método 1: Via Docker
```bash
docker run --rm -it postgres:15-alpine psql \
  "postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require"
```

### Método 2: Via psql local
```bash
psql "postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require"
```

**Resultado esperado**: Conexão estabelecida com sucesso!

---

## ⚠️ Segurança

### ✅ Boas Práticas

1. **Não commite credenciais** no Git
2. **Use variáveis de ambiente** sempre
3. **Service Role Key** só no backend
4. **Anon Key** pode ser pública
5. **Rotacione senhas** periodicamente

### 🔐 Rotação de Senha

Se precisar trocar a senha:
1. Supabase → Settings → Database
2. **Reset database password**
3. Copie a nova senha
4. Atualize DATABASE_URL na stack
5. Reinicie os containers

---

## 📊 Informações do Projeto Supabase

```
Project Name: vfhzimozqsbdqknkncny
Project URL: https://vfhzimozqsbdqknkncny.supabase.co
Region: South America (São Paulo) - sa-east-1
Database: PostgreSQL 15+
Pooler: PgBouncer (Session & Transaction modes)
SSL: Required (sslmode=require)
```

---

## ✅ Tudo Pronto!

Agora você tem:
- ✅ Strings de conexão corretas
- ✅ Stack Portainer configurada
- ✅ Credenciais organizadas
- ✅ Features EE desbloqueadas
- ✅ Pronto para deploy em produção!

**🚀 Basta copiar a stack e fazer deploy no Portainer!**