/**
 * Helpers de download de arquivos de exportação de relatórios (Feature 008).
 *
 * Os arquivos exportados residem em um bucket privado do Storage. A única forma
 * de acesso é uma URL assinada de curta duração (`download_url`) retornada pela
 * Edge Function `relatorios-exportacao`. Este módulo nunca deve receber, gerar
 * ou reutilizar uma URL pública permanente de Storage.
 */

import type { ExportacaoRelatorioResponse, FormatoRelatorio } from '../types/relatorios'

const EXTENSAO_POR_FORMATO: Record<FormatoRelatorio, string> = {
  PDF: 'pdf',
  CSV: 'zip',
}

export interface DadosDownloadAssinado {
  url: string
  nomeArquivo: string
  mimeType: string
  expiresIn: number
}

/**
 * Extrai os dados necessários para disparar um download a partir da resposta
 * de sucesso da Edge Function `relatorios-exportacao` (ações `gerar` e `download`).
 */
export function obterDadosDownload(resposta: ExportacaoRelatorioResponse): DadosDownloadAssinado {
  return {
    url: resposta.download_url,
    nomeArquivo: resposta.exportacao.arquivo_nome,
    mimeType: resposta.exportacao.mime_type,
    expiresIn: resposta.download_expires_in,
  }
}

/**
 * Monta um nome de arquivo amigável para o download local, a partir da categoria
 * do relatório, do período solicitado e do formato exportado.
 *
 * Exemplo: `gerarNomeArquivoExportacao('Financeiro', '2026-07-01', '2026-07-31', 'PDF')`
 * -> `relatorio-financeiro-2026-07-01-2026-07-31.pdf`
 */
export function gerarNomeArquivoExportacao(
  categoria: string,
  data_inicial: string,
  data_final: string,
  formato: FormatoRelatorio
): string {
  const combiningDiacriticalMarks = new RegExp('[̀-ͯ]', 'g')
  const categoriaSlug = categoria
    .normalize('NFD')
    .replace(combiningDiacriticalMarks, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-+|-+$)/g, '')

  const extensao = EXTENSAO_POR_FORMATO[formato]

  return `relatorio-${categoriaSlug}-${data_inicial}-${data_final}.${extensao}`
}

/**
 * Dispara o download de um arquivo já disponível via URL assinada de curta duração,
 * usando um link temporário (`<a download>`) em vez de navegação direta (evita abrir
 * uma nova aba/troca de contexto e funciona tanto para PDF quanto para o ZIP de CSV).
 */
export function dispararDownloadArquivo(urlAssinada: string, nomeArquivo: string): void {
  const link = document.createElement('a')
  link.href = urlAssinada
  link.download = nomeArquivo
  link.rel = 'noopener'
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}
