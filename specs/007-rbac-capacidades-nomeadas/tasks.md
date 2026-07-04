# Tasks: RBAC por Capacidades Nomeadas

**Input**: Design documents from `/specs/007-rbac-capacidades-nomeadas/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `checklists/rbac.md`

**Tests**: Required by spec FR-045..FR-050 and contracts/audit-and-tests.md. Test tasks are listed before implementation tasks in each story where applicable.

**Organization**: Tasks are grouped by user story to preserve independent implementation and validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other marked tasks in the same phase after dependencies are met
- **[Story]**: User story label from `spec.md`
- Every task includes an exact repo path or generated migration path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare files and inventory needed before implementation.

- [ ] T001 Create migration file `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`; if using `supabase migration new rbac_capacidades_foundation`, rename the generated file to this target before editing
- [ ] T002 Create migration file `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`; if using `supabase migration new rbac_capacidades_rpc_guards`, rename the generated file to this target before editing
- [ ] T003 [P] Inventory current write/effect RPC definitions from `supabase/migrations/` against `specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md`
- [ ] T004 [P] Inventory frontend action gates in `src/pages/ClientesPage.tsx`, `src/pages/ProjetosPage.tsx`, `src/pages/EquipePage.tsx`, `src/pages/CobrancasPage.tsx`, `src/pages/PropostasPage.tsx`, `src/pages/ContratosPage.tsx`, `src/pages/RelatoriosPage.tsx`, `src/pages/ConfiguracoesPage.tsx`, `src/pages/FluxoCaixaPage.tsx`, `src/pages/ContasPagarPage.tsx`, and `src/pages/ContasReceberPage.tsx`
- [ ] T005 [P] Confirm existing npm gates in `package.json` cover `build`, `test`, `db:test`, and `audit`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared contracts that block all user stories.

**Critical**: No user story work should start until this phase is complete.

- [ ] T006 Define canonical capability catalog comments/constants inside `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T007 Define shared TypeScript capability type aliases in `src/types/auth.ts`
- [ ] T008 [P] Create `src/lib/capacidades.test.ts` with failing test skeletons for the frontend capability helper
- [ ] T009 [P] Create `src/services/equipe.service.test.ts` with failing test skeletons for apontamento payload normalization
- [ ] T010 [P] Create `supabase/tests/05_capacidades.sql` with failing pgTAP skeleton for the capability matrix suite

**Checkpoint**: Foundation ready - user story implementation can begin.

---

## Phase 3: User Story 1 - Autorizar acoes por capacidade nomeada (Priority: P1) - MVP

**Goal**: Create the named-capability authorization foundation shared by frontend and backend.

**Independent Test**: Each profile receives exactly the expected capabilities, and direct calls without a required capability are rejected even when module read is allowed.

### Tests for User Story 1

- [ ] T011 [P] [US1] Add pgTAP catalog and matrix assertions for all profiles in `supabase/tests/05_capacidades.sql`
- [ ] T012 [P] [US1] Add pgTAP tests for `tem_capacidade` anonymous, missing, and valid capability cases in `supabase/tests/05_capacidades.sql`
- [ ] T013 [P] [US1] Add pgTAP tests for `obter_capacidades_usuario()` ordering and per-profile output in `supabase/tests/05_capacidades.sql`
- [ ] T014 [P] [US1] Add Vitest coverage for `pode()` exact match, absent list, empty string, and no wildcard behavior in `src/lib/capacidades.test.ts`
- [ ] T015 [P] [US1] Add Auth service test for `obter_capacidades_usuario` RPC usage in `src/services/auth.service.test.ts`

### Implementation for User Story 1

- [ ] T016 [US1] Create `public.capacidades_perfil` with primary key, RLS enabled, revoke/grant policy, and seedable catalog in `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T017 [US1] Implement `public.tem_capacidade(p_capacidade text)` with auth guard, active profile lookup, no `user_metadata`, `SECURITY DEFINER`, `SET search_path = public`, revoke, and grant in `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T018 [US1] Implement `public.obter_capacidades_usuario()` returning ordered `text[]` with auth guard, `SECURITY DEFINER`, `SET search_path = public`, revoke, and grant in `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T019 [US1] Seed capability rows for Administrador, Financeiro, Projetos, Comercial, Tecnico, and Visualizador in `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T020 [US1] Adjust module-read seed rules for Dashboard, Visualizador minimal read, and Projetos no Dashboard in `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T021 [US1] Implement `pode(capacidades, capacidade)` in `src/lib/capacidades.ts`
- [ ] T022 [US1] Add `capacidades: string[]` to auth state/types in `src/types/auth.ts`
- [ ] T023 [US1] Add `getCapacidadesUsuario()` using only `supabase.rpc('obter_capacidades_usuario')` in `src/services/auth.service.ts`
- [ ] T024 [US1] Load and refresh capacidades with perfil/permissoes in `src/contexts/AuthContext.tsx`
- [ ] T025 [US1] Ensure unauthenticated or missing-profile auth state returns empty capabilities in `src/contexts/AuthContext.tsx`

**Checkpoint**: US1 works independently with backend capability matrix and frontend session capabilities.

---

## Phase 4: User Story 2 - Corrigir o trabalho diario do Tecnico (Priority: P1)

**Goal**: Let Tecnico edit/move own tasks, register own time, and see limited shared-project teammates without managerial privileges.

**Independent Test**: Tecnico cannot create/delete projects, cannot change others' tasks or time entries, can update own assigned task, can register own hours, and sees only self plus active shared-project teammates with limited data.

### Tests for User Story 2

- [ ] T026 [P] [US2] Add pgTAP test that Tecnico cannot create or delete projects in `supabase/tests/05_capacidades.sql`
- [ ] T027 [P] [US2] Add pgTAP test that Tecnico cannot move or edit a task whose `responsavel_id` is another `membros_equipe.id` in `supabase/tests/05_capacidades.sql`
- [ ] T028 [P] [US2] Add pgTAP test that Tecnico can move and edit a task whose `responsavel_id` is the authenticated user's linked `membros_equipe.id` in `supabase/tests/05_capacidades.sql`
- [ ] T029 [P] [US2] Add pgTAP test that Tecnico cannot forge apontamento for another member in `supabase/tests/05_capacidades.sql`
- [ ] T030 [P] [US2] Add pgTAP test that Tecnico can register own apontamento in `supabase/tests/05_capacidades.sql`
- [ ] T031 [P] [US2] Add pgTAP test for `listar_membros_equipe` limited teammate rows and hidden `perfil_id`/`custo_hora` in `supabase/tests/05_capacidades.sql`

### Implementation for User Story 2

- [ ] T032 [US2] Update `atualizar_tarefa` to accept `tarefas.editar_qualquer` or `tarefas.editar_propria` plus ownership by linked `membros_equipe.id` in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T033 [US2] Update `mover_tarefa` to accept `tarefas.mover_qualquer` or `tarefas.mover_propria` plus ownership by linked `membros_equipe.id` in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T034 [US2] Update project management RPCs `criar_projeto`, `atualizar_projeto`, and `excluir_projeto` to require project capabilities in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T035 [US2] Update `registrar_apontamento_horas` to require `apontamentos.registrar_proprio` plus ownership or `apontamentos.registrar_qualquer` in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T036 [US2] Update `listar_membros_equipe` limited-read branch for Tecnico shared active projects and hidden colleague fields in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T037 [US2] Gate create/edit/delete project buttons and task create/delete actions by capabilities in `src/pages/ProjetosPage.tsx`
- [ ] T038 [US2] Gate own-vs-any task move/edit affordances by capabilities and ownership state in `src/pages/ProjetosPage.tsx`
- [ ] T039 [US2] Gate own-vs-any apontamento actions by capabilities in `src/pages/EquipePage.tsx`
- [ ] T040 [US2] Render limited teammate data without cost/profile leakage in `src/pages/EquipePage.tsx`

**Checkpoint**: US2 can be validated through Tecnico persona and direct RPC calls.

---

## Phase 5: User Story 3 - Remover Visualizador como persona operacional (Priority: P1)

**Goal**: Keep Visualizador as technical minimum signup state while removing it from operational personas.

**Independent Test**: Visualizador exists with zero capabilities and minimal read, but no longer appears in operational seeds, admin operational selector, persona docs, or active-persona E2E.

### Tests for User Story 3

- [ ] T041 [P] [US3] Update RBAC profile tests to cover five operational personas in `supabase/tests/02_rbac_por_perfil.sql`
- [ ] T042 [P] [US3] Add Visualizador technical-minimum assertions for zero capabilities and minimal read in `supabase/tests/05_capacidades.sql`

### Implementation for User Story 3

- [ ] T043 [US3] Remove Visualizador from operational persona seed data while preserving signup default behavior in `supabase/seed.sql`
- [ ] T044 [US3] Remove Visualizador from operational profile choices in `src/pages/ConfiguracoesPage.tsx`
- [ ] T045 [US3] Ensure Visualizador read permissions are limited to relatorios and own configuracoes in `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
- [ ] T046 [US3] Update persona Playwright/E2E validation references to five operational personas in `specs/007-rbac-capacidades-nomeadas/quickstart.md`

**Checkpoint**: US3 can be validated without implementing broad frontend action gates.

---

## Phase 6: User Story 4 - Alinhar os controles do frontend as capacidades (Priority: P2)

**Goal**: Replace sensitive action button gates from broad module write permission to named capabilities.

**Independent Test**: With mocked capabilities, create/delete/apontar/baixar/boleto/notificar/inativar/reativar/exportar buttons appear only for the profiles that own the required capability.

### Tests for User Story 4

- [ ] T047 [P] [US4] Add or update page/helper tests that mock capacidades instead of `podeEscrever` in `src/lib/permissoes.test.ts`
- [ ] T048 [P] [US4] Add regression assertions for action gates using `pode()` in `src/lib/capacidades.test.ts`

### Implementation for User Story 4

- [ ] T049 [US4] Replace sensitive client action gates with `pode()` in `src/pages/ClientesPage.tsx`
- [ ] T050 [US4] Replace proposal action gates with `pode()` in `src/pages/PropostasPage.tsx`
- [ ] T051 [US4] Replace contract action gates with `pode()` in `src/pages/ContratosPage.tsx`
- [ ] T052 [US4] Replace cobranca action gates for emitir, boleto, notificar, and baixar with `pode()` in `src/pages/CobrancasPage.tsx`
- [ ] T053 [US4] Replace equipe management and apontamento action gates with `pode()` in `src/pages/EquipePage.tsx`
- [ ] T054 [US4] Replace relatorio export/agendamento gates with `pode()` in `src/pages/RelatoriosPage.tsx`
- [ ] T055 [US4] Replace configuracoes user/company/profile action gates with `pode()` in `src/pages/ConfiguracoesPage.tsx`
- [ ] T056 [US4] Replace financeiro action gates in `src/pages/FluxoCaixaPage.tsx`
- [ ] T057 [US4] Replace contas a pagar action gates in `src/pages/ContasPagarPage.tsx`
- [ ] T058 [US4] Replace contas a receber action gates in `src/pages/ContasReceberPage.tsx`
- [ ] T059 [US4] Keep route/menu read checks on `podeLer()` and remove only sensitive-action reliance on `podeEscrever()` in `src/lib/permissoes.ts`

**Checkpoint**: US4 can be validated with frontend tests and mocked capabilities.

---

## Phase 7: User Story 5 - Corrigir fluxos funcionais afetados pela validacao (Priority: P2)

**Goal**: Fix the E2E-confirmed workflow bugs around general time entries, detail closing, and client reactivation.

**Independent Test**: General time entry saves with `tarefa_id = null`; Propostas and Contratos detail panels close by visible control and Esc; inactive client can be reactivated by authorized user.

### Tests for User Story 5

- [ ] T060 [P] [US5] Add Vitest coverage that "sem tarefa" normalizes to `tarefa_id: null` in `src/services/equipe.service.test.ts`
- [ ] T061 [P] [US5] Add pgTAP test that `registrar_apontamento_horas` accepts `tarefa_id = null` in `supabase/tests/05_capacidades.sql`

### Implementation for User Story 5

- [ ] T062 [US5] Normalize "atividade geral" to `tarefa_id: null` before RPC call in `src/services/equipe.service.ts`
- [ ] T063 [US5] Ensure `registrar_apontamento_horas` accepts null task IDs and rejects textual sentinel `"geral"` in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T064 [US5] Add visible close control and Esc handling for proposal detail panel in `src/pages/PropostasPage.tsx`
- [ ] T065 [US5] Add visible close control and Esc handling for contract detail panel in `src/pages/ContratosPage.tsx`
- [ ] T066 [US5] Add `Reativar Contato` UI action gated by `clientes.reativar` in `src/pages/ClientesPage.tsx`
- [ ] T067 [US5] Update `atualizar_cliente` capability branch for inactive-to-active status reactivation in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`

**Checkpoint**: US5 can be validated through the four affected workflows.

---

## Phase 8: User Story 6 - Impedir regressao por testes e auditoria (Priority: P2)

**Goal**: Make capability authorization and RPC-first guardrails enforceable by automated checks.

**Independent Test**: A new write/effect RPC without `tem_capacidade` or a domain service using direct `supabase.from()` fails audit before integration.

### Tests for User Story 6

- [ ] T068 [P] [US6] Add audit fixture or assertion for write/effect RPC classification in `scripts/audit-rpc.mjs`
- [ ] T069 [P] [US6] Add pgTAP coverage for all remaining write/effect RPC guard mappings in `supabase/tests/05_capacidades.sql`

### Implementation for User Story 6

- [ ] T070 [US6] Update `scripts/audit-rpc.mjs` to classify read, write, effect, auth-helper, admin-only, and audit-auth functions
- [ ] T071 [US6] Update `scripts/audit-rpc.mjs` to accept `tem_capacidade` as the valid write/effect guard
- [ ] T072 [US6] Update `scripts/audit-rpc.mjs` to fail write/effect RPCs without named capability guards
- [ ] T073 [US6] Update `scripts/audit-rpc.mjs` helper allowlist for `tem_capacidade`, `obter_capacidades_usuario`, `permissao_modulo`, and `obter_permissoes_usuario`
- [ ] T074 [US6] Update Clientes RPCs `criar_cliente`, `atualizar_cliente`, `inativar_cliente`, and `registrar_atendimento` with named capability guards in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T075 [US6] Update Propostas and Contratos RPCs `criar_proposta`, `atualizar_proposta`, `registrar_envio_proposta`, `criar_contrato`, `renovar_contrato`, and `encerrar_contrato` with named capability guards in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T076 [US6] Update Cobrancas RPCs `criar_cobranca`, `solicitar_emissao_boleto`, `solicitar_lembrete_cobranca`, and `registrar_pagamento_cobranca` with named capability guards in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T077 [US6] Update Equipe management RPCs `criar_membro_equipe`, `atualizar_membro_equipe`, `alocar_membro_projeto`, and `inativar_membro_equipe` with named capability guards in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T078 [US6] Update Financeiro RPCs `criar_lancamento_financeiro`, `atualizar_lancamento_financeiro`, and `registrar_pagamento_lancamento` with named capability guards in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T079 [US6] Update Configuracoes and Relatorios RPCs `atualizar_configuracoes_empresa`, `atualizar_usuario_perfil`, `atualizar_minhas_configuracoes`, `atualizar_preferencias_notificacoes`, `solicitar_exportacao_relatorio`, and `agendar_relatorio` with named capability guards in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
- [ ] T080 [US6] Ensure all recreated RPCs in `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql` keep `SECURITY DEFINER`, `SET search_path = public`, identity guard, `REVOKE`, and `GRANT`
- [ ] T081 [US6] Update `supabase/tests/03_auditoria.sql` if needed to align database-side audit expectations with named capability guards

**Checkpoint**: US6 can be validated by `npm run audit` and `npm run db:test`.

---

## Phase 9: User Story 7 - Documentar a nova regra de autorizacao (Priority: P3)

**Goal**: Make the new capability model discoverable for future development.

**Independent Test**: Documentation states five operational personas, Visualizador as technical minimum, and the central rule that frontend uses capabilities for UX while RPCs use the same capabilities for real authorization.

### Implementation for User Story 7

- [ ] T082 [P] [US7] Update five operational personas and Visualizador technical-minimum language in `docs/personas.md`
- [ ] T083 [P] [US7] Document capability table, helpers, RPC authorization rule, and frontend/backend consumption rule in `docs/arquitetura-dados.md`
- [ ] T084 [US7] Document Dashboard official access for Administrador and Financeiro in `docs/personas.md`
- [ ] T085 [US7] Update feature memory with implementation task decisions in `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
- [ ] T086 [US7] Update architecture wiki change history for task generation and RBAC implementation scope in `.sauron/wiki/knowledge/architecture.md`

**Checkpoint**: US7 can be validated by reading docs without inspecting implementation internals.

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: Validate the full feature and remove drift between artifacts and implementation.

- [ ] T087 [P] Run TypeScript build gate and record result from `npm run build`
- [ ] T088 [P] Run frontend unit test gate and record result from `npm run test`
- [ ] T089 [P] Run database test gate and record result from `npm run db:test`
- [ ] T090 [P] Run static audit gate and record result from `npm run audit`
- [ ] T091 Validate capability counts manually with SQL from `specs/007-rbac-capacidades-nomeadas/quickstart.md`
- [ ] T092 Run or update Playwright validation for the five operational personas using `specs/007-rbac-capacidades-nomeadas/quickstart.md`
- [ ] T093 Validate Visualizador technical-minimum signup state using `specs/007-rbac-capacidades-nomeadas/quickstart.md`
- [ ] T094 Check no sensitive action button still depends only on `podeEscrever()` in `src/pages/`
- [ ] T095 Check no domain service introduced direct table access outside approved health-check exceptions using `scripts/check-no-from.mjs`
- [ ] T096 Update `specs/007-rbac-capacidades-nomeadas/quickstart.md` with any command/path correction discovered during validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup.
- **US1 (Phase 3)**: Depends on Foundational and is the MVP foundation.
- **US2 (Phase 4)**: Depends on US1 because Tecnico ownership uses `tem_capacidade`.
- **US3 (Phase 5)**: Depends on US1 because Visualizador zero capabilities must exist.
- **US4 (Phase 6)**: Depends on US1 because frontend requires loaded capabilities and `pode()`.
- **US5 (Phase 7)**: Can start after US1; client reactivation depends on capability branch from US1.
- **US6 (Phase 8)**: Depends on US1 and should finish after all RPC guard migrations are in place.
- **US7 (Phase 9)**: Can run after US1 decisions are stable; final docs should be checked after US2-US6.
- **Polish**: Depends on all desired user stories.

### User Story Dependencies

- **US1 (P1)**: Independent MVP foundation after Foundational.
- **US2 (P1)**: Requires US1 helpers/matrix.
- **US3 (P1)**: Requires US1 matrix and read-permission foundation.
- **US4 (P2)**: Requires US1 frontend capabilities.
- **US5 (P2)**: Requires US1 for capability-gated reactivation and apontamento guards.
- **US6 (P2)**: Requires US1 and benefits from all RPC updates being present.
- **US7 (P3)**: Documentation can be drafted in parallel, final pass after implementation.

### Within Each User Story

- Write or update tests first.
- Implement database guards before frontend controls that depend on them.
- Keep `podeLer()` for route/menu/read access.
- Use `pode()` for sensitive action visibility.
- Validate the story independently before moving to lower-priority phases.

---

## Parallel Opportunities

- T003, T004, and T005 can run in parallel after migration shells exist.
- T008, T009, and T010 can run in parallel during Foundational.
- US1 test tasks T011-T015 can run in parallel.
- US2 test tasks T026-T031 can run in parallel.
- US4 page gate tasks T049-T058 can be split by page after T021-T024.
- US7 documentation tasks T082 and T083 can run in parallel.
- Final gates T087-T090 can run independently once implementation is complete.

---

## Parallel Example: User Story 1

```text
Task: "T011 Add pgTAP catalog and matrix assertions in supabase/tests/05_capacidades.sql"
Task: "T014 Add Vitest coverage for pode() in src/lib/capacidades.test.ts"
Task: "T015 Add Auth service test for obter_capacidades_usuario in src/services/auth.service.test.ts"
```

## Parallel Example: User Story 4

```text
Task: "T049 Replace sensitive client action gates in src/pages/ClientesPage.tsx"
Task: "T052 Replace cobranca action gates in src/pages/CobrancasPage.tsx"
Task: "T054 Replace relatorio export/agendamento gates in src/pages/RelatoriosPage.tsx"
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete US1.
3. Validate `npm run db:test`, `npm run test`, and a direct capability query.
4. Complete US2 and US3 before broad P2 UI work, because they close the highest-risk persona bugs.

### Incremental Delivery

1. US1 establishes the shared authorization source.
2. US2 proves ownership and Tecnico behavior.
3. US3 removes Visualizador ambiguity.
4. US4 aligns UX gates.
5. US5 fixes confirmed functional bugs.
6. US6 locks the rule with audit/tests.
7. US7 documents the governance rule.

### Quality Gates

Run before considering the feature complete:

```powershell
npm run build
npm run test
npm run db:test
npm run audit
```

Then execute the five-persona validation described in `specs/007-rbac-capacidades-nomeadas/quickstart.md`.
