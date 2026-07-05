// Rendering helpers for the `relatorios-exportacao` Edge Function.
//
// Contract: specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
// (see "Rendering Rules" for PDF and CSV/ZIP requirements).
//
// Implementation (US1):
// - PDF via `pdf-lib`.
// - CSV serialized internally, packaged as ZIP via `fflate`.
// Both dependencies are imported here via esm.sh, matching the import style
// already used by `index.ts` (e.g. `@supabase/supabase-js` via esm.sh) and by
// `renderers.test.ts` itself.

import { zipSync } from 'https://esm.sh/fflate@0.8.3'
import { PDFDocument, rgb, StandardFonts } from 'https://esm.sh/pdf-lib@1.17.1'

import type { RelatorioExportPayload } from './payload.ts'

/** Result of rendering an export file, ready for Storage upload. */
export interface RenderedFile {
  bytes: Uint8Array
  mimeType: string
  /** Size in bytes, used for observability (`tamanho_bytes`). */
  tamanhoBytes: number
}

const NO_DATA_FALLBACK_MESSAGE =
  'Nenhum dado encontrado para o periodo selecionado.'

// ---------------------------------------------------------------------------
// PDF (pdf-lib)
// ---------------------------------------------------------------------------

const PAGE_WIDTH = 595.28 // A4, in points
const PAGE_HEIGHT = 841.89
const MARGIN = 50
const LINE_HEIGHT = 16

/**
 * Renders the PDF report for a given payload.
 *
 * Requirements (edge-function-exportacao.md > Rendering Rules > PDF):
 * - Title, category, period, solicitante, generation and expiration timestamps.
 * - Executive summary before details.
 * - Paginated, readable details.
 * - Explicit no-data message when there is no data.
 *
 * Expiration timestamp is not part of the payload returned by the RPC (only
 * `geradoEm` is), so it is derived here from the 12-month retention rule
 * documented in plan.md ("arquivos validos por 12 meses a partir da
 * geracao"), purely for display purposes in the PDF header.
 */
export async function renderPdf(
  payload: RelatorioExportPayload,
): Promise<RenderedFile> {
  const doc = await PDFDocument.create()
  const fontRegular = await doc.embedFont(StandardFonts.Helvetica)
  const fontBold = await doc.embedFont(StandardFonts.HelveticaBold)

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
    ensureSpace()
    page.drawText(text, {
      x: MARGIN,
      y,
      size: opts.size ?? 11,
      font: opts.bold ? fontBold : fontRegular,
      color: rgb(0, 0, 0),
    })
    y -= LINE_HEIGHT
  }

  const geradoEmDate = new Date(payload.geradoEm)
  const expiraEmDate = new Date(geradoEmDate)
  if (!Number.isNaN(expiraEmDate.getTime())) {
    expiraEmDate.setUTCFullYear(expiraEmDate.getUTCFullYear() + 1)
  }

  drawText(`Relatorio de ${payload.tipo}`, { bold: true, size: 18 })
  y -= LINE_HEIGHT / 2
  drawText(`Categoria: ${payload.tipo}`)
  drawText(`Periodo: ${payload.periodo.data_inicial} a ${payload.periodo.data_final}`)
  drawText(`Solicitante: ${payload.solicitante.nome}`)
  drawText(`Gerado em: ${payload.geradoEm}`)
  if (!Number.isNaN(expiraEmDate.getTime())) {
    drawText(`Expira em: ${expiraEmDate.toISOString()}`)
  }

  y -= LINE_HEIGHT / 2
  drawText('Resumo executivo', { bold: true, size: 14 })
  if (payload.resumo.length === 0) {
    drawText(payload.mensagemSemDados ?? NO_DATA_FALLBACK_MESSAGE)
  } else {
    for (const item of payload.resumo) {
      for (const [key, value] of Object.entries(item)) {
        drawText(`${key}: ${String(value)}`)
      }
    }
  }

  y -= LINE_HEIGHT / 2
  drawText('Detalhes', { bold: true, size: 14 })
  if (payload.detalhes.length === 0) {
    drawText(payload.mensagemSemDados ?? NO_DATA_FALLBACK_MESSAGE)
  } else {
    for (const row of payload.detalhes) {
      const line = Object.entries(row)
        .map(([key, value]) => `${key}: ${String(value)}`)
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

/**
 * Escapes a single CSV field per RFC 4180: values containing the delimiter
 * (`,`), a double quote or a line break (`\n`/`\r`) are wrapped in double
 * quotes, with internal double quotes doubled. The original line-break
 * character(s) inside the value are preserved as-is.
 */
function escapeCsvField(value: unknown): string {
  const str = value === null || value === undefined ? '' : String(value)
  if (/[",\n\r]/.test(str)) {
    return `"${str.replace(/"/g, '""')}"`
  }
  return str
}

/**
 * Serializes a set of rows into CSV text.
 *
 * Requirements (edge-function-exportacao.md > Rendering Rules > CSV):
 * - UTF-8.
 * - Escape delimiter, quotes and line breaks correctly.
 * - Headers must be present even when there are no data rows.
 */
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

/**
 * Derives CSV headers from a set of records (union of all keys, in
 * first-seen order), or falls back to a single `mensagem` column when there
 * are no records at all (no-data case).
 */
function deriveHeaders(rows: Record<string, unknown>[]): string[] {
  if (rows.length === 0) return ['mensagem']

  const headers: string[] = []
  const seen = new Set<string>()
  for (const row of rows) {
    for (const key of Object.keys(row)) {
      if (!seen.has(key)) {
        seen.add(key)
        headers.push(key)
      }
    }
  }
  return headers
}

/**
 * Builds CSV text for a section (`resumo` or `detalhes`), keeping headers
 * and an explicit no-data message when there are no rows.
 */
function renderSectionCsv(
  rows: Record<string, unknown>[],
  mensagemSemDados: string | null,
): string {
  if (rows.length === 0) {
    return renderCsv(['mensagem'], [
      { mensagem: mensagemSemDados ?? NO_DATA_FALLBACK_MESSAGE },
    ])
  }
  return renderCsv(deriveHeaders(rows), rows)
}

/**
 * Builds the `resumo.csv` + `detalhes.csv` ZIP package for a given payload.
 *
 * Requirements (edge-function-exportacao.md > Rendering Rules > CSV):
 * - Must include both `resumo.csv` and `detalhes.csv`.
 * - `detalhes.csv` still includes headers and no-data context when empty.
 */
export async function renderCsvZip(
  payload: RelatorioExportPayload,
): Promise<RenderedFile> {
  const resumoCsv = renderSectionCsv(payload.resumo, payload.mensagemSemDados)
  const detalhesCsv = renderSectionCsv(
    payload.detalhes,
    payload.mensagemSemDados,
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
const MAX_SIZE_BYTES = 10 * 1024 * 1024 // 10 MB, before compression

function exportTooLargeError(message: string): Error & { code: string } {
  const error = new Error(message) as Error & { code: string }
  error.code = 'EXPORT_TOO_LARGE'
  return error
}

/**
 * Validates rendered/estimated size against the `EXPORT_TOO_LARGE` business
 * rule (common-volume target: up to 5,000 detailed rows or 10 MB before
 * compression, per edge-function-exportacao.md > Action `gerar` > Validation).
 *
 * Row count is checked directly against `payload.detalhes.length`. Size is
 * estimated from the JSON encoding of `resumo` + `detalhes` (the raw data
 * that both renderers turn into CSV/PDF), which is a conservative
 * pre-compression estimate independent of the final output format.
 */
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
