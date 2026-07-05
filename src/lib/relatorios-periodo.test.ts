import { describe, it, expect } from 'vitest'
import { obterPeriodoPadrao, validarPeriodoExportacao } from './relatorios-periodo'

describe('validarPeriodoExportacao', () => {
  it('permite período de um único dia (data_inicial = data_final)', () => {
    const resultado = validarPeriodoExportacao('2026-07-04', '2026-07-04')
    expect(resultado.valido).toBe(true)
    expect(resultado.codigo).toBeUndefined()
  })

  it('permite intervalo de exatamente 12 meses calendário (ano completo)', () => {
    const resultado = validarPeriodoExportacao('2026-01-01', '2026-12-31')
    expect(resultado.valido).toBe(true)
  })

  it('bloqueia intervalo um dia maior que 12 meses', () => {
    const resultado = validarPeriodoExportacao('2026-01-01', '2027-01-01')
    expect(resultado.valido).toBe(false)
    expect(resultado.codigo).toBe('PERIODO_MAIOR_QUE_12_MESES')
    expect(resultado.mensagem).toBe('Periodo maior que 12 meses.')
  })

  it('bloqueia quando a data final é anterior à data inicial (ordem invertida)', () => {
    const resultado = validarPeriodoExportacao('2026-07-31', '2026-07-01')
    expect(resultado.valido).toBe(false)
    expect(resultado.codigo).toBe('PERIODO_INVALIDO')
    expect(resultado.mensagem).toBe('Periodo invalido.')
  })

  it('bloqueia datas em formato inválido', () => {
    const resultado = validarPeriodoExportacao('04/07/2026', '2026-07-04')
    expect(resultado.valido).toBe(false)
    expect(resultado.codigo).toBe('PERIODO_INVALIDO')
  })

  it('bloqueia datas de calendário inexistentes', () => {
    const resultado = validarPeriodoExportacao('2026-02-30', '2026-03-01')
    expect(resultado.valido).toBe(false)
    expect(resultado.codigo).toBe('PERIODO_INVALIDO')
  })
})

describe('obterPeriodoPadrao', () => {
  it('retorna o primeiro dia do mês corrente até a data atual', () => {
    const referencia = new Date(2026, 6, 15) // 15 de julho de 2026 (mês local, 0-indexado)
    const periodo = obterPeriodoPadrao(referencia)

    expect(periodo.data_inicial).toBe('2026-07-01')
    expect(periodo.data_final).toBe('2026-07-15')
  })

  it('retorna um período sempre válido segundo as regras de validação', () => {
    const referencia = new Date(2026, 11, 31) // 31 de dezembro de 2026
    const periodo = obterPeriodoPadrao(referencia)

    expect(periodo.data_inicial).toBe('2026-12-01')
    expect(periodo.data_final).toBe('2026-12-31')

    const resultado = validarPeriodoExportacao(periodo.data_inicial, periodo.data_final)
    expect(resultado.valido).toBe(true)
  })
})
