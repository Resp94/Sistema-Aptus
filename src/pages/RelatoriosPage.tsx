import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { relatoriosService } from '../services/relatorios.service'
import { podeLer, podeEscrever } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, ErrorState, IntegrationPendingState } from '../components/ui/States'
import type { ExportacaoRelatorioItem } from '../types/relatorios'
import './RelatoriosPage.css'

export default function RelatoriosPage() {
  const { perfil, permissoes } = useAuth()
  const navigate = useNavigate()
  const temEscrita = podeEscrever(permissoes, 'relatorios')

  // Estados de dados
  const [categorias, setCategorias] = useState<string[]>([])
  const [categoriaAtiva, setCategoriaAtiva] = useState<string>('')
  const [previaData, setPreviaData] = useState<any>(null)
  const [historico, setHistorico] = useState<ExportacaoRelatorioItem[]>([])

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [loadingPrevia, setLoadingPrevia] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)
  const [integrationBanner, setIntegrationBanner] = useState<{ message: string; status: string } | null>(null)

  // Modais
  const [exportarModalOpen, setExportarModalOpen] = useState(false)
  const [agendarModalOpen, setAgendarModalOpen] = useState(false)

  // Form Exportar
  const [exportFormato, setExportFormato] = useState<'PDF' | 'CSV'>('PDF')

  // Form Agendar
  const [agendarFrequencia, setAgendarFrequencia] = useState<'Uma vez' | 'Diário' | 'Semanal' | 'Mensal'>('Semanal')
  const [agendarDataHora, setAgendarDataHora] = useState('')

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg)
    setTimeout(() => {
      setToastMsg(null)
    }, 3000)
  }, [])

  const triggerIntegrationStatus = (status: string, message: string) => {
    setIntegrationBanner({ status, message })
    setTimeout(() => {
      setIntegrationBanner(null)
    }, 6000)
  }

  // Carregar categorias e histórico
  const fetchCategoriasEHistorico = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [catList, histList] = await Promise.all([
        relatoriosService.listarCategoriasRelatorios(),
        relatoriosService.listarExportacoesRelatorios()
      ])

      setCategorias(catList)
      setHistorico(histList)

      if (catList.length > 0) {
        setCategoriaAtiva(catList[0])
      }
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar módulo de relatórios.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'relatorios')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchCategoriasEHistorico()
  }, [perfil, permissoes, fetchCategoriasEHistorico, navigate])

  // Carrega a prévia sempre que a categoria muda
  useEffect(() => {
    if (!categoriaAtiva) return

    const loadPrevia = async () => {
      setLoadingPrevia(true)
      try {
        const data = await relatoriosService.gerarPreviaRelatorio(categoriaAtiva)
        setPreviaData(data)
      } catch (err: any) {
        console.error(err)
        showToast(err.message || 'Erro ao gerar pré-visualização.')
        setPreviaData(null)
      } finally {
        setLoadingPrevia(false)
      }
    }

    loadPrevia()
  }, [categoriaAtiva, showToast])

  const handleSolicitarExportacao = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!categoriaAtiva) return

    try {
      await relatoriosService.solicitarExportacaoRelatorio(categoriaAtiva, exportFormato)
      showToast('Exportação solicitada com sucesso!')
      setExportarModalOpen(false)
      
      // Recarrega o histórico
      const histList = await relatoriosService.listarExportacoesRelatorios()
      setHistorico(histList)

      // Alerta amigavelmente que o arquivo_url ficará indisponível
      triggerIntegrationStatus(
        'Indisponível',
        'O relatório foi registrado com sucesso, mas a geração de PDF/CSV depende de microsserviço de impressão externo não integrado.'
      )
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao solicitar exportação.')
    }
  }

  const handleAgendarRelatorio = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!categoriaAtiva) return

    try {
      await relatoriosService.agendarRelatorio({
        tipo: categoriaAtiva,
        formato: 'PDF',
        filtros: {},
        frequencia: agendarFrequencia,
        agendado_para: agendarDataHora || null
      })

      showToast('Relatório agendado com sucesso!')
      setAgendarModalOpen(false)
      setAgendarDataHora('')
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao agendar relatório.')
    }
  }

  const formatarMoeda = (val: number) => {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
  }

  const formatarData = (dtStr: string) => {
    if (!dtStr) return '-'
    const tIndex = dtStr.indexOf('T')
    const datePart = tIndex !== -1 ? dtStr.substring(0, tIndex) : dtStr
    const parts = datePart.split('-')
    if (parts.length === 3) {
      return `${parts[2]}/${parts[1]}/${parts[0]}`
    }
    return new Date(dtStr).toLocaleDateString('pt-BR')
  }

  return (
    <AppShell titulo="Relatórios & Exportação">
      <div className="relatorios-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        {integrationBanner && (
          <IntegrationPendingState 
            status={integrationBanner.status} 
            message={integrationBanner.message} 
          />
        )}

        <header className="page-header">
          <div>
            <h1 className="page-title">Relatórios Operacionais</h1>
            <p className="page-subtitle">Visualize indicadores de desempenho, agende relatórios periódicos e exporte dados da empresa.</p>
          </div>
          {temEscrita && categoriaAtiva && (
            <div className="header-buttons">
              <button className="btn btn-outline" onClick={() => setAgendarModalOpen(true)}>
                Agendar Envio
              </button>
              <button className="btn btn-primary btn-icon" onClick={() => setExportarModalOpen(true)}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="7 10 12 15 17 10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                Exportar Relatório
              </button>
            </div>
          )}
        </header>

        {loading ? (
          <LoadingState message="Carregando categorias e histórico de relatórios..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchCategoriasEHistorico} />
        ) : (
          <div className="relatorios-workspace">
            {/* Seletor de Relatório Sidebar */}
            <aside className="relatorios-sidebar card-box">
              <h2 className="sidebar-title">Selecione o Relatório</h2>
              <ul className="categories-list">
                {categorias.map(cat => (
                  <li key={cat}>
                    <button 
                      className={`category-btn ${categoriaAtiva === cat ? 'active' : ''}`}
                      onClick={() => setCategoriaAtiva(cat)}
                    >
                      {cat}
                    </button>
                  </li>
                ))}
              </ul>
            </aside>

            {/* Preview do Relatório Selecionado */}
            <main className="relatorios-preview-main">
              <section className="card-box previa-box">
                <div className="previa-header">
                  <h2 className="previa-title">Pré-visualização do Relatório: {categoriaAtiva}</h2>
                  <span className="previa-badge">Dados em Tempo Real</span>
                </div>

                {loadingPrevia ? (
                  <div className="previa-loading">
                    <div className="spinner"></div>
                    <p>Processando e consolidando dados...</p>
                  </div>
                ) : previaData ? (
                  <div className="previa-content">
                    {categoriaAtiva === 'Financeiro' && (
                      <div className="previa-grid">
                        <div className="previa-card">
                          <span className="previa-card-label">Total Entradas</span>
                          <span className="previa-card-val color-success">{formatarMoeda(previaData.receitas_totais)}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Total Saídas</span>
                          <span className="previa-card-val color-danger">{formatarMoeda(previaData.despesas_totais)}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Saldo Acumulado</span>
                          <span className={`previa-card-val ${previaData.saldo_acumulado >= 0 ? 'color-success' : 'color-danger'}`}>
                            {formatarMoeda(previaData.saldo_acumulado)}
                          </span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Lançamentos</span>
                          <span className="previa-card-val color-neutral">{previaData.lancamentos_count}</span>
                        </div>
                      </div>
                    )}

                    {categoriaAtiva === 'DRE' && (
                      <div className="previa-table-container">
                        <table className="previa-table">
                          <tbody>
                            <tr>
                              <td><strong>(+) Faturamento Bruto (Receitas)</strong></td>
                              <td className="text-right color-success font-semibold">{formatarMoeda(previaData.faturamento_bruto)}</td>
                            </tr>
                            <tr>
                              <td>(-) Deduções (Impostos / Devoluções)</td>
                              <td className="text-right color-danger font-semibold">{formatarMoeda(previaData.deducoes)}</td>
                            </tr>
                            <tr>
                              <td><strong>(-) Custos Operacionais (Despesas)</strong></td>
                              <td className="text-right color-danger font-semibold">{formatarMoeda(previaData.custos_operacionais)}</td>
                            </tr>
                            <tr className="border-top-double">
                              <td><strong>(=) Resultado Líquido do Período</strong></td>
                              <td className={`text-right font-bold ${previaData.resultado_liquido >= 0 ? 'color-success' : 'color-danger'}`}>
                                {formatarMoeda(previaData.resultado_liquido)}
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                    )}

                    {categoriaAtiva === 'Clientes' && (
                      <div className="previa-grid">
                        <div className="previa-card">
                          <span className="previa-card-label">Clientes Totais</span>
                          <span className="previa-card-val color-neutral">{previaData.total_clients || previaData.total_clientes}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Clientes Ativos</span>
                          <span className="previa-card-val color-success">{previaData.ativos}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Clientes Inativos</span>
                          <span className="previa-card-val color-danger">{previaData.inativos}</span>
                        </div>
                      </div>
                    )}

                    {categoriaAtiva === 'Projetos' && (
                      <div className="previa-grid">
                        <div className="previa-card">
                          <span className="previa-card-label">Total de Projetos</span>
                          <span className="previa-card-val color-neutral">{previaData.total_projects || previaData.total_projetos}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Em Execução</span>
                          <span className="previa-card-val color-primary">{previaData.em_andamento}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Em Planejamento</span>
                          <span className="previa-card-val color-neutral">{previaData.planejamento}</span>
                        </div>
                        <div className="previa-card">
                          <span className="previa-card-label">Concluídos</span>
                          <span className="previa-card-val color-success">{previaData.concluidos}</span>
                        </div>
                      </div>
                    )}
                  </div>
                ) : (
                  <p className="no-records-msg">Dados de pré-visualização indisponíveis para esta categoria.</p>
                )}
              </section>

              {/* Histórico de Exportações */}
              <section className="card-box historico-box">
                <h2 className="section-title">Histórico de Solicitações de Relatórios</h2>
                {historico.length === 0 ? (
                  <p className="no-records-msg">Nenhum relatório exportado anteriormente.</p>
                ) : (
                  <div className="responsive-table-container">
                    <table className="data-table">
                      <thead>
                        <tr>
                          <th>Relatório</th>
                          <th>Formato</th>
                          <th>Data Solicitação</th>
                          <th>Status</th>
                          <th>Arquivo / Link</th>
                        </tr>
                      </thead>
                      <tbody>
                        {historico.map(hist => (
                          <tr key={hist.id}>
                            <td><strong>{hist.tipo}</strong></td>
                            <td>{hist.formato}</td>
                            <td>{formatarData(hist.gerado_em)}</td>
                            <td>
                              <span className={`status-badge status-${hist.status.toLowerCase()}`}>
                                {hist.status === 'Indisponível' ? 'Não Configurado' : hist.status}
                              </span>
                            </td>
                            <td>
                              {hist.arquivo_url ? (
                                <a href={hist.arquivo_url} target="_blank" rel="noopener noreferrer" className="btn btn-xs">
                                  Download
                                </a>
                              ) : (
                                <span className="text-muted text-xs">Pendente de Integração</span>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </section>
            </main>
          </div>
        )}

        {/* Modal Exportar Relatório */}
        {exportarModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Exportar Dados</h3>
                <button className="modal-close-btn" onClick={() => setExportarModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleSolicitarExportacao}>
                <p className="baixa-info-msg">
                  Solicitando arquivo consolidado para: <strong>{categoriaAtiva}</strong>.
                </p>

                <div className="form-group">
                  <label>Formato de Exportação</label>
                  <select 
                    value={exportFormato} 
                    onChange={(e) => setExportFormato(e.target.value as any)}
                  >
                    <option value="PDF">Documento PDF (.pdf)</option>
                    <option value="CSV">Planilha CSV (.csv)</option>
                  </select>
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setExportarModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Solicitar Arquivo</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Agendar Relatório */}
        {agendarModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Agendar Relatório Periódico</h3>
                <button className="modal-close-btn" onClick={() => setAgendarModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleAgendarRelatorio}>
                <p className="baixa-info-msg">
                  Configurando disparo de e-mail periódico para: <strong>{categoriaAtiva}</strong>.
                </p>

                <div className="form-group">
                  <label>Frequência de Envio</label>
                  <select 
                    value={agendarFrequencia} 
                    onChange={(e) => setAgendarFrequencia(e.target.value as any)}
                  >
                    <option value="Diário">Diário (Todo final de tarde)</option>
                    <option value="Semanal">Semanal (Toda segunda-feira de manhã)</option>
                    <option value="Mensal">Mensal (Todo dia 1º de manhã)</option>
                    <option value="Uma vez">Apenas uma vez (Agendado)</option>
                  </select>
                </div>

                <div className="form-group">
                  <label>Primeiro Disparo (Data/Hora)</label>
                  <input 
                    type="datetime-local" 
                    required 
                    value={agendarDataHora}
                    onChange={(e) => setAgendarDataHora(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setAgendarModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Agendar Relatório</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
