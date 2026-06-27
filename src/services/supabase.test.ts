import { describe, it, expect } from 'vitest'
import { checkSupabaseHealth } from './health-check'
import { supabase } from './supabase'

describe('Supabase Client Smoke Test', () => {
  it('deve conseguir instanciar o cliente Supabase', () => {
    expect(supabase).toBeDefined()
    expect(supabase.auth).toBeDefined()
  })

  it('deve conseguir validar a saude da conexao local REST com o Supabase', async () => {
    const result = await checkSupabaseHealth()
    console.log('Status do Health Check:', result)
    expect(result.healthy).toBe(true)
  })
})
