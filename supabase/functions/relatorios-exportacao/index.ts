// Edge Function: relatorios-exportacao
//
// Contract: specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
// Plan: specs/008-exportar-relatorios/plan.md
//
// Responsibilities (per contract):
// - Authenticate the request via `Authorization: Bearer <user_jwt>`.
// - Action `gerar`: validate input, call `iniciar_exportacao_relatorio` with
//   the user JWT, render PDF/CSV(ZIP), upload to the private
//   `relatorios-exportados` bucket, call `concluir_exportacao_relatorio` (or
//   `falhar_exportacao_relatorio` on error), create a short-lived signed URL
//   (`download_expires_in = 600`) and return export metadata.
// - Action `download`: call `autorizar_download_exportacao_relatorio` with
//   the user JWT, create a short-lived signed URL and return it.
// - Never return service role secrets or a public permanent object URL.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8'
import { handleCors, jsonError, jsonResponse, type ExportacaoErrorCode } from './_shared.ts'
import { renderCsvZip, renderPdf, assertWithinSizeLimits } from './renderers.ts'
import {
  buildArquivoNome,
  buildArquivoPath,
  buildRelatorioExportPayload,
  type AutorizarDownloadResult,
  type IniciarExportacaoResult,
} from './payload.ts'

const STORAGE_BUCKET = 'relatorios-exportados'
const DOWNLOAD_EXPIRES_IN = 600 // seconds (10 minutes), per contract.

type ExportacaoAction = 'gerar' | 'download'

interface ExportacaoRequestBody {
  action?: ExportacaoAction
  // `gerar` fields
  tipo?: string
  formato?: string
  data_inicial?: string
  data_final?: string
  // `download` fields
  exportacao_id?: string
}

/**
 * Creates a Supabase client scoped to the requesting user's JWT, so that
 * RPC calls made through it are authorized as that user (per contract:
 * "Must create a user-scoped Supabase client using the incoming JWT for
 * RPC authorization").
 */
function createUserScopedClient(req: Request) {
  const authHeader = req.headers.get('Authorization') ?? ''
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: authHeader },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  })
}

/**
 * Creates a service-role-scoped Supabase client, used *only* for private
 * Storage upload/signing, and only ever called after the user-scoped RPC
 * (`iniciar_exportacao_relatorio`) has already authorized the operation (per
 * contract: "May use service role only inside the function for private
 * Storage upload/signing after the user-scoped RPC authorizes the
 * operation"). The service role key never leaves this process: it is not
 * logged, not echoed back in any response, and this client is never used to
 * call business RPCs (those always go through the user-scoped client so
 * `auth.uid()`-based ownership checks keep working).
 */
function createServiceRoleClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  })
}

/**
 * Best-effort extraction of the `sub` claim from the incoming JWT, used only
 * for observability logging (never for authorization decisions — actual
 * authorization always happens server-side via `auth.uid()` inside the
 * RPCs). Decoding is local (no network round-trip to Auth) and tolerant of
 * malformed/absent tokens, returning `null` rather than throwing.
 */
function extractUsuarioIdFromAuthHeader(authHeader: string | null): string | null {
  if (!authHeader) return null
  const token = authHeader.replace(/^Bearer\s+/i, '').trim()
  const parts = token.split('.')
  if (parts.length < 2) return null

  try {
    const base64Url = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const padded = base64Url.padEnd(base64Url.length + ((4 - (base64Url.length % 4)) % 4), '=')
    const payload = JSON.parse(atob(padded))
    return typeof payload?.sub === 'string' ? payload.sub : null
  } catch {
    return null
  }
}

/** Validates `yyyy-mm-dd` strings that also round-trip to a real calendar date. */
function isValidIsoDateString(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value
}

/**
 * Validates that `value` looks like a UUID before it is ever sent to the
 * `autorizar_download_exportacao_relatorio` RPC. Without this check, a
 * malformed id (e.g. `"abc"`) would reach Postgres and fail with a generic
 * `invalid input syntax for type uuid` error that `mapRpcErrorToCode` cannot
 * recognize (it would fall back to `GENERATION_FAILED`, which is misleading
 * for what is really a client request-shape problem) instead of the more
 * accurate `INVALID_REQUEST`.
 */
function isValidUuidString(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
  )
}

// RPC error messages that map 1:1 to contract error codes: the migration's
// RPCs raise `RAISE EXCEPTION '<CODE>' USING DETAIL = '<mensagem amigavel>'`
// for every business rule, so `error.message` from supabase-js is exactly
// one of these codes when the RPC rejected the request for a known reason.
const KNOWN_RPC_ERROR_CODES: readonly ExportacaoErrorCode[] = [
  'INVALID_PERIOD',
  'PERIOD_TOO_LONG',
  'INVALID_FORMAT',
  'INVALID_CATEGORY',
  'PERMISSION_DENIED',
  'EXPORT_NOT_FOUND',
  'EXPORT_EXPIRED',
  'EXPORT_NOT_READY',
  'EXPORT_TOO_LARGE',
]

/** Friendly (Portuguese) fallback message per error code, used when no safe detail is available. */
const FRIENDLY_MESSAGE_BY_CODE: Record<ExportacaoErrorCode, string> = {
  INVALID_PERIOD: 'Periodo invalido. Verifique as datas informadas.',
  PERIOD_TOO_LONG: 'O periodo maximo permitido para exportacao e de 12 meses.',
  INVALID_FORMAT: 'Formato de exportacao invalido. Utilize PDF ou CSV.',
  INVALID_CATEGORY: 'Categoria de relatorio invalida ou fora do escopo de exportacao.',
  PERMISSION_DENIED: 'Usuario sem permissao para exportar relatorios.',
  EXPORT_NOT_FOUND: 'Exportacao nao encontrada.',
  EXPORT_EXPIRED: 'Exportacao expirada.',
  EXPORT_NOT_READY: 'Exportacao ainda nao esta pronta para download.',
  GENERATION_FAILED: 'Falha ao gerar a exportacao. Tente novamente mais tarde.',
  STORAGE_FAILED: 'Falha ao salvar o arquivo da exportacao. Tente novamente mais tarde.',
  EXPORT_TOO_LARGE: 'A exportacao excede o limite de linhas/tamanho permitido.',
  INVALID_REQUEST: 'Requisicao invalida.',
}

/**
 * Maps a raw RPC error (from `iniciar_exportacao_relatorio`,
 * `concluir_exportacao_relatorio` or `falhar_exportacao_relatorio`) to a
 * contract error code. `Unauthorized` (auth.uid() IS NULL, e.g. an
 * expired/invalid JWT reaching the RPC) and `Forbidden` (ownership check)
 * both surface to the client as `PERMISSION_DENIED`. Anything else
 * (network failures, unexpected Postgres errors) defaults to
 * `GENERATION_FAILED` so no internal detail is ever inferred as a business
 * code by accident.
 */
function mapRpcErrorToCode(message: string | undefined | null): ExportacaoErrorCode {
  if (message && (KNOWN_RPC_ERROR_CODES as readonly string[]).includes(message)) {
    return message as ExportacaoErrorCode
  }
  if (message === 'Unauthorized' || message === 'Forbidden') {
    return 'PERMISSION_DENIED'
  }
  return 'GENERATION_FAILED'
}

// Codes whose `detail` text is always authored by us in the migration (safe,
// non-sensitive, user-facing Portuguese copy) and therefore safe to forward
// verbatim to the client instead of the generic fallback message.
const CODES_WITH_SAFE_DETAIL: readonly ExportacaoErrorCode[] = [
  'INVALID_PERIOD',
  'PERIOD_TOO_LONG',
  'INVALID_FORMAT',
  'INVALID_CATEGORY',
  'PERMISSION_DENIED',
  'EXPORT_NOT_FOUND',
  'EXPORT_EXPIRED',
  'EXPORT_NOT_READY',
]

function messageForCode(code: ExportacaoErrorCode, detail?: string | null): string {
  if (detail && (CODES_WITH_SAFE_DETAIL as readonly string[]).includes(code)) {
    return detail
  }
  return FRIENDLY_MESSAGE_BY_CODE[code]
}

/** Truncates/stringifies an unknown thrown value into a bounded, loggable string (no stack traces). */
function toSanitizedErrorText(error: unknown): string {
  const text = error instanceof Error ? error.message : String(error)
  return text.slice(0, 500)
}

/**
 * Structured observability logger for the `gerar` (T037) and `download`
 * (T052) actions. Emits a single JSON line per lifecycle event so it can be
 * grepped/ingested by any log pipeline, always including the fields required
 * by edge-function-exportacao.md > Observability: `exportacao_id`,
 * `usuario_id`, `tipo`, `formato`, `data_inicial`, `data_final`, `status`,
 * `duracao_ms`, plus `tamanho_bytes` (when available) and a sanitized error
 * (when applicable). Uses `console.error` for failure/denial events so they
 * are easy to separate from normal operational logs.
 *
 * For `exportacao_download_autorizado`/`exportacao_download_negado`, `tipo`/
 * `formato`/`dataInicial`/`dataFinal` are always `null`: unlike `gerar`, the
 * `download` request body only carries `exportacao_id`, and
 * `autorizar_download_exportacao_relatorio` intentionally returns only
 * Storage/file metadata (see `AutorizarDownloadResult` in payload.ts), not
 * the report category/format/period. That full detail is not lost — the RPC
 * itself already records it in `public.audit_log` via
 * `registrar_evento_exportacao` for both the authorized and denied paths —
 * this Edge Function log is a secondary, grep-able layer scoped to what is
 * available in-process without an extra round-trip.
 */
function logExportacaoEvento(
  evento:
    | 'exportacao_relatorio_iniciada'
    | 'exportacao_relatorio_concluida'
    | 'exportacao_relatorio_falhou'
    | 'exportacao_download_autorizado'
    | 'exportacao_download_negado',
  fields: {
    exportacaoId: string | null
    usuarioId: string | null
    tipo: string | null
    formato: string | null
    dataInicial: string | null
    dataFinal: string | null
    status: string
    duracaoMs: number
    tamanhoBytes?: number | null
    erro?: string | null
  },
) {
  const entry = {
    evento,
    exportacao_id: fields.exportacaoId,
    usuario_id: fields.usuarioId,
    tipo: fields.tipo,
    formato: fields.formato,
    data_inicial: fields.dataInicial,
    data_final: fields.dataFinal,
    status: fields.status,
    duracao_ms: fields.duracaoMs,
    tamanho_bytes: fields.tamanhoBytes ?? null,
    erro: fields.erro ?? null,
  }

  if (evento === 'exportacao_relatorio_falhou' || evento === 'exportacao_download_negado') {
    console.error(JSON.stringify(entry))
  } else {
    console.log(JSON.stringify(entry))
  }
}

/**
 * Reports a mid-flight failure to the backend (`falhar_exportacao_relatorio`)
 * without letting a problem in the reporting call itself mask the original
 * error. Uses the user-scoped client, since the RPC enforces
 * `criado_por = auth.uid()` ownership (see migration comment on decision #7).
 */
async function reportFalha(
  client: ReturnType<typeof createUserScopedClient>,
  exportacaoId: string,
  erro: string,
): Promise<void> {
  try {
    const { error } = await client.rpc('falhar_exportacao_relatorio', {
      p_exportacao_id: exportacaoId,
      p_erro: erro,
    })
    if (error) {
      console.error(
        JSON.stringify({
          evento: 'exportacao_relatorio_falhar_rpc_erro',
          exportacao_id: exportacaoId,
          erro: toSanitizedErrorText(error.message ?? error),
        }),
      )
    }
  } catch (unexpected) {
    console.error(
      JSON.stringify({
        evento: 'exportacao_relatorio_falhar_rpc_erro',
        exportacao_id: exportacaoId,
        erro: toSanitizedErrorText(unexpected),
      }),
    )
  }
}

/**
 * Implements the `gerar` action flow described in the contract:
 * 1. Validate `tipo`, `formato`, `data_inicial`, `data_final`.
 * 2. Call `iniciar_exportacao_relatorio` via the user-scoped client.
 * 3. Render the file (see renderers.ts) and upload it to the private
 *    `relatorios-exportados` bucket (service role, only after RPC
 *    authorization succeeded).
 * 4. Call `concluir_exportacao_relatorio` on success or
 *    `falhar_exportacao_relatorio` on failure.
 * 5. Create a short-lived signed URL and return
 *    `{ exportacao, download_url, download_expires_in: 600 }`.
 * 6. Emit observability logs/events (exportacao_id, usuario_id, tipo,
 *    formato, datas, status, duracao_ms, tamanho_bytes, erro sanitizado).
 */
async function handleGerar(
  client: ReturnType<typeof createUserScopedClient>,
  body: ExportacaoRequestBody,
  authHeader: string | null,
): Promise<Response> {
  const startedAt = Date.now()
  const usuarioId = extractUsuarioIdFromAuthHeader(authHeader)

  const tipo = typeof body.tipo === 'string' && body.tipo.length > 0 ? body.tipo : null
  const formato = typeof body.formato === 'string' && body.formato.length > 0 ? body.formato : null
  const dataInicial = typeof body.data_inicial === 'string' && body.data_inicial.length > 0
    ? body.data_inicial
    : null
  const dataFinal = typeof body.data_final === 'string' && body.data_final.length > 0
    ? body.data_final
    : null

  // Mutable so later log calls (after the RPC returns) can include it.
  let exportacaoId: string | null = null

  const duracaoMs = () => Date.now() - startedAt

  // --- Structural validation (missing fields / malformed dates) ---------
  // Category/format/period *business* validation (INVALID_CATEGORY,
  // INVALID_FORMAT, INVALID_PERIOD, PERIOD_TOO_LONG, PERMISSION_DENIED) is
  // owned by `iniciar_exportacao_relatorio` itself (see migration
  // 20260704235640), so it is not duplicated here. This block only rejects
  // requests that would otherwise reach the RPC with null/malformed
  // parameters and silently skip those checks (Postgres `IF <null-expr>` is
  // falsy, not an error).
  if (!tipo || !formato || !dataInicial || !dataFinal) {
    logExportacaoEvento('exportacao_relatorio_falhou', {
      exportacaoId,
      usuarioId,
      tipo,
      formato,
      dataInicial,
      dataFinal,
      status: 'Falhou',
      duracaoMs: duracaoMs(),
      erro: 'INVALID_REQUEST: campos obrigatorios ausentes (tipo, formato, data_inicial, data_final).',
    })
    return jsonError(
      'INVALID_REQUEST',
      'Campos obrigatorios ausentes: tipo, formato, data_inicial, data_final.',
    )
  }

  if (!isValidIsoDateString(dataInicial) || !isValidIsoDateString(dataFinal)) {
    logExportacaoEvento('exportacao_relatorio_falhou', {
      exportacaoId,
      usuarioId,
      tipo,
      formato,
      dataInicial,
      dataFinal,
      status: 'Falhou',
      duracaoMs: duracaoMs(),
      erro: 'INVALID_PERIOD: data_inicial/data_final fora do formato ISO (yyyy-mm-dd).',
    })
    return jsonError('INVALID_PERIOD', messageForCode('INVALID_PERIOD'))
  }

  logExportacaoEvento('exportacao_relatorio_iniciada', {
    exportacaoId,
    usuarioId,
    tipo,
    formato,
    dataInicial,
    dataFinal,
    status: 'Iniciando',
    duracaoMs: duracaoMs(),
  })

  try {
    // 1-2. Start the export (auth, capability, category, format and period
    // validation all happen inside this RPC) and get the full report payload.
    const { data: rpcData, error: rpcError } = await client.rpc('iniciar_exportacao_relatorio', {
      p_tipo: tipo,
      p_formato: formato,
      p_data_inicial: dataInicial,
      p_data_final: dataFinal,
    })

    if (rpcError) {
      const code = mapRpcErrorToCode(rpcError.message)
      logExportacaoEvento('exportacao_relatorio_falhou', {
        exportacaoId,
        usuarioId,
        tipo,
        formato,
        dataInicial,
        dataFinal,
        status: 'Falhou',
        duracaoMs: duracaoMs(),
        erro: toSanitizedErrorText(rpcError.message ?? rpcError),
      })
      return jsonError(code, messageForCode(code, rpcError.details ?? rpcError.message))
    }

    const raw = rpcData as IniciarExportacaoResult
    exportacaoId = raw.exportacao_id

    const geradoEmPrevisto = new Date().toISOString()
    const payload = buildRelatorioExportPayload(raw, geradoEmPrevisto)

    // 3a. Enforce the common-volume/size business rule before spending time
    // rendering a file that would be rejected anyway.
    try {
      assertWithinSizeLimits(payload)
    } catch (sizeError) {
      const erroTexto = toSanitizedErrorText(sizeError)
      await reportFalha(client, exportacaoId, erroTexto)
      logExportacaoEvento('exportacao_relatorio_falhou', {
        exportacaoId,
        usuarioId,
        tipo,
        formato,
        dataInicial,
        dataFinal,
        status: 'Falhou',
        duracaoMs: duracaoMs(),
        erro: erroTexto,
      })
      return jsonError('EXPORT_TOO_LARGE', erroTexto)
    }

    // 3b. Render PDF or CSV/ZIP.
    let rendered
    try {
      rendered = payload.formato === 'PDF' ? await renderPdf(payload) : await renderCsvZip(payload)
    } catch (renderError) {
      const erroTexto = toSanitizedErrorText(renderError)
      await reportFalha(client, exportacaoId, erroTexto)
      logExportacaoEvento('exportacao_relatorio_falhou', {
        exportacaoId,
        usuarioId,
        tipo,
        formato,
        dataInicial,
        dataFinal,
        status: 'Falhou',
        duracaoMs: duracaoMs(),
        erro: erroTexto,
      })
      return jsonError('GENERATION_FAILED', messageForCode('GENERATION_FAILED'))
    }

    const arquivoNome = buildArquivoNome(payload)
    const arquivoPath = buildArquivoPath(payload, arquivoNome)

    // 3c. Upload to the private bucket. Service role is required here
    // because authenticated clients have no INSERT policy on this bucket
    // (contracts/storage-and-retention.md: "Upload is performed by Edge
    // Function after RPC authorization"). This client is created lazily,
    // right before it is needed, and is never reused for RPC calls.
    const serviceClient = createServiceRoleClient()
    const { error: uploadError } = await serviceClient.storage
      .from(STORAGE_BUCKET)
      .upload(arquivoPath, rendered.bytes, {
        contentType: rendered.mimeType,
        upsert: false,
      })

    if (uploadError) {
      const erroTexto = toSanitizedErrorText(uploadError)
      await reportFalha(client, exportacaoId, erroTexto)
      logExportacaoEvento('exportacao_relatorio_falhou', {
        exportacaoId,
        usuarioId,
        tipo,
        formato,
        dataInicial,
        dataFinal,
        status: 'Falhou',
        duracaoMs: duracaoMs(),
        erro: erroTexto,
      })
      return jsonError('STORAGE_FAILED', messageForCode('STORAGE_FAILED'))
    }

    // 4. Mark the export as complete in the DB.
    const { data: concluirData, error: concluirError } = await client.rpc(
      'concluir_exportacao_relatorio',
      {
        p_exportacao_id: exportacaoId,
        p_arquivo_path: arquivoPath,
        p_arquivo_nome: arquivoNome,
        p_mime_type: rendered.mimeType,
        p_tamanho_bytes: rendered.tamanhoBytes,
      },
    )

    if (concluirError) {
      // Storage upload succeeded but DB conclusion failed: attempt to clean
      // up the orphaned object per contracts/storage-and-retention.md
      // ("Failure Handling"), then report/log the failure. Cleanup failures
      // are swallowed (best-effort) so they don't mask the original error.
      await serviceClient.storage.from(STORAGE_BUCKET).remove([arquivoPath]).catch(() => {})

      const erroTexto = toSanitizedErrorText(concluirError.message ?? concluirError)
      await reportFalha(client, exportacaoId, erroTexto)
      logExportacaoEvento('exportacao_relatorio_falhou', {
        exportacaoId,
        usuarioId,
        tipo,
        formato,
        dataInicial,
        dataFinal,
        status: 'Falhou',
        duracaoMs: duracaoMs(),
        erro: erroTexto,
      })
      return jsonError('GENERATION_FAILED', messageForCode('GENERATION_FAILED'))
    }

    // 5. Short-lived signed URL. No public/permanent URL is ever created or
    // returned (contract: "Must never return ... a public permanent object
    // URL").
    const { data: signedData, error: signedError } = await serviceClient.storage
      .from(STORAGE_BUCKET)
      .createSignedUrl(arquivoPath, DOWNLOAD_EXPIRES_IN)

    if (signedError || !signedData?.signedUrl) {
      // File is stored and the DB already says `Pronto`; this is a
      // deliverability problem, not a generation problem, so we surface
      // STORAGE_FAILED without rolling back the completed record (the user
      // can retry the `download` action later once Storage is healthy).
      const erroTexto = toSanitizedErrorText(signedError ?? 'signed URL vazia')
      logExportacaoEvento('exportacao_relatorio_falhou', {
        exportacaoId,
        usuarioId,
        tipo,
        formato,
        dataInicial,
        dataFinal,
        status: 'Falhou',
        duracaoMs: duracaoMs(),
        tamanhoBytes: rendered.tamanhoBytes,
        erro: erroTexto,
      })
      return jsonError('STORAGE_FAILED', messageForCode('STORAGE_FAILED'))
    }

    logExportacaoEvento('exportacao_relatorio_concluida', {
      exportacaoId,
      usuarioId,
      tipo,
      formato,
      dataInicial,
      dataFinal,
      status: 'Pronto',
      duracaoMs: duracaoMs(),
      tamanhoBytes: rendered.tamanhoBytes,
    })

    return jsonResponse({
      exportacao: {
        id: exportacaoId,
        tipo: payload.tipo,
        formato: payload.formato,
        status_exibicao: 'Pronto',
        data_inicial: payload.periodo.data_inicial,
        data_final: payload.periodo.data_final,
        arquivo_nome: arquivoNome,
        mime_type: rendered.mimeType,
        gerado_em: concluirData?.gerado_em ?? geradoEmPrevisto,
        expira_em: concluirData?.expira_em ?? null,
      },
      download_url: signedData.signedUrl,
      download_expires_in: DOWNLOAD_EXPIRES_IN,
    })
  } catch (unexpected) {
    // Safety net for anything not already handled above (e.g. a thrown
    // network error from `client.rpc(...)` itself, rather than a returned
    // `{ error }`). If we already have an exportacao_id, still try to mark
    // the record as failed so it doesn't stay stuck in `Pendente` forever.
    const erroTexto = toSanitizedErrorText(unexpected)
    if (exportacaoId) {
      await reportFalha(client, exportacaoId, erroTexto)
    }
    logExportacaoEvento('exportacao_relatorio_falhou', {
      exportacaoId,
      usuarioId,
      tipo,
      formato,
      dataInicial,
      dataFinal,
      status: 'Falhou',
      duracaoMs: duracaoMs(),
      erro: erroTexto,
    })
    return jsonError('GENERATION_FAILED', messageForCode('GENERATION_FAILED'))
  }
}

/**
 * Implements the `download` action flow described in the contract:
 * 1. Call `autorizar_download_exportacao_relatorio(exportacao_id)` via the
 *    user-scoped client (JWT-authorized, so ownership/perfil/categoria/
 *    expiration rules are enforced server-side exactly as for `gerar`'s
 *    RPCs — see migration 20260704235640, T014).
 * 2. If authorized, use the service-role client *only* to create a
 *    short-lived signed URL (`DOWNLOAD_EXPIRES_IN` = 600s) for the
 *    `arquivo_path` the RPC returned. No public/permanent URL is ever
 *    created (contract: "Must never return ... a public permanent object
 *    URL").
 * 3. Return `{ exportacao, download_url, download_expires_in: 600 }`.
 * 4. If the RPC denies (not found/expired/not ready/no permission), map its
 *    error to the matching contract code via `mapRpcErrorToCode` (all
 *    download-relevant codes — EXPORT_NOT_FOUND, EXPORT_EXPIRED,
 *    EXPORT_NOT_READY, PERMISSION_DENIED — are already known codes, so no
 *    new code is needed).
 * 5. Emit observability logs/events for authorized/denied downloads (T052).
 */
async function handleDownload(
  client: ReturnType<typeof createUserScopedClient>,
  body: ExportacaoRequestBody,
  authHeader: string | null,
): Promise<Response> {
  const startedAt = Date.now()
  const usuarioId = extractUsuarioIdFromAuthHeader(authHeader)
  const duracaoMs = () => Date.now() - startedAt

  // Fields required by `logExportacaoEvento`'s shape but not knowable for
  // `download` (see the doc-comment on `logExportacaoEvento` for why).
  const semCategoriaFormatoPeriodo = { tipo: null, formato: null, dataInicial: null, dataFinal: null }

  const exportacaoIdRaw = body.exportacao_id

  if (!isValidUuidString(exportacaoIdRaw)) {
    logExportacaoEvento('exportacao_download_negado', {
      exportacaoId: typeof exportacaoIdRaw === 'string' ? exportacaoIdRaw : null,
      usuarioId,
      ...semCategoriaFormatoPeriodo,
      status: 'Rejeitado',
      duracaoMs: duracaoMs(),
      erro: 'INVALID_REQUEST: exportacao_id ausente ou com formato invalido.',
    })
    return jsonError('INVALID_REQUEST', 'Campo obrigatorio invalido: exportacao_id (uuid).')
  }

  const exportacaoId = exportacaoIdRaw

  try {
    // 1. Authorize (ownership, perfil, categoria, status "Pronto" and
    // expiration are all enforced inside the RPC).
    const { data: rpcData, error: rpcError } = await client.rpc(
      'autorizar_download_exportacao_relatorio',
      { p_exportacao_id: exportacaoId },
    )

    if (rpcError) {
      const code = mapRpcErrorToCode(rpcError.message)
      logExportacaoEvento('exportacao_download_negado', {
        exportacaoId,
        usuarioId,
        ...semCategoriaFormatoPeriodo,
        status: 'Negado',
        duracaoMs: duracaoMs(),
        erro: toSanitizedErrorText(rpcError.message ?? rpcError),
      })
      return jsonError(code, messageForCode(code, rpcError.details ?? rpcError.message))
    }

    const autorizacao = rpcData as AutorizarDownloadResult

    if (!autorizacao?.arquivo_path) {
      // Defensive: the RPC authorized the request but did not return a
      // usable Storage path (should not happen given the migration's
      // contract, but a signed URL must never be attempted without one).
      const erroTexto = 'RPC autorizou o download, mas nao retornou arquivo_path.'
      logExportacaoEvento('exportacao_download_negado', {
        exportacaoId,
        usuarioId,
        ...semCategoriaFormatoPeriodo,
        status: 'Negado',
        duracaoMs: duracaoMs(),
        erro: erroTexto,
      })
      return jsonError('EXPORT_NOT_READY', messageForCode('EXPORT_NOT_READY'))
    }

    // 2. Short-lived signed URL only, via service role, only for the path
    // the RPC already authorized (never derived/guessed by this function).
    const serviceClient = createServiceRoleClient()
    const { data: signedData, error: signedError } = await serviceClient.storage
      .from(STORAGE_BUCKET)
      .createSignedUrl(autorizacao.arquivo_path, DOWNLOAD_EXPIRES_IN)

    if (signedError || !signedData?.signedUrl) {
      const erroTexto = toSanitizedErrorText(signedError ?? 'signed URL vazia')
      logExportacaoEvento('exportacao_download_negado', {
        exportacaoId,
        usuarioId,
        ...semCategoriaFormatoPeriodo,
        status: 'Negado',
        duracaoMs: duracaoMs(),
        erro: erroTexto,
      })
      return jsonError('STORAGE_FAILED', messageForCode('STORAGE_FAILED'))
    }

    logExportacaoEvento('exportacao_download_autorizado', {
      exportacaoId,
      usuarioId,
      ...semCategoriaFormatoPeriodo,
      status: 'Autorizado',
      duracaoMs: duracaoMs(),
    })

    // 3. Response shape per contract: only file metadata, signed URL and
    // its expiration window — never tipo/formato/period, never a permanent URL.
    return jsonResponse({
      exportacao: {
        id: autorizacao.id ?? exportacaoId,
        arquivo_nome: autorizacao.arquivo_nome,
        mime_type: autorizacao.mime_type,
        expira_em: autorizacao.expira_em,
      },
      download_url: signedData.signedUrl,
      download_expires_in: DOWNLOAD_EXPIRES_IN,
    })
  } catch (unexpected) {
    // Safety net for anything not already handled above (e.g. a thrown
    // network error from `client.rpc(...)` itself, rather than a returned
    // `{ error }`).
    const erroTexto = toSanitizedErrorText(unexpected)
    logExportacaoEvento('exportacao_download_negado', {
      exportacaoId,
      usuarioId,
      ...semCategoriaFormatoPeriodo,
      status: 'Negado',
      duracaoMs: duracaoMs(),
      erro: erroTexto,
    })
    return jsonError('GENERATION_FAILED', messageForCode('GENERATION_FAILED'))
  }
}

Deno.serve(async (req: Request) => {
  const preflight = handleCors(req)
  if (preflight) return preflight

  if (req.method !== 'POST') {
    return jsonError('INVALID_REQUEST', 'Metodo nao suportado, use POST.', 405)
  }

  let body: ExportacaoRequestBody
  try {
    body = await req.json()
  } catch {
    return jsonError('INVALID_REQUEST', 'Corpo da requisicao invalido.')
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return jsonError(
      'PERMISSION_DENIED',
      'Requisicao sem autenticacao (Authorization ausente).',
    )
  }

  const client = createUserScopedClient(req)

  try {
    switch (body.action) {
      case 'gerar':
        return await handleGerar(client, body, authHeader)
      case 'download':
        return await handleDownload(client, body, authHeader)
      default:
        return jsonError(
          'INVALID_REQUEST',
          'Campo "action" deve ser "gerar" ou "download".',
        )
    }
  } catch (error) {
    // Fallback safety net: real generation/download failures must go
    // through `falhar_exportacao_relatorio` per contract; this catch only
    // protects against unexpected scaffold/runtime errors during rollout.
    console.error('relatorios-exportacao unhandled error', error)
    return jsonError(
      'GENERATION_FAILED',
      'Falha inesperada ao processar a exportacao.',
    )
  }
})
