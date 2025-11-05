#!/bin/bash

# Script para fazer upload da imagem Docker para GitHub Container Registry
# Uso: ./push-image.sh [SEU_GITHUB_PAT]

set -e

echo "🚀 Script de Upload da Imagem Chatwoot Premium v4.7.0"
echo "=================================================="

# Verificar se o PAT foi fornecido
if [ -z "$1" ]; then
    echo "❌ Erro: Personal Access Token do GitHub não fornecido"
    echo ""
    echo "📋 Para criar um PAT:"
    echo "1. Vá para: https://github.com/settings/tokens"
    echo "2. Clique em 'Generate new token (classic)'"
    echo "3. Selecione as permissões: write:packages, read:packages"
    echo "4. Copie o token gerado"
    echo ""
    echo "💡 Uso: $0 SEU_GITHUB_PAT"
    exit 1
fi

GITHUB_PAT="$1"
REGISTRY="ghcr.io"
USERNAME="jeronimokarasek"
REPO_NAME="chatwoot_custon"
VERSION="v4.7.0"

echo "📦 Verificando se a imagem local existe..."
if ! docker image inspect "forochat/chatwoot-premium:${VERSION}" >/dev/null 2>&1; then
    echo "❌ Erro: Imagem forochat/chatwoot-premium:${VERSION} não encontrada"
    echo "   Execute primeiro: docker images | grep chatwoot"
    exit 1
fi

echo "✅ Imagem local encontrada!"

echo "🏷️ Criando tags para GHCR..."
docker tag "forochat/chatwoot-premium:${VERSION}" "${REGISTRY}/${USERNAME}/${REPO_NAME}:${VERSION}"
docker tag "forochat/chatwoot-premium:${VERSION}" "${REGISTRY}/${USERNAME}/${REPO_NAME}:latest"

echo "🔐 Fazendo login no GitHub Container Registry..."
echo "${GITHUB_PAT}" | docker login ${REGISTRY} -u ${USERNAME} --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Login realizado com sucesso!"
else
    echo "❌ Erro no login. Verifique seu PAT!"
    exit 1
fi

echo "📤 Fazendo upload da imagem ${VERSION}..."
docker push "${REGISTRY}/${USERNAME}/${REPO_NAME}:${VERSION}"

echo "📤 Fazendo upload da imagem latest..."
docker push "${REGISTRY}/${USERNAME}/${REPO_NAME}:latest"

echo ""
echo "🎉 Upload concluído com sucesso!"
echo ""
echo "📋 Informações da imagem:"
echo "   Repository: ghcr.io/${USERNAME}/${REPO_NAME}"
echo "   Tags: ${VERSION}, latest"
echo "   Tamanho: ~2.47GB"
echo ""
echo "🐳 Para usar a imagem:"
echo "   docker pull ghcr.io/${USERNAME}/${REPO_NAME}:${VERSION}"
echo ""
echo "🌐 Ver no GitHub:"
echo "   https://github.com/${USERNAME}/Chatwoot_custon/pkgs/container/${REPO_NAME}"

# Fazer logout por segurança
docker logout ${REGISTRY}
echo "🔒 Logout realizado por segurança"