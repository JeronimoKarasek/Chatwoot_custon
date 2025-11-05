# Chatwoot Premium Customizado v4.7.0

🚀 **Versão premium customizada do Chatwoot com recursos avançados e otimizações**

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Rails](https://img.shields.io/badge/rails-%23CC0000.svg?style=for-the-badge&logo=ruby-on-rails&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white)

## 📋 Recursos Customizados

- ✅ **QR Code integrado** para WhatsApp Web
- ✅ **Assets corrigidos** e otimizados
- ✅ **Active Storage** configurado com S3
- ✅ **Installation configs** personalizados
- ✅ **Localização PT-BR** completa
- ✅ **Features Enterprise desbloqueadas**
- ✅ **SMTP configurado** para envio de emails
- ✅ **SSL/TLS habilitado**
- ✅ **Configurações de produção** otimizadas

## 🚀 Início Rápido

### 📖 Documentação Completa

**[➡️ Guia Completo de Build e Deploy](BUILD_AND_DEPLOY.md)**

Este guia inclui:
- ✅ Como fazer build da imagem Docker
- ✅ Como publicar no GitHub Container Registry
- ✅ Como fazer deploy no Portainer
- ✅ Configuração de SSL/HTTPS
- ✅ Backup e restore
- ✅ Solução de problemas

### ⚡ Instalação Rápida (3 Passos)

#### 1. Build da Imagem

```bash
git clone https://github.com/JeronimoKarasek/Chatwoot_custon.git
cd Chatwoot_custon
./build_image.sh
```

#### 2. Push para Registry

```bash
# Gere um token em: https://github.com/settings/tokens/new
# Permissões: write:packages, read:packages

./push_to_ghcr.sh 'seu_github_token_aqui'
```

#### 3. Deploy no Portainer

1. Acesse seu Portainer
2. Vá em **Stacks** → **Add stack**
3. Copie o conteúdo de `portainer-stack.yml`
4. Configure as variáveis (DATABASE_URL, SECRET_KEY_BASE, etc.)
5. Clique em **Deploy**

🎉 **Pronto!** Seu Chatwoot estará disponível em `http://seu-servidor:3000`

## 🐳 Imagem Docker

### Usar Imagem Pré-Construída

```bash
docker pull ghcr.io/jeronimokarasek/chatwoot_custon:latest
```

### Informações da Imagem

- **Registry**: GitHub Container Registry (GHCR)
- **Nome**: `ghcr.io/jeronimokarasek/chatwoot_custon`
- **Tags disponíveis**: `latest`, `v4.7.0`
- **Base**: Ruby 3.2 + Node.js 20
- **Tamanho**: ~2.5GB
- **Arquitetura**: AMD64

## 🏗️ Arquitetura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Chatwoot      │    │   PostgreSQL    │
│   NGINX/SSL     │◄──►│   Rails App     │◄──►│   Database      │
│                 │    │   Port: 3000    │    │   Port: 5432    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │     Redis       │
                       │   Cache/Queue   │
                       │   Port: 6379    │
                       └─────────────────┘
```

## ⚙️ Configuração

### Variáveis de Ambiente Obrigatórias

```env
# Database
DATABASE_URL=postgresql://user:password@host:port/database

# Redis
REDIS_URL=redis://redis:6379

# Security
SECRET_KEY_BASE=sua-chave-secreta-muito-longa-e-segura

# Frontend
FRONTEND_URL=https://seu-dominio.com

# Instalação
INSTALLATION_NAME=SeuChatwoot
```

### Variáveis de Ambiente Opcionais

```env
# Email/SMTP
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=seu-email@gmail.com
SMTP_PASSWORD=sua-senha-app
MAILER_SENDER_EMAIL=Chatwoot <seu-email@gmail.com>

# AWS S3 (Storage)
ACTIVE_STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=sua-access-key
AWS_SECRET_ACCESS_KEY=sua-secret-key
AWS_REGION=sa-east-1
S3_BUCKET_NAME=seu-bucket

# Features
ENABLE_ACCOUNT_SIGNUP=true
DEFAULT_LOCALE=pt_BR
CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES=true
```

## 📁 Estrutura do Projeto

```
Chatwoot_custon/
├── README.md                 # Este arquivo
├── docker-compose.yml        # Stack completa
├── docker-compose.prod.yml   # Produção
├── .env.example              # Exemplo de variáveis
├── .github/
│   └── workflows/
│       └── docker-build.yml  # CI/CD automático
├── config/
│   ├── nginx.conf            # Configuração NGINX
│   └── ssl/                  # Certificados SSL
├── scripts/
│   ├── setup.sh              # Script de instalação
│   ├── backup.sh             # Script de backup
│   └── update.sh             # Script de atualização
└── docs/
    ├── installation.md       # Instalação detalhada
    ├── configuration.md      # Configuração avançada
    └── troubleshooting.md    # Solução de problemas
```

## 🔧 Comandos Úteis

### Gerenciamento da Aplicação

```bash
# Ver logs
docker logs -f chatwoot-app

# Executar console Rails
docker exec -it chatwoot-app bundle exec rails console

# Criar admin
docker exec -it chatwoot-app bundle exec rails chatwoot:db:seed

# Backup do banco
docker exec postgres pg_dump -U postgres chatwoot > backup.sql

# Restaurar backup
docker exec -i postgres psql -U postgres chatwoot < backup.sql
```

### Monitoramento

```bash
# Status dos containers
docker ps

# Uso de recursos
docker stats

# Espaço usado
docker system df
```

## 🛠️ Desenvolvimento

### Build Local

```bash
# Clone e entre no diretório
git clone https://github.com/JeronimoKarasek/Chatwoot_custon.git
cd Chatwoot_custon

# Build da imagem
docker build -t chatwoot-custom:local .

# Teste local
docker-compose -f docker-compose.dev.yml up
```

### Customizações

Para aplicar suas próprias customizações:

1. Forke este repositório
2. Modifique o `Dockerfile`
3. Atualize as configurações necessárias
4. Commit e push
5. O GitHub Actions fará o build automaticamente

## 🔐 Segurança

### Configurações Importantes

- ✅ SSL/TLS habilitado por padrão
- ✅ Senhas em variáveis de ambiente
- ✅ CORS configurado adequadamente
- ✅ Rate limiting ativado
- ✅ Headers de segurança configurados

### Recomendações

1. **Use HTTPS sempre** em produção
2. **Configure firewall** adequadamente
3. **Mantenha backups** regulares
4. **Monitore logs** constantemente
5. **Atualize** a imagem regularmente

## 📊 Performance

### Especificações Mínimas

- **CPU:** 2 cores
- **RAM:** 4GB
- **Storage:** 20GB SSD
- **Rede:** 10Mbps

### Especificações Recomendadas

- **CPU:** 4+ cores
- **RAM:** 8GB+
- **Storage:** 50GB+ SSD
- **Rede:** 100Mbps+

## 🆘 Suporte

### Problemas Comuns

1. **Container não inicia:**
   - Verifique as variáveis de ambiente
   - Confirme conectividade com banco/redis

2. **Erro de migração:**
   ```bash
   docker exec chatwoot-app bundle exec rails db:migrate
   ```

3. **Assets não carregam:**
   - Verifique configuração do NGINX/proxy
   - Confirme FRONTEND_URL

### Logs Importantes

```bash
# Logs da aplicação
docker logs chatwoot-app

# Logs do banco
docker logs postgres

# Logs do Redis
docker logs redis
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Changelog

### v4.7.0 (2025-11-05)
- ✅ Versão inicial customizada
- ✅ QR Code integrado
- ✅ Assets corrigidos
- ✅ Active Storage configurado
- ✅ Localização PT-BR
- ✅ Configurações de produção

## 📄 Licença

Este projeto é baseado no Chatwoot open source e mantém a mesma licença MIT.

## 🎯 Roadmap

- [ ] Integração com WhatsApp Business API
- [ ] Dashboard personalizado
- [ ] Relatórios avançados
- [ ] Integração com CRM
- [ ] API customizada
- [ ] Mobile app

---

**🚀 Desenvolvido por [FocoChat Team](https://github.com/JeronimoKarasek)**

Para suporte técnico: `jeronimokarasek@example.com`