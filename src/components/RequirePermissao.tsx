import { Navigate } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { podeLer } from '../lib/permissoes'
import { rotaInicialPorPerfil } from '../lib/usuario'

/**
 * Guard de rota por módulo. Deve ser usado dentro de ProtectedRoute, que já
 * garante sessão e trata o estado "carregando". Aqui validamos o RBAC: se o
 * perfil não tem leitura no módulo da rota, redireciona para a landing inicial
 * do perfil (que é sempre um módulo legível, evitando loop de redirect).
 */
export function RequirePermissao({
  modulo,
  children,
}: {
  modulo: string
  children: ReactNode
}) {
  const { carregando, perfil, permissoes } = useAuth()

  if (carregando) return null
  if (!perfil) return <Navigate to="/login" replace />

  if (!podeLer(permissoes, modulo)) {
    return <Navigate to={rotaInicialPorPerfil(perfil.perfil_acesso)} replace />
  }

  return <>{children}</>
}
