#!/bin/bash

# Script para build da imagem Docker do Chatwoot customizado
# Uso: ./build_image.sh [tag]

set -e

# Configurações
REGISTRY="ghcr.io"
OWNER="jeronimokarasek"
IMAGE_NAME="chatwoot_custon"
DEFAULT_TAG="latest"

# Usar tag fornecida ou padrão
TAG="${1:-$DEFAULT_TAG}"
FULL_IMAGE="${REGISTRY}/${OWNER}/${IMAGE_NAME}:${TAG}"

echo "=========================================="
echo "🐳 Build Chatwoot Custom Docker Image"
echo "=========================================="
echo ""
echo "📦 Imagem: ${FULL_IMAGE}"
echo ""

# Verificar se Docker está disponível
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado!"
    exit 1
fi

echo "🔨 Iniciando build..."
echo "⏳ Isso pode levar 10-20 minutos..."
echo ""

# Build da imagem
docker build \
    --tag "${FULL_IMAGE}" \
    --build-arg CHATWOOT_VERSION=v3.13.0 \
    --progress=plain \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ BUILD CONCLUÍDO COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "📦 Imagem criada: ${FULL_IMAGE}"
    echo ""
    echo "🚀 Próximos passos:"
    echo ""
    echo "1. Testar localmente:"
    echo "   docker run -d -p 3000:3000 \\"
    echo "     -e DATABASE_URL='postgresql://...' \\"
    echo "     -e REDIS_URL='redis://...' \\"
    echo "     -e SECRET_KEY_BASE='...' \\"
    echo "     -e FRONTEND_URL='http://localhost:3000' \\"
    echo "     ${FULL_IMAGE}"
    echo ""
    echo "2. Push para registry:"
    echo "   docker push ${FULL_IMAGE}"
    echo ""
    echo "3. Ou use o script de push:"
    echo "   ./push_to_ghcr.sh"
    echo ""
else
    echo ""
    echo "❌ ERRO NO BUILD!"
    echo ""
    echo "Verifique os logs acima para mais detalhes."
    exit 1
fi
