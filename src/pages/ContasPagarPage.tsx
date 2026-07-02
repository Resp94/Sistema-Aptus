import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { financeiroService } from '../services/financeiro.service'
import { clientesService } from '../services/clientes.service'
import { podeLer, podeEscrever } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState } from '../components/ui/States'
import type { ContaPagarItem, MetricasContas } from '../types/financeiro'
import type { Cliente } from '../types/clientes'
import './ContasPagarPage.css'

export default function ContasPagarPage() {
  const { perfil, permissoes } = useAuth()
  const navigate = useNavigate()
  const temEscrita = podeEscrever(permissoes, 'contas-pagar')

  // Datas padrão para os próximos 30 dias de contas a pagar
  const obterDatasPadrao = () => {
    const hoje = new Date()
    const inicio = new Date(hoje.getFullYear(), hoje.getMonth(), 1)
    const fim = new Date(hoje.getFullYear(), hoje.getMonth() + 1, 15) // até dia 15 do próximo mês

    const formatar = (d: Date) => d.toISOString().split('T')[0]
    return {
      inicio: formatar(inicio),
      fim: formatar(fim)
    }
  }

  const { inicio: dtInicio, fim: dtFim } = obterDatasPadrao()

  // Estados de dados
  const [contas, setContas] = useState<ContaPagarItem[]>([])
  const [metricas, setMetricas] = useState<MetricasContas | null>(null)
  const [fornecedores, setFornecedores] = useState<Cliente[]>([])

  // Filtros
  const [statusFiltro, setStatusFiltro] = useState<string>('Pendente')
  const [fornecedorFiltro, setFornecedorFiltro] = useState('')
  const [dataInicio, setDataInicio] = useState(dtInicio)
  const [dataFim, setDataFim] = useState(dtFim)

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)

  // Modais
  const [novoGastoModalOpen, setNovoGastoModalOpen] = useState(false)
  const [baixaModalOpen, setBaixaModalOpen] = useState(false)

  // Form de Gasto
  const [formDescricao, setFormDescricao] = useState('')
  const [formValor, setFormValor] = useState('')
  const [formCategoria, setFormCategoria] = useState('Infraestrutura')
  const [formFornecedorId, setFormFornecedorId] = useState('')
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
      const [list, stats, fornList] = await Promise.all([
        financeiroService.listarContasPagar(
          statusFiltro === 'Todos' ? undefined : statusFiltro,
          fornecedorFiltro || undefined,
          dataInicio || undefined,
          dataFim || undefined
        ),
        financeiroService.obterMetricasContas('a_pagar', dataInicio || undefined, dataFim || undefined),
        clientesService.listarClientes('fornecedor')
      ])

      setContas(list)
      setMetricas(stats)
      setFornecedores(fornList)
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar contas a pagar.')
    } finally {
      setLoading(false)
    }
  }, [statusFiltro, fornecedorFiltro, dataInicio, dataFim])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'contas-pagar')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleCriarContaPagar = async (e: React.FormEvent) => {
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
        tipo: 'despesa',
        natureza: 'a_pagar',
        descricao: formDescricao.trim(),
        valor: valorNum,
        categoria: formCategoria,
        cliente_id: formFornecedorId || null,
        data_competencia: formDataCompetencia,
        data_vencimento: formDataVencimento
      })

      showToast('Conta a pagar cadastrada com sucesso!')
      setNovoGastoModalOpen(false)
      
      // Reset
      setFormDescricao('')
      setFormValor('')
      setFormFornecedorId('')
      setFormDataVencimento('')

      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao cadastrar despesa.')
    }
  }

  const handleOpenBaixa = (item: ContaPagarItem) => {
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
      showToast('O valor da baixa deve ser maior que zero.')
      return
    }

    try {
      await financeiroService.registrarPagamentoLancamento(baixaId, baixaData, valorNum)
      showToast('Baixa de despesa registrada com sucesso!')
      setBaixaModalOpen(false)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar pagamento.')
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
    <AppShell titulo="Contas a Pagar">
      <div className="contas-pagar-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        <header className="page-header">
          <div>
            <h1 className="page-title">Contas a Pagar</h1>
            <p className="page-subtitle">Monitore os compromissos financeiros e saídas agendadas.</p>
          </div>
          {temEscrita && (
            <button className="btn btn-primary btn-icon" onClick={() => setNovoGastoModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Adicionar Conta
            </button>
          )}
        </header>

        {/* Métricas Superiores */}
        {metricas && (
          <section className="dashboard-cards metricas-contas">
            <div className="card-item">
              <div className="card-label">Total no Período</div>
              <div className="card-value color-neutral">{formatarMoeda(metricas.total_valor)}</div>
              <div className="card-sub">{metricas.total_qtd} contas lançadas</div>
            </div>
            <div className="card-item border-danger">
              <div className="card-label">Contas Vencidas</div>
              <div className="card-value color-danger">{formatarMoeda(metricas.vencidas_valor)}</div>
              <div className="card-sub">{metricas.vencidas_qtd} vencidas</div>
            </div>
            <div className="card-item border-warn">
              <div className="card-label">Vencem Hoje</div>
              <div className="card-value color-warn">{formatarMoeda(metricas.vencem_hoje_valor)}</div>
              <div className="card-sub">{metricas.vencem_hoje_qtd} pendentes</div>
            </div>
            <div className="card-item border-primary">
              <div className="card-label">Próximos 7 Dias</div>
              <div className="card-value color-primary">{formatarMoeda(metricas.proximos_7_dias_valor)}</div>
              <div className="card-sub">{metricas.proximos_7_dias_qtd} contas agendadas</div>
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
              <label htmlFor="filter-fornecedor">Fornecedor</label>
              <select 
                id="filter-fornecedor"
                value={fornecedorFiltro} 
                onChange={(e) => setFornecedorFiltro(e.target.value)}
              >
                <option value="">Todos</option>
                {fornecedores.map(f => (
                  <option key={f.id} value={f.empresa}>{f.empresa}</option>
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

        {/* Lista */}
        {loading ? (
          <LoadingState message="Carregando contas a pagar..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : contas.length === 0 ? (
          <EmptyState 
            title="Nenhuma despesa para pagar" 
            description="Não encontramos nenhuma conta agendada para os filtros selecionados."
            action={temEscrita ? { label: 'Adicionar Conta', onClick: () => setNovoGastoModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Descrição</th>
                  <th>Fornecedor</th>
                  <th>Vencimento</th>
                  <th>Categoria</th>
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
                    <td>{item.fornecedor || 'Fornecedor avulso'}</td>
                    <td>{formatarData(item.data_vencimento)}</td>
                    <td>{item.categoria}</td>
                    <td className="text-right font-semibold color-danger">
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
                            Pagar
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

        {/* Modal Novo Lançamento de Conta a Pagar */}
        {novoGastoModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Lançar Nova Conta a Pagar</h3>
                <button className="modal-close-btn" onClick={() => setNovoGastoModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarContaPagar}>
                <div className="form-group">
                  <label>Descrição da Conta</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Assinatura Anual AWS" 
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
                      <option value="Infraestrutura">Infraestrutura</option>
                      <option value="Licenciamento">Licenciamento</option>
                      <option value="Marketing">Marketing</option>
                      <option value="Serviços">Serviços</option>
                      <option value="Consultoria">Consultoria</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label>Fornecedor</label>
                  <select 
                    value={formFornecedorId} 
                    onChange={(e) => setFormFornecedorId(e.target.value)}
                  >
                    <option value="">Sem fornecedor vinculado</option>
                    {fornecedores.map(f => (
                      <option key={f.id} value={f.id}>{f.empresa} ({f.nome_contato})</option>
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
                  <button type="button" className="btn btn-secondary" onClick={() => setNovoGastoModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Cadastrar Conta</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal de Baixa de Pagamento */}
        {baixaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Baixar Conta a Pagar</h3>
                <button className="modal-close-btn" onClick={() => setBaixaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleRegistrarBaixa}>
                <p className="baixa-info-msg">
                  Confirmando o pagamento da conta: <strong>{baixaDescricao}</strong>.
                </p>

                <div className="form-group">
                  <label>Data do Pagamento</label>
                  <input 
                    type="date" 
                    required 
                    value={baixaData}
                    onChange={(e) => setBaixaData(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label>Valor Pago (R$)</label>
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
                  <button type="submit" className="btn btn-primary">Confirmar Pagamento</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
