# Quickstart: Exportar Relatorios

**Date**: 2026-07-04

## Prerequisites

- Supabase local running.
- `.env.local` configured for local Supabase.
- Feature 007 capability foundation available: `tem_capacidade` and `obter_capacidades_usuario`.
- Supabase CLI checked with `supabase --version` and `supabase functions --help`.

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
npm run db:test
supabase functions serve relatorios-exportacao
npm run test
npm run build
npm run audit
```

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

## Completion Criteria

- All final gates pass.
- No permanent public report URL is exposed.
- `arquivo_url` is not used by the new download flow.
- History download uses Edge Function authorization every time.
- `.agents` and `.sauron` documentation are updated with architectural and business rule changes.
