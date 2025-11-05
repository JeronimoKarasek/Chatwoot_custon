#!/bin/bash

# Script para testar conexão com Supabase

set -e

echo "🔍 Testando Conexão com Supabase"
echo "================================="
echo ""

# Credenciais
PROJECT_REF="vfhzimozqsbdqknkncny"
PASSWORD="TqgcYbFD5EKGAQuo"
HOST="aws-0-sa-east-1.pooler.supabase.com"
PORT="5432"
DATABASE="postgres"

echo "📋 Informações do Banco:"
echo "  Project: $PROJECT_REF"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Database: $DATABASE"
echo ""

# String de conexão completa
CONNECTION_STRING="postgresql://postgres.${PROJECT_REF}:${PASSWORD}@${HOST}:${PORT}/${DATABASE}?sslmode=require"

echo "🔗 String de Conexão:"
echo "  $CONNECTION_STRING"
echo ""

# Teste 1: Conexão básica
echo "📡 Teste 1: Conexão básica via psql..."
if command -v psql &> /dev/null; then
    echo "  ✅ psql encontrado, testando..."
    if psql "$CONNECTION_STRING" -c "SELECT version();" 2>&1 | grep -q "PostgreSQL"; then
        echo "  ✅ Conexão bem-sucedida!"
        psql "$CONNECTION_STRING" -c "SELECT version();"
    else
        echo "  ❌ Falha na conexão"
        psql "$CONNECTION_STRING" -c "SELECT version();" 2>&1 || true
    fi
else
    echo "  ⚠️  psql não instalado, pulando..."
fi

echo ""

# Teste 2: Conexão via Docker
echo "📦 Teste 2: Conexão via Docker..."
if docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -c "SELECT 'Conexão OK!' as status, current_database(), current_user, version();" 2>&1 | grep -q "Conexão OK"; then
    echo "  ✅ Conexão via Docker bem-sucedida!"
    docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -c "SELECT 'Conexão OK!' as status, current_database() as database, current_user as user;"
else
    echo "  ❌ Falha na conexão via Docker"
    docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -c "SELECT 1;" 2>&1 || true
fi

echo ""

# Teste 3: Testar tabelas do Chatwoot
echo "🗄️  Teste 3: Verificando tabelas do Chatwoot..."
TABLES=$(docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
TABLES=$(echo $TABLES | xargs)

if [ "$TABLES" -gt "0" ]; then
    echo "  ✅ Banco contém $TABLES tabelas"
    echo "  📋 Principais tabelas:"
    docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name LIMIT 10;" 2>/dev/null || true
else
    echo "  ⚠️  Banco vazio ou não contém tabelas do Chatwoot"
    echo "  💡 Isso é normal se for a primeira instalação"
fi

echo ""

# Teste 4: Verificar permissões
echo "🔐 Teste 4: Verificando permissões do usuário..."
docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -c "SELECT 
    current_user as usuario,
    current_database() as database,
    inet_server_addr() as server_ip,
    inet_server_port() as server_port,
    pg_backend_pid() as backend_pid;" 2>/dev/null || echo "  ❌ Erro ao verificar permissões"

echo ""

# Teste 5: Status da conexão
echo "📊 Teste 5: Status do pooler..."
docker run --rm postgres:15-alpine psql "$CONNECTION_STRING" -c "SELECT 
    COUNT(*) as conexoes_ativas 
FROM pg_stat_activity 
WHERE datname = 'postgres';" 2>/dev/null || echo "  ⚠️  Não foi possível verificar conexões"

echo ""
echo "================================="
echo "✅ Testes Concluídos!"
echo ""
echo "📋 Resumo:"
echo "  Connection String para usar no Chatwoot:"
echo "  DATABASE_URL=$CONNECTION_STRING&prepared_statements=false"
echo ""
echo "  ou com prepared_statements desabilitado:"
echo "  DATABASE_URL=postgresql://postgres.${PROJECT_REF}:${PASSWORD}@${HOST}:${PORT}/${DATABASE}?sslmode=require&prepared_statements=false"
echo ""
echo "💡 Se todos os testes passaram, sua conexão está OK!"
echo "   Use a string acima no seu docker-compose.yml ou Portainer stack"