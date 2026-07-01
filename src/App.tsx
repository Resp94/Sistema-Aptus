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
import FluxoCaixaPage from './pages/FluxoCaixaPage'
import ContasPagarPage from './pages/ContasPagarPage'
import ContasReceberPage from './pages/ContasReceberPage'
import CobrancasPage from './pages/CobrancasPage'
import PropostasPage from './pages/PropostasPage'
import ContratosPage from './pages/ContratosPage'
import EquipePage from './pages/EquipePage'
import RelatoriosPage from './pages/RelatoriosPage'
import ConfiguracoesPage from './pages/ConfiguracoesPage'
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
            <Route
              path="/fluxo-caixa"
              element={
                <RequirePermissao modulo="fluxo-caixa">
                  <FluxoCaixaPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/contas-pagar"
              element={
                <RequirePermissao modulo="contas-pagar">
                  <ContasPagarPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/contas-receber"
              element={
                <RequirePermissao modulo="contas-receber">
                  <ContasReceberPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/cobrancas"
              element={
                <RequirePermissao modulo="cobrancas">
                  <CobrancasPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/propostas"
              element={
                <RequirePermissao modulo="propostas">
                  <PropostasPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/contratos"
              element={
                <RequirePermissao modulo="contratos">
                  <ContratosPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/equipe"
              element={
                <RequirePermissao modulo="equipe">
                  <EquipePage />
                </RequirePermissao>
              }
            />
            <Route
              path="/relatorios"
              element={
                <RequirePermissao modulo="relatorios">
                  <RelatoriosPage />
                </RequirePermissao>
              }
            />
            <Route
              path="/configuracoes"
              element={
                <RequirePermissao modulo="configuracoes">
                  <ConfiguracoesPage />
                </RequirePermissao>
              }
            />
            {ITENS_NAV.filter(
              (i) =>
                i.modulo !== 'dashboard' &&
                i.modulo !== 'projetos' &&
                i.modulo !== 'clientes' &&
                i.modulo !== 'fluxo-caixa' &&
                i.modulo !== 'contas-pagar' &&
                i.modulo !== 'contas-receber' &&
                i.modulo !== 'cobrancas' &&
                i.modulo !== 'propostas' &&
                i.modulo !== 'contratos' &&
                i.modulo !== 'equipe' &&
                i.modulo !== 'relatorios' &&
                i.modulo !== 'configuracoes'
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

