# Contract: RPCs de Exportacao de Relatorios

All functions must use fixed `search_path`, explicit grants, `auth.uid()` validation, and backend authorization. Names below are target contracts. The Edge Function must use these contracts, not the legacy request-only RPC.

## Exportable Categories

Canonical visible categories continue to come from `public.listar_categorias_relatorios()` for read/preview. Export authorization must additionally use a helper/RPC derived from the same matrix, for example:

```sql
public.categoria_relatorio_exportavel(
  p_tipo text,
  p_perfil text
) returns boolean
```

Rules:

- Administrador: `Financeiro`, `DRE`, `Clientes`, `Projetos`.
- Financeiro: `Financeiro`, `DRE`.
- Projetos: `Projetos`.
- Visualizador, Comercial and Tecnico: none.
- `Personalizado`: not exportable in feature 008.

## `public.iniciar_exportacao_relatorio`

### Signature

```sql
public.iniciar_exportacao_relatorio(
  p_tipo text,
  p_formato text,
  p_data_inicial date,
  p_data_final date
) returns jsonb
```

### Responsibilities

- Validate authenticated user.
- Validate `tem_capacidade('relatorios.exportar')`.
- Validate persona/category scope.
- Validate format `PDF` or `CSV`.
- Validate period order and inclusive 12-month maximum.
- Insert `exportacoes_relatorios` with `status = 'Pendente'`.
- Build complete report payload with executive summary and details.
- Return payload to Edge Function.

### Return Shape

```json
{
  "exportacao_id": "uuid",
  "tipo": "financeiro",
  "formato": "PDF",
  "periodo": {
    "data_inicial": "2026-07-01",
    "data_final": "2026-07-31"
  },
  "solicitante": {
    "id": "uuid",
    "nome": "Usuario"
  },
  "resumo": [],
  "detalhes": [],
  "mensagem_sem_dados": null
}
```

## `public.concluir_exportacao_relatorio`

### Signature

```sql
public.concluir_exportacao_relatorio(
  p_exportacao_id uuid,
  p_arquivo_path text,
  p_arquivo_nome text,
  p_mime_type text,
  p_tamanho_bytes bigint,
  p_hash_sha256 text default null
) returns jsonb
```

### Responsibilities

- Validate authenticated user or trusted server context.
- Ensure export belongs to current user unless called by controlled server path.
- Ensure current status is `Pendente`.
- Set `status = 'Pronto'`.
- Set file metadata.
- Set `gerado_em = now()`.
- Set `expira_em = now() + interval '12 months'`.
- Clear `erro`.

## `public.falhar_exportacao_relatorio`

### Signature

```sql
public.falhar_exportacao_relatorio(
  p_exportacao_id uuid,
  p_erro text
) returns void
```

### Responsibilities

- Validate authenticated user or trusted server context.
- Ensure export belongs to current user unless called by controlled server path.
- Set `status = 'Falhou'`.
- Store sanitized error message.
- Ensure file metadata remains null unless a later cleanup task is explicitly implemented.

## `public.autorizar_download_exportacao_relatorio`

### Signature

```sql
public.autorizar_download_exportacao_relatorio(
  p_exportacao_id uuid
) returns jsonb
```

### Responsibilities

- Validate authenticated user.
- Validate `tem_capacidade('relatorios.exportar')`.
- Validate current persona/category scope.
- Enforce history visibility:
  - Administrador: any export.
  - Financeiro/Projetos: only own export (`criado_por = auth.uid()`).
  - Other profiles: denied.
- Ensure `status = 'Pronto'`.
- Ensure `expira_em >= now()`.
- Return `arquivo_path`, `arquivo_nome`, `mime_type`, and metadata for signing.

### Return Shape

```json
{
  "id": "uuid",
  "arquivo_path": "financeiro/2026/uuid/relatorio-financeiro-2026-07-01-2026-07-31-ab12cd.pdf",
  "arquivo_nome": "relatorio-financeiro-2026-07-01-2026-07-31-ab12cd.pdf",
  "mime_type": "application/pdf",
  "expira_em": "2027-07-04T15:00:00Z"
}
```

## `public.listar_exportacoes_relatorios`

### Existing contract change

Expand the existing RPC response to include period, expiration, requester and display status.

### Responsibilities

- Return newest records first.
- Scope results by persona:
  - Administrador: all exports.
  - Financeiro/Projetos: own exports.
  - Visualizador/Comercial/Tecnico: no exportable history, unless product later defines read-only audit view.
- Compute `status_exibicao`.
- Compute `pode_baixar`.
- Keep legacy `Indisponível` rows visible without download when they exist.

### Return Item Shape

```json
{
  "id": "uuid",
  "tipo": "financeiro",
  "formato": "PDF",
  "formato_entrega": "PDF",
  "status": "Pronto",
  "status_exibicao": "Pronto",
  "data_inicial": "2026-07-01",
  "data_final": "2026-07-31",
  "arquivo_nome": "relatorio-financeiro-2026-07-01-2026-07-31-ab12cd.pdf",
  "mime_type": "application/pdf",
  "tamanho_bytes": 128000,
  "criado_por": "uuid",
  "criado_por_nome": "Usuario",
  "gerado_em": "2026-07-04T15:00:00Z",
  "expira_em": "2027-07-04T15:00:00Z",
  "pode_baixar": true,
  "erro": null
}
```

## Legacy RPC: `solicitar_exportacao_relatorio`

The current RPC inserts `Indisponível`/pending-style rows. Implementation should either:

- Deprecate frontend usage and keep it only for compatibility.

The frontend for feature 008 must call the Edge Function, not the legacy request-only flow.
The legacy RPC must not be re-routed into the new generation path in this feature. It may continue returning legacy `Indisponível` records only for older callers, with no simulated success and no `arquivo_url`.
