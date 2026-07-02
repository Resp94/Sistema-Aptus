import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { equipeService } from '../services/equipe.service'
import { projectsService } from '../services/projetos.service'
import { podeLer, podeEscrever } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState } from '../components/ui/States'
import type { MembroEquipeItem, AlocacaoEquipeItem, ApontamentoHorasItem, MetricasEquipe } from '../types/equipe'
import type { Projeto, TarefaKanban } from '../types/projetos'
import './EquipePage.css'

export default function EquipePage() {
  const { perfil, permissoes } = useAuth()
  const navigate = useNavigate()
  const temEscrita = podeEscrever(permissoes, 'equipe')

  // Estados de dados
  const [membros, setMembros] = useState<MembroEquipeItem[]>([])
  const [metricas, setMetricas] = useState<MetricasEquipe | null>(null)
  const [detalhe, setDetalhe] = useState<MembroEquipeItem | null>(null)
  const [alocacoes, setAlocacoes] = useState<AlocacaoEquipeItem[]>([])
  const [apontamentos, setApontamentos] = useState<ApontamentoHorasItem[]>([])
  const [projetos, setProjetos] = useState<Projeto[]>([])
  const [todasTarefas, setTodasTarefas] = useState<TarefaKanban[]>([])

  // Filtros
  const [statusFiltro, setStatusFiltro] = useState<string>('Todos')
  const [buscaText, setBuscaText] = useState('')

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)

  // Modais
  const [novoMembroModalOpen, setNovoMembroModalOpen] = useState(false)
  const [alocarModalOpen, setAlocarModalOpen] = useState(false)
  const [apontarModalOpen, setApontarModalOpen] = useState(false)

  // Form Novo Membro
  const [formNome, setFormNome] = useState('')
  const [formFuncao, setFormFuncao] = useState('')
  const [formHabilidades, setFormHabilidades] = useState('')
  const [formCapacidade, setFormCapacidade] = useState('100')
  const [formCustoHora, setFormCustoHora] = useState('')

  // Form Alocar Membro
  const [alocarMembroId, setAlocarMembroId] = useState('')
  const [alocarProjetoId, setAlocarProjetoId] = useState('')
  const [alocarInicio, setAlocarInicio] = useState(new Date().toISOString().split('T')[0])
  const [alocarFim, setAlocarFim] = useState('')
  const [alocarPct, setAlocarPct] = useState('50')
  const [alocarFuncao, setAlocarFuncao] = useState('')

  // Form Apontar Horas
  const [apontarMembroId, setApontarMembroId] = useState('')
  const [apontarProjetoId, setApontarProjetoId] = useState('')
  const [apontarTarefaId, setApontarTarefaId] = useState('')
  const [apontarHoras, setApontarHoras] = useState('')
  const [apontarData, setApontarData] = useState(new Date().toISOString().split('T')[0])
  const [apontarDescricao, setApontarDescricao] = useState('')

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg)
    setTimeout(() => {
      setToastMsg(null)
    }, 3000)
  }, [])

  // Carregar membros e métricas
  const fetchDados = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [list, stats, projList, tList] = await Promise.all([
        equipeService.listarMembrosEquipe(
          statusFiltro === 'Todos' ? undefined : statusFiltro,
          buscaText.trim() || undefined
        ),
        equipeService.obterMetricasEquipe(),
        projectsService.listarProjetos(),
        projectsService.listarTarefasKanban()
      ])

      setMembros(list)
      setMetricas(stats)
      setProjetos(projList)
      setTodasTarefas(tList)
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar dados da equipe.')
    } finally {
      setLoading(false)
    }
  }, [statusFiltro, buscaText])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'equipe')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleVerDetalhe = async (membro: MembroEquipeItem) => {
    try {
      const [alocList, apList] = await Promise.all([
        equipeService.obterAlocacaoPorProjeto(membro.id),
        equipeService.listarApontamentosHoras(membro.id)
      ])

      setDetalhe(membro)
      setAlocacoes(alocList)
      setApontamentos(apList)

      setTimeout(() => {
        document.getElementById('membroDetailSection')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }, 100)
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao obter detalhes do membro da equipe.')
    }
  }

  const handleCriarMembro = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formNome.trim() || !formFuncao.trim() || !formCapacidade) {
      showToast('Nome, Função e Capacidade são obrigatórios.')
      return
    }

    const capacidadeNum = parseInt(formCapacidade)
    const custoNum = formCustoHora ? parseFloat(formCustoHora) : null

    try {
      await equipeService.criarMembroEquipe({
        nome: formNome.trim(),
        funcao: formFuncao.trim(),
        habilidades: formHabilidades.split(',').map(s => s.trim()).filter(Boolean),
        status: 'Disponível',
        capacidade: capacidadeNum,
        custo_hora: custoNum
      })

      showToast('Membro cadastrado com sucesso!')
      setNovoMembroModalOpen(false)
      
      // Reset
      setFormNome('')
      setFormFuncao('')
      setFormHabilidades('')
      setFormCapacidade('100')
      setFormCustoHora('')

      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao cadastrar membro.')
    }
  }

  const handleOpenAlocar = (membro: MembroEquipeItem) => {
    setAlocarMembroId(membro.id)
    setAlocarModalOpen(true)
  }

  const handleAlocarMembro = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!alocarMembroId || !alocarProjetoId || !alocarInicio || !alocarFim || !alocarPct || !alocarFuncao.trim()) {
      showToast('Todos os campos de alocação são obrigatórios.')
      return
    }

    const pctNum = parseInt(alocarPct)

    try {
      await equipeService.alocarMembroProjeto({
        membro_equipe_id: alocarMembroId,
        projeto_id: alocarProjetoId,
        data_inicio: alocarInicio,
        data_fim: alocarFim,
        percentual_alocacao: pctNum,
        funcao_no_projeto: alocarFuncao.trim()
      })

      showToast('Membro alocado no projeto com sucesso!')
      setAlocarModalOpen(false)
      
      // Reset
      setAlocarFuncao('')
      setAlocarProjetoId('')

      if (detalhe && detalhe.id === alocarMembroId) {
        handleVerDetalhe(detalhe)
      }
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao alocar membro.')
    }
  }

  const handleOpenApontar = (membro: MembroEquipeItem) => {
    setApontarMembroId(membro.id)
    // Se for o Técnico logado, restringe apenas a ele
    setApontarModalOpen(true)
  }

  const handleApontarHoras = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!apontarMembroId || !apontarProjetoId || !apontarTarefaId || !apontarHoras || !apontarData || !apontarDescricao.trim()) {
      showToast('Todos os campos de apontamento são obrigatórios.')
      return
    }

    const horasNum = parseFloat(apontarHoras)
    if (isNaN(horasNum) || horasNum <= 0) {
      showToast('As horas apontadas devem ser maiores que zero.')
      return
    }

    try {
      await equipeService.registrarApontamentoHoras({
        tarefa_id: apontarTarefaId,
        projeto_id: apontarProjetoId,
        membro_equipe_id: apontarMembroId,
        horas: horasNum,
        descricao: apontarDescricao.trim(),
        data: apontarData
      })

      showToast('Horas apontadas com sucesso!')
      setApontarModalOpen(false)
      
      // Reset
      setApontarHoras('')
      setApontarDescricao('')
      setApontarTarefaId('')

      if (detalhe && detalhe.id === apontarMembroId) {
        handleVerDetalhe(detalhe)
      }
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar apontamento de horas.')
    }
  }

  const handleInativarMembro = async (id: string, nome: string) => {
    if (!window.confirm(`Deseja realmente inativar/arquivar o perfil de "${nome}" na equipe?`)) {
      return
    }

    try {
      await equipeService.inativarMembroEquipe(id)
      showToast('Membro da equipe desativado com sucesso.')
      setDetalhe(null)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao desativar membro.')
    }
  }

  const formatarMoeda = (val: number | null) => {
    if (val === null) return 'Restrito'
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
  }

  const formatarData = (dtStr: string) => {
    if (!dtStr) return '-'
    const datePart = dtStr.includes('T') ? dtStr.split('T')[0] : dtStr
    const parts = datePart.split('-')
    if (parts.length === 3) {
      return `${parts[2]}/${parts[1]}/${parts[0]}`
    }
    return new Date(dtStr).toLocaleDateString('pt-BR')
  }

  return (
    <AppShell titulo="Gestão de Equipe">
      <div className="equipe-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        <header className="page-header">
          <div>
            <h1 className="page-title">Equipe & Alocação</h1>
            <p className="page-subtitle">Monitore a capacidade do time, aloque engenheiros em projetos e lance horas de trabalho.</p>
          </div>
          {temEscrita && (
            <button className="btn btn-primary btn-icon" onClick={() => setNovoMembroModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Adicionar Membro
            </button>
          )}
        </header>

        {/* Métricas */}
        {metricas && (
          <section className="dashboard-cards">
            <div className="card-item">
              <div className="card-label">Total de Colaboradores</div>
              <div className="card-value color-neutral">{metricas.total_membros}</div>
              <div className="card-sub">{metricas.membros_ativos} profissionais ativos</div>
            </div>
            <div className="card-item">
              <div className="card-label">Capacidade Disponível</div>
              <div className="card-value color-primary">{metricas.capacidade_total}h</div>
              <div className="card-sub">Horas semanais combinadas</div>
            </div>
            <div className="card-item">
              <div className="card-label">Custo Médio / Hora</div>
              <div className="card-value color-neutral">
                {metricas.custo_medio !== null ? formatarMoeda(metricas.custo_medio) : 'Restrito'}
              </div>
              <div className="card-sub">Baseado na folha de alocação</div>
            </div>
          </section>
        )}

        {/* Filtros */}
        <section className="filters-bar card-box">
          <div className="filters-grid">
            <div className="filter-field">
              <label htmlFor="filter-status">Status</label>
              <select 
                id="filter-status"
                value={statusFiltro} 
                onChange={(e) => setStatusFiltro(e.target.value)}
              >
                <option value="Todos">Todos</option>
                <option value="Disponível">Disponíveis</option>
                <option value="Alocado">Alocados</option>
                <option value="Férias">Em Férias</option>
                <option value="Ausente">Ausentes</option>
              </select>
            </div>
            <div className="filter-field search-field">
              <label htmlFor="filter-busca">Buscar</label>
              <input 
                id="filter-busca"
                type="text" 
                placeholder="Buscar por nome ou função..."
                value={buscaText} 
                onChange={(e) => setBuscaText(e.target.value)} 
              />
            </div>
          </div>
        </section>

        {/* Tabela de Membros */}
        {loading ? (
          <LoadingState message="Carregando engenheiros da equipe..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : membros.length === 0 ? (
          <EmptyState 
            title="Nenhum membro cadastrado" 
            description="Não encontramos nenhum registro de equipe para os filtros configurados."
            action={temEscrita ? { label: 'Adicionar Membro', onClick: () => setNovoMembroModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Nome / Função</th>
                  <th>Habilidades</th>
                  <th>Capacidade</th>
                  <th className="text-right">Custo / Hora</th>
                  <th>Status</th>
                  <th className="text-center">Ações</th>
                </tr>
              </thead>
              <tbody>
                {membros.map(item => (
                  <tr key={item.id} className="table-row-hover">
                    <td>
                      <div className="font-semibold text-fg">{item.nome}</div>
                      <div className="text-xs text-muted">{item.funcao}</div>
                    </td>
                    <td>
                      <div className="habilidades-tags">
                        {(item.habilidades ?? []).slice(0, 3).map((h, i) => (
                          <span key={i} className="skill-tag">{h}</span>
                        ))}
                        {(item.habilidades?.length ?? 0) > 3 && (
                          <span className="skill-tag skill-more">+{(item.habilidades?.length ?? 0) - 3}</span>
                        )}
                      </div>
                    </td>
                    <td>{item.capacidade}%</td>
                    <td className="text-right font-semibold text-fg">
                      {item.custo_hora !== null ? formatarMoeda(item.custo_hora) : 'Restrito'}
                    </td>
                    <td>
                      <span className={`status-badge status-${item.status.toLowerCase().replace(' ', '-')}`}>
                        {item.status}
                      </span>
                    </td>
                    <td className="text-center actions-cell">
                      <button className="btn btn-xs btn-outline" onClick={() => handleVerDetalhe(item)}>
                        Visualizar
                      </button>
                      {temEscrita && (
                        <>
                          <button className="btn btn-xs btn-outline-secondary" onClick={() => handleOpenAlocar(item)}>
                            Alocar
                          </button>
                          <button className="btn btn-xs btn-outline-secondary" onClick={() => handleOpenApontar(item)}>
                            Apontar
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Detalhes Expansíveis */}
        {detalhe && (
          <section id="membroDetailSection" className="detail-section card-box">
            <div className="detail-header">
              <div>
                <span className="detail-tag">Cadastro Funcional</span>
                <h2 className="detail-title">{detalhe.nome}</h2>
                <p className="text-sm text-muted">{detalhe.funcao}</p>
              </div>
              <div className="detail-header-actions">
                {temEscrita && (
                  <button className="btn btn-outline color-danger" onClick={() => handleInativarMembro(detalhe.id, detalhe.nome)}>
                    Desativar Profissional
                  </button>
                )}
              </div>
            </div>

            <div className="detail-grid">
              <div className="detail-col">
                <h3 className="detail-sub">Alocações Ativas em Projetos ({alocacoes.length})</h3>
                {alocacoes.length === 0 ? (
                  <p className="no-records-msg">Este profissional não possui alocações vigentes.</p>
                ) : (
                  <ul className="info-card-list">
                    {alocacoes.map(aloc => (
                      <li key={aloc.id} className="info-card-item">
                        <div className="card-title font-semibold">{aloc.projeto_nome}</div>
                        <div className="card-body-text">
                          Papel: <strong>{aloc.funcao_no_projeto}</strong> | Alocação: <strong>{aloc.percentual_alocacao}%</strong>
                        </div>
                        <div className="card-dates text-xs text-muted">
                          Período: {formatarData(aloc.data_inicio)} até {formatarData(aloc.data_fim)}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>

              <div className="detail-col">
                <h3 className="detail-sub">Histórico de Apontamento de Horas ({apontamentos.length})</h3>
                {apontamentos.length === 0 ? (
                  <p className="no-records-msg">Nenhum apontamento registrado recentemente.</p>
                ) : (
                  <ul className="info-card-list scroll-list">
                    {apontamentos.map(ap => (
                      <li key={ap.id} className="info-card-item">
                        <div className="card-title font-semibold">{ap.projeto_nome}</div>
                        <div className="card-body-text italic">"{ap.descricao}"</div>
                        <div className="card-body-meta text-xs">
                          Horas: <strong>{ap.horas}h</strong> | Tarefa: <strong>{ap.tarefa_titulo || 'Atividade geral'}</strong>
                        </div>
                        <div className="card-dates text-xs text-muted">
                          Lançado em {formatarData(ap.data)}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
          </section>
        )}

        {/* Modal Novo Membro */}
        {novoMembroModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Cadastrar Novo Membro na Equipe</h3>
                <button className="modal-close-btn" onClick={() => setNovoMembroModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarMembro}>
                <div className="form-group">
                  <label>Nome Completo</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Carlos Roberto Silva" 
                    value={formNome}
                    onChange={(e) => setFormNome(e.target.value)}
                  />
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Função / Cargo</label>
                    <input 
                      type="text" 
                      required 
                      placeholder="Ex: Arquiteto de Software" 
                      value={formFuncao}
                      onChange={(e) => setFormFuncao(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Capacidade Semanal (%)</label>
                    <input 
                      type="number" 
                      required 
                      min="1" 
                      max="100" 
                      value={formCapacidade}
                      onChange={(e) => setFormCapacidade(e.target.value)}
                    />
                  </div>
                </div>

                {perfil?.perfil_acesso === 'Administrador' && (
                  <div className="form-group">
                    <label>Custo por Hora (R$)</label>
                    <input 
                      type="number" 
                      step="0.01" 
                      placeholder="0.00 (Opcional - restrito a administradores)" 
                      value={formCustoHora}
                      onChange={(e) => setFormCustoHora(e.target.value)}
                    />
                  </div>
                )}

                <div className="form-group">
                  <label>Habilidades (Separadas por vírgula)</label>
                  <input 
                    type="text" 
                    placeholder="Ex: React, Node.js, AWS, Kubernetes" 
                    value={formHabilidades}
                    onChange={(e) => setFormHabilidades(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setNovoMembroModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Cadastrar</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Alocar Membro */}
        {alocarModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Alocar Engenheiro em Projeto</h3>
                <button className="modal-close-btn" onClick={() => setAlocarModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleAlocarMembro}>
                <div className="form-group">
                  <label>Projeto de Destino</label>
                  <select 
                    required
                    value={alocarProjetoId}
                    onChange={(e) => setAlocarProjetoId(e.target.value)}
                  >
                    <option value="">Selecione o projeto</option>
                    {projetos.map(p => (
                      <option key={p.id} value={p.id}>{p.nome}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label>Papel no Projeto</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Líder Técnico / DevOps" 
                    value={alocarFuncao}
                    onChange={(e) => setAlocarFuncao(e.target.value)}
                  />
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Percentual de Alocação (%)</label>
                    <input 
                      type="number" 
                      required 
                      min="10" 
                      max="100" 
                      value={alocarPct}
                      onChange={(e) => setAlocarPct(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Data de Início</label>
                    <input 
                      type="date" 
                      required 
                      value={alocarInicio}
                      onChange={(e) => setAlocarInicio(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Data Prevista de Término</label>
                  <input 
                    type="date" 
                    required 
                    value={alocarFim}
                    onChange={(e) => setAlocarFim(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setAlocarModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Confirmar Alocação</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Apontar Horas */}
        {apontarModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Apontamento de Horas de Trabalho</h3>
                <button className="modal-close-btn" onClick={() => setApontarModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleApontarHoras}>
                <div className="form-group">
                  <label>Membro Responsável</label>
                  <select 
                    disabled={perfil?.perfil_acesso === 'Técnico'}
                    value={apontarMembroId}
                    onChange={(e) => setApontarMembroId(e.target.value)}
                  >
                    {membros.map(m => (
                      <option key={m.id} value={m.id}>{m.nome}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Projeto</label>
                    <select 
                      required
                      value={apontarProjetoId}
                      onChange={(e) => setApontarProjetoId(e.target.value)}
                    >
                      <option value="">Selecione o projeto</option>
                      {projetos.map(p => (
                        <option key={p.id} value={p.id}>{p.nome}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label>Tarefa Associada</label>
                    <select 
                      required
                      value={apontarTarefaId}
                      onChange={(e) => setApontarTarefaId(e.target.value)}
                      disabled={!apontarProjetoId}
                    >
                      <option value="">Selecione a tarefa</option>
                      {todasTarefas
                        .filter(t => t.projeto_id === apontarProjetoId)
                        .map(t => (
                          <option key={t.id} value={t.id}>{t.titulo} ({t.situacao})</option>
                        ))
                      }
                      <option value="geral">Atividade Geral do Projeto (Sem tarefa)</option>
                    </select>
                  </div>
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Horas Gastas</label>
                    <input 
                      type="number" 
                      step="0.25" 
                      min="0.25" 
                      required 
                      placeholder="0.00" 
                      value={apontarHoras}
                      onChange={(e) => setApontarHoras(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Data da Atividade</label>
                    <input 
                      type="date" 
                      required 
                      value={apontarData}
                      onChange={(e) => setApontarData(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Descrição do Trabalho Realizado</label>
                  <textarea 
                    rows={3} 
                    required 
                    placeholder="Descreva as atividades executadas detalhadamente..."
                    value={apontarDescricao}
                    onChange={(e) => setApontarDescricao(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setApontarModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Registrar Apontamento</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
