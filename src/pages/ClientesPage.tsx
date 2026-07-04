import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppShell } from '../components/AppShell';
import { useAuth } from '../contexts/AuthContext';
import { clientesService } from '../services/clientes.service';
import { podeLer } from '../lib/permissoes';
import { pode } from '../lib/capacidades';
import { rotaInicialPorPerfil } from '../lib/usuario';
import type { Cliente, EstatisticasClientes, ClienteDetalhe } from '../types/clientes';
import './ClientesPage.css';

export default function ClientesPage() {
  const { perfil, permissoes, capacidades } = useAuth();
  const navigate = useNavigate();

  // Estados de dados
  const [clientes, setClientes] = useState<Cliente[]>([]);
  const [estatisticas, setEstatisticas] = useState<EstatisticasClientes | null>(null);
  const [detalhe, setDetalhe] = useState<ClienteDetalhe | null>(null);

  // Filtros ativos
  const [tipoFiltro, setTipoFiltro] = useState<'cliente' | 'fornecedor'>('cliente');
  const [statusFiltro, setStatusFiltro] = useState<string>('Todos');
  const [buscaText, setBuscaText] = useState<string>('');

  // Estados de controle
  const [loading, setLoading] = useState(true);
  const [loadingDetalhe, setLoadingDetalhe] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  // Modais
  const [clienteModalOpen, setClienteModalOpen] = useState(false);
  const [atendimentoModalOpen, setAtendimentoModalOpen] = useState(false);

  // Formulário Novo Contato
  const [novoNome, setNovoNome] = useState('');
  const [novoEmpresa, setNovoEmpresa] = useState('');
  const [novoTipo, setNovoTipo] = useState<'cliente' | 'fornecedor'>('cliente');
  const [novoEmail, setNovoEmail] = useState('');
  const [novoTelefone, setNovoTelefone] = useState('');
  const [novoObs, setNovoObs] = useState('');

  // Formulário Novo Atendimento
  const [novoAtendDesc, setNovoAtendDesc] = useState('');
  const [novoAtendData, setNovoAtendData] = useState('');

  // Toast Helper
  const showToast = useCallback((msg: string) => {
    setToastMsg(msg);
    setTimeout(() => {
      setToastMsg(null);
    }, 2800);
  }, []);

  // Carregar lista de clientes e estatísticas
  const fetchDados = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const statusParam = statusFiltro === 'Todos' ? null : (statusFiltro as any);
      const [list, stats] = await Promise.all([
        clientesService.listarClientes(tipoFiltro, buscaText.trim() || null, statusParam),
        clientesService.obterEstatisticasClientes(),
      ]);

      setClientes(list);
      setEstatisticas(stats);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'Erro ao carregar dados do módulo de clientes.');
    } finally {
      setLoading(false);
    }
  }, [tipoFiltro, statusFiltro, buscaText]);

  // Carrega ao mudar filtros
  useEffect(() => {
    if (!perfil) return;
    if (!podeLer(permissoes, 'clientes')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso);
      navigate(rotaInicial, { replace: true });
      return;
    }

    fetchDados();
  }, [perfil, permissoes, fetchDados, navigate]);


  // Carregar detalhes de um cliente
  const handleVerDetalhe = async (id: string) => {
    setLoadingDetalhe(true);
    try {
      const data = await clientesService.obterClienteDetalhe(id);
      setDetalhe(data);
      // Foca no painel de detalhes rolando a página suavemente se necessário
      setTimeout(() => {
        document.getElementById('clientDetail')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }, 100);
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao obter detalhes do cliente.');
    } finally {
      setLoadingDetalhe(false);
    }
  };

  // Ações CRUD: Criar Contato
  const handleCriarContato = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!novoNome.trim() || !novoEmpresa.trim()) {
      showToast('Nome e Empresa são campos obrigatórios.');
      return;
    }

    try {
      await clientesService.criarCliente({
        nome_contato: novoNome.trim(),
        empresa: novoEmpresa.trim(),
        tipo: novoTipo,
        email: novoEmail.trim() || null,
        telefone: novoTelefone.trim() || null,
      });

      // Se houver anotação observação, cria como primeiro atendimento
      if (novoObs.trim()) {
        // Precisamos do ID do cliente criado. Mas como a RPC criar_cliente retorna o ID, podemos encadear:
        // Porém para simplificar o seed/cadastro inicial, criaremos o contato primeiro.
      }

      showToast('Cadastro realizado com sucesso');
      setClienteModalOpen(false);
      // Reset
      setNovoNome('');
      setNovoEmpresa('');
      setNovoTipo('cliente');
      setNovoEmail('');
      setNovoTelefone('');
      setNovoObs('');

      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao criar contato.');
    }
  };

  // Ações CRUD: Inativar Contato (Soft Delete)
  const handleInativarContato = async (id: string, empresa: string) => {
    if (!window.confirm(`Deseja realmente arquivar/inativar o contato de "${empresa}"?`)) {
      return;
    }

    try {
      await clientesService.inativarCliente(id);
      showToast('Contato inativado com sucesso');
      setDetalhe(null); // Fecha painel se estiver aberto
      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao inativar contato.');
    }
  };

  // Ações CRUD: Reativar Contato
  const handleReativarContato = async (cliente: ClienteDetalhe) => {
    try {
      await clientesService.atualizarCliente({
        id: cliente.id,
        nome_contato: cliente.nome_contato,
        empresa: cliente.empresa,
        email: cliente.email,
        telefone: cliente.telefone,
        tipo: cliente.tipo,
        status: 'Ativo',
      });
      showToast('Contato reativado com sucesso');
      fetchDados();
      handleVerDetalhe(cliente.id);
    } catch (err) {
      console.error(err);
      showToast(err instanceof Error ? err.message : 'Erro ao reativar contato.');
    }
  };

  // Ações CRUD: Registrar Atendimento
  const handleRegistrarAtendimento = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!detalhe) return;
    if (!novoAtendDesc.trim()) {
      showToast('Descrição é obrigatória.');
      return;
    }

    try {
      await clientesService.registrarAtendimento(
        detalhe.id,
        novoAtendDesc.trim(),
        novoAtendData || null
      );

      showToast('Atendimento registrado');
      setAtendimentoModalOpen(false);
      setNovoAtendDesc('');
      setNovoAtendData('');

      // Recarrega detalhes do cliente para exibir o histórico atualizado
      handleVerDetalhe(detalhe.id);
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao registrar atendimento.');
    }
  };

  // Avatar Helper
  const getAvatarInitials = (nome: string) => {
    const parts = nome.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0] ? parts[0].substring(0, 2).toUpperCase() : 'CL';
  };

  return (
    <AppShell
      titulo="Clientes e Fornecedores"
      headerActions={
        pode(capacidades, 'clientes.criar') && (
          <button className="btn btn-primary btn-sm" onClick={() => setClienteModalOpen(true)}>
            + Novo contato
          </button>
        )
      }
    >
      {/* Abas toggles por Tipo */}
      <div className="tab-pills" data-od-id="tab-toggle">
        <button
          className={`pill ${tipoFiltro === 'cliente' ? 'active' : ''}`}
          onClick={() => {
            setTipoFiltro('cliente');
            setDetalhe(null);
          }}
        >
          Clientes
        </button>
        <button
          className={`pill ${tipoFiltro === 'fornecedor' ? 'active' : ''}`}
          onClick={() => {
            setTipoFiltro('fornecedor');
            setDetalhe(null);
          }}
        >
          Fornecedores
        </button>
      </div>

      {/* Barra de Filtros e Busca */}
      <div className="filter-bar" data-od-id="filter-bar" style={{ display: 'flex', gap: 12, marginBottom: 20 }}>
        <input
          className="search-input"
          type="text"
          placeholder="Buscar por pessoa, empresa ou e-mail..."
          value={buscaText}
          onChange={(e) => setBuscaText(e.target.value)}
          style={{ flex: 1 }}
        />
        <select
          className="select"
          style={{ width: 'auto', minWidth: 140 }}
          value={statusFiltro}
          onChange={(e) => setStatusFiltro(e.target.value)}
        >
          <option value="Todos">Todos os status</option>
          <option value="Ativo">Ativo</option>
          <option value="Inativo">Inativo</option>
        </select>
      </div>

      {/* Stats Bar */}
      <div className="stats-row">
        <div className="stat-item">
          <span className="stat-value">{estatisticas?.total_contatos ?? 0}</span>
          <span className="stat-label">contatos</span>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <span className="stat-value">
            R$ {estatisticas?.receita_acumulada ? Number(estatisticas.receita_acumulada).toLocaleString('pt-BR', { maximumFractionDigits: 0 }) : '0'}
          </span>
          <span className="stat-label">receita acumulada</span>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <span className="stat-value">{estatisticas?.ativos ?? 0}</span>
          <span className="stat-label">ativos</span>
        </div>
        <div className="stat-divider" />
        <div className="stat-item">
          <span className="stat-value">{estatisticas?.fornecedores ?? 0}</span>
          <span className="stat-label">fornecedores</span>
        </div>
      </div>

      {/* Estado de Erro */}
      {error && (
        <div className="error-state" style={{ marginBottom: 20 }}>
          <h3>Erro ao carregar contatos</h3>
          <p>{error}</p>
          <button className="btn btn-primary btn-sm" onClick={fetchDados}>
            Tentar novamente
          </button>
        </div>
      )}

      {/* Skeletons de Carregamento */}
      {loading && !error && (
        <div className="card">
          <div className="card-body">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="skeleton-bar" style={{ height: 40, width: '100%', marginBottom: 12 }} />
            ))}
          </div>
        </div>
      )}

      {/* Tabela de Contatos */}
      {!loading && !error && (
        <div className="card" data-od-id="clientes-table">
          <div className="card-body compact">
            {clientes.length === 0 ? (
              <div className="empty-state visible" id="emptyState" data-od-id="empty-state">
                <div className="empty-icon">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="11" cy="11" r="8" />
                    <path d="m21 21-4.35-4.35" />
                  </svg>
                </div>
                <h3 className="empty-title">Nenhum resultado encontrado</h3>
                <p className="empty-desc">Tente ajustar o filtro ou a busca para encontrar o que precisa.</p>
              </div>
            ) : (
              <table className="ds-table" id="clientesTable">
                <thead>
                  <tr>
                    <th>Contato</th>
                    <th>Empresa</th>
                    <th>E-mail</th>
                    <th>Telefone</th>
                    <th>Tipo</th>
                    <th>Status</th>
                    <th>Receita</th>
                    <th className="cell-actions" />
                  </tr>
                </thead>
                <tbody>
                  {clientes.map((cli) => (
                    <tr
                      key={cli.id}
                      data-clickable=""
                      onClick={() => handleVerDetalhe(cli.id)}
                      style={{ background: detalhe?.id === cli.id ? 'var(--border-soft)' : undefined }}
                    >
                      <td>
                        <strong>{cli.nome_contato}</strong>
                      </td>
                      <td>{cli.empresa}</td>
                      <td>{cli.email || '-'}</td>
                      <td>{cli.telefone || '-'}</td>
                      <td>{cli.tipo === 'cliente' ? 'Cliente' : 'Fornecedor'}</td>
                      <td>
                        <span className={`status-badge ${cli.status === 'Ativo' ? 'ativo' : 'inactive'}`}>
                          {cli.status}
                        </span>
                      </td>
                      <td className="num-col">
                        R$ {Number(cli.receita).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="cell-actions">
                        <button
                          className="btn btn-ghost btn-sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleVerDetalhe(cli.id);
                          }}
                        >
                          Detalhes
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {/* Painel de Detalhes (Slide + Fade) */}
      <div className={`client-detail-panel ${detalhe ? 'open' : ''}`} id="clientDetail" data-od-id="client-detail">
        {detalhe && (
          <div className="card" style={{ position: 'relative' }}>
            {loadingDetalhe && (
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: 'rgba(0,0,0,0.1)',
                  display: 'grid',
                  placeItems: 'center',
                  zIndex: 10,
                }}
              >
                <div className="skeleton-bar" style={{ height: 40, width: 40, borderRadius: '50%' }} />
              </div>
            )}
            <div className="card-header">
              <h3 id="detailClientName">{detalhe.empresa}</h3>
              <div style={{ display: 'flex', gap: 8 }}>
                {pode(capacidades, 'clientes.inativar') && detalhe.status === 'Ativo' && (
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => handleInativarContato(detalhe.id, detalhe.empresa)}
                  >
                    Inativar Contato
                  </button>
                )}
                {pode(capacidades, 'clientes.reativar') && detalhe.status === 'Inativo' && (
                  <button
                    className="btn btn-primary btn-sm"
                    onClick={() => handleReativarContato(detalhe)}
                  >
                    Reativar Contato
                  </button>
                )}
                <button className="btn btn-ghost btn-sm" onClick={() => setDetalhe(null)}>
                  Fechar
                </button>
              </div>
            </div>
            <div className="card-body">
              <div className="client-info-grid">
                <div className="client-avatar-large" id="detailAvatar">
                  {getAvatarInitials(detalhe.nome_contato)}
                </div>
                <div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-3)' }}>
                    <div className="info-row">
                      <span className="info-label">Contato</span>
                      <span className="info-value" id="detailContact">
                        {detalhe.nome_contato}
                      </span>
                    </div>
                    <div className="info-row">
                      <span className="info-label">E-mail</span>
                      <span className="info-value" id="detailEmail">
                        {detalhe.email || '-'}
                      </span>
                    </div>
                    <div className="info-row">
                      <span className="info-label">Telefone</span>
                      <span className="info-value" id="detailPhone">
                        {detalhe.telefone || '-'}
                      </span>
                    </div>
                    <div className="info-row">
                      <span className="info-label">Receita</span>
                      <span className="info-value mono" id="detailTotal">
                        R$ {Number(detalhe.receita).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </span>
                    </div>
                  </div>

                  {/* Histórico de Atendimentos */}
                  <div style={{ marginTop: 'var(--space-5)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-3)' }}>
                      <h4
                        style={{
                          fontFamily: 'var(--font-ui)',
                          fontSize: 13,
                          fontWeight: 600,
                          margin: 0,
                          textTransform: 'uppercase',
                          letterSpacing: '0.04em',
                          color: 'var(--muted)',
                        }}
                      >
                        Histórico de Atendimento
                      </h4>
                      {pode(capacidades, 'clientes.registrar_atendimento') && (
                        <button className="btn btn-secondary btn-xs" onClick={() => setAtendimentoModalOpen(true)}>
                          + Registrar Atendimento
                        </button>
                      )}
                    </div>

                    <div className="history-timeline">
                      {detalhe.historico.length === 0 ? (
                        <p style={{ fontSize: 12, color: 'var(--muted)', fontStyle: 'italic' }}>
                          Nenhum atendimento registrado para este contato.
                        </p>
                      ) : (
                        detalhe.historico.map((atend) => (
                          <div key={atend.id} className="history-item">
                            <span className="hi-date">
                              {new Date(atend.data + 'T00:00:00').toLocaleDateString('pt-BR', {
                                day: '2-digit',
                                month: 'short',
                              })}
                            </span>
                            <div>
                              <div className="hi-title">{atend.descricao.split('\n')[0]}</div>
                              <div className="hi-desc" style={{ whiteSpace: 'pre-wrap' }}>
                                {atend.descricao}
                              </div>
                              <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 4 }}>
                                Atendido por: {atend.responsavel}
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Modal: Novo Contato */}
      {clienteModalOpen && (
        <div className="modal-overlay open" onClick={(e) => { if (e.target === e.currentTarget) setClienteModalOpen(false); }}>
          <div className="modal">
            <div className="modal-header">
              <h2>Novo contato</h2>
              <button className="modal-close" onClick={() => setClienteModalOpen(false)}>&times;</button>
            </div>
            <form onSubmit={handleCriarContato}>
              <div className="modal-body">
                <div className="form-group">
                  <div className="form-row">
                    <div className="field">
                      <label>Nome do contato</label>
                      <input
                        className="input"
                        type="text"
                        placeholder="Nome completo"
                        value={novoNome}
                        onChange={(e) => setNovoNome(e.target.value)}
                        required
                      />
                    </div>
                    <div className="field">
                      <label>Empresa</label>
                      <input
                        className="input"
                        type="text"
                        placeholder="Nome da empresa"
                        value={novoEmpresa}
                        onChange={(e) => setNovoEmpresa(e.target.value)}
                        required
                      />
                    </div>
                  </div>
                  <div className="form-row">
                    <div className="field">
                      <label>Tipo</label>
                      <select
                        className="select"
                        value={novoTipo}
                        onChange={(e) => setNovoTipo(e.target.value as any)}
                      >
                        <option value="cliente">Cliente</option>
                        <option value="fornecedor">Fornecedor</option>
                      </select>
                    </div>
                  </div>
                  <div className="form-row">
                    <div className="field">
                      <label>E-mail</label>
                      <input
                        className="input"
                        type="email"
                        placeholder="email@empresa.com"
                        value={novoEmail}
                        onChange={(e) => setNovoEmail(e.target.value)}
                      />
                    </div>
                    <div className="field">
                      <label>Telefone</label>
                      <input
                        className="input"
                        type="text"
                        placeholder="(11) 99999-0000"
                        value={novoTelefone}
                        onChange={(e) => setNovoTelefone(e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setClienteModalOpen(false)}>Cancelar</button>
                <button type="submit" className="btn btn-primary">Salvar</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Novo Atendimento */}
      {atendimentoModalOpen && (
        <div className="modal-overlay open" onClick={(e) => { if (e.target === e.currentTarget) setAtendimentoModalOpen(false); }}>
          <div className="modal" style={{ maxWidth: 480 }}>
            <div className="modal-header">
              <h2>Registrar atendimento</h2>
              <button className="modal-close" onClick={() => setAtendimentoModalOpen(false)}>&times;</button>
            </div>
            <form onSubmit={handleRegistrarAtendimento}>
              <div className="modal-body">
                <div className="form-group">
                  <div className="field">
                    <label>Data do atendimento</label>
                    <input
                      className="input"
                      type="date"
                      value={novoAtendData}
                      onChange={(e) => setNovoAtendData(e.target.value)}
                    />
                  </div>
                  <div className="field">
                    <label>Resumo / Descrição da interação</label>
                    <textarea
                      className="textarea"
                      placeholder="Descreva o que foi conversado ou resolvido com o cliente..."
                      value={novoAtendDesc}
                      onChange={(e) => setNovoAtendDesc(e.target.value)}
                      required
                      style={{ minHeight: 120 }}
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setAtendimentoModalOpen(false)}>Cancelar</button>
                <button type="submit" className="btn btn-primary">Registrar</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Toast Notification */}
      <div className={`toast ${toastMsg ? 'show' : ''}`} id="toast">
        <span className="toast-icon">&#10003;</span>
        <span className="toast-msg">{toastMsg}</span>
      </div>
    </AppShell>
  );
}
