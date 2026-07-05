/**
 * Funções puras de cálculo e validação de período para exportação de relatórios
 * (Feature 008). As regras aqui devem espelhar exatamente a validação feita no
 * backend (RPC `iniciar_exportacao_relatorio` / Edge Function `relatorios-exportacao`),
 * pois o backend permanece a fonte de verdade e revalida tudo novamente.
 *
 * Sem dependência de React — apenas datas/strings.
 */

const REGEX_DATA_ISO = /^\d{4}-\d{2}-\d{2}$/

export interface PeriodoRelatorio {
  data_inicial: string
  data_final: string
}

export type CodigoErroPeriodoRelatorio = 'PERIODO_INVALIDO' | 'PERIODO_MAIOR_QUE_12_MESES'

export interface ResultadoValidacaoPeriodo {
  valido: boolean
  codigo?: CodigoErroPeriodoRelatorio
  mensagem?: string
}

function formatarDataISO(data: Date): string {
  const ano = data.getUTCFullYear()
  const mes = String(data.getUTCMonth() + 1).padStart(2, '0')
  const dia = String(data.getUTCDate()).padStart(2, '0')
  return `${ano}-${mes}-${dia}`
}

function parseDataISO(dataStr: string): Date | null {
  if (typeof dataStr !== 'string' || !REGEX_DATA_ISO.test(dataStr)) {
    return null
  }

  const [ano, mes, dia] = dataStr.split('-').map(Number)
  const data = new Date(Date.UTC(ano, mes - 1, dia))

  // Rejeita datas de calendário inválidas (ex.: 2026-02-30 vira 2026-03-02 no Date nativo)
  if (data.getUTCFullYear() !== ano || data.getUTCMonth() !== mes - 1 || data.getUTCDate() !== dia) {
    return null
  }

  return data
}

/**
 * Calcula o período default do modal de exportação: do primeiro dia do mês
 * corrente até a data atual (inclusive), conforme contrato do frontend de Relatorios.
 *
 * @param referencia Data de referência (default: agora). Útil para testes determinísticos.
 */
export function obterPeriodoPadrao(referencia: Date = new Date()): PeriodoRelatorio {
  const primeiroDiaDoMes = new Date(Date.UTC(referencia.getFullYear(), referencia.getMonth(), 1))
  const hoje = new Date(
    Date.UTC(referencia.getFullYear(), referencia.getMonth(), referencia.getDate())
  )

  return {
    data_inicial: formatarDataISO(primeiroDiaDoMes),
    data_final: formatarDataISO(hoje),
  }
}

/**
 * Calcula a última data permitida (inclusive) para `data_final` dado um `data_inicial`,
 * respeitando a regra de intervalo máximo de 12 meses calendário.
 *
 * Exemplo: `2026-01-01` -> `2026-12-31`.
 */
function calcularLimiteMaximoPeriodo(dataInicial: Date): Date {
  const limite = new Date(
    Date.UTC(dataInicial.getUTCFullYear(), dataInicial.getUTCMonth() + 12, dataInicial.getUTCDate())
  )
  limite.setUTCDate(limite.getUTCDate() - 1)
  return limite
}

/**
 * Valida um período de exportação de relatório com as mesmas regras aplicadas pelo
 * backend:
 *
 * - `data_inicial` e `data_final` devem ser datas ISO (`YYYY-MM-DD`) válidas.
 * - Datas são inclusivas; `data_inicial` deve ser menor ou igual a `data_final`
 *   (período de um único dia é permitido).
 * - O intervalo não pode exceder 12 meses calendário inclusivos:
 *   `2026-01-01` a `2026-12-31` é válido; `2026-01-01` a `2027-01-01` é bloqueado.
 */
export function validarPeriodoExportacao(
  data_inicial: string,
  data_final: string
): ResultadoValidacaoPeriodo {
  const inicio = parseDataISO(data_inicial)
  const fim = parseDataISO(data_final)

  if (!inicio || !fim || inicio.getTime() > fim.getTime()) {
    return {
      valido: false,
      codigo: 'PERIODO_INVALIDO',
      mensagem: 'Periodo invalido.',
    }
  }

  const limiteMaximo = calcularLimiteMaximoPeriodo(inicio)

  if (fim.getTime() > limiteMaximo.getTime()) {
    return {
      valido: false,
      codigo: 'PERIODO_MAIOR_QUE_12_MESES',
      mensagem: 'Periodo maior que 12 meses.',
    }
  }

  return { valido: true }
}
