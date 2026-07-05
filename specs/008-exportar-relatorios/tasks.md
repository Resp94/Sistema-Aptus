# Tasks: Exportar Relatorios

**Input**: Design documents from `/specs/008-exportar-relatorios/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [quickstart.md](./quickstart.md), [contracts/](./contracts/)

**Tests**: Required. The feature specification and audit contract define pgTAP, Vitest, Edge Function validation and final gates.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently after the shared foundation.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare dependencies, local Supabase command discovery and file structure.

- [X] T001 Verify Supabase CLI commands with `supabase --version`, `supabase --help`, `supabase functions --help`, and document any required local upgrade note in `specs/008-exportar-relatorios/quickstart.md`
- [X] T002 Add pinned runtime dependencies `pdf-lib` and `fflate` to `package.json` and update `package-lock.json`
- [X] T003 [P] Create Edge Function folder scaffold in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T004 [P] Create Edge Function shared CORS/error helper file in `supabase/functions/relatorios-exportacao/_shared.ts`
- [X] T005 [P] Create renderer helper file in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T006 [P] Create export payload helper file in `supabase/functions/relatorios-exportacao/payload.ts`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Database, Storage, RPC contracts, types and shared helpers that block all user stories.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T007 Generate migration with `supabase migration new exportar_relatorios` and implement the resulting `supabase/migrations/*_exportar_relatorios.sql` for `exportacoes_relatorios` fields, indexes and backward-compatible `arquivo_url`
- [X] T008 Add private Storage bucket `relatorios-exportados` and non-public Storage policies to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T009 Add export category helper/RPC `categoria_relatorio_exportavel(p_tipo text, p_perfil text)` to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T010 Add period validation helper for inclusive 12-month rule to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T011 Add complete report payload builders for Financeiro, DRE, Clientes and Projetos to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T012 Add RPC `iniciar_exportacao_relatorio` to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T013 Add RPCs `concluir_exportacao_relatorio` and `falhar_exportacao_relatorio` to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T014 Add RPC `autorizar_download_exportacao_relatorio` to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T015 Update RPC `listar_exportacoes_relatorios` response fields, history scoping and `status_exibicao` computation in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T016 Preserve legacy RPC `solicitar_exportacao_relatorio` as compatibility-only and document no new frontend usage in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T017 Add audit/event logging support for generation/download lifecycle to the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T018 [P] Extend `StatusExportacao` with `Expirado` in `src/types/common.ts`
- [X] T019 [P] Extend report export types and Edge Function response/input types in `src/types/relatorios.ts`
- [X] T020 [P] Add date-range helper functions for default month and inclusive 12-month validation in `src/lib/relatorios-periodo.ts`
- [X] T021 [P] Add download helper for signed URLs and filenames in `src/lib/download.ts`
- [X] T022 [P] Add Vitest coverage for date-range helpers in `src/lib/relatorios-periodo.test.ts`
- [X] T023 [P] Add pgTAP seed/helper utilities for report-export personas, rows and Storage policy assertions that prove `relatorios-exportados` is private and broad public/authenticated object reads are denied in `supabase/tests/008_exportar_relatorios.sql`

**Checkpoint**: Database contracts, Storage, shared types and helpers are ready.

---

## Phase 3: User Story 1 - Exportar relatorio completo imediatamente (Priority: P1) MVP

**Goal**: Authorized users can select one exportable category, choose dates and PDF/CSV, generate the full report immediately and download the generated file.

**Independent Test**: Login as Administrador, Financeiro and Projetos, export allowed categories in PDF and CSV within a valid period, and receive a downloadable file with summary and details.

### Tests for User Story 1

> Write these tests first and confirm they fail before implementation.

- [X] T024 [P] [US1] Add pgTAP tests for `iniciar_exportacao_relatorio` auth, capability, category matrix and `Personalizado` blocking in `supabase/tests/008_exportar_relatorios.sql`
- [X] T025 [P] [US1] Add pgTAP tests for invalid date order, same-day period, `2026-01-01` to `2026-12-31`, `2026-01-01` to `2027-01-01`, and over-12-month blocking in `supabase/tests/008_exportar_relatorios.sql`
- [X] T026 [P] [US1] Add pgTAP tests for complete payload shape by Financeiro, DRE, Clientes and Projetos in `supabase/tests/008_exportar_relatorios.sql`
- [X] T027 [P] [US1] Add Vitest service tests for `exportarRelatorio` invoking `relatorios-exportacao` action `gerar`, asserting `download_expires_in = 600` and no public permanent URL usage in `src/services/relatorios.service.test.ts`
- [X] T028 [P] [US1] Add Vitest UI tests for export modal defaults, validation, PDF/CSV selection, `Personalizado` blocking, initial focus, explicit labels, keyboard navigation, Escape close and 320px-safe layout behavior in `src/pages/RelatoriosPage.test.tsx`
- [X] T029 [P] [US1] Add Edge Function renderer/flow tests for CSV escaping, ZIP contents, PDF no-data rendering, oversized export failure and generation observability fields in `supabase/functions/relatorios-exportacao/renderers.test.ts` and `supabase/functions/relatorios-exportacao/index.test.ts`

### Implementation for User Story 1

- [X] T030 [US1] Implement `iniciar_exportacao_relatorio` validation, pending row insert and payload return in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T031 [US1] Implement complete Financeiro and DRE payload queries with period-filtered `lancamentos` in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T032 [US1] Implement complete Clientes and Projetos payload queries with current snapshot plus period metrics in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T033 [US1] Implement `concluir_exportacao_relatorio` and `falhar_exportacao_relatorio` status transitions in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T034 [US1] Implement CSV serializer, ZIP packaging and `EXPORT_TOO_LARGE` checks in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T035 [US1] Implement PDF renderer with `pdf-lib`, summary-first layout, details and no-data message in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T036 [US1] Implement Edge Function `gerar` flow with user JWT RPC call, private Storage upload, DB conclusion, signed URL, `download_expires_in = 600`, no public permanent URL response and failure handling in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T037 [US1] Add observability logs/events for generation started, completed and failed with `exportacao_id`, user, category, format, period, status, duration, file size when available and sanitized error when applicable in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T038 [US1] Add `exportarRelatorio` service method and keep legacy `solicitarExportacaoRelatorio` out of the new manual export path in `src/services/relatorios.service.ts`
- [X] T039 [US1] Update `RelatoriosPage.tsx` export modal with date inputs, defaults, validation, PDF/CSV controls and "Gerar e baixar" action in `src/pages/RelatoriosPage.tsx`
- [X] T040 [US1] Update export modal styling for 320px responsiveness, focus states and keyboard-friendly controls in `src/pages/RelatoriosPage.css`
- [X] T041 [US1] Remove manual-export integration-pending banner path from `src/pages/RelatoriosPage.tsx`
- [X] T042 [US1] Wire signed URL download behavior and history refresh after generation in `src/pages/RelatoriosPage.tsx`
- [X] T043 [US1] Validate US1 with `npm run db:test`, `npm run test`, `npm run build`, and local `supabase functions serve relatorios-exportacao` using `specs/008-exportar-relatorios/quickstart.md`

**Checkpoint**: User Story 1 is independently functional as MVP.

---

## Phase 4: User Story 2 - Baixar exportacoes anteriores (Priority: P2)

**Goal**: Authorized users can view export history and re-download valid previous files while expired, failed, pending and legacy records remain visible without download.

**Independent Test**: Generate an export, reload history, download it again through the history action, then verify expired/failed records are not downloadable and persona history scope is enforced.

### Tests for User Story 2

- [X] T044 [P] [US2] Add pgTAP tests for Admin seeing/downloading all exports and Financeiro/Projetos seeing/downloading only own exports in `supabase/tests/008_exportar_relatorios.sql`
- [X] T045 [P] [US2] Add pgTAP tests for expired, pending, failed and legacy `Indisponível` download denial in `supabase/tests/008_exportar_relatorios.sql`
- [X] T046 [P] [US2] Add pgTAP tests for newest-first history ordering and `pode_baixar`/`status_exibicao` computation in `supabase/tests/008_exportar_relatorios.sql`
- [X] T047 [P] [US2] Add Vitest service tests for `baixarExportacaoRelatorio` invoking `relatorios-exportacao` action `download`, asserting `download_expires_in = 600`, no public permanent URL usage and backend denial surfacing in `src/services/relatorios.service.test.ts`
- [X] T048 [P] [US2] Add Vitest UI tests for history period, requester, expiration, status text, non-color-only status communication, keyboard-accessible download actions and disabled download button states in `src/pages/RelatoriosPage.test.tsx`

### Implementation for User Story 2

- [X] T049 [US2] Implement `autorizar_download_exportacao_relatorio` with current capability, category scope, ownership and expiration checks in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T050 [US2] Implement expanded `listar_exportacoes_relatorios` with requester fields, period fields, `pode_baixar`, `status_exibicao` and newest-first ordering in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T051 [US2] Implement Edge Function `download` flow with RPC authorization, short-lived signed URL creation, `download_expires_in = 600` response and no public permanent URL exposure in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T052 [US2] Add observability logs/events for authorized download and denied download with `exportacao_id`, user, category, format, period, status, duration and sanitized error when applicable in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T053 [US2] Add `baixarExportacaoRelatorio` service method in `src/services/relatorios.service.ts`
- [X] T054 [US2] Update `ExportacaoRelatorioItem` history fields in `src/types/relatorios.ts`
- [X] T055 [US2] Update history table columns, requester visibility, period, expiration and status labels in `src/pages/RelatoriosPage.tsx`
- [X] T056 [US2] Update history responsive styling and non-color-only status badges in `src/pages/RelatoriosPage.css`
- [X] T057 [US2] Wire history download action through Edge Function and signed URL helper in `src/pages/RelatoriosPage.tsx`
- [X] T058 [US2] Validate US2 with `npm run db:test`, `npm run test`, and local history re-download scenario from `specs/008-exportar-relatorios/quickstart.md`

**Checkpoint**: User Story 2 is independently functional with US1-generated or seeded exports.

---

## Phase 5: User Story 3 - Respeitar personas e leitura sem exportacao (Priority: P3)

**Goal**: Relatorios remains readable where allowed, but export and download are blocked for Visualizador, Comercial, Tecnico and any user without `relatorios.exportar`.

**Independent Test**: Validate each persona can only see export controls, generate files, and download history according to the capability/category matrix.

### Tests for User Story 3

- [X] T059 [P] [US3] Add pgTAP tests for Visualizador, Comercial and Tecnico denied generation and download in `supabase/tests/008_exportar_relatorios.sql`
- [X] T060 [P] [US3] Add pgTAP tests for Financeiro denied Projetos/Clientes and Projetos denied Financeiro/DRE/Clientes in `supabase/tests/008_exportar_relatorios.sql`
- [X] T061 [P] [US3] Add Vitest tests for hidden/disabled export controls without `relatorios.exportar` in `src/pages/RelatoriosPage.test.tsx`
- [X] T062 [P] [US3] Add Vitest tests for backend denial surfacing when UI gating is bypassed in `src/services/relatorios.service.test.ts`

### Implementation for User Story 3

- [X] T063 [US3] Enforce exportable category helper in `iniciar_exportacao_relatorio` and `autorizar_download_exportacao_relatorio` in the generated `supabase/migrations/*_exportar_relatorios.sql`
- [X] T064 [US3] Ensure frontend capability gate uses `relatorios.exportar` and suppresses export actions for `Personalizado` in `src/pages/RelatoriosPage.tsx`
- [X] T065 [US3] Add user-facing permission/category denial messages for Edge Function errors in `src/services/relatorios.service.ts`
- [X] T066 [US3] Validate persona matrix manually through quickstart scenarios and document any seed prerequisites in `specs/008-exportar-relatorios/quickstart.md`
- [X] T067 [US3] Validate US3 with `npm run db:test` and `npm run test` using `specs/008-exportar-relatorios/quickstart.md`

**Checkpoint**: All user stories are independently functional and persona gates are enforced by backend and UI.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final quality gates, documentation, audits and cleanup across all stories.

- [X] T068 [P] Add or update project documentation for report export rules in `docs/arquitetura-dados.md`
- [X] T069 [P] Add or update persona documentation for report export permissions in `docs/personas.md`
- [X] T070 [P] Update feature memory with implementation notes in `.agents/project-memory/008-exportar-relatorios.md`
- [X] T071 [P] Update architecture change history with implementation notes in `.sauron/wiki/knowledge/architecture.md`
- [X] T072 Run RPC audit and update allowlist/classification if required in `scripts/audit-rpc.mjs`
- [X] T073 Run no-direct-table-access audit and adjust frontend services if required by `scripts/check-no-from.mjs`
- [X] T074 Run metadata audit and ensure no authorization uses user-editable metadata in `scripts/check-no-user-metadata.mjs`
- [X] T075 Run full database tests with `npm run db:test` per `package.json`, including the Storage bucket/private policy assertions from `supabase/tests/008_exportar_relatorios.sql`
- [X] T076 Run full frontend tests with `npm run test` per `package.json`
- [X] T077 Run production build with `npm run build` per `package.json`
- [X] T078 Run full audit suite with `npm run audit` per `package.json`
- [X] T079 Execute quickstart validation scenarios and record results in `specs/008-exportar-relatorios/quickstart.md`
- [X] T080 Inspect git diff for unintended changes and ensure generated files under `supabase/migrations/` and `supabase/functions/relatorios-exportacao/` are included in `git status`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories.
- **US1 (Phase 3)**: Depends on Foundational; MVP.
- **US2 (Phase 4)**: Depends on Foundational and can use seeded data, but is most useful after US1 generation exists.
- **US3 (Phase 5)**: Depends on Foundational; can be developed in parallel with US1/US2 after shared RPC helpers exist.
- **Polish (Phase 6)**: Depends on all desired user stories.

### User Story Dependencies

- **US1 Exportar relatorio completo imediatamente**: MVP; no dependency on US2/US3 after foundation.
- **US2 Baixar exportacoes anteriores**: Can be tested with seeded `exportacoes_relatorios`, but final manual validation uses US1-generated files.
- **US3 Respeitar personas e leitura sem exportacao**: Depends on shared capability/category helpers; validates gates around US1/US2.

### Within Each User Story

- Tests before implementation.
- Database/RPC contracts before Edge Function calls that depend on them.
- Edge Function before frontend service integration.
- Services/types before page wiring.
- Story validation before proceeding to next priority when working sequentially.

---

## Parallel Execution Examples

### User Story 1

```text
T024, T025, T026, T027, T028, T029 can be authored in parallel.
T031 and T032 can be implemented in parallel after T030.
T034 and T035 can be implemented in parallel before T036.
```

### User Story 2

```text
T044, T045, T046, T047, T048 can be authored in parallel.
T049 and T050 can be implemented in parallel after foundational schema changes.
T053, T054 and T056 can be implemented in parallel before T055/T057 integration.
```

### User Story 3

```text
T059, T060, T061 and T062 can be authored in parallel.
T064 and T065 can be implemented in parallel after T063.
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1 setup.
2. Complete Phase 2 foundation.
3. Complete Phase 3 US1.
4. Validate immediate PDF and CSV generation/download for allowed personas.
5. Stop for review before expanding history/persona hardening if needed.

### Incremental Delivery

1. US1 delivers immediate real export.
2. US2 adds durable history and re-download.
3. US3 hardens persona/category separation and bypass protections.
4. Polish runs audits, build and documentation.

### Parallel Team Strategy

After Phase 2:

- Developer A: US1 Edge Function/renderers and frontend modal.
- Developer B: US2 history/download RPCs and UI.
- Developer C: US3 persona matrix tests and authorization hardening.

---

## Notes

- All tasks use exact feature paths except the Supabase migration, which must be generated by `supabase migration new exportar_relatorios` per project/Supabase rules.
- `[P]` tasks touch distinct files or can be authored independently.
- Every user story has database and frontend tests before implementation.
- No new manual export flow may use `solicitar_exportacao_relatorio`.
- No generated report file may depend on `arquivo_url` or public Storage URLs.
