# Guia de Solução de Problemas - Chatwoot Premium

## 🔴 Erro: "We're sorry, but something went wrong"

### Causa Principal
Erro de conexão com o banco de dados Supabase.

### Diagnóstico
```bash
# Verificar logs do container
docker logs <container_name> --tail 50 | grep -i error

# Erro comum:
# "connection to server failed: FATAL: Tenant or user not found"
```

---

## ✅ Solução 1: Verificar Credenciais do Supabase

### 1.1 Verificar String de Conexão

Sua string atual:
```
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
```

### 1.2 Validar Componentes

- **Host**: `aws-0-sa-east-1.pooler.supabase.com`
- **Porta**: `5432`
- **Database**: `postgres`
- **User**: `postgres.vfhzimozqsbdqknkncny`
- **Password**: `TqgcYbFD5EKGAQuo`

### 1.3 Obter Credenciais Corretas no Supabase

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Vá em: **Settings** → **Database**
4. Role até **Connection string** → **URI**
5. Copie a string completa

### 1.4 Formato Correto da String

```bash
# Formato Session Mode (Recomendado para aplicações)
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres

# Formato Transaction Mode (Para alta concorrência)
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres

# Formato Direct Connection (Sem pooler)
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

---

## ✅ Solução 2: Atualizar Stack com Nova Imagem Desbloqueada

### 2.1 Stack Portainer Atualizada

```yaml
version: '3.8'

services:
  chatwoot:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    environment:
      # ===== CONEXÃO SUPABASE - ATUALIZE AQUI =====
      DATABASE_URL: postgresql://postgres.SEU_PROJECT_REF:SUA_SENHA@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
      
      # ===== REDIS =====
      REDIS_URL: redis://redis:6379
      
      # ===== OBRIGATÓRIAS =====
      SECRET_KEY_BASE: sua-chave-secreta-unica
      FRONTEND_URL: https://seu-dominio.com
      
      # ===== INSTALAÇÃO =====
      INSTALLATION_NAME: MeuChatwoot
      DEFAULT_LOCALE: pt_BR
      ENABLE_ACCOUNT_SIGNUP: "true"
      
      # ===== FEATURES EE (JÁ DESBLOQUEADAS NA IMAGEM) =====
      CW_EDITION: ee
      CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES: "true"
    ports:
      - "3000:3000"
    depends_on:
      - redis

  sidekiq:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    environment:
      DATABASE_URL: postgresql://postgres.SEU_PROJECT_REF:SUA_SENHA@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: sua-chave-secreta-unica
      RAILS_ENV: production
      CW_EDITION: ee
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

### 2.2 Passos para Atualizar

1. **Copie a stack acima**
2. **Atualize a DATABASE_URL** com suas credenciais do Supabase
3. **Gere uma nova SECRET_KEY_BASE**:
   ```bash
   openssl rand -hex 64
   ```
4. **No Portainer**: 
   - Vá em Stacks → Sua Stack
   - Clique em **Editor**
   - Cole o novo conteúdo
   - Clique em **Update the stack**

---

## ✅ Solução 3: Testar Conexão Manualmente

### 3.1 Teste de Conexão Básico

```bash
# Instalar psql (se não tiver)
apt-get install -y postgresql-client

# Testar conexão
psql "postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require"
```

### 3.2 Teste via Docker

```bash
docker run --rm -it postgres:15-alpine psql \
  "postgresql://postgres.SEU_PROJECT_REF:SUA_SENHA@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require"
```

---

## ✅ Solução 4: Problemas Comuns do Supabase

### 4.1 Projeto Pausado

**Sintoma**: "Tenant or user not found"

**Solução**:
1. Acesse https://app.supabase.com
2. Verifique se o projeto está **pausado**
3. Se estiver, clique em **Resume project**
4. Aguarde ~2 minutos

### 4.2 IP Bloqueado

**Sintoma**: Connection timeout

**Solução**:
1. Vá em: **Settings** → **Database** → **Connection pooling**
2. Em **Restrict connections**, verifique se seu IP está permitido
3. Para permitir todos: adicione `0.0.0.0/0` (não recomendado em produção)

### 4.3 Pool de Conexões Esgotado

**Sintoma**: "Sorry, too many clients already"

**Solução**:
```yaml
# Use Transaction Mode na URL
DATABASE_URL: postgresql://postgres.[REF]:[PASS]@aws-0-[REGION].pooler.supabase.com:6543/postgres
```

### 4.4 Senha Incorreta

**Solução**:
1. Vá em: **Settings** → **Database** → **Database password**
2. Clique em **Reset database password**
3. Copie a nova senha
4. Atualize a DATABASE_URL na stack

---

## 🔓 Features EE Desbloqueadas

A nova imagem `ghcr.io/jeronimokarasek/chatwoot_custon:latest` já vem com:

✅ **Captain** - Conversas com IA  
✅ **Custom Branding** - Marca personalizada  
✅ **Agent Capacity** - Capacidade de agentes  
✅ **Audit Logs** - Logs de auditoria  
✅ **Help Center** - Central de ajuda  
✅ **SLA Management** - Gerenciamento de SLA  
✅ **All Channels** - Todos os canais (WhatsApp, Email, SMS, etc)  
✅ **Advanced Reports** - Relatórios avançados  
✅ **Automations** - Automações  
✅ **Custom Roles** - Funções personalizadas  
✅ **E muito mais!**

**Nenhum cadeado!** Todas as configurações em Settings estão liberadas!

---

## 📞 Suporte

### Verificar Logs
```bash
# Logs do app
docker logs <container_name> --tail 100 -f

# Logs do sidekiq
docker logs <sidekiq_container> --tail 100 -f
```

### Script de Diagnóstico
```bash
./scripts/diagnose.sh <container_name>
```

### Container Health Check
```bash
docker ps | grep chatwoot
docker exec <container_name> curl -f http://localhost:3000/health
```

---

## 🚀 Checklist de Deploy

- [ ] Credenciais do Supabase corretas
- [ ] Projeto Supabase ativo (não pausado)
- [ ] SECRET_KEY_BASE única e segura
- [ ] FRONTEND_URL configurada corretamente
- [ ] Redis funcionando
- [ ] Container iniciando sem erros
- [ ] Health check respondendo
- [ ] Login funcionando
- [ ] Features EE visíveis (sem cadeados)

---

## 📝 Exemplo de DATABASE_URL Funcionais

```bash
# Session Mode (Padrão - Recomendado)
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:SUA_SENHA_AQUI@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false

# Transaction Mode (Alta concorrência)
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:SUA_SENHA_AQUI@aws-0-sa-east-1.pooler.supabase.com:6543/postgres?sslmode=require&prepared_statements=false

# Direct Connection (Sem pooler)
DATABASE_URL=postgresql://postgres:SUA_SENHA_AQUI@db.vfhzimozqsbdqknkncny.supabase.co:5432/postgres?sslmode=require&prepared_statements=false
```

**⚠️ Importante**: Substitua `SUA_SENHA_AQUI` pela senha real do seu projeto Supabase!