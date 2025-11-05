#!/bin/bash

# Script de backup do Chatwoot
# Uso: ./backup.sh [diretório_destino]

set -e

BACKUP_DIR="${1:-./backups}"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="chatwoot_backup_${DATE}"

echo "💾 Chatwoot Backup Script"
echo "========================"

# Criar diretório de backup
mkdir -p "${BACKUP_DIR}"

echo "📦 Criando backup: ${BACKUP_NAME}"

# Backup do banco PostgreSQL
echo "🗄️ Fazendo backup do banco de dados..."
docker compose exec -T postgres pg_dump -U postgres chatwoot > "${BACKUP_DIR}/${BACKUP_NAME}_database.sql"

# Backup dos volumes
echo "📁 Fazendo backup dos volumes..."
docker run --rm -v "$(pwd)"_postgres_data:/data -v "${PWD}/${BACKUP_DIR}:/backup" alpine tar czf "/backup/${BACKUP_NAME}_postgres_data.tar.gz" -C /data .
docker run --rm -v "$(pwd)"_app_storage:/data -v "${PWD}/${BACKUP_DIR}:/backup" alpine tar czf "/backup/${BACKUP_NAME}_app_storage.tar.gz" -C /data .

# Backup das configurações
echo "⚙️ Fazendo backup das configurações..."
tar czf "${BACKUP_DIR}/${BACKUP_NAME}_configs.tar.gz" docker-compose.yml .env 2>/dev/null || true

echo "✅ Backup concluído!"
echo ""
echo "📋 Arquivos criados:"
echo "   Database: ${BACKUP_DIR}/${BACKUP_NAME}_database.sql"
echo "   Storage:  ${BACKUP_DIR}/${BACKUP_NAME}_app_storage.tar.gz"
echo "   Postgres: ${BACKUP_DIR}/${BACKUP_NAME}_postgres_data.tar.gz"
echo "   Configs:  ${BACKUP_DIR}/${BACKUP_NAME}_configs.tar.gz"
echo ""
echo "💡 Para restaurar, use: ./restore.sh ${BACKUP_NAME}"