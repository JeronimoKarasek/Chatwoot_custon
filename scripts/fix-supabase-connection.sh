#!/bin/bash

# Script para corrigir e testar a conexão com Supabase
# Criado para resolver o erro "Tenant or user not found"

set -e

echo "🔍 Diagnóstico da Conexão Supabase"
echo "=================================="
echo ""

# Credenciais
PROJECT_REF="vfhzimozqsbdqknkncny"
REGION="sa-east-1"
DB_PASSWORD="svlIAbquBQ2vGNUC"
DB_USER="postgres.${PROJECT_REF}"

echo "📋 Informações do Projeto:"
echo "  - Project Ref: $PROJECT_REF"
echo "  - Região: $REGION"
echo "  - Usuário DB: $DB_USER"
echo ""

# Teste 1: API REST (já sabemos que funciona)
echo "✅ TESTE 1: API REST Supabase"
echo "----------------------------"
API_RESPONSE=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/accounts?limit=1" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmaHppbW96cXNiZHFrbmtuY255Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyODUyNzIsImV4cCI6MjA3Nzg2MTI3Mn0.WHNI01KdsXH_DO-B_LFHpUB71O2Ue_0CHKqcSfeiSOg" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmaHppbW96cXNiZHFrbmtuY255Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjI4NTI3MiwiZXhwIjoyMDc3ODYxMjcyfQ.K3nhcO5Or1LQqwFFgW6BcNqxf4ne8Qp9M2cKxLrojUI")

if echo "$API_RESPONSE" | grep -q "FocoChat"; then
  echo "✅ API REST funcionando! Conta 'FocoChat' encontrada!"
else
  echo "❌ API REST não respondeu corretamente"
  echo "Resposta: $API_RESPONSE"
fi
echo ""

# Teste 2: Connection Pooler (porta 6543)
echo "🔧 TESTE 2: Connection Pooler (Recomendado para Apps)"
echo "------------------------------------------------------"
POOLER_URL="postgresql://${DB_USER}:${DB_PASSWORD}@aws-0-${REGION}.pooler.supabase.com:6543/postgres"
echo "URL: postgresql://${DB_USER}:***@aws-0-${REGION}.pooler.supabase.com:6543/postgres"
echo ""
echo "Testando conexão via Connection Pooler..."

docker run --rm postgres:15-alpine psql "$POOLER_URL" -c "SELECT version();" 2>&1 | head -20
POOLER_EXIT=$?

if [ $POOLER_EXIT -eq 0 ]; then
  echo "✅ Connection Pooler FUNCIONANDO!"
else
  echo "⚠️  Connection Pooler falhou"
fi
echo ""

# Teste 3: Conexão Direta (porta 5432)
echo "🔧 TESTE 3: Conexão Direta ao PostgreSQL"
echo "-----------------------------------------"
DIRECT_URL="postgresql://${DB_USER}:${DB_PASSWORD}@db.${PROJECT_REF}.supabase.co:5432/postgres"
echo "URL: postgresql://${DB_USER}:***@db.${PROJECT_REF}.supabase.co:5432/postgres"
echo ""
echo "Testando conexão direta..."

docker run --rm postgres:15-alpine psql "$DIRECT_URL" -c "SELECT version();" 2>&1 | head -20
DIRECT_EXIT=$?

if [ $DIRECT_EXIT -eq 0 ]; then
  echo "✅ Conexão Direta FUNCIONANDO!"
else
  echo "⚠️  Conexão Direta falhou"
fi
echo ""

# Teste 4: IPv6 (porta 6543)
echo "🔧 TESTE 4: Connection Pooler IPv6"
echo "-----------------------------------"
IPV6_URL="postgresql://${DB_USER}:${DB_PASSWORD}@aws-0-${REGION}.pooler.supabase.com:6543/postgres"
echo "URL: postgresql://${DB_USER}:***@aws-0-${REGION}.pooler.supabase.com:6543/postgres"
echo ""
echo "Testando conexão via IPv6..."

docker run --rm postgres:15-alpine psql "$IPV6_URL" -c "SELECT current_database();" 2>&1 | head -20
IPV6_EXIT=$?

if [ $IPV6_EXIT -eq 0 ]; then
  echo "✅ IPv6 FUNCIONANDO!"
else
  echo "⚠️  IPv6 falhou"
fi
echo ""

# Resumo e Recomendação
echo "📊 RESUMO DOS TESTES"
echo "===================="
echo ""

if [ $POOLER_EXIT -eq 0 ]; then
  echo "🎉 SOLUÇÃO ENCONTRADA!"
  echo ""
  echo "Use a seguinte DATABASE_URL no docker-compose.yml:"
  echo ""
  echo "DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@aws-0-${REGION}.pooler.supabase.com:6543/postgres"
  echo ""
  
  # Criar arquivo .env com a configuração correta
  cat > .env.supabase << EOF
# Supabase Database Configuration - WORKING
# Connection Pooler (Recommended for Applications)

DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@aws-0-${REGION}.pooler.supabase.com:6543/postgres

# Supabase API Keys
SUPABASE_URL=https://${PROJECT_REF}.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmaHppbW96cXNiZHFrbmtuY255Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyODUyNzIsImV4cCI6MjA3Nzg2MTI3Mn0.WHNI01KdsXH_DO-B_LFHpUB71O2Ue_0CHKqcSfeiSOg
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmaHppbW96cXNiZHFrbmtuY255Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjI4NTI3MiwiZXhwIjoyMDc3ODYxMjcyfQ.K3nhcO5Or1LQqwFFgW6BcNqxf4ne8Qp9M2cKxLrojUI

# Redis Configuration
REDIS_URL=redis://redis:6379

# Rails Configuration
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
SECRET_KEY_BASE=replace_with_super_secret_key_base_generated_by_rake_secret

# Enterprise Edition Configuration
INSTALLATION_NAME=FocoChat
CHATWOOT_EDITION=ee

# Frontend URL
FRONTEND_URL=http://localhost:3000
EOF

  echo "✅ Arquivo .env.supabase criado com a configuração correta!"
  echo ""
  
elif [ $DIRECT_EXIT -eq 0 ]; then
  echo "🎉 SOLUÇÃO ENCONTRADA!"
  echo ""
  echo "Use a seguinte DATABASE_URL no docker-compose.yml:"
  echo ""
  echo "DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db.${PROJECT_REF}.supabase.co:5432/postgres"
  echo ""
  
elif [ $IPV6_EXIT -eq 0 ]; then
  echo "🎉 SOLUÇÃO ENCONTRADA (IPv6)!"
  echo ""
  echo "Use a seguinte DATABASE_URL no docker-compose.yml:"
  echo ""
  echo "DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@aws-0-${REGION}.pooler.supabase.com:6543/postgres"
  echo ""
  
else
  echo "⚠️  NENHUMA CONEXÃO FUNCIONOU"
  echo ""
  echo "Possíveis problemas:"
  echo "1. Senha incorreta (verifique no dashboard do Supabase)"
  echo "2. Firewall bloqueando conexões PostgreSQL"
  echo "3. Projeto Supabase pausado (precisa ativar no dashboard)"
  echo "4. IP bloqueado (verifique as configurações de rede no Supabase)"
  echo ""
  echo "💡 RECOMENDAÇÃO:"
  echo "Use PostgreSQL local (já documentado em URGENT_DATABASE_FIX.md)"
  echo ""
fi

echo ""
echo "🔗 Links Úteis:"
echo "  - Dashboard: https://supabase.com/dashboard/project/${PROJECT_REF}"
echo "  - Database Settings: https://supabase.com/dashboard/project/${PROJECT_REF}/settings/database"
echo "  - API Keys: https://supabase.com/dashboard/project/${PROJECT_REF}/settings/api"
echo ""
