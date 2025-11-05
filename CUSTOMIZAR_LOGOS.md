# 🎨 Guia de Customização de Logos - FocoChat

## 📋 Visão Geral

Este guia mostra como substituir as logos do Chatwoot pelas suas próprias.

## 🖼️ Logos Necessárias

Prepare 3 arquivos de imagem:

### 1. Logo Principal (`logo.png`)
- **Tamanho recomendado**: 200x50px ou 400x100px
- **Formato**: PNG com fundo transparente
- **Uso**: Cabeçalho do dashboard, emails, widget
- **Exemplo**: [Seu nome/marca horizontal]

### 2. Logo Dark Mode (`logo-dark.png`)
- **Tamanho**: Igual à logo principal
- **Formato**: PNG com fundo transparente
- **Cores**: Ajustadas para fundo escuro
- **Uso**: Dashboard com tema escuro ativado

### 3. Favicon (`favicon.png`)
- **Tamanho recomendado**: 512x512px (quadrado)
- **Formato**: PNG
- **Uso**: Ícone do navegador, mobile, PWA

## 🚀 Método 1: Volume Mount (Mais Rápido)

### Passo 1: Criar diretório de logos

```bash
cd /root/chatwoot-custom/Chatwoot_custon
mkdir -p custom-logos
```

### Passo 2: Adicionar suas logos

Copie seus arquivos para o diretório:

```bash
# Exemplo com wget (substitua pelos URLs das suas imagens)
wget -O custom-logos/logo.png https://seu-site.com/logo.png
wget -O custom-logos/logo-dark.png https://seu-site.com/logo-dark.png
wget -O custom-logos/favicon.png https://seu-site.com/favicon.png

# Ou copie de outro local
cp /caminho/para/sua/logo.png custom-logos/
```

### Passo 3: Atualizar docker-compose.yml

Adicione os volumes no serviço `chatwoot-app`:

```yaml
chatwoot-app:
  image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
  volumes:
    # Logos customizadas
    - ./custom-logos/logo.png:/app/app/javascript/design-system/images/logo.png:ro
    - ./custom-logos/logo-dark.png:/app/app/javascript/design-system/images/logo-dark.png:ro
    - ./custom-logos/favicon.png:/app/public/favicon-512x512.png:ro
    - ./custom-logos/favicon.png:/app/public/packs/favicon-512x512.png:ro
    # Volumes existentes
    - app_storage:/app/storage
    - app_public:/app/public
```

### Passo 4: Reiniciar container

```bash
docker-compose restart chatwoot-app
```

## 🏗️ Método 2: Construir Imagem Customizada

### Passo 1: Preparar logos

```bash
cd /root/chatwoot-custom/Chatwoot_custon
mkdir -p logos
# Adicione suas logos no diretório logos/
```

### Passo 2: Criar Dockerfile customizado

```dockerfile
# Dockerfile.branding
FROM ghcr.io/jeronimokarasek/chatwoot_custon:latest

USER root

# Copiar logos customizadas
COPY logos/logo.png /app/app/javascript/design-system/images/logo.png
COPY logos/logo-dark.png /app/app/javascript/design-system/images/logo-dark.png
COPY logos/favicon.png /app/public/favicon-512x512.png
COPY logos/favicon.png /app/public/packs/favicon-512x512.png

# Ajustar permissões
RUN chown -R chatwoot:chatwoot /app/app/javascript/design-system/images/ \
    && chown -R chatwoot:chatwoot /app/public/

USER chatwoot
```

### Passo 3: Construir imagem

```bash
docker build -f Dockerfile.branding -t chatwoot-focochat:latest .
```

### Passo 4: Atualizar docker-compose.yml

```yaml
chatwoot-app:
  image: chatwoot-focochat:latest  # Usar imagem customizada
  # ... resto da configuração
```

## 🎨 Método 3: Variáveis de Ambiente (Chatwoot nativo)

Alguns recursos do Chatwoot permitem customização via env vars:

```yaml
environment:
  # Configurações de branding
  BRAND_NAME: "FocoChat"
  INSTALLATION_NAME: "FocoChat"
  
  # URLs de logos externas (se suportado pela versão)
  LOGO_URL: "https://seu-cdn.com/logo.png"
  LOGO_THUMBNAIL_URL: "https://seu-cdn.com/favicon.png"
```

## 🔧 Verificação

### 1. Verificar se os arquivos foram copiados:

```bash
# Verificar logo principal
docker exec chatwoot-app ls -lh /app/app/javascript/design-system/images/logo.png

# Verificar favicon
docker exec chatwoot-app ls -lh /app/public/favicon-512x512.png
```

### 2. Testar no navegador:

1. Acesse: `http://localhost:3000`
2. Faça hard refresh: `Ctrl+F5` (Windows/Linux) ou `Cmd+Shift+R` (Mac)
3. Verifique o favicon na aba do navegador
4. Faça login e verifique a logo no dashboard

### 3. Limpar cache do navegador:

```bash
# Se a logo antiga ainda aparece, limpe o cache do Rails
docker exec chatwoot-app bundle exec rails tmp:cache:clear
docker-compose restart chatwoot-app
```

## 📐 Especificações Técnicas

### Logo Principal

```
Arquivo: logo.png
Dimensões: 200x50px (proporção 4:1) ou 400x100px (retina)
Formato: PNG-24 com canal alpha
Resolução: 144 DPI (para telas retina)
Tamanho máximo: 50KB
Background: Transparente
```

### Logo Dark Mode

```
Arquivo: logo-dark.png
Dimensões: Idêntica à logo principal
Cores: Ajustadas para contraste em fundo escuro
Dica: Se sua logo for escura, faça versão clara/branca
```

### Favicon

```
Arquivo: favicon.png
Dimensões: 512x512px (quadrado)
Formato: PNG-8 ou PNG-24
Tamanho máximo: 100KB
Background: Transparente ou cor sólida
Nota: Será redimensionado automaticamente para 16x16, 32x32, 96x96
```

## 🎯 Dicas de Design

### Logo Principal:
- ✅ Use vetores (SVG) sempre que possível
- ✅ Mantenha simples e legível em tamanhos pequenos
- ✅ Teste em fundo claro E escuro
- ✅ Evite detalhes muito finos
- ❌ Não use texto muito pequeno

### Favicon:
- ✅ Design minimalista funciona melhor
- ✅ Cores contrastantes
- ✅ Teste em 16x16px (tamanho real na aba)
- ✅ Pode ser apenas iniciais ou símbolo
- ❌ Evite muito detalhe

## 🔄 Reverter para Logos Originais

### Método 1 (Volume Mount):

```bash
# Simplesmente remova os volumes do docker-compose.yml
# e reinicie
docker-compose restart chatwoot-app
```

### Método 2 (Imagem customizada):

```bash
# Volte para imagem original
# No docker-compose.yml:
chatwoot-app:
  image: ghcr.io/jeronimokarasek/chatwoot_custon:latest
```

## 📱 Logos em Diferentes Locais

As logos aparecem em:

1. **Dashboard Web**
   - Cabeçalho superior (logo.png)
   - Login page (logo.png)
   - Aba do navegador (favicon)

2. **Widget de Chat**
   - Cabeçalho do widget (logo.png pequena)
   - Ícone do botão flutuante (pode usar favicon)

3. **Emails**
   - Cabeçalho de emails transacionais
   - Rodapé de notificações

4. **Mobile/PWA**
   - App icon (usa favicon em múltiplos tamanhos)
   - Splash screen

## 🆘 Troubleshooting

### Logo não aparece:

1. **Limpar cache:**
   ```bash
   docker exec chatwoot-app bundle exec rails tmp:cache:clear
   docker exec chatwoot-app bundle exec rails assets:precompile
   docker-compose restart chatwoot-app
   ```

2. **Verificar permissões:**
   ```bash
   docker exec chatwoot-app ls -la /app/app/javascript/design-system/images/
   ```

3. **Hard refresh no navegador:**
   - Chrome: `Ctrl+Shift+R` ou `Ctrl+F5`
   - Firefox: `Ctrl+Shift+R`
   - Safari: `Cmd+Option+R`

### Logo cortada ou desproporcional:

1. Verifique as dimensões da imagem
2. Use proporção 4:1 (ex: 200x50, 400x100)
3. Certifique-se de que há padding/margem adequado

### Favicon não atualiza:

```bash
# Forçar regeneração
docker exec chatwoot-app rm -f /app/public/packs/favicon-*
docker-compose restart chatwoot-app

# Limpar cache do navegador completamente
```

## 📚 Recursos Úteis

- **Criar Favicon**: https://favicon.io
- **Otimizar PNG**: https://tinypng.com
- **Converter imagens**: https://cloudconvert.com
- **Gerar múltiplos tamanhos**: https://realfavicongenerator.net

---

**Criado para**: FocoChat  
**Data**: 05/11/2025  
**Versão Chatwoot**: Premium Edition (EE Unlocked)
