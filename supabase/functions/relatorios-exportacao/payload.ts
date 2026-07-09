// Report export payload types/helpers for the `relatorios-exportacao`
// Edge Function.
//
// Contract: specs/011-padrao-enterprise-relatorios/contracts/download-sem-preview.md

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

export interface AutorizarDownloadResult {
  id: string
  arquivo_path: string
  arquivo_nome: string
  mime_type: string
  expira_em: string
}

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

export function buildArquivoNome(
  payload: RelatorioExportPayload,
): string {
  const tipoSlug = payload.tipo.toLowerCase()
  const combiningDiacriticalMarks = new RegExp('[̀-ͯ]', 'g')
  const slug = tipoSlug
    .normalize('NFD')
    .replace(combiningDiacriticalMarks, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-+|-+$)/g, '')

  const extensao = payload.formato === 'PDF' ? 'pdf' : 'zip'
  const prefixo = payload.formato === 'PDF' ? 'relatorio' : 'exportacao'

  return `${prefixo}-${slug}-${payload.periodo.data_inicial}-${payload.periodo.data_final}.${extensao}`
}

export function buildArquivoPath(
  payload: RelatorioExportPayload,
  arquivoNome: string,
): string {
  const tipoSlug = payload.tipo.toLowerCase()
  const ano = payload.geradoEm.slice(0, 4)
  return `${tipoSlug}/${ano}/${payload.exportacaoId}/${arquivoNome}`
}
