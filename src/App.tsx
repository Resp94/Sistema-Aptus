import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import { ProtectedRoute } from './components/ProtectedRoute'
import { RequirePermissao } from './components/RequirePermissao'
import Login from './pages/Login'
import ResetPassword from './pages/ResetPassword'
import ModuloNaoMigrado from './pages/ModuloNaoMigrado'
import DashboardPage from './pages/DashboardPage'
import ProjetosPage from './pages/ProjetosPage'
import ClientesPage from './pages/ClientesPage'
import { ITENS_NAV } from './lib/navegacao'

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/reset-password" element={<ResetPassword />} />
          <Route element={<ProtectedRoute />}>
            <Route
              path="/dashboard"
              element={
                <RequirePermissao modulo="dashboard">
                  <DashboardPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/projetos"
              element={
                <RequirePermissao modulo="projetos">
                  <ProjetosPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/clientes"
              element={
                <RequirePermissao modulo="clientes">
                  <ClientesPage />
                </RequirePermissao>
              }
            />
            {ITENS_NAV.filter(
              (i) =>
                i.modulo !== 'dashboard' &&
                i.modulo !== 'projetos' &&
                i.modulo !== 'clientes'
            ).map((i) => (
              <Route
                key={i.rota}
                path={i.rota}
                element={
                  <RequirePermissao modulo={i.modulo}>
                    <ModuloNaoMigrado />
                  </RequirePermissao>
                }
              />
            ))}
          </Route>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App

