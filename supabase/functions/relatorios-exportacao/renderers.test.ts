// Tests for renderers.ts (T029).
//
// Contract: specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
//   > "Rendering Rules" (PDF / CSV) and "Action `gerar` > Validation"
//   (EXPORT_TOO_LARGE, common-volume target of up to 5,000 detailed rows or
//   10 MB before compression).
// Plan: specs/008-exportar-relatorios/plan.md
//
// Status at authoring time: `renderCsv`, `renderCsvZip`, `renderPdf` and
// `assertWithinSizeLimits` are scaffolds that only `throw new Error(...)`
// (see renderers.ts). Every test below is expected to FAIL until those are
// implemented in T034/T035. This file intentionally does not implement any
// rendering logic itself.
//
// Runtime: Deno (Supabase Edge Functions). No existing `*.test.ts` file or
// Deno test convention was found elsewhere in `supabase/functions/`, so this
// uses plain `Deno.test` with `https://deno.land/std` assertions, mirroring
// how `index.ts` already imports third-party deps directly via URL/esm.sh.
//
// Suggested run command (from repo root):
//   deno test --allow-net --allow-env supabase/functions/relatorios-exportacao/renderers.test.ts

import {
  assert,
  assertEquals,
  assertThrows,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { unzipSync } from 'https://esm.sh/fflate@0.8.3'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

import {
  assertWithinSizeLimits,
  carregarFontesNoto,
  renderCsv,
  renderCsvZip,
  renderPdf,
} from './renderers.ts'
import type { RelatorioExportPayload } from './payload.ts'

/** Builds a valid baseline payload, with overrides for individual fields. */
function buildPayload(
  overrides: Partial<RelatorioExportPayload> = {},
): RelatorioExportPayload {
  return {
    exportacaoId: '11111111-1111-1111-1111-111111111111',
    tipo: 'Financeiro',
    formato: 'CSV',
    periodo: { data_inicial: '2026-07-01', data_final: '2026-07-31' },
    solicitante: { id: '22222222-2222-2222-2222-222222222222', nome: 'Fulano de Tal' },
    resumo: [{ receitas: 1000, despesas: 500, saldo: 500 }],
    detalhes: [
      {
        data: '2026-07-05',
        tipo: 'Receita',
        valor: 1000,
        descricao: 'Servico prestado',
      },
    ],
    mensagemSemDados: null,
    geradoEm: '2026-07-04T15:00:00Z',
    ...overrides,
  }
}

// ---------------------------------------------------------------------------
// CSV escaping (renderCsv)
// ---------------------------------------------------------------------------

Deno.test('renderCsv quotes and escapes fields with commas, quotes and line breaks', () => {
  const headers = ['plain', 'comma_field', 'quote_field', 'newline_field']
  const rows = [
    {
      plain: 'Sem caracteres especiais',
      comma_field: 'Rua A, 123',
      quote_field: 'Ele disse "ola"',
      newline_field: 'Linha 1\nLinha 2',
    },
  ]

  const csv = renderCsv(headers, rows)

  // Header line: plain field names, comma-joined, no escaping needed.
  assert(
    csv.startsWith('plain,comma_field,quote_field,newline_field'),
    'esperado que a primeira linha seja o cabecalho com os nomes das colunas',
  )

  // Value with a comma must be wrapped in double quotes.
  assert(
    csv.includes('"Rua A, 123"'),
    'valor com virgula deve ser envolvido em aspas duplas',
  )

  // Value with embedded double quotes must have them doubled and be wrapped.
  assert(
    csv.includes('"Ele disse ""ola"""'),
    'aspas internas devem ser escapadas duplicando-as, e o campo envolvido em aspas',
  )

  // Value with a line break must be wrapped in quotes, preserving the break.
  assert(
    csv.includes('"Linha 1\nLinha 2"'),
    'valor com quebra de linha deve ser envolvido em aspas preservando a quebra',
  )

  // Plain value without special characters should still be present.
  assert(
    csv.includes('Sem caracteres especiais'),
    'valor sem caracteres especiais deve aparecer no CSV',
  )
})

Deno.test('renderCsv still emits headers when there are no data rows', () => {
  const headers = ['data', 'tipo', 'valor']
  const csv = renderCsv(headers, [])

  assertEquals(
    csv.trim(),
    'data,tipo,valor',
    'com zero linhas, o CSV deve conter apenas o cabecalho',
  )
})

// ---------------------------------------------------------------------------
// ZIP contents (renderCsvZip)
// ---------------------------------------------------------------------------

Deno.test('renderCsvZip packages resumo.csv and detalhes.csv with the right names and content', async () => {
  const payload = buildPayload({
    detalhes: [
      {
        data: '2026-07-05',
        tipo: 'Receita',
        descricao: 'Servico, prestado',
        valor: 1000,
      },
    ],
  })

  const rendered = await renderCsvZip(payload)

  assertEquals(rendered.mimeType, 'application/zip')
  assert(rendered.tamanhoBytes > 0, 'arquivo ZIP gerado nao pode ter tamanho zero')
  assertEquals(
    rendered.tamanhoBytes,
    rendered.bytes.byteLength,
    'tamanhoBytes deve corresponder ao tamanho real dos bytes retornados',
  )

  const files = unzipSync(rendered.bytes)
  const fileNames = Object.keys(files)

  assert(fileNames.includes('resumo.csv'), 'ZIP deve conter resumo.csv')
  assert(fileNames.includes('detalhes.csv'), 'ZIP deve conter detalhes.csv')

  const decoder = new TextDecoder('utf-8')
  const resumoText = decoder.decode(files['resumo.csv'])
  const detalhesText = decoder.decode(files['detalhes.csv'])

  assert(resumoText.includes('receitas'), 'resumo.csv deve conter as colunas do resumo executivo')
  assert(resumoText.includes('1000'), 'resumo.csv deve conter os valores do resumo')

  assert(detalhesText.includes('descricao'), 'detalhes.csv deve conter as colunas de detalhe')
  assert(
    detalhesText.includes('"Servico, prestado"'),
    'valor com virgula em detalhes.csv deve ser escapado corretamente dentro do ZIP',
  )
})

Deno.test('renderCsvZip keeps detalhes.csv with headers and no-data context when there are no detail rows', async () => {
  const payload = buildPayload({
    detalhes: [],
    mensagemSemDados: 'Nenhum dado encontrado para o periodo selecionado.',
  })

  const rendered = await renderCsvZip(payload)
  const files = unzipSync(rendered.bytes)

  assert(Object.keys(files).includes('detalhes.csv'), 'ZIP deve conter detalhes.csv mesmo sem linhas')

  const detalhesText = new TextDecoder('utf-8').decode(files['detalhes.csv'])
  assert(
    detalhesText.trim().length > 0,
    'detalhes.csv nao pode ficar vazio; deve ao menos manter o cabecalho',
  )
  assert(
    detalhesText.includes(payload.mensagemSemDados ?? ''),
    'detalhes.csv deve refletir a mensagem de ausencia de dados quando nao ha linhas',
  )
})

// ---------------------------------------------------------------------------
// PDF rendering with no data (renderPdf)
// ---------------------------------------------------------------------------

Deno.test('carregarFontesNoto embeds the bundled Noto Sans fonts without fallback', async () => {
  const doc = await PDFDocument.create()
  const fontes = await carregarFontesNoto(doc)

  assertEquals(fontes.usandoFallback, false)
})

Deno.test('renderPdf renders a valid, non-empty PDF with an explicit no-data message and does not throw', async () => {
  const payload = buildPayload({
    formato: 'PDF',
    resumo: [],
    detalhes: [],
    mensagemSemDados: 'Nenhum dado encontrado para o periodo selecionado.',
  })

  const rendered = await renderPdf(payload)

  assertEquals(rendered.mimeType, 'application/pdf')
  assert(rendered.tamanhoBytes > 0, 'PDF gerado nao pode ter tamanho zero mesmo sem dados')

  // We can't reliably extract text content from a pdf-lib-generated PDF
  // without an additional PDF-text-extraction dependency (none exists in
  // this project). The structural checks below assert the contract's core
  // requirement: rendering must not break when there is no data, and must
  // produce a structurally valid, readable PDF document.
  const doc = await PDFDocument.load(rendered.bytes)
  assert(doc.getPageCount() >= 1, 'PDF sem dados ainda deve ter ao menos 1 pagina (ex.: mensagem de ausencia de dados)')
})

// ---------------------------------------------------------------------------
// EXPORT_TOO_LARGE (assertWithinSizeLimits)
// ---------------------------------------------------------------------------
//
// Business rule (plan.md > Constraints / Performance Goals and
// edge-function-exportacao.md > Action `gerar` > Validation): common-volume
// target is up to 5,000 detailed rows OR 10 MB before compression. Exceeding
// either must raise an error identifiable as `EXPORT_TOO_LARGE` so `index.ts`
// can map it to the contract's HTTP error code.

Deno.test('assertWithinSizeLimits does not throw for a payload within common-volume limits', () => {
  const payload = buildPayload({
    detalhes: Array.from({ length: 10 }, (_, i) => ({ id: i, valor: i * 10 })),
  })

  assertWithinSizeLimits(payload)
})

Deno.test('assertWithinSizeLimits allows exactly 5000 detail rows (inclusive boundary)', () => {
  const payload = buildPayload({
    detalhes: Array.from({ length: 5000 }, (_, i) => ({ id: i })),
  })

  assertWithinSizeLimits(payload)
})

Deno.test('assertWithinSizeLimits throws an EXPORT_TOO_LARGE-coded error for more than 5000 detail rows', () => {
  const payload = buildPayload({
    detalhes: Array.from({ length: 5001 }, (_, i) => ({ id: i })),
  })

  const error = assertThrows(() => assertWithinSizeLimits(payload)) as Error & {
    code?: string
  }
  assertEquals(error.code, 'EXPORT_TOO_LARGE')
})

Deno.test('assertWithinSizeLimits throws an EXPORT_TOO_LARGE-coded error when estimated size exceeds 10MB', () => {
  const oneMegabyteString = 'x'.repeat(1024 * 1024)
  const payload = buildPayload({
    // 11 rows of ~1MB each comfortably exceeds the 10MB threshold even
    // before accounting for JSON/CSV overhead.
    detalhes: Array.from({ length: 11 }, () => ({ campo: oneMegabyteString })),
  })

  const error = assertThrows(() => assertWithinSizeLimits(payload)) as Error & {
    code?: string
  }
  assertEquals(error.code, 'EXPORT_TOO_LARGE')
})

// ---------------------------------------------------------------------------
// PT-BR value formatting and label translations (T021 / T022)
// ---------------------------------------------------------------------------

import {
  formatarMoeda,
  formatarPorcentagem,
  formatarHoras,
  formatarData,
  formatarDataHora,
  formatarValorResumo,
  formatarCampoDetalhe,
  LABEL_MAP
} from './renderers.ts'

Deno.test('formatarMoeda formats numbers correctly to BRL currency string', () => {
  const formatado = formatarMoeda(1250.5)
  // Substitui espaços não quebráveis por espaço padrão para consistência nos testes
  const limpo = formatado.replace(/\u00a0/g, ' ')
  assert(limpo.includes('R$') && limpo.includes('1.250,50'))
})

Deno.test('formatarPorcentagem format numbers to percentage string', () => {
  assertEquals(formatarPorcentagem(75.5), '75.5%')
})

Deno.test('formatarHoras formats hours decimal value correctly', () => {
  const formatado = formatarHoras(8.5)
  const limpo = formatado.replace(/\u00a0/g, ' ')
  assertEquals(limpo, '8,50h')
})

Deno.test('formatarData converts ISO dates and Date strings to DD/MM/AAAA', () => {
  assertEquals(formatarData('2026-07-09'), '09/07/2026')
})

Deno.test('LABEL_MAP contains all business translations for all 4 categories', () => {
  assert(LABEL_MAP.Financeiro)
  assert(LABEL_MAP.DRE)
  assert(LABEL_MAP.Clientes)
  assert(LABEL_MAP.Projetos)

  assertEquals(LABEL_MAP.Financeiro.valor, 'Valor')
  assertEquals(LABEL_MAP.Clientes.nome_contato, 'Nome do Contato')
  assertEquals(LABEL_MAP.Projetos.horas_apontadas_no_periodo, 'Horas Apontadas no Período')
})
