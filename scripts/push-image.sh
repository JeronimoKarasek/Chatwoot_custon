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
UNLOCKED_IMAGE="forochat/chatwoot-premium:v4.7.0-unlocked"

echo "📦 Verificando se as imagens locais existem..."
if ! docker image inspect "${UNLOCKED_IMAGE}" >/dev/null 2>&1; then
    echo "❌ Erro: Imagem ${UNLOCKED_IMAGE} não encontrada"
    echo "   Execute primeiro: ./scripts/build-unlocked-image.sh"
    exit 1
fi

echo "✅ Imagem desbloqueada encontrada!"

echo "🏷️ Criando tags para GHCR..."
docker tag "${UNLOCKED_IMAGE}" "${REGISTRY}/${USERNAME}/${REPO_NAME}:${VERSION}"
docker tag "${UNLOCKED_IMAGE}" "${REGISTRY}/${USERNAME}/${REPO_NAME}:latest"
docker tag "${UNLOCKED_IMAGE}" "${REGISTRY}/${USERNAME}/${REPO_NAME}:unlocked"

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

echo "📤 Fazendo upload da imagem latest (desbloqueada)..."
docker push "${REGISTRY}/${USERNAME}/${REPO_NAME}:latest"

echo "📤 Fazendo upload da imagem unlocked..."
docker push "${REGISTRY}/${USERNAME}/${REPO_NAME}:unlocked"

echo ""
echo "🎉 Upload concluído com sucesso!"
echo ""
echo "📋 Informações das imagens:"
echo "   Repository: ghcr.io/${USERNAME}/${REPO_NAME}"
echo "   Tags: ${VERSION}, latest, unlocked"
echo "   Features: ✅ TODAS AS FEATURES EE DESBLOQUEADAS"
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