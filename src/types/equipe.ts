import type { StatusMembro } from './common'

export interface MembroEquipeItem {
  id: string
  perfil_id: string | null
  nome: string
  funcao: string
  habilidades: string[]
  status: StatusMembro
  capacidade: number
  custo_hora: number | null
}

export interface AlocacaoEquipeItem {
  id: string
  membro_equipe_id: string
  membro_nome: string
  projeto_id: string
  projeto_nome: string
  data_inicio: string
  data_fim: string
  percentual_alocacao: number
  funcao_no_projeto: string
}

export interface ApontamentoHorasItem {
  id: string
  membro_nome: string
  projeto_nome: string
  tarefa_titulo: string | null
  horas: number
  descricao: string
  data: string
}

export interface MetricasEquipe {
  total_membros: number
  membros_ativos: number
  capacidade_total: number
  custo_medio: number | null
}

export interface CapacidadeEquipeItem {
  membro_id: string
  membro_nome: string
  capacidade: number
  alocado: number
  disponivel: number
}
