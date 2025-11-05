#!/bin/bash

# Script para fazer push da imagem Chatwoot customizada para o GHCR
# Uso: ./push_to_ghcr.sh [GITHUB_TOKEN]

set -e

IMAGE_NAME="ghcr.io/jeronimokarasek/chatwoot_custon:latest"
LOCAL_IMAGE="chatwoot_unlocked:v2"

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
    echo "2. Marque: write:packages, read:packages, delete:packages"
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
if docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1; then
    echo "✅ Imagem local encontrada: $LOCAL_IMAGE"
else
    echo "❌ Imagem local não encontrada: $LOCAL_IMAGE"
    exit 1
fi

echo ""
echo "🔐 Fazendo login no GHCR..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u jeronimokarasek --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Login bem sucedido!"
else
    echo "❌ Falha no login!"
    exit 1
fi

echo ""
echo "🏷️  Tagueando imagem..."
docker tag "$LOCAL_IMAGE" "$IMAGE_NAME"
echo "✅ Imagem tagueada: $IMAGE_NAME"

echo ""
echo "⬆️  Fazendo push para GHCR..."
echo "   Isso pode levar alguns minutos..."
docker push "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ SUCESSO! Imagem enviada para GHCR"
    echo "=========================================="
    echo ""
    echo "📦 Imagem disponível em:"
    echo "   $IMAGE_NAME"
    echo ""
    echo "🔄 Para atualizar o serviço Swarm:"
    echo "   docker service update --image $IMAGE_NAME chatv44_chatwoot_app --force"
    echo ""
    echo "🌐 Visualize em:"
    echo "   https://github.com/JeronimoKarasek?tab=packages"
else
    echo ""
    echo "❌ Falha ao fazer push da imagem!"
    exit 1
fi
