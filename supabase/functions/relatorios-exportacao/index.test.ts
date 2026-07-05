// Tests for index.ts (T029).
//
// Contract: specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
//   > "Observability" section.
// Plan: specs/008-exportar-relatorios/plan.md (Observability model),
// data-model.md ("Observability Model").
//
// Scope of this file: the `gerar`/`download` observability requirement
// (exportacao_id, usuario_id, tipo, formato, data_inicial, data_final,
// status, duracao_ms, tamanho_bytes) plus a couple of sanity checks on the
// HTTP contract already present in the scaffold (CORS, method, auth,
// action routing). CSV escaping, ZIP contents, PDF no-data rendering and the
// EXPORT_TOO_LARGE business rule are covered as unit tests in
// `renderers.test.ts` instead, since they are pure functions there.
//
// Testability constraint (do not "fix" without a separate task): `index.ts`
// calls `Deno.serve(...)` at module top level and does not export a request
// handler, so there is no way to invoke its logic in isolation today. Per
// this task's instructions we must test against today's scaffold as-is
// (no implementation of index.ts), so these tests import the module (which
// starts a real HTTP listener on the Deno.serve default port, 8000) and
// drive it over `fetch`. That listener cannot be closed from here, so all
// tests below disable Deno's resource/op sanitizers. This is a known
// limitation: a future refactor exporting a plain `handleRequest(req)`
// function (guarded by `if (import.meta.main) Deno.serve(handleRequest)`)
// would make this file far more robust and would remove the port-8000
// dependency; that refactor is out of scope for this task.
//
// Runtime: Deno (Supabase Edge Functions). No existing `*.test.ts` file or
// Deno test convention was found elsewhere in `supabase/functions/`, so this
// uses plain `Deno.test` with `https://deno.land/std` assertions.
//
// Suggested run command (from repo root):
//   deno test --allow-net --allow-env supabase/functions/relatorios-exportacao/index.test.ts
//
// Required permissions: --allow-net (server + fetch) and --allow-env
// (SUPABASE_URL / SUPABASE_ANON_KEY read by createUserScopedClient).

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'

// Dummy but well-formed values so `createClient(...)` inside
// `createUserScopedClient` does not throw on an invalid URL before our
// assertions even run.
Deno.env.set('SUPABASE_URL', 'http://127.0.0.1:54321')
Deno.env.set('SUPABASE_ANON_KEY', 'test-anon-key')

// Importing the module executes `Deno.serve(...)` (see index.ts), starting
// a listener on the default port (8000) for the lifetime of this process.
import './index.ts'

const BASE_URL = 'http://127.0.0.1:8000'

// ---------------------------------------------------------------------------
// Sanity checks on the HTTP contract that already exists in the scaffold.
// These are expected to PASS today; they confirm the test harness itself
// (server-on-import + fetch) is wired correctly before we rely on it for the
// observability assertions below.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Observability (the actual T029 requirement for this file).
//
// edge-function-exportacao.md > Observability requires that every `gerar`
// action produce a traceable log/event carrying exportacao_id, usuario_id,
// tipo, formato, data_inicial, data_final, status and duracao_ms (plus
// tamanho_bytes when a file exists, and a sanitized error on failure).
//
// Today, `handleGerar` immediately returns a 501 NOT_IMPLEMENTED response
// without emitting any structured log, so this test is expected to FAIL
// until the real `gerar` flow (T036) emits these fields.
// ---------------------------------------------------------------------------

Deno.test({
  name:
    "gerar action emits an observability log/event with exportacao_id, usuario_id, tipo, formato, data_inicial, data_final, status and duracao_ms",
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
          formato: 'CSV',
          data_inicial: '2026-07-01',
          data_final: '2026-07-31',
        }),
      })
      await res.body?.cancel()
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
        `esperado log de observabilidade contendo o campo "${field}" para a acao 'gerar', ` +
          `mas nenhum log foi emitido (fluxo 'gerar' ainda retorna 501 NOT_IMPLEMENTED sem registrar evento)`,
      )
    }
  },
})
