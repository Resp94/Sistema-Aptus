# Tasks: Demais Telas por Perfil de Acesso

**Input**: Design documents from `/specs/005-demais-telas-perfis/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included because the specification defines independent tests, quickstart scenarios, and final gates for each user story.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm baseline, references, and migration scaffolding before domain work starts.

- [x] T001 Run `npm test` and record the current baseline result in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T002 Run `npm run build` and record the current baseline result in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T003 Run `npm run supabase:status` and confirm local Supabase readiness before migration work in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T004 [P] Review `reference/legacy-html/fluxo-caixa.html`, `reference/legacy-html/contas-pagar.html`, and `reference/legacy-html/contas-receber.html` and note reusable layout sections in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T005 [P] Review `reference/legacy-html/propostas.html`, `reference/legacy-html/contratos.html`, and `reference/legacy-html/cobrancas.html` and note reusable layout sections in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T006 [P] Review `reference/legacy-html/equipe.html`, `reference/legacy-html/relatorios.html`, and `reference/legacy-html/configuracoes.html` and note reusable layout sections in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T007 Run `npx supabase migration new demais_telas_schema` and use the generated `supabase/migrations/*_demais_telas_schema.sql`
- [x] T008 Run `npx supabase migration new demais_telas_security` and use the generated `supabase/migrations/*_demais_telas_security.sql`
- [x] T009 Run `npx supabase migration new demais_telas_rpc_financeiro_read` and use the generated `supabase/migrations/*_demais_telas_rpc_financeiro_read.sql`
- [x] T010 Run `npx supabase migration new demais_telas_rpc_financeiro_write` and use the generated `supabase/migrations/*_demais_telas_rpc_financeiro_write.sql`
- [x] T011 Run `npx supabase migration new demais_telas_rpc_comercial_read` and use the generated `supabase/migrations/*_demais_telas_rpc_comercial_read.sql`
- [x] T012 Run `npx supabase migration new demais_telas_rpc_comercial_write` and use the generated `supabase/migrations/*_demais_telas_rpc_comercial_write.sql`
- [x] T013 Run `npx supabase migration new demais_telas_rpc_equipe_read` and use the generated `supabase/migrations/*_demais_telas_rpc_equipe_read.sql`
- [x] T014 Run `npx supabase migration new demais_telas_rpc_equipe_write` and use the generated `supabase/migrations/*_demais_telas_rpc_equipe_write.sql`
- [x] T015 Run `npx supabase migration new demais_telas_rpc_relatorios_config_read` and use the generated `supabase/migrations/*_demais_telas_rpc_relatorios_config_read.sql`
- [x] T016 Run `npx supabase migration new demais_telas_rpc_config_write` and use the generated `supabase/migrations/*_demais_telas_rpc_config_write.sql`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data, security, shared UI, and test infrastructure required before any user story can be implemented.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T017 Implement tables, constraints, indexes, and updated audit enum/event support for `propostas`, `contratos`, `documentos`, `cobrancas`, `pagamentos_cobrancas`, `membros_equipe`, `alocacoes_equipe`, `apontamentos_horas`, `agendamentos_relatorios`, `exportacoes_relatorios`, `configuracoes_empresa`, and `preferencias_notificacoes` in `supabase/migrations/*_demais_telas_schema.sql`
- [x] T018 Implement RLS enablement, `TO authenticated` policies, explicit `GRANT`/`REVOKE`, and helper usage for all new public tables in `supabase/migrations/*_demais_telas_security.sql`
- [x] T019 Implement shared RPC permission guard patterns with `auth.uid()`, RBAC module checks, fixed `search_path`, and revoked `PUBLIC` execute access in `supabase/migrations/*_demais_telas_security.sql`
- [x] T020 Implement shared SQL validation patterns for required fields, money, dates, inactive links, integration-pending states, and duplicate cobranca/lancamento prevention in `supabase/migrations/*_demais_telas_security.sql`
- [x] T021 Seed profile/route coverage for Administrador, Financeiro, Comercial, Projetos, Tecnico, and Visualizador in `supabase/seed.sql`
- [x] T022 [P] Create shared status, money, date, integration, and API error types in `src/types/common.ts`
- [x] T023 [P] Create shared UI helpers for loading, empty, error, and integration-pending states in `src/components/ui/States.tsx`
- [x] T024 [P] Create shared CSS utilities for responsive data grids, tables, cards, focus states, and badges in `src/components/ui/states.css`
- [x] T025 [P] Add service test helpers that mock `supabase.rpc()` without table queries in `src/services/rpc-test-utils.ts`
- [x] T026 [P] Add route/permission test helpers for all technical profiles in `src/lib/route-test-utils.ts`
- [x] T027 Update `src/main.tsx` or `src/App.tsx` imports to load shared UI state styles from `src/components/ui/states.css`
- [x] T028 Run `npm run supabase:reset` and fix migration/seed failures before starting user story pages

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel.

---

## Phase 3: User Story 1 - Financeiro opera o ciclo financeiro completo (Priority: P1) MVP

**Goal**: Financeiro and Administrador can operate Fluxo de Caixa, Contas a Pagar, Contas a Receber, and financial actions in Cobrancas using persisted data.

**Independent Test**: Login as Financeiro, navigate through `/fluxo-caixa`, `/contas-pagar`, `/contas-receber`, and `/cobrancas`, create/edit/register permitted records, apply filters, and confirm indicators/tables persist after reload.

### Tests for User Story 1

- [x] T029 [P] [US1] Add financeiro service RPC contract tests for summaries, lists, metrics, create/update, and payment calls in `src/services/financeiro.service.test.ts`
- [x] T030 [P] [US1] Add financial permission and hidden-action tests for read/write combinations in `src/lib/permissoes.test.ts`

### Implementation for User Story 1

- [x] T031 [US1] Implement financeiro read RPCs from `contracts/financeiro-rpc.md` with derived `status_exibicao` in `supabase/migrations/*_demais_telas_rpc_financeiro_read.sql`
- [x] T032 [US1] Implement financeiro write RPCs from `contracts/financeiro-rpc.md` with validation, rollback-safe errors, audit where sensitive, and no duplicate cobranca/lancamento in `supabase/migrations/*_demais_telas_rpc_financeiro_write.sql`
- [x] T033 [P] [US1] Define Fluxo de Caixa, Contas a Pagar, Contas a Receber, and shared financial types in `src/types/financeiro.ts`
- [x] T034 [US1] Implement `supabase.rpc()` only calls for financeiro reads/writes in `src/services/financeiro.service.ts`
- [x] T035 [P] [US1] Implement `/fluxo-caixa` page layout and state handling from `reference/legacy-html/fluxo-caixa.html` in `src/pages/FluxoCaixaPage.tsx`
- [x] T036 [P] [US1] Implement responsive/focus-safe styles for Fluxo de Caixa in `src/pages/FluxoCaixaPage.css`
- [x] T037 [P] [US1] Implement `/contas-pagar` page layout, filters, create/edit account, and register payment flows from `reference/legacy-html/contas-pagar.html` in `src/pages/ContasPagarPage.tsx`
- [x] T038 [P] [US1] Implement responsive/focus-safe styles for Contas a Pagar in `src/pages/ContasPagarPage.css`
- [x] T039 [P] [US1] Implement `/contas-receber` page layout, filters, create invoice, cobranças entry point, and register receipt flows from `reference/legacy-html/contas-receber.html` in `src/pages/ContasReceberPage.tsx`
- [x] T040 [P] [US1] Implement responsive/focus-safe styles for Contas a Receber in `src/pages/ContasReceberPage.css`
- [x] T041 [US1] Implement shared `/cobrancas` base page for the Financeiro view, payment/conciliation action gating, and recoverable states in `src/pages/CobrancasPage.tsx` and `src/pages/CobrancasPage.css`
- [x] T042 [US1] Wire Fluxo de Caixa, Contas a Pagar, Contas a Receber, and Cobrancas into explicit protected routes and remove those modules from the placeholder route loop in `src/App.tsx`
- [x] T043 [US1] Refresh financeiro lists and indicators after successful writes without manual reload in `src/pages/FluxoCaixaPage.tsx`, `src/pages/ContasPagarPage.tsx`, `src/pages/ContasReceberPage.tsx`, and `src/pages/CobrancasPage.tsx`
- [x] T044 [US1] Validate US1 with C2 and C11 from `specs/005-demais-telas-perfis/quickstart.md`

**Checkpoint**: User Story 1 is fully functional and testable independently.

---

## Phase 4: User Story 2 - Comercial gerencia propostas, contratos e cobrancas (Priority: P1)

**Goal**: Comercial and Administrador can create proposals, progress commercial statuses, convert approved proposals into contracts, and track customer cobranças without fake external integrations.

**Independent Test**: Login as Comercial, access `/propostas`, `/contratos`, and `/cobrancas`, create records, update statuses, and validate only permitted commercial data/actions appear.

### Tests for User Story 2

- [x] T045 [P] [US2] Add comercial service RPC contract tests for propostas, contratos, cobrancas, integration-pending results, and duplicate rejection in `src/services/comercial.service.test.ts`
- [x] T046 [P] [US2] Add cobrancas ownership tests for Comercial, Financeiro, and Administrador action visibility in `src/lib/permissoes.test.ts`

### Implementation for User Story 2

- [x] T047 [US2] Implement comercial read RPCs from `contracts/comercial-rpc.md` with profile-scoped field omission in `supabase/migrations/*_demais_telas_rpc_comercial_read.sql`
- [x] T048 [US2] Implement comercial write RPCs from `contracts/comercial-rpc.md` with proposal status transitions, contract renewal/closure audit, cobrança duplicate protection, and integration-pending states in `supabase/migrations/*_demais_telas_rpc_comercial_write.sql`
- [x] T049 [P] [US2] Define proposta, contrato, cobranca, documento, and commercial integration types in `src/types/comercial.ts`
- [x] T050 [US2] Implement `supabase.rpc()` only calls for comercial reads/writes in `src/services/comercial.service.ts`
- [x] T051 [P] [US2] Implement `/propostas` page layout, filters, detail, create/update, and send-pending flows from `reference/legacy-html/propostas.html` in `src/pages/PropostasPage.tsx`
- [x] T052 [P] [US2] Implement responsive/focus-safe styles for Propostas in `src/pages/PropostasPage.css`
- [x] T053 [P] [US2] Implement `/contratos` page layout, filters, detail, create-from-proposal, renewal, closure, and document-pending states from `reference/legacy-html/contratos.html` in `src/pages/ContratosPage.tsx`
- [x] T054 [P] [US2] Implement responsive/focus-safe styles for Contratos in `src/pages/ContratosPage.css`
- [x] T055 [P] [US2] Extend the existing `/cobrancas` page with commercial filters, detail, reminders, boleto-pending state, and commercial/financial ownership separation from `reference/legacy-html/cobrancas.html` in `src/pages/CobrancasPage.tsx`
- [x] T056 [P] [US2] Extend responsive/focus-safe styles for the commercial Cobrancas states in `src/pages/CobrancasPage.css`
- [x] T057 [US2] Wire Propostas and Contratos into explicit protected routes, keep the existing Cobrancas route single, and remove those modules from the placeholder route loop in `src/App.tsx`
- [x] T058 [US2] Validate US2 with C3, C10, and C11 from `specs/005-demais-telas-perfis/quickstart.md`

**Checkpoint**: User Story 2 works independently and Cobrancas respects shared Comercial/Financeiro ownership.

---

## Phase 5: User Story 3 - Projetos e Tecnico acompanham equipe, capacidade e apontamentos (Priority: P2)

**Goal**: Projetos can manage team capacity and allocations, while Tecnico sees only their permitted operational slice and own editable data.

**Independent Test**: Login as Projetos and Tecnico, compare `/equipe`, and confirm Projetos sees full allocation/capacity while Tecnico does not receive cost or unrelated member data.

### Tests for User Story 3

- [x] T059 [P] [US3] Add equipe service RPC contract tests for manager versus tecnico scopes and cost omission in `src/services/equipe.service.test.ts`

### Implementation for User Story 3

- [x] T060 [US3] Implement equipe read RPCs from `contracts/equipe-rpc.md` with `alocacoes_projeto` as Tecnico authorization source and `alocacoes_equipe` as operational source in `supabase/migrations/*_demais_telas_rpc_equipe_read.sql`
- [x] T061 [US3] Implement equipe write RPCs from `contracts/equipe-rpc.md` with own-profile limits for Tecnico and audit for member inactivation in `supabase/migrations/*_demais_telas_rpc_equipe_write.sql`
- [x] T062 [P] [US3] Define member, allocation, capacity, and time-entry types in `src/types/equipe.ts`
- [x] T063 [US3] Implement `supabase.rpc()` only calls for equipe reads/writes in `src/services/equipe.service.ts`
- [x] T064 [P] [US3] Implement `/equipe` page layout, metrics, members table, allocation by project, capacity view, create/edit/allocation, and Tecnico restricted mode from `reference/legacy-html/equipe.html` in `src/pages/EquipePage.tsx`
- [x] T065 [P] [US3] Implement responsive/focus-safe styles for Equipe in `src/pages/EquipePage.css`
- [x] T066 [US3] Wire Equipe into an explicit protected route and remove it from the placeholder route loop in `src/App.tsx`
- [x] T067 [US3] Validate US3 with C4 from `specs/005-demais-telas-perfis/quickstart.md`

**Checkpoint**: User Story 3 is independently usable by Projetos and Tecnico.

---

## Phase 6: User Story 4 - Administrador controla configuracoes e usuarios (Priority: P2)

**Goal**: Administrador manages company settings, users, permissions, notifications, and appearance while Tecnico only edits their own allowed settings.

**Independent Test**: Login as Administrador and Tecnico, access `/configuracoes`, verify visible tabs/actions, save allowed changes, and confirm permission changes refresh navigation/guards.

### Tests for User Story 4

- [x] T068 [P] [US4] Add configuracoes service RPC contract tests for admin-only global settings, own settings, and profile update flows in `src/services/configuracoes.service.test.ts`
- [x] T069 [P] [US4] Add route refresh tests for permission changes during an active session in `src/lib/usuario.test.ts`

### Implementation for User Story 4

- [x] T070 [US4] Implement configuracoes read RPCs from `contracts/relatorios-configuracoes-rpc.md` with admin-only global data and own-settings responses in `supabase/migrations/*_demais_telas_rpc_relatorios_config_read.sql`
- [x] T071 [US4] Implement configuracoes write RPCs from `contracts/relatorios-configuracoes-rpc.md` with profile/status updates, sensitive setting audit, and permission refresh support in `supabase/migrations/*_demais_telas_rpc_config_write.sql`
- [x] T072 [P] [US4] Define company settings, user settings, notification preference, and permission update types in `src/types/configuracoes.ts`
- [x] T073 [US4] Implement `supabase.rpc()` only calls for configuracoes reads/writes in `src/services/configuracoes.service.ts`
- [x] T074 [P] [US4] Implement `/configuracoes` page layout, admin tabs, own-settings mode, profile updates, notification preferences, integration unavailable states, and appearance preferences from `reference/legacy-html/configuracoes.html` in `src/pages/ConfiguracoesPage.tsx`
- [x] T075 [P] [US4] Implement responsive/focus-safe styles for Configuracoes in `src/pages/ConfiguracoesPage.css`
- [x] T076 [US4] Update auth/profile refresh flow so permission changes re-evaluate sidebar and protected routes in `src/contexts/AuthContext.tsx`
- [x] T077 [US4] Wire Configuracoes into an explicit protected route and remove it from the placeholder route loop in `src/App.tsx`
- [x] T078 [US4] Validate US4 with C5 and C7 from `specs/005-demais-telas-perfis/quickstart.md`

**Checkpoint**: User Story 4 controls settings and active-session permission changes safely.

---

## Phase 7: User Story 5 - Relatorios e Visualizador funcionam em modo leitura (Priority: P3)

**Goal**: Administrador, Financeiro, Projetos, and Visualizador can consult permitted reports while read-only users cannot perform writes.

**Independent Test**: Login as Visualizador, access `/relatorios`, apply filters, confirm categories are permitted, and verify no write actions appear or execute.

### Tests for User Story 5

- [x] T079 [P] [US5] Add relatorios service RPC contract tests for category scope, preview filters, exports, and unavailable export generation in `src/services/relatorios.service.test.ts`

### Implementation for User Story 5

- [x] T080 [US5] Implement relatorios read/export-request RPCs from `contracts/relatorios-configuracoes-rpc.md` with category scoping and null `arquivo_url` when generation is unavailable in `supabase/migrations/*_demais_telas_rpc_relatorios_config_read.sql`
- [x] T081 [P] [US5] Define report category, preview, export, schedule, and filter types in `src/types/relatorios.ts`
- [x] T082 [US5] Implement `supabase.rpc()` only calls for relatorios reads and export/schedule requests in `src/services/relatorios.service.ts`
- [x] T083 [P] [US5] Implement `/relatorios` page layout, category filters, preview, export history, unavailable export state, and read-only Visualizador mode from `reference/legacy-html/relatorios.html` in `src/pages/RelatoriosPage.tsx`
- [x] T084 [P] [US5] Implement responsive/focus-safe styles for Relatorios in `src/pages/RelatoriosPage.css`
- [x] T085 [US5] Wire Relatorios into an explicit protected route and remove it from the placeholder route loop in `src/App.tsx`
- [x] T086 [US5] Validate US5 with C6 from `specs/005-demais-telas-perfis/quickstart.md`

**Checkpoint**: User Story 5 gives Visualizador a useful read-only reporting experience.

---

## Phase 8: User Story 6 - Navegacao nao exibe placeholders nem acessos indevidos (Priority: P3)

**Goal**: Authorized users never see `ModuloNaoMigrado` on scoped routes, and unauthorized direct access redirects before route data is displayed.

**Independent Test**: Login with every test profile, compare sidebar, direct URL access, and absence of the generic placeholder for all authorized routes in scope.

### Tests for User Story 6

- [x] T087 [P] [US6] Add navigation visibility tests for all technical profiles and feature routes in `src/lib/navegacao.test.ts`
- [x] T088 [P] [US6] Add route fallback and initial-route tests for authorized redirects and Visualizador behavior in `src/lib/usuario.test.ts`

### Implementation for User Story 6

- [x] T089 [US6] Audit explicit route declarations for all scoped pages and remove any residual `ITENS_NAV` placeholder route loop in `src/App.tsx`
- [x] T090 [US6] Ensure `ModuloNaoMigrado` is not rendered for `/fluxo-caixa`, `/contas-pagar`, `/contas-receber`, `/propostas`, `/contratos`, `/cobrancas`, `/equipe`, `/relatorios`, or `/configuracoes` in `src/App.tsx`
- [x] T091 [US6] Update initial route selection for Visualizador and any changed profile behavior in `src/lib/usuario.ts`
- [x] T092 [US6] Confirm sidebar permission filtering remains synchronized with actual readable modules in `src/lib/navegacao.ts`
- [x] T093 [US6] Validate US6 with C1 and C7 from `specs/005-demais-telas-perfis/quickstart.md`

**Checkpoint**: All scoped routes are real pages and direct unauthorized access is blocked before data load.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final quality, security, performance, documentation, and release readiness across all user stories.

- [x] T094 [P] Verify every page in scope has loading, empty, no-result, recoverable error, no-write, and integration-unavailable states in `src/pages/FluxoCaixaPage.tsx`, `src/pages/ContasPagarPage.tsx`, `src/pages/ContasReceberPage.tsx`, `src/pages/PropostasPage.tsx`, `src/pages/ContratosPage.tsx`, `src/pages/CobrancasPage.tsx`, `src/pages/EquipePage.tsx`, `src/pages/RelatoriosPage.tsx`, and `src/pages/ConfiguracoesPage.tsx`
- [x] T095 [P] Verify no domain data remains hardcoded as mock values in `src/pages/` and `src/services/`
- [x] T096 [P] Verify no frontend domain data access uses `supabase.from()` in `src/services/`
- [x] T097 [P] Verify RPC grants, RLS policies, and function `search_path` for all new SQL files in `supabase/migrations/`
- [x] T098 [P] Measure each route family against the 2s/3s performance goals with seeded data and record results in `specs/005-demais-telas-perfis/quickstart.md`
- [x] T099 [P] Verify desktop and mobile responsive behavior for all scoped page styles in `src/pages/*.css`
- [x] T100 [P] Verify accessible names, focus states, and non-color-only status communication in `src/pages/`
- [x] T101 Run `npm test` and fix failures before release
- [x] T102 Run `npm run build` and fix failures before release
- [x] T103 Run `npm run supabase:reset` and fix migration/seed failures before release
- [x] T104 Execute all scenarios C1-C12 from `specs/005-demais-telas-perfis/quickstart.md`
- [x] T105 Update feature memory with final implementation decisions in `.agents/project-memory/005-demais-telas-perfis.md`
- [x] T106 Update architectural/business-rule documentation for implemented changes in `.sauron/wiki/knowledge/architecture.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 Financeiro (P1)**: Can start after Foundational; MVP scope
- **US2 Comercial (P1)**: Can start after Foundational and after the US1 Cobrancas base route exists; it extends the shared page with commercial ownership without adding a duplicate route
- **US3 Equipe (P2)**: Can start after Foundational; no dependency on US1/US2
- **US4 Configuracoes (P2)**: Can start after Foundational; route refresh affects all stories, validate after each profile change
- **US5 Relatorios (P3)**: Can start after Foundational; consumes seeded data from prior domains for richer previews
- **US6 Navegacao (P3)**: Should finish after page components exist; each earlier wiring task removes its own module from the placeholder loop, and US6 audits that no residual placeholder remains

### Within Each User Story

- Tests before implementation tasks where test files are listed
- SQL/RPCs before frontend services
- Types before pages
- Services before page data integration
- Page route wiring before manual quickstart validation

---

## Parallel Opportunities

- T004-T006 can run in parallel because each reviews different legacy HTML files.
- T022-T026 can run in parallel because they create separate shared frontend files.
- US1 page files T035-T041 can run in parallel after T031-T034.
- US2 page files T051-T056 can run in parallel after T047-T050.
- US3, US4, and US5 can proceed in parallel after Phase 2 because they touch distinct SQL, service, type, and page files.
- Polish checks T094-T100 can run in parallel before final command gates T101-T103.

## Parallel Example: User Story 1

```text
Task: "Add financeiro service RPC contract tests for summaries, lists, metrics, create/update, and payment calls in src/services/financeiro.service.test.ts"
Task: "Define Fluxo de Caixa, Contas a Pagar, Contas a Receber, and shared financial types in src/types/financeiro.ts"
Task: "Implement /fluxo-caixa page layout and state handling from reference/legacy-html/fluxo-caixa.html in src/pages/FluxoCaixaPage.tsx"
Task: "Implement /contas-pagar page layout, filters, create/edit account, and register payment flows from reference/legacy-html/contas-pagar.html in src/pages/ContasPagarPage.tsx"
Task: "Implement /contas-receber page layout, filters, create invoice, cobranças entry point, and register receipt flows from reference/legacy-html/contas-receber.html in src/pages/ContasReceberPage.tsx"
Task: "Implement shared /cobrancas base page for the Financeiro view, payment/conciliation action gating, and recoverable states in src/pages/CobrancasPage.tsx and src/pages/CobrancasPage.css"
```

## Parallel Example: User Story 2

```text
Task: "Add comercial service RPC contract tests for propostas, contratos, cobrancas, integration-pending results, and duplicate rejection in src/services/comercial.service.test.ts"
Task: "Define proposta, contrato, cobranca, documento, and commercial integration types in src/types/comercial.ts"
Task: "Implement /propostas page layout, filters, detail, create/update, and send-pending flows from reference/legacy-html/propostas.html in src/pages/PropostasPage.tsx"
Task: "Implement /contratos page layout, filters, detail, create-from-proposal, renewal, closure, and document-pending states from reference/legacy-html/contratos.html in src/pages/ContratosPage.tsx"
Task: "Extend the existing /cobrancas page with commercial filters, detail, reminders, boleto-pending state, and commercial/financial ownership separation from reference/legacy-html/cobrancas.html in src/pages/CobrancasPage.tsx"
```

## Parallel Example: User Story 3

```text
Task: "Add equipe service RPC contract tests for manager versus tecnico scopes and cost omission in src/services/equipe.service.test.ts"
Task: "Define member, allocation, capacity, and time-entry types in src/types/equipe.ts"
Task: "Implement /equipe page layout, metrics, members table, allocation by project, capacity view, create/edit/allocation, and Tecnico restricted mode from reference/legacy-html/equipe.html in src/pages/EquipePage.tsx"
```

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: US1 Financeiro
4. Stop and validate C2/C11 from `quickstart.md`
5. Continue to US2 only after financial data, permissions, shared Cobrancas base route, and route behavior are stable

### Incremental Delivery

1. Setup + Foundational establish DB, RLS, seeds, shared states, and test helpers
2. Deliver US1 Financeiro as the first business-complete increment
3. Deliver US2 Comercial and shared Cobrancas ownership
4. Deliver US3 Equipe and US4 Configuracoes for operational control
5. Deliver US5 Relatorios and US6 navigation closure
6. Run Phase 9 gates before release

### Parallel Team Strategy

1. One developer owns shared SQL security and seeds during Phase 2
2. One developer owns shared frontend state/test helpers during Phase 2
3. After Phase 2, split by domain: Financeiro, Comercial, Equipe, Configuracoes, Relatorios
4. Reserve `src/App.tsx`, `src/lib/usuario.ts`, and final route tests for coordinated integration to avoid merge conflicts

## Notes

- All frontend domain reads/writes must use `supabase.rpc()`, never `supabase.from()`.
- All new public tables must have RLS enabled and explicit grants.
- RPCs must validate `auth.uid()`, profile permissions, fixed `search_path`, and restricted field omission.
- `reference/legacy-html/` is the primary visual/behavior source for all scoped pages.
- Integration-dependent actions must return pending/unavailable states, never fake success.
- `Vencido` is derived from date/status in queries and UI, not stored as the authoritative state.
- `alocacoes_projeto` remains the Tecnico authorization source; `alocacoes_equipe` is operational capacity/history.
- Each story wiring task must remove its scoped modules from the placeholder route loop; US6 is the final audit, not the first route replacement.
