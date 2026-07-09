// @vitest-environment jsdom

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { dispararDownloadArquivo, obterDadosDownload, gerarNomeArquivoExportacao } from './download'
import type { ExportacaoRelatorioResponse } from '../types/relatorios'

describe('download helpers', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    vi.stubGlobal('URL', {
      createObjectURL: vi.fn(() => 'blob:http://localhost/mock-uuid'),
      revokeObjectURL: vi.fn(),
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  describe('obterDadosDownload', () => {
    it('deve extrair corretamente os dados da resposta da Edge Function', () => {
      const mockResposta: ExportacaoRelatorioResponse = {
        download_url: 'http://localhost/signed-url',
        download_expires_in: 600,
        exportacao: {
          id: 'uuid-123',
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
      }

      const resultado = obterDadosDownload(mockResposta)
      expect(resultado).toEqual({
        url: 'http://localhost/signed-url',
        nomeArquivo: 'relatorio-financeiro.pdf',
        mimeType: 'application/pdf',
        expiresIn: 600,
      })
    })
  })

  describe('gerarNomeArquivoExportacao', () => {
    it('deve gerar o nome do arquivo sanitizado com extensao correta para PDF', () => {
      const nome = gerarNomeArquivoExportacao('Financeiro', '2026-07-01', '2026-07-31', 'PDF')
      expect(nome).toBe('relatorio-financeiro-2026-07-01-2026-07-31.pdf')
    })

    it('deve gerar o nome do arquivo sanitizado com extensao correta para CSV', () => {
      const nome = gerarNomeArquivoExportacao('Projetos e Clientes', '2026-07-01', '2026-07-31', 'CSV')
      expect(nome).toBe('relatorio-projetos-e-clientes-2026-07-01-2026-07-31.zip')
    })
  })

  describe('dispararDownloadArquivo', () => {
    it('deve buscar a URL assinada, criar ObjectURL, simular clique no link e limpar recursos', async () => {
      const mockBlob = new Blob(['conteudo'], { type: 'application/pdf' })
      const mockFetchResponse = {
        ok: true,
        blob: vi.fn().mockResolvedValue(mockBlob),
        statusText: 'OK',
      }
      
      vi.mocked(fetch).mockResolvedValue(mockFetchResponse as any)

      const clickSpy = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {})
      const appendSpy = vi.spyOn(document.body, 'appendChild')
      const removeSpy = vi.spyOn(document.body, 'removeChild')

      await dispararDownloadArquivo('http://localhost/signed-url', 'relatorio.pdf')

      expect(fetch).toHaveBeenCalledWith('http://localhost/signed-url')
      expect(mockFetchResponse.blob).toHaveBeenCalled()
      expect(URL.createObjectURL).toHaveBeenCalledWith(mockBlob)
      
      expect(appendSpy).toHaveBeenCalled()
      expect(clickSpy).toHaveBeenCalled()
      expect(removeSpy).toHaveBeenCalled()
      expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-uuid')
    })

    it('deve lancar erro se o fetch da URL assinada falhar', async () => {
      const mockFetchResponse = {
        ok: false,
        statusText: 'Forbidden',
      }
      
      vi.mocked(fetch).mockResolvedValue(mockFetchResponse as any)

      await expect(
        dispararDownloadArquivo('http://localhost/signed-url', 'relatorio.pdf')
      ).rejects.toThrow('Falha ao obter arquivo para download: Forbidden')

      expect(URL.createObjectURL).not.toHaveBeenCalled()
    })
  })
})
