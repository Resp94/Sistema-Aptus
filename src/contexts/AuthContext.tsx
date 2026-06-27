import { createContext, useContext, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { supabase } from '../services/supabase'
import { authService } from '../services/auth.service'
import type { PerfilUsuario, PermissaoModulo } from '../types/auth'

interface AuthState {
  carregando: boolean
  perfil: PerfilUsuario | null
  permissoes: PermissaoModulo[]
  sair: () => Promise<void>
}

const AuthContext = createContext<AuthState | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [carregando, setCarregando] = useState(true)
  const [perfil, setPerfil] = useState<PerfilUsuario | null>(null)
  const [permissoes, setPermissoes] = useState<PermissaoModulo[]>([])

  useEffect(() => {
    let ativo = true

    async function carregar() {
      const { data } = await supabase.auth.getSession()
      if (!data.session) {
        if (ativo) {
          setPerfil(null)
          setPermissoes([])
          setCarregando(false)
        }
        return
      }
      try {
        const p = await authService.getPerfilUsuario()
        const perms = await authService.getPermissoesUsuario()
        if (ativo) {
          setPerfil(p)
          setPermissoes(perms)
        }
      } catch {
        // perfil ausente/inativo: getPerfilUsuario já fez signOut
        if (ativo) {
          setPerfil(null)
          setPermissoes([])
        }
      } finally {
        if (ativo) setCarregando(false)
      }
    }

    carregar()

    const { data: sub } = supabase.auth.onAuthStateChange((_evento, session) => {
      if (!session) {
        setPerfil(null)
        setPermissoes([])
      }
    })

    return () => {
      ativo = false
      sub.subscription.unsubscribe()
    }
  }, [])

  async function sair() {
    await authService.signOut()
    setPerfil(null)
    setPermissoes([])
  }

  return (
    <AuthContext.Provider value={{ carregando, perfil, permissoes, sair }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth deve ser usado dentro de <AuthProvider>')
  return ctx
}
