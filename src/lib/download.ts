/**
 * Helpers de download de arquivos de exportação de relatórios (Feature 008 / Feature 011).
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
 * buscando o arquivo via fetch para convertê-lo a Blob e forçar o download local,
 * impedindo qualquer visualização nativa de PDF (preview) do navegador.
 * Realiza o cleanup do Object URL criado com URL.revokeObjectURL.
 */
export async function dispararDownloadArquivo(urlAssinada: string, nomeArquivo: string): Promise<void> {
  const resposta = await fetch(urlAssinada)
  if (!resposta.ok) {
    throw new Error(`Falha ao obter arquivo para download: ${resposta.statusText}`)
  }
  const blob = await resposta.blob()
  const objectUrl = URL.createObjectURL(blob)

  const link = document.createElement('a')
  link.href = objectUrl
  link.download = nomeArquivo
  link.rel = 'noopener'
  document.body.appendChild(link)
  link.click()

  document.body.removeChild(link)
  URL.revokeObjectURL(objectUrl)
}
