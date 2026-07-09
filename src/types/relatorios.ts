import type { StatusExportacao } from './common'

export type FormatoRelatorio = 'PDF' | 'CSV'
export type FormatoEntregaRelatorio = 'PDF' | 'ZIP_CSV'
export type TipoArtefatoRelatorio = 'EXECUTIVO' | 'OPERACIONAL'

/**
 * Item retornado por `listar_exportacoes_relatorios` (histórico de exportações).
 * `status` é o status armazenado; `status_exibicao` é o status computado para a UI
 * (inclui `Expirado`, que nunca é persistido, apenas calculado na leitura).
 */
export interface ExportacaoRelatorioItem {
  id: string
  tipo: string
  formato: FormatoRelatorio
  formato_entrega: FormatoEntregaRelatorio
  status: StatusExportacao
  status_exibicao: StatusExportacao
  data_inicial: string
  data_final: string
  /** @deprecated Mantido apenas para compatibilidade com registros legados `Indisponível`. */
  arquivo_url: string | null
  arquivo_nome: string | null
  mime_type: string | null
  tamanho_bytes: number | null
  criado_por: string
  criado_por_nome: string | null
  gerado_em: string | null
  expira_em: string | null
  pode_baixar: boolean
  erro: string | null
}

export interface AgendamentoRelatorioItem {
  id: string
  tipo: string
  formato: 'PDF' | 'CSV'
  filtros: any
  frequencia: 'Uma vez' | 'Diário' | 'Semanal' | 'Mensal'
  agendado_para: string | null
  status: 'Ativo' | 'Inativo'
}

// --- Edge Function `relatorios-exportacao` ---

export type AcaoExportacaoRelatorio = 'gerar' | 'download'

/** Payload aceito pelo serviço `relatoriosService.exportarRelatorio`. */
export interface ExportarRelatorioInput {
  tipo: string
  formato: FormatoRelatorio
  data_inicial: string
  data_final: string
}

/** Payload aceito pelo serviço `relatoriosService.baixarExportacaoRelatorio`. */
export interface BaixarExportacaoInput {
  exportacao_id: string
}

/** Corpo enviado para a Edge Function `relatorios-exportacao` na ação `gerar`. */
export interface GerarExportacaoRelatorioRequest extends ExportarRelatorioInput {
  action: 'gerar'
}

/** Corpo enviado para a Edge Function `relatorios-exportacao` na ação `download`. */
export interface BaixarExportacaoRelatorioRequest extends BaixarExportacaoInput {
  action: 'download'
}

export type ExportacaoRelatorioRequest =
  | GerarExportacaoRelatorioRequest
  | BaixarExportacaoRelatorioRequest

/** Metadados da exportação retornados pela Edge Function (ações `gerar` e `download`). */
export interface ExportacaoRelatorioMetadata {
  id: string
  tipo?: string
  formato?: FormatoRelatorio
  formato_entrega?: FormatoEntregaRelatorio
  status_exibicao?: StatusExportacao
  data_inicial?: string
  data_final?: string
  arquivo_nome: string
  mime_type: string
  gerado_em?: string
  expira_em: string
}

/** Resposta de sucesso da Edge Function `relatorios-exportacao` (ações `gerar` e `download`). */
export interface ExportacaoRelatorioResponse {
  exportacao: ExportacaoRelatorioMetadata
  download_url: string
  download_expires_in: number
}

export type ErroExportacaoRelatorioCodigo =
  | 'INVALID_PERIOD'
  | 'PERIOD_TOO_LONG'
  | 'INVALID_FORMAT'
  | 'INVALID_CATEGORY'
  | 'PERMISSION_DENIED'
  | 'EXPORT_NOT_FOUND'
  | 'EXPORT_EXPIRED'
  | 'EXPORT_NOT_READY'
  | 'GENERATION_FAILED'
  | 'STORAGE_FAILED'
  | 'EXPORT_TOO_LARGE'

/** Corpo de erro retornado pela Edge Function `relatorios-exportacao`. */
export interface ExportacaoRelatorioErro {
  error: {
    code: ErroExportacaoRelatorioCodigo | string
    message: string
  }
}
