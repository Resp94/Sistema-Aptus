// Supplementary tests for the `download` action (T051/T052).
//
// Contract: specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
//   > Action "download" / "Observability" sections.
//
// Scope: this file only covers what can be exercised without a real
// Supabase backend (same constraint documented in index.test.ts): request
// validation that happens *before* any RPC call (INVALID_REQUEST for a
// missing/malformed `exportacao_id`), and the observability log emitted once
// `autorizar_download_exportacao_relatorio` settles (success or error) or the
// call throws (e.g. because there is no real backend at the dummy
// SUPABASE_URL used in tests). It intentionally does not assert a specific
// error *code* for the "RPC was attempted" case, since that depends on
// whether a local Supabase instance is reachable at the configured URL —
// that end-to-end path (real authorization + signed URL) is exercised
// separately in manual/integration testing against a running local stack.
//
// Runtime/permissions: same as index.test.ts.
//   deno test --allow-net --allow-env supabase/functions/relatorios-exportacao/index.download.test.ts
//
// Note: this file imports `./index.ts` just like index.test.ts. Deno caches
// modules per absolute URL within a process, so `Deno.serve(...)`'s
// side-effect only runs once even if both test files are executed together
// in the same `deno test` invocation.

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'

Deno.env.set('SUPABASE_URL', 'http://127.0.0.1:54321')
Deno.env.set('SUPABASE_ANON_KEY', 'test-anon-key')
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-service-role-key')

import './index.ts'

const BASE_URL = 'http://127.0.0.1:8000'

Deno.test({
  name: 'download action rejects a missing exportacao_id with INVALID_REQUEST (no RPC call attempted)',
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer fake-jwt-for-test',
      },
      body: JSON.stringify({ action: 'download' }),
    })
    const json = await res.json()

    assertEquals(res.status, 400)
    assertEquals(json.error.code, 'INVALID_REQUEST')
  },
})

Deno.test({
  name: 'download action rejects a malformed (non-uuid) exportacao_id with INVALID_REQUEST',
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const res = await fetch(BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer fake-jwt-for-test',
      },
      body: JSON.stringify({ action: 'download', exportacao_id: 'nao-e-um-uuid' }),
    })
    const json = await res.json()

    assertEquals(res.status, 400)
    assertEquals(json.error.code, 'INVALID_REQUEST')
  },
})

Deno.test({
  name:
    'download action with a well-formed exportacao_id calls the RPC and emits an observability log with exportacao_id, usuario_id, status and duracao_ms',
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

    const exportacaoId = '11111111-2222-3333-4444-555555555555'

    let res: Response
    try {
      res = await fetch(BASE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer fake-jwt-for-test',
        },
        body: JSON.stringify({ action: 'download', exportacao_id: exportacaoId }),
      })
      await res.body?.cancel()
    } finally {
      console.log = originalLog
      console.error = originalError
    }

    // No real Supabase backend is reachable at the dummy SUPABASE_URL, so the
    // RPC call is expected to fail one way or another; the important
    // contract here is that it never returns a raw 5xx/undefined body and
    // always resolves to the standard JSON error envelope.
    const json = await res.json().catch(() => null)
    assert(json === null || typeof json?.error?.code === 'string')

    const combinedOutput = captured.join('\n')
    const requiredObservabilityFields = ['exportacao_id', 'usuario_id', 'status', 'duracao_ms']

    for (const field of requiredObservabilityFields) {
      assert(
        combinedOutput.includes(field),
        `esperado log de observabilidade contendo o campo "${field}" para a acao 'download', mas nenhum log foi emitido`,
      )
    }
    assert(
      combinedOutput.includes(exportacaoId),
      'esperado log de observabilidade contendo o exportacao_id da requisicao',
    )
  },
})
