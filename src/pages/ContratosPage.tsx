import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { comercialService } from '../services/comercial.service'
import { clientesService } from '../services/clientes.service'
import { podeLer, podeEscrever } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState } from '../components/ui/States'
import type { ContratoItem, ContratoDetalhe } from '../types/comercial'
import type { Cliente } from '../types/clientes'
import './ContratosPage.css'

export default function ContratosPage() {
  const { perfil, permissoes } = useAuth()
  const navigate = useNavigate()
  const temEscrita = podeEscrever(permissoes, 'contratos')

  // Estados
  const [contratos, setContratos] = useState<ContratoItem[]>([])
  const [clientes, setClientes] = useState<Cliente[]>([])
  const [detalhe, setDetalhe] = useState<ContratoDetalhe | null>(null)

  // Filtros
  const [statusFiltro, setStatusFiltro] = useState<string>('Todos')
  const [clienteFiltro, setClienteFiltro] = useState('')
  const [buscaText, setBuscaText] = useState('')

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)

  // Modais
  const [novoContratoModalOpen, setNovoContratoModalOpen] = useState(false)
  const [renovarModalOpen, setRenovarModalOpen] = useState(false)

  // Form Criar Contrato
  const [formClienteId, setFormClienteId] = useState('')
  const [formTitulo, setFormTitulo] = useState('')
  const [formDataInicio, setFormDataInicio] = useState(new Date().toISOString().split('T')[0])
  const [formDataFim, setFormDataFim] = useState('')
  const [formValorRecorrente, setFormValorRecorrente] = useState('')

  // Form Renovar Contrato
  const [renovarDataFim, setRenovarDataFim] = useState('')
  const [renovarValor, setRenovarValor] = useState('')

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
      const [list, cliList] = await Promise.all([
        comercialService.listarContratos(
          statusFiltro === 'Todos' ? undefined : statusFiltro,
          clienteFiltro || undefined,
          buscaText.trim() || undefined
        ),
        clientesService.listarClientes('cliente')
      ])

      setContratos(list)
      setClientes(cliList)
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar contratos.')
    } finally {
      setLoading(false)
    }
  }, [statusFiltro, clienteFiltro, buscaText])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'contratos')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleVerDetalhe = async (id: string) => {
    try {
      const data = await comercialService.obterContratoDetalhe(id)
      setDetalhe(data)
      setTimeout(() => {
        document.getElementById('contratoDetailSection')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }, 100)
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao obter detalhes do contrato.')
    }
  }

  const handleCriarContrato = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formClienteId || !formTitulo.trim() || !formDataInicio || !formDataFim || !formValorRecorrente) {
      showToast('Todos os campos obrigatórios do contrato devem ser preenchidos.')
      return
    }

    const valorNum = parseFloat(formValorRecorrente)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor recorrente deve ser maior que zero.')
      return
    }

    try {
      await comercialService.criarContrato({
        cliente_id: formClienteId,
        titulo: formTitulo.trim(),
        data_inicio: formDataInicio,
        data_fim: formDataFim,
        valor_recorrente: valorNum,
        status: 'Vigente'
      })

      showToast('Contrato direto cadastrado com sucesso!')
      setNovoContratoModalOpen(false)

      // Reset
      setFormClienteId('')
      setFormTitulo('')
      setFormDataFim('')
      setFormValorRecorrente('')

      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao cadastrar contrato.')
    }
  }

  const handleOpenRenovar = () => {
    if (!detalhe) return
    setRenovarValor(detalhe.valor_recorrente.toString())
    
    // Sugere extensão de mais 1 ano
    const fimAtual = new Date(detalhe.data_fim)
    const novaFim = new Date(fimAtual.getFullYear() + 1, fimAtual.getMonth(), fimAtual.getDate())
    setRenovarDataFim(novaFim.toISOString().split('T')[0])
    
    setRenovarModalOpen(true)
  }

  const handleRenovarContrato = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!detalhe || !renovarDataFim) return

    const valorNum = parseFloat(renovarValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor de renovação deve ser maior que zero.')
      return
    }

    try {
      await comercialService.renovarContrato(detalhe.id, renovarDataFim, valorNum)
      showToast('Contrato renovado com sucesso!')
      setRenovarModalOpen(false)

      handleVerDetalhe(detalhe.id)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao renovar contrato.')
    }
  }

  const handleEncerrarContrato = async () => {
    if (!detalhe) return
    if (!window.confirm(`Deseja realmente rescindir/encerrar o contrato "${detalhe.titulo}"?`)) {
      return
    }

    try {
      await comercialService.encerrarContrato(detalhe.id)
      showToast('Contrato encerrado e arquivado.')
      
      handleVerDetalhe(detalhe.id)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao encerrar contrato.')
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
    <AppShell titulo="Contratos de Clientes">
      <div className="contratos-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        <header className="page-header">
          <div>
            <h1 className="page-title">Contratos de Clientes</h1>
            <p className="page-subtitle">Acompanhe contratos de prestação de serviços, termos ativos e vencimentos.</p>
          </div>
          {temEscrita && (
            <button className="btn btn-primary btn-icon" onClick={() => setNovoContratoModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Novo Contrato
            </button>
          )}
        </header>

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
                <option value="Vigente">Vigentes</option>
                <option value="Vencimento próximo">Vencendo Logo</option>
                <option value="Encerrado">Encerrados</option>
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
            <div className="filter-field search-field">
              <label htmlFor="filter-busca">Buscar</label>
              <input 
                id="filter-busca"
                type="text" 
                placeholder="Título do contrato..."
                value={buscaText} 
                onChange={(e) => setBuscaText(e.target.value)} 
              />
            </div>
          </div>
        </section>

        {/* Tabela */}
        {loading ? (
          <LoadingState message="Carregando contratos..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : contratos.length === 0 ? (
          <EmptyState 
            title="Nenhum contrato ativo" 
            description="Não encontramos contratos registrados correspondentes aos filtros aplicados."
            action={temEscrita ? { label: 'Novo Contrato', onClick: () => setNovoContratoModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Título</th>
                  <th>Cliente</th>
                  <th>Data Início</th>
                  <th>Data Fim</th>
                  <th className="text-right">Valor Recorrente</th>
                  <th>Status</th>
                  <th className="text-center">Ações</th>
                </tr>
              </thead>
              <tbody>
                {contratos.map(item => (
                  <tr key={item.id} className="table-row-hover">
                    <td>
                      <div className="font-semibold text-fg">{item.titulo}</div>
                    </td>
                    <td>{item.cliente}</td>
                    <td>{formatarData(item.data_inicio)}</td>
                    <td>{formatarData(item.data_fim)}</td>
                    <td className="text-right font-semibold text-fg">
                      {formatarMoeda(item.valor_recorrente)}/mês
                    </td>
                    <td>
                      <span className={`status-badge status-${item.status_exibicao.toLowerCase().replace(' ', '-')}`}>
                        {item.status_exibicao}
                      </span>
                    </td>
                    <td className="text-center">
                      <button className="btn btn-xs btn-outline" onClick={() => handleVerDetalhe(item.id)}>
                        Visualizar
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Detalhes Expansíveis */}
        {detalhe && (
          <section id="contratoDetailSection" className="detail-section card-box">
            <div className="detail-header">
              <div>
                <span className="detail-tag">Detalhes do Contrato</span>
                <h2 className="detail-title">{detalhe.titulo}</h2>
              </div>
              <div className="detail-header-actions">
                {temEscrita && detalhe.status_exibicao !== 'Encerrado' && (
                  <>
                    <button className="btn btn-secondary" onClick={handleOpenRenovar}>
                      Renovar / Estender
                    </button>
                    <button className="btn btn-outline color-danger" onClick={handleEncerrarContrato}>
                      Encerrar Contrato
                    </button>
                  </>
                )}
              </div>
            </div>

            <div className="detail-grid">
              <div className="detail-col">
                <h3 className="detail-sub">Dados Gerais</h3>
                <div className="detail-info-row">
                  <span className="info-label">Cliente contratante:</span>
                  <span className="info-val">{detalhe.empresa} ({detalhe.nome_contato})</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Proposta Vinculada:</span>
                  <span className="info-val">{detalhe.proposta_titulo || 'Contrato Direto'}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Cadastrado Por:</span>
                  <span className="info-val">{detalhe.created_by_nome}</span>
                </div>
              </div>

              <div className="detail-col">
                <h3 className="detail-sub">Financeiro e Prazo</h3>
                <div className="detail-info-row">
                  <span className="info-label">Valor Recorrente:</span>
                  <span className="info-val font-semibold text-fg">{formatarMoeda(detalhe.valor_recorrente)} / mês</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Data de Início:</span>
                  <span className="info-val">{formatarData(detalhe.data_inicio)}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Data de Fim:</span>
                  <span className="info-val">{formatarData(detalhe.data_fim)}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Status do Contrato:</span>
                  <span className="info-val">
                    <span className={`status-badge status-${detalhe.status_exibicao.toLowerCase().replace(' ', '-')}`}>
                      {detalhe.status_exibicao}
                    </span>
                  </span>
                </div>
              </div>
            </div>

            {detalhe.documentos.length > 0 && (
              <div className="detail-documents">
                <h3 className="detail-sub">Documentos Firmados ({detalhe.documentos.length})</h3>
                <ul className="doc-list">
                  {detalhe.documentos.map(doc => (
                    <li key={doc.id} className="doc-item">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="doc-icon">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                        <polyline points="14 2 14 8 20 8" />
                      </svg>
                      <a href={doc.arquivo_url} target="_blank" rel="noopener noreferrer" className="doc-link">
                        {doc.nome}
                      </a>
                      <span className="doc-meta">Assinado/Enviado em {formatarData(doc.criado_em.split('T')[0])}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </section>
        )}

        {/* Modal Novo Contrato Direto */}
        {novoContratoModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Lançar Novo Contrato</h3>
                <button className="modal-close-btn" onClick={() => setNovoContratoModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarContrato}>
                <div className="form-group">
                  <label>Cliente Contratante</label>
                  <select 
                    required
                    value={formClienteId} 
                    onChange={(e) => setFormClienteId(e.target.value)}
                  >
                    <option value="">Selecione o cliente</option>
                    {clientes.map(c => (
                      <option key={c.id} value={c.id}>{c.empresa} ({c.nome_contato})</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label>Título do Contrato / Termo</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Contrato de Suporte Mensal" 
                    value={formTitulo}
                    onChange={(e) => setFormTitulo(e.target.value)}
                  />
                </div>

                <div className="form-group row-2">
                  <div>
                    <label>Valor Mensal Recorrente (R$)</label>
                    <input 
                      type="number" 
                      step="0.01" 
                      min="0.01" 
                      required 
                      placeholder="0.00" 
                      value={formValorRecorrente}
                      onChange={(e) => setFormValorRecorrente(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Data de Início</label>
                    <input 
                      type="date" 
                      required 
                      value={formDataInicio}
                      onChange={(e) => setFormDataInicio(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Data de Término</label>
                  <input 
                    type="date" 
                    required 
                    value={formDataFim}
                    onChange={(e) => setFormDataFim(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setNovoContratoModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Assinar Contrato</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Renovar Contrato */}
        {renovarModalOpen && detalhe && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Renovação de Contrato</h3>
                <button className="modal-close-btn" onClick={() => setRenovarModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleRenovarContrato}>
                <p className="baixa-info-msg">
                  Renovando contrato: <strong>{detalhe.titulo}</strong>.
                </p>

                <div className="form-group">
                  <label>Novo Término de Vigência</label>
                  <input 
                    type="date" 
                    required 
                    value={renovarDataFim}
                    onChange={(e) => setRenovarDataFim(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label>Novo Valor Recorrente Mensal (R$)</label>
                  <input 
                    type="number" 
                    step="0.01" 
                    min="0.01" 
                    required 
                    value={renovarValor}
                    onChange={(e) => setRenovarValor(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setRenovarModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Confirmar Renovação</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
