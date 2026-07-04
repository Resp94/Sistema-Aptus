import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { comercialService } from '../services/comercial.service'
import { clientesService } from '../services/clientes.service'
import { podeLer } from '../lib/permissoes'
import { pode } from '../lib/capacidades'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState, IntegrationPendingState } from '../components/ui/States'
import type { PropostaItem, PropostaDetalhe } from '../types/comercial'
import type { Cliente } from '../types/clientes'
import './PropostasPage.css'

export default function PropostasPage() {
  const { perfil, permissoes, capacidades } = useAuth()
  const navigate = useNavigate()
  const podeCriarProposta = pode(capacidades, 'propostas.criar')
  const podeEnviarProposta = pode(capacidades, 'propostas.enviar')
  const podeGerarContrato = pode(capacidades, 'propostas.gerar_contrato')

  // Estados
  const [propostas, setPropostas] = useState<PropostaItem[]>([])
  const [clientes, setClientes] = useState<Cliente[]>([])
  const [detalhe, setDetalhe] = useState<PropostaDetalhe | null>(null)

  // Filtros
  const [statusFiltro, setStatusFiltro] = useState<string>('Todos')
  const [clienteFiltro, setClienteFiltro] = useState('')
  const [buscaText, setBuscaText] = useState('')

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)
  const [integrationBanner, setIntegrationBanner] = useState<{ message: string; status: string } | null>(null)

  // Modais
  const [novaPropostaModalOpen, setNovaPropostaModalOpen] = useState(false)
  const [gerarContratoModalOpen, setGerarContratoModalOpen] = useState(false)

  // Form Criar Proposta
  const [formClienteId, setFormClienteId] = useState('')
  const [formTitulo, setFormTitulo] = useState('')
  const [formDescricao, setFormDescricao] = useState('')
  const [formValor, setFormValor] = useState('')

  // Form Gerar Contrato
  const [contratoTitulo, setContratoTitulo] = useState('')
  const [contratoInicio, setContratoInicio] = useState(new Date().toISOString().split('T')[0])
  const [contratoFim, setContratoFim] = useState('')
  const [contratoValor, setContratoValor] = useState('')

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
    }, 5000)
  }

  // Carregar dados
  const fetchDados = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [list, cliList] = await Promise.all([
        comercialService.listarPropostas(
          statusFiltro === 'Todos' ? undefined : statusFiltro,
          clienteFiltro || undefined,
          buscaText.trim() || undefined
        ),
        clientesService.listarClientes('cliente')
      ])

      setPropostas(list)
      setClientes(cliList)
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar propostas comerciais.')
    } finally {
      setLoading(false)
    }
  }, [statusFiltro, clienteFiltro, buscaText])

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'propostas')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  const handleVerDetalhe = async (id: string) => {
    try {
      const data = await comercialService.obterPropostaDetalhe(id)
      setDetalhe(data)
      setTimeout(() => {
        document.getElementById('propostaDetailSection')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }, 100)
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao obter detalhes da proposta.')
    }
  }

  const handleFecharDetalhe = () => {
    setDetalhe(null)
  }

  // Fecha o painel de detalhe da proposta ao pressionar Esc
  useEffect(() => {
    if (!detalhe) return

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        handleFecharDetalhe()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [detalhe])

  const handleCriarProposta = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formClienteId || !formTitulo.trim() || !formValor) {
      showToast('Cliente, Título e Valor são obrigatórios.')
      return
    }

    const valorNum = parseFloat(formValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor deve ser maior que zero.')
      return
    }

    try {
      await comercialService.criarProposta({
        cliente_id: formClienteId,
        titulo: formTitulo.trim(),
        descricao: formDescricao.trim() || null,
        valor: valorNum,
        status: 'Rascunho'
      })

      showToast('Proposta comercial criada em Rascunho!')
      setNovaPropostaModalOpen(false)
      
      // Reset
      setFormClienteId('')
      setFormTitulo('')
      setFormDescricao('')
      setFormValor('')

      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao criar proposta.')
    }
  }

  const handleRegistrarEnvio = async (id: string) => {
    try {
      await comercialService.registrarEnvioProposta(id)
      showToast('Proposta enviada.')
    } catch (err: any) {
      console.error(err)
      triggerIntegrationStatus('Não configurado', err.message || 'Serviço de envio de e-mails/WhatsApp não configurado.')
    }
  }

  const handleOpenGerarContrato = () => {
    if (!detalhe) return
    setContratoTitulo(`Contrato - ${detalhe.titulo}`)
    setContratoValor((detalhe.valor / 12).toFixed(2)) // Sugere valor mensal baseado no total
    
    // Sugere fim em 1 ano
    const hoje = new Date()
    const anoQueVem = new Date(hoje.getFullYear() + 1, hoje.getMonth(), hoje.getDate())
    setContratoFim(anoQueVem.toISOString().split('T')[0])
    
    setGerarContratoModalOpen(true)
  }

  const handleGerarContrato = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!detalhe || !contratoTitulo.trim() || !contratoInicio || !contratoFim || !contratoValor) return

    const valorNum = parseFloat(contratoValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor recorrente deve ser maior que zero.')
      return
    }

    try {
      await comercialService.criarContrato({
        cliente_id: detalhe.cliente_id,
        proposta_id: detalhe.id,
        titulo: contratoTitulo.trim(),
        data_inicio: contratoInicio,
        data_fim: contratoFim,
        valor_recorrente: valorNum,
        status: 'Vigente'
      })

      showToast('Contrato assinado e gerado com sucesso!')
      setGerarContratoModalOpen(false)
      
      // Recarrega detalhes e lista
      handleVerDetalhe(detalhe.id)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao gerar contrato.')
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

  return (
    <AppShell titulo="Propostas Comerciais">
      <div className="propostas-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}

        {integrationBanner && (
          <IntegrationPendingState 
            status={integrationBanner.status} 
            message={integrationBanner.message} 
          />
        )}

        <header className="page-header">
          <div>
            <h1 className="page-title">Propostas Comerciais</h1>
            <p className="page-subtitle">Acompanhe negociações comerciais, envie propostas e feche novos contratos.</p>
          </div>
          {podeCriarProposta && (
            <button className="btn btn-primary btn-icon" onClick={() => setNovaPropostaModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Nova Proposta
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
                <option value="Rascunho">Rascunhos</option>
                <option value="Enviado">Enviadas</option>
                <option value="Em análise">Em Análise</option>
                <option value="Aprovado">Aprovadas</option>
                <option value="Rejeitado">Rejeitadas</option>
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
                placeholder="Título da proposta..."
                value={buscaText} 
                onChange={(e) => setBuscaText(e.target.value)} 
              />
            </div>
          </div>
        </section>

        {/* Tabela de Propostas */}
        {loading ? (
          <LoadingState message="Carregando propostas..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : propostas.length === 0 ? (
          <EmptyState 
            title="Nenhuma proposta comercial" 
            description="Não encontramos propostas lançadas para os filtros configurados."
            action={podeCriarProposta ? { label: 'Nova Proposta', onClick: () => setNovaPropostaModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Título</th>
                  <th>Cliente</th>
                  <th className="text-right">Valor Total</th>
                  <th>Enviada Em</th>
                  <th>Status</th>
                  <th className="text-center">Ações</th>
                </tr>
              </thead>
              <tbody>
                {propostas.map(item => (
                  <tr key={item.id} className="table-row-hover">
                    <td>
                      <div className="font-semibold text-fg">{item.titulo}</div>
                    </td>
                    <td>{item.cliente}</td>
                    <td className="text-right font-semibold text-fg">
                      {formatarMoeda(item.valor)}
                    </td>
                    <td>{formatarData(item.enviada_em)}</td>
                    <td>
                      <span className={`status-badge status-${item.status.toLowerCase().replace(' ', '-')}`}>
                        {item.status}
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

        {/* Detalhes Expansíveis Abaixo da Tabela */}
        {detalhe && (
          <section id="propostaDetailSection" className="detail-section card-box">
            <div className="detail-header">
              <div>
                <span className="detail-tag">Visualizando Detalhes</span>
                <h2 className="detail-title">{detalhe.titulo}</h2>
              </div>
              <div className="detail-header-actions">
                {podeEnviarProposta && detalhe.status === 'Rascunho' && (
                  <button className="btn btn-secondary" onClick={() => handleRegistrarEnvio(detalhe.id)}>
                    Enviar para Cliente
                  </button>
                )}
                {podeGerarContrato && detalhe.status === 'Aprovado' && (
                  <button className="btn btn-primary" onClick={handleOpenGerarContrato}>
                    Gerar Contrato
                  </button>
                )}
                <button
                  type="button"
                  className="modal-close-btn"
                  onClick={handleFecharDetalhe}
                  aria-label="Fechar detalhes da proposta"
                  title="Fechar"
                >
                  ×
                </button>
              </div>
            </div>

            <div className="detail-grid">
              <div className="detail-col">
                <h3 className="detail-sub">Informações Básicas</h3>
                <div className="detail-info-row">
                  <span className="info-label">Cliente/Empresa:</span>
                  <span className="info-val">{detalhe.empresa} ({detalhe.nome_contato})</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">E-mail:</span>
                  <span className="info-val">{detalhe.email || '-'}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Telefone:</span>
                  <span className="info-val">{detalhe.telefone || '-'}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Criado Por:</span>
                  <span className="info-val">{detalhe.criado_por_nome}</span>
                </div>
              </div>

              <div className="detail-col">
                <h3 className="detail-sub">Financeiro e Datas</h3>
                <div className="detail-info-row">
                  <span className="info-label">Valor da Proposta:</span>
                  <span className="info-val font-semibold text-fg">{formatarMoeda(detalhe.valor)}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Status Atual:</span>
                  <span className="info-val">
                    <span className={`status-badge status-${detalhe.status.toLowerCase().replace(' ', '-')}`}>
                      {detalhe.status}
                    </span>
                  </span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Cadastrado Em:</span>
                  <span className="info-val">{formatarData(detalhe.created_at.split('T')[0])}</span>
                </div>
                <div className="detail-info-row">
                  <span className="info-label">Enviado Em:</span>
                  <span className="info-val">{formatarData(detalhe.enviada_em)}</span>
                </div>
              </div>
            </div>

            <div className="detail-description">
              <h3 className="detail-sub font-semibold">Descrição do Escopo</h3>
              <p>{detalhe.descricao || 'Nenhuma descrição detalhada anexada a esta proposta.'}</p>
            </div>

            {(detalhe.documentos?.length ?? 0) > 0 && (
              <div className="detail-documents">
                <h3 className="detail-sub">Documentos Anexos ({detalhe.documentos.length})</h3>
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
                      <span className="doc-meta">Enviado em {formatarData(doc.criado_em.split('T')[0])}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </section>
        )}

        {/* Modal Nova Proposta */}
        {novaPropostaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Criar Nova Proposta Comercial</h3>
                <button className="modal-close-btn" onClick={() => setNovaPropostaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarProposta}>
                <div className="form-group">
                  <label>Cliente Destinatário</label>
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
                  <label>Título da Proposta</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Ex: Desenvolvimento de E-commerce B2B" 
                    value={formTitulo}
                    onChange={(e) => setFormTitulo(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label>Valor Total da Proposta (R$)</label>
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

                <div className="form-group">
                  <label>Descrição do Escopo / Notas</label>
                  <textarea 
                    rows={4} 
                    placeholder="Escreva detalhes sobre o escopo, cronograma sugerido e entregáveis..."
                    value={formDescricao}
                    onChange={(e) => setFormDescricao(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setNovaPropostaModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Salvar Rascunho</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Gerar Contrato */}
        {gerarContratoModalOpen && detalhe && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Assinar Contrato de Prestação de Serviços</h3>
                <button className="modal-close-btn" onClick={() => setGerarContratoModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleGerarContrato}>
                <p className="baixa-info-msg">
                  Gerando contrato para a proposta: <strong>{detalhe.titulo}</strong> (Cliente: {detalhe.empresa}).
                </p>

                <div className="form-group">
                  <label>Título do Contrato</label>
                  <input 
                    type="text" 
                    required 
                    value={contratoTitulo}
                    onChange={(e) => setContratoTitulo(e.target.value)}
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
                      value={contratoValor}
                      onChange={(e) => setContratoValor(e.target.value)}
                    />
                  </div>
                  <div>
                    <label>Data de Início</label>
                    <input 
                      type="date" 
                      required 
                      value={contratoInicio}
                      onChange={(e) => setContratoInicio(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Data de Término</label>
                  <input 
                    type="date" 
                    required 
                    value={contratoFim}
                    onChange={(e) => setContratoFim(e.target.value)}
                  />
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setGerarContratoModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Assinar Contrato</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppShell>
  )
}
