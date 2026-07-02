import { supabase } from './supabase'
import type {
  PropostaItem,
  PropostaDetalhe,
  ContratoItem,
  ContratoDetalhe,
  CobrancaItem,
  CobrancaDetalhe
} from '../types/comercial'

export const comercialService = {
  // --- PROPOSTAS ---
  async listarPropostas(
    status?: string,
    clienteId?: string,
    busca?: string
  ): Promise<PropostaItem[]> {
    const { data, error } = await supabase.rpc('listar_propostas', {
      p_status: status || null,
      p_cliente_id: clienteId || null,
      p_busca: busca || null
    })

    if (error) {
      console.error('Erro ao listar propostas:', error)
      throw new Error(error.message || 'Erro ao carregar propostas.')
    }

    return (data || []) as PropostaItem[]
  },

  async obterPropostaDetalhe(propostaId: string): Promise<PropostaDetalhe> {
    const { data, error } = await supabase.rpc('obter_proposta_detalhe', {
      p_proposta_id: propostaId
    })

    if (error) {
      console.error('Erro ao obter detalhes da proposta:', error)
      throw new Error(error.message || 'Erro ao carregar detalhes da proposta.')
    }

    return data as PropostaDetalhe
  },

  async criarProposta(payload: {
    cliente_id: string
    titulo: string
    descricao?: string | null
    valor: number
    status: string
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_proposta', {
      payload
    })

    if (error) {
      console.error('Erro ao criar proposta:', error)
      throw new Error(error.message || 'Erro ao criar proposta comercial.')
    }

    return data as string
  },

  async atualizarProposta(
    id: string,
    payload: Partial<{
      titulo: string
      descricao: string | null
      valor: number
      status: string
    }>
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_proposta', {
      p_id: id,
      payload
    })

    if (error) {
      console.error('Erro ao atualizar proposta:', error)
      throw new Error(error.message || 'Erro ao atualizar proposta comercial.')
    }

    return !!data
  },

  async registrarEnvioProposta(id: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('registrar_envio_proposta', {
      p_id: id
    })

    if (error) {
      console.error('Erro ao enviar proposta:', error)
      throw new Error(error.message || 'Erro ao processar envio da proposta.')
    }

    return !!data
  },

  // --- CONTRATOS ---
  async listarContratos(
    status?: string,
    clienteId?: string,
    busca?: string
  ): Promise<ContratoItem[]> {
    const { data, error } = await supabase.rpc('listar_contratos', {
      p_status: status || null,
      p_cliente_id: clienteId || null,
      p_busca: busca || null
    })

    if (error) {
      console.error('Erro ao listar contratos:', error)
      throw new Error(error.message || 'Erro ao carregar contratos.')
    }

    return (data || []) as ContratoItem[]
  },

  async obterContratoDetalhe(contratoId: string): Promise<ContratoDetalhe> {
    const { data, error } = await supabase.rpc('obter_contrato_detalhe', {
      p_contrato_id: contratoId
    })

    if (error) {
      console.error('Erro ao obter detalhes do contrato:', error)
      throw new Error(error.message || 'Erro ao carregar detalhes do contrato.')
    }

    return data as ContratoDetalhe
  },

  async criarContrato(payload: {
    cliente_id: string
    proposta_id?: string | null
    titulo: string
    data_inicio: string
    data_fim: string
    valor_recorrente: number
    status: string
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_contrato', {
      payload
    })

    if (error) {
      console.error('Erro ao criar contrato:', error)
      throw new Error(error.message || 'Erro ao criar contrato de serviços.')
    }

    return data as string
  },

  async renovarContrato(
    id: string,
    novaDataFim: string,
    novoValor?: number
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('renovar_contrato', {
      p_id: id,
      p_nova_data_fim: novaDataFim,
      p_novo_valor: novoValor || null
    })

    if (error) {
      console.error('Erro ao renovar contrato:', error)
      throw new Error(error.message || 'Erro ao renovar contrato.')
    }

    return !!data
  },

  async encerrarContrato(id: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('encerrar_contrato', {
      p_id: id
    })

    if (error) {
      console.error('Erro ao encerrar contrato:', error)
      throw new Error(error.message || 'Erro ao encerrar contrato.')
    }

    return !!data
  },

  // --- COBRANÇAS ---
  async listarCobrancas(
    status?: string,
    clienteId?: string,
    dataInicio?: string,
    dataFim?: string
  ): Promise<CobrancaItem[]> {
    const { data, error } = await supabase.rpc('listar_cobrancas', {
      p_status: status || null,
      p_cliente_id: clienteId || null,
      p_data_inicio: dataInicio || null,
      p_data_fim: dataFim || null
    })

    if (error) {
      console.error('Erro ao listar cobranças:', error)
      throw new Error(error.message || 'Erro ao carregar cobranças.')
    }

    return (data || []) as CobrancaItem[]
  },

  async obterCobrancaDetalhe(cobrancaId: string): Promise<CobrancaDetalhe> {
    const { data, error } = await supabase.rpc('obter_cobranca_detalhe', {
      p_cobranca_id: cobrancaId
    })

    if (error) {
      console.error('Erro ao obter detalhes da cobrança:', error)
      throw new Error(error.message || 'Erro ao carregar detalhes da cobrança.')
    }

    return data as CobrancaDetalhe
  },

  async criarCobranca(payload: {
    cliente_id: string
    contrato_id?: string | null
    valor: number
    data_vencimento: string
    criar_lancamento_financeiro?: boolean
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_cobranca', {
      payload
    })

    if (error) {
      console.error('Erro ao criar cobrança:', error)
      throw new Error(error.message || 'Erro ao criar cobrança.')
    }

    return data as string
  },

  async registrarPagamentoCobranca(
    id: string,
    pagoEm: string,
    valor: number,
    formaPagamento: string
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('registrar_pagamento_cobranca', {
      p_id: id,
      p_pago_em: pagoEm,
      p_valor: valor,
      p_forma_pagamento: formaPagamento
    })

    if (error) {
      console.error('Erro ao registrar pagamento de cobrança:', error)
      throw new Error(error.message || 'Erro ao registrar recebimento de cobrança.')
    }

    return !!data
  },

  async solicitarEmissaoBoleto(id: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('solicitar_emissao_boleto', {
      p_id: id
    })

    if (error) {
      console.error('Erro ao solicitar boleto:', error)
      throw new Error(error.message || 'Erro ao emitir boleto.')
    }

    return !!data
  },

  async solicitarLembreteCobranca(id: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('solicitar_lembrete_cobranca', {
      p_id: id
    })

    if (error) {
      console.error('Erro ao solicitar lembrete:', error)
      throw new Error(error.message || 'Erro ao enviar lembrete de cobrança.')
    }

    return !!data
  }
}
export type ComercialService = typeof comercialService
