import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { financeiroService } from '../services/financeiro.service'
import { clientesService } from '../services/clientes.service'
import { podeLer } from '../lib/permissoes'
import { pode } from '../lib/capacidades'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState } from '../components/ui/States'
import type { FluxoCaixaItem, ResumoFluxoCaixa, FluxoCaixaSerie } from '../types/financeiro'
import type { Cliente } from '../types/clientes'
import './FluxoCaixaPage.css'

export default function FluxoCaixaPage() {
  const { perfil, permissoes, capacidades } = useAuth()
  const navigate = useNavigate()
  const podeLancarLancamento = pode(capacidades, 'financeiro.lancar')
  const podeBaixarLancamento = pode(capacidades, 'financeiro.baixar_lancamento')

  // Filtros de data padrão: do início do mês atual até o fim do mês atual
  const obterDatasPadrao = () => {
    const hoje = new Date()
    const ano = hoje.getFullYear()
    const mes = hoje.getMonth()
    
    const primeiroDia = new Date(ano, mes, 1)
    const ultimoDia = new Date(ano, mes + 1, 0)

    const formatar = (d: Date) => d.toISOString().split('T')[0]
    return {
      inicio: formatar(primeiroDia),
      fim: formatar(ultimoDia)
    }
  }

  const { inicio: dtInicio, fim: dtFim } = obterDatasPadrao()

  // Estados de dados
  const [lancamentos, setLancamentos] = useState<FluxoCaixaItem[]>([])
  const [resumo, setResumo] = useState<ResumoFluxoCaixa | null>(null)
  const [series, setSeries] = useState<FluxoCaixaSerie[]>([])
  const [clientes, setClientes] = useState<Cliente[]>([])

  // Filtros ativos
  const [dataInicio, setDataInicio] = useState(dtInicio)
  const [dataFim, setDataFim] = useState(dtFim)
  const [categoriaFiltro, setCategoriaFiltro] = useState('')
  const [buscaText, setBuscaText] = useState('')

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)

  // Modais
  const [lancamentoModalOpen, setLancamentoModalOpen] = useState(false)
  const [baixaModalOpen, setBaixaModalOpen] = useState(false)

  // Form de Lançamento
  const [formTipo, setFormTipo] = useState<'receita' | 'despesa'>('receita')
  const [formNatureza, setFormNatureza] = useState<'realizado' | 'a_receber' | 'a_pagar'>('realizado')
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

  // Carregar dados principais
  const fetchDados = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [resumoData, lancamentosData, seriesData] = await Promise.all([
        financeiroService.obterResumoFluxoCaixa(dataInicio, dataFim),
        financeiroService.listarFluxoCaixa(dataInicio, dataFim, categoriaFiltro || undefined, buscaText.trim() || undefined),
        financeiroService.obterFluxoCaixaSeries(dataInicio, dataFim)
      ])

      setResumo(resumoData)
      setLancamentos(lancamentosData)
      setSeries(seriesData)

      // Módulo "clientes" pode ser negado por RBAC (ex.: perfil Financeiro); degrada
      // para lista vazia em vez de quebrar a página inteira.
      try {
        setClientes(await clientesService.listarClientes())
      } catch {
        setClientes([])
      }
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar dados do Fluxo de Caixa.')
    } finally {
      setLoading(false)
    }
  }, [dataInicio, dataFim, categoriaFiltro, buscaText])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'fluxo-caixa')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleCriarLancamento = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formDescricao.trim() || !formValor) {
      showToast('Descrição e Valor são obrigatórios.')
      return
    }

    const valorNum = parseFloat(formValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor inserido deve ser maior que zero.')
      return
    }

    try {
      await financeiroService.criarLancamento({
        tipo: formTipo,
        natureza: formNatureza,
        descricao: formDescricao.trim(),
        valor: valorNum,
        categoria: formCategoria,
        cliente_id: formClienteId || null,
        data_competencia: formDataCompetencia,
        data_vencimento: formNatureza !== 'realizado' ? (formDataVencimento || null) : null
      })

      showToast('Lançamento financeiro registrado com sucesso!')
      setLancamentoModalOpen(false)
      
      // Reset form
      setFormDescricao('')
      setFormValor('')
      setFormClienteId('')
      setFormDataVencimento('')
      
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar lançamento.')
    }
  }

  const handleOpenBaixa = (item: FluxoCaixaItem) => {
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
      showToast('Pagamento/Recebimento baixado com sucesso!')
      setBaixaModalOpen(false)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar a baixa do lançamento.')
    }
  }

  const formatarMoeda = (val: number) => {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
  }

  const formatarData = (dtStr: string | null) => {
    if (!dtStr) return '-'
    const datePart = dtStr.includes('T') ? dtStr.split('T')[0] : dtStr
    const parts = datePart.split('-')
    if (parts.length === 3) {
      return `${parts[2]}/${parts[1]}/${parts[0]}`
    }
    return new Date(dtStr).toLocaleDateString('pt-BR')
  }

  // Achar o maior valor nas séries para escala do gráfico CSS
  const maxSerieVal = series.reduce((acc, curr) => {
    return Math.max(acc, curr.receitas, curr.despesas)
  }, 100)

  return (
    <AppShell titulo="Fluxo de Caixa">
      <div className="fluxo-caixa-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}
        
        <header className="page-header">
          <div>
            <h1 className="page-title">Fluxo de Caixa</h1>
            <p className="page-subtitle">Acompanhe as entradas, saídas e projeção de saldo da empresa.</p>
          </div>
          {podeLancarLancamento && (
            <button className="btn btn-primary btn-icon" onClick={() => setLancamentoModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Novo Lançamento
            </button>
          )}
        </header>

        {/* Resumo Financeiro */}
        {resumo && (
          <section className="dashboard-cards">
            <div className="card-item">
              <div className="card-label">Saldo Inicial Competência</div>
              <div className="card-value color-neutral">{formatarMoeda(resumo.saldo_inicial)}</div>
            </div>
            <div className="card-item">
              <div className="card-label">Total de Entradas</div>
              <div className="card-value color-success">+{formatarMoeda(resumo.entradas)}</div>
            </div>
            <div className="card-item">
              <div className="card-label">Total de Saídas</div>
              <div className="card-value color-danger">-{formatarMoeda(resumo.saidas)}</div>
            </div>
            <div className="card-item card-highlight">
              <div className="card-label">Saldo Final Projetado</div>
              <div className="card-value color-primary">
                {formatarMoeda(resumo.saldo_final_projetado)}
              </div>
            </div>
          </section>
        )}

        {/* Gráfico de Barras CSS */}
        {series.length > 0 && (
          <section className="chart-section card-box">
            <h2 className="section-title">Evolução de Fluxo de Caixa (Mensal / Diária)</h2>
            <div className="css-bar-chart">
              {series.map((s, idx) => {
                const recHeight = (s.receitas / maxSerieVal) * 100
                const despHeight = (s.despesas / maxSerieVal) * 100
                return (
                  <div className="chart-bar-group" key={idx}>
                    <div className="bar-pair">
                      <div 
                        className="bar bar-receita" 
                        style={{ height: `${Math.max(recHeight, 4)}%` }} 
                        title={`Receitas: ${formatarMoeda(s.receitas)}`}
                      >
                        <span className="bar-tooltip">R: {formatarMoeda(s.receitas)}</span>
                      </div>
                      <div 
                        className="bar bar-despesa" 
                        style={{ height: `${Math.max(despHeight, 4)}%` }} 
                        title={`Despesas: ${formatarMoeda(s.despesas)}`}
                      >
                        <span className="bar-tooltip">D: {formatarMoeda(s.despesas)}</span>
                      </div>
                    </div>
                    <div className="bar-label">{s.periodo}</div>
                  </div>
                )
              })}
            </div>
            <div className="chart-legend">
              <div className="legend-item"><span className="legend-dot color-rec"></span> Receitas</div>
              <div className="legend-item"><span className="legend-dot color-des"></span> Despesas</div>
            </div>
          </section>
        )}

        {/* Barra de Filtros */}
        <section className="filters-bar card-box">
          <div className="filters-grid">
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
            <div className="filter-field">
              <label htmlFor="filter-categoria">Categoria</label>
              <select 
                id="filter-categoria"
                value={categoriaFiltro} 
                onChange={(e) => setCategoriaFiltro(e.target.value)}
              >
                <option value="">Todas</option>
                <option value="Projetos">Projetos</option>
                <option value="Consultoria">Consultoria</option>
                <option value="Suporte">Suporte</option>
                <option value="Infraestrutura">Infraestrutura</option>
                <option value="Licenciamento">Licenciamento</option>
                <option value="Marketing">Marketing</option>
                <option value="Serviços">Serviços</option>
              </select>
            </div>
            <div className="filter-field search-field">
              <label htmlFor="filter-busca">Buscar</label>
              <input 
                id="filter-busca"
                type="text" 
                placeholder="Descrição ou Cliente..."
                value={buscaText} 
                onChange={(e) => setBuscaText(e.target.value)} 
              />
            </div>
          </div>
        </section>

        {/* Tabela de Lançamentos */}
        {loading ? (
          <LoadingState message="Carregando lançamentos do fluxo de caixa..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : lancamentos.length === 0 ? (
          <EmptyState 
            title="Nenhum lançamento financeiro" 
            description="Não encontramos nenhum registro correspondente ao período ou filtros aplicados."
            action={podeLancarLancamento ? { label: 'Novo Lançamento', onClick: () => setLancamentoModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Descrição</th>
                  <th>Tipo/Nat.</th>
                  <th>Competência</th>
                  <th>Vencimento</th>
                  <th>Categoria</th>
                  <th>Cliente/Fornecedor</th>
                  <th className="text-right">Valor</th>
                  <th>Status</th>
                  {podeBaixarLancamento && <th className="text-center">Ações</th>}
                </tr>
              </thead>
              <tbody>
                {lancamentos.map((item) => {
                  const isRec = item.tipo === 'receita'
                  return (
                    <tr key={item.id} className="table-row-hover">
                      <td>
                        <div className="font-semibold text-fg">{item.descricao}</div>
                      </td>
                      <td>
                        <span className={`badge-type ${isRec ? 'badge-receita' : 'badge-despesa'}`}>
                          {isRec ? 'Receita' : 'Despesa'} ({item.natureza})
                        </span>
                      </td>
                      <td>{formatarData(item.data_competencia)}</td>
                      <td>{formatarData(item.data_vencimento)}</td>
                      <td>{item.categoria}</td>
                      <td>{item.cliente || '-'}</td>
                      <td className={`text-right font-semibold ${isRec ? 'color-success' : 'color-danger'}`}>
                        {isRec ? '+' : '-'}{formatarMoeda(item.valor)}
                      </td>
                      <td>
                        <span className={`status-badge status-${item.status_exibicao.toLowerCase().replace(' ', '-')}`}>
                          {item.status_exibicao}
                        </span>
                      </td>
                      {podeBaixarLancamento && (
                        <td className="text-center">
                          {item.status_exibicao === 'Pendente' && (
                            <button className="btn btn-xs btn-outline" onClick={() => handleOpenBaixa(item)}>
                              Baixar
                            </button>
                          )}
                        </td>
                      )}
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* Modal Novo Lançamento */}
        {lancamentoModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Novo Lançamento Financeiro</h3>
                <button className="modal-close-btn" onClick={() => setLancamentoModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarLancamento}>
                <div className="form-group row-2">
                  <div>
                    <label>Tipo de Lançamento</label>
                    <select 
                      value={formTipo} 
                      onChange={(e) => {
                        const val = e.target.value as 'receita' | 'despesa'
                        setFormTipo(val)
                        setFormNatureza(val === 'receita' ? 'a_receber' : 'a_pagar')
                      }}
                    >
                      <option value="receita">Receita</option>
                      <option value="despesa">Despesa</option>
                    </select>
                  </div>
                  <div>
                    <label>Natureza</label>
                    <select 
                      value={formNatureza} 
                      onChange={(e) => setFormNatureza(e.target.value as any)}
                    >
                      <option value="realizado">Realizado (Pago/Recebido)</option>
                      {formTipo === 'receita' ? (
                        <option value="a_receber">A Receber (Projetado)</option>
                      ) : (
                        <option value="a_pagar">A Pagar (Projetado)</option>
                      )}
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label>Descrição</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Parcela 01/12 - Projeto Infra" 
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
                      <option value="Infraestrutura">Infraestrutura</option>
                      <option value="Licenciamento">Licenciamento</option>
                      <option value="Marketing">Marketing</option>
                      <option value="Serviços">Serviços</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label>Cliente / Fornecedor</label>
                  <select 
                    value={formClienteId} 
                    onChange={(e) => setFormClienteId(e.target.value)}
                  >
                    <option value="">Sem vínculo</option>
                    {clientes
                      .filter(c => formTipo === 'receita' ? c.tipo === 'cliente' : c.tipo === 'fornecedor')
                      .map(c => (
                        <option key={c.id} value={c.id}>{c.empresa} ({c.nome_contato})</option>
                      ))
                    }
                  </select>
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Data Competência</label>
                    <input 
                      type="date" 
                      required 
                      value={formDataCompetencia}
                      onChange={(e) => setFormDataCompetencia(e.target.value)}
                    />
                  </div>
                  {formNatureza !== 'realizado' && (
                    <div>
                      <label>Data Vencimento</label>
                      <input 
                        type="date" 
                        required 
                        value={formDataVencimento}
                        onChange={(e) => setFormDataVencimento(e.target.value)}
                      />
                    </div>
                  )}
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setLancamentoModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Registrar</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Baixar Lançamento */}
        {baixaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Registrar Baixa de Pagamento</h3>
                <button className="modal-close-btn" onClick={() => setBaixaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleRegistrarBaixa}>
                <p className="baixa-info-msg">
                  Confirmando o pagamento do lançamento: <strong>{baixaDescricao}</strong>.
                </p>

                <div className="form-group">
                  <label>Data de Pagamento</label>
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
                  <button type="submit" className="btn btn-primary">Confirmar Baixa</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
