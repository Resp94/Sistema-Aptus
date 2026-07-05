// Report export payload types/helpers for the `relatorios-exportacao`
// Edge Function.
//
// Contract: specs/008-exportar-relatorios/contracts/rpc-exportacao-relatorios.md
// Data model: specs/008-exportar-relatorios/data-model.md
//
// This module will own the mapping between the payload returned by
// `public.iniciar_exportacao_relatorio` (called with the user JWT) and the
// normalized shape consumed by `renderers.ts`. Implementation for all four
// categories (Financeiro, DRE, Clientes, Projetos) is planned for US1.

/** Exportable report categories in scope for feature 008. */
export type CategoriaRelatorioExportavel =
  | 'Financeiro'
  | 'DRE'
  | 'Clientes'
  | 'Projetos'

export type FormatoExportacao = 'PDF' | 'CSV'

export interface PeriodoExportacao {
  data_inicial: string
  data_final: string
}

export interface SolicitanteExportacao {
  id: string
  nome: string
}

/**
 * Raw shape returned by `public.iniciar_exportacao_relatorio`.
 * See "Return Shape" in contracts/rpc-exportacao-relatorios.md.
 */
export interface IniciarExportacaoResult {
  exportacao_id: string
  tipo: string
  formato: FormatoExportacao
  periodo: PeriodoExportacao
  solicitante: SolicitanteExportacao
  resumo: unknown[]
  detalhes: unknown[]
  mensagem_sem_dados: string | null
}

/**
 * Raw shape returned by `public.autorizar_download_exportacao_relatorio`
 * (migration 20260704235640, T014). Deliberately minimal: only what the
 * Edge Function needs to sign the already-authorized Storage object
 * (`arquivo_path`) and echo file metadata back to the client. It does not
 * include `tipo`/`formato`/`data_inicial`/`data_final` — the RPC itself
 * already persists those into `public.audit_log` (via
 * `registrar_evento_exportacao`) for both the authorized and denied paths,
 * so the Edge Function does not need them to satisfy traceability; see
 * `handleDownload` in index.ts for the corresponding log call.
 */
export interface AutorizarDownloadResult {
  id: string
  arquivo_path: string
  arquivo_nome: string
  mime_type: string
  expira_em: string
}

/**
 * Normalized payload consumed by the CSV/ZIP and PDF renderers, independent
 * of the exact RPC response shape.
 */
export interface RelatorioExportPayload {
  exportacaoId: string
  tipo: CategoriaRelatorioExportavel
  formato: FormatoExportacao
  periodo: PeriodoExportacao
  solicitante: SolicitanteExportacao
  resumo: Record<string, unknown>[]
  detalhes: Record<string, unknown>[]
  mensagemSemDados: string | null
  geradoEm: string
}

/**
 * Type guard/validator for the categories exportable in feature 008.
 * `Personalizado` and any other value must be rejected with
 * `INVALID_CATEGORY` by the caller (see edge-function-exportacao.md).
 */
export function isCategoriaExportavel(
  tipo: string,
): tipo is CategoriaRelatorioExportavel {
  return (
    tipo === 'Financeiro' ||
    tipo === 'DRE' ||
    tipo === 'Clientes' ||
    tipo === 'Projetos'
  )
}

/**
 * Builds the normalized export payload from the raw RPC result returned by
 * `iniciar_exportacao_relatorio`.
 *
 * The RPC already performs all category/format/period validation and
 * returns `resumo`/`detalhes` as plain arrays of objects (see
 * contracts/rpc-exportacao-relatorios.md "Return Shape"), so this is mostly
 * a type-narrowing/defaulting step. `geradoEm` is not part of the RPC return
 * (it is only set later, in `concluir_exportacao_relatorio`), so the caller
 * (index.ts) passes the timestamp captured right after `iniciar_exportacao_relatorio`
 * resolves — used for display in the rendered file only.
 */
export function buildRelatorioExportPayload(
  raw: IniciarExportacaoResult,
  geradoEm: string,
): RelatorioExportPayload {
  if (!isCategoriaExportavel(raw.tipo)) {
    throw new Error(`Categoria de relatorio inesperada retornada pela RPC: ${raw.tipo}`)
  }

  return {
    exportacaoId: raw.exportacao_id,
    tipo: raw.tipo,
    formato: raw.formato,
    periodo: raw.periodo,
    solicitante: raw.solicitante,
    resumo: (raw.resumo ?? []) as Record<string, unknown>[],
    detalhes: (raw.detalhes ?? []) as Record<string, unknown>[],
    mensagemSemDados: raw.mensagem_sem_dados ?? null,
    geradoEm,
  }
}

/**
 * Builds the download filename following the convention documented in
 * contracts/storage-and-retention.md:
 * `relatorio-<tipo>-<data_inicial>-<data_final>-<short_id>.<pdf|zip>`.
 *
 * `tipo` is lowercased to match the documented examples
 * (`relatorio-financeiro-...`, `relatorio-projetos-...`). `short_id` is the
 * first 6 hex characters of `exportacaoId` with dashes removed, matching the
 * `-ab12cd` / `-6e6d3f` examples in the contract.
 */
export function buildArquivoNome(
  payload: RelatorioExportPayload,
): string {
  const tipoSlug = payload.tipo.toLowerCase()
  const shortId = payload.exportacaoId.replace(/-/g, '').slice(0, 6)
  const extensao = payload.formato === 'PDF' ? 'pdf' : 'zip'
  return `relatorio-${tipoSlug}-${payload.periodo.data_inicial}-${payload.periodo.data_final}-${shortId}.${extensao}`
}

/**
 * Builds the private Storage object path following the convention documented
 * in contracts/storage-and-retention.md: `<tipo>/<yyyy>/<exportacao_id>/<arquivo_nome>`.
 *
 * `<yyyy>` is derived from the generation timestamp (`geradoEm`), not from
 * the report period, so that objects are bucketed by when they were created
 * (consistent with the 12-month retention window counted from `gerado_em`)
 * rather than by the (arbitrary, user-chosen) report period.
 */
export function buildArquivoPath(
  payload: RelatorioExportPayload,
  arquivoNome: string,
): string {
  const tipoSlug = payload.tipo.toLowerCase()
  const ano = payload.geradoEm.slice(0, 4)
  return `${tipoSlug}/${ano}/${payload.exportacaoId}/${arquivoNome}`
}
