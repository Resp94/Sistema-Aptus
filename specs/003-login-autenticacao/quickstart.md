# Quickstart: Validar Login e Autenticação

### Pré-requisitos

- Docker Desktop rodando
- Node.js 20+
- Variáveis `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` configuradas em `.env.local` (valores do `supabase start`)
- Variável `SEED_USER_PASSWORD` definida no ambiente usada pelo `seed.sql` para criar as senhas dos usuários de teste

### Configurar senha de teste (obrigatório)

As senhas dos usuários de teste NÃO estão hardcoded. Crie um arquivo `.env.local` na raiz com:

```env
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=<key-do-supabase-start>
SEED_USER_PASSWORD=<senha-segura-para-testes>
```

O `seed.sql` lê `SEED_USER_PASSWORD` do ambiente. Sem essa variável, o seed falha.

### Subir o ambiente local

```bash
npm install
npx supabase start
npm run dev
```

### Criar schema e usuários de teste

```bash
npx supabase db reset
```

Isso aplica a migration `00000000000000_UsuariosPerfis.sql` e executa `seed.sql` com os usuários de teste.

### Cenários de validação

> **Senha de teste**: todos os cenários abaixo usam a senha definida em `SEED_USER_PASSWORD` no `.env.local`. Substitua `<senha>` pelo valor configurado.

1. **Login bem-sucedido — Administrador**
   - Acesse `http://localhost:5173/login`
   - E-mail: `admin@aptusflow.local`
   - Senha: `<senha>`
   - Esperado: redirecionamento para `/dashboard`

2. **Login bem-sucedido — Analista Financeiro**
   - E-mail: `financeiro@aptusflow.local`
   - Senha: `<senha>`
   - Esperado: redirecionamento para `/dashboard`

3. **Login bem-sucedido — Gerente de Projetos**
   - E-mail: `projetos@aptusflow.local`
   - Senha: `<senha>`
   - Esperado: redirecionamento para `/projetos`

4. **Login bem-sucedido — Consultor Comercial**
   - E-mail: `comercial@aptusflow.local`
   - Senha: `<senha>`
   - Esperado: redirecionamento para `/clientes`

5. **Login bem-sucedido — Profissional Técnico**
   - E-mail: `tecnico@aptusflow.local`
   - Senha: `<senha>`
   - Esperado: redirecionamento para `/projetos`

6. **Senha incorreta**
   - E-mail: `admin@aptusflow.local`
   - Senha: `senhaerrada`
   - Esperado: mensagem "E-mail ou senha inválidos" no toast, sem redirecionamento

7. **Recuperação de senha**
   - Clique em "Esqueci a senha"
   - Informe `admin@aptusflow.local`
   - Esperado: mensagem de confirmação genérica
   - Verifique o e-mail capturado no Inbucket (`http://localhost:54324`)

### Testes automatizados

```bash
npm run test
```

Esperado: todos os testes de fumaça do cliente Supabase passam e a conexão local está saudável.
