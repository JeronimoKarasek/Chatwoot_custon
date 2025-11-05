#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Push Rápido para GHCR"
echo "=========================================="
echo ""

# Verificar se o token foi fornecido
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Erro: GITHUB_TOKEN não definido"
    echo ""
    echo "Execute assim:"
    echo "  GITHUB_TOKEN='seu_token' ./quick_push.sh"
    echo ""
    echo "Ou:"
    echo "  export GITHUB_TOKEN='seu_token'"
    echo "  ./quick_push.sh"
    exit 1
fi

echo "🔐 Fazendo login no GHCR..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u jeronimokarasek --password-stdin

if [ $? -ne 0 ]; then
    echo "❌ Falha no login!"
    exit 1
fi

echo "✅ Login bem sucedido!"
echo ""
echo "⬆️  Fazendo push da imagem..."
echo "   Imagem: ghcr.io/jeronimokarasek/chatwoot_custon:latest"
echo "   Tamanho: ~2.4 GB"
echo ""

docker push ghcr.io/jeronimokarasek/chatwoot_custon:latest

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ SUCESSO! Push concluído"
    echo "=========================================="
    echo ""
    echo "📦 Imagem disponível em:"
    echo "   https://github.com/JeronimoKarasek/Chatwoot_custon/pkgs/container/chatwoot_custon"
    echo ""
    echo "🔄 Para outros servidores puxarem a imagem:"
    echo "   docker pull ghcr.io/jeronimokarasek/chatwoot_custon:latest"
else
    echo ""
    echo "❌ Erro ao fazer push!"
    exit 1
fi
