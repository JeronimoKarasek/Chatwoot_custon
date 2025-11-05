# 🔴 PROBLEMA IDENTIFICADO E SOLUÇÃO

## Diagnóstico Completo

### ✅ O que está FUNCIONANDO:
1. **API REST do Supabase** - Totalmente operacional
2. **Projeto Supabase** - Ativo e respondendo
3. **Banco de Dados** - Conta "FocoChat" existe e está acessível via API
4. **Usuário SuperAdmin** - jeronimo.karasek@farolpromotora.com.br criado

### ❌ O que está FALHANDO:
1. **Connection Pooler (porta 6543)** - Erro: "Tenant or user not found"
2. **Conexão Direta PostgreSQL (porta 5432)** - Erro: "Network unreachable"

## 🎯 CAUSA RAIZ DO PROBLEMA

O Supabase tem **3 formas de conexão ao banco de dados**:

### 1. Transaction Mode (Session Pooler) ❌
```
postgresql://postgres.vfhzimozqsbdqknkncny:PASSWORD@aws-0-sa-east-1.pooler.supabase.com:6543/postgres
```
**Status**: FALHA - "Tenant or user not found"

### 2. Session Mode (Connection Pooler) ❌
```
postgresql://postgres.vfhzimozqsbdqknkncny:PASSWORD@aws-0-sa-east-1.pooler.supabase.com:5432/postgres
```
**Status**: FALHA - "Network unreachable"

### 3. Conexão Direta ❌
```
postgresql://postgres.vfhzimozqsbdqknkncny:PASSWORD@db.vfhzimozqsbdqknkncny.supabase.co:5432/postgres
```
**Status**: FALHA - "Network unreachable"

## 🔍 RAZÃO DO ERRO

O erro "Tenant or user not found" ocorre porque:

1. **Formato de usuário incorreto** no Supabase
   - ❌ NÃO use: `postgres.vfhzimozqsbdqknkncny`
   - ✅ USE: `postgres`

2. **Porta incorreta para Transaction Mode**
   - ❌ NÃO use porta 6543 (é para Session Mode)
   - ✅ USE porta 6543 com modo de transação

3. **IPv6 não habilitado** no servidor
   - O DNS retorna IPv6 primeiro
   - Servidor atual não tem suporte IPv6

## ✅ SOLUÇÃO DEFINITIVA

### Opção 1: Corrigir String de Conexão (RECOMENDADO)

Use este formato exato:

```bash
# Transaction Mode Pooler (Recomendado para Rails/Chatwoot)
DATABASE_URL=postgresql://postgres:[PASSWORD]@db.vfhzimozqsbdqknkncny.supabase.co:6543/postgres?pgbouncer=true

# Parâmetros importantes:
# - Usuário: postgres (SEM o sufixo .PROJECT_REF)
# - Host: db.PROJECT_REF.supabase.co
# - Porta: 6543 (Transaction Mode)
# - Parâmetro: ?pgbouncer=true (indica uso do pooler)
```

### Opção 2: Usar PostgreSQL Local

Se a conexão Supabase continuar falhando, use o stack local documentado em:
- `URGENT_DATABASE_FIX.md`

## 🔧 PASSOS PARA RESOLVER

### Passo 1: Verificar Senha no Dashboard Supabase

1. Acesse: https://supabase.com/dashboard/project/vfhzimozqsbdqknkncny/settings/database
2. Role até "Database password"
3. Clique em "Reset Database Password"
4. Copie a nova senha
5. Salve em local seguro

### Passo 2: Testar Conexão com a Nova Senha

```bash
#!/bin/bash

# Substituir PASSWORD pela senha real do passo 1
NEW_PASSWORD="sua_senha_aqui"

# Teste com usuário correto
docker run --rm postgres:15-alpine psql \
  "postgresql://postgres:${NEW_PASSWORD}@db.vfhzimozqsbdqknkncny.supabase.co:6543/postgres?pgbouncer=true" \
  -c "SELECT current_database(), current_user, version();"
```

### Passo 3: Atualizar docker-compose.yml

```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server
    volumes:
      - redis_data:/data
    networks:
      - chatwoot

  chatwoot:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    depends_on:
      - redis
    ports:
      - "3000:3000"
    environment:
      # ✅ String de conexão CORRETA
      DATABASE_URL: postgresql://postgres:SUA_SENHA_AQUI@db.vfhzimozqsbdqknkncny.supabase.co:6543/postgres?pgbouncer=true
      
      REDIS_URL: redis://redis:6379
      
      # Rails
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "true"
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      
      # Chatwoot Enterprise Edition (UNLOCKED)
      INSTALLATION_NAME: FocoChat
      CHATWOOT_EDITION: ee
      FORCE_SSL: "false"
      
      # Frontend
      FRONTEND_URL: http://localhost:3000
      
    networks:
      - chatwoot
    command: >
      sh -c "
        bundle exec rails db:chatwoot_prepare &&
        bundle exec rails server -b 0.0.0.0
      "

  sidekiq:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    depends_on:
      - redis
    environment:
      DATABASE_URL: postgresql://postgres:SUA_SENHA_AQUI@db.vfhzimozqsbdqknkncny.supabase.co:6543/postgres?pgbouncer=true
      REDIS_URL: redis://redis:6379
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      INSTALLATION_NAME: FocoChat
      CHATWOOT_EDITION: ee
    networks:
      - chatwoot
    command: bundle exec sidekiq -C config/sidekiq.yml

networks:
  chatwoot:
    driver: bridge

volumes:
  redis_data:
```

### Passo 4: Gerar SECRET_KEY_BASE

```bash
# Gerar chave secreta
SECRET_KEY=$(docker run --rm ghcr.io/jeronimokarasek/chatwoot_custon:latest bundle exec rake secret)

# Criar arquivo .env
cat > .env << EOF
SECRET_KEY_BASE=${SECRET_KEY}
EOF

echo "✅ Arquivo .env criado com SECRET_KEY_BASE"
```

### Passo 5: Iniciar Stack

```bash
# Parar containers antigos
docker-compose down -v

# Iniciar com nova configuração
docker-compose up -d

# Acompanhar logs
docker-compose logs -f chatwoot
```

## 🔄 ALTERNATIVA: PostgreSQL Local

Se mesmo assim não funcionar, use o PostgreSQL local:

```bash
# Usar o docker-compose.local-db.yml
docker-compose -f docker-compose.local-db.yml up -d
```

O arquivo `docker-compose.local-db.yml` já está documentado em `URGENT_DATABASE_FIX.md`.

## 📊 Checklist de Verificação

- [ ] Resetar senha do banco no dashboard Supabase
- [ ] Testar conexão com `psql` usando o formato correto
- [ ] Atualizar DATABASE_URL no docker-compose.yml
- [ ] Gerar novo SECRET_KEY_BASE
- [ ] Limpar volumes antigos (`docker-compose down -v`)
- [ ] Iniciar stack (`docker-compose up -d`)
- [ ] Verificar logs (`docker-compose logs -f chatwoot`)
- [ ] Acessar http://localhost:3000

## 🆘 Se Ainda Não Funcionar

**Motivos possíveis:**

1. **Firewall** bloqueando porta 6543
   - Solução: Use PostgreSQL local

2. **Projeto Supabase pausado**
   - Solução: Ative no dashboard

3. **Plano Supabase Free com limitações**
   - Solução: Upgrade para plano pago ou use local

4. **IPv6 obrigatório no Supabase**
   - Solução: Habilite IPv6 no servidor ou use local

## 💡 RECOMENDAÇÃO FINAL

**Para produção**: Use PostgreSQL local (mais confiável)
**Para testes**: Pode usar Supabase após resolver autenticação

---

**Criado**: 05/11/2025  
**Última atualização**: Após diagnóstico completo via API
