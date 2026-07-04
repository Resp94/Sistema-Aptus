# Contract: Frontend Relatorios

## Page

`src/pages/RelatoriosPage.tsx`

## UX Requirements

- Export modal must include:
  - selected category display
  - `data_inicial`
  - `data_final`
  - format selector `PDF` or `CSV`
  - primary action "Gerar e baixar"
- Default period:
  - `data_inicial`: first day of current month
  - `data_final`: current date
- Frontend validates:
  - start date <= end date
  - period <= 12 months
  - format selected
  - user has export capability
- Backend remains source of truth and repeats all validations.
- Layout must remain usable from 320px width upward.
- Modal must have explicit labels, initial focus on the first editable field, keyboard navigation, and close on Escape.
- Status badges must not rely on color alone; text labels are required.

## Service

`src/services/relatorios.service.ts`

### `exportarRelatorio`

```ts
type ExportarRelatorioInput = {
  tipo: string
  formato: 'PDF' | 'CSV'
  data_inicial: string
  data_final: string
}
```

Behavior:

- Call `supabase.functions.invoke('relatorios-exportacao', { body: { action: 'gerar', ...input } })`.
- On success, trigger browser download/open using returned signed URL.
- Refresh history after success or failure.

### `baixarExportacaoRelatorio`

```ts
type BaixarExportacaoInput = {
  exportacao_id: string
}
```

Behavior:

- Call `supabase.functions.invoke('relatorios-exportacao', { body: { action: 'download', exportacao_id } })`.
- Trigger download using returned signed URL.

## Types

Update `src/types/relatorios.ts` and common status types:

- Add `data_inicial`
- Add `data_final`
- Add `expira_em`
- Add `arquivo_nome`
- Add `mime_type`
- Add `tamanho_bytes`
- Add `criado_por`
- Add `criado_por_nome`
- Add `status_exibicao`
- Add `pode_baixar`
- Add display status `Expirado`

## History Table

Display columns:

- Categoria
- Formato
- Periodo
- Status
- Solicitante (visible especially for Administrador)
- Gerado em
- Expira em
- Acao

Rules:

- Show Download only when `pode_baixar = true`.
- Show expired state without download.
- Show failed state with clear message.
- Show legacy `Indisponível` without download.
- Newest first.
- Administrador sees requester identity for all rows.
- Financeiro and Projetos receive requester data in the contract but the UI may show own name or omit the requester column on compact/mobile layouts.
- Mobile layouts may collapse less important columns, but must keep category, format, period, status and download state understandable.

## Capability UI

- User without `relatorios.exportar` must not see active export controls.
- Visualizador may continue reading reports if allowed, but sees no export PDF/CSV action.
- Backend denial must be surfaced even if UI gating failed.
- `Personalizado` must not show an active export action for feature 008.

## Error Messages

Required user-facing cases:

- Periodo invalido.
- Periodo maior que 12 meses.
- Sem permissao para exportar.
- Categoria nao permitida.
- Exportacao expirada.
- Exportacao ainda nao pronta.
- Falha ao gerar arquivo.
- Sem dados no periodo, when applicable.
- Exportacao muito grande para download imediato.
- Categoria sem contrato de exportacao completo.

## Legacy Flow Removal

- `RelatoriosPage.tsx` must stop calling `solicitarExportacaoRelatorio` for manual export.
- `relatorios.service.ts` should keep legacy method only if existing callers still need it; new manual export must use `exportarRelatorio`.
- The integration-pending banner for manual export should be removed from the new export path.
