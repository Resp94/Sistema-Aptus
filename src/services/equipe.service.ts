import { supabase } from './supabase'
import type {
  MembroEquipeItem,
  AlocacaoEquipeItem,
  ApontamentoHorasItem,
  MetricasEquipe,
  CapacidadeEquipeItem
} from '../types/equipe'

export const equipeService = {
  async obterMetricasEquipe(): Promise<MetricasEquipe> {
    const { data, error } = await supabase.rpc('obter_metricas_equipe')

    if (error) {
      console.error('Erro ao obter métricas de equipe:', error)
      throw new Error(error.message || 'Erro ao obter indicadores da equipe.')
    }

    // Se vier como array, extrai o primeiro objeto (padrão de agregação RPC)
    return (Array.isArray(data) ? data[0] : data) as MetricasEquipe
  },

  async listarMembrosEquipe(
    status?: string,
    busca?: string
  ): Promise<MembroEquipeItem[]> {
    const { data, error } = await supabase.rpc('listar_membros_equipe', {
      p_status: status || null,
      p_busca: busca || null
    })

    if (error) {
      console.error('Erro ao listar membros da equipe:', error)
      throw new Error(error.message || 'Erro ao carregar membros da equipe.')
    }

    return (data || []) as MembroEquipeItem[]
  },

  async obterAlocacaoPorProjeto(membroId: string): Promise<AlocacaoEquipeItem[]> {
    const { data, error } = await supabase.rpc('obter_alocacao_por_projeto', {
      p_membro_id: membroId
    })

    if (error) {
      console.error('Erro ao obter alocações por projeto:', error)
      throw new Error(error.message || 'Erro ao obter alocações do membro.')
    }

    return (data || []) as AlocacaoEquipeItem[]
  },

  async obterCapacidadeEquipe(): Promise<CapacidadeEquipeItem[]> {
    const { data, error } = await supabase.rpc('obter_capacidade_equipe')

    if (error) {
      console.error('Erro ao obter capacidade da equipe:', error)
      throw new Error(error.message || 'Erro ao obter dados de capacidade.')
    }

    return (data || []) as CapacidadeEquipeItem[]
  },

  async listarApontamentosHoras(
    membroId?: string,
    projetoId?: string,
    inicio?: string,
    fim?: string
  ): Promise<ApontamentoHorasItem[]> {
    const { data, error } = await supabase.rpc('listar_apontamentos_horas', {
      p_membro_id: membroId || null,
      p_projeto_id: projetoId || null,
      p_data_inicio: inicio || null,
      p_data_fim: fim || null
    })

    if (error) {
      console.error('Erro ao listar apontamentos de horas:', error)
      throw new Error(error.message || 'Erro ao carregar apontamentos de horas.')
    }

    return (data || []) as ApontamentoHorasItem[]
  },

  async criarMembroEquipe(payload: {
    perfil_id?: string | null
    nome: string
    funcao: string
    habilidades: string[]
    status: string
    capacidade: number
    custo_hora?: number | null
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_membro_equipe', {
      payload
    })

    if (error) {
      console.error('Erro ao criar membro da equipe:', error)
      throw new Error(error.message || 'Erro ao criar perfil de membro.')
    }

    return data as string
  },

  async atualizarMembroEquipe(
    id: string,
    payload: Partial<{
      nome: string
      funcao: string
      habilidades: string[]
      status: string
      capacidade: number
      custo_hora: number | null
    }>
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_membro_equipe', {
      p_id: id,
      payload
    })

    if (error) {
      console.error('Erro ao atualizar membro da equipe:', error)
      throw new Error(error.message || 'Erro ao atualizar dados do membro.')
    }

    return !!data
  },

  async alocarMembroProjeto(payload: {
    membro_equipe_id: string
    projeto_id: string
    data_inicio: string
    data_fim: string
    percentual_alocacao: number
    funcao_no_projeto: string
  }): Promise<string> {
    const { data, error } = await supabase.rpc('alocar_membro_projeto', {
      payload
    })

    if (error) {
      console.error('Erro ao alocar membro em projeto:', error)
      throw new Error(error.message || 'Erro ao alocar membro.')
    }

    return data as string
  },

  async registrarApontamentoHoras(payload: {
    tarefa_id: string | null
    projeto_id: string
    membro_equipe_id: string
    horas: number
    descricao: string
    data: string
  }): Promise<string> {
    // Normaliza a seleção de "Atividade Geral do Projeto (Sem tarefa)" para
    // tarefa_id: null antes de chamar a RPC. A sentinela textual 'geral'
    // nunca deve ser enviada ao backend.
    const tarefaIdNormalizado =
      !payload.tarefa_id || payload.tarefa_id === 'geral' ? null : payload.tarefa_id

    const { data, error } = await supabase.rpc('registrar_apontamento_horas', {
      payload: {
        ...payload,
        tarefa_id: tarefaIdNormalizado
      }
    })

    if (error) {
      console.error('Erro ao registrar apontamento de horas:', error)
      throw new Error(error.message || 'Erro ao salvar apontamento de horas.')
    }

    return data as string
  },

  async inativarMembroEquipe(id: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('inativar_membro_equipe', {
      p_id: id
    })

    if (error) {
      console.error('Erro ao inativar membro da equipe:', error)
      throw new Error(error.message || 'Erro ao desativar membro.')
    }

    return !!data
  }
}
export type EquipeService = typeof equipeService
