// Shared helpers for the `relatorios-exportacao` Edge Function.
//
// Contract: specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
//
// This file centralizes CORS handling and the JSON error envelope so that
// `index.ts` (and any future Edge Function added to this project) can reuse
// the same conventions instead of re-implementing them per function.

/**
 * Error codes required by the Edge Function contract.
 * See "Error Responses" section of edge-function-exportacao.md.
 */
export type ExportacaoErrorCode =
  | 'INVALID_PERIOD'
  | 'PERIOD_TOO_LONG'
  | 'INVALID_FORMAT'
  | 'INVALID_CATEGORY'
  | 'PERMISSION_DENIED'
  | 'EXPORT_NOT_FOUND'
  | 'EXPORT_EXPIRED'
  | 'EXPORT_NOT_READY'
  | 'GENERATION_FAILED'
  | 'STORAGE_FAILED'
  | 'EXPORT_TOO_LARGE'
  // Generic fallback for request-shape problems not covered by a named
  // business code above (missing/invalid `action`, malformed JSON body).
  | 'INVALID_REQUEST'

export interface ExportacaoErrorBody {
  error: {
    code: ExportacaoErrorCode
    message: string
  }
}

/**
 * Maps known error codes to a default HTTP status. `index.ts` may override
 * this by passing an explicit status to `jsonError`.
 */
const DEFAULT_STATUS_BY_CODE: Record<ExportacaoErrorCode, number> = {
  INVALID_PERIOD: 400,
  PERIOD_TOO_LONG: 400,
  INVALID_FORMAT: 400,
  INVALID_CATEGORY: 400,
  PERMISSION_DENIED: 403,
  EXPORT_NOT_FOUND: 404,
  EXPORT_EXPIRED: 410,
  EXPORT_NOT_READY: 409,
  GENERATION_FAILED: 500,
  STORAGE_FAILED: 500,
  EXPORT_TOO_LARGE: 413,
  INVALID_REQUEST: 400,
}

// TODO(US1/US2): Replace `*` with the configured application origin(s) for
// local/dev/prod once those are defined for this feature. Keeping `*` for
// now only so the scaffold responds to preflight requests during setup.
const ALLOWED_ORIGIN = '*'

export const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

/**
 * Handles a CORS preflight `OPTIONS` request. Returns `null` when the
 * request is not a preflight request so the caller can continue processing.
 */
export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }
  return null
}

/**
 * Builds a JSON success response with CORS headers applied.
 */
export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
    },
  })
}

/**
 * Builds the standard JSON error envelope required by the contract:
 * `{ "error": { "code": "...", "message": "..." } }`.
 */
export function jsonError(
  code: ExportacaoErrorCode,
  message: string,
  status?: number,
): Response {
  const body: ExportacaoErrorBody = { error: { code, message } }
  return jsonResponse(body, status ?? DEFAULT_STATUS_BY_CODE[code])
}
