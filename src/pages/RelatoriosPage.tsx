import React, { useState, useEffect, useCallback, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { relatoriosService } from '../services/relatorios.service'
import { podeLer } from '../lib/permissoes'
import { pode } from '../lib/capacidades'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, ErrorState } from '../components/ui/States'
import { obterPeriodoPadrao, validarPeriodoExportacao } from '../lib/relatorios-periodo'
import { obterDadosDownload, dispararDownloadArquivo } from '../lib/download'
import type { ExportacaoRelatorioItem } from '../types/relatorios'
import './RelatoriosPage.css'

const CATEGORIA_SEM_EXPORTACAO = 'Personalizado'

export default function RelatoriosPage() {
  const { perfil, permissoes, capacidades } = useAuth()
  const navigate = useNavigate()
  const temEscrita = pode(capacidades, 'relatorios.exportar')

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

  // Modais
  const [exportarModalOpen, setExportarModalOpen] = useState(false)
  const [agendarModalOpen, setAgendarModalOpen] = useState(false)

  // Form Exportar
  const [exportFormato, setExportFormato] = useState<'PDF' | 'CSV'>('PDF')
  const [exportDataInicial, setExportDataInicial] = useState('')
  const [exportDataFinal, setExportDataFinal] = useState('')
  const [exportPeriodoErro, setExportPeriodoErro] = useState<string | null>(null)
  const [exportErro, setExportErro] = useState<string | null>(null)
  const [exportLoading, setExportLoading] = useState(false)
  const dataInicialInputRef = useRef<HTMLInputElement>(null)

  // Download de item do histórico
  const [baixandoHistoricoId, setBaixandoHistoricoId] = useState<string | null>(null)

  // Form Agendar
  const [agendarFrequencia, setAgendarFrequencia] = useState<'Uma vez' | 'Diário' | 'Semanal' | 'Mensal'>('Semanal')
  const [agendarDataHora, setAgendarDataHora] = useState('')

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg)
    setTimeout(() => {
      setToastMsg(null)
    }, 3000)
  }, [])

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

  const abrirModalExportar = () => {
    if (!categoriaAtiva || categoriaAtiva === CATEGORIA_SEM_EXPORTACAO) return

    const periodoPadrao = obterPeriodoPadrao()
    setExportFormato('PDF')
    setExportDataInicial(periodoPadrao.data_inicial)
    setExportDataFinal(periodoPadrao.data_final)
    setExportPeriodoErro(null)
    setExportErro(null)
    setExportarModalOpen(true)
  }

  const fecharModalExportar = useCallback(() => {
    setExportarModalOpen(false)
    setExportPeriodoErro(null)
    setExportErro(null)
  }, [])

  // Foca automaticamente o primeiro campo editável (Data Inicial) ao abrir o modal
  useEffect(() => {
    if (exportarModalOpen) {
      dataInicialInputRef.current?.focus()
    }
  }, [exportarModalOpen])

  const revalidarPeriodo = (dataInicial: string, dataFinal: string) => {
    const resultado = validarPeriodoExportacao(dataInicial, dataFinal)
    setExportPeriodoErro(resultado.valido ? null : resultado.mensagem || null)
    return resultado
  }

  const handleDataInicialChange = (valor: string) => {
    setExportDataInicial(valor)
    revalidarPeriodo(valor, exportDataFinal)
  }

  const handleDataFinalChange = (valor: string) => {
    setExportDataFinal(valor)
    revalidarPeriodo(exportDataInicial, valor)
  }

  const handleExportarModalKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (e.key === 'Escape') {
      e.stopPropagation()
      fecharModalExportar()
      return
    }

    if (e.key !== 'Tab') return

    const container = e.currentTarget
    const focusaveis = Array.from(
      container.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
    )

    if (focusaveis.length === 0) return

    const primeiro = focusaveis[0]
    const ultimo = focusaveis[focusaveis.length - 1]

    if (e.shiftKey) {
      if (document.activeElement === primeiro) {
        e.preventDefault()
        ultimo.focus()
      }
    } else if (document.activeElement === ultimo) {
      e.preventDefault()
      primeiro.focus()
    }
  }

  const handleExportar = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!categoriaAtiva || categoriaAtiva === CATEGORIA_SEM_EXPORTACAO) return

    const resultado = revalidarPeriodo(exportDataInicial, exportDataFinal)
    if (!resultado.valido) return

    setExportLoading(true)
    setExportErro(null)

    try {
      const resposta = await relatoriosService.exportarRelatorio({
        tipo: categoriaAtiva,
        formato: exportFormato,
        data_inicial: exportDataInicial,
        data_final: exportDataFinal
      })

      const dadosDownload = obterDadosDownload(resposta)
      dispararDownloadArquivo(dadosDownload.url, dadosDownload.nomeArquivo)

      showToast('Exportação gerada com sucesso!')
      setExportarModalOpen(false)

      // Recarrega o histórico para refletir a exportação recém-gerada
      const histList = await relatoriosService.listarExportacoesRelatorios()
      setHistorico(histList)
    } catch (err: any) {
      console.error(err)
      const mensagem = err.message || 'Erro ao exportar relatório.'
      setExportErro(mensagem)
      showToast(mensagem)

      // Mesmo em falha, o backend pode ter registrado a tentativa no histórico
      try {
        const histList = await relatoriosService.listarExportacoesRelatorios()
        setHistorico(histList)
      } catch (histErr) {
        console.error(histErr)
      }
    } finally {
      setExportLoading(false)
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

  // Aciona o download de um item já pronto do histórico (US2 - T057). Busca uma
  // signed URL de curta duração via `baixarExportacaoRelatorio` e dispara o
  // download local a partir dela — nunca reutiliza `arquivo_url` legado.
  const handleBaixarHistorico = async (item: ExportacaoRelatorioItem) => {
    if (!item.pode_baixar || baixandoHistoricoId) return

    setBaixandoHistoricoId(item.id)
    try {
      const resposta = await relatoriosService.baixarExportacaoRelatorio({ exportacao_id: item.id })
      const dadosDownload = obterDadosDownload(resposta)
      dispararDownloadArquivo(dadosDownload.url, dadosDownload.nomeArquivo)
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao baixar exportação.')
    } finally {
      setBaixandoHistoricoId(null)
    }
  }

  const formatarMoeda = (val: number) => {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
  }

  const formatarData = (dtStr: string | null) => {
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
              {categoriaAtiva !== CATEGORIA_SEM_EXPORTACAO && (
                <button className="btn btn-primary btn-icon" onClick={abrirModalExportar}>
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                    <polyline points="7 10 12 15 17 10" />
                    <line x1="12" y1="15" x2="12" y2="3" />
                  </svg>
                  Exportar Relatório
                </button>
              )}
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
                    <table className="data-table historico-table">
                      <thead>
                        <tr>
                          <th>Relatório</th>
                          <th>Formato</th>
                          <th>Período</th>
                          <th>Status</th>
                          <th className="col-solicitante">Solicitante</th>
                          <th className="col-gerado-em">Gerado em</th>
                          <th>Expira em</th>
                          <th>Ação</th>
                        </tr>
                      </thead>
                      <tbody>
                        {historico.map(hist => {
                          const statusTexto = hist.status_exibicao === 'Indisponível' ? 'Não Configurado' : hist.status_exibicao
                          const statusClasse = (hist.status_exibicao || '').toLowerCase()

                          return (
                            <tr key={hist.id}>
                              <td><strong>{hist.tipo}</strong></td>
                              <td>{hist.formato}</td>
                              <td className="periodo-cell">
                                {formatarData(hist.data_inicial)} - {formatarData(hist.data_final)}
                              </td>
                              <td>
                                <span className={`status-badge status-${statusClasse}`}>
                                  {statusTexto}
                                </span>
                                {hist.status_exibicao === 'Falhou' && hist.erro && (
                                  <p className="historico-erro-msg">{hist.erro}</p>
                                )}
                              </td>
                              <td className="col-solicitante">{hist.criado_por_nome || '-'}</td>
                              <td className="col-gerado-em">{formatarData(hist.gerado_em)}</td>
                              <td>{formatarData(hist.expira_em)}</td>
                              <td>
                                {hist.pode_baixar ? (
                                  <a
                                    href="#"
                                    className="btn btn-xs historico-download-link"
                                    aria-disabled={baixandoHistoricoId === hist.id}
                                    onClick={(e) => {
                                      e.preventDefault()
                                      handleBaixarHistorico(hist)
                                    }}
                                  >
                                    Baixar
                                  </a>
                                ) : (
                                  <span className="text-muted text-xs">Indisponível</span>
                                )}
                              </td>
                            </tr>
                          )
                        })}
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
          <div
            className="modal-backdrop"
            onMouseDown={(e) => {
              if (e.target === e.currentTarget) fecharModalExportar()
            }}
          >
            <div
              className="modal-content modal-sm"
              role="dialog"
              aria-modal="true"
              aria-labelledby="exportar-modal-title"
              onKeyDown={handleExportarModalKeyDown}
            >
              <div className="modal-header">
                <h3 className="modal-title" id="exportar-modal-title">Exportar Dados</h3>
                <button type="button" className="modal-close-btn" aria-label="Fechar" onClick={fecharModalExportar}>×</button>
              </div>
              <form onSubmit={handleExportar} noValidate>
                <p className="baixa-info-msg">
                  Gerando arquivo consolidado para: <strong>{categoriaAtiva}</strong>.
                </p>

                <div className="form-group form-group-row">
                  <div className="form-field">
                    <label htmlFor="exportar-data-inicial">Data Inicial</label>
                    <input
                      id="exportar-data-inicial"
                      type="date"
                      ref={dataInicialInputRef}
                      value={exportDataInicial}
                      onChange={(e) => handleDataInicialChange(e.target.value)}
                      required
                    />
                  </div>
                  <div className="form-field">
                    <label htmlFor="exportar-data-final">Data Final</label>
                    <input
                      id="exportar-data-final"
                      type="date"
                      value={exportDataFinal}
                      onChange={(e) => handleDataFinalChange(e.target.value)}
                      required
                    />
                  </div>
                </div>

                {exportPeriodoErro && (
                  <p className="field-error" role="alert">{exportPeriodoErro}</p>
                )}

                <div className="form-group">
                  <label htmlFor="exportar-formato">Formato de Exportação</label>
                  <select
                    id="exportar-formato"
                    value={exportFormato}
                    onChange={(e) => setExportFormato(e.target.value as any)}
                  >
                    <option value="PDF">Documento PDF (.pdf)</option>
                    <option value="CSV">Planilha CSV (.csv)</option>
                  </select>
                </div>

                {exportErro && (
                  <p className="field-error" role="alert">{exportErro}</p>
                )}

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={fecharModalExportar}>Cancelar</button>
                  <button type="submit" className="btn btn-primary" disabled={!!exportPeriodoErro || exportLoading}>
                    {exportLoading ? 'Gerando...' : 'Gerar e baixar'}
                  </button>
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
