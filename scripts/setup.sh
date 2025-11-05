#!/bin/bash

# Script de instalação e configuração do Chatwoot Premium
# Uso: ./setup.sh

set -e

echo "🚀 Chatwoot Premium v4.7.0 - Setup Automático"
echo "=============================================="

# Verificar se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado!"
    echo "📥 Instalando Docker..."
    
    # Atualizar pacotes
    apt-get update
    
    # Instalar dependências
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Adicionar chave GPG oficial do Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Adicionar repositório do Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Iniciar serviço
    systemctl start docker
    systemctl enable docker
    
    echo "✅ Docker instalado com sucesso!"
fi

# Verificar se o Docker Compose está disponível
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose não está disponível!"
    echo "📥 Instalando Docker Compose..."
    
    # Instalar Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    echo "✅ Docker Compose instalado com sucesso!"
fi

echo "📋 Verificando arquivos necessários..."

# Verificar se o docker-compose.yml existe
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Arquivo docker-compose.yml não encontrado!"
    echo "   Certifique-se de estar no diretório correto do projeto."
    exit 1
fi

echo "✅ Arquivo docker-compose.yml encontrado!"

# Criar arquivo .env se não existir
if [ ! -f ".env" ]; then
    echo "📝 Criando arquivo .env a partir do exemplo..."
    cp .env.example .env
    
    echo "⚠️  IMPORTANTE: Configure as variáveis no arquivo .env antes de continuar!"
    echo "   As seguintes variáveis são OBRIGATÓRIAS:"
    echo "   - FRONTEND_URL"
    echo "   - SECRET_KEY_BASE"
    echo "   - POSTGRES_PASSWORD"
    echo ""
    echo "💡 Execute: nano .env"
    echo ""
    read -p "Pressione Enter após configurar o arquivo .env..."
fi

echo "🔧 Gerando SECRET_KEY_BASE se necessário..."
if grep -q "sua-chave-secreta" .env; then
    NEW_SECRET=$(openssl rand -hex 64)
    sed -i "s/SECRET_KEY_BASE=sua-chave-secreta.*/SECRET_KEY_BASE=${NEW_SECRET}/" .env
    echo "✅ Nova SECRET_KEY_BASE gerada!"
fi

echo "📥 Fazendo pull das imagens Docker..."
docker compose pull

echo "🏗️ Iniciando os serviços..."
docker compose up -d

echo "⏳ Aguardando serviços ficarem prontos..."
sleep 30

echo "🔍 Verificando status dos serviços..."
docker compose ps

# Verificar se os serviços estão rodando
if docker compose ps | grep -q "Up"; then
    echo "✅ Serviços iniciados com sucesso!"
    
    echo ""
    echo "🎉 Instalação concluída!"
    echo ""
    echo "📋 Informações importantes:"
    echo "   URL: Conforme configurado em FRONTEND_URL"
    echo "   Porta: 3000 (se usando localhost)"
    echo "   Admin: Será criado no primeiro acesso"
    echo ""
    echo "🔧 Comandos úteis:"
    echo "   Ver logs:        docker compose logs -f"
    echo "   Parar serviços:  docker compose down"
    echo "   Reiniciar:       docker compose restart"
    echo "   Atualizar:       docker compose pull && docker compose up -d"
    echo ""
    echo "📖 Documentação completa: README.md"
    
else
    echo "❌ Erro ao iniciar os serviços!"
    echo "📋 Verificando logs..."
    docker compose logs
    exit 1
fi