# Tasks: Login e Autenticação

**Input**: Design documents from `/specs/003-login-autenticacao/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/login-flow.md, quickstart.md

**Tests**: Not explicitly requested — test tasks are included as smoke/validation only, not TDD.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Ensure development environment is ready and Supabase local instance is running

- [ ] T001 Verify Docker Desktop is running and Supabase CLI is installed (`supabase --version`)
- [ ] T002 [P] Create `.env.example` in repo root with placeholder entries: `VITE_SUPABASE_URL=`, `VITE_SUPABASE_ANON_KEY=`, `SEED_USER_PASSWORD=`
- [ ] T003 [P] Create `.env.local` from `.env.example` with real values for local dev (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SEED_USER_PASSWORD`)
- [ ] T004 [P] Verify `src/services/supabase.ts` client initializes correctly (already exists, smoke test)
- [ ] T005 Run `supabase status` to confirm local Supabase container is healthy (container já está rodando no Docker local)

---

## Phase 2: Foundational (Database Schema + RPCs + Auth Config)

**Purpose**: Create the database schema (tables, triggers, RLS, RPCs) that all user stories depend on

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete

- [ ] T006 Create migration `supabase/migrations/00000000000000_usuarios_perfis.sql` with:
  - Table `usuarios` (mirror of `auth.users`) with all columns per data-model.md
  - Table `perfis` (1:1 with usuarios) with perfil_acesso, status, departamento
  - Table `audit_log` (append-only security events) per data-model.md §audit_log
  - Trigger function to sync `auth.users` → `public.usuarios` on INSERT/UPDATE
  - Enable RLS on all three tables

- [ ] T007 [P] Add RLS policies to `supabase/migrations/00000000000000_usuarios_perfis.sql` per data-model.md §RLS:
  - `usuarios`: SELECT (self), INSERT/UPDATE (service role trigger), DELETE (blocked)
  - `perfis`: SELECT (self + admin), INSERT (admin), UPDATE (self fields + admin), DELETE (blocked)
  - `audit_log`: INSERT only (via SECURITY DEFINER functions), SELECT (admin via RPC), no UPDATE/DELETE

- [ ] T008 [P] Create helper function `existe_perfil_admin(uid uuid)` in migration file per data-model.md §Função auxiliar de RLS

- [ ] T009 Create RPC functions in `supabase/migrations/00000000000000_usuarios_perfis.sql`:
  - `obter_perfil_usuario()` — SECURITY DEFINER, returns profile for `auth.uid()`
  - `obter_permissoes_usuario()` — SECURITY DEFINER, returns `{ modulo, pode_ler, pode_escrever }[]` mapped from `perfil_acesso`
  - `criar_perfil_teste(email, senha, nome, perfil_acesso)` — SECURITY DEFINER, checks `existe_perfil_admin(auth.uid())`, creates auth user + perfil, inserts audit_log entry
  - `registrar_evento_auditoria(evento, usuario_id, ip_origem, user_agent)` — SECURITY DEFINER, appends to `audit_log`

- [ ] T010 [P] Create type definitions in `src/types/auth.ts`:
  - `PerfilUsuario` type: `{ nome, perfil_acesso, status, avatar_url, departamento }`
  - `PermissaoModulo` type: `{ modulo, pode_ler, pode_escrever }`
  - `PerfilAcesso` union type: `'Administrador' | 'Financeiro' | 'Projetos' | 'Comercial' | 'Técnico' | 'Visualizador'`

- [ ] T011 [P] Create auth service in `src/services/auth.service.ts`:
  - `getPerfilUsuario()`: calls `supabase.rpc('obter_perfil_usuario')`, handles null (force logout + redirect per Null Profile Contract)
  - `getPermissoesUsuario()`: calls `supabase.rpc('obter_permissoes_usuario')`
  - `signIn(email, password)`: wraps `supabase.auth.signInWithPassword` with error normalization
  - `signOut()`: wraps `supabase.auth.signOut`
  - `resetPassword(email)`: wraps `supabase.auth.resetPasswordForEmail`

- [ ] T012 Run `supabase db reset` to apply migration and verify schema creation

- [ ] T013 [P] Configure GoTrue auth settings to require email confirmation: in `supabase/config.toml` set `[auth] enable_confirmations = true` (or verify it's the default). This covers FR-013 (email confirmation gate).

**Checkpoint**: Database schema, RPCs, and auth service ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Login com e-mail e senha (Priority: P1) 🎯 MVP

**Goal**: Página de login funcional baseada em `login.html`, integrada ao Supabase Auth, com validação completa, tratamento de erros e redirecionamento por perfil

**Independent Test**: Acessar `/login`, digitar credenciais válidas de qualquer persona, verificar redirecionamento para a tela apropriada ao perfil

### Implementation for User Story 1

- [ ] T014 [US1] Create `src/pages/Login.tsx` — full React component recreating `login.html` layout:
  - Two-column layout with brand panel (logo, tagline, features list) and form panel
  - Email input with label, placeholder, `aria-invalid` state, inline error display
  - Password input with show/hide toggle (eye icon), `aria-invalid` state, inline error
  - "Lembrar de mim" checkbox (default checked)
  - Submit button "Acessar painel" with loading spinner state (`.btn-loading`)
  - "Esqueci a senha" link (opens modal — implemented in US2)
  - Mobile-responsive: single column below 1024px, brand bar above form
  - All CSS inline or co-located — reuse `aptus.css` design tokens

- [ ] T015 [US1] Implement form validation logic in `src/pages/Login.tsx`:
  - Email: required, valid format check (`type="email"`), trim + lowercase before submit
  - Password: required, min 8 characters (mirrors FR-009), trim not applied
  - Inline error messages in Portuguese below each field on validation failure
  - Real-time clearing of `aria-invalid` on input change

- [ ] T016 [US1] Implement login submission flow in `src/pages/Login.tsx`:
  - On submit: validate → disable button 3s (client rate limit per FR-010) → call `authService.signIn(email, password)`
  - Loading: `.btn-loading` class on button with CSS spinner
  - Success: call `authService.getPerfilUsuario()` → redirect based on `perfil_acesso`:
    - Administrador → `/dashboard`
    - Financeiro → `/dashboard`
    - Projetos → `/projetos`
    - Comercial → `/clientes`
    - Técnico → `/projetos`
  - Use SPA routing if React Router is available, otherwise fallback to `window.location.href` for navigation.
  - Error: normalize Supabase error codes to user-facing messages:
    - Invalid credentials → "E-mail ou senha inválidos." (generic, per FR-008)
    - Email not confirmed → "Confirme seu e-mail antes de fazer login."
    - Inactive account → "Conta desativada. Entre em contato com o administrador."
    - Network/unknown → "Serviço de autenticação temporariamente indisponível."

- [ ] T017 [US1] Implement toast notification system in `src/components/ui/Toast.tsx`:
  - Fixed position bottom-center, slide-up animation
  - Support `error` (red/danger bg) and `success` (dark bg) variants
  - Auto-dismiss after 3.5s (unless `prefers-reduced-motion`)
  - Accessible: `role="alert"`, `aria-live="polite"`

- [ ] T018 [US1] Integrate toast into login error handling — all error messages from T014 display via `<Toast>` instead of inline for credential errors

- [ ] T019 [US1] Update `src/App.tsx` to route `/login` to `<Login />` component (simple conditional render or React Router if available)

- [ ] T020 [US1] Implement null profile handling per contracts/login-flow.md §Null Profile Contract:
  - If `getPerfilUsuario()` returns null: display toast "Perfil não encontrado.", call `signOut()`, redirect to `/login`

**Checkpoint**: Login page fully functional — any persona can authenticate and be redirected correctly

---

## Phase 4: User Story 2 — Recuperação de senha (Priority: P2)

**Goal**: Modal de "Esqueci a senha" funcional, com envio de link de redefinição e feedback genérico de privacidade

**Independent Test**: Clicar em "Esqueci a senha" na tela de login, informar um e-mail, verificar mensagem de confirmação e capturar o e-mail no Inbucket (`http://localhost:54324`)

### Implementation for User Story 2

- [ ] T021 [US2] Implement forgot password modal in `src/pages/Login.tsx`:
  - Overlay (`.modal-overlay`) with centered card (`.modal-content`)
  - Title "Recuperar acesso", description text, email input, Cancel/Send buttons
  - Open: button click → show modal, focus email input, close on Escape/overlay click
  - Close: restore focus to trigger element per `login.html` pattern
  - Send: validate email → call `authService.resetPassword(email)` → show success toast
  - Success message: "Enviamos um link de redefinição para [email] – verifique sua caixa de entrada." (per US2-Scenario2 — same message whether email exists or not)

- [ ] T022 [US2] Implement password reset callback page in `src/pages/ResetPassword.tsx`:
  - Minimal page that captures the reset token from URL hash
  - On load: if token valid, show "Senha redefinida com sucesso. Faça login com sua nova senha." and redirect to `/login` after 3s
  - If token expired/invalid: show "Link expirado. Solicite uma nova redefinição de senha." with link back to `/login`
  - No automatic login — forced re-authentication per FR-014

**Checkpoint**: Password reset flow works end-to-end — request via modal, email captured in Inbucket, reset confirmation page handles success/expiry

---

## Phase 5: User Story 3 — Usuários de teste para cada persona (Priority: P3)

**Goal**: Seed database com 5 usuários de teste (um por persona), cada um com perfil RBAC vinculado, e verificação de que todos conseguem fazer login

**Independent Test**: Rodar `supabase db reset`, acessar `/login` com cada e-mail de persona, confirmar autenticação e redirecionamento

### Implementation for User Story 3

- [ ] T023 [US3] Create `supabase/seed.sql` with test users and profiles:
  - Read `SEED_USER_PASSWORD` from environment (fail if not set)
  - Create 5 auth users via `supabase_auth.create_user()` or raw `auth.users` insert:
    - `admin@aptusflow.local` → Administrador
    - `financeiro@aptusflow.local` → Financeiro
    - `projetos@aptusflow.local` → Projetos
    - `comercial@aptusflow.local` → Comercial
    - `tecnico@aptusflow.local` → Técnico
  - Set `email_confirmed_at` to now (simulate confirmed emails per data-model.md §Email Confirmation Policy)
  - Insert corresponding rows in `public.perfis` with correct `perfil_acesso`, `status = 'Ativo'`, `nome` matching persona
  - Ensure trigger syncs `auth.users` → `public.usuarios`

- [ ] T024 [US3] Verify login for all 5 personas:
  - Start local env (`npm run dev`)
  - Log in with each email + `SEED_USER_PASSWORD`
  - Confirm redirection matches the perfil_acesso mapping from T014
  - Confirm no PII leakage in error responses per SC-005

- [ ] T025 [US3] Test edge cases per spec.md §Edge Cases:
  - Blank fields → inline validation errors
  - Wrong password → "E-mail ou senha inválidos." (generic)
  - Non-existent email → "E-mail ou senha inválidos." (same message)
  - Inactive account → block with specific message
  - Supabase stopped → "Serviço de autenticação temporariamente indisponível."

**Checkpoint**: All 5 personas authenticate successfully; edge cases validated

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final quality improvements, security hardening, and documentation

- [ ] T026 [P] Add `remember` session persistence: pass `remember` parameter to `signInWithPassword` options per contracts/login-flow.md §"Lembrar de mim" Contract

- [ ] T027 [P] Add audit logging RPC call on login success/failure in `src/services/auth.service.ts` — call `registrar_evento_auditoria` with event type, user ID, and client IP

- [ ] T028 [P] Add `.gitignore` entry for `.env.local` to prevent accidental commit of credentials and keys

- [ ] T029 Run `quickstart.md` validation checklist — confirm all 7 scenarios pass end-to-end

- [ ] T030 Update `AGENTS.md` SPECKIT block to confirm current plan reference is correct

- [ ] T031 Run `npm run build` to verify TypeScript compilation and Vite build succeed with no errors

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001, T004) — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (T005–T011) — No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on Foundational (T005–T011) + T017 (Toast component from US1) — Can otherwise proceed in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Foundational (T005–T011) + US1 complete (seed uses login page to verify) — Must run after US1 is functional
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) ─── BLOCKS ALL ───
    │
    ├──► Phase 3 (US1: Login) ───► Phase 5 (US3: Test Users, depends on US1 for verification)
    │         │
    │         └──► Phase 4 (US2: Password Reset, depends on T017 Toast)
    │
    └──► Phase 6 (Polish)
```

### Within Each Phase

- **Phase 2**: T005 → T006+T007 (depend on table creation) → T008 (depends on helper) → T009+T010 (parallel, depend on schema) → T011 (validation)
- **Phase 3**: T012 → T013+T014 → T015 → T016+T017+T018 → T019+T020
- **Phase 4**: T021 → T022 (modal first, then callback page)
- **Phase 5**: T023 → T024 → T025 (seed → verify → edge cases)
- **Phase 6**: All [P] tasks can run in parallel

### Parallel Opportunities

- **Phase 2**: T006, T007, T009, T010 can all start once T005 schema is created
- **Phase 3 vs Phase 4**: US1 and US2 can be developed in parallel once Phase 2 is complete (T017 is the only cross-dependency)
- **Phase 6**: T026, T027, T028 are all independent files

---

## Parallel Example: User Story 1

```text
Developer A: T012 (Login.tsx component structure)
Developer B: T017 (Toast component) ──► then integrate with T018

After T012 + T013 complete:
Developer A: T014 (login flow) → T019 (App.tsx routing) → T020 (null profile)
Developer B: T017 → T018 (toast integration)
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T004)
2. Complete Phase 2: Foundational (T005–T011) — **CRITICAL GATE**
3. Complete Phase 3: US1 Login (T012–T020)
4. **STOP and VALIDATE**: Can any persona log in and be redirected?
5. Deploy/demo MVP

### Incremental Delivery

1. **MVP** (US1): Login funcional → deploy
2. **+US2**: Password reset → deploy
3. **+US3**: Test users + full edge case validation → deploy
4. **+Polish**: Security hardening, audit logging, build validation → final release

---

## Task Summary

| Phase | User Story | Task Count | Key Files |
|-------|-----------|------------|-----------|
| Phase 1 | Setup | 4 | `.env.local`, `supabase` |
| Phase 2 | Foundational | 7 | `migrations/*.sql`, `src/types/auth.ts`, `src/services/auth.service.ts` |
| Phase 3 | US1 (P1) 🎯 MVP | 7 | `src/pages/Login.tsx`, `src/components/ui/Toast.tsx`, `src/App.tsx` |
| Phase 4 | US2 (P2) | 2 | `src/pages/Login.tsx`, `src/pages/ResetPassword.tsx` |
| Phase 5 | US3 (P3) | 3 | `supabase/seed.sql` |
| Phase 6 | Polish | 6 | `src/services/auth.service.ts`, `.gitignore`, `AGENTS.md` |
| **Total** | | **29** | |

| User Story | Independent Test |
|------------|-----------------|
| US1 (P1) | Login with any persona credentials → correct redirect |
| US2 (P2) | Forgot password → email captured in Inbucket → reset page handles token |
| US3 (P3) | `db reset` → all 5 personas login successfully → edge cases validated |
