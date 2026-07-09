import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { relatoriosService } from './relatorios.service'
import { supabase } from './supabase'

vi.mock('./supabase', () => ({
  supabase: {
    functions: {
      invoke: vi.fn(),
    },
    rpc: vi.fn(),
  },
}))

describe('relatoriosService', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  describe('exportarRelatorio', () => {
    it('deve invocar a Edge Function com a acao gerar e os parametros corretos', async () => {
      const mockResposta = {
        exportacao: {
          id: 'uuid-exportacao-123',
          tipo: 'Financeiro',
          formato: 'PDF',
          status_exibicao: 'Pronto',
          data_inicial: '2026-07-01',
          data_final: '2026-07-31',
          arquivo_nome: 'relatorio-financeiro.pdf',
          mime_type: 'application/pdf',
          gerado_em: '2026-07-09T10:00:00Z',
          expira_em: '2026-07-09T10:10:00Z',
        },
        download_url: 'http://localhost/signed-url',
        download_expires_in: 600,
      }

      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: mockResposta,
        error: null,
      })

      const resultado = await relatoriosService.exportarRelatorio({
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31',
      })

      expect(supabase.functions.invoke).toHaveBeenCalledWith('relatorios-exportacao', {
        body: {
          action: 'gerar',
          tipo: 'Financeiro',
          formato: 'PDF',
          data_inicial: '2026-07-01',
          data_final: '2026-07-31',
        },
      })
      expect(resultado).toEqual(mockResposta)
    })

    it('deve propagar o erro caso a Edge Function falhe', async () => {
      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: null,
        error: {
          message: 'Edge Function returned a non-2xx status code',
          context: {
            json: async () => ({
              error: {
                code: 'PERIOD_TOO_LONG',
                message: 'O periodo maximo permitido para exportacao e de 12 meses.',
              },
            }),
          },
        } as any,
      })

      await expect(
        relatoriosService.exportarRelatorio({
          tipo: 'Financeiro',
          formato: 'PDF',
          data_inicial: '2026-07-01',
          data_final: '2027-08-01',
        })
      ).rejects.toThrow('O periodo maximo permitido para exportacao e de 12 meses.')
    })

    it('deve expor apenas URL assinada de curta duracao e remover arquivo_url permanente', async () => {
      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: {
          exportacao: {
            id: 'uuid-exportacao-123',
            tipo: 'Financeiro',
            formato: 'PDF',
            status_exibicao: 'Pronto',
            data_inicial: '2026-07-01',
            data_final: '2026-07-31',
            arquivo_nome: 'relatorio-financeiro.pdf',
            arquivo_url: 'https://storage.example/public/permanente.pdf',
            mime_type: 'application/pdf',
            gerado_em: '2026-07-09T10:00:00Z',
            expira_em: '2026-07-09T10:10:00Z',
          },
          arquivo_url: 'https://storage.example/public/permanente.pdf',
          download_url: 'https://storage.example/signed/temporaria',
          download_expires_in: 600,
        },
        error: null,
      })

      const resultado = await relatoriosService.exportarRelatorio({
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31',
      })

      expect(resultado.download_expires_in).toBe(600)
      expect((resultado as any).arquivo_url).toBeUndefined()
      expect((resultado.exportacao as any).arquivo_url).toBeUndefined()
    })

    it('deve rejeitar erro de negocio retornado no corpo mesmo com status HTTP de sucesso', async () => {
      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: {
          error: {
            code: 'PERMISSION_DENIED',
            message: 'Usuario sem permissao para exportar relatorios.',
          },
        },
        error: null,
      })

      await expect(
        relatoriosService.exportarRelatorio({
          tipo: 'Financeiro',
          formato: 'PDF',
          data_inicial: '2026-07-01',
          data_final: '2026-07-31',
        })
      ).rejects.toThrow('Usuario sem permissao para exportar relatorios.')
    })
  })

  describe('baixarExportacaoRelatorio', () => {
    it('deve invocar a Edge Function com a acao download e o id correto', async () => {
      const mockResposta = {
        exportacao: {
          id: 'uuid-exportacao-123',
          arquivo_nome: 'relatorio-financeiro.pdf',
          mime_type: 'application/pdf',
          expira_em: '2026-07-09T10:10:00Z',
        },
        download_url: 'http://localhost/signed-url',
        download_expires_in: 600,
      }

      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: mockResposta,
        error: null,
      })

      const resultado = await relatoriosService.baixarExportacaoRelatorio({
        exportacao_id: 'uuid-exportacao-123',
      })

      expect(supabase.functions.invoke).toHaveBeenCalledWith('relatorios-exportacao', {
        body: {
          action: 'download',
          exportacao_id: 'uuid-exportacao-123',
        },
      })
      expect(resultado).toEqual(mockResposta)
    })

    it('deve propagar o erro caso o download falhe por expiracao', async () => {
      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: null,
        error: {
          message: 'Edge Function returned a non-2xx status code',
          context: {
            json: async () => ({
              error: {
                code: 'EXPORT_EXPIRED',
                message: 'Esta exportacao expirou e nao esta mais disponivel para download.',
              },
            }),
          },
        } as any,
      })

      await expect(
        relatoriosService.baixarExportacaoRelatorio({
          exportacao_id: 'uuid-exportacao-123',
        })
      ).rejects.toThrow('Esta exportacao expirou e nao esta mais disponivel para download.')
    })

    it('deve remover arquivo_url permanente da resposta de download', async () => {
      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: {
          exportacao: {
            id: 'uuid-exportacao-123',
            arquivo_nome: 'relatorio-financeiro.pdf',
            arquivo_url: 'https://storage.example/public/permanente.pdf',
            mime_type: 'application/pdf',
            expira_em: '2026-07-09T10:10:00Z',
          },
          arquivo_url: 'https://storage.example/public/permanente.pdf',
          download_url: 'https://storage.example/signed/temporaria',
          download_expires_in: 600,
        },
        error: null,
      })

      const resultado = await relatoriosService.baixarExportacaoRelatorio({
        exportacao_id: 'uuid-exportacao-123',
      })

      expect(resultado.download_expires_in).toBe(600)
      expect((resultado as any).arquivo_url).toBeUndefined()
      expect((resultado.exportacao as any).arquivo_url).toBeUndefined()
    })

    it('deve rejeitar negacao de download retornada no corpo', async () => {
      vi.mocked(supabase.functions.invoke).mockResolvedValue({
        data: {
          error: {
            code: 'PERMISSION_DENIED',
            message: 'Usuario sem permissao para baixar a exportacao.',
          },
        },
        error: null,
      })

      await expect(
        relatoriosService.baixarExportacaoRelatorio({
          exportacao_id: 'uuid-exportacao-123',
        })
      ).rejects.toThrow('Usuario sem permissao para baixar a exportacao.')
    })
  })
})
