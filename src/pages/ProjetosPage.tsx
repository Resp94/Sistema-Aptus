import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppShell } from '../components/AppShell';
import { useAuth } from '../contexts/AuthContext';
import { projectsService } from '../services/projetos.service';
import { clientesService } from '../services/clientes.service';
import { podeLer, podeEscrever } from '../lib/permissoes';
import { rotaInicialPorPerfil } from '../lib/usuario';
import { supabase } from '../services/supabase';
import type { Projeto, ResumoProjetos, DistribuicaoCliente, TarefaKanban } from '../types/projetos';
import type { Cliente } from '../types/clientes';
import './ProjetosPage.css';

export default function ProjetosPage() {
  const { perfil, permissoes } = useAuth();
  const navigate = useNavigate();
  const temEscrita = podeEscrever(permissoes, 'projetos');

  // Estados de dados
  const [projetos, setProjetos] = useState<Projeto[]>([]);
  const [resumo, setResumo] = useState<ResumoProjetos | null>(null);
  const [distribuicao, setDistribuicao] = useState<DistribuicaoCliente[]>([]);
  const [tarefas, setTarefas] = useState<TarefaKanban[]>([]);
  const [clientes, setClientes] = useState<Cliente[]>([]);
  const [responsaveis, setResponsaveis] = useState<{ id: string; nome: string }[]>([]);

  // Estados de controle da página
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  // Modais
  const [projetoModalOpen, setProjetoModalOpen] = useState(false);
  const [tarefaModalOpen, setTarefaModalOpen] = useState(false);
  const [instrucoesModalOpen, setInstrucoesModalOpen] = useState(false);

  // Campos de Formulários
  const [novoProjNome, setNovoProjNome] = useState('');
  const [novoProjClienteId, setNovoProjClienteId] = useState('');
  const [novoProjOrcamento, setNovoProjOrcamento] = useState('');
  const [novoProjPrazo, setNovoProjPrazo] = useState('');

  const [novaTarefaTitulo, setNovaTarefaTitulo] = useState('');
  const [novaTarefaProjetoId, setNovaTarefaProjetoId] = useState('');
  const [novaTarefaResponsavelId, setNovaTarefaResponsavelId] = useState('');
  const [novaTarefaPrioridade, setNovaTarefaPrioridade] = useState<'Alta' | 'Média' | 'Baixa'>('Média');
  const [novaTarefaPrazo, setNovaTarefaPrazo] = useState('');
  const [novaTarefaInstrucoes, setNovaTarefaInstrucoes] = useState('');

  const [instrucoesTarefaId, setInstrucoesTarefaId] = useState<string | null>(null);
  const [instrucoesTitulo, setInstrucoesTitulo] = useState('');
  const [instrucoesAtuais, setInstrucoesAtuais] = useState('');
  const [instrucoesNovas, setInstrucoesNovas] = useState('');

  // Toast Helper
  const showToast = useCallback((msg: string) => {
    setToastMsg(msg);
    setTimeout(() => {
      setToastMsg(null);
    }, 2800);
  }, []);

  // Busca dados do banco
  const fetchDados = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [projList, resumoData, distData, tarefasData] = await Promise.all([
        projectsService.listarProjetos(),
        projectsService.obterResumoProjetos(),
        projectsService.obterDistribuicaoClientes(),
        projectsService.listarTarefasKanban(),
      ]);

      setProjetos(projList);
      setResumo(resumoData);
      setDistribuicao(distData);
      setTarefas(tarefasData);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'Erro ao carregar dados do módulo de projetos.');
    } finally {
      setLoading(false);
    }
  }, []);

  // Carga inicial e meta-dados secundários
  useEffect(() => {
    if (!perfil) return;
    if (!podeLer(permissoes, 'projetos')) {
      const rotaInicial = rotaInicialPorPerfil(perfil.perfil_acesso);
      navigate(rotaInicial, { replace: true });
      return;
    }

    fetchDados();

    // Carregar clientes ativos para o formulário de projetos (try-catch para resiliência de RBAC)
    async function carregarClientes() {
      try {
        const cliList = await clientesService.listarClientes('cliente', null, 'Ativo');
        setClientes(cliList);
      } catch {
        // Silencia erro se o usuário não tiver permissão para ler clientes
        setClientes([]);
      }
    }

    // Carregar equipe/perfis para o formulário de tarefas (RLS friendly)
    async function carregarResponsaveis() {
      try {
        const data = await projectsService.listarResponsaveisTarefas();
        if (data) {
          setResponsaveis(data.map((d) => ({ id: d.usuario_id, nome: `${d.nome} (${d.perfil_acesso})` })));
        }
      } catch {
        // Fallback: tenta obter o usuário logado atual
        const { data } = await supabase.auth.getUser();
        if (data?.user) {
          setResponsaveis([{ id: data.user.id, nome: data.user.email || 'Eu' }]);
        }
      }
    }

    carregarClientes();
    carregarResponsaveis();
  }, [perfil, permissoes, fetchDados, navigate]);


  // Ações CRUD: Criar Projeto
  const handleCriarProjeto = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!novoProjNome.trim()) {
      showToast('Nome do projeto é obrigatório.');
      return;
    }

    try {
      const orcamento = parseFloat(novoProjOrcamento.replace(/[^\d.,]/g, '').replace(',', '.')) || 0;
      await projectsService.criarProjeto({
        nome: novoProjNome.trim(),
        cliente_id: novoProjClienteId || null,
        orcamento,
        prazo: novoProjPrazo || null,
      });

      showToast('Projeto criado com sucesso');
      setProjetoModalOpen(false);
      // Reset campos
      setNovoProjNome('');
      setNovoProjClienteId('');
      setNovoProjOrcamento('');
      setNovoProjPrazo('');

      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao criar projeto.');
    }
  };

  // Ações CRUD: Excluir Projeto
  const handleExcluirProjeto = async (id: string, nome: string) => {
    if (!window.confirm(`Tem certeza que deseja excluir o projeto "${nome}"? Todas as tarefas e alocações associadas serão perdidas permanentemente.`)) {
      return;
    }

    try {
      await projectsService.excluirProjeto(id);
      showToast('Projeto excluído com sucesso');
      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao excluir projeto.');
    }
  };

  // Ações CRUD: Criar Tarefa
  const handleCriarTarefa = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!novaTarefaTitulo.trim()) {
      showToast('Título da tarefa é obrigatório.');
      return;
    }
    if (!novaTarefaProjetoId) {
      showToast('Projeto associado é obrigatório.');
      return;
    }

    try {
      await projectsService.criarTarefa({
        projeto_id: novaTarefaProjetoId,
        titulo: novaTarefaTitulo.trim(),
        prioridade: novaTarefaPrioridade,
        responsavel_id: novaTarefaResponsavelId || null,
        prazo: novaTarefaPrazo || null,
        instrucoes: novaTarefaInstrucoes || null,
      });

      showToast('Tarefa adicionada ao Kanban');
      setTarefaModalOpen(false);
      // Reset campos
      setNovaTarefaTitulo('');
      setNovaTarefaProjetoId('');
      setNovaTarefaResponsavelId('');
      setNovaTarefaPrioridade('Média');
      setNovaTarefaPrazo('');
      setNovaTarefaInstrucoes('');

      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao adicionar tarefa.');
    }
  };

  // Ações CRUD: Salvar Instruções
  const handleSalvarInstrucao = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!instrucoesTarefaId) return;

    try {
      const tarefaObj = tarefas.find((t) => t.id === instrucoesTarefaId);
      if (!tarefaObj) return;

      await projectsService.atualizarTarefa({
        id: instrucoesTarefaId,
        titulo: tarefaObj.titulo,
        prioridade: tarefaObj.prioridade,
        responsavel_id: responsaveis.find((r) => r.nome === tarefaObj.responsavel)?.id || null,
        prazo: tarefaObj.prazo,
        instrucoes: instrucoesNovas.trim() || null,
      });

      showToast('Instruções salvas');
      setInstrucoesModalOpen(false);
      setInstrucoesTarefaId(null);
      setInstrucoesNovas('');

      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao salvar instruções.');
    }
  };

  // Ações CRUD: Excluir Tarefa
  const handleExcluirTarefa = async (id: string, titulo: string) => {
    if (!window.confirm(`Excluir a tarefa "${titulo}"?`)) return;

    try {
      await projectsService.excluirTarefa(id);
      showToast('Tarefa excluída');
      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao excluir tarefa.');
    }
  };

  // Drag and Drop Handlers
  const handleDragStart = (e: React.DragEvent, id: string) => {
    e.dataTransfer.setData('text/plain', id);
    e.dataTransfer.effectAllowed = 'move';
    const card = e.currentTarget as HTMLElement;
    card.classList.add('dragging');
  };

  const handleDragEnd = (e: React.DragEvent) => {
    const card = e.currentTarget as HTMLElement;
    card.classList.remove('dragging');
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    const column = e.currentTarget as HTMLElement;
    column.classList.add('drag-over');
  };

  const handleDragLeave = (e: React.DragEvent) => {
    const column = e.currentTarget as HTMLElement;
    column.classList.remove('drag-over');
  };

  const handleDrop = async (e: React.DragEvent, situacao: 'A Fazer' | 'Em Andamento' | 'Concluído') => {
    e.preventDefault();
    const column = e.currentTarget as HTMLElement;
    column.classList.remove('drag-over');

    const id = e.dataTransfer.getData('text/plain');
    if (!id) return;

    // Atualização otimista local
    setTarefas((prev) => prev.map((t) => (t.id === id ? { ...t, situacao } : t)));

    try {
      await projectsService.moverTarefa(id, situacao);
      showToast(`Tarefa movida para "${situacao}"`);
      fetchDados();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Erro ao mover tarefa no banco.');
      fetchDados(); // Reverte para o estado correto
    }
  };

  // Gerar Pizza de Distribuição com Conic Gradient
  let acumulador = 0;
  const cores = ['var(--accent)', 'var(--success)', '#9fbbe0', 'var(--warn)', 'rgba(207,45,86,0.35)', '#b39ddb', '#80deea', '#ffab91'];
  
  const conicGradientStyle = distribuicao.map((item, index) => {
    const cor = cores[index % cores.length];
    const inicio = acumulador;
    acumulador += Number(item.percentual);
    return `${cor} ${inicio}% ${acumulador}%`;
  }).join(', ');

  const visualStyle = conicGradientStyle 
    ? { background: `conic-gradient(${conicGradientStyle})` } 
    : { background: 'var(--border-soft)' };

  // Organizar Kanban por coluna
  const tarefasTodo = tarefas.filter((t) => t.situacao === 'A Fazer');
  const tarefasProgress = tarefas.filter((t) => t.situacao === 'Em Andamento');
  const tarefasDone = tarefas.filter((t) => t.situacao === 'Concluído');

  return (
    <AppShell
      titulo="Projetos"
      headerActions={
        temEscrita && (
          <button className="btn btn-primary btn-sm" onClick={() => setProjetoModalOpen(true)}>
            + Novo projeto
          </button>
        )
      }
    >
      {/* Estado de Erro Geral */}
      {error && (
        <div className="error-state">
          <h3>Erro ao carregar dados</h3>
          <p>{error}</p>
          <button className="btn btn-primary btn-sm" onClick={fetchDados}>
            Tentar novamente
          </button>
        </div>
      )}

      {/* Skeletons de Carregamento */}
      {loading && !error && (
        <>
          <div className="projeto-summary">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="metric-card">
                <div className="skeleton-bar" style={{ height: 14, width: '60%', marginBottom: 12 }} />
                <div className="skeleton-bar" style={{ height: 28, width: '40%', marginBottom: 8 }} />
                <div className="skeleton-bar" style={{ height: 12, width: '80%' }} />
              </div>
            ))}
          </div>
          <div className="projeto-grid">
            <div className="card">
              <div className="card-header"><div className="skeleton-bar" style={{ height: 18, width: '40%' }} /></div>
              <div className="card-body">
                {[1, 2, 3].map((i) => (
                  <div key={i} style={{ marginBottom: 16 }}>
                    <div className="skeleton-bar" style={{ height: 14, width: '100%', marginBottom: 8 }} />
                    <div className="skeleton-bar" style={{ height: 6, width: '100%' }} />
                  </div>
                ))}
              </div>
            </div>
            <div className="card">
              <div className="card-header"><div className="skeleton-bar" style={{ height: 18, width: '40%' }} /></div>
              <div className="card-body" style={{ display: 'flex', gap: 20 }}>
                <div className="skeleton-bar" style={{ height: 100, width: 100, borderRadius: '50%' }} />
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {[1, 2, 3].map((i) => (
                    <div key={i} className="skeleton-bar" style={{ height: 12, width: '60%' }} />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Exibição dos Dados */}
      {!loading && !error && (
        <>
          {/* Métricas Topo */}
          <div className="projeto-summary" data-od-id="projeto-summary">
            <div className="metric-card">
              <div className="metric-label">Projetos ativos</div>
              <div className="metric-value">{resumo?.projetos_ativos ?? 0}</div>
              <div className="metric-sub">
                {projetos.filter((p) => p.status === 'Em andamento').length} em andamento &middot;{' '}
                {projetos.filter((p) => p.status === 'Planejamento').length} em planejamento
              </div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Tarefas abertas</div>
              <div className="metric-value">{resumo?.tarefas_abertas ?? 0}</div>
              <div className="metric-sub">
                {tarefas.filter((t) => t.situacao === 'Em Andamento').length} em andamento &middot;{' '}
                {tarefas.filter((t) => t.situacao === 'A Fazer').length} pendentes
              </div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Orçamento total</div>
              <div className="metric-value">
                R$ {resumo?.orcamento_total ? Number(resumo.orcamento_total).toLocaleString('pt-BR', { minimumFractionDigits: 2 }) : '0,00'}
              </div>
              <div className="metric-sub">{resumo?.orcamento_utilizado_pct ?? 0}% utilizado</div>
            </div>
            <div className="metric-card">
              <div className="metric-label">Em risco</div>
              <div className="metric-value">{resumo?.em_risco ?? 0}</div>
              <div className="metric-change down">Atraso ou desvio crítico</div>
            </div>
          </div>

          {/* Seção Grid: Progresso e Distribuição */}
          <div className="projeto-grid" data-od-id="projeto-grid">
            <div className="card">
              <div className="card-header">
                <h3>Progresso dos projetos</h3>
              </div>
              <div className="card-body">
                {projetos.length === 0 ? (
                  <div className="empty-state">
                    <p className="empty-desc">Nenhum projeto cadastrado.</p>
                  </div>
                ) : (
                  <div className="project-progress-list">
                    {projetos.map((proj) => {
                      let color = 'var(--accent)';
                      if (proj.status === 'Concluído') color = 'var(--success)';
                      else if (proj.em_risco) color = 'var(--danger)';
                      else if (proj.progresso < 40) color = 'var(--warn)';

                      return (
                        <div key={proj.id} className="project-progress-item">
                          <div className="pp-name">
                            <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              {proj.nome}
                              {temEscrita && (
                                <button
                                  className="card-action-btn delete-btn"
                                  style={{ padding: 2, display: 'inline-flex' }}
                                  onClick={() => handleExcluirProjeto(proj.id, proj.nome)}
                                  title="Excluir projeto"
                                >
                                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ width: 12, height: 12 }}>
                                    <polyline points="3 6 5 6 21 6" />
                                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                                  </svg>
                                </button>
                              )}
                            </span>
                            <span className="pp-percent" style={{ color }}>
                              {proj.progresso}%
                            </span>
                          </div>
                          <div className="progress-bar">
                            <div className="fill" style={{ width: `${proj.progresso}%`, background: color }} />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            <div className="card">
              <div className="card-header">
                <h3>Distribuição por cliente</h3>
              </div>
              <div className="card-body">
                {distribuicao.length === 0 ? (
                  <div className="empty-state">
                    <p className="empty-desc">Sem dados de distribuição.</p>
                  </div>
                ) : (
                  <div className="chart-pie">
                    <div className="pie-visual" style={visualStyle} />
                    <div className="pie-legend">
                      {distribuicao.map((item, index) => (
                        <div key={item.cliente} className="legend-item">
                          <span className="legend-dot" style={{ background: cores[index % cores.length] }} />
                          {item.cliente} ({Number(item.percentual)}%)
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Kanban de Tarefas */}
          <div className="card" data-od-id="kanban-section">
            <div className="card-header">
              <h3>Kanban: tarefas</h3>
              {temEscrita && (
                <button className="btn btn-secondary btn-sm" onClick={() => setTarefaModalOpen(true)}>
                  + Adicionar Tarefa
                </button>
              )}
            </div>
            <div className="card-body">
              <div className="kanban" data-od-id="kanban">
                {/* Coluna A Fazer */}
                <div
                  className="kanban-column col-todo"
                  onDragOver={handleDragOver}
                  onDragLeave={handleDragLeave}
                  onDrop={(e) => handleDrop(e, 'A Fazer')}
                >
                  <div className="column-header">
                    <span className="column-header-left">
                      <span className="column-dot" />
                      <span>A Fazer</span>
                    </span>
                    <span className="column-count">{tarefasTodo.length}</span>
                  </div>
                  {tarefasTodo.map((tarefa) => (
                    <div
                      key={tarefa.id}
                      className="kanban-card"
                      data-card-id={tarefa.id}
                      draggable={temEscrita}
                      onDragStart={(e) => handleDragStart(e, tarefa.id)}
                      onDragEnd={handleDragEnd}
                    >
                      <div className="card-title">{tarefa.titulo}</div>
                      <div className="card-meta">
                        <span>{tarefa.prioridade} prioridade</span>
                        {tarefa.prazo && (
                          <>
                            <span>&middot;</span>
                            <span>Prazo: {new Date(tarefa.prazo + 'T00:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' })}</span>
                          </>
                        )}
                      </div>
                      <div className="card-tags">
                        <span className="tag">{tarefa.projeto}</span>
                      </div>
                      {tarefa.instrucoes && <div className="card-instructions">{tarefa.instrucoes}</div>}
                      <div className="card-actions">
                        <button
                          className="card-action-btn"
                          onClick={() => {
                            setInstrucoesTarefaId(tarefa.id);
                            setInstrucoesTitulo(tarefa.titulo);
                            setInstrucoesAtuais(tarefa.instrucoes || '');
                            setInstrucoesNovas(tarefa.instrucoes || '');
                            setInstrucoesModalOpen(true);
                          }}
                        >
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                            <polyline points="14 2 14 8 20 8" />
                            <line x1="16" y1="13" x2="8" y2="13" />
                            <line x1="16" y1="17" x2="8" y2="17" />
                          </svg>
                          Instruções
                        </button>
                        {temEscrita && (
                          <button
                            className="card-action-btn delete-btn"
                            onClick={() => handleExcluirTarefa(tarefa.id, tarefa.titulo)}
                            title="Excluir tarefa"
                          >
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style={{ width: 14, height: 14 }}>
                              <polyline points="3 6 5 6 21 6" />
                              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                            </svg>
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>

                {/* Coluna Em Andamento */}
                <div
                  className="kanban-column col-progress"
                  onDragOver={handleDragOver}
                  onDragLeave={handleDragLeave}
                  onDrop={(e) => handleDrop(e, 'Em Andamento')}
                >
                  <div className="column-header">
                    <span className="column-header-left">
                      <span className="column-dot" />
                      <span>Em Andamento</span>
                    </span>
                    <span className="column-count">{tarefasProgress.length}</span>
                  </div>
                  {tarefasProgress.map((tarefa) => (
                    <div
                      key={tarefa.id}
                      className="kanban-card"
                      data-card-id={tarefa.id}
                      draggable={temEscrita}
                      onDragStart={(e) => handleDragStart(e, tarefa.id)}
                      onDragEnd={handleDragEnd}
                    >
                      <div className="card-title">{tarefa.titulo}</div>
                      <div className="card-meta">
                        <span>{tarefa.prioridade} prioridade</span>
                        {tarefa.responsavel && (
                          <>
                            <span>&middot;</span>
                            <span>Resp: {tarefa.responsavel.split(' ')[0]}</span>
                          </>
                        )}
                      </div>
                      <div className="card-tags">
                        <span className="tag">{tarefa.projeto}</span>
                      </div>
                      {tarefa.instrucoes && <div className="card-instructions">{tarefa.instrucoes}</div>}
                      <div className="card-actions">
                        <button
                          className="card-action-btn"
                          onClick={() => {
                            setInstrucoesTarefaId(tarefa.id);
                            setInstrucoesTitulo(tarefa.titulo);
                            setInstrucoesAtuais(tarefa.instrucoes || '');
                            setInstrucoesNovas(tarefa.instrucoes || '');
                            setInstrucoesModalOpen(true);
                          }}
                        >
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                            <polyline points="14 2 14 8 20 8" />
                            <line x1="16" y1="13" x2="8" y2="13" />
                            <line x1="16" y1="17" x2="8" y2="17" />
                          </svg>
                          Instruções
                        </button>
                        {temEscrita && (
                          <button
                            className="card-action-btn delete-btn"
                            onClick={() => handleExcluirTarefa(tarefa.id, tarefa.titulo)}
                            title="Excluir tarefa"
                          >
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style={{ width: 14, height: 14 }}>
                              <polyline points="3 6 5 6 21 6" />
                              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                            </svg>
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>

                {/* Coluna Concluído */}
                <div
                  className="kanban-column col-done"
                  onDragOver={handleDragOver}
                  onDragLeave={handleDragLeave}
                  onDrop={(e) => handleDrop(e, 'Concluído')}
                >
                  <div className="column-header">
                    <span className="column-header-left">
                      <span className="column-dot" />
                      <span>Concluído</span>
                    </span>
                    <span className="column-count">{tarefasDone.length}</span>
                  </div>
                  {tarefasDone.map((tarefa) => (
                    <div
                      key={tarefa.id}
                      className="kanban-card"
                      data-card-id={tarefa.id}
                      draggable={temEscrita}
                      onDragStart={(e) => handleDragStart(e, tarefa.id)}
                      onDragEnd={handleDragEnd}
                    >
                      <div className="card-title">{tarefa.titulo}</div>
                      <div className="card-meta">
                        {tarefa.prazo ? (
                          <span>Prazo: {new Date(tarefa.prazo + 'T00:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' })}</span>
                        ) : (
                          <span>Concluído</span>
                        )}
                      </div>
                      <div className="card-tags">
                        <span className="tag">{tarefa.projeto}</span>
                      </div>
                      {tarefa.instrucoes && <div className="card-instructions">{tarefa.instrucoes}</div>}
                      <div className="card-actions">
                        <button
                          className="card-action-btn"
                          onClick={() => {
                            setInstrucoesTarefaId(tarefa.id);
                            setInstrucoesTitulo(tarefa.titulo);
                            setInstrucoesAtuais(tarefa.instrucoes || '');
                            setInstrucoesNovas(tarefa.instrucoes || '');
                            setInstrucoesModalOpen(true);
                          }}
                        >
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                            <polyline points="14 2 14 8 20 8" />
                            <line x1="16" y1="13" x2="8" y2="13" />
                            <line x1="16" y1="17" x2="8" y2="17" />
                          </svg>
                          Instruções
                        </button>
                        {temEscrita && (
                          <button
                            className="card-action-btn delete-btn"
                            onClick={() => handleExcluirTarefa(tarefa.id, tarefa.titulo)}
                            title="Excluir tarefa"
                          >
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style={{ width: 14, height: 14 }}>
                              <polyline points="3 6 5 6 21 6" />
                              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                            </svg>
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Modal: Novo Projeto */}
      {projetoModalOpen && (
        <div className="modal-overlay open" onClick={(e) => { if (e.target === e.currentTarget) setProjetoModalOpen(false); }}>
          <div className="modal">
            <div className="modal-header">
              <h2>Novo projeto</h2>
              <button className="modal-close" onClick={() => setProjetoModalOpen(false)}>&times;</button>
            </div>
            <form onSubmit={handleCriarProjeto}>
              <div className="modal-body">
                <div className="form-group">
                  <div className="field">
                    <label>Nome do projeto</label>
                    <input
                      className="input"
                      type="text"
                      placeholder="Ex: Plataforma Omnichannel"
                      value={novoProjNome}
                      onChange={(e) => setNovoProjNome(e.target.value)}
                      required
                    />
                  </div>
                  <div className="form-row">
                    <div className="field">
                      <label>Cliente</label>
                      <select
                        className="select"
                        value={novoProjClienteId}
                        onChange={(e) => setNovoProjClienteId(e.target.value)}
                      >
                        <option value="">Selecione (Opcional)</option>
                        {clientes.map((c) => (
                          <option key={c.id} value={c.id}>
                            {c.empresa} ({c.nome_contato})
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label>Orçamento</label>
                      <input
                        className="input"
                        type="text"
                        placeholder="R$ 0,00"
                        value={novoProjOrcamento}
                        onChange={(e) => setNovoProjOrcamento(e.target.value)}
                      />
                    </div>
                  </div>
                  <div className="form-row">
                    <div className="field">
                      <label>Prazo de entrega</label>
                      <input
                        className="input"
                        type="date"
                        value={novoProjPrazo}
                        onChange={(e) => setNovoProjPrazo(e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setProjetoModalOpen(false)}>Cancelar</button>
                <button type="submit" className="btn btn-primary">Criar Projeto</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Nova Tarefa */}
      {tarefaModalOpen && (
        <div className="modal-overlay open" onClick={(e) => { if (e.target === e.currentTarget) setTarefaModalOpen(false); }}>
          <div className="modal">
            <div className="modal-header">
              <h2>Nova tarefa</h2>
              <button className="modal-close" onClick={() => setTarefaModalOpen(false)}>&times;</button>
            </div>
            <form onSubmit={handleCriarTarefa}>
              <div className="modal-body">
                <div className="form-group">
                  <div className="field">
                    <label>Título da tarefa</label>
                    <input
                      className="input"
                      type="text"
                      placeholder="Ex: Implementar API de integração"
                      value={novaTarefaTitulo}
                      onChange={(e) => setNovaTarefaTitulo(e.target.value)}
                      required
                    />
                  </div>
                  <div className="form-row">
                    <div className="field">
                      <label>Projeto</label>
                      <select
                        className="select"
                        value={novaTarefaProjetoId}
                        onChange={(e) => setNovaTarefaProjetoId(e.target.value)}
                        required
                      >
                        <option value="">Selecione o projeto</option>
                        {projetos.map((p) => (
                          <option key={p.id} value={p.id}>
                            {p.nome}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label>Responsável</label>
                      <select
                        className="select"
                        value={novaTarefaResponsavelId}
                        onChange={(e) => setNovaTarefaResponsavelId(e.target.value)}
                      >
                        <option value="">Selecione o responsável (Opcional)</option>
                        {responsaveis.map((r) => (
                          <option key={r.id} value={r.id}>
                            {r.nome}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                  <div className="form-row">
                    <div className="field">
                      <label>Prioridade</label>
                      <select
                        className="select"
                        value={novaTarefaPrioridade}
                        onChange={(e) => setNovaTarefaPrioridade(e.target.value as any)}
                      >
                        <option value="Alta">Alta</option>
                        <option value="Média">Média</option>
                        <option value="Baixa">Baixa</option>
                      </select>
                    </div>
                    <div className="field">
                      <label>Prazo</label>
                      <input
                        className="input"
                        type="date"
                        value={novaTarefaPrazo}
                        onChange={(e) => setNovaTarefaPrazo(e.target.value)}
                      />
                    </div>
                  </div>
                  <div className="field">
                    <label>Instruções / Observações</label>
                    <textarea
                      className="textarea"
                      placeholder="Passos ou escopo a seguir..."
                      value={novaTarefaInstrucoes}
                      onChange={(e) => setNovaTarefaInstrucoes(e.target.value)}
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setTarefaModalOpen(false)}>Cancelar</button>
                <button type="submit" className="btn btn-primary">Adicionar</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Instruções da Tarefa */}
      {instrucoesModalOpen && (
        <div className="modal-overlay open" onClick={(e) => { if (e.target === e.currentTarget) setInstrucoesModalOpen(false); }}>
          <div className="modal">
            <div className="modal-header">
              <h2>Instruções</h2>
              <button className="modal-close" onClick={() => setInstrucoesModalOpen(false)}>&times;</button>
            </div>
            <form onSubmit={handleSalvarInstrucao}>
              <div className="modal-body">
                <div style={{ marginBottom: 16 }}>
                  <strong style={{ fontSize: 14, color: 'var(--fg)' }}>{instrucoesTitulo}</strong>
                </div>
                {instrucoesAtuais && (
                  <div style={{ marginBottom: 16 }}>
                    <div style={{ fontSize: 11, textTransform: 'uppercase', color: 'var(--muted)', marginBottom: 4 }}>Instruções atuais</div>
                    <div className="card-instructions" style={{ margin: 0 }}>{instrucoesAtuais}</div>
                  </div>
                )}
                <div className="field">
                  <label>{temEscrita ? 'Escrever novas instruções' : 'Visualizar instruções'}</label>
                  <textarea
                    className="textarea"
                    placeholder="Descreva os passos e observações técnicas..."
                    value={instrucoesNovas}
                    onChange={(e) => setInstrucoesNovas(e.target.value)}
                    disabled={!temEscrita}
                    style={{ minHeight: 120 }}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setInstrucoesModalOpen(false)}>
                  {temEscrita ? 'Cancelar' : 'Fechar'}
                </button>
                {temEscrita && <button type="submit" className="btn btn-primary">Salvar</button>}
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
