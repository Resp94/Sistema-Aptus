import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export function ProtectedRoute() {
  const { carregando, perfil } = useAuth()

  if (carregando) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)', color: 'var(--muted)', fontFamily: 'var(--font-body)' }}>
        Carregando…
      </div>
    )
  }

  if (!perfil) {
    return <Navigate to="/login" replace />
  }

  return <Outlet />
}
