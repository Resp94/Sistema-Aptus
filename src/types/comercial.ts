import type { StatusProposta } from './common'

export interface PropostaItem {
  id: string
  titulo: string
  cliente: string
  valor: number
  status: StatusProposta
  enviada_em: string | null
}

export interface PropostaDetalhe {
  id: string
  cliente_id: string
  empresa: string
  nome_contato: string
  email: string | null
  telefone: string | null
  titulo: string
  descricao: string | null
  valor: number
  status: StatusProposta
  enviada_em: string | null
  criado_por_nome: string
  created_at: string
  documentos: Array<{
    id: string
    nome: string
    arquivo_url: string
    criado_em: string
  }>
}

export interface ContratoItem {
  id: string
  titulo: string
  cliente: string
  data_inicio: string
  data_fim: string
  valor_recorrente: number
  status_exibicao: string
}

export interface ContratoDetalhe {
  id: string
  cliente_id: string
  empresa: string
  nome_contato: string
  titulo: string
  proposta_id: string | null
  proposta_titulo: string | null
  data_inicio: string
  data_fim: string
  status_exibicao: string
  valor_recorrente: number
  created_by_nome: string
  created_at: string
  documentos: Array<{
    id: string
    nome: string
    arquivo_url: string
    criado_em: string
  }>
}

export interface CobrancaItem {
  id: string
  cliente: string
  contrato: string | null
  valor: number
  data_vencimento: string
  status_exibicao: string
}

export interface CobrancaDetalhe {
  id: string
  cliente_id: string
  empresa: string
  contrato_id: string | null
  contrato_titulo: string | null
  lancamento_id: string | null
  valor: number
  data_vencimento: string
  status_exibicao: string
  data_pagamento: string | null
  forma_pagamento: string | null
  created_by_nome: string
  created_at: string
}
