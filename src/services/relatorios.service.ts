import { supabase } from './supabase'
import type { ExportacaoRelatorioItem } from '../types/relatorios'

export const relatoriosService = {
  async listarCategoriasRelatorios(): Promise<string[]> {
    const { data, error } = await supabase.rpc('listar_categorias_relatorios')

    if (error) {
      console.error('Erro ao listar categorias de relatórios:', error)
      throw new Error(error.message || 'Erro ao carregar categorias de relatórios.')
    }

    // A RPC retorna uma tabela com coluna "categoria"
    return (data || []).map((row: any) => row.categoria as string)
  },

  async gerarPreviaRelatorio(tipo: string, filtros: any = {}): Promise<any> {
    const { data, error } = await supabase.rpc('gerar_previa_relatorio', {
      p_tipo: tipo,
      p_filtros: filtros
    })

    if (error) {
      console.error('Erro ao gerar prévia do relatório:', error)
      throw new Error(error.message || 'Erro ao obter pré-visualização.')
    }

    return data
  },

  async listarExportacoesRelatorios(tipo?: string): Promise<ExportacaoRelatorioItem[]> {
    const { data, error } = await supabase.rpc('listar_exportacoes_relatorios', {
      p_tipo: tipo || null
    })

    if (error) {
      console.error('Erro ao listar histórico de exportações:', error)
      throw new Error(error.message || 'Erro ao obter histórico de exportações.')
    }

    return (data || []) as ExportacaoRelatorioItem[]
  },

  async solicitarExportacaoRelatorio(
    tipo: string,
    formato: 'PDF' | 'CSV',
    filtros: any = {}
  ): Promise<string> {
    const { data, error } = await supabase.rpc('solicitar_exportacao_relatorio', {
      p_tipo: tipo,
      p_formato: formato,
      p_filtros: filtros
    })

    if (error) {
      console.error('Erro ao solicitar exportação de relatório:', error)
      throw new Error(error.message || 'Erro ao solicitar exportação.')
    }

    return data as string
  },

  async agendarRelatorio(payload: {
    tipo: string
    formato: 'PDF' | 'CSV'
    filtros: any
    frequencia: 'Uma vez' | 'Diário' | 'Semanal' | 'Mensal'
    agendado_para?: string | null
  }): Promise<string> {
    const { data, error } = await supabase.rpc('agendar_relatorio', {
      payload
    })

    if (error) {
      console.error('Erro ao agendar relatório:', error)
      throw new Error(error.message || 'Erro ao agendar relatório.')
    }

    return data as string
  }
}
export type RelatoriosService = typeof relatoriosService
