import React, { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { comercialService } from '../services/comercial.service'
import { clientesService } from '../services/clientes.service'
import { podeLer, podeEscrever } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'
import { LoadingState, EmptyState, ErrorState, IntegrationPendingState } from '../components/ui/States'
import type { CobrancaItem, ContratoItem } from '../types/comercial'
import type { Cliente } from '../types/clientes'
import './CobrancasPage.css'

export default function CobrancasPage() {
  const { perfil, permissoes } = useAuth()
  const navigate = useNavigate()
  const temEscrita = podeEscrever(permissoes, 'cobrancas')
  // Registrar pagamento é ownership do Financeiro/Administrador (a RPC rejeita
  // Comercial mesmo com escrita em 'cobrancas'); a ação "Baixar" só aparece
  // para quem realmente pode executá-la.
  const podeRegistrarPagamento = podeEscrever(permissoes, 'financeiro')

  // Estados de dados
  const [cobrancas, setCobrancas] = useState<CobrancaItem[]>([])
  const [clientes, setClientes] = useState<Cliente[]>([])
  const [contratosDoCliente, setContratosDoCliente] = useState<ContratoItem[]>([])

  // Filtros
  const [statusFiltro, setStatusFiltro] = useState<string>('Pendente')
  const [clienteFiltro, setClienteFiltro] = useState('')
  const [buscaText, setBuscaText] = useState('')

  // Controle de interface
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toastMsg, setToastMsg] = useState<string | null>(null)
  const [integrationBanner, setIntegrationBanner] = useState<{ message: string; status: string } | null>(null)

  // Modais
  const [novaCobrancaModalOpen, setNovaCobrancaModalOpen] = useState(false)
  const [baixaModalOpen, setBaixaModalOpen] = useState(false)

  // Form de Criar Cobrança
  const [formClienteId, setFormClienteId] = useState('')
  const [formContratoId, setFormContratoId] = useState('')
  const [formValor, setFormValor] = useState('')
  const [formDataVencimento, setFormDataVencimento] = useState('')
  const [formCriarLancamento, setFormCriarLancamento] = useState(true)

  // Form de Registrar Pagamento
  const [baixaId, setBaixaId] = useState<string | null>(null)
  const [baixaCliente, setBaixaCliente] = useState('')
  const [baixaValor, setBaixaValor] = useState('')
  const [baixaData, setBaixaData] = useState(new Date().toISOString().split('T')[0])
  const [baixaForma, setBaixaForma] = useState('Pix')

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

  // Carregar cobranças
  const fetchDados = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [list] = await Promise.all([
        comercialService.listarCobrancas(
          statusFiltro === 'Todos' ? undefined : statusFiltro,
          clienteFiltro || undefined
        )
      ])

      setCobrancas(list)

      // Módulo "clientes" pode ser negado por RBAC (ex.: perfil Financeiro); degrada
      // para lista vazia em vez de quebrar a página inteira.
      try {
        setClientes(await clientesService.listarClientes('cliente'))
      } catch {
        setClientes([])
      }
    } catch (err: any) {
      console.error(err)
      setError(err.message || 'Erro ao carregar cobranças.')
    } finally {
      setLoading(false)
    }
  }, [statusFiltro, clienteFiltro])

  // A RPC listar_cobrancas não aceita busca textual; filtramos no cliente
  // sobre a lista já carregada (cliente/contrato).
  const cobrancasFiltradas = buscaText.trim()
    ? cobrancas.filter((item) => {
        const termo = buscaText.trim().toLowerCase()
        return (
          item.cliente.toLowerCase().includes(termo) ||
          (item.contrato || '').toLowerCase().includes(termo)
        )
      })
    : cobrancas

  useEffect(() => {
    if (!perfil) return
    if (!podeLer(permissoes, 'cobrancas')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso)
      navigate(rotaInicial, { replace: true })
      return
    }

    fetchDados()
  }, [perfil, permissoes, fetchDados, navigate])

  // Busca contratos quando muda o cliente no form de criação
  useEffect(() => {
    if (!formClienteId) {
      setContratosDoCliente([])
      return
    }

    comercialService.listarContratos('Vigente', formClienteId)
      .then(res => setContratosDoCliente(res))
      .catch(err => console.error('Erro ao buscar contratos do cliente:', err))
  }, [formClienteId])

  const handleCriarCobranca = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formClienteId || !formValor || !formDataVencimento) {
      showToast('Cliente, Valor e Vencimento são obrigatórios.')
      return
    }

    const valorNum = parseFloat(formValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor inserido deve ser maior que zero.')
      return
    }

    try {
      await comercialService.criarCobranca({
        cliente_id: formClienteId,
        contrato_id: formContratoId || null,
        valor: valorNum,
        data_vencimento: formDataVencimento,
        criar_lancamento_financeiro: formCriarLancamento
      })

      showToast('Cobrança emitida com sucesso!')
      setNovaCobrancaModalOpen(false)
      
      // Reset
      setFormClienteId('')
      setFormContratoId('')
      setFormValor('')
      setFormDataVencimento('')
      
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar cobrança.')
    }
  }

  const handleOpenBaixa = (item: CobrancaItem) => {
    setBaixaId(item.id)
    setBaixaCliente(item.cliente)
    setBaixaValor(item.valor.toString())
    setBaixaModalOpen(true)
  }

  const handleRegistrarBaixa = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!baixaId || !baixaData || !baixaValor) return

    const valorNum = parseFloat(baixaValor)
    if (isNaN(valorNum) || valorNum <= 0) {
      showToast('O valor do pagamento deve ser maior que zero.')
      return
    }

    try {
      await comercialService.registrarPagamentoCobranca(baixaId, baixaData, valorNum, baixaForma)
      showToast('Baixa de cobrança registrada com sucesso!')
      setBaixaModalOpen(false)
      fetchDados()
    } catch (err: any) {
      console.error(err)
      showToast(err.message || 'Erro ao registrar pagamento.')
    }
  }

  const handleEmitirBoleto = async (id: string) => {
    try {
      await comercialService.solicitarEmissaoBoleto(id)
      showToast('Boleto solicitado.')
    } catch (err: any) {
      console.error(err)
      // Exibe amigavelmente o status de integração não configurada
      triggerIntegrationStatus('Não configurado', err.message || 'Gateway de pagamento não configurado.')
    }
  }

  const handleEnviarLembrete = async (id: string) => {
    try {
      await comercialService.solicitarLembreteCobranca(id)
      showToast('Lembrete solicitado.')
    } catch (err: any) {
      console.error(err)
      // Exibe amigavelmente o status de lembrete não enviado
      triggerIntegrationStatus('Não enviado', err.message || 'Integração de comunicação (e-mail/WhatsApp) indisponível.')
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
    <AppShell titulo="Cobranças">
      <div className="cobrancas-container">
        {toastMsg && <div className="toast-notification">{toastMsg}</div>}
        
        {integrationBanner && (
          <IntegrationPendingState 
            status={integrationBanner.status} 
            message={integrationBanner.message} 
          />
        )}

        <header className="page-header">
          <div>
            <h1 className="page-title">Faturamento & Cobranças</h1>
            <p className="page-subtitle">Emita e acompanhe cobranças de clientes e status de adimplência.</p>
          </div>
          {temEscrita && (
            <button className="btn btn-primary btn-icon" onClick={() => setNovaCobrancaModalOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="12" y1="5" x2="12" y2="19" strokeLinecap="round" />
                <line x1="5" y1="12" x2="19" y2="12" strokeLinecap="round" />
              </svg>
              Emitir Cobrança
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
                <option value="Pendente">Pendentes</option>
                <option value="Pago">Pagas</option>
                <option value="Vencido">Vencidas</option>
                <option value="Cancelado">Canceladas</option>
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
                placeholder="Buscar por cliente ou contrato..."
                value={buscaText} 
                onChange={(e) => setBuscaText(e.target.value)} 
              />
            </div>
          </div>
        </section>

        {/* Tabela de Cobranças */}
        {loading ? (
          <LoadingState message="Carregando faturamento..." />
        ) : error ? (
          <ErrorState message={error} onRetry={fetchDados} />
        ) : cobrancasFiltradas.length === 0 ? (
          <EmptyState
            title="Nenhuma fatura de cobrança emitida"
            description="Não encontramos cobranças correspondentes para os filtros configurados."
            action={temEscrita ? { label: 'Emitir Cobrança', onClick: () => setNovaCobrancaModalOpen(true) } : undefined}
          />
        ) : (
          <div className="responsive-table-container card-box">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Cliente</th>
                  <th>Contrato</th>
                  <th>Vencimento</th>
                  <th className="text-right">Valor</th>
                  <th>Status</th>
                  {temEscrita && <th className="text-center">Ações</th>}
                </tr>
              </thead>
              <tbody>
                {cobrancasFiltradas.map(item => (
                  <tr key={item.id} className="table-row-hover">
                    <td>
                      <div className="font-semibold text-fg">{item.cliente}</div>
                    </td>
                    <td>{item.contrato || '-'}</td>
                    <td>{formatarData(item.data_vencimento)}</td>
                    <td className="text-right font-semibold text-fg">
                      {formatarMoeda(item.valor)}
                    </td>
                    <td>
                      <span className={`status-badge status-${item.status_exibicao.toLowerCase().replace(' ', '-')}`}>
                        {item.status_exibicao}
                      </span>
                    </td>
                    {temEscrita && (
                      <td className="text-center actions-cell">
                        {item.status_exibicao !== 'Pago' && item.status_exibicao !== 'Cancelado' && (
                          <>
                            {podeRegistrarPagamento && (
                              <button className="btn btn-xs btn-outline" onClick={() => handleOpenBaixa(item)}>
                                Baixar
                              </button>
                            )}
                            <button className="btn btn-xs btn-outline-secondary" onClick={() => handleEmitirBoleto(item.id)}>
                              Boleto
                            </button>
                            <button className="btn btn-xs btn-outline-secondary" onClick={() => handleEnviarLembrete(item.id)}>
                              Notificar
                            </button>
                          </>
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Modal Emitir Cobrança */}
        {novaCobrancaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content">
              <div className="modal-header">
                <h3 className="modal-title">Emitir Nova Fatura de Cobrança</h3>
                <button className="modal-close-btn" onClick={() => setNovaCobrancaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleCriarCobranca}>
                <div className="form-group">
                  <label>Cliente</label>
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
                  <label>Contrato de Origem</label>
                  <select 
                    value={formContratoId} 
                    onChange={(e) => setFormContratoId(e.target.value)}
                    disabled={!formClienteId}
                  >
                    <option value="">Sem contrato vinculado (Avulso)</option>
                    {contratosDoCliente.map(c => (
                      <option key={c.id} value={c.id}>{c.titulo} ({formatarMoeda(c.valor_recorrente)}/mês)</option>
                    ))}
                  </select>
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
                    <label>Data de Vencimento</label>
                    <input 
                      type="date" 
                      required 
                      value={formDataVencimento}
                      onChange={(e) => setFormDataVencimento(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group checkbox-group">
                  <label className="checkbox-label">
                    <input 
                      type="checkbox" 
                      checked={formCriarLancamento}
                      onChange={(e) => setFormCriarLancamento(e.target.checked)}
                    />
                    Lançar receita pendente no financeiro automaticamente
                  </label>
                </div>

                <div className="modal-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setNovaCobrancaModalOpen(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Emitir Fatura</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal de Baixa de Cobrança */}
        {baixaModalOpen && (
          <div className="modal-backdrop">
            <div className="modal-content modal-sm">
              <div className="modal-header">
                <h3 className="modal-title">Registrar Baixa de Cobrança</h3>
                <button className="modal-close-btn" onClick={() => setBaixaModalOpen(false)}>×</button>
              </div>
              <form onSubmit={handleRegistrarBaixa}>
                <p className="baixa-info-msg">
                  Confirmando o recebimento da fatura do cliente: <strong>{baixaCliente}</strong>.
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

                <div className="form-group row-2">
                  <div>
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
                  <div>
                    <label>Forma de Pagamento</label>
                    <select 
                      value={baixaForma}
                      onChange={(e) => setBaixaForma(e.target.value)}
                    >
                      <option value="Pix">Pix</option>
                      <option value="Boleto">Boleto Bancário</option>
                      <option value="Transferência">TED/DOC</option>
                      <option value="Cartão de Crédito">Cartão de Crédito</option>
                    </select>
                  </div>
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
