import { describe, it, expect, vi, afterEach } from 'vitest'
import { relatoriosService } from './relatorios.service'
import { supabase } from './supabase'
import type { ExportacaoRelatorioResponse } from '../types/relatorios'

/**
 * Helper local para mockar supabase.functions.invoke, seguindo a mesma convenção
 * de mockSupabaseRpc (src/services/rpc-test-utils.ts), mas para Edge Functions.
 */
function mockSupabaseFunctionsInvoke(fnName: string, resolvedValue: any, errorValue: any = null) {
  // BUGFIX (não é uma flexibilização de asserção): `supabase.functions` é um getter
  // que retorna uma NOVA instância de `FunctionsClient` a cada acesso
  // (@supabase/supabase-js SupabaseClient#functions). Por isso, `vi.spyOn(supabase.functions, 'invoke')`
  // mockava apenas essa instância descartável — o código de produção, ao acessar
  // `supabase.functions.invoke(...)` novamente, obtinha outra instância (com o método
  // original, não mockado) e disparava uma chamada de rede real (timeout/erro 503 nos
  // testes, mesmo com a implementação de `exportarRelatorio` correta). O método `invoke`
  // é definido na classe `FunctionsClient`, logo vive em `FunctionsClient.prototype` e é
  // compartilhado por todas as instâncias; mockar o protótipo garante que qualquer
  // instância futura (inclusive as criadas dentro do serviço) use a implementação mockada.
  const mockInvoke = vi.spyOn(Object.getPrototypeOf(supabase.functions), 'invoke')

  mockInvoke.mockImplementation((...args: unknown[]) => {
    const name = args[0] as string
    if (name === fnName) {
      return Promise.resolve({ data: errorValue ? null : resolvedValue, error: errorValue }) as any
    }
    return Promise.resolve({ data: null, error: { message: 'Edge Function não mockada' } }) as any
  })

  return mockInvoke
}

describe('relatoriosService.exportarRelatorio (US1 - T027)', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  const mockResponse: ExportacaoRelatorioResponse = {
    exportacao: {
      id: 'export-uuid-1',
      tipo: 'Financeiro',
      formato: 'PDF',
      status_exibicao: 'Pronto',
      data_inicial: '2026-07-01',
      data_final: '2026-07-31',
      arquivo_nome: 'relatorio-financeiro-2026-07-01-2026-07-31-ab12cd.pdf',
      mime_type: 'application/pdf',
      gerado_em: '2026-07-04T15:00:00Z',
      expira_em: '2027-07-04T15:00:00Z'
    },
    download_url: 'https://storage.example/signed/relatorio-financeiro.pdf?token=abc123',
    download_expires_in: 600
  }

  it('deve invocar a Edge Function relatorios-exportacao com action "gerar" e o payload de categoria/formato/período', async () => {
    const mockInvoke = mockSupabaseFunctionsInvoke('relatorios-exportacao', mockResponse)

    await relatoriosService.exportarRelatorio({
      tipo: 'Financeiro',
      formato: 'PDF',
      data_inicial: '2026-07-01',
      data_final: '2026-07-31'
    })

    expect(mockInvoke).toHaveBeenCalledWith('relatorios-exportacao', {
      body: {
        action: 'gerar',
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      }
    })
  })

  it('deve retornar uma resposta cujo download_expires_in é 600 (URL de curta duração)', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', mockResponse)

    const res = await relatoriosService.exportarRelatorio({
      tipo: 'Financeiro',
      formato: 'PDF',
      data_inicial: '2026-07-01',
      data_final: '2026-07-31'
    })

    expect(res.download_expires_in).toBe(600)
    expect(res.download_url).toBe(mockResponse.download_url)
  })

  it('não deve expor arquivo_url como link público permanente no fluxo de exportação', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', mockResponse)

    const res = await relatoriosService.exportarRelatorio({
      tipo: 'Financeiro',
      formato: 'PDF',
      data_inicial: '2026-07-01',
      data_final: '2026-07-31'
    })

    // A normalização do service não deve incluir/derivar um campo "arquivo_url" permanente:
    // o único link de download exposto é o download_url de curta duração retornado pela Edge Function.
    expect((res as any).arquivo_url).toBeUndefined()
    expect((res.exportacao as any).arquivo_url).toBeUndefined()
    expect(res.download_url).toBe(mockResponse.download_url)
  })

  it('deve propagar erro quando a Edge Function retorna falha (ex.: PERMISSION_DENIED)', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', null, { message: 'Usuario sem permissao para exportar relatorios.' })

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Projetos',
        formato: 'CSV',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toBeTruthy()
  })
})

describe('relatoriosService.baixarExportacaoRelatorio (US2 - T047)', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  const mockDownloadResponse: ExportacaoRelatorioResponse = {
    exportacao: {
      id: 'export-uuid-1',
      arquivo_nome: 'relatorio-projetos-2026-07-01-2026-07-31-ab12cd.zip',
      mime_type: 'application/zip',
      expira_em: '2027-07-04T15:00:00Z'
    },
    download_url: 'https://storage.example/signed/relatorio-projetos.zip?token=xyz789',
    download_expires_in: 600
  }

  it('deve invocar a Edge Function relatorios-exportacao com action "download" e o exportacao_id', async () => {
    const mockInvoke = mockSupabaseFunctionsInvoke('relatorios-exportacao', mockDownloadResponse)

    await relatoriosService.baixarExportacaoRelatorio({
      exportacao_id: 'export-uuid-1'
    })

    expect(mockInvoke).toHaveBeenCalledWith('relatorios-exportacao', {
      body: {
        action: 'download',
        exportacao_id: 'export-uuid-1'
      }
    })
  })

  it('deve retornar uma resposta cujo download_expires_in é 600 (URL de curta duração)', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', mockDownloadResponse)

    const res = await relatoriosService.baixarExportacaoRelatorio({
      exportacao_id: 'export-uuid-1'
    })

    expect(res.download_expires_in).toBe(600)
    expect(res.download_url).toBe(mockDownloadResponse.download_url)
  })

  it('não deve expor arquivo_url como link público permanente no fluxo de download', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', mockDownloadResponse)

    const res = await relatoriosService.baixarExportacaoRelatorio({
      exportacao_id: 'export-uuid-1'
    })

    // A normalização do service não deve incluir/derivar um campo "arquivo_url" permanente:
    // o único link de download exposto é o download_url de curta duração retornado pela Edge Function.
    expect((res as any).arquivo_url).toBeUndefined()
    expect((res.exportacao as any).arquivo_url).toBeUndefined()
    expect(res.download_url).toBe(mockDownloadResponse.download_url)
  })

  it('deve propagar erro quando a Edge Function nega o download (ex.: EXPORT_EXPIRED)', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', null, { message: 'Exportação expirada.' })

    await expect(
      relatoriosService.baixarExportacaoRelatorio({
        exportacao_id: 'export-uuid-expirado'
      })
    ).rejects.toBeTruthy()
  })

  it('deve propagar erro quando a Edge Function nega o download (ex.: PERMISSION_DENIED)', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', null, { message: 'Usuario sem permissao para baixar a exportacao.' })

    await expect(
      relatoriosService.baixarExportacaoRelatorio({
        exportacao_id: 'export-uuid-1'
      })
    ).rejects.toBeTruthy()
  })
})

/**
 * Testes de superfície de negação do backend (Feature 008 - Exportar Relatórios,
 * User Story 3 / T062).
 *
 * IMPORTANTE (TDD): estes testes verificam que mensagens de negação vindas da Edge Function
 * `relatorios-exportacao` (per `supabase/functions/relatorios-exportacao/_shared.ts` ->
 * `FRIENDLY_MESSAGE_BY_CODE`) continuam visíveis/reconhecíveis em `err.message` mesmo que a
 * checagem de capacidade do lado do cliente (`pode(capacidades, 'relatorios.exportar')`,
 * ver T061) tenha falhado ou sido contornada — ou seja, o service NUNCA deve engolir/mascarar
 * uma negação do backend, pois "Backend denial must be surfaced even if UI gating failed."
 * (contract `frontend-relatorios.md` > Capability UI). Os cenários cobrem tanto o formato de
 * erro "function-level" (`error` não nulo, retornado pelo client de Edge Functions) quanto o
 * formato "data-level" (status 200 com corpo `{ error: { code, message } }`), simulando uma
 * chamada direta ao service como se o gate de UI tivesse sido burlado.
 */
describe('relatoriosService - Superfície de negação do backend mesmo com bypass do gate client-side (US3 - T062)', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  const MSG_PERMISSION_DENIED = 'Usuario sem permissao para exportar relatorios.'
  const MSG_INVALID_CATEGORY = 'Categoria de relatorio invalida ou fora do escopo de exportacao.'

  it('exportarRelatorio propaga PERMISSION_DENIED (erro function-level) mesmo chamado diretamente, sem gate de UI', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', null, { message: MSG_PERMISSION_DENIED })

    // Simula um usuário/perfil sem `relatorios.exportar` chamando o service diretamente,
    // como se o botão "Exportar Relatório" não tivesse sido ocultado pela UI (bypass do gate).
    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow(MSG_PERMISSION_DENIED)
  })

  it('exportarRelatorio propaga INVALID_CATEGORY (erro function-level) quando a categoria não é exportável para o perfil', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', null, { message: MSG_INVALID_CATEGORY })

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Personalizado',
        formato: 'CSV',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow(MSG_INVALID_CATEGORY)
  })

  it('exportarRelatorio propaga PERMISSION_DENIED quando vem no corpo de resposta (data-level, status 200 com { error })', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', {
      error: { code: 'PERMISSION_DENIED', message: MSG_PERMISSION_DENIED }
    })

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Projetos',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow(MSG_PERMISSION_DENIED)
  })

  it('exportarRelatorio propaga INVALID_CATEGORY quando vem no corpo de resposta (data-level, status 200 com { error })', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', {
      error: { code: 'INVALID_CATEGORY', message: MSG_INVALID_CATEGORY }
    })

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Personalizado',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow(MSG_INVALID_CATEGORY)
  })

  it('exportarRelatorio rejeita com mensagem de fallback (não trava/ resolve como sucesso) quando o backend envia apenas o code, sem message amigável', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', {
      error: { code: 'PERMISSION_DENIED' }
    })

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow(/erro ao exportar relat[oó]rio/i)
  })

  it('baixarExportacaoRelatorio propaga PERMISSION_DENIED (erro function-level) mesmo chamado diretamente, sem gate de UI', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', null, {
      message: 'Usuario sem permissao para baixar a exportacao.'
    })

    await expect(
      relatoriosService.baixarExportacaoRelatorio({ exportacao_id: 'export-uuid-1' })
    ).rejects.toThrow('Usuario sem permissao para baixar a exportacao.')
  })

  it('baixarExportacaoRelatorio propaga negação quando vem no corpo de resposta (data-level, status 200 com { error })', async () => {
    mockSupabaseFunctionsInvoke('relatorios-exportacao', {
      error: { code: 'PERMISSION_DENIED', message: 'Usuario sem permissao para baixar a exportacao.' }
    })

    await expect(
      relatoriosService.baixarExportacaoRelatorio({ exportacao_id: 'export-uuid-1' })
    ).rejects.toThrow('Usuario sem permissao para baixar a exportacao.')
  })
})

/**
 * Testes de regressão (T065) para o formato REAL de erro devolvido por
 * `@supabase/functions-js` quando a Edge Function responde HTTP não-2xx
 * (todo código de negócio de `relatorios-exportacao` mapeia para não-2xx —
 * ver `_shared.ts` > `DEFAULT_STATUS_BY_CODE`): o client lança
 * `FunctionsHttpError`, cujo `error.message` é SEMPRE o texto técnico
 * genérico "Edge Function returned a non-2xx status code", nunca a mensagem
 * de negócio. A mensagem real fica no corpo JSON ainda não consumido em
 * `error.context` (um `Response`). Os testes anteriores (T062) mockavam
 * `error` como `{ message: '<mensagem amigável>' }`, o que não reflete esse
 * comportamento real e mascararia uma regressão nesse caminho — por isso
 * simulamos aqui o formato real com `error.context.json()`.
 */
describe('relatoriosService - mensagens amigáveis a partir do corpo real de FunctionsHttpError (T065)', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  function mockFunctionsHttpError(corpoErro: { code: string; message?: string }) {
    return {
      name: 'FunctionsHttpError',
      message: 'Edge Function returned a non-2xx status code',
      context: {
        json: async () => ({ error: corpoErro })
      }
    }
  }

  it('exportarRelatorio extrai a mensagem amigável do corpo de um FunctionsHttpError real, em vez do texto técnico genérico', async () => {
    mockSupabaseFunctionsInvoke(
      'relatorios-exportacao',
      null,
      mockFunctionsHttpError({
        code: 'PERMISSION_DENIED',
        message: 'Usuario sem permissao para exportar relatorios.'
      })
    )

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow('Usuario sem permissao para exportar relatorios.')
  })

  it('exportarRelatorio nunca propaga o texto técnico "Edge Function returned a non-2xx status code" ao usuário final', async () => {
    mockSupabaseFunctionsInvoke(
      'relatorios-exportacao',
      null,
      mockFunctionsHttpError({
        code: 'INVALID_CATEGORY',
        message: 'Categoria de relatorio invalida ou fora do escopo de exportacao.'
      })
    )

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Personalizado',
        formato: 'CSV',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.not.toThrow(/non-2xx/i)
  })

  it('exportarRelatorio usa o mapa local de mensagens amigáveis por código quando o corpo do FunctionsHttpError não traz message', async () => {
    mockSupabaseFunctionsInvoke(
      'relatorios-exportacao',
      null,
      mockFunctionsHttpError({ code: 'EXPORT_TOO_LARGE' })
    )

    await expect(
      relatoriosService.exportarRelatorio({
        tipo: 'Projetos',
        formato: 'CSV',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31'
      })
    ).rejects.toThrow(/grande demais para download imediato/i)
  })

  it('baixarExportacaoRelatorio extrai a mensagem amigável do corpo de um FunctionsHttpError real (ex.: EXPORT_EXPIRED)', async () => {
    mockSupabaseFunctionsInvoke(
      'relatorios-exportacao',
      null,
      mockFunctionsHttpError({ code: 'EXPORT_EXPIRED', message: 'Exportacao expirada.' })
    )

    await expect(
      relatoriosService.baixarExportacaoRelatorio({ exportacao_id: 'export-uuid-expirado' })
    ).rejects.toThrow('Exportacao expirada.')
  })
})
