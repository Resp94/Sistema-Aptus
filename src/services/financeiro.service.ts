import { supabase } from './supabase'
import type { 
  ResumoFluxoCaixa, 
  FluxoCaixaItem, 
  FluxoCaixaSerie, 
  ContaPagarItem, 
  ContaReceberItem, 
  MetricasContas 
} from '../types/financeiro'

export const financeiroService = {
  async obterResumoFluxoCaixa(inicio: string, fim: string): Promise<ResumoFluxoCaixa> {
    const { data, error } = await supabase.rpc('obter_resumo_fluxo_caixa', {
      p_data_inicio: inicio,
      p_data_fim: fim
    })

    if (error) {
      console.error('Erro ao obter resumo do fluxo de caixa:', error)
      throw new Error(error.message || 'Erro ao carregar resumo do fluxo de caixa.')
    }

    return data as ResumoFluxoCaixa
  },

  async listarFluxoCaixa(
    inicio: string, 
    fim: string, 
    categoria?: string, 
    busca?: string
  ): Promise<FluxoCaixaItem[]> {
    const { data, error } = await supabase.rpc('listar_fluxo_caixa', {
      p_data_inicio: inicio,
      p_data_fim: fim,
      p_categoria: categoria || null,
      p_busca: busca || null
    })

    if (error) {
      console.error('Erro ao listar fluxo de caixa:', error)
      throw new Error(error.message || 'Erro ao carregar lançamentos do fluxo de caixa.')
    }

    return (data || []) as FluxoCaixaItem[]
  },

  async obterFluxoCaixaSeries(inicio: string, fim: string): Promise<FluxoCaixaSerie[]> {
    const { data, error } = await supabase.rpc('obter_fluxo_caixa_series', {
      p_data_inicio: inicio,
      p_data_fim: fim
    })

    if (error) {
      console.error('Erro ao obter séries do fluxo de caixa:', error)
      throw new Error(error.message || 'Erro ao carregar dados do gráfico.')
    }

    return (data || []) as FluxoCaixaSerie[]
  },

  async listarContasPagar(
    status?: string, 
    fornecedor?: string, 
    inicio?: string, 
    fim?: string
  ): Promise<ContaPagarItem[]> {
    const { data, error } = await supabase.rpc('listar_contas_pagar', {
      p_status: status || null,
      p_fornecedor: fornecedor || null,
      p_data_inicio: inicio || null,
      p_data_fim: fim || null
    })

    if (error) {
      console.error('Erro ao listar contas a pagar:', error)
      throw new Error(error.message || 'Erro ao carregar contas a pagar.')
    }

    return (data || []) as ContaPagarItem[]
  },

  async listarContasReceber(
    status?: string, 
    clienteId?: string, 
    inicio?: string, 
    fim?: string
  ): Promise<ContaReceberItem[]> {
    const { data, error } = await supabase.rpc('listar_contas_receber', {
      p_status: status || null,
      p_cliente_id: clienteId || null,
      p_data_inicio: inicio || null,
      p_data_fim: fim || null
    })

    if (error) {
      console.error('Erro ao listar contas a receber:', error)
      throw new Error(error.message || 'Erro ao carregar contas a receber.')
    }

    return (data || []) as ContaReceberItem[]
  },

  async obterMetricasContas(
    natureza: 'a_pagar' | 'a_receber', 
    inicio?: string, 
    fim?: string
  ): Promise<MetricasContas> {
    const { data, error } = await supabase.rpc('obter_metricas_contas', {
      p_natureza: natureza,
      p_data_inicio: inicio || null,
      p_data_fim: fim || null
    })

    if (error) {
      console.error(`Erro ao obter métricas de contas (${natureza}):`, error)
      throw new Error(error.message || 'Erro ao carregar indicadores.')
    }

    return data as MetricasContas
  },

  async criarLancamento(payload: {
    tipo: 'receita' | 'despesa'
    natureza: 'realizado' | 'a_pagar' | 'a_receber'
    descricao: string
    valor: number
    categoria: string
    cliente_id?: string | null
    data_competencia?: string
    data_vencimento?: string | null
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_lancamento_financeiro', {
      payload
    })

    if (error) {
      console.error('Erro ao criar lançamento:', error)
      throw new Error(error.message || 'Erro ao criar lançamento financeiro.')
    }

    return data as string
  },

  async atualizarLancamento(
    id: string, 
    payload: Partial<{
      tipo: 'receita' | 'despesa'
      natureza: 'realizado' | 'a_pagar' | 'a_receber'
      descricao: string
      valor: number
      categoria: string
      cliente_id?: string | null
      data_competencia?: string
      data_vencimento?: string | null
      status?: 'Pendente' | 'Pago' | 'Vencido'
    }>
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_lancamento_financeiro', {
      p_id: id,
      payload
    })

    if (error) {
      console.error('Erro ao atualizar lançamento:', error)
      throw new Error(error.message || 'Erro ao atualizar lançamento financeiro.')
    }

    return !!data
  },

  async registrarPagamentoLancamento(
    id: string, 
    dataPagamento: string, 
    valor: number
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('registrar_pagamento_lancamento', {
      p_id: id,
      p_data_pagamento: dataPagamento,
      p_valor: valor
    })

    if (error) {
      console.error('Erro ao registrar pagamento do lançamento:', error)
      throw new Error(error.message || 'Erro ao registrar pagamento do lançamento.')
    }

    return !!data
  }
}
