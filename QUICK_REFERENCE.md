# 🚀 Quick Reference - Chatwoot Custom

## Build e Push (Desenvolvedores)

```bash
# 1. Build local
./build_image.sh

# 2. Push para GHCR
./push_to_ghcr.sh 'seu_github_token'
```

## Deploy no Portainer (Usuários)

### Passo 1: Criar Stack
1. Acesse Portainer
2. Vá em **Stacks** → **Add stack**
3. Nome: `chatwoot-custom`

### Passo 2: Cole a Stack
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
      DATABASE_URL: postgresql://postgres:MUDE_ESTA_SENHA@postgres:5432/chatwoot?sslmode=disable
      REDIS_URL: redis://redis:6379
      SECRET_KEY_BASE: GERE_CHAVE_COM_openssl_rand_-hex_64
      FRONTEND_URL: https://chat.seu-dominio.com
      INSTALLATION_NAME: MeuChatwoot
      DEFAULT_LOCALE: pt_BR
      RAILS_ENV: production
      CW_EDITION: ee
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

### Passo 3: Configurar
- ✅ Mude `POSTGRES_PASSWORD`
- ✅ Gere `SECRET_KEY_BASE`: `openssl rand -hex 64`
- ✅ Configure `FRONTEND_URL` com seu domínio

### Passo 4: Deploy
Clique em **Deploy the stack** e aguarde ~3 minutos

## Acesso

- **URL**: http://seu-servidor:3000
- **Primeira vez**: Crie sua conta de admin

## Comandos Úteis

### Ver logs
```bash
docker logs -f chatwoot-custom-chatwoot-1
```

### Criar admin
```bash
docker exec -it chatwoot-custom-chatwoot-1 bundle exec rails chatwoot:db:seed
```

### Backup banco
```bash
docker exec chatwoot-custom-postgres-1 pg_dump -U postgres chatwoot > backup.sql
```

### Atualizar imagem
```bash
docker pull ghcr.io/jeronimokarasek/chatwoot_custon:latest
# Depois atualizar a stack no Portainer
```

## SSL/HTTPS (Produção)

Use Nginx ou Traefik como proxy reverso:

### Nginx exemplo
```nginx
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

## Troubleshooting

### Container não inicia
```bash
docker logs chatwoot-custom-chatwoot-1
# Verifique DATABASE_URL e SECRET_KEY_BASE
```

### Banco não conecta
```bash
# Testar conexão
docker exec -it chatwoot-custom-postgres-1 psql -U postgres -d chatwoot
```

### Assets não carregam
- Verifique `FRONTEND_URL`
- Limpe cache do navegador
- Verifique logs do Nginx/Traefik

## Suporte

- 📖 [Guia Completo](BUILD_AND_DEPLOY.md)
- 📖 [README](README.md)
- 🐛 [Issues](https://github.com/JeronimoKarasek/Chatwoot_custon/issues)
