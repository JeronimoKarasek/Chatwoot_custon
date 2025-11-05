#!/bin/bash

# Script para criar uma nova imagem com features EE desbloqueadas

set -e

echo "🔓 Criando Nova Imagem Chatwoot com Features EE Desbloqueadas"
echo "=============================================================="

# Nome da imagem original
ORIGINAL_IMAGE="forochat/chatwoot-premium:v4.7.0"
NEW_IMAGE="forochat/chatwoot-premium:v4.7.0-unlocked"

echo "📦 Imagem original: $ORIGINAL_IMAGE"
echo "🆕 Nova imagem: $NEW_IMAGE"

# Verificar se a imagem original existe
if ! docker image inspect "$ORIGINAL_IMAGE" >/dev/null 2>&1; then
    echo "❌ Imagem original não encontrada: $ORIGINAL_IMAGE"
    echo "   Verifique se a imagem existe com: docker images | grep chatwoot"
    exit 1
fi

echo "✅ Imagem original encontrada!"

# Criar Dockerfile temporário para o patch
echo "📝 Criando Dockerfile de patch..."
cat > /tmp/Dockerfile.unlock << 'EOF'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Copiar patch de desbloqueio
COPY ee_unlock.rb /app/config/initializers/ee_unlock.rb

# Garantir permissões corretas
RUN chown -R root:root /app/config/initializers/ee_unlock.rb

# Label da versão
LABEL version="4.7.0-unlocked"
LABEL description="Chatwoot Premium with all EE features unlocked"
EOF

echo "✅ Dockerfile de patch criado!"

# Copiar o arquivo de patch
cp config/ee_unlock.rb /tmp/ee_unlock.rb

echo "🏗️ Construindo nova imagem..."
cd /tmp
docker build \
    --build-arg BASE_IMAGE="$ORIGINAL_IMAGE" \
    -f Dockerfile.unlock \
    -t "$NEW_IMAGE" \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Nova imagem criada com sucesso!"
    echo ""
    echo "📋 Informações da imagem:"
    docker images | grep "chatwoot-premium.*unlocked"
    echo ""
    echo "🔖 Tags adicionais:"
    docker tag "$NEW_IMAGE" "forochat/chatwoot-premium:latest-unlocked"
    docker tag "$NEW_IMAGE" "ghcr.io/jeronimokarasek/chatwoot_custon:v4.7.0-unlocked"
    docker tag "$NEW_IMAGE" "ghcr.io/jeronimokarasek/chatwoot_custon:latest"
    
    echo "✅ Tags criadas:"
    echo "   - forochat/chatwoot-premium:v4.7.0-unlocked"
    echo "   - forochat/chatwoot-premium:latest-unlocked"
    echo "   - ghcr.io/jeronimokarasek/chatwoot_custon:v4.7.0-unlocked"
    echo "   - ghcr.io/jeronimokarasek/chatwoot_custon:latest"
    echo ""
    echo "🚀 Para usar a nova imagem:"
    echo "   1. Atualize sua stack no Portainer ou docker-compose"
    echo "   2. Use: ghcr.io/jeronimokarasek/chatwoot_custon:latest"
    echo "   3. Ou: forochat/chatwoot-premium:v4.7.0-unlocked"
    echo ""
    echo "📤 Para fazer upload no GitHub Container Registry:"
    echo "   ./scripts/push-image.sh SEU_GITHUB_PAT"
    
else
    echo "❌ Erro ao construir a imagem!"
    exit 1
fi

# Limpar arquivos temporários
rm /tmp/Dockerfile.unlock /tmp/ee_unlock.rb

echo ""
echo "✅ Processo concluído!"