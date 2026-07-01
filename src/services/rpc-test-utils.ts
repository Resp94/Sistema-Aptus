import { vi } from 'vitest'
import { supabase } from './supabase'

/**
 * Helper para mockar chamadas do supabase.rpc nos testes unitários.
 * Permite interceptar as chamadas para funções RPC específicas e simular retornos de sucesso ou de erro.
 */
export function mockSupabaseRpc(
  fnName: string,
  resolvedValue: any,
  errorValue: any = null
) {
  // Cria um spy/mock na chamada do rpc do supabase
  const mockRpc = vi.spyOn(supabase, 'rpc')
  
  if (errorValue) {
    mockRpc.mockImplementation((name: string) => {
      if (name === fnName) {
        return Promise.resolve({ data: null, error: errorValue }) as any
      }
      return Promise.resolve({ data: null, error: { message: 'Função RPC não mockada' } }) as any
    })
  } else {
    mockRpc.mockImplementation((name: string) => {
      if (name === fnName) {
        return Promise.resolve({ data: resolvedValue, error: null }) as any
      }
      return Promise.resolve({ data: null, error: { message: 'Função RPC não mockada' } }) as any
    })
  }

  return mockRpc;
}

/**
 * Limpa todos os mocks de RPC criados
 */
export function restaurarMocksRpc() {
  vi.restoreAllMocks()
}
