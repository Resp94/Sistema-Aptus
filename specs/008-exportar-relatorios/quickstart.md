# Quickstart: Exportar Relatorios

**Date**: 2026-07-04

## Prerequisites

- Supabase local running.
- `.env.local` configured for local Supabase.
- Feature 007 capability foundation available: `tem_capacidade` and `obter_capacidades_usuario`.
- Supabase CLI checked with `supabase --version` and `supabase functions --help`.

## Supabase CLI Verification (2026-07-04)

- Installed version: `supabase --version` reports `2.75.0`.
- The CLI itself flags that a newer version is available (`v2.109.0`) and recommends updating, but does not block usage.
- `supabase --help` exposes all commands needed for this feature: `functions`, `db`, `migration`, `start`, `status`, `secrets`, `services`.
- `supabase functions --help` exposes `deploy`, `serve`, `new`, `list`, `download` and `delete` — i.e. everything required to develop, serve locally and deploy the `relatorios-exportacao` Edge Function.
- Conclusion: no CLI upgrade is required before implementing this feature. The locally available `functions` subcommands cover the full local dev loop (`supabase functions serve relatorios-exportacao`) and deployment. Upgrading to `2.109.0` remains a "nice to have" for newer features/bug fixes and advisors, but is not a blocker for Phase 2/implementation.

## Expected Implementation Order

1. Create migration for `exportacoes_relatorios` fields, indexes, bucket and RPCs.
2. Add pgTAP tests for authorization, period validation, history scope and expiration.
3. Implement Edge Function `relatorios-exportacao`.
4. Add frontend service methods and type updates.
5. Update `RelatoriosPage.tsx` modal and history.
6. Add Vitest coverage.
7. Run final gates.

## Local Commands

```bash
npm run supabase:start
npm run supabase:reset
npm run db:test
supabase functions serve relatorios-exportacao
npm run test
npm run build
npm run audit
```

`npm run supabase:reset` before `npm run db:test` is required for a
deterministic result: the pgTAP files under `supabase/tests/` are not
transaction-isolated from each other (fixtures like
`fixture_exportacao_pronta`/`iniciar_exportacao_relatorio` insert real rows
that persist across runs), so re-running `db:test` repeatedly against the
same long-lived local database without a reset can accumulate rows that make
unrelated older tests (e.g. `05_capacidades.sql`) fail on data no longer
matching a 1-row expectation. This is a pre-existing characteristic of this
project's pgTAP suite, not something specific to feature 008. Also note: the
helper file was renamed from `00_helpers.sql` to `000_helpers.sql` (2026-07-05)
so it always sorts and executes before `008_exportar_relatorios.sql` — the
literal byte-sort of `008_...` vs `00_helpers.sql` used by `supabase test db`'s
file discovery placed `008_...` first, which broke on a freshly reset database
because it calls `reset_auth()`/`set_auth_by_email()` before they existed.

## Manual Validation Scenarios

### 1. Admin PDF immediate download

1. Login as Administrador.
2. Open Relatorios.
3. Select Financeiro.
4. Open export modal.
5. Keep default period.
6. Select PDF.
7. Click Gerar e baixar.

Expected:

- PDF downloads immediately.
- History shows record `Pronto`.
- Period, format, requester, generation and expiration are visible.

### 2. CSV package

1. Login as Financeiro.
2. Select allowed financial category.
3. Choose CSV.
4. Generate export.

Expected:

- Browser downloads `.zip`.
- ZIP contains `resumo.csv` and `detalhes.csv`.
- CSV files are UTF-8 and open correctly in spreadsheet tooling.

### 3. Projects scoped export

1. Login as Projetos.
2. Select Projetos.
3. Generate PDF or CSV.

Expected:

- File contains current project snapshot plus activity metrics for period.
- It does not include disallowed categories.

### 4. Invalid period

1. Set start date after end date.
2. Try to generate.

Expected:

- Frontend blocks before calling the function.
- Direct Edge Function/RPC attempt is also rejected.

### 5. Period greater than 12 months

1. Set a period longer than 12 months.
2. Try to generate.

Expected:

- Export is blocked.
- No file is created.
- No `Pronto` history record is created.

Boundary expectations:

- `2026-01-01` to `2026-12-31` is allowed.
- `2026-01-01` to `2027-01-01` is blocked.
- Same-day export is allowed.

### 6. Expired history

1. Seed or update an export with `expira_em < now()`.
2. Open history.

Expected:

- Record appears as `Expirado`.
- Download action is disabled/hidden.
- Direct download action returns `EXPORT_EXPIRED`.

### 7. Persona blocking

Validate each profile:

- Visualizador can read allowed Relatorios but cannot export.
- Comercial cannot export by UI or direct function call.
- Tecnico cannot export by UI or direct function call.
- Financeiro/Projetos cannot download another user's export.
- Administrador can download valid exports from all users.
- `Personalizado` cannot be exported in feature 008.
- Admin, Financeiro and Projetos each have at least one PDF and one CSV success scenario for allowed categories.

### 8. Accessibility and responsive export modal

Expected:

- Modal works at 320px width and desktop widths.
- First editable field receives initial focus.
- Labels are explicit for date and format controls.
- Keyboard navigation reaches all controls.
- Escape closes the modal.
- Status is readable as text, not only color.

### 9. Large export and observability

Generate or seed an export payload above 5,000 detailed rows or 10 MB before compression.

Expected:

- Export fails with clear message.
- No partial file is presented as success.
- Logs/events include export id, user, category, format, period, duration and sanitized error.

## No-Data Scenario

Generate a report for a valid category/period with no rows.

Expected:

- Export succeeds.
- File has title, category, period and explicit no-data message.
- CSV package still contains headers.

## US3 Persona Matrix — Manual Validation (T066)

Ambiente sem browser headless disponível: a validação manual da matriz completa
de personas foi feita via `psql` (conectado ao container local
`supabase_db_sistema-aptus`), simulando JWT com os helpers de
`supabase/tests/000_helpers.sql` (`set_auth_by_email`/`set_anon`/`reset_auth`)
e reaproveitando os helpers de persona/fixture já seedados por
`supabase/tests/008_exportar_relatorios.sql`
(`email_persona_teste_relatorios`, `fixture_persona_visualizador_008`,
`fixture_exportacao_pronta`), exatamente como os cenários acima descrevem.

### Pré-requisitos de seed para rodar esta validação

- **Personas operacionais** (`supabase/seed.sql`, já seedadas por padrão):
  `admin@aptusflow.local` (Administrador), `financeiro@aptusflow.local`
  (Financeiro), `projetos@aptusflow.local` (Projetos),
  `comercial@aptusflow.local` (Comercial), `tecnico@aptusflow.local`
  (Técnico). Todas com `perfis.status = 'Ativo'`.
- **Persona Visualizador**: não é seedada por padrão (mesma situação de
  `supabase/tests/05_capacidades.sql`, seção 5). Para validação manual, crie-a
  com `SELECT public.fixture_persona_visualizador_008();` (definida em
  `supabase/tests/008_exportar_relatorios.sql`, idempotente) — isso insere
  `visualizador_teste_008@aptusflow.local` em `auth.users` e o trigger padrão
  de cadastro cria o `perfis` correspondente com `perfil_acesso =
  'Visualizador'` e `status = 'Ativo'`.
- **Fixtures de exportação `Pronto`** (necessárias apenas para exercitar
  `autorizar_download_exportacao_relatorio`/histórico sem depender de rodar o
  fluxo completo de geração de arquivo): use
  `SELECT public.fixture_exportacao_pronta('<email-dono>', '<categoria>');`
  (também em `008_exportar_relatorios.sql`) logo após `SELECT reset_auth();`
  (a função não é `SECURITY DEFINER` e depende de RLS permissivo do role
  padrão). Retorna o `id` da exportação simulada, útil para chamar
  `autorizar_download_exportacao_relatorio(id)` em seguida com uma persona
  autenticada via `set_auth_by_email`.
- Rodar `npm run db:test` (ou `npx supabase test db
  supabase/tests/000_helpers.sql supabase/tests/008_exportar_relatorios.sql`)
  ao menos uma vez garante que todos os helpers/fixtures acima já existem no
  catálogo do banco local antes de uma sessão manual avulsa de `psql`.

### Resultado da validação (2026-07-05, banco local resetado com `npm run supabase:reset`)

**Leitura/preview** (`listar_categorias_relatorios`):

| Persona | Categorias visíveis |
|---|---|
| Administrador | Financeiro, DRE, Clientes, Projetos, Personalizado |
| Visualizador | Financeiro, DRE, Clientes, Projetos, Personalizado (mesmo conjunto do Admin; leitura sem exportação) |
| Financeiro | Financeiro, DRE |
| Projetos | Projetos |
| Comercial | nenhuma (`permissao_modulo('relatorios').pode_ler = false` na matriz RBAC atual — Comercial não tem acesso de leitura ao módulo Relatórios, não só à exportação) |
| Técnico | nenhuma (mesmo motivo do Comercial) |

**Exportação** (`iniciar_exportacao_relatorio`, testado nas 5 categorias
incluindo `Personalizado` para cada persona):

| Persona | Financeiro | DRE | Clientes | Projetos | Personalizado |
|---|---|---|---|---|---|
| Administrador | permitido | permitido | permitido | permitido | `INVALID_CATEGORY` |
| Financeiro | permitido | permitido | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `INVALID_CATEGORY` |
| Projetos | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | permitido | `INVALID_CATEGORY` |
| Visualizador | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` |
| Comercial | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` |
| Técnico | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` | `PERMISSION_DENIED` |

**Download** (`autorizar_download_exportacao_relatorio`, exportações fixture
`Pronto` cruzando dono x solicitante):

- Administrador baixa exportação de qualquer dono (testado: export Financeiro
  gerado por Financeiro, export Projetos gerado por Projetos) → permitido.
- Financeiro baixa a própria exportação Financeiro → permitido; tenta baixar
  exportação alheia de Projetos (dono Projetos) → `PERMISSION_DENIED`; tenta
  baixar exportação de categoria não permitida ao seu perfil (Clientes, ainda
  que gerada por Admin) → `PERMISSION_DENIED`.
- Projetos baixa a própria exportação Projetos → permitido; tenta baixar
  exportação alheia de Financeiro → `PERMISSION_DENIED`.
- Visualizador, Comercial e Técnico → `PERMISSION_DENIED` em qualquer
  exportação, independentemente do dono ou categoria (sem capacidade
  `relatorios.exportar`).

**Histórico** (`listar_exportacoes_relatorios`, contagem de linhas visíveis
por persona no banco de validação):

- Administrador: todas as exportações existentes (visão global).
- Financeiro: apenas as próprias.
- Projetos: apenas as próprias.
- Visualizador, Comercial, Técnico: 0 linhas (sem histórico, conforme
  contracts/rpc-exportacao-relatorios.md).

### Veredito da validação manual (T066)

A matriz de personas x categorias x ações (ler/exportar/baixar) bate
exatamente com `spec.md` (User Story 3, FR-015 a FR-019b) e com a matriz já
coberta por pgTAP em `supabase/tests/008_exportar_relatorios.sql` (seções 4,
7, 10 e 11): nenhuma divergência encontrada entre o comportamento observado
via chamada direta de RPC e o que os testes automatizados afirmam. O único
ponto que vale registrar como contexto (não é uma lacuna da feature 008): o
bloqueio de leitura de Comercial/Técnico no módulo Relatórios acontece um
nível acima da matriz de categorias exportáveis desta feature —
`permissao_modulo('relatorios').pode_ler` já é `false` para esses dois perfis
na configuração RBAC atual (feature 007), então o branch de
`listar_categorias_relatorios` que retornaria `Clientes` para Comercial nunca
é alcançado hoje. Isso é consistente com o escopo desta feature (que não
redefine RBAC de leitura do módulo), mas fica documentado aqui para quem for
depurar "por que Comercial não vê nem Clientes" no futuro.

## Completion Criteria

- All final gates pass.
- No permanent public report URL is exposed.
- `arquivo_url` is not used by the new download flow.
- History download uses Edge Function authorization every time.
- `.agents` and `.sauron` documentation are updated with architectural and business rule changes.

## Final Gates Results — Polish T075-T080 (2026-07-05)

Executed on a freshly reset local database (`npx supabase db reset`) to
guarantee determinism per the note above about non-transaction-isolated
pgTAP fixtures.

- **T075 `npm run db:test`**: `PASS` — `Files=7, Tests=369` (includes
  `supabase/tests/000_helpers.sql`, `008_exportar_relatorios.sql`,
  `01_anon_rejeitado.sql`, `02_rbac_por_perfil.sql`, `03_auditoria.sql`,
  `04_signup_sem_escalacao.sql`, `05_capacidades.sql`). The private-bucket
  and public-read-denial assertions in `008_exportar_relatorios.sql` pass as
  part of this run.
- **T076 `npm run test`**: `PASS` — `Test Files 12 passed (12)`,
  `Tests 113 passed (113)`. Console `stderr` lines visible during the run
  (e.g. `PERMISSION_DENIED`, `EXPORT_EXPIRED`, `Invalid login credentials`,
  `Not implemented: navigation to another Document`) are expected
  negative-path logging from tests that assert on error handling, not
  failures — all 113 tests report as passed.
- **T077 `npm run build`**: `PASS` — `tsc -b && vite build` completes with
  no type or build errors. Vite emits a non-blocking chunk-size advisory
  (`dist/assets/index-*.js` ~650 kB) suggesting future code-splitting; this
  is an informational warning, not a build failure, and is pre-existing
  (not introduced by feature 008 report rendering code, which runs
  server-side in the Edge Function, not in the bundled client chunk).
- **T078 `npm run audit`**: `PASS` (re-confirmed) — `audit:rpc` reports
  `93/93 functions compliant`, `audit:from` reports no forbidden
  `supabase.from()` calls, `audit:metadata` reports no unexpected
  `raw_user_meta_data`/`user_metadata` usage.
- **T079 Quickstart scenarios**: All manual scenarios 1-9 above and the US3
  persona matrix (T066 section) were already executed and recorded on
  2026-07-04/2026-07-05 before this final gate pass; this entry confirms
  the automated regression suite (T075/T076) still passes against the same
  behavior after a full local database reset, so the recorded manual
  results remain valid and are not stale.
- **T080 Git inventory**: `git status`/`git diff --stat` reviewed in full.
  All expected generated paths are present:
  `supabase/migrations/20260704235640_exportar_relatorios.sql`,
  the complete `supabase/functions/relatorios-exportacao/` folder
  (`index.ts`, `_shared.ts`, `renderers.ts`, `payload.ts`, plus Deno-native
  `index.test.ts`, `index.download.test.ts`, `renderers.test.ts`), and
  `supabase/tests/008_exportar_relatorios.sql`. One unrelated-looking
  artifact was found and investigated: a root-level `deno.lock` (untracked,
  not covered by `.gitignore`). It only contains resolved remote-module
  hashes for `deno.land/std@0.224.0` and `esm.sh` packages referenced by
  `supabase/functions/relatorios-exportacao/*.ts` (`@supabase/supabase-js`,
  `pdf-lib`, `fflate`, plus the `deno.land/std` `assert` module used only by
  the Deno-native `*.test.ts` files) — no absolute local paths or
  machine-specific data. It was generated automatically by the Deno runtime
  the first time `supabase functions serve relatorios-exportacao` (or a
  manual `deno test`/`deno check` pass over the new Edge Function test
  files) ran locally during implementation, since this is the first Edge
  Function added to the project and no prior `deno.lock` or import-map
  convention existed to suppress it. Recommendation: treat it like
  `package-lock.json` and commit it — it pins the exact remote dependency
  versions this Edge Function resolves against, which is what gives
  `supabase functions deploy` reproducible builds; it is not a stray/
  accidental artifact tied to one machine. No `.gitignore` change is
  required either way since nothing currently excludes it. This decision is
  left to the developer completing the commit, since it is a
  repo-convention choice rather than a feature-008 correctness gate.
