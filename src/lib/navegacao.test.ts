import { describe, it, expect } from 'vitest'
import { ITENS_NAV, filtrarNavPorPermissoes } from './navegacao'
import type { PermissaoModulo } from '../types/auth'

describe('ITENS_NAV', () => {
  it('contém os 12 itens da sidebar do dashboard.html', () => {
    expect(ITENS_NAV.map((i) => i.modulo)).toEqual([
      'dashboard', 'fluxo-caixa', 'contas-pagar', 'contas-receber',
      'clientes', 'propostas', 'contratos', 'cobrancas',
      'projetos', 'equipe', 'relatorios', 'configuracoes',
    ])
  })
})

describe('filtrarNavPorPermissoes', () => {
  it('mantém apenas itens com pode_ler = true', () => {
    const permissoes: PermissaoModulo[] = [
      { modulo: 'dashboard', pode_ler: true, pode_escrever: true },
      { modulo: 'clientes', pode_ler: false, pode_escrever: false },
      { modulo: 'projetos', pode_ler: true, pode_escrever: true },
    ]
    const filtrados = filtrarNavPorPermissoes(ITENS_NAV, permissoes).map((i) => i.modulo)
    expect(filtrados).toContain('dashboard')
    expect(filtrados).toContain('projetos')
    expect(filtrados).not.toContain('clientes')
  })
  it('oculta itens sem permissão correspondente', () => {
    const filtrados = filtrarNavPorPermissoes(ITENS_NAV, [])
    expect(filtrados).toHaveLength(0)
  })
})
