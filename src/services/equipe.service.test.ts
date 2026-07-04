import { describe, it, expect, afterEach } from 'vitest'
import { equipeService } from './equipe.service'
import { mockSupabaseRpc, restaurarMocksRpc } from './rpc-test-utils'

describe('equipeService.registrarApontamentoHoras (Mocked RPCs)', () => {
  afterEach(() => {
    restaurarMocksRpc()
  })

  it('deve normalizar a seleção "geral" (sem tarefa) para tarefa_id: null antes de chamar a RPC', async () => {
    const mockId = 'uuid-apontamento'
    const mockRpc = mockSupabaseRpc('registrar_apontamento_horas', mockId)

    const res = await equipeService.registrarApontamentoHoras({
      tarefa_id: 'geral',
      projeto_id: 'projeto-1',
      membro_equipe_id: 'membro-1',
      horas: 2,
      descricao: 'Atividade geral do projeto',
      data: '2026-07-03'
    })

    expect(mockRpc).toHaveBeenCalledWith('registrar_apontamento_horas', {
      payload: {
        tarefa_id: null,
        projeto_id: 'projeto-1',
        membro_equipe_id: 'membro-1',
        horas: 2,
        descricao: 'Atividade geral do projeto',
        data: '2026-07-03'
      }
    })
    expect(res).toBe(mockId)
  })

  it('nunca deve enviar a string "geral" como tarefa_id para a RPC', async () => {
    const mockRpc = mockSupabaseRpc('registrar_apontamento_horas', 'uuid-apontamento')

    await equipeService.registrarApontamentoHoras({
      tarefa_id: 'geral',
      projeto_id: 'projeto-1',
      membro_equipe_id: 'membro-1',
      horas: 1,
      descricao: 'Teste',
      data: '2026-07-03'
    })

    const chamada = mockRpc.mock.calls[0]
    expect(chamada[1]).toBeDefined()
    expect((chamada[1] as any).payload.tarefa_id).not.toBe('geral')
    expect((chamada[1] as any).payload.tarefa_id).toBeNull()
  })

  it('deve manter tarefa_id: null quando já vier nulo', async () => {
    const mockRpc = mockSupabaseRpc('registrar_apontamento_horas', 'uuid-apontamento')

    await equipeService.registrarApontamentoHoras({
      tarefa_id: null,
      projeto_id: 'projeto-1',
      membro_equipe_id: 'membro-1',
      horas: 1,
      descricao: 'Teste',
      data: '2026-07-03'
    })

    expect(mockRpc).toHaveBeenCalledWith('registrar_apontamento_horas', {
      payload: expect.objectContaining({ tarefa_id: null })
    })
  })

  it('deve preservar o tarefa_id quando uma tarefa real é selecionada', async () => {
    const mockRpc = mockSupabaseRpc('registrar_apontamento_horas', 'uuid-apontamento')

    await equipeService.registrarApontamentoHoras({
      tarefa_id: 'tarefa-real-123',
      projeto_id: 'projeto-1',
      membro_equipe_id: 'membro-1',
      horas: 3,
      descricao: 'Trabalho na tarefa',
      data: '2026-07-03'
    })

    expect(mockRpc).toHaveBeenCalledWith('registrar_apontamento_horas', {
      payload: expect.objectContaining({ tarefa_id: 'tarefa-real-123' })
    })
  })
})
