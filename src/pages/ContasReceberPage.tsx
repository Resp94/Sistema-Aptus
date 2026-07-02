import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { financeiroService } from '../services/financeiro.service'
import { clientesService } from '../services/clientes.service'
import { podeLer, podeEscrever } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState } from '../components/ui/States'
import type { ContaReceberItem, MetricasContas } from '../types/financeiro'
import type { Cliente } from '../types/clientes'
import './ContasReceberPage.css'

export default function ContasReceberPage() {
  const { perfil, permissoes } = useAuth()
  const navigate = useNavigate()
  const temEscrita = podeEscrever(permissoes, 'contas-receber')

  // Datas padrão para os próximos 30 dias de contas a receber
  const obterDatasPadrao = () => {
    const hoje = new Date()
    const inicio = new Date(hoje.getFullYear(), hoje.getMonth(), 1)
    const fim = new Date(hoje.getFullYear(), hoje.getMonth() + 1, 15)

    const formatar = (d: Date) => d.toISOString().split('T')[0]
    return {
      inicio: formatar(inicio),
      fim: formatar(fim)
    }
  }

  const { inicio: dtInicio, fim: dtFim } = obterDatasPadrao()

  // Estados de dados
  const [contas, setContas] = useState<ContaReceberItem[]>([])
  const [metricas, setMetricas] = useState<MetricasContas | null>(null)
  const [clientes, setClientes] = useState<Cliente[]>([])

  // Filtros
  const [statusFiltro, setStatusFiltro] = useState<string>('Pendente')
  const [clienteFiltro, setClienteFiltro] = useState('')
  const [dataInicio, setDataInicio] = useState(dtInicio)
  const [dataFim, setDataFim] = useState(dtFim)

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)

  // Modais
  const [novaReceitaModalOpen, setNovaReceitaModalOpen] = useState(false)
  const [baixaModalOpen, setBaixaModalOpen] = useState(false)

  // Form de Receita
  const [formDescricao, setFormDescricao] = useState('')
  const [formValor, setFormValor] = useState('')
  const [formCategoria, setFormCategoria] = useState('Projetos')
  const [formClienteId, setFormClienteId] = useState('')
  const [formDataCompetencia, setFormDataCompetencia] = useState(new Date().toISOString().split('T')[0])
  const [formDataVencimento, setFormDataVencimento] = useState('')

  // Form de Baixa
  const [baixaId, setBaixaId] = useState<string | null>(null)
  const [baixaDescricao, setBaixaDescricao] = useState('')
  const [baixaValor, setBaixaValor] = useState('')
  const [baixaData, setBaixaData] = useState(new Date().toISOString().split('T')[0])

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg)
    setTimeout(() => {
      setToastMsg(null)
    }, 3000)
  }, [])

  // Carregar dados
  const fetchDados = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [list, stats] = await Promise.all([
        financeiroService.listarContasReceber(
          statusFiltro === 'Todos' ? undefined : statusFiltro,
          clienteFiltro || undefined,
          dataInicio || undefined,
          dataFim || undefined
        ),
        financeiroService.obterMetricasContas('a_receber', dataInicio || undefined, dataFim || undefined)
      ])

      setContas(list)
      setMetricas(stats)

      // Módulo "clientes" pode ser negado por RBAC (ex.: perfil Financeiro); degrada
      // para lista vazia em vez de quebrar a página inteira.
      try {
        setClientes(await clientesService.listarClientes('cliente'))
      } catch {
        setClientes([])
      }
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar contas a receber.')
    } finally {
      setLoading(false)
    }
  }, [statusFiltro, clienteFiltro, dataInicio, dataFim])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'contas-receber')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleCriarContaReceber = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formDescricao.trim() || !formValor || !formDataVencimento) {
      showToast('Descrição, Valor e Vencimento são obrigatórios.')
      return
    }

    const valorNum = parseFloat(formValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor deve ser maior que zero.')
      return
    }

    try {
      await financeiroService.criarLancamento({
        tipo: 'receita',
        natureza: 'a_receber',
        descricao: formDescricao.trim(),
        valor: valorNum,
        categoria: formCategoria,
        cliente_id: formClienteId || null,
        data_competencia: formDataCompetencia,
        data_vencimento: formDataVencimento
      })

      showToast('Conta a receber cadastrada com sucesso!')
      setNovaReceitaModalOpen(false)
      
      // Reset
      setFormDescricao('')
      setFormValor('')
      setFormClienteId('')
      setFormDataVencimento('')

      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao cadastrar receita.')
    }
  }

  const handleOpenBaixa = (item: ContaReceberItem) => {
    setBaixaId(item.id)
    setBaixaDescricao(item.descricao)
    setBaixaValor(item.valor.toString())
    setBaixaModalOpen(true)
  }

  const handleRegistrarBaixa = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!baixaId || !baixaData || !baixaValor) return

    const valorNum = parseFloat(baixaValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor recebido deve ser maior que zero.')
      return
    }

    try {
      await financeiroService.registrarPagamentoLancamento(baixaId, baixaData, valorNum)
      showToast('Baixa de receita registrada com sucesso!')
      setBaixaModalOpen(false)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar recebimento.')
    }
  }

  const formatarMoeda = (val: number) => {
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
    <AppShell titulo="Contas a Receber">
      <div className="contas-receber-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        <header className="page-header">
          <div>
            <h1 className="page-title">Contas a Receber</h1>
            <p className="page-subtitle">Acompanhe as receitas previstas, faturas e recebimentos.</p>
          </div>
          {temEscrita && (
            <button className="btn btn-primary btn-icon" onClick={() => setNovaReceitaModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Lançar Receita
            </button>
          )}
        </header>

        {/* Métricas Superiores */}
        {metricas && (
          <section className="dashboard-cards metricas-contas">
            <div className="card-item">
              <div className="card-label">Total a Receber</div>
              <div className="card-value color-neutral">{formatarMoeda(metricas.total_valor)}</div>
              <div className="card-sub">{metricas.total_qtd} parcelas previstas</div>
            </div>
            <div className="card-item border-danger">
              <div className="card-label">Receitas Vencidas</div>
              <div className="card-value color-danger">{formatarMoeda(metricas.vencidas_valor)}</div>
              <div className="card-sub">{metricas.vencidas_qtd} faturas atrasadas</div>
            </div>
            <div className="card-item border-warn">
              <div className="card-label">Vencem Hoje</div>
              <div className="card-value color-warn">{formatarMoeda(metricas.vencem_hoje_valor)}</div>
              <div className="card-sub">{metricas.vencem_hoje_qtd} faturas hoje</div>
            </div>
            <div className="card-item border-primary">
              <div className="card-label">Próximos 7 Dias</div>
              <div className="card-value color-primary">{formatarMoeda(metricas.proximos_7_dias_valor)}</div>
              <div className="card-sub">{metricas.proximos_7_dias_qtd} faturas próximas</div>
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
                <option value="Pendente">Pendentes</option>
                <option value="Pago">Pagas</option>
                <option value="Vencido">Vencidas</option>
              </select>
            </div>
            <div className="filter-field">
              <label htmlFor="filter-cliente">Cliente</label>
              <select 
                id="filter-cliente"
                value={clienteFiltro} 
                onChange={(e) => setClienteFiltro(e.target.value)}
              >
                <option value="">Todos</option>
                {clientes.map(c => (
                  <option key={c.id} value={c.id}>{c.empresa}</option>
                ))}
              </select>
            </div>
            <div className="filter-field">
              <label htmlFor="filter-inicio">Data Início</label>
              <input 
                id="filter-inicio"
                type="date" 
                value={dataInicio} 
                onChange={(e) => setDataInicio(e.target.value)} 
              />
            </div>
            <div className="filter-field">
              <label htmlFor="filter-fim">Data Fim</label>
              <input 
                id="filter-fim"
                type="date" 
                value={dataFim} 
                onChange={(e) => setDataFim(e.target.value)} 
              />
            </div>
          </div>
        </section>

        {/* Tabela de Lançamentos */}
        {loading ? (
          <LoadingState message="Carregando faturas a receber..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : contas.length === 0 ? (
          <EmptyState 
            title="Nenhuma fatura a receber" 
            description="Nenhuma previsão de receita encontrada para os filtros aplicados."
            action={temEscrita ? { label: 'Lançar Receita', onClick: () => setNovaReceitaModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Descrição</th>
                  <th>Cliente</th>
                  <th>Competência</th>
                  <th>Vencimento</th>
                  <th className="text-right">Valor</th>
                  <th>Status</th>
                  {temEscrita && <th className="text-center">Ações</th>}
                </tr>
              </thead>
              <tbody>
                {contas.map(item => (
                  <tr key={item.id} className="table-row-hover">
                    <td>
                      <div className="font-semibold text-fg">{item.descricao}</div>
                    </td>
                    <td>{item.cliente || 'Cliente avulso'}</td>
                    <td>{formatarData(item.data_competencia)}</td>
                    <td>{formatarData(item.data_vencimento)}</td>
                    <td className="text-right font-semibold color-success">
                      {formatarMoeda(item.valor)}
                    </td>
                    <td>
                      <span className={`status-badge status-${item.status_exibicao.toLowerCase().replace(' ', '-')}`}>
                        {item.status_exibicao}
                      </span>
                    </td>
                    {temEscrita && (
                      <td className="text-center">
                        {item.status_exibicao !== 'Pago' && (
                          <button className="btn btn-xs btn-outline" onClick={() => handleOpenBaixa(item)}>
                            Receber
                          </button>
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Modal Novo Lançamento de Receita */}
        {novaReceitaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Lançar Nova Receita a Receber</h3>
                <button className="modal-close-btn" onClick={() => setNovaReceitaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarContaReceber}>
                <div className="form-group">
                  <label>Descrição do Recebimento</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Parcela 02/03 - Licenciamento Inovatec" 
                    value={formDescricao}
                    onChange={(e) => setFormDescricao(e.target.value)}
                  />
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Valor (R$)</label>
                    <input 
                      type="number" 
                      step="0.01" 
                      min="0.01" 
                      required 
                      placeholder="0.00" 
                      value={formValor}
                      onChange={(e) => setFormValor(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Categoria</label>
                    <select 
                      value={formCategoria} 
                      onChange={(e) => setFormCategoria(e.target.value)}
                    >
                      <option value="Projetos">Projetos</option>
                      <option value="Consultoria">Consultoria</option>
                      <option value="Suporte">Suporte</option>
                      <option value="Licenciamento">Licenciamento</option>
                      <option value="Serviços">Serviços</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label>Cliente</label>
                  <select 
                    value={formClienteId} 
                    onChange={(e) => setFormClienteId(e.target.value)}
                  >
                    <option value="">Sem cliente vinculado</option>
                    {clientes.map(c => (
                      <option key={c.id} value={c.id}>{c.empresa} ({c.nome_contato})</option>
                    ))}
                  </select>
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Data de Competência</label>
                    <input 
                      type="date" 
                      required 
                      value={formDataCompetencia}
                      onChange={(e) => setFormDataCompetencia(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Data de Vencimento</label>
                    <input 
                      type="date" 
                      required 
                      value={formDataVencimento}
                      onChange={(e) => setFormDataVencimento(e.target.value)}
                    />
                  </div>
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setNovaReceitaModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Cadastrar Receita</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal de Baixa de Recebimento */}
        {baixaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Baixar Conta a Receber</h3>
                <button className="modal-close-btn" onClick={() => setBaixaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleRegistrarBaixa}>
                <p className="baixa-info-msg">
                  Confirmando o recebimento da receita: <strong>{baixaDescricao}</strong>.
                </p>

                <div className="form-group">
                  <label>Data do Recebimento</label>
                  <input 
                    type="date" 
                    required 
                    value={baixaData}
                    onChange={(e) => setBaixaData(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label>Valor Recebido (R$)</label>
                  <input 
                    type="number" 
                    step="0.01" 
                    min="0.01" 
                    required 
                    value={baixaValor}
                    onChange={(e) => setBaixaValor(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setBaixaModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Confirmar Recebimento</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
