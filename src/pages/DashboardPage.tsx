import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppShell } from '../components/AppShell';
import { useAuth } from '../contexts/AuthContext';
import { saudacaoPorHora } from '../lib/usuario';
import { dashboardService } from '../services/dashboard.service';
import type {
  MetricasDashboard,
  FluxoCaixaMes,
  LancamentoResumo,
  ContaPagarProxima,
  ComposicaoReceita,
} from '../types/dashboard';
import './DashboardPage.css';

export default function DashboardPage() {
  const navigate = useNavigate();
  const { perfil } = useAuth();
  const primeiroNome = perfil?.nome.split(' ')[0] ?? '';

  // Estados de dados
  const [metricas, setMetricas] = useState<MetricasDashboard | null>(null);
  const [fluxoCaixa, setFluxoCaixa] = useState<FluxoCaixaMes[]>([]);
  const [ultimos, setUltimos] = useState<LancamentoResumo[]>([]);
  const [contasPagar, setContasPagar] = useState<ContaPagarProxima[]>([]);
  const [composicao, setComposicao] = useState<ComposicaoReceita[]>([]);

  // Estados de controle
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Busca dados agregados
  const fetchDados = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [metricasData, fluxoData, ultimosData, contasData, composicaoData] = await Promise.all([
        dashboardService.obterMetricasDashboard(),
        dashboardService.obterFluxoCaixaMensal(6),
        dashboardService.listarUltimosLancamentos(5),
        dashboardService.listarContasPagarProximas(7),
        dashboardService.obterComposicaoReceita(),
      ]);

      setMetricas(metricasData);
      setFluxoCaixa(fluxoData);
      setUltimos(ultimosData);
      setContasPagar(contasData);
      setComposicao(composicaoData);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'Erro ao carregar dados do painel financeiro.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDados();
  }, [fetchDados]);

  // Formatação de Valores
  const formatMoney = (val: number) => {
    return Number(val).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  };

  // Helper para o gráfico de fluxo de caixa (barras)
  const maxFluxo = fluxoCaixa.length > 0 ? Math.max(...fluxoCaixa.map((f) => Math.abs(f.total))) : 1;

  // Helper para o conic-gradient da composição de receitas
  let acumulador = 0;
  const cores = ['var(--accent)', 'var(--success)', 'var(--warn)', 'var(--muted)', 'var(--border)'];
  const conicGradientStyle = composicao
    .map((item, index) => {
      const cor = cores[index % cores.length];
      const inicio = acumulador;
      acumulador += Number(item.percentual);
      return `${cor} ${inicio}% ${acumulador}%`;
    })
    .join(', ');

  const visualStyle = conicGradientStyle
    ? { background: `conic-gradient(${conicGradientStyle})` }
    : { background: 'var(--border-soft)' };

  return (
    <AppShell titulo="Dashboard">
      <h2 className="greeting">
        {saudacaoPorHora(new Date().getHours())}, {primeiroNome}
      </h2>
      <p className="greeting-sub">Visão geral do mês: saldo, contas e projetos em um só lugar</p>

      {/* Estado de Erro */}
      {error && (
        <div className="error-state" style={{ marginBottom: 24, padding: 20 }}>
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
          <div className="metric-grid">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="metric-card">
                <div className="skeleton-bar" style={{ height: 14, width: '60%', marginBottom: 12 }} />
                <div className="skeleton-bar" style={{ height: 28, width: '45%', marginBottom: 8 }} />
                <div className="skeleton-bar" style={{ height: 12, width: '70%' }} />
              </div>
            ))}
          </div>
          <div className="dashboard-grid" style={{ marginTop: 24 }}>
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="card">
                <div className="card-header">
                  <div className="skeleton-bar" style={{ height: 18, width: '40%' }} />
                </div>
                <div className="card-body">
                  <div className="skeleton-bar" style={{ height: 80, width: '100%' }} />
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      {/* Exibição Principal */}
      {!loading && !error && (
        <>
          {/* Grid de Métricas Financeiras */}
          <div className="metric-grid" data-od-id="metrics">
            <div className="metric-card" data-clickable="" onClick={() => navigate('/fluxo-caixa')}>
              <div className="metric-icon orange">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                  <rect x="2" y="4" width="20" height="16" rx="2" />
                  <line x1="2" y1="10" x2="22" y2="10" />
                </svg>
              </div>
              <div className="metric-label">Saldo em conta</div>
              <div className="metric-value">{formatMoney(metricas?.saldo_em_conta ?? 0)}</div>
              <div className="metric-change up">Dados atualizados do banco</div>
            </div>

            <div className="metric-card" data-clickable="" onClick={() => navigate('/contas-receber')}>
              <div className="metric-icon green">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                  <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
                </svg>
              </div>
              <div className="metric-label">Contas a receber</div>
              <div className="metric-value">{formatMoney(metricas?.contas_receber ?? 0)}</div>
              <div className="metric-change down">{metricas?.cobrancas_pendentes ?? 0} cobranças pendentes</div>
            </div>

            <div className="metric-card" data-clickable="" onClick={() => navigate('/contas-pagar')}>
              <div className="metric-icon red">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                  <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
                </svg>
              </div>
              <div className="metric-label">Contas a pagar</div>
              <div className="metric-value">{formatMoney(metricas?.contas_pagar ?? 0)}</div>
              <div className="metric-sub">{metricas?.faturas_abertas ?? 0} faturas abertas</div>
            </div>

            <div className="metric-card" data-clickable="" onClick={() => navigate('/clientes')}>
              <div className="metric-icon yellow">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
              </div>
              <div className="metric-label">Clientes ativos</div>
              <div className="metric-value">{metricas?.clientes_ativos ?? 0}</div>
              <div className="metric-sub">{metricas?.clientes_novos_mes ?? 0} novos este mês</div>
            </div>
          </div>

          {/* Seção de Gráficos e Tabelas do Dashboard */}
          <div className="dashboard-grid" data-od-id="dashboard-grid">
            {/* Gráfico Fluxo de Caixa */}
            <div className="card">
              <div className="card-header">
                <h3>Fluxo de Caixa</h3>
                <button className="btn btn-ghost btn-sm" onClick={() => navigate('/fluxo-caixa')}>
                  Abrir fluxo
                </button>
              </div>
              <div className="card-body">
                {fluxoCaixa.length === 0 ? (
                  <div className="empty-state">
                    <p className="empty-desc">Sem dados no período.</p>
                  </div>
                ) : (
                  <div className="chart-bar" style={{ paddingTop: 'var(--space-6)' }}>
                    {fluxoCaixa.map((item) => {
                      const percentage = maxFluxo > 0 ? (Math.abs(item.total) / maxFluxo) * 85 : 0; // maximo 85% para não estourar
                      const isPositive = item.total >= 0;

                      return (
                        <div key={`${item.mes}-${item.ano}`} className="bar" style={{ height: `${percentage}%` }}>
                          <span className="bar-value">
                            {isPositive ? '' : '-'}R$ {Math.round(Math.abs(item.total) / 1000)}k
                          </span>
                          <span className="bar-label">{item.mes}</span>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Últimos Lançamentos */}
            <div className="card">
              <div className="card-header">
                <h3>Últimos Lançamentos</h3>
                <button className="btn btn-ghost btn-sm" onClick={() => navigate('/fluxo-caixa')}>
                  Ver lançamentos
                </button>
              </div>
              <div className="card-body compact">
                {ultimos.length === 0 ? (
                  <div className="empty-state">
                    <p className="empty-desc">Nenhum lançamento recente.</p>
                  </div>
                ) : (
                  <div className="recent-list">
                    {ultimos.map((lanc) => {
                      const isReceita = lanc.tipo === 'receita';
                      return (
                        <div key={lanc.id} className="recent-item" data-clickable="" onClick={() => navigate('/fluxo-caixa')}>
                          <div className="ri-left">
                            <span className="ri-title">{lanc.descricao}</span>
                            <span className="ri-meta">
                              {new Date(lanc.data + 'T00:00:00').toLocaleDateString('pt-BR', {
                                day: '2-digit',
                                month: 'short',
                              })}
                            </span>
                          </div>
                          <span className={`ri-value ${isReceita ? 'positive' : 'negative'}`}>
                            {isReceita ? '+' : '-'}
                            {formatMoney(lanc.valor)}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Contas a Pagar: 7 dias */}
            <div className="card">
              <div className="card-header">
                <h3>Contas a pagar: próximos 7 dias</h3>
                <button className="btn btn-ghost btn-sm" onClick={() => navigate('/contas-pagar')}>
                  Ver vencimentos
                </button>
              </div>
              <div className="card-body compact">
                {contasPagar.length === 0 ? (
                  <div className="empty-state">
                    <p className="empty-desc">Sem contas a pagar nos próximos 7 dias.</p>
                  </div>
                ) : (
                  <div className="recent-list">
                    {contasPagar.map((c) => (
                      <div key={c.id} className="recent-item" data-clickable="" onClick={() => navigate('/contas-pagar')}>
                        <div className="ri-left">
                          <span className="ri-title">{c.descricao}</span>
                          <span className="ri-meta">
                            Vence{' '}
                            {new Date(c.data_vencimento + 'T00:00:00').toLocaleDateString('pt-BR', {
                              day: '2-digit',
                              month: 'short',
                            })}
                          </span>
                        </div>
                        <span className="ri-value negative">-{formatMoney(c.valor)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Composição de Receita (Pizza) */}
            <div className="card">
              <div className="card-header">
                <h3>Composição de receita</h3>
              </div>
              <div className="card-body">
                {composicao.length === 0 ? (
                  <div className="empty-state">
                    <p className="empty-desc">Sem dados de receita cadastrados.</p>
                  </div>
                ) : (
                  <div className="chart-pie">
                    <div className="pie-visual" style={visualStyle} />
                    <div className="pie-legend">
                      {composicao.map((item, index) => (
                        <div key={item.categoria} className="legend-item">
                          <span className="legend-dot" style={{ background: cores[index % cores.length] }} />
                          {item.categoria} ({Number(item.percentual)}%)
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </>
      )}
    </AppShell>
  );
}
