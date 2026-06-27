# Research: Login e Autenticação

## Decisions

### Provedor de autenticação: Supabase Auth (GoTrue)

- **Decision**: Utilizar o Supabase Auth nativo para autenticação por e-mail e senha.
- **Rationale**: O projeto já adota Supabase como backend/banco. Reutilizar GoTrue elimina a necessidade de um backend customizado, fornece sessão JWT, confirmação de e-mail e recuperação de senha prontos.
- **Alternatives considered**: Backend customizado Node.js/Express + JWT — rejeitado por adicionar complexidade desnecessária.
- **Security defaults inherited from GoTrue**:
  - Senhas hasheadas com **bcrypt** (nunca armazenadas em plaintext)
  - **Rate limiting**: 5 tentativas de login por minuto por IP; bloqueio temporário após tentativas repetidas
  - **JWT access token**: expiração padrão de 1 hora
  - **Refresh token**: rotação automática; token anterior é invalidado ao gerar um novo
  - **Password reset token**: expira em 1 hora, uso único (one-time use)
  - **Email confirmation**: obrigatório por padrão; configurável via `auth.config.toml`
  - **CSRF protection**: GoTrue gerencia tokens CSRF internamente nas chamadas de auth
  - Todas as comunicações com GoTrue são via **HTTPS** (imposto pelo Supabase)

### Tabela `usuarios` como espelho do auth provider

- **Decision**: Criar a tabela `usuarios` no schema `public` espelhando os campos do auth provider, conforme `banco-de-dados.md`.
- **Rationale**: O Supabase Auth mantém seus próprios registros em `auth.users`. A tabela `public.usuarios` é populada por triggers para permitir relacionamentos FK no banco de dados aplicacional.
- **Alternatives considered**: Usar diretamente `auth.users` — rejeitado porque RLS/policies do app não podem depender apenas do schema `auth` para relacionamentos comerciais.

### Página de login em React

- **Decision**: Recriar `login.html` como `src/pages/Login.tsx` mantendo o layout de duas colunas, identidade visual e comportamentos (mostrar/ocultar senha, modal de recuperação, toast de erro).
- **Rationale**: A migração para React/Vite/TS é a diretriz da stack. A tela legada serve de referência de design.
- **Alternatives considered**: Manter login.html estático — rejeitado por não integrar com Supabase Auth.

### Arquitetura RPC-first (acesso a dados via PostgreSQL Functions)

- **Decision**: Toda leitura e escrita de dados aplicacionais pelo frontend será feita exclusivamente através de RPCs (PostgreSQL Functions chamadas via `supabase.rpc()`), nunca por queries diretas a tabelas.
- **Rationale**: Centraliza a lógica de negócio no banco de dados, simplifica o frontend (que apenas chama funções), reduz a superfície de ataque (tabelas não precisam de permissão SELECT/INSERT direta para a role `anon`/`authenticated`) e facilita versionamento e auditoria.
- **Alternatives considered**: Queries diretas via `supabase.from()` — rejeitado por espalhar lógica de negócio entre frontend e RLS, dificultando manutenção e segurança.

### Testes de login com usuários de teste

- **Decision**: Criar 5 usuários de teste (um por persona de negócio) via seed SQL/Supabase Auth Admin API, com perfis RBAC vinculados.
- **Rationale**: Permite validar rapidamente cada perfil sem expor dados reais da empresa.
- **Alternatives considered**: Criar usuários manualmente no Studio — rejeitado por não ser reprodutível nem versionável.

### Mapeamento de personas para perfis técnicos

| Persona de negócio | Perfil técnico (RBAC) | E-mail de teste |
|--------------------|-----------------------|-----------------|
| Administrador | Administrador | admin@aptusflow.local |
| Analista Financeiro | Financeiro | financeiro@aptusflow.local |
| Gerente de Projetos | Projetos | projetos@aptusflow.local |
| Consultor Comercial | Comercial | comercial@aptusflow.local |
| Profissional Técnico | Técnico | tecnico@aptusflow.local |

> O perfil **Visualizador** é um modo restrito auxiliar sem persona de negócio dedicada; pode ser usado como restrição adicional sobre qualquer perfil.
