# 🔴 ATENÇÃO: Erro "Tenant or user not found"

## ❌ Problema Identificado

O teste de conexão com o Supabase falhou com o erro:
```
FATAL: Tenant or user not found
```

---

## 🔍 Possíveis Causas

### 1. 🔴 Projeto Pausado (MAIS PROVÁVEL)

O Supabase pausa automaticamente projetos inativos no plano gratuito.

**✅ Solução:**
1. Acesse: https://app.supabase.com
2. Entre na sua conta
3. Selecione o projeto: `vfhzimozqsbdqknkncny`
4. Se estiver pausado, clique em **"Resume project"**
5. Aguarde 2-3 minutos
6. Execute novamente: `./scripts/test-supabase.sh`

---

### 2. 🔑 Senha do Database Incorreta

A senha pode ter sido resetada ou estar incorreta.

**✅ Solução:**
1. Acesse: https://app.supabase.com
2. Projeto → **Settings** → **Database**
3. Role até **"Database password"**
4. Clique em **"Reset database password"**
5. **COPIE A NOVA SENHA** (ela só aparece uma vez!)
6. Atualize o arquivo `.env.production` com a nova senha
7. Teste novamente

---

### 3. 🌐 Connection String Incorreta

O formato da URL pode estar errado.

**✅ Solução - Obter Connection String Oficial:**
1. Acesse: https://app.supabase.com
2. Projeto → **Settings** → **Database**
3. Role até **"Connection string"**
4. Selecione **"URI"**
5. Mode: **"Session"** (para Chatwoot)
6. **COPIE** a string completa
7. Cole no arquivo `.env.production`

Exemplo esperado:
```
postgresql://postgres.vfhzimozqsbdqknkncny:[SUA_SENHA]@aws-0-sa-east-1.pooler.supabase.com:5432/postgres
```

---

### 4. 🌍 Region Incorreta

A região pode estar diferente.

**✅ Verificar:**
- URL do projeto: `https://vfhzimozqsbdqknkncny.supabase.co`
- No Settings → Database, verifique a **Region**
- Pode ser: `sa-east-1`, `us-east-1`, `eu-west-1`, etc.

---

## 🚀 Passo a Passo para Resolver

### 1️⃣ Verificar Status do Projeto

```bash
# Acesse
https://app.supabase.com/project/vfhzimozqsbdqknkncny

# Verifique se há mensagem de "Project paused"
```

**Se pausado:**
- Clique em **"Resume project"**
- Aguarde completar
- Teste: `./scripts/test-supabase.sh`

---

### 2️⃣ Obter Nova Connection String

No Supabase:
1. **Settings** → **Database**
2. **Connection string** → **URI**
3. Mode: **Session**
4. **Copie a string completa**

---

### 3️⃣ Atualizar Configuração

Edite o arquivo `.env.production`:

```bash
# Antes (pode estar incorreto)
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:TqgcYbFD5EKGAQuo@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false

# Depois (use a string que você copiou do Supabase)
DATABASE_URL=postgresql://postgres.vfhzimozqsbdqknkncny:[NOVA_SENHA]@aws-0-[REGION].pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
```

---

### 4️⃣ Testar Novamente

```bash
./scripts/test-supabase.sh
```

**Resultado esperado:**
```
✅ Conexão bem-sucedida!
PostgreSQL 15.x ...
```

---

## 📋 Checklist de Verificação

- [ ] Projeto Supabase está **ATIVO** (não pausado)
- [ ] Senha do database está **CORRETA**
- [ ] Connection string está no formato **CORRETO**
- [ ] Region está **CORRETA** (sa-east-1, us-east-1, etc)
- [ ] Portas estão **ABERTAS** no firewall (5432)
- [ ] SSL está **HABILITADO** (sslmode=require)

---

## 🔧 Alternativas de Connection String

### Opção 1: Session Mode (Recomendado)
```bash
postgresql://postgres.vfhzimozqsbdqknkncny:[PASSWORD]@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require&prepared_statements=false
```

### Opção 2: Transaction Mode
```bash
postgresql://postgres.vfhzimozqsbdqknkncny:[PASSWORD]@aws-0-sa-east-1.pooler.supabase.com:6543/postgres?sslmode=require&prepared_statements=false
```

### Opção 3: Direct Connection
```bash
postgresql://postgres:[PASSWORD]@db.vfhzimozqsbdqknkncny.supabase.co:5432/postgres?sslmode=require&prepared_statements=false
```

**Nota:** Substitua `[PASSWORD]` pela senha real do seu database!

---

## 🆘 Ainda com Problemas?

### Verificar no Supabase Dashboard

1. **Logs do Database:**
   - Settings → Database → Logs
   - Procure por erros de autenticação

2. **Connection Pooling:**
   - Settings → Database → Connection pooling
   - Verifique se está habilitado

3. **Network Restrictions:**
   - Settings → Database → Restrict connections
   - Certifique-se que seu IP não está bloqueado
   - Ou adicione `0.0.0.0/0` (todos IPs - apenas para teste!)

---

## 📞 Próximos Passos

1. ✅ **PRIMEIRO**: Acesse Supabase e reative o projeto se pausado
2. ✅ Obtenha a connection string correta do Dashboard
3. ✅ Atualize `.env.production` ou `SUPABASE_CONFIG.md`
4. ✅ Teste: `./scripts/test-supabase.sh`
5. ✅ Deploy no Portainer com a string correta

---

## 💡 Dica Importante

**SEMPRE obtenha a connection string diretamente do Supabase Dashboard!**

Não confie em strings antigas ou copiadas de outros lugares. A senha pode ter mudado, a região pode ser diferente, ou o formato pode ter sido atualizado.

---

**🔗 Link direto para suas configurações:**
https://app.supabase.com/project/vfhzimozqsbdqknkncny/settings/database