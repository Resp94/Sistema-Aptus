> This task list is immediately executable. Each task is specific enough to be completed without additional context.

# Tasks: Definição da Stack Tecnológica

**Input**: Design documents from `specs/002-tech-stack-definition/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the project structure and install base dependencies for the new stack.

- [x] T001 Create Vite + React + TypeScript project scaffold with `index.html`, `package.json`, `vite.config.ts`, and `tsconfig.json` in repository root
- [x] T002 [P] Configure ESLint and Prettier for TypeScript/React in repository root
- [x] T003 [P] Install runtime dependencies: `react`, `react-dom`, `@supabase/supabase-js` in `package.json`
- [x] T004 [P] Install dev dependencies: `typescript`, `vite`, `@types/react`, `@types/react-dom`, `vitest` in `package.json`
- [x] T005 Create source directory structure: `src/main.tsx`, `src/App.tsx`, `src/components/`, `src/pages/`, `src/services/`, `src/types/`
- [x] T006 Verify existing `supabase/` structure and create missing `supabase/migrations/` directory and `supabase/seed.sql` placeholder
- [x] T007 Create `docs/stack.md` as the single source of truth for stack decisions
- [x] T008 Create `public/` directory for static assets and move existing static assets if applicable

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Configure the core infrastructure that MUST be complete before ANY user story can be fully validated.

**⚠️ CRITICAL**: No user story work can be considered complete until this phase is done.

- [x] T009 Create `src/services/supabase.ts` with `createClient` using environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
- [x] T010 Create `.env.example` documenting required environment variables for local and production
- [x] T011 Create `.env.local` with default values pointing to local Supabase (`http://localhost:54321`)
- [x] T012 Review existing `supabase/config.toml` for local development settings and adjust `project_id`, ports, or seed path if needed
- [x] T013 Add npm scripts to `package.json`: `dev`, `build`, `preview`, `test`
- [x] T014 If `supabase/migrations/` is empty, create a baseline migration that captures the current local schema using `npx supabase db diff -f initial_schema`
- [x] T015 Create `supabase/seed.sql` with minimal seed data for local validation

**Checkpoint**: Foundation ready — `npm install`, `npm run dev`, and `npx supabase start` can be executed.

---

## Phase 3: User Story 1 — Ambiente de desenvolvimento local reproduzível (Priority: P1) 🎯 MVP

**Goal**: Qualquer desenvolvedor consegue subir backend, banco e frontend localmente seguindo a documentação.

**Independent Test**: Um novo desenvolvedor clona o repo, executa `npm install`, confirma que `npx supabase status` reporta os serviços healthy, executa `npm run dev` e acessa a aplicação em `http://localhost:5173` sem erros.

### Implementation for User Story 1

- [x] T016 [US1] Verify the already-running local Supabase services are healthy using `npx supabase status`
- [x] T017 [US1] Implement a health-check page or console script in `src/services/health-check.ts` that calls the local Supabase REST endpoint
- [x] T018 [US1] Add `supabase:status`, `supabase:start`, `supabase:stop`, and `supabase:reset` npm scripts in `package.json`
- [x] T019 [US1] Update `quickstart.md` with verified commands and expected outcomes for local setup
- [x] T020 [US1] Document troubleshooting steps for Docker unavailability or resource constraints in `docs/stack.md`
- [x] T021 [US1] Run `npx supabase db reset` and confirm existing schema + seed data apply cleanly
- [x] T022 [US1] Configure Vitest in `vite.config.ts` and create a smoke integration test `src/services/supabase.test.ts` that calls the local Supabase REST endpoint
- [x] T023 [US1] Validate local → cloud promotion by linking to a non-production Supabase Cloud project and running `npx supabase db push`

**Checkpoint**: User Story 1 is fully functional and independently testable.

---

## Phase 4: User Story 2 — Plataforma de hospedagem e deploy definida (Priority: P2)

**Goal**: A plataforma de hospedagem do frontend está decidida, configurada e documentada.

**Independent Test**: Um `npm run build` gera uma pasta `dist/` que pode ser publicada na Cloudflare Pages seguindo os passos documentados.

### Implementation for User Story 2

- [x] T024 [US2] Configure `vite.config.ts` output directory to `dist/` and verify build produces static assets
- [x] T025 [US2] Document Cloudflare Pages project creation and Git integration steps in `docs/stack.md`
- [x] T026 [US2] Add Cloudflare Pages-specific build settings (build command `npm run build`, output directory `dist`) to `docs/stack.md`
- [x] T027 [US2] Configure custom domain or preview branch strategy in Cloudflare dashboard and document in `docs/stack.md`
- [x] T028 [US2] Create a deployment checklist in `docs/stack.md` for publishing new frontend versions
- [x] T029 [US2] Verify the production build runs successfully with `npm run build && npm run preview`

**Checkpoint**: User Story 2 is complete — deploy path to Cloudflare Pages is documented and validated.

---

## Phase 5: User Story 3 — Decisões arquiteturais registradas (Priority: P3)

**Goal**: As escolhas de stack e suas justificativas estão registradas em um único documento acessível.

**Independent Test**: Um novo membro da equipe lê `docs/stack.md` e `.sauron/wiki/knowledge/architecture.md` e entende todas as decisões sem precisar perguntar.

### Implementation for User Story 3

- [x] T030 [US3] Populate `docs/stack.md` with the complete stack overview: Cloudflare, Supabase, Vite + React + TypeScript, Supabase CLI + Docker
- [x] T031 [US3] Document each decision with problem, options considered, chosen solution, and justification in `docs/stack.md`
- [x] T032 [US3] Document the local → cloud promotion workflow in `docs/stack.md` referencing `contracts/local-cloud-promotion.md`
- [x] T033 [US3] Document the Supabase integration contract in `docs/stack.md` referencing `contracts/supabase-integration.md`
- [x] T034 [US3] Update `.sauron/wiki/knowledge/architecture.md` to reference `docs/stack.md` and the `specs/002-tech-stack-definition/` artifacts
- [x] T035 [US3] Update `.sauron/wiki/summary.json` metadata if architecture.md content changed

**Checkpoint**: User Story 3 is complete — all architectural decisions are traceable and documented.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, documentation consistency, and preparation for implementation of future business features.

- [x] T036 [P] Run through all steps in `quickstart.md` and mark the feature validated
- [x] T037 [P] Review `docs/stack.md`, `plan.md`, and `research.md` for consistency
- [x] T038 [P] Document the migration strategy for legacy `*.html` files at repository root (preserve, redirect, or migrate per page) in `docs/stack.md`
- [x] T039 [P] Add a `README.md` section describing the new stack and how to run the project
- [x] T040 [P] Archive completed design artifacts (`spec.md`, `plan.md`, `tasks.md`, checklists) reference in `.sauron/wiki/knowledge/architecture.md` if not already present

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories.
- **User Stories (Phases 3–5)**: All depend on Foundational phase completion.
  - Can proceed sequentially in priority order (P1 → P2 → P3) or in parallel if staffed.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2). No dependencies on other stories.
- **User Story 2 (P2)**: Can start after Foundational (Phase 2). Depends on build tooling from Phase 1/2; independent of US1 functionality.
- **User Story 3 (P3)**: Can start after Foundational (Phase 2). Depends on decisions made in earlier phases; primarily documentation.

### Within Each User Story

- Core setup before validation
- Documentation updated as the last task of each story
- Story marked complete when its independent test criteria pass

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel.
- All Foundational tasks marked [P] can run in parallel (within Phase 2).
- Once Foundational phase completes, US1, US2, and US3 can be worked on in parallel by different team members.
- All Polish tasks marked [P] can run in parallel.

---

## Suggested MVP Scope

**MVP = User Story 1 only** (local development environment).

Delivering US1 provides immediate value: any developer can clone the repo and have a working local environment. US2 and US3 can follow in subsequent iterations.

---

## Parallel Example: User Story 1

If multiple developers are available after Phase 2:

- Developer A: T016, T017, T022 (verify Supabase services, health check, and integration test)
- Developer B: T018, T019, T023 (npm scripts, quickstart updates, and cloud promotion validation)
- Developer C: T020, T021 (troubleshooting docs and migration validation)

All merge when the independent test passes: clean clone → install → supabase status healthy → npm run dev → app loads.
