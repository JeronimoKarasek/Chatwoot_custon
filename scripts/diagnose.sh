#!/bin/bash

# Script para corrigir problemas de conexão do banco de dados

set -e

echo "🔧 Chatwoot Database Connection Fix"
echo "===================================="

CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Uso: $0 <nome_do_container>"
    echo ""
    echo "Para listar containers: docker ps | grep chatwoot"
    exit 1
fi

echo "🔍 Verificando logs de erro..."
docker logs "$CONTAINER_NAME" --tail 50 | grep -i "error\|failed" | tail -10

echo ""
echo "📋 Verificando variáveis de ambiente..."
docker exec "$CONTAINER_NAME" env | grep -E "DATABASE_URL|REDIS_URL|SECRET_KEY"

echo ""
echo "🔄 Testando conexão com banco de dados..."
docker exec "$CONTAINER_NAME" bundle exec rails runner 'puts "✅ Conexão OK: #{ActiveRecord::Base.connection.execute(\"SELECT version()\").first}" rescue puts "❌ Erro: #{$!.message}"'

echo ""
echo "🔄 Testando conexão com Redis..."
docker exec "$CONTAINER_NAME" bundle exec rails runner 'puts "✅ Redis OK: #{Redis.new(url: ENV[\"REDIS_URL\"]).ping}" rescue puts "❌ Erro: #{$!.message}"'

echo ""
echo "📊 Status do container:"
docker stats --no-stream "$CONTAINER_NAME"