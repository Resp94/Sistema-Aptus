import { createContext, useContext, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { supabase } from '../services/supabase'
import { authService } from '../services/auth.service'
import type { PerfilUsuario, PermissaoModulo } from '../types/auth'

interface AuthState {
  carregando: boolean
  perfil: PerfilUsuario | null
  permissoes: PermissaoModulo[]
  capacidades: string[]
  sair: () => Promise<void>
}

const AuthContext = createContext<AuthState | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [carregando, setCarregando] = useState(true)
  const [perfil, setPerfil] = useState<PerfilUsuario | null>(null)
  const [permissoes, setPermissoes] = useState<PermissaoModulo[]>([])
  const [capacidades, setCapacidades] = useState<string[]>([])

  useEffect(() => {
    let ativo = true

    // Carrega perfil + permissões + capacidades a partir da sessão ativa.
    // getPerfilUsuario lança (e faz signOut) quando o perfil está ausente/inativo.
    async function carregarPerfil() {
      if (ativo) setCarregando(true)
      try {
        const [p, perms, caps] = await Promise.all([
          authService.getPerfilUsuario(),
          authService.getPermissoesUsuario(),
          authService.getCapacidadesUsuario(),
        ])
        if (ativo) {
          setPerfil(p)
          setPermissoes(perms)
          setCapacidades(caps)
        }
      } catch {
        if (ativo) {
          setPerfil(null)
          setPermissoes([])
          setCapacidades([])
        }
      } finally {
        if (ativo) setCarregando(false)
      }
    }

    async function inicializar() {
      const { data } = await supabase.auth.getSession()
      if (data.session) {
        await carregarPerfil()
      } else if (ativo) {
        setPerfil(null)
        setPermissoes([])
        setCapacidades([])
        setCarregando(false)
      }
    }

    inicializar()

    // Reage a login (SIGNED_IN) recarregando o perfil e a logout (SIGNED_OUT)
    // limpando-o. INITIAL_SESSION é ignorado pois já é coberto por inicializar().
    const { data: sub } = supabase.auth.onAuthStateChange((evento, session) => {
      if (!ativo || evento === 'INITIAL_SESSION') return
      if (session) {
        carregarPerfil()
      } else {
        setPerfil(null)
        setPermissoes([])
        setCapacidades([])
        setCarregando(false)
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
    setCapacidades([])
  }

  return (
    <AuthContext.Provider value={{ carregando, perfil, permissoes, capacidades, sair }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth deve ser usado dentro de <AuthProvider>')
  return ctx
}
