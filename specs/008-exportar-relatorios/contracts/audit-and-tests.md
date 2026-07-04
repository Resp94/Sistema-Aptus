# Contract: Audit and Tests

## pgTAP / Database Tests

Create `supabase/tests/008_exportar_relatorios.sql` covering:

- `iniciar_exportacao_relatorio` blocks unauthenticated user.
- User without `relatorios.exportar` cannot start export.
- Visualizador cannot start or download export.
- Comercial and Tecnico cannot start or download export.
- Financeiro can export allowed financial category.
- Financeiro can export DRE.
- Projetos can export allowed projects category.
- Administrador can export Financeiro, DRE, Clientes and Projetos.
- `Personalizado` is not exportable in feature 008.
- Category outside persona scope is blocked.
- Admin can list/download exports from other users.
- Financeiro and Projetos list/download only own exports.
- `data_inicial > data_final` is blocked.
- Period greater than 12 months is blocked.
- One-day period is allowed.
- `2026-01-01` through `2026-12-31` is allowed.
- `2026-01-01` through `2027-01-01` is blocked.
- `autorizar_download_exportacao_relatorio` blocks expired export.
- `autorizar_download_exportacao_relatorio` blocks failed/pending/legacy unavailable export.
- `listar_exportacoes_relatorios` returns newest first and computes `status_exibicao`.

## Vitest / Frontend Tests

Cover:

- Export modal defaults to current month start and today.
- User can change date range and format.
- Frontend blocks invalid date order.
- Frontend blocks period greater than 12 months.
- Service calls Edge Function action `gerar` with category, format and dates.
- Download history calls Edge Function action `download`.
- History renders `Pronto`, `Falhou`, `Expirado` and legacy unavailable states.
- Export controls are hidden/disabled without capability.
- Export controls are not active for `Personalizado`.
- Modal supports keyboard navigation, initial focus, Escape close and labels.
- History status is communicated with text, not only color.

## Edge Function Validation

At minimum, validate locally with:

- Generate PDF success.
- Generate CSV ZIP success.
- Generate PDF and CSV for at least one allowed category per export-capable persona:
  - Administrador: any of Financeiro/DRE/Clientes/Projetos.
  - Financeiro: Financeiro or DRE.
  - Projetos: Projetos.
- Download previous export success.
- Expired export denied.
- Unauthorized persona denied.
- Storage upload failure marks export as failed.
- Export above 5,000 detailed rows or 10 MB before compression returns `EXPORT_TOO_LARGE` or equivalent clear failure.

If a Deno test harness exists or is added, cover renderer helpers for:

- CSV escaping.
- ZIP contains `resumo.csv` and `detalhes.csv`.
- PDF renderer handles no-data payload.

## Final Gates

Run before claiming implementation complete:

```bash
npm run db:test
npm run test
npm run build
npm run audit
```

If Supabase local services are required:

```bash
npm run supabase:start
supabase functions serve relatorios-exportacao
```

## Persona Matrix

| Persona | Read Relatorios | Generate | Download Own | Download Others |
|---------|-----------------|----------|--------------|-----------------|
| Administrador | Yes | Yes | Yes | Yes |
| Financeiro | Yes, scoped | Yes, scoped | Yes | No |
| Projetos | Yes, scoped | Yes, scoped | Yes | No |
| Visualizador | Yes, limited | No | No | No |
| Comercial | No/limited per route policy | No | No | No |
| Tecnico | No/limited per route policy | No | No | No |

## Observability Checks

Requirements and tasks must cover logs/events for:

- generation started
- generation completed
- generation failed
- download authorized
- download denied

Each event should include `exportacao_id`, user, category, format, period, duration and sanitized error when applicable.
