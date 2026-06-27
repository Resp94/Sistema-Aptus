import { useState, useEffect } from 'react'
import type { ReactNode } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { ITENS_NAV, filtrarNavPorPermissoes } from '../lib/navegacao'
import type { SecaoNav } from '../lib/navegacao'
import { obterIniciais } from '../lib/usuario'
import { NAV_ICONS } from './icons'

interface AppShellProps {
  titulo: string
  headerActions?: ReactNode
  children: ReactNode
}

const SECOES: SecaoNav[] = ['Principal', 'Gestão']

export function AppShell({ titulo, headerActions, children }: AppShellProps) {
  const { perfil, permissoes, sair } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [colapsada, setColapsada] = useState(
    () => localStorage.getItem('aptus-sidebar') === 'collapsed',
  )
  const [popoverAberto, setPopoverAberto] = useState(false)

  const itens = filtrarNavPorPermissoes(ITENS_NAV, permissoes)

  useEffect(() => {
    const fechar = () => setPopoverAberto(false)
    document.addEventListener('click', fechar)
    return () => document.removeEventListener('click', fechar)
  }, [])

  function alternarSidebar() {
    setColapsada((c) => {
      const nova = !c
      localStorage.setItem('aptus-sidebar', nova ? 'collapsed' : 'expanded')
      return nova
    })
  }

  function alternarTema() {
    const html = document.documentElement
    const atual = html.getAttribute('data-theme')
    const novo = atual === 'dark' ? 'light' : 'dark'
    html.setAttribute('data-theme', novo)
    localStorage.setItem('aptus-theme', novo)
  }

  async function aoSair() {
    await sair()
    navigate('/login', { replace: true })
  }

  return (
    <div className={`app-shell${colapsada ? ' sidebar-collapsed' : ''}`}>
      <aside className="app-sidebar">
        <div className="logo"><span className="logo-dot"></span><span>Aptus Flow</span></div>
        <button className="sidebar-toggle" onClick={alternarSidebar} aria-label="Recolher sidebar">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
        </button>
        <div className="nav-scroll">
          {SECOES.map((secao) => {
            const doSecao = itens.filter((i) => i.secao === secao)
            if (doSecao.length === 0) return null
            return (
              <div key={secao}>
                <div className="nav-section"><span>{secao}</span></div>
                <nav>
                  {doSecao.map((item) => (
                    <Link
                      key={item.rota}
                      to={item.rota}
                      className={location.pathname === item.rota ? 'active' : undefined}
                      data-tooltip={item.rotulo}
                    >
                      {NAV_ICONS[item.icone]}
                      <span className="nav-label">{item.rotulo}</span>
                    </Link>
                  ))}
                </nav>
              </div>
            )
          })}
        </div>
        <div className="user-section">
          <div className="user-info" onClick={(e) => { e.stopPropagation(); setPopoverAberto((v) => !v) }}>
            <div className="avatar">{perfil ? obterIniciais(perfil.nome) : ''}</div>
            <div><div className="user-name">{perfil?.nome}</div><div className="user-role">{perfil?.perfil_acesso}</div></div>
            <svg className="user-chevron" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="6 9 12 15 18 9"/></svg>
          </div>
          <div className={`user-popover${popoverAberto ? ' open' : ''}`} onClick={(e) => e.stopPropagation()}>
            <button className="user-popover-item" onClick={alternarTema}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"></path></svg>
              Alternar tema
            </button>
            <button className="user-popover-item" onClick={aoSair}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"></path></svg>
              Sair
            </button>
          </div>
        </div>
      </aside>

      <header className="app-header">
        <div className="page-title">{titulo}</div>
        <div className="header-actions">{headerActions}</div>
      </header>

      <main className="app-content">{children}</main>
    </div>
  )
}
