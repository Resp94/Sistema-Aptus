import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import RelatoriosPage from './RelatoriosPage'
import { relatoriosService } from '../services/relatorios.service'
import { dispararDownloadArquivo } from '../lib/download'
import { obterPeriodoPadrao, validarPeriodoExportacao } from '../lib/relatorios-periodo'
import { MemoryRouter } from 'react-router-dom'

import { createContext, useContext } from 'react'

const MockAuthContext = createContext<any>(null)
const COPIA_BETA_MODAL =
  'Esta exportação utiliza o padrão executivo experimental (Beta) e está em fase de homologação.'
const AUTH_ADMIN = {
  perfil: { perfil_acesso: 'Administrador', nome: 'Administrador Aptus' },
  permissoes: [{ modulo: 'relatorios', pode_ler: true, pode_escrever: true }],
  capacidades: ['relatorios.exportar'],
}

// Mock do hook useAuth com valor estável por render para evitar reexecuções espúrias de effects.
vi.mock('../contexts/AuthContext', () => ({
  useAuth: () => useContext(MockAuthContext),
}))

// Mock de relatorios.service
vi.mock('../services/relatorios.service', () => ({
  relatoriosService: {
    listarCategoriasRelatorios: vi.fn(),
    listarExportacoesRelatorios: vi.fn(),
    gerarPreviaRelatorio: vi.fn(),
    exportarRelatorio: vi.fn(),
    baixarExportacaoRelatorio: vi.fn(),
  },
}))

// Mock de download helper
vi.mock('../lib/download', () => ({
  obterDadosDownload: vi.fn((resp) => ({
    url: resp.download_url,
    nomeArquivo: resp.exportacao.arquivo_nome,
    mimeType: resp.exportacao.mime_type,
    expiresIn: resp.download_expires_in,
  })),
  dispararDownloadArquivo: vi.fn(),
}))

const renderComponent = (authVal?: any) => {
  return render(
    <MockAuthContext.Provider value={authVal ?? AUTH_ADMIN}>
      <MemoryRouter>
        <RelatoriosPage />
      </MemoryRouter>
    </MockAuthContext.Provider>
  )
}

describe('RelatoriosPage', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.clearAllMocks()

    // Configura os mocks padrão de carregamento
    vi.mocked(relatoriosService.listarCategoriasRelatorios).mockResolvedValue(['Financeiro', 'DRE'])
    vi.mocked(relatoriosService.listarExportacoesRelatorios).mockResolvedValue([
      {
        id: 'uuid-1',
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31',
        status_exibicao: 'Pronto',
        criado_por_nome: 'Jonathas',
        gerado_em: '2026-07-09T08:00:00Z',
        expira_em: '2026-07-09T08:10:00Z',
        pode_baixar: true,
      },
    ] as any)
    vi.mocked(relatoriosService.gerarPreviaRelatorio).mockResolvedValue({
      receitas_totais: 50000,
      despesas_totais: 20000,
      saldo_acumulado: 30000,
      lancamentos_count: 42,
    })
  })

  it('deve renderizar a pagina e o historico corretamente para usuario autorizado', async () => {
    renderComponent()

    expect(screen.getByText('Carregando categorias e histórico de relatórios...')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByText(/Relatórios Operacionais/i)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Financeiro' })).toBeInTheDocument()
      expect(screen.getByText(/DRE/i)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /Exportar Relatório/i })).toBeInTheDocument()
    })
  })

  it('deve desabilitar o botao Exportar Relatorio com tooltip apropriado se o usuario nao tiver permissao', async () => {
    renderComponent({
      perfil: { perfil_acesso: 'Visualizador', nome: 'Visualizador Aptus' },
      permissoes: [{ modulo: 'relatorios', pode_ler: true, pode_escrever: false }],
      capacidades: [], // Sem relatorios.exportar
    })

    await waitFor(() => {
      const btnExportar = screen.getByRole('button', { name: /Exportar Relatório/i })
      expect(btnExportar).toBeDisabled()
      expect(btnExportar).toHaveAttribute('title', 'Você não tem permissão para exportar')
    })
  })

  it('deve distinguir documento executivo de exportacao operacional no modal', async () => {
    renderComponent()

    await screen.findByRole('button', { name: 'Financeiro' })
    await screen.findByText('42')
    fireEvent.click(screen.getByRole('button', { name: /Exportar Relatório/i }))

    expect(screen.getByRole('option', { name: 'Documento Executivo (.pdf)' })).toBeInTheDocument()
    expect(screen.getByRole('option', { name: 'Exportação Operacional (.zip)' })).toBeInTheDocument()
    expect(screen.getByText(COPIA_BETA_MODAL)).toBeInTheDocument()
  })

  it('deve abrir o modal com periodo padrao, labels associados e foco inicial', async () => {
    renderComponent()

    await screen.findByText('42')
    fireEvent.click(screen.getByRole('button', { name: /Exportar Relatório/i }))

    const periodoPadrao = obterPeriodoPadrao()
    expect(screen.getByLabelText('Data Inicial')).toHaveValue(periodoPadrao.data_inicial)
    expect(screen.getByLabelText('Data Final')).toHaveValue(periodoPadrao.data_final)
    expect(screen.getByLabelText('Formato de Exportação')).toHaveValue('PDF')
    expect(screen.getByLabelText('Data Inicial')).toHaveFocus()
  })

  it('deve bloquear exportacao com data final anterior a data inicial', async () => {
    renderComponent()

    await screen.findByText('42')
    fireEvent.click(screen.getByRole('button', { name: /Exportar Relatório/i }))
    fireEvent.change(screen.getByLabelText('Data Inicial'), { target: { value: '2026-07-20' } })
    fireEvent.change(screen.getByLabelText('Data Final'), { target: { value: '2026-07-01' } })
    fireEvent.click(screen.getByRole('button', { name: 'Gerar e baixar' }))

    const validacao = validarPeriodoExportacao('2026-07-20', '2026-07-01')
    expect(screen.getByRole('alert')).toHaveTextContent(validacao.mensagem!)
    expect(relatoriosService.exportarRelatorio).not.toHaveBeenCalled()
  })

  it('deve fechar o modal com Escape', async () => {
    renderComponent()

    await screen.findByText('42')
    fireEvent.click(screen.getByRole('button', { name: /Exportar Relatório/i }))
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' })

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('deve exibir badges de formato distintos no historico', async () => {
    vi.mocked(relatoriosService.listarExportacoesRelatorios).mockResolvedValue([
      {
        id: 'uuid-pdf',
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31',
        status_exibicao: 'Pronto',
        criado_por_nome: 'Jonathas',
        gerado_em: '2026-07-09T08:00:00Z',
        expira_em: '2026-07-19T08:00:00Z',
        pode_baixar: true,
      },
      {
        id: 'uuid-csv',
        tipo: 'Clientes',
        formato: 'CSV',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31',
        status_exibicao: 'Pronto',
        criado_por_nome: 'Jonathas',
        gerado_em: '2026-07-09T08:00:00Z',
        expira_em: '2026-07-19T08:00:00Z',
        pode_baixar: true,
      },
    ] as any)

    renderComponent()

    expect(await screen.findByText('PDF', { selector: '.formato-badge.formato-pdf' })).toBeInTheDocument()
    expect(screen.getByText('CSV', { selector: '.formato-badge.formato-csv' })).toBeInTheDocument()
  })

  it('deve bloquear item expirado com tooltip de negocio', async () => {
    vi.mocked(relatoriosService.listarExportacoesRelatorios).mockResolvedValue([
      {
        id: 'uuid-expirado',
        tipo: 'Financeiro',
        formato: 'PDF',
        data_inicial: '2026-07-01',
        data_final: '2026-07-31',
        status_exibicao: 'Expirado',
        criado_por_nome: 'Jonathas',
        gerado_em: '2026-07-01T08:00:00Z',
        expira_em: '2026-07-08T08:00:00Z',
        pode_baixar: false,
      },
    ] as any)

    renderComponent()

    const botao = await screen.findByRole('button', { name: 'Baixar' })
    expect(botao).toBeDisabled()
    expect(botao).toHaveAttribute(
      'title',
      'Este relatório expirou em 08/07/2026. Gere um novo para o mesmo período.',
    )
  })

  it('deve abrir o modal de exportacao, submeter e iniciar o download sem alterar rotas', async () => {
    vi.mocked(relatoriosService.exportarRelatorio).mockResolvedValue({
      exportacao: { arquivo_nome: 'relatorio-financeiro.pdf', mime_type: 'application/pdf' },
      download_url: 'http://localhost/signed-url',
      download_expires_in: 600,
    } as any)

    renderComponent({
      perfil: { perfil_acesso: 'Financeiro', nome: 'Financeiro Aptus' },
      permissoes: [{ modulo: 'relatorios', pode_ler: true, pode_escrever: true }],
      capacidades: ['relatorios.exportar'],
    })

    await waitFor(() => {
      const btnExportar = screen.getByRole('button', { name: /Exportar Relatório/i })
      fireEvent.click(btnExportar)
    })

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Exportar Dados')).toBeInTheDocument()

    const btnGerar = screen.getByRole('button', { name: 'Gerar e baixar' })
    fireEvent.click(btnGerar)

    await waitFor(() => {
      expect(relatoriosService.exportarRelatorio).toHaveBeenCalled()
      expect(dispararDownloadArquivo).toHaveBeenCalledWith('http://localhost/signed-url', 'relatorio-financeiro.pdf')
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
      expect(screen.getByText('Exportação gerada com sucesso!')).toBeInTheDocument()
    })
  })

  it('deve acionar o download do item no historico sem navegar na pagina', async () => {
    vi.mocked(relatoriosService.baixarExportacaoRelatorio).mockResolvedValue({
      exportacao: { arquivo_nome: 'relatorio-financeiro.pdf', mime_type: 'application/pdf' },
      download_url: 'http://localhost/signed-url-hist',
      download_expires_in: 600,
    } as any)

    renderComponent({
      perfil: { perfil_acesso: 'Financeiro', nome: 'Financeiro Aptus' },
      permissoes: [{ modulo: 'relatorios', pode_ler: true, pode_escrever: true }],
      capacidades: ['relatorios.exportar'],
    })

    await waitFor(() => {
      const linkBaixar = screen.getByText('Baixar')
      fireEvent.click(linkBaixar)
    })

    await waitFor(() => {
      expect(relatoriosService.baixarExportacaoRelatorio).toHaveBeenCalledWith({ exportacao_id: 'uuid-1' })
      expect(dispararDownloadArquivo).toHaveBeenCalledWith('http://localhost/signed-url-hist', 'relatorio-financeiro.pdf')
    })
  })
})
