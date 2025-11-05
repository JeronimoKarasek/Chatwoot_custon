#!/bin/bash

# Script para forçar liberação de features EE modificando diretamente o código
# Este método funciona mesmo sem acesso ao banco de dados

set -e

echo "🔓 Chatwoot EE Features - Force Unlock (Code Patch)"
echo "===================================================="

CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Uso: $0 <nome_do_container>"
    echo ""
    echo "Exemplos:"
    echo "  $0 chatv44_chatwoot_app.1.xxx"
    echo ""
    echo "Para listar: docker ps | grep chatwoot"
    exit 1
fi

echo "🔍 Container: $CONTAINER_NAME"

echo ""
echo "📝 Criando patch para desbloquear features EE..."

# Criar arquivo de patch temporário
cat > /tmp/chatwoot_ee_patch.rb << 'EOF'
# Patch para desbloquear todas as features EE
module EnterpriseEditionPatch
  def self.apply!
    puts "🔓 Aplicando patch de desbloqueio de features EE..."
    
    # Sobrescrever verificação de features
    Account.class_eval do
      def feature_enabled?(feature_key)
        true # Sempre retorna true, liberando todas as features
      end
      
      def limits_enabled?
        false # Desabilita limites
      end
    end
    
    # Patch no InstallationConfig
    InstallationConfig.class_eval do
      def self.is_enterprise_edition?
        true # Sempre Enterprise Edition
      end
      
      def self.enterprise_plan?
        true
      end
    end
    
    puts "✅ Patch aplicado com sucesso!"
    puts "📋 Todas as features EE estão agora desbloqueadas!"
  end
end

EnterpriseEditionPatch.apply!
EOF

echo "📦 Copiando patch para o container..."
docker cp /tmp/chatwoot_ee_patch.rb "$CONTAINER_NAME":/app/config/initializers/ee_unlock_patch.rb

echo "🔄 Reiniciando container para aplicar o patch..."
docker restart "$CONTAINER_NAME"

echo ""
echo "⏳ Aguardando container reiniciar (30 segundos)..."
sleep 30

echo ""
echo "✅ Verificando status..."
docker ps | grep "$CONTAINER_NAME"

echo ""
echo "🎉 Patch aplicado com sucesso!"
echo ""
echo "📋 O que foi feito:"
echo "  ✅ Todas as verificações de features EE foram desabilitadas"
echo "  ✅ Todos os cadeados foram removidos"
echo "  ✅ Limites de conta desabilitados"
echo ""
echo "🔄 Próximos passos:"
echo "  1. Acesse o Chatwoot"
echo "  2. Faça login (ou limpe cache se já logado)"
echo "  3. Vá em Settings - todas as features devem estar disponíveis!"
echo ""
echo "⚠️  IMPORTANTE: Se o container for recriado, execute este script novamente"

# Limpar arquivo temporário
rm /tmp/chatwoot_ee_patch.rb

echo ""
echo "💾 Para tornar permanente, adicione o patch na sua imagem Docker"