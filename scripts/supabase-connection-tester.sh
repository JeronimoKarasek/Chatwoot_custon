#!/bin/bash

# Script completo para testar todas as combinações de conexão Supabase
# Criado para resolver definitivamente o erro "Tenant or user not found"

set +e  # Não parar em erros

echo "🔍 TESTE COMPLETO DE CONEXÃO SUPABASE"
echo "======================================"
echo ""

# Credenciais
PROJECT_REF="vfhzimozqsbdqknkncny"
PASSWORD="svlIAbquBQ2vGNUC"
POOLER_IPS=("52.67.1.88" "15.229.150.166" "54.94.90.106")

echo "📋 Configuração:"
echo "  Project: $PROJECT_REF"
echo "  Senha: ${PASSWORD:0:5}***"
echo "  IPs Pooler: ${POOLER_IPS[@]}"
echo ""

# Arrays de teste
USERS=(
    "postgres"
    "postgres.vfhzimozqsbdqknkncny"
    "vfhzimozqsbdqknkncny"
)

PORTS=("5432" "6543")

DATABASES=("postgres" "chatwoot_production")

SSLMODES=("require" "prefer" "disable")

HOSTS=(
    "aws-0-sa-east-1.pooler.supabase.com"
    "db.vfhzimozqsbdqknkncny.supabase.co"
    "${POOLER_IPS[0]}"
    "${POOLER_IPS[1]}"
    "${POOLER_IPS[2]}"
)

# Contador de testes
TEST_NUM=0
SUCCESS_COUNT=0

# Função para testar conexão
test_connection() {
    local host=$1
    local port=$2
    local dbname=$3
    local user=$4
    local password=$5
    local sslmode=$6
    
    TEST_NUM=$((TEST_NUM + 1))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 TESTE #$TEST_NUM"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Host: $host"
    echo "  Port: $port"
    echo "  DB: $dbname"
    echo "  User: $user"
    echo "  SSL: $sslmode"
    echo ""
    
    # Construir connection string
    CONN_STR="host=$host port=$port dbname=$dbname user=$user password=$password sslmode=$sslmode"
    
    echo "  Testando..."
    RESULT=$(timeout 5 docker run --rm postgres:15-alpine psql "$CONN_STR" -c "SELECT current_database(), current_user, version();" 2>&1)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "  ✅ SUCESSO!"
        echo ""
        echo "  Resultado:"
        echo "$RESULT" | head -10
        echo ""
        echo "  🎉 CONNECTION STRING VÁLIDA:"
        echo "  postgresql://$user:$password@$host:$port/$dbname?sslmode=$sslmode"
        echo ""
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Salvar conexão válida
        cat >> /tmp/supabase_working_connections.txt << EOF

✅ CONEXÃO FUNCIONANDO #$SUCCESS_COUNT
Host: $host
Port: $port
Database: $dbname
User: $user
SSL Mode: $sslmode
Connection String: postgresql://$user:$password@$host:$port/$dbname?sslmode=$sslmode
Teste: $TEST_NUM
Timestamp: $(date)

EOF
        
    else
        echo "  ❌ FALHA"
        echo "  Erro: $(echo "$RESULT" | head -2 | tail -1)"
    fi
    echo ""
}

# Limpar arquivo de resultados
> /tmp/supabase_working_connections.txt

echo "🚀 Iniciando testes..."
echo ""

# Testar todas as combinações
for host in "${HOSTS[@]}"; do
    for port in "${PORTS[@]}"; do
        for dbname in "${DATABASES[@]}"; do
            for user in "${USERS[@]}"; do
                for sslmode in "${SSLMODES[@]}"; do
                    test_connection "$host" "$port" "$dbname" "$user" "$PASSWORD" "$sslmode"
                done
            done
        done
    done
done

# Resumo final
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMO FINAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total de testes: $TEST_NUM"
echo "  Sucessos: $SUCCESS_COUNT"
echo "  Falhas: $((TEST_NUM - SUCCESS_COUNT))"
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "🎉 ENCONTRADAS $SUCCESS_COUNT CONEXÕES VÁLIDAS!"
    echo ""
    echo "📄 Resultados salvos em: /tmp/supabase_working_connections.txt"
    echo ""
    cat /tmp/supabase_working_connections.txt
else
    echo "❌ NENHUMA CONEXÃO FUNCIONOU"
    echo ""
    echo "🔍 Possíveis causas:"
    echo "  1. Senha incorreta - Resete no dashboard Supabase"
    echo "  2. Projeto pausado - Ative no dashboard"
    echo "  3. Database não criado - Crie via dashboard ou API"
    echo "  4. Firewall/IP bloqueado - Verifique configurações de rede"
    echo "  5. Plano Free com limitações - Considere upgrade"
    echo ""
    echo "💡 PRÓXIMOS PASSOS:"
    echo "  1. Acesse: https://supabase.com/dashboard/project/$PROJECT_REF"
    echo "  2. Vá em Settings > Database"
    echo "  3. Reset Database Password"
    echo "  4. Copie a nova senha"
    echo "  5. Execute novamente este script com a nova senha"
fi
echo ""
