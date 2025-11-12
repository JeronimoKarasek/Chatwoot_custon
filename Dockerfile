# Dockerfile para Chatwoot Premium Customizado
# Base: Ruby 3.2 + Node.js 20 (versões compatíveis com Chatwoot)

FROM ruby:3.2-slim

# Metadata
LABEL maintainer="FocoChat Team"
LABEL version="4.7.0"
LABEL description="Chatwoot customizado: QR code, assets corrigidos, Active Storage, installation_configs"
LABEL org.opencontainers.image.source="https://github.com/JeronimoKarasek/Chatwoot_custon"

# Args para versão do Chatwoot
ARG CHATWOOT_VERSION=v3.13.0

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
    imagemagick \
    libvips-dev \
    wget \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Instalar Node.js 20.x (versão compatível)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Instalar Yarn
RUN npm install -g yarn

# Configurar usuário e diretório
USER root
WORKDIR /app

# Clonar Chatwoot do repositório oficial
RUN git clone --branch ${CHATWOOT_VERSION} --depth 1 https://github.com/chatwoot/chatwoot.git /app \
    && rm -rf /app/.git

# Configurar variáveis de ambiente do Ruby/Rails
ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLER_VERSION=2.5.11
ENV BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_PATH=/usr/local/bundle
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
ENV FORCE_SSL=false
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

# Instalar bundler específico
RUN gem install bundler -v ${BUNDLER_VERSION}

# Copiar Gemfile e instalar dependências Ruby
RUN bundle install --jobs 4 --retry 5

# Instalar dependências Node.js
RUN yarn install --frozen-lockfile

# Copiar patches customizados
COPY config/ee_unlock.rb /app/config/initializers/ee_unlock.rb
COPY patches/zz_final_unlock.rb /app/config/initializers/zz_final_unlock.rb
COPY patches/check_new_versions_job_patch.rb /app/config/initializers/check_new_versions_job_patch.rb
COPY patches/_user.json.jbuilder /app/app/views/api/v1/models/_user.json.jbuilder

# Copiar brand assets se existirem (opcional)
RUN mkdir -p /app/public/brand-assets
COPY --chown=root:root patches/brand-assets/ /app/public/brand-assets/ || true

# Pré-compilar assets
RUN SECRET_KEY_BASE=placeholder bundle exec rails assets:precompile

# Criar diretórios necessários
RUN mkdir -p /app/storage /app/public /app/tmp/pids

# Copiar entrypoint script
COPY docker/entrypoints/rails.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expor porta
EXPOSE 3000

# Volume para storage
VOLUME ["/app/storage", "/app/public"]

# Entrypoint e comando padrão
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD curl -f http://localhost:3000/api || exit 1