# Dockerfile para Chatwoot Premium Customizado
# Base: Ruby 3.4.4 + Node.js 23.7.0

FROM ruby:3.4.4-slim

# Metadata
LABEL maintainer="FocoChat Team"
LABEL version="4.7.0"
LABEL description="Chatwoot customizado: QR code, assets corrigidos, Active Storage, installation_configs"

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libxml2-dev \
    libxslt-dev \
    shared-mime-info \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Instalar Node.js e pnpm
ENV NODE_VERSION=23.7.0
ENV PNPM_VERSION=10.2.0

RUN curl -fsSL https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz | tar -xJ -C /usr/local --strip-components=1
RUN npm install -g pnpm@$PNPM_VERSION

# Configurar usuário root
USER root

# Diretório de trabalho
WORKDIR /app

# Configurar variáveis de ambiente do Ruby/Rails
ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLER_VERSION=2.5.11
ENV BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_PATH=/gems
ENV EXECJS_RUNTIME=Disabled
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

# Configurações específicas do Chatwoot
ENV CW_EDITION=ee
ENV INSTALLATION_ENV=docker
ENV USE_INBOX_AVATAR_FOR_BOT=true
ENV CHATWOOT_ENABLE_ACCOUNT_LEVEL_FEATURES=true
ENV DEFAULT_LOCALE=pt_BR
ENV ENABLE_ACCOUNT_SIGNUP=true
ENV DISABLE_AGENT_CONVERSATION_VIEW_OTHER=false
ENV HIDE_ALL_CHATS_FROM_AGENT=true
ENV FORCE_SSL=true
ENV DIRECT_UPLOADS_ENABLED=true
ENV ENABLE_RACK_ATTACK=false

# Configurações de performance
ENV RAILS_MAX_THREADS=7
ENV WEB_CONCURRENCY=4
ENV SIDEKIQ_CONCURRENCY=20
ENV RACK_TIMEOUT_SERVICE_TIMEOUT=0

# Configurações de email/SMTP
ENV SMTP_ADDRESS=smtp.gmail.com
ENV SMTP_PORT=587
ENV SMTP_DOMAIN=gmail.com
ENV SMTP_AUTHENTICATION=login
ENV SMTP_ENABLE_STARTTLS_AUTO=true
ENV SMTP_OPENSSL_VERIFY_MODE=peer

# Configurações AWS S3
ENV ACTIVE_STORAGE_SERVICE=amazon
ENV AWS_REGION=sa-east-1

# Configurações específicas
ENV INSTALLATION_NAME=FocoChat
ENV CHATWOOT_HUB_URL=https://inovanode.com.br

# Expor porta
EXPOSE 3000

# Volume para storage
VOLUME ["/app/storage", "/app/public"]

# Entrypoint e comando padrão
ENTRYPOINT ["docker/entrypoints/rails.sh"]
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Comentário final
COMMENT="Chatwoot customizado: QR code, assets corrigidos, Active Storage, installation_configs"