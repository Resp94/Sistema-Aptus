import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { saudacaoPorHora } from '../lib/usuario'
import './DashboardPage.css'

export default function DashboardPage() {
  const navigate = useNavigate()
  const { perfil } = useAuth()
  const [notifAberto, setNotifAberto] = useState(false)
  const primeiroNome = perfil?.nome.split(' ')[0] ?? ''

  useEffect(() => {
    function fecharEsc(e: KeyboardEvent) {
      if (e.key === 'Escape') setNotifAberto(false)
    }
    document.addEventListener('keydown', fecharEsc)
    return () => document.removeEventListener('keydown', fecharEsc)
  }, [])

  const headerActions = (
    <>
      <span style={{ fontFamily: 'var(--font-ui)', fontSize: 12, color: 'var(--muted)' }}>Período: Junho 2026</span>
      <button className="btn-icon" onClick={() => setNotifAberto(true)} title="Notificações">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0"></path></svg>
      </button>
    </>
  )

  return (
    <AppShell titulo="Dashboard" headerActions={headerActions}>
      <h2 className="greeting">{saudacaoPorHora(new Date().getHours())}, {primeiroNome}</h2>
      <p className="greeting-sub">Visão geral do mês: saldo, contas e projetos em um só lugar</p>

      <div className="metric-grid" data-od-id="metrics">
        <div className="metric-card" data-clickable="" onClick={() => navigate('/fluxo-caixa')}>
          <div className="metric-icon orange">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="2" y="4" width="20" height="16" rx="2"></rect><line x1="2" y1="10" x2="22" y2="10"></line></svg>
          </div>
          <div className="metric-label">Saldo em conta</div>
          <div className="metric-value">R$ 347.200</div>
          <div className="metric-change up">+12,4% vs. mês anterior</div>
        </div>
        <div className="metric-card" data-clickable="" onClick={() => navigate('/contas-receber')}>
          <div className="metric-icon green">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
          </div>
          <div className="metric-label">Contas a receber</div>
          <div className="metric-value">R$ 89.450</div>
          <div className="metric-change down">3 cobranças pendentes</div>
        </div>
        <div className="metric-card" data-clickable="" onClick={() => navigate('/contas-pagar')}>
          <div className="metric-icon red">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path></svg>
          </div>
          <div className="metric-label">Contas a pagar</div>
          <div className="metric-value">R$ 42.800</div>
          <div className="metric-sub">8 faturas com vencimento aberto</div>
        </div>
        <div className="metric-card" data-clickable="" onClick={() => navigate('/clientes')}>
          <div className="metric-icon yellow">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
          </div>
          <div className="metric-label">Clientes ativos</div>
          <div className="metric-value">48</div>
          <div className="metric-sub">6 novos este mês</div>
        </div>
      </div>

      <div className="dashboard-grid" data-od-id="dashboard-grid">
        <div className="card">
          <div className="card-header">
            <h3>Fluxo de Caixa</h3>
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/fluxo-caixa')}>Abrir fluxo</button>
          </div>
          <div className="card-body">
            <div className="chart-bar" style={{ paddingTop: 'var(--space-6)' }}>
              <div className="bar" style={{ height: '60%' }}><span className="bar-value">R$42k</span><span className="bar-label">Jan</span></div>
              <div className="bar" style={{ height: '75%' }}><span className="bar-value">R$53k</span><span className="bar-label">Fev</span></div>
              <div className="bar" style={{ height: '55%' }}><span className="bar-value">R$39k</span><span className="bar-label">Mar</span></div>
              <div className="bar" style={{ height: '85%' }}><span className="bar-value">R$61k</span><span className="bar-label">Abr</span></div>
              <div className="bar" style={{ height: '70%' }}><span className="bar-value">R$49k</span><span className="bar-label">Mai</span></div>
              <div className="bar" style={{ height: '95%', background: 'var(--accent)' }}><span className="bar-value" style={{ color: 'var(--fg)' }}>R$68k</span><span className="bar-label">Jun</span></div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3>Últimos Lançamentos</h3>
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/fluxo-caixa')}>Ver lançamentos</button>
          </div>
          <div className="card-body compact">
            <div className="recent-list">
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Pagamento recebido da Inovatec</span><span className="ri-meta">Hoje, 14:23</span></div>
                <span className="ri-value positive">+R$ 12.400</span>
              </div>
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Nota fiscal da DataFlow</span><span className="ri-meta">Ontem, 09:15</span></div>
                <span className="ri-value negative">-R$ 3.800</span>
              </div>
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Assinatura AWS</span><span className="ri-meta">25 jun, 08:00</span></div>
                <span className="ri-value negative">-R$ 2.450</span>
              </div>
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Pagamento recebido da Nexum AI</span><span className="ri-meta">24 jun, 16:40</span></div>
                <span className="ri-value positive">+R$ 8.900</span>
              </div>
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">GitHub Copilot</span><span className="ri-meta">23 jun, 10:30</span></div>
                <span className="ri-value negative">-R$ 1.200</span>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3>Contas a pagar: próximos 7 dias</h3>
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/contas-pagar')}>Ver vencimentos</button>
          </div>
          <div className="card-body compact">
            <div className="recent-list">
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Aluguel da sede</span><span className="ri-meta">Vence 28 jun</span></div>
                <span className="ri-value negative">-R$ 8.500</span>
              </div>
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Folha de pagamento</span><span className="ri-meta">Vence 30 jun</span></div>
                <span className="ri-value negative">-R$ 38.000</span>
              </div>
              <div className="recent-item" data-clickable="">
                <div className="ri-left"><span className="ri-title">Servidor GPU para treinamento</span><span className="ri-meta">Vence 01 jul</span></div>
                <span className="ri-value negative">-R$ 4.800</span>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3>Composição de receita</h3>
          </div>
          <div className="card-body">
            <div className="chart-pie">
              <div className="pie-visual" style={{ background: 'conic-gradient(var(--accent) 0% 45%, var(--success) 45% 65%, var(--warn) 65% 82%, var(--muted) 82% 92%, var(--border) 92% 100%)' }}></div>
              <div className="pie-legend">
                <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--accent)' }}></span> Projetos (45%)</div>
                <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--success)' }}></span> Consultoria (20%)</div>
                <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--warn)' }}></span> Suporte (17%)</div>
                <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--muted)' }}></span> Treinamento (10%)</div>
                <div className="legend-item"><span className="legend-dot" style={{ background: 'var(--border)' }}></span> Outros (8%)</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {notifAberto && (
        <div className="modal-overlay open" onClick={(e) => { if (e.target === e.currentTarget) setNotifAberto(false) }}>
          <div className="modal" style={{ maxWidth: 400 }}>
            <div className="modal-header">
              <h2>Notificações</h2>
              <button className="modal-close" onClick={() => setNotifAberto(false)}>×</button>
            </div>
            <div className="modal-body compact">
              <div className="recent-list">
                <div className="recent-item" data-clickable=""><div className="ri-left"><span className="ri-title">Boleto vence hoje</span><span className="ri-meta">Aluguel da sede: R$ 8.500</span></div></div>
                <div className="recent-item" data-clickable=""><div className="ri-left"><span className="ri-title">Pagamento confirmado</span><span className="ri-meta">Inovatec: R$ 12.400</span></div></div>
                <div className="recent-item" data-clickable=""><div className="ri-left"><span className="ri-title">Novo cliente cadastrado</span><span className="ri-meta">TechSolve Ltda</span></div></div>
              </div>
            </div>
          </div>
        </div>
      )}
    </AppShell>
  )
}
