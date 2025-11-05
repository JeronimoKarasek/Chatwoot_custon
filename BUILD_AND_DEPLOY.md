# 🐳 Guia Completo: Build e Deploy da Imagem Docker

Este guia mostra como criar a imagem Docker do Chatwoot customizado e fazer o deploy no Portainer.

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Build da Imagem](#build-da-imagem)
3. [Push para GitHub Container Registry](#push-para-github-container-registry)
4. [Deploy no Portainer](#deploy-no-portainer)
5. [Solução de Problemas](#solução-de-problemas)

---

## 🔧 Pré-requisitos

### 1. Docker Instalado

```bash
# Verificar instalação do Docker
docker --version

# Deve retornar algo como: Docker version 24.0.0, build ...
```

Se não tiver Docker instalado:
- **Linux**: https://docs.docker.com/engine/install/
- **Windows/Mac**: https://docs.docker.com/desktop/

### 2. GitHub Personal Access Token (PAT)

Para fazer push da imagem para o GitHub Container Registry:

1. Acesse: https://github.com/settings/tokens/new
2. Dê um nome: `chatwoot-ghcr-push`
3. Marque as permissões:
   - ✅ `write:packages`
   - ✅ `read:packages`
4. Clique em **"Generate token"**
5. **COPIE O TOKEN** (você só verá ele uma vez!)

### 3. Espaço em Disco

- Mínimo: 10GB livres
- Recomendado: 20GB+ livres

---

## 🏗️ Build da Imagem

### Método 1: Script Automatizado (Recomendado)

```bash
# Clone o repositório (se ainda não clonou)
git clone https://github.com/JeronimoKarasek/Chatwoot_custon.git
cd Chatwoot_custon

# Execute o script de build
./build_image.sh

# Ou com uma tag específica
./build_image.sh v4.7.0
```

O script irá:
1. ✅ Baixar o código fonte do Chatwoot
2. ✅ Instalar todas as dependências
3. ✅ Aplicar patches customizados
4. ✅ Compilar assets
5. ✅ Criar a imagem Docker

**Tempo estimado**: 10-20 minutos (depende da sua conexão e hardware)

### Método 2: Build Manual

```bash
docker build \
  --tag ghcr.io/jeronimokarasek/chatwoot_custon:latest \
  --build-arg CHATWOOT_VERSION=v3.13.0 \
  .
```

### Verificar a Imagem Criada

```bash
# Listar imagens
docker images | grep chatwoot_custon

# Deve mostrar algo como:
# ghcr.io/jeronimokarasek/chatwoot_custon   latest   abc123def456   2 minutes ago   2.5GB
```

---

## 📤 Push para GitHub Container Registry

### Método 1: Script Automatizado (Recomendado)

```bash
# Opção 1: Token via argumento
./push_to_ghcr.sh 'ghp_seu_token_aqui'

# Opção 2: Token via variável de ambiente
export GITHUB_TOKEN='ghp_seu_token_aqui'
./push_to_ghcr.sh

# Push com tag específica
./push_to_ghcr.sh 'ghp_seu_token_aqui' v4.7.0
```

### Método 2: Push Manual

```bash
# 1. Login no GHCR
echo 'ghp_seu_token_aqui' | docker login ghcr.io -u jeronimokarasek --password-stdin

# 2. Push da imagem
docker push ghcr.io/jeronimokarasek/chatwoot_custon:latest
```

### Verificar Push

Após o push bem-sucedido, acesse:
```
https://github.com/JeronimoKarasek/Chatwoot_custon/pkgs/container/chatwoot_custon
```

---

## 🚀 Deploy no Portainer

### 1. Acessar Portainer

1. Abra seu Portainer: `https://seu-portainer.com`
2. Faça login
3. Selecione seu environment (Docker/Swarm)

### 2. Criar Stack

1. Vá em: **Stacks** → **Add stack**
2. Dê um nome: `chatwoot-custom`
3. Selecione: **Web editor**

### 3. Cole a Stack

Cole o conteúdo do arquivo `portainer-stack.yml` ou use esta configuração:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: chatwoot
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: MUDE_ESTA_SENHA
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - chatwoot

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - chatwoot

  chatwoot:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    environment:
      # ===== CONFIGURAÇÕES OBRIGATÓRIAS =====
      DATABASE_URL: postgresql://postgres:MUDE_ESTA_SENHA@postgres:5432/chatwoot?sslmode=disable
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: GERE_UMA_CHAVE_SECRETA_AQUI
      FRONTEND_URL: https://chat.seu-dominio.com
      
      # ===== CONFIGURAÇÕES DA INSTALAÇÃO =====
      INSTALLATION_NAME: MeuChatwoot
      DEFAULT_LOCALE: pt_BR
      
      # ===== OUTRAS CONFIGURAÇÕES =====
      RAILS_ENV: production
      CW_EDITION: ee
      CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES: "true"
    ports:
      - "3000:3000"
    volumes:
      - app_storage:/app/storage
    networks:
      - chatwoot

  sidekiq:
    image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    environment:
      DATABASE_URL: postgresql://postgres:MUDE_ESTA_SENHA@postgres:5432/chatwoot?sslmode=disable
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: MESMA_CHAVE_DO_CHATWOOT
      RAILS_ENV: production
      CW_EDITION: ee
    volumes:
      - app_storage:/app/storage
    networks:
      - chatwoot

volumes:
  postgres_data:
  redis_data:
  app_storage:

networks:
  chatwoot:
    driver: bridge
```

### 4. Configurar Variáveis Importantes

**⚠️ IMPORTANTE**: Antes de fazer deploy, MUDE estas variáveis:

#### SECRET_KEY_BASE

Gere uma chave segura:
```bash
openssl rand -hex 64
```

#### Senhas do PostgreSQL

Use senhas fortes e únicas.

#### FRONTEND_URL

Configure com seu domínio:
```
https://chat.seu-dominio.com
```

### 5. Deploy

1. Revise todas as configurações
2. Clique em **"Deploy the stack"**
3. Aguarde 2-3 minutos para inicialização
4. Verifique os logs dos containers

### 6. Acessar o Chatwoot

1. Abra: `http://seu-servidor:3000`
2. Crie sua conta de admin
3. Configure suas inboxes

---

## 🔐 Configuração SSL/HTTPS

Para produção, configure um proxy reverso com SSL:

### Opção 1: Nginx + Certbot

```nginx
server {
    listen 80;
    server_name chat.seu-dominio.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name chat.seu-dominio.com;

    ssl_certificate /etc/letsencrypt/live/chat.seu-dominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chat.seu-dominio.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Opção 2: Traefik

Adicione labels ao serviço chatwoot:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.chatwoot.rule=Host(`chat.seu-dominio.com`)"
  - "traefik.http.routers.chatwoot.entrypoints=websecure"
  - "traefik.http.routers.chatwoot.tls.certresolver=letsencrypt"
```

---

## 🔄 Atualização da Imagem

### 1. Build Nova Versão

```bash
# Build com nova tag
./build_image.sh v4.7.1

# Push para registry
./push_to_ghcr.sh 'ghp_seu_token' v4.7.1
```

### 2. Atualizar no Portainer

1. Vá em: **Stacks** → Sua stack
2. Clique em **Editor**
3. Atualize a tag da imagem
4. Clique em **Update the stack**

Ou via Docker CLI:

```bash
# Docker Compose
docker compose pull
docker compose up -d

# Docker Swarm
docker service update --image ghcr.io/jeronimokarasek/chatwoot_custon:v4.7.1 chatwoot
```

---

## 🛠️ Solução de Problemas

### Build Falha

**Erro**: `No space left on device`
```bash
# Limpar imagens antigas
docker system prune -a
```

**Erro**: `Failed to fetch packages`
```bash
# Tentar build novamente
./build_image.sh
```

### Push Falha

**Erro**: `unauthorized: authentication required`
```bash
# Verificar token
docker logout ghcr.io
./push_to_ghcr.sh 'ghp_novo_token'
```

### Container Não Inicia

```bash
# Ver logs
docker logs chatwoot-chatwoot-1

# Verificar variáveis de ambiente
docker inspect chatwoot-chatwoot-1 | grep -A 20 Env
```

### Banco de Dados Não Conecta

Verifique:
1. ✅ `DATABASE_URL` está correto
2. ✅ PostgreSQL está rodando
3. ✅ Senha está correta

```bash
# Testar conexão manualmente
docker exec -it chatwoot-postgres-1 psql -U postgres -d chatwoot
```

### Assets Não Carregam

1. Verifique `FRONTEND_URL`
2. Confirme proxy reverso está configurado
3. Limpe cache do navegador

---

## 📊 Monitoramento

### Verificar Status

```bash
# Status dos containers
docker ps

# Uso de recursos
docker stats

# Logs em tempo real
docker logs -f chatwoot-chatwoot-1
```

### Backup

```bash
# Backup do PostgreSQL
docker exec chatwoot-postgres-1 pg_dump -U postgres chatwoot > backup.sql

# Backup dos volumes
docker run --rm -v chatwoot_app_storage:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/storage-backup.tar.gz /data
```

### Restore

```bash
# Restore PostgreSQL
docker exec -i chatwoot-postgres-1 psql -U postgres chatwoot < backup.sql

# Restore volumes
docker run --rm -v chatwoot_app_storage:/data -v $(pwd):/backup \
  ubuntu tar xzf /backup/storage-backup.tar.gz -C /
```

---

## 📞 Suporte

- **Issues**: https://github.com/JeronimoKarasek/Chatwoot_custon/issues
- **Documentação Oficial Chatwoot**: https://www.chatwoot.com/docs
- **Portainer Docs**: https://docs.portainer.io

---

## 🎯 Checklist de Deploy

- [ ] Docker instalado e funcionando
- [ ] GitHub token gerado
- [ ] Imagem buildada localmente
- [ ] Imagem enviada para GHCR
- [ ] Stack criada no Portainer
- [ ] Variáveis de ambiente configuradas
- [ ] SECRET_KEY_BASE gerado
- [ ] Senhas alteradas
- [ ] FRONTEND_URL configurado
- [ ] Deploy realizado
- [ ] Containers iniciados
- [ ] Logs verificados
- [ ] Aplicação acessível
- [ ] SSL/HTTPS configurado (produção)
- [ ] Backup configurado

---

**✅ Pronto! Seu Chatwoot customizado está no ar! 🚀**
