import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import ConfiguracoesPage from './ConfiguracoesPage'

const mockUseAuth = vi.fn()
const mockNavigate = vi.fn()

const mockObterMinhasConfiguracoes = vi.fn()
const mockListarPreferenciasNotificacoes = vi.fn()
const mockListarUsuariosConfiguracoes = vi.fn()
const mockCriarUsuarioConfiguracoes = vi.fn()

vi.mock('../contexts/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}))

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual<typeof import('react-router-dom')>('react-router-dom')
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  }
})

vi.mock('../services/configuracoes.service', () => ({
  configuracoesService: {
    obterMinhasConfiguracoes: (...args: any[]) => mockObterMinhasConfiguracoes(...args),
    listarPreferenciasNotificacoes: (...args: any[]) => mockListarPreferenciasNotificacoes(...args),
    listarUsuariosConfiguracoes: (...args: any[]) => mockListarUsuariosConfiguracoes(...args),
    criarUsuarioConfiguracoes: (...args: any[]) => mockCriarUsuarioConfiguracoes(...args),
    atualizarUsuarioPerfil: vi.fn(),
    obterConfiguracoesEmpresa: vi.fn(),
    atualizarConfiguracoesEmpresa: vi.fn(),
    atualizarMinhasConfiguracoes: vi.fn(),
    atualizarPreferenciasNotificacoes: vi.fn(),
    listarLogsAuditoria: vi.fn(),
  },
}))

describe('ConfiguracoesPage - gestão de usuários', () => {
  beforeEach(() => {
    vi.clearAllMocks()

    mockUseAuth.mockReturnValue({
      perfil: {
        nome: 'Admin',
        perfil_acesso: 'Administrador',
        status: 'Ativo',
        departamento: null,
      },
      permissoes: [{ modulo: 'configuracoes', pode_ler: true, pode_escrever: true }],
      capacidades: ['configuracoes.gerenciar_usuarios', 'configuracoes.editar_empresa', 'configuracoes.editar_proprio_perfil'],
      sair: vi.fn(),
    })

    mockObterMinhasConfiguracoes.mockResolvedValue({
      perfil: { nome: 'Admin', perfil_acesso: 'Administrador', departamento: null },
      usuario: { email: 'admin@aptusflow.local' },
    })
    mockListarPreferenciasNotificacoes.mockResolvedValue([])
    mockListarUsuariosConfiguracoes.mockResolvedValue([
      {
        usuario_id: 'user-1',
        nome: 'Usuário Existente',
        email: 'existente@aptusflow.local',
        perfil_acesso: 'Visualizador',
        status: 'Ativo',
        departamento: null,
      },
    ])
    mockCriarUsuarioConfiguracoes.mockResolvedValue(true)
  })

  it('não renderiza o campo Avatar URL na aba Minha Conta', async () => {
    render(
      <MemoryRouter>
        <ConfiguracoesPage />
      </MemoryRouter>,
    )

    await screen.findByDisplayValue('admin@aptusflow.local')

    expect(screen.queryByText('Avatar URL')).not.toBeInTheDocument()
  })

  it('permite que administrador cadastre um novo usuário pela aba Contas e Acessos', async () => {
    const user = userEvent.setup()

    render(
      <MemoryRouter>
        <ConfiguracoesPage />
      </MemoryRouter>,
    )

    await user.click(await screen.findByRole('button', { name: /contas e acessos/i }))

    await screen.findByText('Usuário Existente')

    await user.click(screen.getByRole('button', { name: /cadastrar usuário/i }))

    await screen.findByRole('heading', { name: /cadastrar novo usuário/i })

    await user.type(screen.getByLabelText(/nome completo/i), 'Novo Usuário')
    await user.type(screen.getByLabelText(/e-mail/i), 'novo@aptusflow.local')
    await user.type(screen.getByLabelText(/senha temporária/i), 'SenhaTemp123!')
    fireEvent.change(screen.getByLabelText(/perfil de acesso/i), { target: { value: 'Financeiro' } })
    await user.type(screen.getByLabelText(/departamento/i), 'Financeiro')

    await user.click(screen.getByRole('button', { name: /^cadastrar$/i }))

    await waitFor(() => {
      expect(mockCriarUsuarioConfiguracoes).toHaveBeenCalledWith({
        nome: 'Novo Usuário',
        email: 'novo@aptusflow.local',
        senha_temporaria: 'SenhaTemp123!',
        perfil_acesso: 'Financeiro',
        departamento: 'Financeiro',
        status: 'Ativo',
      })
    })
  })
})
