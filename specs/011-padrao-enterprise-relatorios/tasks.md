# Tasks: Padrao Enterprise Relatorios

**Input**: Design documents from `/specs/011-padrao-enterprise-relatorios/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [quickstart.md](./quickstart.md), [contracts/](./contracts/)

**Tests**: Required. The feature spec, plan, quickstart and export quality checklist require Vitest coverage, Edge Function validation and final browser/manual verification.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently on top of the feature 008 baseline.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare files, assets and validation scaffolding used across all stories.

- [X] T001 Register the 011 validation prerequisites and expected browser checks in `specs/011-padrao-enterprise-relatorios/quickstart.md`
- [X] T002 [P] Create test scaffolds in `src/lib/download.test.ts`, `src/services/relatorios.service.test.ts`, `src/pages/RelatoriosPage.test.tsx`, `supabase/functions/relatorios-exportacao/renderers.test.ts`, and `supabase/functions/relatorios-exportacao/index.test.ts`
- [X] T003 [P] Add font asset placeholders for executive PDF rendering in `supabase/functions/relatorios-exportacao/assets/NotoSans-Regular.ttf` and `supabase/functions/relatorios-exportacao/assets/NotoSans-Bold.ttf`
- [X] T004 [P] Keep the feature checklist (`specs/011-padrao-enterprise-relatorios/checklists/export-quality.md`) in sync during US1–US3 implementation: re-validate each CHK item apos a implementacao da user story correspondente e atualizar o status se necessario (todos os 26 itens estao atualmente em `[x]` apos a fase de design).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared helpers, metadata contracts and renderer primitives that block all user stories.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T005 Extend executive/operational export metadata types in `src/types/relatorios.ts`
- [X] T006 [P] Add attachment-oriented blob/object URL download helpers with cleanup support in `src/lib/download.ts`
- [X] T007 [P] Add shared PT-BR value formatters and category label maps from `specs/011-padrao-enterprise-relatorios/contracts/rotulos-negocio.md` in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T008 [P] Add reusable font loading and fallback helpers for Noto Sans in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T009 Normalize executive vs operational file metadata in `supabase/functions/relatorios-exportacao/payload.ts`
- [X] T010 [P] Add shared expired-tooltip and Experimental/Beta copy constants in `src/pages/RelatoriosPage.tsx`

**Checkpoint**: Shared download, metadata, label mapping and font primitives are ready.

---

## Phase 3: User Story 1 - Baixar relatorio executivo sem preview (Priority: P1) 🎯 MVP

**Goal**: PDF exports and PDF history downloads behave as direct downloads without preview or route replacement.

**Independent Test**: Generate a PDF in `/relatorios` and download a ready PDF from history; both actions must start a download without opening preview and the page must remain usable.

### Tests for User Story 1

- [X] T011 [P] [US1] Add attachment download helper tests for blob saving and object URL cleanup in `src/lib/download.test.ts`
- [X] T012 [P] [US1] Add service tests for immediate export and history PDF download preserving attachment semantics in `src/services/relatorios.service.test.ts`
- [X] T013 [P] [US1] Add page tests for immediate PDF export and history PDF download without route replacement in `src/pages/RelatoriosPage.test.tsx`
- [X] T014 [P] [US1] Add Edge Function flow tests for signed URL handoff and executive download metadata in `supabase/functions/relatorios-exportacao/index.test.ts`

### Implementation for User Story 1

- [X] T015 [US1] Implement attachment-only signed URL fetching and local file saving in `src/lib/download.ts`
- [X] T016 [US1] Wire `exportarRelatorio` and `baixarExportacaoRelatorio` to the attachment download flow in `src/services/relatorios.service.ts`
- [X] T017 [US1] Update immediate PDF export and history PDF download actions to preserve page state in `src/pages/RelatoriosPage.tsx`
- [X] T018 [US1] Update non-blocking loading, toast and disabled-button states for PDF downloads in `src/pages/RelatoriosPage.css`
- [X] T018.1 [US1] Verify and implement the permission-denied button state: botao "Exportar Relatorio" desabilitado com tooltip "Voce nao tem permissao para exportar" para usuarios sem a capacidade `relatorios.exportar` (conforme spec Edge Cases) em `src/pages/RelatoriosPage.tsx`
- [X] T019 [US1] Adjust Edge Function response handling and font helper reuse for attachment-oriented PDF delivery in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T020 [US1] Record the US1 manual validation steps and outcomes in `specs/011-padrao-enterprise-relatorios/quickstart.md`

**Checkpoint**: User Story 1 is independently functional and validates the no-preview MVP.

---

## Phase 4: User Story 2 - Receber documento apresentavel para negocio (Priority: P2)

**Goal**: The generated PDF becomes a business-ready executive document with PT-BR copy, category-aware sections and no leakage of internal keys.

**Independent Test**: Generate one PDF for each supported category and confirm correct section order, PT-BR labels, executive hierarchy and absence of `label:`/`valor:` leakage.

### Tests for User Story 2

- [X] T021 [P] [US2] Add renderer tests for PT-BR headings, executive section order and no `label`/`valor` leakage in `supabase/functions/relatorios-exportacao/renderers.test.ts`
- [X] T022 [P] [US2] Add renderer tests for font loading fallback and category-specific summary/detail formatting in `supabase/functions/relatorios-exportacao/renderers.test.ts`
- [X] T023 [P] [US2] Add Edge Function tests for Noto Sans loading and warning fallback behavior in `supabase/functions/relatorios-exportacao/index.test.ts`

### Implementation for User Story 2

- [X] T024 [US2] Implement Noto Sans embed loading and warning fallback flow in `supabase/functions/relatorios-exportacao/index.ts`
- [X] T025 [US2] Implement shared business label maps and PT-BR value formatting in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T026 [US2] Replace generic PDF rendering with executive templates for `Financeiro` and `DRE` in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T027 [US2] Replace generic PDF rendering with executive templates for `Clientes` and `Projetos` in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T028 [US2] Apply the approved typography, spacing and section-order rules across all PDF templates in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T029 [US2] Substituir a mensagem legada de empty state "Nenhum dado encontrado para o periodo selecionado." pela nova mensagem aprovada "Nao ha dados disponiveis para o periodo selecionado. Selecione um intervalo diferente ou entre em contato com o administrador." em `supabase/functions/relatorios-exportacao/renderers.ts`. Implementar fallback de secao de detalhes que preserva as secoes 1-4 do documento executivo (identificacao, metadados, resumo) e exibe a mensagem na secao de detalhes.
- [X] T030 [US2] Normalize payload metadata consumed by executive templates in `supabase/functions/relatorios-exportacao/payload.ts`
- [X] T031 [US2] Record the executive PDF validation outcomes against the checklist in `specs/011-padrao-enterprise-relatorios/quickstart.md`

**Checkpoint**: User Story 2 is independently functional and the PDF is business-ready.

---

## Phase 5: User Story 3 - Entender claramente o papel de cada formato (Priority: P3)

**Goal**: The product clearly distinguishes executive PDF from operational CSV/ZIP in the export UI, file naming and history behavior.

**Independent Test**: Review the export modal, download one PDF and one CSV/ZIP, then inspect history items for badges, naming, expired behavior and Experimental/Beta placement.

### Tests for User Story 3

- [X] T032 [P] [US3] Add renderer tests for CSV BOM, `Observacao` empty-state header, translated headers and operational filenames in `supabase/functions/relatorios-exportacao/renderers.test.ts`
- [X] T033 [P] [US3] Add service tests for executive vs operational metadata and file naming in `src/services/relatorios.service.test.ts`
- [X] T034 [P] [US3] Add page tests for format labels, Experimental/Beta marker, expired tooltip and history badges in `src/pages/RelatoriosPage.test.tsx`

### Implementation for User Story 3

- [X] T035 [US3] Implement CSV BOM UTF-8, translated headers and `Observacao` empty-state output in `supabase/functions/relatorios-exportacao/renderers.ts`
- [X] T036 [US3] Return differentiated `arquivo_nome`, `mime_type` and format metadata for PDF vs CSV/ZIP in `supabase/functions/relatorios-exportacao/payload.ts` and `supabase/functions/relatorios-exportacao/index.ts`
- [X] T037 [US3] Extend history/export metadata models for executive and operational labels in `src/types/relatorios.ts`
- [X] T038 [US3] Update the export modal and page labels so PDF is presented as the executive document and CSV/ZIP as operational export in `src/pages/RelatoriosPage.tsx`
- [X] T039 [US3] Style format badges, Experimental/Beta marker and expired disabled states in `src/pages/RelatoriosPage.css`
- [X] T040 [US3] Align export and history copy with the approved product terminology in `src/services/relatorios.service.ts` and `src/pages/RelatoriosPage.tsx`
- [X] T041 [US3] Record CSV/history/manual differentiation results in `specs/011-padrao-enterprise-relatorios/quickstart.md`. Este cenario manual de diferenciacao (PDF="Documento Executivo" com badge azul vs CSV="Exportacao Operacional (.zip)" com badge cinza, prefixos `relatorio-` vs `exportacao-` nos nomes de arquivo) serve como validacao qualitativa do SC-003.

**Checkpoint**: User Story 3 is independently functional and the product terminology is unambiguous.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation, audits and validation across all user stories.

- [X] T042 [P] Update the final validation guide and command list in `specs/011-padrao-enterprise-relatorios/quickstart.md`
- [X] T043 [P] Document feature 011 implementation notes in `.agents/project-memory/011-padrao-enterprise-relatorios.md`
- [X] T044 [P] Document feature 011 module impact in `.sauron/wiki/modules/feature-011-padrao-enterprise-relatorios.md`
- [X] T045 [P] Update cross-feature export memory notes in `.agents/project-memory/008-exportar-relatorios.md` and `.sauron/wiki/modules/feature-008-exportar-relatorios.md`
- [ ] T046 Run feature-focused frontend and Edge Function tests with `npm run test` — frontend focado passou (23/23) e a Edge Function foi validada em produção via Supabase MCP/Chrome; `deno test` local não foi executado porque o binário Deno não está acessível no shell desta sessão.
- [X] T047 Run production build validation with `npm run build`
- [X] T048 [P] Execute the browser/manual scenarios from `specs/011-padrao-enterprise-relatorios/quickstart.md` and record outcomes in `specs/011-padrao-enterprise-relatorios/quickstart.md`
- [X] T049 Inspect `git diff` and `git status` to confirm only intended 011-related files changed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories.
- **US1 (Phase 3)**: Depends on Foundational and delivers the MVP.
- **US2 (Phase 4)**: Depends on Foundational and benefits from US1 being in place for end-to-end PDF validation.
- **US3 (Phase 5)**: Depends on Foundational and can proceed after US1/US2 shared helpers are available.
- **Polish (Phase 6)**: Depends on all desired user stories.

### User Story Dependencies

- **US1**: No dependency on other stories after foundation.
- **US2**: Uses the no-preview flow from US1 for complete end-to-end validation, but renderer work is otherwise independent.
- **US3**: Depends on the metadata and renderer outputs stabilized by US1 and US2.

### Within Each User Story

- Tests before implementation.
- Shared helpers before page wiring.
- Renderer changes before final manual PDF/CSV validation.
- Story-specific validation before moving to the next priority when working sequentially.

---

## Parallel Execution Examples

### User Story 1

```text
T011, T012, T013 and T014 can be authored in parallel.
T016 and T019 can proceed in parallel after T015 is defined.
```

### User Story 2

```text
T021, T022 and T023 can be authored in parallel.
T026 and T027 can be implemented in parallel after T025.
```

### User Story 3

```text
T032, T033 and T034 can be authored in parallel.
T038 and T039 can be implemented in parallel after T037.
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 setup.
2. Complete Phase 2 foundation.
3. Complete Phase 3 US1.
4. Validate direct PDF download without preview.
5. Stop for review before moving to executive renderer quality.

### Incremental Delivery

1. US1 secures the no-preview download behavior.
2. US2 upgrades the PDF to executive quality.
3. US3 clarifies product semantics for PDF vs CSV/ZIP and history states.
4. Polish closes documentation, memory and validation gates.

### Parallel Team Strategy

After Phase 2:

- Developer A: US1 frontend download flow and tests.
- Developer B: US2 renderer templates, fonts and PDF formatting.
- Developer C: US3 CSV/history semantics, labels and quickstart validation.

---

## Notes

- All tasks follow the strict checklist format with IDs, optional `[P]`, story labels and exact file paths.
- No migration or schema rewrite is planned unless implementation uncovers a real contract gap in feature 008.
- The missing-production constraint remains: this backlog prepares the implementation but does not imply production rollout.
