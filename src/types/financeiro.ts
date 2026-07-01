
export interface FluxoCaixaItem {
  id: string
  tipo: 'receita' | 'despesa'
  natureza: 'a_receber' | 'a_pagar' | 'realizado'
  descricao: string
  valor: number
  categoria: string
  cliente: string
  data_competencia: string
  data_vencimento: string | null
  status_exibicao: string
}

export interface ResumoFluxoCaixa {
  saldo_inicial: number
  entradas: number
  saidas: number
  saldo_final_projetado: number
}

export interface FluxoCaixaSerie {
  periodo: string
  receitas: number
  despesas: number
  saldo: number
}

export interface ContaPagarItem {
  id: string
  descricao: string
  fornecedor: string
  data_vencimento: string
  categoria: string
  valor: number
  status_exibicao: string
}

export interface ContaReceberItem {
  id: string
  descricao: string
  cliente: string
  cliente_id: string
  data_competencia: string
  data_vencimento: string
  valor: number
  status_exibicao: string
}

export interface MetricasContas {
  total_valor: number
  total_qtd: number
  vencidas_valor: number
  vencidas_qtd: number
  vencem_hoje_valor: number
  vencem_hoje_qtd: number
  proximos_7_dias_valor: number
  proximos_7_dias_qtd: number
}
