import { supabase } from './supabase'
import type {
  ExportacaoRelatorioItem,
  ExportarRelatorioInput,
  ExportacaoRelatorioResponse,
  BaixarExportacaoInput
} from '../types/relatorios'

/**
 * Mensagens amigáveis por código de erro de negócio da Edge Function
 * `relatorios-exportacao` (mesmos códigos de
 * supabase/functions/relatorios-exportacao/_shared.ts ->
 * `ExportacaoErrorCode` / contracts/frontend-relatorios.md > "Error Messages").
 *
 * Usado apenas como *fallback* — o backend já envia uma mensagem amigável em
 * `error.message`/`error.code` na prática; este mapa cobre o caso de defesa
 * em profundidade em que o corpo da resposta traz apenas o código, sem texto
 * (T065).
 */
const MENSAGEM_AMIGAVEL_POR_CODIGO: Record<string, string> = {
  INVALID_PERIOD: 'Período inválido. Verifique as datas informadas.',
  PERIOD_TOO_LONG: 'O período máximo permitido para exportação é de 12 meses.',
  INVALID_FORMAT: 'Formato de exportação inválido. Utilize PDF ou CSV.',
  INVALID_CATEGORY: 'Esta categoria não está disponível para exportação (ainda não possui contrato de exportação completo).',
  PERMISSION_DENIED: 'Você não tem permissão para exportar ou baixar este relatório.',
  EXPORT_NOT_FOUND: 'Exportação não encontrada.',
  EXPORT_EXPIRED: 'Esta exportação expirou e não está mais disponível para download.',
  EXPORT_NOT_READY: 'Esta exportação ainda não está pronta para download.',
  EXPORT_TOO_LARGE: 'Esta exportação é grande demais para download imediato. Reduza o período ou tente novamente mais tarde.'
}

// `@supabase/functions-js` (FunctionsClient#invoke) lança `FunctionsHttpError`
// para QUALQUER resposta HTTP não-2xx da Edge Function — e essa classe sempre
// usa esta mensagem técnica genérica em `error.message`, independentemente do
// corpo JSON real devolvido pela função (ver node_modules/@supabase/functions-js
// src/types.ts -> `FunctionsHttpError`). Como todos os códigos de erro de
// negócio de `relatorios-exportacao` mapeiam para status não-2xx
// (400/403/404/409/410/413 em _shared.ts -> `DEFAULT_STATUS_BY_CODE`), usar
// `error.message` direto (como antes) exibiria sempre este texto técnico ao
// usuário final, nunca a mensagem de negócio real. A mensagem real fica no
// corpo JSON ainda não consumido em `error.context` (um `Response`).
const MENSAGEM_TECNICA_NON_2XX = 'Edge Function returned a non-2xx status code'

async function extrairCorpoErroEdgeFunction(
  error: any
): Promise<{ code?: string; message?: string } | null> {
  const contexto = error?.context
  if (contexto && typeof contexto.json === 'function') {
    try {
      const corpo = await contexto.json()
      if (corpo && corpo.error) {
        return corpo.error
      }
    } catch {
      // Corpo não é JSON válido (ex.: erro de rede/relay) — usa fallback abaixo.
    }
  }
  return null
}

/**
 * Resolve a mensagem amigável final para um erro vindo da Edge Function
 * `relatorios-exportacao`, cobrindo os dois formatos possíveis (T065):
 *
 * - "function-level": `supabase.functions.invoke` retorna `error` preenchido
 *   (ex.: `FunctionsHttpError`). O `error.message` do client é sempre o texto
 *   técnico genérico `MENSAGEM_TECNICA_NON_2XX` — a mensagem de negócio real
 *   precisa ser lida do corpo JSON em `error.context`.
 * - "data-level": a função responde HTTP 200 com `{ error: { code, message } }`
 *   no corpo (`data.error`).
 *
 * Ordem de preferência: mensagem de negócio do backend > mapa local de
 * mensagens amigáveis por código > mensagem padrão do chamador.
 */
async function resolverMensagemErroExportacao(
  error: any,
  data: any,
  mensagemPadrao: string
): Promise<string> {
  const erroDataLevel = data && (data as any).error ? (data as any).error : null
  if (erroDataLevel) {
    return erroDataLevel.message || mensagemPadrao
  }

  if (error) {
    const corpo = await extrairCorpoErroEdgeFunction(error)
    if (corpo) {
      return corpo.message || MENSAGEM_AMIGAVEL_POR_CODIGO[corpo.code || ''] || mensagemPadrao
    }

    if (error.message && error.message !== MENSAGEM_TECNICA_NON_2XX) {
      return error.message
    }
  }

  return mensagemPadrao
}

export const relatoriosService = {
  async listarCategoriasRelatorios(): Promise<string[]> {
    const { data, error } = await supabase.rpc('listar_categorias_relatorios')

    if (error) {
      console.error('Erro ao listar categorias de relatórios:', error)
      throw new Error(error.message || 'Erro ao carregar categorias de relatórios.')
    }

    // A RPC retorna uma tabela com coluna "categoria"
    return (data || []).map((row: any) => row.categoria as string)
  },

  async gerarPreviaRelatorio(tipo: string, filtros: any = {}): Promise<any> {
    const { data, error } = await supabase.rpc('gerar_previa_relatorio', {
      p_tipo: tipo,
      p_filtros: filtros
    })

    if (error) {
      console.error('Erro ao gerar prévia do relatório:', error)
      throw new Error(error.message || 'Erro ao obter pré-visualização.')
    }

    return data
  },

  async listarExportacoesRelatorios(tipo?: string): Promise<ExportacaoRelatorioItem[]> {
    const { data, error } = await supabase.rpc('listar_exportacoes_relatorios', {
      p_tipo: tipo || null
    })

    if (error) {
      console.error('Erro ao listar histórico de exportações:', error)
      throw new Error(error.message || 'Erro ao obter histórico de exportações.')
    }

    return (data || []) as ExportacaoRelatorioItem[]
  },

  /**
   * @deprecated Fluxo legado baseado em RPC direta. Mantido apenas para compatibilidade
   * com código existente; o fluxo de exportação manual (US1) usa `exportarRelatorio`,
   * que invoca a Edge Function `relatorios-exportacao`.
   */
  async solicitarExportacaoRelatorio(
    tipo: string,
    formato: 'PDF' | 'CSV',
    filtros: any = {}
  ): Promise<string> {
    const { data, error } = await supabase.rpc('solicitar_exportacao_relatorio', {
      p_tipo: tipo,
      p_formato: formato,
      p_filtros: filtros
    })

    if (error) {
      console.error('Erro ao solicitar exportação de relatório:', error)
      throw new Error(error.message || 'Erro ao solicitar exportação.')
    }

    return data as string
  },

  /**
   * Fluxo de exportação manual (US1 - T038). Invoca a Edge Function
   * `relatorios-exportacao` com `action: 'gerar'`, repassando categoria, formato
   * e período. A resposta é normalizada para expor apenas a signed URL de curta
   * duração (`download_url`/`download_expires_in`) — nunca um `arquivo_url`
   * público/permanente.
   */
  async exportarRelatorio(
    input: ExportarRelatorioInput
  ): Promise<ExportacaoRelatorioResponse> {
    const { data, error } = await supabase.functions.invoke('relatorios-exportacao', {
      body: {
        action: 'gerar',
        tipo: input.tipo,
        formato: input.formato,
        data_inicial: input.data_inicial,
        data_final: input.data_final
      }
    })

    if (error) {
      console.error('Erro ao exportar relatório:', error)
      throw new Error(await resolverMensagemErroExportacao(error, null, 'Erro ao exportar relatório.'))
    }

    // Defesa extra: algumas versões do client de Edge Functions retornam o corpo
    // de erro em `data` mesmo com `error` nulo (ex.: status HTTP 200 com payload
    // `{ error: { code, message } }`). Trata esse caso como falha também.
    if (!data || (data as any).error) {
      const backendError = (data as any)?.error
      console.error('Erro ao exportar relatório:', backendError)
      throw new Error(await resolverMensagemErroExportacao(null, data, 'Erro ao exportar relatório.'))
    }

    const response = data as ExportacaoRelatorioResponse
    const { exportacao, download_url, download_expires_in } = response

    // Normaliza a resposta: repassa somente os campos de metadados conhecidos,
    // garantindo que nenhum `arquivo_url` (permanente) escape do fluxo — apenas
    // a signed URL de curta duração retornada pela Edge Function.
    return {
      exportacao: {
        id: exportacao.id,
        tipo: exportacao.tipo,
        formato: exportacao.formato,
        status_exibicao: exportacao.status_exibicao,
        data_inicial: exportacao.data_inicial,
        data_final: exportacao.data_final,
        arquivo_nome: exportacao.arquivo_nome,
        mime_type: exportacao.mime_type,
        gerado_em: exportacao.gerado_em,
        expira_em: exportacao.expira_em
      },
      download_url,
      download_expires_in
    }
  },

  /**
   * Fluxo de download de exportação (US2 - T053). Invoca a Edge Function
   * `relatorios-exportacao` com `action: 'download'`, repassando apenas o
   * `exportacao_id`. A resposta é normalizada para expor somente a signed URL
   * de curta duração (`download_url`/`download_expires_in`) — nunca um
   * `arquivo_url` público/permanente.
   */
  async baixarExportacaoRelatorio(
    input: BaixarExportacaoInput
  ): Promise<ExportacaoRelatorioResponse> {
    const { data, error } = await supabase.functions.invoke('relatorios-exportacao', {
      body: {
        action: 'download',
        exportacao_id: input.exportacao_id
      }
    })

    if (error) {
      console.error('Erro ao baixar exportação de relatório:', error)
      throw new Error(
        await resolverMensagemErroExportacao(error, null, 'Erro ao baixar exportação de relatório.')
      )
    }

    // Defesa extra: algumas versões do client de Edge Functions retornam o corpo
    // de erro em `data` mesmo com `error` nulo (ex.: status HTTP 200 com payload
    // `{ error: { code, message } }`). Trata esse caso como falha também.
    if (!data || (data as any).error) {
      const backendError = (data as any)?.error
      console.error('Erro ao baixar exportação de relatório:', backendError)
      throw new Error(
        await resolverMensagemErroExportacao(null, data, 'Erro ao baixar exportação de relatório.')
      )
    }

    const response = data as ExportacaoRelatorioResponse
    const { exportacao, download_url, download_expires_in } = response

    // Normaliza a resposta: repassa somente os campos de metadados conhecidos,
    // garantindo que nenhum `arquivo_url` (permanente) escape do fluxo — apenas
    // a signed URL de curta duração retornada pela Edge Function.
    return {
      exportacao: {
        id: exportacao.id,
        arquivo_nome: exportacao.arquivo_nome,
        mime_type: exportacao.mime_type,
        expira_em: exportacao.expira_em
      },
      download_url,
      download_expires_in
    }
  },

  async agendarRelatorio(payload: {
    tipo: string
    formato: 'PDF' | 'CSV'
    filtros: any
    frequencia: 'Uma vez' | 'Diário' | 'Semanal' | 'Mensal'
    agendado_para?: string | null
  }): Promise<string> {
    const { data, error } = await supabase.rpc('agendar_relatorio', {
      payload
    })

    if (error) {
      console.error('Erro ao agendar relatório:', error)
      throw new Error(error.message || 'Erro ao agendar relatório.')
    }

    return data as string
  }
}
export type RelatoriosService = typeof relatoriosService
