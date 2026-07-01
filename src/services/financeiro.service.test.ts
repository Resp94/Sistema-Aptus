import { describe, it, expect, afterEach } from 'vitest'
import { financeiroService } from './financeiro.service'
import { mockSupabaseRpc, restaurarMocksRpc } from './rpc-test-utils'

describe('financeiroService Unit Tests (Mocked RPCs)', () => {
  afterEach(() => {
    restaurarMocksRpc()
  })

  it('obterResumoFluxoCaixa deve chamar a RPC obter_resumo_fluxo_caixa', async () => {
    const mockData = {
      saldo_inicial: 1000,
      entradas: 500,
      saidas: 200,
      saldo_final_projetado: 1300
    }
    const mockRpc = mockSupabaseRpc('obter_resumo_fluxo_caixa', mockData)

    const res = await financeiroService.obterResumoFluxoCaixa('2026-06-01', '2026-06-30')
    
    expect(mockRpc).toHaveBeenCalledWith('obter_resumo_fluxo_caixa', {
      p_data_inicio: '2026-06-01',
      p_data_fim: '2026-06-30'
    })
    expect(res).toEqual(mockData)
  })

  it('listarFluxoCaixa deve chamar a RPC listar_fluxo_caixa', async () => {
    const mockList = [
      { id: '1', descricao: 'Teste', valor: 100, tipo: 'receita', status_exibicao: 'Pago' }
    ]
    const mockRpc = mockSupabaseRpc('listar_fluxo_caixa', mockList)

    const res = await financeiroService.listarFluxoCaixa('2026-06-01', '2026-06-30', 'Projetos', 'busca')

    expect(mockRpc).toHaveBeenCalledWith('listar_fluxo_caixa', {
      p_data_inicio: '2026-06-01',
      p_data_fim: '2026-06-30',
      p_categoria: 'Projetos',
      p_busca: 'busca'
    })
    expect(res).toEqual(mockList)
  })

  it('listarContasPagar deve chamar a RPC listar_contas_pagar', async () => {
    const mockList = [
      { id: '1', descricao: 'Despesa', valor: 200, status_exibicao: 'Vencido' }
    ]
    const mockRpc = mockSupabaseRpc('listar_contas_pagar', mockList)

    const res = await financeiroService.listarContasPagar('Vencido', 'Fornecedor X', '2026-06-01', '2026-06-30')

    expect(mockRpc).toHaveBeenCalledWith('listar_contas_pagar', {
      p_status: 'Vencido',
      p_fornecedor: 'Fornecedor X',
      p_data_inicio: '2026-06-01',
      p_data_fim: '2026-06-30'
    })
    expect(res).toEqual(mockList)
  })

  it('criarLancamento deve chamar a RPC criar_lancamento_financeiro', async () => {
    const mockId = 'uuid-novo-lancamento'
    const mockRpc = mockSupabaseRpc('criar_lancamento_financeiro', mockId)
    const payload = {
      tipo: 'despesa' as const,
      natureza: 'a_pagar' as const,
      descricao: 'Aluguel',
      valor: 1500,
      categoria: 'Infra'
    }

    const res = await financeiroService.criarLancamento(payload)

    expect(mockRpc).toHaveBeenCalledWith('criar_lancamento_financeiro', {
      payload
    })
    expect(res).toBe(mockId)
  })

  it('registrarPagamentoLancamento deve chamar a RPC registrar_pagamento_lancamento', async () => {
    const mockRpc = mockSupabaseRpc('registrar_pagamento_lancamento', true)

    const res = await financeiroService.registrarPagamentoLancamento('id-lanc', '2026-06-25', 1500)

    expect(mockRpc).toHaveBeenCalledWith('registrar_pagamento_lancamento', {
      p_id: 'id-lanc',
      p_data_pagamento: '2026-06-25',
      p_valor: 1500
    })
    expect(res).toBe(true)
  })
})
