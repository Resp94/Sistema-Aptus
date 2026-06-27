import { describe, it, expect } from 'vitest'
import { obterIniciais, saudacaoPorHora, rotaInicialPorPerfil } from './usuario'

describe('obterIniciais', () => {
  it('retorna as iniciais de nome e sobrenome em maiúsculas', () => {
    expect(obterIniciais('Ana Martins')).toBe('AM')
  })
  it('usa apenas a primeira letra quando há um único nome', () => {
    expect(obterIniciais('Ana')).toBe('A')
  })
  it('ignora espaços extras', () => {
    expect(obterIniciais('  Ana   Martins  ')).toBe('AM')
  })
})

describe('saudacaoPorHora', () => {
  it('Bom dia antes do meio-dia', () => {
    expect(saudacaoPorHora(9)).toBe('Bom dia')
  })
  it('Boa tarde entre 12 e 17', () => {
    expect(saudacaoPorHora(15)).toBe('Boa tarde')
  })
  it('Boa tarde exatamente ao meio-dia (limite)', () => {
    expect(saudacaoPorHora(12)).toBe('Boa tarde')
  })
  it('Boa noite a partir das 18', () => {
    expect(saudacaoPorHora(20)).toBe('Boa noite')
  })
  it('Boa noite exatamente às 18 (limite)', () => {
    expect(saudacaoPorHora(18)).toBe('Boa noite')
  })
})

describe('rotaInicialPorPerfil', () => {
  it('Administrador vai para /dashboard', () => {
    expect(rotaInicialPorPerfil('Administrador')).toBe('/dashboard')
  })
  it('Projetos vai para /projetos', () => {
    expect(rotaInicialPorPerfil('Projetos')).toBe('/projetos')
  })
  it('Financeiro vai para /dashboard', () => {
    expect(rotaInicialPorPerfil('Financeiro')).toBe('/dashboard')
  })
  it('Técnico vai para /projetos', () => {
    expect(rotaInicialPorPerfil('Técnico')).toBe('/projetos')
  })
  it('Comercial vai para /clientes', () => {
    expect(rotaInicialPorPerfil('Comercial')).toBe('/clientes')
  })
  it('Visualizador (default) vai para /dashboard', () => {
    expect(rotaInicialPorPerfil('Visualizador')).toBe('/dashboard')
  })
})
