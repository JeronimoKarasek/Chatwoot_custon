#!/bin/bash

# Script para fazer push da imagem Chatwoot customizada para o GHCR
# Uso: ./push_to_ghcr.sh [GITHUB_TOKEN] [TAG]

set -e

# Configurações
REGISTRY="ghcr.io"
OWNER="jeronimokarasek"
IMAGE_NAME="chatwoot_custon"
TAG="${2:-latest}"
FULL_IMAGE="${REGISTRY}/${OWNER}/${IMAGE_NAME}:${TAG}"

echo "=========================================="
echo "🚀 Push Chatwoot Custom para GHCR"
echo "=========================================="
echo ""

# Verificar se o token foi passado como argumento
if [ -n "$1" ]; then
    GITHUB_TOKEN="$1"
    echo "✅ Token fornecido via argumento"
elif [ -n "$GITHUB_TOKEN" ]; then
    echo "✅ Token encontrado em variável de ambiente"
else
    echo "❌ Token não encontrado!"
    echo ""
    echo "Para gerar um token:"
    echo "1. Acesse: https://github.com/settings/tokens/new"
    echo "2. Marque: write:packages, read:packages"
    echo "3. Gere o token e execute:"
    echo "   export GITHUB_TOKEN='seu_token_aqui'"
    echo "   ./push_to_ghcr.sh"
    echo ""
    echo "Ou execute diretamente:"
    echo "   ./push_to_ghcr.sh 'seu_token_aqui'"
    exit 1
fi

echo ""
echo "📦 Verificando imagem local..."
if docker image inspect "$FULL_IMAGE" >/dev/null 2>&1; then
    echo "✅ Imagem local encontrada: $FULL_IMAGE"
else
    echo "❌ Imagem local não encontrada: $FULL_IMAGE"
    echo ""
    echo "💡 Execute primeiro o build:"
    echo "   ./build_image.sh ${TAG}"
    exit 1
fi

echo ""
echo "🔐 Fazendo login no GHCR..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "${OWNER}" --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Login bem sucedido!"
else
    echo "❌ Falha no login!"
    exit 1
fi

echo ""
echo "⬆️  Fazendo push para GHCR..."
echo "   Imagem: $FULL_IMAGE"
echo "   Isso pode levar alguns minutos..."
echo ""
docker push "$FULL_IMAGE"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ SUCESSO! Imagem enviada para GHCR"
    echo "=========================================="
    echo ""
    echo "📦 Imagem disponível em:"
    echo "   $FULL_IMAGE"
    echo ""
    echo "🔄 Para usar em Portainer/Docker Swarm/Compose:"
    echo "   Use a imagem: $FULL_IMAGE"
    echo ""
    echo "🌐 Visualize em:"
    echo "   https://github.com/${OWNER}/${IMAGE_NAME}/pkgs/container/${IMAGE_NAME}"
    echo ""
    echo "📥 Para baixar em outro servidor:"
    echo "   docker pull $FULL_IMAGE"
    echo ""
else
    echo ""
    echo "❌ Falha ao fazer push da imagem!"
    exit 1
fi
