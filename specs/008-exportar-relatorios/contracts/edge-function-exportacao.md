# Contract: Edge Function `relatorios-exportacao`

**Path**: `supabase/functions/relatorios-exportacao/index.ts`

## Authentication

- Requires `Authorization: Bearer <user_jwt>`.
- Must create a user-scoped Supabase client using the incoming JWT for RPC authorization.
- May use service role only inside the function for private Storage upload/signing after the user-scoped RPC authorizes the operation.
- Must never return service role secrets or public permanent object URLs.

## CORS

- Support `OPTIONS`.
- Allow application origin(s) configured for local/dev/prod.
- Return JSON errors for failed validation/authorization.

## Action: `gerar`

### Request

```json
{
  "action": "gerar",
  "tipo": "financeiro",
  "formato": "PDF",
  "data_inicial": "2026-07-01",
  "data_final": "2026-07-31"
}
```

### Validation

- `tipo` must be one of the categories exposed by Relatorios and allowed to the current persona.
- `formato` must be `PDF` or `CSV`.
- `data_inicial` and `data_final` must be valid ISO dates.
- `data_inicial <= data_final`.
- Dates are inclusive.
- One-day periods are valid.
- Period must not exceed the inclusive 12-month business rule: `2026-01-01` to `2026-12-31` is valid; `2026-01-01` to `2027-01-01` is invalid.
- Current user must have `relatorios.exportar`.
- `tipo` must be one of `Financeiro`, `DRE`, `Clientes`, or `Projetos`; `Personalizado` returns `INVALID_CATEGORY`.
- Common-volume target is up to 5,000 detailed rows or 10 MB before compression.

### Flow

1. Call `iniciar_exportacao_relatorio(tipo, formato, data_inicial, data_final)` with user JWT.
2. Render PDF or ZIP CSV from returned report payload.
3. Upload file to private bucket `relatorios-exportados`.
4. Call `concluir_exportacao_relatorio(...)` with file metadata.
5. Create short-lived signed URL for the object.
6. Return export metadata and `download_url`.
7. On any generation/upload error after the record is created, call `falhar_exportacao_relatorio(exportacao_id, erro)`.

### Success Response

```json
{
  "exportacao": {
    "id": "uuid",
    "tipo": "financeiro",
    "formato": "PDF",
    "status_exibicao": "Pronto",
    "data_inicial": "2026-07-01",
    "data_final": "2026-07-31",
    "arquivo_nome": "relatorio-financeiro-2026-07-01-2026-07-31-ab12cd.pdf",
    "mime_type": "application/pdf",
    "gerado_em": "2026-07-04T15:00:00Z",
    "expira_em": "2027-07-04T15:00:00Z"
  },
  "download_url": "https://...",
  "download_expires_in": 600
}
```

## Action: `download`

### Request

```json
{
  "action": "download",
  "exportacao_id": "uuid"
}
```

### Flow

1. Call `autorizar_download_exportacao_relatorio(exportacao_id)` with user JWT.
2. If authorized and not expired, create short-lived signed URL.
3. Return signed URL and file metadata.

### Success Response

```json
{
  "exportacao": {
    "id": "uuid",
    "arquivo_nome": "relatorio-projetos-2026-07-01-2026-07-31-ab12cd.zip",
    "mime_type": "application/zip",
    "expira_em": "2027-07-04T15:00:00Z"
  },
  "download_url": "https://...",
  "download_expires_in": 600
}
```

## Error Responses

```json
{
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "Usuario sem permissao para exportar relatorios."
  }
}
```

Required codes:

- `INVALID_PERIOD`
- `PERIOD_TOO_LONG`
- `INVALID_FORMAT`
- `INVALID_CATEGORY`
- `PERMISSION_DENIED`
- `EXPORT_NOT_FOUND`
- `EXPORT_EXPIRED`
- `EXPORT_NOT_READY`
- `GENERATION_FAILED`
- `STORAGE_FAILED`
- `EXPORT_TOO_LARGE`

## Rendering Rules

### PDF

- Render with `pdf-lib`.
- Include title, category, period, solicitante, generation timestamp and expiration timestamp.
- Show executive summary before details.
- Details must be readable and paginated.
- If no data exists, include explicit no-data message.

### CSV

- Serialize CSV internally and create ZIP with `fflate`.
- Include `resumo.csv`.
- Include `detalhes.csv`.
- Use UTF-8.
- Escape delimiter, quotes and line breaks correctly.
- If details are empty, `detalhes.csv` still includes headers and no-data context.

## Observability

Each `gerar` and `download` action must produce traceable logs/events with:

- `exportacao_id`
- `usuario_id`
- `tipo`
- `formato`
- `data_inicial`
- `data_final`
- `status`
- `duracao_ms`
- `tamanho_bytes`, when a file exists
- sanitized error code/message when it fails

Successful generation, generation failure and authorized download should be recorded in the existing audit/event mechanism when available.
