# Data Model: Login e Autenticação

## Entities

### `usuarios`

Espelho dos dados do provedor de autenticação. Não contém regras de negócio do aplicativo.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | UID gerado pelo auth provider | Interno |
| email | text | Email único de autenticação | **PII** |
| email_confirmed_at | timestamp | Data de confirmação do email | Interno |
| phone | text | Telefone vinculado à conta | **PII** |
| phone_confirmed_at | timestamp | Data de confirmação do telefone | Interno |
| raw_user_meta_data | jsonb | Metadados públicos do usuário (ex.: nome, avatar) | **PII** (contém nome) |
| raw_app_meta_data | jsonb | Metadados internos do app controlados pelo backend | Interno |
| aud | text | Audience do token de autenticação | Interno |
| created_at | timestamp | Data de criação da conta no auth | Interno |
| updated_at | timestamp | Última atualização no auth | Interno |
| last_sign_in_at | timestamp | Último login realizado | Interno |

### `perfis`

Dados aplicacionais de cada usuário autenticado.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador do perfil | Interno |
| usuario_id | uuid fk | Referência a `usuarios.id` (1:1) | Interno |
| nome | text | Nome completo exibido no sistema | **PII** |
| avatar_url | text | URL do avatar | Interno |
| perfil_acesso | text | Perfil RBAC: Administrador, Financeiro, Projetos, Comercial, Técnico, Visualizador | Interno |
| status | text | Ativo ou Inativo | Interno |
| departamento | text | Departamento/setor | Interno |
| created_at | timestamp | Data de criação | Interno |
| updated_at | timestamp | Última atualização | Interno |

## Relationships

- `perfis.usuario_id → usuarios.id` (1:1)
- Todo perfil deve referenciar um usuário existente.

## Validation Rules

- `usuarios.email` deve ser único e formato de e-mail válido (validado pelo Supabase Auth).
- `perfis.perfil_acesso` deve ser um dos valores definidos no documento de personas: `Administrador`, `Financeiro`, `Projetos`, `Comercial`, `Técnico`, `Visualizador`.
- `perfis.status` deve ser `Ativo` ou `Inativo`.
- Apenas um perfil por `usuario_id`.

## State Transitions

- `Ativo` → `Inativo`: impede novos logins, mas mantém dados.
- `Inativo` → `Ativo`: permite logins novamente.

## Row Level Security (RLS)

As RLS são a camada de defesa granular que protege cada ação nas tabelas. **Nenhuma política usa `ALL`** — cada operação (SELECT, INSERT, UPDATE, DELETE) tem sua própria política explícita.

### `usuarios`

| Operação | Política | Regra |
|----------|----------|-------|
| SELECT | `usuarios_select_self` | `auth.uid() = id` — usuário lê apenas o próprio registro |
| INSERT | `usuarios_insert_service` | Permitido apenas via trigger pós-criação no `auth.users` (service role) |
| UPDATE | `usuarios_update_service` | Permitido apenas via trigger de sincronização do `auth.users` (service role) |
| DELETE | ❌ **Não permitido** | Usuários são desativados (`perfis.status = 'Inativo'`), nunca deletados |

### `perfis`

| Operação | Política | Regra |
|----------|----------|-------|
| SELECT | `perfis_select_self` | `auth.uid() = usuario_id` — usuário lê o próprio perfil |
| SELECT | `perfis_select_admin` | `existe_perfil_admin(auth.uid())` — Administrador lê todos os perfis |
| INSERT | `perfis_insert_admin` | `existe_perfil_admin(auth.uid())` — apenas Administrador cria perfis |
| UPDATE | `perfis_update_self` | `auth.uid() = usuario_id` — usuário edita `nome`, `avatar_url`, `departamento` (campos próprios) |
| UPDATE | `perfis_update_admin` | `existe_perfil_admin(auth.uid())` — Administrador edita `perfil_acesso` e `status` de qualquer perfil |
| DELETE | ❌ **Não permitido** | Perfis são desativados (`status = 'Inativo'`), nunca deletados. Mantém rastreabilidade. |

### Função auxiliar de RLS

```sql
CREATE OR REPLACE FUNCTION existe_perfil_admin(uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfis
    WHERE usuario_id = uid AND perfil_acesso = 'Administrador' AND status = 'Ativo'
  );
$$;
```

### `audit_log`

Registro imutável de eventos de segurança e ações administrativas.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador do evento | Interno |
| evento | text | Tipo: `login_sucesso`, `login_falha`, `senha_alterada`, `usuario_criado`, `conta_desativada`, `conta_ativada` | Interno |
| usuario_id | uuid fk | Usuário afetado (referência `usuarios.id`) | **PII** |
| ip_origem | text | IP de origem da ação | **PII** |
| user_agent | text | User-Agent do cliente | Interno |
| created_at | timestamp | Data/hora do evento | Interno |

> **Nota:** A tabela `audit_log` é somente INSERT (append-only). Nenhuma política de UPDATE ou DELETE é concedida. A leitura é restrita a Administradores via RPC.

### Email Confirmation Policy

- **Ambiente de desenvolvimento**: E-mails de confirmação são capturados pelo Inbucket (`http://localhost:54324`). O desenvolvedor clica no link para confirmar.
- **Ambiente de produção**: E-mails são enviados pelo servidor SMTP configurado no Supabase. O usuário DEVE confirmar o e-mail antes do primeiro login.
- **Contas de teste (seed)**: O `email_confirmed_at` é preenchido automaticamente no seed, simulando e-mails já confirmados para agilizar os testes.

## RPC Functions (PostgreSQL)

Seguindo a arquitetura **RPC-first**, o frontend nunca faz queries diretas às tabelas. Todo acesso é intermediado por funções PostgreSQL chamadas via `supabase.rpc()`.

| Function | Signature | Description |
|----------|-----------|-------------|
| `obter_perfil_usuario()` | → `TABLE(...)` | Retorna os dados do perfil do usuário autenticado (`auth.uid()`) |
| `obter_permissoes_usuario()` | → `TABLE(...)` | Retorna os módulos e permissões do usuário autenticado |
| `criar_perfil_teste(email, senha, nome, perfil_acesso)` | → `usuario_id, perfil_id` | Admin: cria usuário auth + perfil para testes |
