/**
 * Testes de UI do modal de exportação de RelatoriosPage (Feature 008 - Exportar Relatórios,
 * User Story 1 / T028).
 *
 * IMPORTANTE (TDD): estes testes descrevem o comportamento exigido pelo contrato
 * `specs/008-exportar-relatorios/contracts/frontend-relatorios.md` para o NOVO modal de
 * exportação (campos de data, validação de período, ação "Gerar e baixar", foco inicial,
 * labels explícitos, navegação por teclado, fechamento com Escape e responsividade a partir
 * de 320px). A página atual (`RelatoriosPage.tsx`) ainda implementa o fluxo legado (somente
 * seletor de formato + `solicitarExportacaoRelatorio`), então é esperado que a maioria destes
 * testes FALHE até a implementação de T039/T040/T041/T042. Não implemente a página aqui.
 *
 * `relatoriosService` e `useAuth` são mockados para isolar o teste de UI de Supabase/rede.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import RelatoriosPage from './RelatoriosPage'
import { obterPeriodoPadrao, validarPeriodoExportacao } from '../lib/relatorios-periodo'
import type { PerfilUsuario, PermissaoModulo } from '../types/auth'
import type { ExportacaoRelatorioItem } from '../types/relatorios'

// --- Mocks de dependências externas à página ---

const mockUseAuth = vi.fn()
vi.mock('../contexts/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}))

const mockListarCategorias = vi.fn()
const mockListarExportacoes = vi.fn()
const mockGerarPrevia = vi.fn()
const mockExportarRelatorio = vi.fn()
const mockSolicitarExportacaoLegado = vi.fn()
const mockBaixarExportacao = vi.fn()

vi.mock('../services/relatorios.service', () => ({
  relatoriosService: {
    listarCategoriasRelatorios: (...args: any[]) => mockListarCategorias(...args),
    listarExportacoesRelatorios: (...args: any[]) => mockListarExportacoes(...args),
    gerarPreviaRelatorio: (...args: any[]) => mockGerarPrevia(...args),
    exportarRelatorio: (...args: any[]) => mockExportarRelatorio(...args),
    solicitarExportacaoRelatorio: (...args: any[]) => mockSolicitarExportacaoLegado(...args),
    baixarExportacaoRelatorio: (...args: any[]) => mockBaixarExportacao(...args),
    agendarRelatorio: vi.fn(),
  },
}))

const PERFIL_ADMIN: PerfilUsuario = {
  nome: 'Ana Admin',
  perfil_acesso: 'Administrador',
  status: 'Ativo',
  avatar_url: null,
  departamento: null,
}

const PERMISSOES_RELATORIOS: PermissaoModulo[] = [
  { modulo: 'relatorios', pode_ler: true, pode_escrever: true },
]

const CATEGORIAS = ['Financeiro', 'DRE', 'Clientes', 'Projetos', 'Personalizado']

function configurarAuthPadrao() {
  mockUseAuth.mockReturnValue({
    perfil: PERFIL_ADMIN,
    permissoes: PERMISSOES_RELATORIOS,
    capacidades: ['relatorios.exportar'],
    sair: vi.fn(),
  })
}

function renderPagina() {
  return render(
    <MemoryRouter>
      <RelatoriosPage />
    </MemoryRouter>,
  )
}

async function abrirModalExportar(user: ReturnType<typeof userEvent.setup>) {
  const botao = await screen.findByRole('button', { name: /exportar relatório/i })
  await user.click(botao)
}

beforeEach(() => {
  vi.clearAllMocks()
  configurarAuthPadrao()
  mockListarCategorias.mockResolvedValue(CATEGORIAS)
  mockListarExportacoes.mockResolvedValue([] as ExportacaoRelatorioItem[])
  mockGerarPrevia.mockResolvedValue({})
  mockExportarRelatorio.mockResolvedValue({
    exportacao: {
      id: 'exp-1',
      arquivo_nome: 'financeiro.pdf',
      mime_type: 'application/pdf',
      expira_em: '2027-07-15T00:00:00Z',
    },
    download_url: 'https://example.com/signed-url',
    download_expires_in: 600,
  })
})

describe('RelatoriosPage - Modal de Exportação (Feature 008, US1 - T028)', () => {
  it('preenche data_inicial com o primeiro dia do mês corrente e data_final com hoje ao abrir o modal', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    const esperado = obterPeriodoPadrao(new Date())

    expect(await screen.findByLabelText(/data inicial/i)).toHaveValue(esperado.data_inicial)
    expect(screen.getByLabelText(/data final/i)).toHaveValue(esperado.data_final)
  })

  it('expõe labels explícitos e associados para os campos do formulário de exportação', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    expect(await screen.findByLabelText(/data inicial/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/data final/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/formato/i)).toBeInTheDocument()
  })

  it('foca automaticamente o primeiro campo editável (Data Inicial) ao abrir o modal', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    const dataInicial = await screen.findByLabelText(/data inicial/i)
    expect(dataInicial).toHaveFocus()
  })

  it('bloqueia a exportação quando a data final é anterior à data inicial', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    const dataInicial = await screen.findByLabelText(/data inicial/i)
    const dataFinal = screen.getByLabelText(/data final/i)

    fireEvent.change(dataInicial, { target: { value: '2026-07-20' } })
    fireEvent.change(dataFinal, { target: { value: '2026-07-01' } })

    const esperado = validarPeriodoExportacao('2026-07-20', '2026-07-01')
    expect(await screen.findByText(esperado.mensagem!)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /gerar e baixar/i }))
    expect(mockExportarRelatorio).not.toHaveBeenCalled()
  })

  it('bloqueia a exportação quando o período excede 12 meses', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    const dataInicial = await screen.findByLabelText(/data inicial/i)
    const dataFinal = screen.getByLabelText(/data final/i)

    fireEvent.change(dataInicial, { target: { value: '2026-01-01' } })
    fireEvent.change(dataFinal, { target: { value: '2027-01-02' } })

    const esperado = validarPeriodoExportacao('2026-01-01', '2027-01-02')
    expect(await screen.findByText(esperado.mensagem!)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /gerar e baixar/i }))
    expect(mockExportarRelatorio).not.toHaveBeenCalled()
  })

  it('permite selecionar CSV e chama exportarRelatorio (não mais o fluxo legado solicitarExportacaoRelatorio)', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    const esperado = obterPeriodoPadrao(new Date())

    await user.selectOptions(screen.getByLabelText(/formato/i), 'CSV')
    await user.click(screen.getByRole('button', { name: /gerar e baixar/i }))

    await waitFor(() => {
      expect(mockExportarRelatorio).toHaveBeenCalledWith({
        tipo: 'Financeiro',
        formato: 'CSV',
        data_inicial: esperado.data_inicial,
        data_final: esperado.data_final,
      })
    })
    expect(mockSolicitarExportacaoLegado).not.toHaveBeenCalled()
  })

  it('não exibe ação ativa de exportação para a categoria Personalizado (fora do escopo 008)', async () => {
    const user = userEvent.setup()
    renderPagina()

    const botaoPersonalizado = await screen.findByRole('button', { name: 'Personalizado' })
    await user.click(botaoPersonalizado)

    await waitFor(() => {
      const botaoExportar = screen.queryByRole('button', { name: /exportar relatório/i })
      expect(botaoExportar === null || botaoExportar.hasAttribute('disabled')).toBe(true)
    })
  })

  it('fecha o modal ao pressionar Escape', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    expect(screen.getByText('Exportar Dados')).toBeInTheDocument()

    await user.keyboard('{Escape}')

    await waitFor(() => {
      expect(screen.queryByText('Exportar Dados')).not.toBeInTheDocument()
    })
  })

  it('mantém o foco dentro do modal (focus trap) ao navegar com Tab/Shift+Tab', async () => {
    const user = userEvent.setup()
    renderPagina()
    await abrirModalExportar(user)

    const dialog = await screen.findByRole('dialog', { name: /exportar/i })
    expect(within(dialog).getByLabelText(/data inicial/i)).toHaveFocus()

    for (let i = 0; i < 8; i++) {
      await user.tab()
      expect(dialog.contains(document.activeElement)).toBe(true)
    }

    await user.tab({ shift: true })
    expect(dialog.contains(document.activeElement)).toBe(true)
  })

  it('mantém uma regra de responsividade mobile (<=360px) no CSS da página, cobrindo o modal em 320px', () => {
    const css = readFileSync(join(process.cwd(), 'src/pages/RelatoriosPage.css'), 'utf-8')
    const temBreakpointMobile = /@media\s*\(max-width:\s*(3[0-6]\d)px\)/.test(css)
    expect(temBreakpointMobile).toBe(true)
  })
})

/**
 * Testes da tabela de Histórico de Exportações de RelatoriosPage (Feature 008 - Exportar
 * Relatórios, User Story 2 / T048).
 *
 * IMPORTANTE (TDD): estes testes descrevem o comportamento exigido pelo contrato
 * `specs/008-exportar-relatorios/contracts/frontend-relatorios.md` para a tabela de
 * histórico (seção "History Table"): coluna de Período, coluna de Solicitante, indicação
 * de Expiração, texto de status legível (não somente cor) para todo `status_exibicao`
 * incluindo `Expirado`, e um controle de download que só existe/está habilitado quando
 * `pode_baixar` é `true`, acessível via teclado (Tab + Enter). A implementação atual da
 * página (pós-US1) ainda usa o histórico legado (`hist.status` + `hist.arquivo_url`), sem
 * essas colunas e sem gating por `pode_baixar`, então é esperado que estes testes FALHEM
 * até a implementação de US2 (T049+). Não implemente a página aqui.
 */
function criarItemHistorico(
  overrides: Partial<ExportacaoRelatorioItem> &
    Pick<ExportacaoRelatorioItem, 'id' | 'tipo' | 'status_exibicao' | 'pode_baixar'>,
): ExportacaoRelatorioItem {
  return {
    formato: 'PDF',
    formato_entrega: 'PDF',
    status: overrides.status_exibicao,
    data_inicial: '2026-06-01',
    data_final: '2026-06-30',
    arquivo_url: null,
    arquivo_nome: 'relatorio.pdf',
    mime_type: 'application/pdf',
    tamanho_bytes: 1024,
    criado_por: 'user-1',
    criado_por_nome: 'Ana Admin',
    gerado_em: '2026-07-01T10:00:00Z',
    expira_em: '2026-07-10T00:00:00Z',
    erro: null,
    ...overrides,
  }
}

const ITEM_PRONTO = criarItemHistorico({
  id: 'exp-pronto',
  tipo: 'Relatorio-Pronto',
  status_exibicao: 'Pronto',
  pode_baixar: true,
})

const ITEM_PENDENTE = criarItemHistorico({
  id: 'exp-pendente',
  tipo: 'Relatorio-Pendente',
  status_exibicao: 'Pendente',
  pode_baixar: false,
  gerado_em: null,
  expira_em: null,
  arquivo_nome: null,
  mime_type: null,
  tamanho_bytes: null,
})

const ITEM_FALHOU = criarItemHistorico({
  id: 'exp-falhou',
  tipo: 'Relatorio-Falhou',
  status_exibicao: 'Falhou',
  pode_baixar: false,
  erro: 'Falha ao gerar arquivo.',
  expira_em: null,
  arquivo_nome: null,
  mime_type: null,
  tamanho_bytes: null,
})

const ITEM_EXPIRADO = criarItemHistorico({
  id: 'exp-expirado',
  tipo: 'Relatorio-Expirado',
  status_exibicao: 'Expirado',
  status: 'Pronto',
  pode_baixar: false,
  expira_em: '2026-06-15T00:00:00Z',
})

const ITEM_INDISPONIVEL = criarItemHistorico({
  id: 'exp-indisponivel',
  tipo: 'Relatorio-Indisponivel',
  status_exibicao: 'Indisponível',
  status: 'Indisponível',
  pode_baixar: false,
  expira_em: null,
  arquivo_nome: null,
  mime_type: null,
  tamanho_bytes: null,
})

function obterLinhaPorTipo(tipo: string): HTMLElement {
  const celula = screen.getByText(tipo)
  const linha = celula.closest('tr')
  if (!linha) throw new Error(`Linha da tabela não encontrada para tipo "${tipo}"`)
  return linha as HTMLElement
}

describe('RelatoriosPage - Tabela de Histórico (Feature 008, US2 - T048)', () => {
  it('exibe uma coluna de Período com as datas inicial e final da exportação', async () => {
    mockListarExportacoes.mockResolvedValue([ITEM_PRONTO])
    renderPagina()

    expect(
      await screen.findByRole('columnheader', { name: /per[ií]odo/i }),
    ).toBeInTheDocument()

    const linha = obterLinhaPorTipo('Relatorio-Pronto')
    expect(within(linha).getByText(/01\/06\/2026/)).toBeInTheDocument()
    expect(within(linha).getByText(/30\/06\/2026/)).toBeInTheDocument()
  })

  it('exibe uma coluna de Solicitante/Requerente com o nome de quem gerou a exportação', async () => {
    mockListarExportacoes.mockResolvedValue([ITEM_PRONTO])
    renderPagina()

    expect(
      await screen.findByRole('columnheader', { name: /solicitante|requerente/i }),
    ).toBeInTheDocument()

    const linha = obterLinhaPorTipo('Relatorio-Pronto')
    expect(within(linha).getByText('Ana Admin')).toBeInTheDocument()
  })

  it('exibe indicação de Expiração (Expira em) para exportações com data de expiração', async () => {
    mockListarExportacoes.mockResolvedValue([ITEM_PRONTO])
    renderPagina()

    expect(await screen.findByRole('columnheader', { name: /expira/i })).toBeInTheDocument()

    const linha = obterLinhaPorTipo('Relatorio-Pronto')
    expect(within(linha).getByText(/10\/07\/2026/)).toBeInTheDocument()
  })

  it('exibe texto de status legível para cada situação, incluindo "Expirado" (não apenas cor)', async () => {
    mockListarExportacoes.mockResolvedValue([
      ITEM_PRONTO,
      ITEM_PENDENTE,
      ITEM_FALHOU,
      ITEM_EXPIRADO,
    ])
    renderPagina()

    await screen.findByText('Relatorio-Pronto')

    expect(within(obterLinhaPorTipo('Relatorio-Pronto')).getByText('Pronto')).toBeInTheDocument()
    expect(
      within(obterLinhaPorTipo('Relatorio-Pendente')).getByText('Pendente'),
    ).toBeInTheDocument()
    expect(within(obterLinhaPorTipo('Relatorio-Falhou')).getByText('Falhou')).toBeInTheDocument()
    expect(
      within(obterLinhaPorTipo('Relatorio-Expirado')).getByText('Expirado'),
    ).toBeInTheDocument()
  })

  it('o botão de download é acessível por teclado (Tab + Enter aciona o download) quando pode_baixar é true', async () => {
    const user = userEvent.setup()
    mockListarExportacoes.mockResolvedValue([ITEM_PRONTO])
    renderPagina()

    await screen.findByText('Relatorio-Pronto')

    const controleDownload =
      screen.queryByRole('button', { name: /baixar|download/i }) ??
      screen.getByRole('link', { name: /baixar|download/i })

    let alcancado = false
    for (let i = 0; i < 60; i++) {
      await user.tab()
      if (document.activeElement === controleDownload) {
        alcancado = true
        break
      }
    }
    expect(alcancado).toBe(true)

    await user.keyboard('{Enter}')

    await waitFor(() => {
      expect(mockBaixarExportacao).toHaveBeenCalledWith({ exportacao_id: 'exp-pronto' })
    })
  })

  it('não exibe (ou desabilita) o controle de download quando pode_baixar é false: pendente, falhou, expirado e indisponível', async () => {
    mockListarExportacoes.mockResolvedValue([
      ITEM_PENDENTE,
      ITEM_FALHOU,
      ITEM_EXPIRADO,
      ITEM_INDISPONIVEL,
    ])
    renderPagina()

    await screen.findByText('Relatorio-Pendente')

    for (const item of [ITEM_PENDENTE, ITEM_FALHOU, ITEM_EXPIRADO, ITEM_INDISPONIVEL]) {
      const linha = obterLinhaPorTipo(item.tipo)
      const link = within(linha).queryByRole('link', { name: /baixar|download/i })
      const botao = within(linha).queryByRole('button', { name: /baixar|download/i })
      const controle = link ?? botao

      const desabilitadoOuAusente =
        controle === null || (controle as HTMLButtonElement).disabled === true

      expect(desabilitadoOuAusente).toBe(true)
    }
  })
})

/**
 * Testes de gate de capacidade `relatorios.exportar` de RelatoriosPage (Feature 008 -
 * Exportar Relatórios, User Story 3 / T061).
 *
 * IMPORTANTE (TDD): estes testes descrevem o comportamento exigido pelo contrato
 * `specs/008-exportar-relatorios/contracts/frontend-relatorios.md` (seção "Capability UI"):
 * "User without `relatorios.exportar` must not see active export controls." e "Visualizador
 * may continue reading reports if allowed, but sees no export PDF/CSV action.". A tarefa
 * T064 (endurecimento do gate de capacidade na página, incluindo suprimir a ação de
 * exportação para `Personalizado`) ainda não foi implementada nesta rodada, então é
 * esperado que alguns destes testes FALHEM contra o estado atual de `RelatoriosPage.tsx`
 * até T064 ser concluída. Não implemente a página aqui.
 *
 * A página já expõe `capacidades` via `useAuth()` (mockado abaixo) e usa
 * `pode(capacidades, 'relatorios.exportar')` para decidir a visibilidade dos botões do
 * cabeçalho; os testes abaixo simulam explicitamente um usuário SEM essa capacidade.
 */
function configurarAuthSemCapacidadeExportar(perfilAcesso: PerfilUsuario['perfil_acesso'] = 'Visualizador') {
  mockUseAuth.mockReturnValue({
    perfil: { ...PERFIL_ADMIN, perfil_acesso: perfilAcesso },
    permissoes: PERMISSOES_RELATORIOS,
    capacidades: [] as string[],
    sair: vi.fn(),
  })
}

describe('RelatoriosPage - Gate de capacidade relatorios.exportar (Feature 008, US3 - T061)', () => {
  it('não exibe o botão "Exportar Relatório" quando o usuário não possui a capacidade relatorios.exportar', async () => {
    configurarAuthSemCapacidadeExportar()
    renderPagina()

    await screen.findByText('Selecione o Relatório')

    const botaoExportar = screen.queryByRole('button', { name: /exportar relatório/i })
    expect(botaoExportar === null || (botaoExportar as HTMLButtonElement).disabled).toBe(true)
  })

  it('não exibe o botão "Agendar Envio" quando o usuário não possui a capacidade relatorios.exportar', async () => {
    configurarAuthSemCapacidadeExportar()
    renderPagina()

    await screen.findByText('Selecione o Relatório')

    const botaoAgendar = screen.queryByRole('button', { name: /agendar envio/i })
    expect(botaoAgendar === null || (botaoAgendar as HTMLButtonElement).disabled).toBe(true)
  })

  it('Visualizador sem capacidade de exportar consegue ler a pré-visualização e o histórico, mas não vê nenhum controle de exportação ativo', async () => {
    configurarAuthSemCapacidadeExportar('Visualizador')
    mockListarExportacoes.mockResolvedValue([ITEM_PRONTO])
    renderPagina()

    // Continua conseguindo ler: categorias, prévia e histórico permanecem visíveis.
    expect(await screen.findByText('Selecione o Relatório')).toBeInTheDocument()
    await screen.findByText('Relatorio-Pronto')

    // Nenhum controle ativo de exportação (gerar PDF/CSV) deve estar disponível.
    expect(screen.queryByRole('button', { name: /exportar relatório/i })).not.toBeInTheDocument()
    expect(screen.queryByText('Exportar Dados')).not.toBeInTheDocument()
  })

  it('não revela o botão de exportação ao trocar de categoria, mesmo para uma categoria exportável, quando falta a capacidade', async () => {
    const user = userEvent.setup()
    configurarAuthSemCapacidadeExportar('Comercial')
    renderPagina()

    const botaoFinanceiro = await screen.findByRole('button', { name: 'Financeiro' })
    await user.click(botaoFinanceiro)

    await waitFor(() => {
      const botaoExportar = screen.queryByRole('button', { name: /exportar relatório/i })
      expect(botaoExportar === null || (botaoExportar as HTMLButtonElement).disabled).toBe(true)
    })
  })

  it('(sanidade) com a capacidade relatorios.exportar presente, o botão "Exportar Relatório" é exibido e habilitado', async () => {
    configurarAuthPadrao()
    renderPagina()

    const botaoExportar = await screen.findByRole('button', { name: /exportar relatório/i })
    expect(botaoExportar).toBeEnabled()
  })
})
