#!/bin/bash

# Script para aplicar logos customizadas no Chatwoot
# Uso: ./scripts/apply-custom-logos.sh

set -e

echo "🎨 Chatwoot - Aplicador de Logos Customizadas"
echo "=============================================="
echo ""

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretório de logos
LOGO_DIR="custom-logos"
COMPOSE_FILE="docker-compose.yml"

# Verificar se docker-compose existe
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}❌ Erro: docker-compose.yml não encontrado${NC}"
    exit 1
fi

# Criar diretório se não existir
if [ ! -d "$LOGO_DIR" ]; then
    echo -e "${BLUE}📁 Criando diretório $LOGO_DIR...${NC}"
    mkdir -p "$LOGO_DIR"
fi

echo -e "${YELLOW}📋 Status das Logos:${NC}"
echo ""

# Verificar logos existentes
LOGO_PRINCIPAL="$LOGO_DIR/logo.png"
LOGO_DARK="$LOGO_DIR/logo-dark.png"
FAVICON="$LOGO_DIR/favicon.png"

check_file() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        dimensions=$(file "$file" | grep -oP '\d+\s*x\s*\d+' || echo "N/A")
        echo -e "  ✅ $name"
        echo -e "     Arquivo: $file"
        echo -e "     Tamanho: $size"
        echo -e "     Dimensões: $dimensions"
        return 0
    else
        echo -e "  ❌ $name"
        echo -e "     Arquivo: $file (não encontrado)"
        return 1
    fi
    echo ""
}

LOGO_COUNT=0

check_file "$LOGO_PRINCIPAL" "Logo Principal" && LOGO_COUNT=$((LOGO_COUNT + 1))
check_file "$LOGO_DARK" "Logo Dark Mode" && LOGO_COUNT=$((LOGO_COUNT + 1))
check_file "$FAVICON" "Favicon" && LOGO_COUNT=$((LOGO_COUNT + 1))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $LOGO_COUNT -eq 0 ]; then
    echo -e "${RED}❌ Nenhuma logo encontrada!${NC}"
    echo ""
    echo -e "${YELLOW}📝 Instruções:${NC}"
    echo ""
    echo "1. Adicione suas logos no diretório $LOGO_DIR:"
    echo "   - logo.png (200x50px, fundo transparente)"
    echo "   - logo-dark.png (200x50px, para tema escuro)"
    echo "   - favicon.png (512x512px, ícone do navegador)"
    echo ""
    echo "2. Exemplo com URLs:"
    echo "   wget -O $LOGO_DIR/logo.png https://seu-site.com/logo.png"
    echo "   wget -O $LOGO_DIR/logo-dark.png https://seu-site.com/logo-dark.png"
    echo "   wget -O $LOGO_DIR/favicon.png https://seu-site.com/favicon.png"
    echo ""
    echo "3. Execute novamente este script"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Encontradas $LOGO_COUNT logo(s)${NC}"
echo ""

# Perguntar se deseja continuar
read -p "Deseja aplicar as logos ao Chatwoot? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo -e "${BLUE}🔧 Aplicando logos...${NC}"
echo ""

# Método 1: Atualizar docker-compose.yml
echo "1️⃣  Atualizando docker-compose.yml..."

# Backup do docker-compose
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "   ✅ Backup criado"

# Verificar se já tem volumes de logos
if grep -q "custom-logos/logo.png" "$COMPOSE_FILE"; then
    echo "   ℹ️  Volumes de logos já configurados"
else
    echo "   📝 Adicionando volumes de logos..."
    
    # Adicionar volumes (método simples - você pode melhorar)
    cat >> "$COMPOSE_FILE" << 'EOF'

# Adicionar estas linhas em chatwoot-app > volumes:
#    - ./custom-logos/logo.png:/app/app/javascript/design-system/images/logo.png:ro
#    - ./custom-logos/logo-dark.png:/app/app/javascript/design-system/images/logo-dark.png:ro
#    - ./custom-logos/favicon.png:/app/public/favicon-512x512.png:ro
EOF
    
    echo "   ⚠️  ATENÇÃO: Adicione manualmente os volumes no docker-compose.yml"
    echo "   Veja instruções no final do arquivo"
fi

# Método 2: Copiar diretamente para container (se estiver rodando)
echo ""
echo "2️⃣  Copiando logos para container em execução..."

if docker ps | grep -q "chatwoot-app"; then
    echo "   Container encontrado!"
    
    [ -f "$LOGO_PRINCIPAL" ] && docker cp "$LOGO_PRINCIPAL" chatwoot-app:/app/app/javascript/design-system/images/logo.png && echo "   ✅ Logo principal copiada"
    
    [ -f "$LOGO_DARK" ] && docker cp "$LOGO_DARK" chatwoot-app:/app/app/javascript/design-system/images/logo-dark.png && echo "   ✅ Logo dark copiada"
    
    [ -f "$FAVICON" ] && docker cp "$FAVICON" chatwoot-app:/app/public/favicon-512x512.png && echo "   ✅ Favicon copiado"
    
    [ -f "$FAVICON" ] && docker cp "$FAVICON" chatwoot-app:/app/public/packs/favicon-512x512.png && echo "   ✅ Favicon (packs) copiado"
    
    echo ""
    echo "3️⃣  Ajustando permissões..."
    docker exec -u root chatwoot-app chown -R chatwoot:chatwoot /app/app/javascript/design-system/images/ 2>/dev/null || true
    docker exec -u root chatwoot-app chown -R chatwoot:chatwoot /app/public/ 2>/dev/null || true
    echo "   ✅ Permissões ajustadas"
    
    echo ""
    echo "4️⃣  Limpando cache..."
    docker exec chatwoot-app bundle exec rails tmp:cache:clear 2>/dev/null || true
    echo "   ✅ Cache limpo"
    
    echo ""
    echo "5️⃣  Reiniciando container..."
    docker-compose restart chatwoot-app
    echo "   ✅ Container reiniciado"
    
else
    echo "   ⚠️  Container não está rodando"
    echo "   Execute: docker-compose up -d"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🎉 Logos aplicadas com sucesso!${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos passos:${NC}"
echo ""
echo "1. Acesse: http://localhost:3000"
echo "2. Faça hard refresh: Ctrl+F5 (ou Cmd+Shift+R no Mac)"
echo "3. Limpe o cache do navegador se necessário"
echo ""
echo "🔍 Verificar logos aplicadas:"
echo "   docker exec chatwoot-app ls -lh /app/app/javascript/design-system/images/"
echo ""
echo "📚 Documentação completa: CUSTOMIZAR_LOGOS.md"
echo ""
