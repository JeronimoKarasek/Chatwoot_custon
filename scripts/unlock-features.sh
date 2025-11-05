#!/bin/bash

# Script para desbloquear features Enterprise Edition (EE) do Chatwoot
# Remove os cadeados das configurações no painel administrativo

set -e

echo "🔓 Chatwoot EE Features Unlock Script"
echo "======================================"

# Verificar se o container está rodando
CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Uso: $0 <nome_do_container>"
    echo ""
    echo "Exemplos:"
    echo "  $0 chatwoot-app"
    echo "  $0 chatv44_chatwoot_app.1.xxx"
    echo ""
    echo "Para listar containers: docker ps | grep chatwoot"
    exit 1
fi

echo "🔍 Verificando container: $CONTAINER_NAME"

if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container '$CONTAINER_NAME' não está rodando!"
    exit 1
fi

echo "✅ Container encontrado!"

echo ""
echo "🔓 Desbloqueando features Enterprise Edition..."
echo ""

# Executar script Ruby no console Rails para liberar todas as features EE
docker exec -it "$CONTAINER_NAME" bundle exec rails runner - <<'RUBY_SCRIPT'
puts "=" * 60
puts "🔓 DESBLOQUEANDO FEATURES ENTERPRISE EDITION"
puts "=" * 60
puts ""

begin
  # Desbloquear todas as contas
  Account.find_each do |account|
    puts "📦 Processando conta: #{account.name} (ID: #{account.id})"
    
    # Habilitar todas as features EE
    features = [
      'captain',                      # AI-powered conversations
      'custom_branding',              # Custom branding
      'agent_capacity',               # Agent capacity limits
      'audit_logs',                   # Audit logs
      'disable_branding',             # Disable branding
      'help_center',                  # Help center
      'sla',                          # SLA management
      'team_management',              # Team management
      'campaigns',                    # Campaigns
      'integrations',                 # Advanced integrations
      'ip_lookup',                    # IP lookup
      'inbox_management',             # Inbox management
      'labels',                       # Labels
      'macros',                       # Macros
      'reports',                      # Advanced reports
      'response_bot',                 # Response bot
      'voice',                        # Voice channel
      'channel_email',                # Email channel
      'channel_facebook',             # Facebook channel
      'channel_twitter',              # Twitter channel
      'channel_whatsapp',             # WhatsApp channel
      'channel_sms',                  # SMS channel
      'channel_telegram',             # Telegram channel
      'channel_line',                 # Line channel
      'channel_api',                  # API channel
      'channel_web_widget',           # Web widget
      'auto_resolve_conversations',   # Auto resolve
      'automations',                  # Automations
      'canned_responses',             # Canned responses
      'custom_attributes',            # Custom attributes
      'inbox_greeting',               # Inbox greeting
      'website_live_chat',            # Website live chat
      'advanced_reports',             # Advanced reports
      'csat',                         # CSAT
      'agent_bots',                   # Agent bots
      'priority',                     # Priority management
      'custom_role',                  # Custom roles
    ]
    
    # Habilitar cada feature
    features.each do |feature|
      account.enable_features(feature)
      print "  ✅ #{feature} "
    end
    
    puts ""
    puts "  💾 Salvando alterações..."
    account.save!
    
    puts "  ✅ Conta atualizada com sucesso!"
    puts ""
  end
  
  puts "=" * 60
  puts "🎉 TODAS AS FEATURES FORAM DESBLOQUEADAS!"
  puts "=" * 60
  puts ""
  puts "📋 Features ativadas:"
  puts "  - Captain (AI)"
  puts "  - Custom Branding"
  puts "  - Agent Capacity"
  puts "  - Audit Logs"
  puts "  - Help Center"
  puts "  - SLA Management"
  puts "  - All Channels (WhatsApp, Email, SMS, etc)"
  puts "  - Advanced Reports"
  puts "  - Automations"
  puts "  - E muito mais!"
  puts ""
  puts "⚠️  Importante: Faça logout e login novamente para ver as mudanças!"
  
rescue => e
  puts ""
  puts "❌ ERRO: #{e.message}"
  puts ""
  puts "Detalhes do erro:"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
RUBY_SCRIPT

echo ""
echo "🎉 Processo concluído!"
echo ""
echo "📋 Próximos passos:"
echo "1. Faça logout da sua conta"
echo "2. Faça login novamente"
echo "3. Vá em Settings para verificar as features desbloqueadas"
echo ""
echo "⚠️  Se ainda ver cadeados, limpe o cache do navegador (Ctrl+Shift+Del)"
