import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'

// Configura as variáveis de ambiente necessárias para a inicialização do módulo.
// Apontamos para uma porta mock local que simularemos usando Deno.serve para interceptar chamadas RPC/Storage.
Deno.env.set('SUPABASE_URL', 'http://127.0.0.1:54321')
Deno.env.set('SUPABASE_ANON_KEY', 'test-anon-key')

// Mock do Servidor do Supabase (para interceptar as chamadas feitas por index.ts)
const mockSupabaseServer = Deno.serve({ port: 54321 }, async (req) => {
  const url = new URL(req.url)

  // Mock da RPC iniciar_exportacao_relatorio
  if (url.pathname === '/rest/v1/rpc/iniciar_exportacao_relatorio') {
    return new Response(JSON.stringify({
      exportacao_id: '88888888-8888-8888-8888-888888888888',
      exportacao_tipo: 'Financeiro',
      exportacao_formato: 'PDF',
      data_inicial: '2026-07-01',
      data_final: '2026-07-31',
      lancamentos: []
    }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  }

  // Mock da RPC concluir_exportacao_relatorio
  if (url.pathname === '/rest/v1/rpc/concluir_exportacao_relatorio') {
    return new Response(JSON.stringify({
      gerado_em: '2026-07-09T10:00:00Z',
      expira_em: '2026-07-09T10:10:00Z'
    }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  }

  // Mock da RPC autorizar_download_exportacao_relatorio
  if (url.pathname === '/rest/v1/rpc/autorizar_download_exportacao_relatorio') {
    return new Response(JSON.stringify({
      id: '88888888-8888-8888-8888-888888888888',
      arquivo_path: 'relatorios-exportados/uuid/financeiro.pdf',
      arquivo_nome: 'relatorio-financeiro-2026-07-01-2026-07-31.pdf',
      mime_type: 'application/pdf',
      expira_em: '2026-07-09T10:10:00Z'
    }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  }

  // Mock do Storage Upload
  if (url.pathname.startsWith('/storage/v1/object/relatorios-exportados')) {
    return new Response(JSON.stringify({ Key: 'relatorios-exportados/path' }), { status: 200 })
  }

  // Mock do Storage Signed URL
  if (url.pathname.startsWith('/storage/v1/object/sign/relatorios-exportados')) {
    return new Response(JSON.stringify({
      signedURL: 'http://127.0.0.1:54321/storage/v1/object/sign/relatorios-exportados/file.pdf?token=123'
    }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  }

  return new Response('Not Found', { status: 404 })
})

// Agora importamos a Edge Function (que iniciará Deno.serve na porta default 8000)
import './index.ts'

const BASE_URL = 'http://127.0.0.1:8000'

Deno.test({
  name: 'OPTIONS preflight is handled without requiring authentication',
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, { method: 'OPTIONS' })
    assertEquals(res.status, 200)
    await res.body?.cancel()
  },
})

Deno.test({
  name: 'rejects requests without an Authorization header with PERMISSION_DENIED',
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'gerar' }),
    })
    const json = await res.json()

    assertEquals(res.status, 403)
    assertEquals(json.error.code, 'PERMISSION_DENIED')
  },
})

Deno.test({
  name: 'rejects an unknown/missing action with INVALID_REQUEST',
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer fake-jwt-for-test',
      },
      body: JSON.stringify({ action: 'nao-existe' }),
    })
    const json = await res.json()

    assertEquals(res.status, 400)
    assertEquals(json.error.code, 'INVALID_REQUEST')
  },
})

Deno.test({
  name: "gerar action emits an observability log/event and returns signed URL and metadata",
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const originalLog = console.log
    const originalError = console.error
    const captured: string[] = []

    console.log = (...args: unknown[]) => {
      captured.push(args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' '))
    }
    console.error = (...args: unknown[]) => {
      captured.push(args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' '))
    }

    try {
      const res = await fetch(BASE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer fake-jwt-for-test',
        },
        body: JSON.stringify({
          action: 'gerar',
          tipo: 'Financeiro',
          formato: 'PDF',
          data_inicial: '2026-07-01',
          data_final: '2026-07-31',
        }),
      })
      const json = await res.json()

      assertEquals(res.status, 200)
      assert(json.download_url.includes('token=123'))
      assertEquals(json.exportacao.status_exibicao, 'Pronto')
    } finally {
      console.log = originalLog
      console.error = originalError
    }

    const combinedOutput = captured.join('\n')
    const requiredObservabilityFields = [
      'exportacao_id',
      'usuario_id',
      'tipo',
      'formato',
      'data_inicial',
      'data_final',
      'status',
      'duracao_ms',
    ]

    for (const field of requiredObservabilityFields) {
      assert(
        combinedOutput.includes(field),
        `esperado log de observabilidade contendo o campo "${field}" para a acao 'gerar'`
      )
    }
  },
})

Deno.test({
  name: "download action authorizes and returns signed URL",
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer fake-jwt-for-test',
      },
      body: JSON.stringify({
        action: 'download',
        exportacao_id: '88888888-8888-8888-8888-888888888888',
      }),
    })
    const json = await res.json()

    assertEquals(res.status, 200)
    assert(json.download_url.includes('token=123'))
    assertEquals(json.exportacao.arquivo_nome, 'relatorio-financeiro-2026-07-01-2026-07-31.pdf')
  },
})

Deno.test({
  name: "download action rejects invalid UUID",
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer fake-jwt-for-test',
      },
      body: JSON.stringify({
        action: 'download',
        exportacao_id: 'invalido-uuid-123',
      }),
    })
    const json = await res.json()

    assertEquals(res.status, 400)
    assertEquals(json.error.code, 'INVALID_REQUEST')
  },
})

// Fechamento dos servidores ao fim da suite de testes
Deno.test({
  name: "cleanup servers",
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    await mockSupabaseServer.shutdown()
  }
})
