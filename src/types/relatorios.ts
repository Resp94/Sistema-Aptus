import type { StatusExportacao } from './common'

export interface ExportacaoRelatorioItem {
  id: string
  tipo: string
  formato: 'PDF' | 'CSV'
  status: StatusExportacao
  arquivo_url: string | null
  gerado_em: string
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
