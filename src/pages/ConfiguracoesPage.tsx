import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { configuracoesService } from '../services/configuracoes.service'
import { podeLer } from '../lib/permissoes'
import { pode } from '../lib/capacidades'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, ErrorState } from '../components/ui/States'
import type {
  ConfiguracaoEmpresa,
  UsuarioConfigItem,
  PreferenciaNotificacaoItem,
  AuditoriaEventoItem,
  CriarUsuarioConfiguracoesPayload,
} from '../types/configuracoes'
import './ConfiguracoesPage.css'

type TabConfig = 'minha-conta' | 'empresa' | 'usuarios' | 'auditoria'

export default function ConfiguracoesPage() {
  const { perfil, permissoes, capacidades } = useAuth()
  const navigate = useNavigate()
  const podeGerenciarUsuarios = pode(capacidades, 'configuracoes.gerenciar_usuarios')
  const podeEditarEmpresa = pode(capacidades, 'configuracoes.editar_empresa')
  const podeEditarProprioPerfil = pode(capacidades, 'configuracoes.editar_proprio_perfil')
  const isAdmin = perfil?.perfil_acesso === 'Administrador'

  // Estados
  const [activeTab, setActiveTab] = useState<TabConfig>('minha-conta')
  const [minhaConta, setMinhaConta] = useState<{ perfil: any; usuario: any } | null>(null)
  const [preferencias, setPreferencias] = useState<PreferenciaNotificacaoItem[]>([])
  
  // Dados de Admin
  const [, setEmpresa] = useState<ConfiguracaoEmpresa | null>(null)
  const [usuarios, setUsuarios] = useState<UsuarioConfigItem[]>([])
  const [auditoriaLogs, setAuditoriaLogs] = useState<AuditoriaEventoItem[]>([])

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)

  // Forms
  const [formNome, setFormNome] = useState('')
  const [formAvatar, setFormAvatar] = useState('')
  const [formDepto, setFormDepto] = useState('')

  // Form Empresa
  const [empRazao, setEmpRazao] = useState('')
  const [empDoc, setEmpDoc] = useState('')
  const [empEmail, setEmpEmail] = useState('')
  const [empTel, setEmpTel] = useState('')
  const [empEnd, setEmpEnd] = useState('')
  const [empVenc, setEmpVenc] = useState('5')
  const [empMulta, setEmpMulta] = useState('2')
  const [empCobrancaAuto, setEmpCobrancaAuto] = useState(true)

  // Modal cadastrar usuário
  const [novoUsuarioModalOpen, setNovoUsuarioModalOpen] = useState(false)
  const [formNovoUsuarioNome, setFormNovoUsuarioNome] = useState('')
  const [formNovoUsuarioEmail, setFormNovoUsuarioEmail] = useState('')
  const [formNovoUsuarioSenha, setFormNovoUsuarioSenha] = useState('')
  const [formNovoUsuarioPerfil, setFormNovoUsuarioPerfil] = useState<CriarUsuarioConfiguracoesPayload['perfil_acesso']>('Visualizador')
  const [formNovoUsuarioStatus, setFormNovoUsuarioStatus] = useState<'Ativo' | 'Inativo'>('Ativo')
  const [formNovoUsuarioDepto, setFormNovoUsuarioDepto] = useState('')

  // Modal gerenciar usuário
  const [selectedUser, setSelectedUser] = useState<UsuarioConfigItem | null>(null)
  const [userModalOpen, setUserModalOpen] = useState(false)
  const [formUserPerfil, setFormUserPerfil] = useState('')
  const [formUserStatus, setFormUserStatus] = useState<'Ativo' | 'Inativo'>('Ativo')
  const [formUserDepto, setFormUserDepto] = useState('')

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg)
    setTimeout(() => {
      setToastMsg(null)
    }, 3000)
  }, [])

  const resetNovoUsuarioForm = useCallback(() => {
    setFormNovoUsuarioNome('')
    setFormNovoUsuarioEmail('')
    setFormNovoUsuarioSenha('')
    setFormNovoUsuarioPerfil('Visualizador')
    setFormNovoUsuarioStatus('Ativo')
    setFormNovoUsuarioDepto('')
  }, [])

  // Carregar dados da aba ativa
  const fetchDados = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      if (activeTab === 'minha-conta') {
        const [me, prefs] = await Promise.all([
          configuracoesService.obterMinhasConfiguracoes(),
          configuracoesService.listarPreferenciasNotificacoes()
        ])
        setMinhaConta(me)
        setPreferencias(prefs)
        setFormNome(me.perfil?.nome || '')
        setFormAvatar(me.perfil?.avatar_url || '')
        setFormDepto(me.perfil?.departamento || '')
      } else if (activeTab === 'empresa' && isAdmin) {
        const data = await configuracoesService.obterConfiguracoesEmpresa()
        setEmpresa(data)
        setEmpRazao(data.razao_social || '')
        setEmpDoc(data.documento || '')
        setEmpEmail(data.email || '')
        setEmpTel(data.telefone || '')
        setEmpEnd(data.endereco || '')
        setEmpVenc(data.dia_vencimento_padrao?.toString() || '5')
        setEmpMulta(data.percentual_multa_atraso?.toString() || '2')
        setEmpCobrancaAuto(!!data.cobranca_automatica_ativa)
      } else if (activeTab === 'usuarios' && isAdmin) {
        const list = await configuracoesService.listarUsuariosConfiguracoes()
        setUsuarios(list)
      } else if (activeTab === 'auditoria' && isAdmin) {
        const logs = await configuracoesService.listarLogsAuditoria()
        setAuditoriaLogs(logs)
      }
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar configurações.')
    } finally {
      setLoading(false)
    }
  }, [activeTab, isAdmin])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'configuracoes')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleSalvarMinhaConta = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formNome.trim()) {
      showToast('O nome é obrigatório.')
      return
    }

    try {
      await configuracoesService.atualizarMinhasConfiguracoes({
        nome: formNome.trim(),
        avatar_url: formAvatar.trim() || null,
        departamento: formDepto.trim() || null
      })
      showToast('Seus dados cadastrais foram atualizados!')
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao atualizar dados pessoais.')
    }
  }

  const handleTogglePreferencia = async (pref: PreferenciaNotificacaoItem) => {
    try {
      await configuracoesService.atualizarPreferenciasNotificacoes({
        canal: pref.canal,
        tipo: pref.tipo,
        ativo: !pref.ativo
      })
      showToast('Preferência de notificação salva!')
      // Recarrega apenas preferências
      const prefs = await configuracoesService.listarPreferenciasNotificacoes()
      setPreferencias(prefs)
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao salvar preferências.')
    }
  }

  const handleSalvarEmpresa = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!empRazao.trim()) return

    try {
      await configuracoesService.atualizarConfiguracoesEmpresa({
        razao_social: empRazao.trim(),
        documento: empDoc.trim(),
        email: empEmail.trim(),
        telefone: empTel.trim(),
        endereco: empEnd.trim(),
        dia_vencimento_padrao: parseInt(empVenc),
        percentual_multa_atraso: parseFloat(empMulta),
        cobranca_automatica_ativa: empCobrancaAuto
      })
      showToast('Configurações globais salvas e auditadas!')
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao atualizar dados da empresa.')
    }
  }

  const handleOpenNovoUsuario = () => {
    resetNovoUsuarioForm()
    setNovoUsuarioModalOpen(true)
  }

  const handleCadastrarUsuario = async (e: React.FormEvent) => {
    e.preventDefault()

    const payload: CriarUsuarioConfiguracoesPayload = {
      nome: formNovoUsuarioNome.trim(),
      email: formNovoUsuarioEmail.trim().toLowerCase(),
      senha_temporaria: formNovoUsuarioSenha,
      perfil_acesso: formNovoUsuarioPerfil,
      departamento: formNovoUsuarioDepto.trim() || null,
      status: formNovoUsuarioStatus,
    }

    if (!payload.nome || !payload.email || !payload.senha_temporaria) {
      showToast('Nome, e-mail e senha são obrigatórios.')
      return
    }

    if (payload.senha_temporaria.length < 8) {
      showToast('A senha precisa ter pelo menos 8 caracteres.')
      return
    }

    try {
      await configuracoesService.criarUsuarioConfiguracoes(payload)
      showToast('Novo usuário cadastrado com sucesso!')
      setNovoUsuarioModalOpen(false)
      resetNovoUsuarioForm()
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao cadastrar novo usuário.')
    }
  }

  const handleOpenGerenciarUsuario = (usr: UsuarioConfigItem) => {
    setSelectedUser(usr)
    setFormUserPerfil(usr.perfil_acesso)
    setFormUserStatus(usr.status)
    setFormUserDepto(usr.departamento || '')
    setUserModalOpen(true)
  }

  const handleSalvarUsuarioPerfil = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedUser) return

    try {
      await configuracoesService.atualizarUsuarioPerfil(selectedUser.usuario_id, {
        perfil_acesso: formUserPerfil,
        status: formUserStatus,
        departamento: formUserDepto.trim() || null
      })
      showToast('Perfil de acesso e privilégios atualizados!')
      setUserModalOpen(false)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao gerenciar conta.')
    }
  }

  const formatarData = (dtStr: string) => {
    if (!dtStr) return '-'
    const dateObj = new Date(dtStr)
    return dateObj.toLocaleString('pt-BR')
  }

  return (
    <AppShell titulo="Configurações">
      <div className="configuracoes-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        <header className="page-header">
          <div>
            <h1 className="page-title">Configurações do Sistema</h1>
            <p className="page-subtitle">Ajuste preferências de conta, notificações, dados fiscais e políticas organizacionais.</p>
          </div>
        </header>

        {/* Abas Superiores */}
        <nav className="config-tabs">
          <button 
            className={`tab-btn ${activeTab === 'minha-conta' ? 'active' : ''}`}
            onClick={() => setActiveTab('minha-conta')}
          >
            Minha Conta
          </button>
          {isAdmin && (
            <>
              <button 
                className={`tab-btn ${activeTab === 'empresa' ? 'active' : ''}`}
                onClick={() => setActiveTab('empresa')}
              >
                Dados da Empresa
              </button>
              <button 
                className={`tab-btn ${activeTab === 'usuarios' ? 'active' : ''}`}
                onClick={() => setActiveTab('usuarios')}
              >
                Contas e Acessos
              </button>
              <button 
                className={`tab-btn ${activeTab === 'auditoria' ? 'active' : ''}`}
                onClick={() => setActiveTab('auditoria')}
              >
                Logs de Auditoria
              </button>
            </>
          )}
        </nav>

        {loading ? (
          <LoadingState message="Carregando configurações..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : (
          <div className="config-tab-content">
            
            {/* 1. ABA MINHA CONTA */}
            {activeTab === 'minha-conta' && minhaConta && (
              <div className="config-grid">
                <form onSubmit={handleSalvarMinhaConta} className="card-box flex-col gap-4">
                  <h2 className="section-title">Dados do Meu Perfil</h2>
                  
                  <div className="form-group">
                    <label>E-mail (Login)</label>
                    <input type="text" disabled value={minhaConta.usuario?.email || ''} />
                  </div>

                  <div className="form-group">
                    <label>Nome Exibição</label>
                    <input 
                      type="text" 
                      required 
                      value={formNome} 
                      onChange={(e) => setFormNome(e.target.value)} 
                      disabled={!podeEditarProprioPerfil}
                    />
                  </div>

                  <div className="form-group">
                    <label>Avatar URL</label>
                    <input 
                      type="text" 
                      value={formAvatar} 
                      onChange={(e) => setFormAvatar(e.target.value)} 
                      placeholder="https://..."
                      disabled={!podeEditarProprioPerfil}
                    />
                  </div>

                  <div className="form-group row-2">
                    <div>
                      <label>Departamento</label>
                      <input 
                        type="text" 
                        value={formDepto} 
                        onChange={(e) => setFormDepto(e.target.value)}
                        placeholder="Ex: Engenharia / Comercial" 
                        disabled={!podeEditarProprioPerfil}
                      />
                    </div>
                    <div>
                      <label>Perfil de Acesso</label>
                      <input type="text" disabled value={minhaConta.perfil?.perfil_acesso || ''} />
                    </div>
                  </div>

                  {podeEditarProprioPerfil && (
                    <button type="submit" className="btn btn-primary align-self-start">
                      Salvar Cadastro
                    </button>
                  )}
                </form>

                {/* Preferências de Notificações */}
                <div className="card-box flex-col gap-4">
                  <h2 className="section-title">Preferências de Notificações</h2>
                  <p className="text-sm text-muted">Defina como e quais alertas você deseja receber.</p>
                  
                  <div className="notification-list">
                    {preferencias.map(pref => (
                      <div key={pref.id} className="notification-item">
                        <div>
                          <div className="font-semibold text-sm">{pref.tipo}</div>
                          <div className="text-xs text-muted">Via canal {pref.canal}</div>
                        </div>
                        <label className="switch">
                          <input 
                            type="checkbox" 
                            checked={pref.ativo}
                            onChange={() => handleTogglePreferencia(pref)}
                            disabled={!podeEditarProprioPerfil}
                          />
                          <span className="slider round"></span>
                        </label>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* 2. ABA EMPRESA */}
            {activeTab === 'empresa' && isAdmin && (
              <form onSubmit={handleSalvarEmpresa} className="config-grid">
                <div className="card-box flex-col gap-4">
                  <h2 className="section-title">Cadastro da Empresa</h2>
                  <div className="form-group">
                    <label>Razão Social</label>
                    <input
                      type="text"
                      required
                      value={empRazao}
                      onChange={(e) => setEmpRazao(e.target.value)}
                      disabled={!podeEditarEmpresa}
                    />
                  </div>
                  <div className="form-group row-2">
                    <div>
                      <label>CNPJ / Documento</label>
                      <input
                        type="text"
                        required
                        value={empDoc}
                        onChange={(e) => setEmpDoc(e.target.value)}
                        disabled={!podeEditarEmpresa}
                      />
                    </div>
                    <div>
                      <label>E-mail Corporativo</label>
                      <input
                        type="email"
                        required
                        value={empEmail}
                        onChange={(e) => setEmpEmail(e.target.value)}
                        disabled={!podeEditarEmpresa}
                      />
                    </div>
                  </div>
                  <div className="form-group row-2">
                    <div>
                      <label>Telefone</label>
                      <input
                        type="text"
                        value={empTel}
                        onChange={(e) => setEmpTel(e.target.value)}
                        disabled={!podeEditarEmpresa}
                      />
                    </div>
                    <div>
                      <label>Endereço Físico</label>
                      <input
                        type="text"
                        value={empEnd}
                        onChange={(e) => setEmpEnd(e.target.value)}
                        disabled={!podeEditarEmpresa}
                      />
                    </div>
                  </div>
                </div>

                <div className="card-box flex-col gap-4">
                  <h2 className="section-title">Faturamento & Cobrança Global</h2>
                  <div className="form-group row-2">
                    <div>
                      <label>Dia Vencimento Padrão</label>
                      <input
                        type="number"
                        min="1"
                        max="31"
                        required
                        value={empVenc}
                        onChange={(e) => setEmpVenc(e.target.value)}
                        disabled={!podeEditarEmpresa}
                      />
                    </div>
                    <div>
                      <label>Multa por Atraso (%)</label>
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        required
                        value={empMulta}
                        onChange={(e) => setEmpMulta(e.target.value)}
                        disabled={!podeEditarEmpresa}
                      />
                    </div>
                  </div>
                  <div className="form-group checkbox-group">
                    <label className="checkbox-label">
                      <input
                        type="checkbox"
                        checked={empCobrancaAuto}
                        onChange={(e) => setEmpCobrancaAuto(e.target.checked)}
                        disabled={!podeEditarEmpresa}
                      />
                      Gatilho automático de cobranças vencidas por e-mail
                    </label>
                  </div>

                  {podeEditarEmpresa && (
                    <button type="submit" className="btn btn-primary align-self-start">
                      Salvar Parâmetros
                    </button>
                  )}
                </div>
              </form>
            )}

            {/* 3. ABA USUÁRIOS */}
            {activeTab === 'usuarios' && isAdmin && (
              <div className="responsive-table-container card-box">
                <div className="row-between margin-bottom-4">
                  <h2 className="section-title margin-bottom-0">Gerenciamento de Contas e Perfis</h2>
                  {podeGerenciarUsuarios && (
                    <button className="btn btn-primary" onClick={handleOpenNovoUsuario}>
                      Cadastrar Usuário
                    </button>
                  )}
                </div>
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Nome</th>
                      <th>E-mail</th>
                      <th>Perfil Acesso (Persona)</th>
                      <th>Departamento</th>
                      <th>Status</th>
                      <th className="text-center">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    {usuarios.map(usr => (
                      <tr key={usr.usuario_id}>
                        <td><strong>{usr.nome}</strong></td>
                        <td>{usr.email}</td>
                        <td>
                          <span className="badge-persona">{usr.perfil_acesso}</span>
                        </td>
                        <td>{usr.departamento || '-'}</td>
                        <td>
                          <span className={`status-badge status-${usr.status === 'Ativo' ? 'pago' : 'cancelado'}`}>
                            {usr.status}
                          </span>
                        </td>
                        <td className="text-center">
                          {podeGerenciarUsuarios && (
                            <button className="btn btn-xs btn-outline" onClick={() => handleOpenGerenciarUsuario(usr)}>
                              Gerenciar
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {/* 4. ABA AUDITORIA */}
            {activeTab === 'auditoria' && isAdmin && (
              <div className="responsive-table-container card-box">
                <h2 className="section-title margin-bottom-4">Logs de Auditoria de Segurança</h2>
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Data / Hora</th>
                      <th>Evento</th>
                      <th>Usuário</th>
                      <th>IP Address</th>
                      <th>Detalhes da Mutação</th>
                    </tr>
                  </thead>
                  <tbody>
                    {auditoriaLogs.map(log => (
                      <tr key={log.id} className="table-row-hover text-xs">
                        <td className="text-muted">{formatarData(log.criado_em)}</td>
                        <td>
                          <span className="badge-evento">{log.evento}</span>
                        </td>
                        <td><strong>{log.usuario_nome}</strong></td>
                        <td><code>{log.ip_address}</code></td>
                        <td>{log.detalhes}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

          </div>
        )}

        {/* Modal Cadastrar Usuário (Admin) */}
        {novoUsuarioModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Cadastrar Novo Usuário</h3>
                <button className="modal-close-btn" onClick={() => setNovoUsuarioModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCadastrarUsuario}>
                <div className="form-group">
                  <label htmlFor="novo-usuario-nome">Nome Completo</label>
                  <input
                    id="novo-usuario-nome"
                    type="text"
                    required
                    value={formNovoUsuarioNome}
                    onChange={(e) => setFormNovoUsuarioNome(e.target.value)}
                    placeholder="Ex: Maria Oliveira"
                  />
                </div>

                <div className="form-group row-2">
                  <div>
                    <label htmlFor="novo-usuario-email">E-mail</label>
                    <input
                      id="novo-usuario-email"
                      type="email"
                      required
                      value={formNovoUsuarioEmail}
                      onChange={(e) => setFormNovoUsuarioEmail(e.target.value)}
                      placeholder="usuario@empresa.com"
                    />
                  </div>
                  <div>
                    <label htmlFor="novo-usuario-senha">Senha Temporária</label>
                    <input
                      id="novo-usuario-senha"
                      type="password"
                      required
                      minLength={8}
                      value={formNovoUsuarioSenha}
                      onChange={(e) => setFormNovoUsuarioSenha(e.target.value)}
                      placeholder="Mínimo de 8 caracteres"
                    />
                  </div>
                </div>

                <div className="form-group row-2">
                  <div>
                    <label htmlFor="novo-usuario-perfil">Perfil de Acesso</label>
                    <select
                      id="novo-usuario-perfil"
                      value={formNovoUsuarioPerfil}
                      onChange={(e) => setFormNovoUsuarioPerfil(e.target.value as CriarUsuarioConfiguracoesPayload['perfil_acesso'])}
                    >
                      <option value="Visualizador">Visualizador</option>
                      <option value="Administrador">Administrador</option>
                      <option value="Financeiro">Financeiro</option>
                      <option value="Projetos">Projetos</option>
                      <option value="Comercial">Comercial</option>
                      <option value="Técnico">Técnico</option>
                    </select>
                  </div>
                  <div>
                    <label htmlFor="novo-usuario-status">Status</label>
                    <select
                      id="novo-usuario-status"
                      value={formNovoUsuarioStatus}
                      onChange={(e) => setFormNovoUsuarioStatus(e.target.value as 'Ativo' | 'Inativo')}
                    >
                      <option value="Ativo">Ativo</option>
                      <option value="Inativo">Inativo</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label htmlFor="novo-usuario-departamento">Departamento</label>
                  <input
                    id="novo-usuario-departamento"
                    type="text"
                    value={formNovoUsuarioDepto}
                    onChange={(e) => setFormNovoUsuarioDepto(e.target.value)}
                    placeholder="Ex: Financeiro / Comercial"
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setNovoUsuarioModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Cadastrar</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Gerenciar Usuário (Admin) */}
        {userModalOpen && selectedUser && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Configurar Conta de Usuário</h3>
                <button className="modal-close-btn" onClick={() => setUserModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleSalvarUsuarioPerfil}>
                <p className="baixa-info-msg">
                  Editando conta de: <strong>{selectedUser.nome}</strong> ({selectedUser.email}).
                </p>

                <div className="form-group">
                  <label>Perfil de Acesso (RBAC)</label>
                  <select 
                    value={formUserPerfil}
                    onChange={(e) => setFormUserPerfil(e.target.value)}
                  >
                    <option value="Administrador">Administrador</option>
                    <option value="Financeiro">Analista Financeiro</option>
                    <option value="Projetos">Gerente de Projetos</option>
                    <option value="Comercial">Consultor Comercial</option>
                    <option value="Técnico">Profissional Técnico</option>
                  </select>
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Status</label>
                    <select 
                      value={formUserStatus}
                      onChange={(e) => setFormUserStatus(e.target.value as any)}
                    >
                      <option value="Ativo">Ativo</option>
                      <option value="Inativo">Inativo (Bloquear Login)</option>
                    </select>
                  </div>
                  <div>
                    <label>Departamento</label>
                    <input 
                      type="text" 
                      value={formUserDepto}
                      onChange={(e) => setFormUserDepto(e.target.value)}
                      placeholder="Ex: Suporte / Engenharia"
                    />
                  </div>
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setUserModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Salvar Acessos</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
