// Rendering helpers for the `relatorios-exportacao` Edge Function.
//
// Contract: specs/011-padrao-enterprise-relatorios/contracts/rotulos-negocio.md
// and specs/011-padrao-enterprise-relatorios/contracts/pdf-executivo.md
// (see "Rendering Rules" for PDF and CSV/ZIP requirements).

import { zipSync } from 'https://esm.sh/fflate@0.8.3'
import { PDFDocument, rgb, StandardFonts } from 'https://esm.sh/pdf-lib@1.17.1'
import fontkit from 'https://esm.sh/@pdf-lib/fontkit@1.1.1'

import { NOTO_SANS_BOLD_BASE64, NOTO_SANS_REGULAR_BASE64 } from './font-assets.ts'
import type { RelatorioExportPayload } from './payload.ts'

/** Result of rendering an export file, ready for Storage upload. */
export interface RenderedFile {
  bytes: Uint8Array
  mimeType: string
  /** Size in bytes, used for observability (`tamanho_bytes`). */
  tamanhoBytes: number
}

const NO_DATA_FALLBACK_MESSAGE =
  'Não há dados disponíveis para o período selecionado. Selecione um intervalo diferente ou entre em contato com o administrador.'

// ---------------------------------------------------------------------------
// Business Label Map & PT-BR Value Formatters
// ---------------------------------------------------------------------------

export const LABEL_MAP: Record<string, Record<string, string>> = {
  Financeiro: {
    data: 'Data',
    tipo: 'Tipo',
    natureza: 'Natureza',
    status: 'Status',
    categoria: 'Categoria',
    descricao: 'Descrição',
    cliente: 'Cliente',
    projeto: 'Projeto',
    valor: 'Valor',
  },
  DRE: {
    data: 'Data',
    grupo_dre: 'Grupo DRE',
    categoria: 'Categoria',
    descricao: 'Descrição',
    valor: 'Valor',
  },
  Clientes: {
    id: 'ID',
    nome_contato: 'Nome do Contato',
    empresa: 'Empresa',
    email: 'E-mail',
    telefone: 'Telefone',
    tipo: 'Tipo',
    status: 'Status',
    criado_em: 'Criado em',
    atualizado_em: 'Atualizado em',
    atendimentos_no_periodo: 'Atendimentos no Período',
  },
  Projetos: {
    id: 'ID',
    nome: 'Nome',
    cliente: 'Cliente',
    status: 'Status',
    prazo: 'Prazo',
    responsavel: 'Responsável',
    progresso: 'Progresso',
    orcamento: 'Orçamento',
    orcamento_utilizado: 'Orçamento Utilizado',
    horas_apontadas_no_periodo: 'Horas Apontadas no Período',
    tarefas_concluidas_no_periodo: 'Tarefas Concluídas no Período',
  },
}

export function formatarMoeda(valor: number): string {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(valor)
}

export function formatarPorcentagem(valor: number): string {
  return typeof valor === 'number' ? `${valor}%` : `${String(valor)}`
}

export function formatarHoras(valor: number): string {
  return new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(valor) + 'h'
}

export function formatarData(valor: unknown): string {
  if (!valor) return ''
  const str = String(valor)
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) {
    const [ano, mes, dia] = str.split('-')
    return `${dia}/${mes}/${ano}`
  }
  try {
    const date = new Date(str)
    if (!Number.isNaN(date.getTime())) {
      const dia = String(date.getUTCDate()).padStart(2, '0')
      const mes = String(date.getUTCMonth() + 1).padStart(2, '0')
      const ano = date.getUTCFullYear()
      return `${dia}/${mes}/${ano}`
    }
  } catch {
    // fallback
  }
  return str
}

export function formatarDataHora(valor: unknown): string {
  if (!valor) return ''
  const str = String(valor)
  try {
    const date = new Date(str)
    if (!Number.isNaN(date.getTime())) {
      const dia = String(date.getUTCDate()).padStart(2, '0')
      const mes = String(date.getUTCMonth() + 1).padStart(2, '0')
      const ano = date.getUTCFullYear()
      const horas = String(date.getUTCHours()).padStart(2, '0')
      const minutos = String(date.getUTCMinutes()).padStart(2, '0')
      return `${dia}/${mes}/${ano} ${horas}:${minutos}`
    }
  } catch {
    // fallback
  }
  return str
}

export function formatarValorResumo(label: string, valor: unknown): string {
  if (typeof valor !== 'number') return String(valor)

  const labelsMoeda = [
    'Receitas', 'Despesas', 'Saldo',
    'Faturamento bruto', 'Deduções', 'Custos operacionais', 'Resultado líquido'
  ]
  const labelsHoras = ['Horas apontadas no período']

  if (labelsMoeda.includes(label)) {
    return formatarMoeda(valor)
  }
  if (labelsHoras.includes(label)) {
    return formatarHoras(valor)
  }
  return new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 }).format(valor)
}

export function formatarCampoDetalhe(categoria: string, chave: string, valor: unknown): string {
  if (valor === null || valor === undefined) return ''

  if (chave === 'data' || chave === 'prazo') {
    return formatarData(valor)
  }
  if (chave === 'criado_em' || chave === 'atualizado_em') {
    return formatarDataHora(valor)
  }
  if (
    chave === 'valor' ||
    chave === 'orcamento' ||
    chave === 'orcamento_utilizado'
  ) {
    return typeof valor === 'number' ? formatarMoeda(valor) : String(valor)
  }
  if (chave === 'horas_apontadas_no_periodo') {
    return typeof valor === 'number' ? formatarHoras(valor) : String(valor)
  }
  if (chave === 'progresso') {
    return typeof valor === 'number' ? formatarPorcentagem(valor) : String(valor)
  }
  if (chave === 'atendimentos_no_periodo' || chave === 'tarefas_concluidas_no_periodo') {
    return typeof valor === 'number' ? new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 }).format(valor) : String(valor)
  }
  if (chave === 'tipo' && categoria === 'Financeiro') {
    if (typeof valor === 'string') {
      return valor.charAt(0).toUpperCase() + valor.slice(1).toLowerCase()
    }
  }
  if (chave === 'status' && categoria === 'Financeiro') {
    if (typeof valor === 'string') {
      return valor.charAt(0).toUpperCase() + valor.slice(1).toLowerCase()
    }
  }
  return String(valor)
}

export function removerAcentos(texto: string): string {
  return texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

export function tituloRelatorio(categoria: string): string {
  return `Relatório ${categoria}`
}

// ---------------------------------------------------------------------------
// Font Loading and Fallback (Noto Sans)
// ---------------------------------------------------------------------------

interface CarregadorFontesResult {
  regular: any
  bold: any
  usandoFallback: boolean
}

function decodeBase64Font(base64: string): Uint8Array {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

export async function carregarFontesNoto(doc: PDFDocument): Promise<CarregadorFontesResult> {
  try {
    doc.registerFontkit(fontkit)

    const regularBytes = decodeBase64Font(NOTO_SANS_REGULAR_BASE64)
    const boldBytes = decodeBase64Font(NOTO_SANS_BOLD_BASE64)

    const fontRegular = await doc.embedFont(regularBytes, { subset: true })
    const fontBold = await doc.embedFont(boldBytes, { subset: true })

    return {
      regular: fontRegular,
      bold: fontBold,
      usandoFallback: false
    }
  } catch (error) {
    console.warn(
      `[WARNING] Falha ao carregar fonte Noto Sans. Ativando fallback StandardFonts.Helvetica. Detalhe: ${error instanceof Error ? error.message : String(error)}`
    )
    const fontRegular = await doc.embedFont(StandardFonts.Helvetica)
    const fontBold = await doc.embedFont(StandardFonts.HelveticaBold)
    return {
      regular: fontRegular,
      bold: fontBold,
      usandoFallback: true
    }
  }
}

// ---------------------------------------------------------------------------
// PDF (pdf-lib)
// ---------------------------------------------------------------------------

const PAGE_WIDTH = 595.28 // A4, in points
const PAGE_HEIGHT = 841.89
const MARGIN = 50
const LINE_HEIGHT = 16
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2

function wrapText(text: string, font: any, size: number, maxWidth: number): string[] {
  if (font.widthOfTextAtSize(text, size) <= maxWidth) {
    return [text]
  }

  const lines: string[] = []
  let current = ''

  for (const word of text.split(/\s+/)) {
    const candidate = current ? `${current} ${word}` : word
    if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
      current = candidate
      continue
    }

    if (current) {
      lines.push(current)
      current = word
    } else {
      lines.push(word)
    }
  }

  if (current) {
    lines.push(current)
  }

  return lines.length > 0 ? lines : ['']
}

/**
 * Renders the PDF report for a given payload.
 */
export async function renderPdf(
  payload: RelatorioExportPayload,
): Promise<RenderedFile> {
  const doc = await PDFDocument.create()
  const fontes = await carregarFontesNoto(doc)
  const usandoFallback = fontes.usandoFallback

  let page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT])
  let y = PAGE_HEIGHT - MARGIN

  const ensureSpace = () => {
    if (y - LINE_HEIGHT < MARGIN) {
      page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT])
      y = PAGE_HEIGHT - MARGIN
    }
  }

  const drawText = (
    text: string,
    opts: { bold?: boolean; size?: number } = {},
  ) => {
    const size = opts.size ?? 11
    const font = opts.bold ? fontes.bold : fontes.regular
    const textoLimpo = usandoFallback ? removerAcentos(text) : text
    const linhas = wrapText(textoLimpo, font, size, CONTENT_WIDTH)

    for (const linha of linhas) {
      ensureSpace()
      page.drawText(linha, {
        x: MARGIN,
        y,
        size,
        font,
        color: rgb(0, 0, 0),
      })
      y -= LINE_HEIGHT
    }
  }

  const geradoEmDate = new Date(payload.geradoEm)
  const expiraEmDate = new Date(geradoEmDate)
  if (!Number.isNaN(expiraEmDate.getTime())) {
    expiraEmDate.setUTCFullYear(expiraEmDate.getUTCFullYear() + 1)
  }

  drawText(tituloRelatorio(payload.tipo), { bold: true, size: 18 })
  y -= LINE_HEIGHT / 2
  drawText(`Categoria: ${payload.tipo}`)
  drawText(`Período: ${formatarData(payload.periodo.data_inicial)} a ${formatarData(payload.periodo.data_final)}`)
  drawText(`Solicitante: ${payload.solicitante.nome}`)
  drawText(`Gerado em: ${formatarDataHora(payload.geradoEm)}`)
  if (!Number.isNaN(expiraEmDate.getTime())) {
    drawText(`Expira em: ${formatarDataHora(expiraEmDate.toISOString())}`)
  }

  y -= LINE_HEIGHT / 2
  drawText('Resumo executivo', { bold: true, size: 14 })
  if (payload.resumo.length === 0) {
    drawText(payload.mensagemSemDados ?? NO_DATA_FALLBACK_MESSAGE)
  } else {
    for (const item of payload.resumo) {
      const label = item.label ? String(item.label) : ''
      const valor = item.valor
      const valorFormatado = formatarValorResumo(label, valor)
      drawText(`${label}: ${valorFormatado}`)
    }
  }

  y -= LINE_HEIGHT / 2
  drawText('Detalhes', { bold: true, size: 14 })
  if (payload.detalhes.length === 0) {
    drawText(NO_DATA_FALLBACK_MESSAGE)
  } else {
    const mapaTraducoes = LABEL_MAP[payload.tipo] || {}
    for (const row of payload.detalhes) {
      const line = Object.entries(row)
        .map(([key, value]) => {
          const rotuloNegocio = mapaTraducoes[key] || key
          const valorFormatado = formatarCampoDetalhe(payload.tipo, key, value)
          return `${rotuloNegocio}: ${valorFormatado}`
        })
        .join(' | ')
      drawText(line)
    }
  }

  const bytes = await doc.save()
  return {
    bytes,
    mimeType: 'application/pdf',
    tamanhoBytes: bytes.byteLength,
  }
}

// ---------------------------------------------------------------------------
// CSV (internal serializer)
// ---------------------------------------------------------------------------

function escapeCsvField(value: unknown): string {
  const str = value === null || value === undefined ? '' : String(value)
  if (/[",\n\r]/.test(str)) {
    return `"${str.replace(/"/g, '""')}"`
  }
  return str
}

export function renderCsv(
  headers: string[],
  rows: Record<string, unknown>[],
): string {
  const headerLine = headers.map(escapeCsvField).join(',')
  const dataLines = rows.map((row) =>
    headers.map((header) => escapeCsvField(row[header])).join(','),
  )
  return [headerLine, ...dataLines].join('\n')
}

function traduzirEFormatarDados(
  rows: Record<string, unknown>[],
  categoria: string,
): { headers: string[]; rows: Record<string, unknown>[] } {
  if (rows.length === 0) {
    return { headers: [], rows: [] }
  }

  const mapa = LABEL_MAP[categoria] || {}
  const chavesOriginais = Object.keys(rows[0])
  const headersTraduzidos = chavesOriginais.map(key => mapa[key] || key)

  const novasLinhas = rows.map(row => {
    const novaLinha: Record<string, unknown> = {}
    for (const key of chavesOriginais) {
      const headerTraduzido = mapa[key] || key
      const valorFormatado = formatarCampoDetalhe(categoria, key, row[key])
      novaLinha[headerTraduzido] = valorFormatado
    }
    return novaLinha
  })

  return {
    headers: headersTraduzidos,
    rows: novasLinhas
  }
}

function renderSectionCsv(
  rows: Record<string, unknown>[],
  _mensagemSemDados: string | null,
  categoria: string,
): string {
  const msg = NO_DATA_FALLBACK_MESSAGE

  if (rows.length === 0) {
    return '\ufeff' + renderCsv(['Observacao'], [{ Observacao: msg }])
  }

  const { headers, rows: rowsFormatados } = traduzirEFormatarDados(rows, categoria)
  return '\ufeff' + renderCsv(headers, rowsFormatados)
}

export async function renderCsvZip(
  payload: RelatorioExportPayload,
): Promise<RenderedFile> {
  let resumoCsv = ''
  if (payload.resumo.length === 0) {
    resumoCsv = '\ufeff' + renderCsv(['Observacao'], [{ Observacao: NO_DATA_FALLBACK_MESSAGE }])
  } else {
    const resumoFormatado = payload.resumo.map(item => {
      const label = item.label ? String(item.label) : ''
      const valor = item.valor
      return {
        'Indicador': label,
        'Valor': formatarValorResumo(label, valor)
      }
    })
    resumoCsv = '\ufeff' + renderCsv(['Indicador', 'Valor'], resumoFormatado)
  }

  const detalhesCsv = renderSectionCsv(
    payload.detalhes,
    payload.mensagemSemDados,
    payload.tipo,
  )

  const encoder = new TextEncoder()
  const zipped = zipSync({
    'resumo.csv': encoder.encode(resumoCsv),
    'detalhes.csv': encoder.encode(detalhesCsv),
  })

  return {
    bytes: zipped,
    mimeType: 'application/zip',
    tamanhoBytes: zipped.byteLength,
  }
}

// ---------------------------------------------------------------------------
// Size limits
// ---------------------------------------------------------------------------

const MAX_DETAIL_ROWS = 5000
const MAX_SIZE_BYTES = 10 * 1024 * 1024

function exportTooLargeError(message: string): Error & { code: string } {
  const error = new Error(message) as Error & { code: string }
  error.code = 'EXPORT_TOO_LARGE'
  return error
}

export function assertWithinSizeLimits(
  payload: RelatorioExportPayload,
): void {
  const detailCount = payload.detalhes.length
  if (detailCount > MAX_DETAIL_ROWS) {
    throw exportTooLargeError(
      `Exportacao excede o limite de ${MAX_DETAIL_ROWS} linhas detalhadas (recebido: ${detailCount}).`,
    )
  }

  const estimatedBytes = new TextEncoder().encode(
    JSON.stringify({ resumo: payload.resumo, detalhes: payload.detalhes }),
  ).length

  if (estimatedBytes > MAX_SIZE_BYTES) {
    throw exportTooLargeError(
      `Exportacao excede o limite de ${MAX_SIZE_BYTES} bytes antes da compressao (estimado: ${estimatedBytes}).`,
    )
  }
}
