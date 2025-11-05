#!/bin/bash

# Script para rebuild da imagem com 100% desbloqueado
set -e

echo "🔓 Chatwoot Premium - Rebuild com 100% Desbloqueado"
echo "===================================================="
echo ""

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Imagens
BASE_IMAGE="forochat/chatwoot-premium:v4.7.0"
NEW_TAG="ghcr.io/jeronimokarasek/chatwoot_custon:fully-unlocked"
LATEST_TAG="ghcr.io/jeronimokarasek/chatwoot_custon:latest"

echo -e "${BLUE}📦 Criando imagem 100% desbloqueada...${NC}"
echo ""

# Criar Dockerfile temporário
cat > Dockerfile.fully-unlocked << 'DOCKERFILE_END'
FROM forochat/chatwoot-premium:v4.7.0

USER root

# Copiar patch de desbloqueio 100%
COPY config/ee_unlock.rb /app/config/initializers/ee_unlock.rb

# Garantir que o arquivo tem permissões corretas
RUN chmod 644 /app/config/initializers/ee_unlock.rb

# Forçar variáveis de ambiente
ENV CHATWOOT_EDITION=ee \
    CW_EDITION=ee \
    CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES=true \
    DISABLE_ENTERPRISE_RESTRICTIONS=true

DOCKERFILE_END

echo "✅ Dockerfile criado"
echo ""

# Build da imagem
echo -e "${BLUE}🔨 Construindo imagem...${NC}"
docker build -f Dockerfile.fully-unlocked -t "$NEW_TAG" -t "$LATEST_TAG" .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Imagem construída com sucesso!${NC}"
    echo ""
    echo "📦 Tags criadas:"
    echo "  - $NEW_TAG"
    echo "  - $LATEST_TAG"
    echo ""
    
    # Mostrar tamanho
    echo "📊 Informações da imagem:"
    docker images "$LATEST_TAG" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    echo ""
    
    # Perguntar se quer fazer push
    read -p "Deseja fazer push para o GitHub Container Registry? (s/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        echo ""
        echo -e "${BLUE}📤 Fazendo push...${NC}"
        
        docker push "$NEW_TAG"
        docker push "$LATEST_TAG"
        
        echo ""
        echo -e "${GREEN}✅ Push concluído!${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}📝 Próximos passos:${NC}"
    echo ""
    echo "1. Atualizar docker-compose.yml para usar a nova imagem:"
    echo "   image: $LATEST_TAG"
    echo ""
    echo "2. Reiniciar o stack:"
    echo "   docker-compose down"
    echo "   docker-compose pull"
    echo "   docker-compose up -d"
    echo ""
    echo "3. Verificar logs:"
    echo "   docker-compose logs -f chatwoot-app | grep DESBLOQUEADO"
    echo ""
    echo "4. Acessar e testar Custom Branding:"
    echo "   http://localhost:3000"
    echo "   Settings > Account Settings > Custom Branding"
    echo ""
    
else
    echo ""
    echo -e "${RED}❌ Erro ao construir imagem${NC}"
    exit 1
fi

# Limpar Dockerfile temporário
rm -f Dockerfile.fully-unlocked
echo "🧹 Arquivos temporários removidos"
echo ""
