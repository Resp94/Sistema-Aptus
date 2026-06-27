# Migração HTML → React (Login + Dashboard) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar o acesso não autenticado aos painéis e estabelecer o padrão de migração — corrigir o login quebrado, fechar o furo dos HTML estáticos, adicionar route guard e converter o `dashboard.html` em React idêntico ao original.

**Architecture:** SPA React com `react-router-dom`. Um `<AuthProvider>` resolve a sessão Supabase + perfil + permissões uma única vez e expõe via Context. Um `<ProtectedRoute>` bloqueia rotas sem sessão. Os HTML legados saem da raiz servível e viram referência visual. O `aptus.css` passa a ser o design system global.

**Tech Stack:** React 19, TypeScript, Vite 8, `react-router-dom`, Supabase JS, Vitest (testes de lógica pura).

## Global Constraints

- Estilo único: `aptus.css` (não recriar CSS; reutilizar classes existentes). Não importar o `index.css`/`App.css` boilerplate do Vite.
- Paridade visual: cada tela React deve ser **idêntica** ao `.html` de referência (mesmo markup/classes).
- Dados reais nesta etapa: somente usuário (`obter_perfil_usuario`) e menu (`obter_permissoes_usuario`). Números financeiros e lançamentos do dashboard permanecem **mock idênticos ao HTML**.
- Tema padrão `data-theme="dark"` no `<html>` (chave localStorage `aptus-theme`); estado da sidebar em `aptus-sidebar`.
- Mensagens de erro de auth mantêm o texto genérico já existente ("E-mail ou senha inválidos.").
- Testes de lógica em arquivos `src/lib/*.test.ts` rodam em ambiente `node` (sem render de componente). Verificação visual e de guard é feita no navegador (Chrome DevTools).

---

### Task 1: Corrigir CSS global e bootstrap do HTML (conserta o login)

**Files:**
- Modify: `src/main.tsx`
- Modify: `index.html`
- Modify: `src/App.css` (esvaziar)
- Modify: `src/index.css` (esvaziar)

**Interfaces:**
- Consumes: `aptus.css` (na raiz do projeto), classes `.login-page`, `.login-brand`, `.input`, `.btn`, variáveis `--bg`, `--accent`, etc.
- Produces: design system global disponível para todos os componentes; `<html data-theme="dark">`.

- [ ] **Step 1: Importar o design system e remover o boilerplate em `src/main.tsx`**

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../aptus.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
```

(Remove os imports de `./index.css` e `./App.css`.)

- [ ] **Step 2: Ajustar `index.html` (lang, tema, título)**

```html
<!doctype html>
<html lang="pt-BR" data-theme="dark">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Aptus Flow</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 3: Esvaziar `src/App.css` e `src/index.css`**

Substituir o conteúdo de cada arquivo por um comentário único:

```css
/* Estilo global vem de aptus.css (importado em main.tsx). */
```

- [ ] **Step 4: Verificar o login no navegador**

Com o dev server rodando (`npm run dev`), abrir `http://localhost:5173/` e comparar com `reference/legacy-html/login.html` (após a Task 2; antes dela, comparar com o `login.html` da raiz). Conferir: layout de duas colunas, coluna de marca à esquerda com features, formulário estilizado à direita, cores do tema escuro.

Critério: o login renderiza idêntico ao `login.html` (não mais centralizado/sem estilo).

- [ ] **Step 5: Commit**

```bash
git add src/main.tsx index.html src/App.css src/index.css
git commit -m "fix: carregar aptus.css global e corrigir bootstrap do login"
```

---

### Task 2: Mover HTML legados para referência e bloquear acesso no dev server (fecha o furo)

**Files:**
- Move: `dashboard.html`, `fluxo-caixa.html`, `contas-pagar.html`, `contas-receber.html`, `clientes.html`, `propostas.html`, `contratos.html`, `cobrancas.html`, `projetos.html`, `equipe.html`, `relatorios.html`, `configuracoes.html`, `financeiro.html`, `login.html`, `index.legacy.html` → `reference/legacy-html/`
- Modify: `vite.config.ts`

**Interfaces:**
- Consumes: nada.
- Produces: nenhum painel acessível por URL no dev; arquivos legados preservados como referência de conversão.

- [ ] **Step 1: Mover os HTML legados para `reference/legacy-html/`**

```bash
mkdir -p reference/legacy-html
git mv dashboard.html fluxo-caixa.html contas-pagar.html contas-receber.html \
  clientes.html propostas.html contratos.html cobrancas.html projetos.html \
  equipe.html relatorios.html configuracoes.html financeiro.html \
  login.html index.legacy.html reference/legacy-html/
```

(Mantém os arquivos `*.artifact.json` na raiz como estão — são metadados, não páginas servíveis.)

- [ ] **Step 2: Bloquear acesso a `reference/` no dev server em `vite.config.ts`**

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    fs: {
      deny: ['**/reference/**'],
    },
  },
  // @ts-ignore
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
  },
})
```

- [ ] **Step 3: Reiniciar o dev server e verificar que os painéis não são mais acessíveis**

Reiniciar `npm run dev`. No navegador:
- `http://localhost:5173/dashboard.html` → 404 (arquivo não existe mais na raiz).
- `http://localhost:5173/reference/legacy-html/dashboard.html` → bloqueado/403 (negado por `server.fs.deny`).

Critério: nenhum dos 13 painéis renderiza por URL direta.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: mover HTML legados para reference/ e bloquear no dev server"
```

---

### Task 3: Utilitários puros de usuário e navegação (com testes)

**Files:**
- Create: `src/lib/usuario.ts`
- Create: `src/lib/usuario.test.ts`
- Create: `src/lib/navegacao.ts`
- Create: `src/lib/navegacao.test.ts`

**Interfaces:**
- Consumes: `PerfilAcesso`, `PermissaoModulo` de `src/types/auth.ts`.
- Produces:
  - `obterIniciais(nome: string): string`
  - `saudacaoPorHora(hora: number): string`
  - `rotaInicialPorPerfil(perfil: PerfilAcesso): string`
  - `ItemNav` (tipo) e `ITENS_NAV: ItemNav[]`
  - `filtrarNavPorPermissoes(itens: ItemNav[], permissoes: PermissaoModulo[]): ItemNav[]`

- [ ] **Step 1: Escrever os testes de `src/lib/usuario.ts`**

```ts
import { describe, it, expect } from 'vitest'
import { obterIniciais, saudacaoPorHora, rotaInicialPorPerfil } from './usuario'

describe('obterIniciais', () => {
  it('retorna as iniciais de nome e sobrenome em maiúsculas', () => {
    expect(obterIniciais('Ana Martins')).toBe('AM')
  })
  it('usa apenas a primeira letra quando há um único nome', () => {
    expect(obterIniciais('Ana')).toBe('A')
  })
  it('ignora espaços extras', () => {
    expect(obterIniciais('  Ana   Martins  ')).toBe('AM')
  })
})

describe('saudacaoPorHora', () => {
  it('Bom dia antes do meio-dia', () => {
    expect(saudacaoPorHora(9)).toBe('Bom dia')
  })
  it('Boa tarde entre 12 e 17', () => {
    expect(saudacaoPorHora(15)).toBe('Boa tarde')
  })
  it('Boa noite a partir das 18', () => {
    expect(saudacaoPorHora(20)).toBe('Boa noite')
  })
})

describe('rotaInicialPorPerfil', () => {
  it('Administrador vai para /dashboard', () => {
    expect(rotaInicialPorPerfil('Administrador')).toBe('/dashboard')
  })
  it('Projetos vai para /projetos', () => {
    expect(rotaInicialPorPerfil('Projetos')).toBe('/projetos')
  })
  it('Comercial vai para /clientes', () => {
    expect(rotaInicialPorPerfil('Comercial')).toBe('/clientes')
  })
})
```

- [ ] **Step 2: Rodar os testes e verificar que falham**

Run: `npx vitest run src/lib/usuario.test.ts`
Expected: FAIL (módulo `./usuario` não existe).

- [ ] **Step 3: Implementar `src/lib/usuario.ts`**

```ts
import type { PerfilAcesso } from '../types/auth'

export function obterIniciais(nome: string): string {
  const partes = nome.trim().split(/\s+/).filter(Boolean)
  if (partes.length === 0) return ''
  if (partes.length === 1) return partes[0][0].toUpperCase()
  return (partes[0][0] + partes[partes.length - 1][0]).toUpperCase()
}

export function saudacaoPorHora(hora: number): string {
  if (hora < 12) return 'Bom dia'
  if (hora < 18) return 'Boa tarde'
  return 'Boa noite'
}

export function rotaInicialPorPerfil(perfil: PerfilAcesso): string {
  switch (perfil) {
    case 'Administrador':
    case 'Financeiro':
      return '/dashboard'
    case 'Projetos':
    case 'Técnico':
      return '/projetos'
    case 'Comercial':
      return '/clientes'
    default:
      return '/dashboard'
  }
}
```

- [ ] **Step 4: Rodar os testes e verificar que passam**

Run: `npx vitest run src/lib/usuario.test.ts`
Expected: PASS.

- [ ] **Step 5: Escrever os testes de `src/lib/navegacao.ts`**

```ts
import { describe, it, expect } from 'vitest'
import { ITENS_NAV, filtrarNavPorPermissoes } from './navegacao'
import type { PermissaoModulo } from '../types/auth'

describe('ITENS_NAV', () => {
  it('contém os 12 itens da sidebar do dashboard.html', () => {
    expect(ITENS_NAV.map((i) => i.modulo)).toEqual([
      'dashboard', 'fluxo-caixa', 'contas-pagar', 'contas-receber',
      'clientes', 'propostas', 'contratos', 'cobrancas',
      'projetos', 'equipe', 'relatorios', 'configuracoes',
    ])
  })
})

describe('filtrarNavPorPermissoes', () => {
  it('mantém apenas itens com pode_ler = true', () => {
    const permissoes: PermissaoModulo[] = [
      { modulo: 'dashboard', pode_ler: true, pode_escrever: true },
      { modulo: 'clientes', pode_ler: false, pode_escrever: false },
      { modulo: 'projetos', pode_ler: true, pode_escrever: true },
    ]
    const filtrados = filtrarNavPorPermissoes(ITENS_NAV, permissoes).map((i) => i.modulo)
    expect(filtrados).toContain('dashboard')
    expect(filtrados).toContain('projetos')
    expect(filtrados).not.toContain('clientes')
  })
  it('oculta itens sem permissão correspondente', () => {
    const filtrados = filtrarNavPorPermissoes(ITENS_NAV, [])
    expect(filtrados).toHaveLength(0)
  })
})
```

- [ ] **Step 6: Rodar os testes e verificar que falham**

Run: `npx vitest run src/lib/navegacao.test.ts`
Expected: FAIL (módulo `./navegacao` não existe).

- [ ] **Step 7: Implementar `src/lib/navegacao.ts`**

```ts
import type { PermissaoModulo } from '../types/auth'

export type SecaoNav = 'Principal' | 'Gestão'

export interface ItemNav {
  modulo: string
  rotulo: string
  rota: string
  secao: SecaoNav
  icone: string
}

// Ordem e rótulos idênticos à sidebar de reference/legacy-html/dashboard.html
export const ITENS_NAV: ItemNav[] = [
  { modulo: 'dashboard', rotulo: 'Dashboard', rota: '/dashboard', secao: 'Principal', icone: 'grid' },
  { modulo: 'fluxo-caixa', rotulo: 'Fluxo de Caixa', rota: '/fluxo-caixa', secao: 'Principal', icone: 'activity' },
  { modulo: 'contas-pagar', rotulo: 'Contas a Pagar', rota: '/contas-pagar', secao: 'Principal', icone: 'pagar' },
  { modulo: 'contas-receber', rotulo: 'Contas a Receber', rota: '/contas-receber', secao: 'Principal', icone: 'receber' },
  { modulo: 'clientes', rotulo: 'Clientes / Fornecedores', rota: '/clientes', secao: 'Gestão', icone: 'users' },
  { modulo: 'propostas', rotulo: 'Propostas', rota: '/propostas', secao: 'Gestão', icone: 'file' },
  { modulo: 'contratos', rotulo: 'Contratos', rota: '/contratos', secao: 'Gestão', icone: 'contract' },
  { modulo: 'cobrancas', rotulo: 'Cobranças', rota: '/cobrancas', secao: 'Gestão', icone: 'clock' },
  { modulo: 'projetos', rotulo: 'Projetos', rota: '/projetos', secao: 'Gestão', icone: 'kanban' },
  { modulo: 'equipe', rotulo: 'Equipe', rota: '/equipe', secao: 'Gestão', icone: 'team' },
  { modulo: 'relatorios', rotulo: 'Relatórios / Exportação', rota: '/relatorios', secao: 'Gestão', icone: 'report' },
  { modulo: 'configuracoes', rotulo: 'Configurações', rota: '/configuracoes', secao: 'Gestão', icone: 'gear' },
]

export function filtrarNavPorPermissoes(
  itens: ItemNav[],
  permissoes: PermissaoModulo[],
): ItemNav[] {
  const legiveis = new Set(
    permissoes.filter((p) => p.pode_ler).map((p) => p.modulo),
  )
  return itens.filter((item) => legiveis.has(item.modulo))
}
```

- [ ] **Step 8: Rodar os testes e verificar que passam**

Run: `npx vitest run src/lib/navegacao.test.ts`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/lib/usuario.ts src/lib/usuario.test.ts src/lib/navegacao.ts src/lib/navegacao.test.ts
git commit -m "feat: utilitários de usuário e navegação com testes"
```

---

### Task 4: Cliente Supabase com storageKey próprio + AuthProvider/Context

**Files:**
- Modify: `src/services/supabase.ts`
- Create: `src/contexts/AuthContext.tsx`

**Interfaces:**
- Consumes: `supabase` de `src/services/supabase.ts`; `authService.getPerfilUsuario`, `authService.getPermissoesUsuario`, `authService.signOut` de `src/services/auth.service.ts`; `PerfilUsuario`, `PermissaoModulo` de `src/types/auth.ts`.
- Produces:
  - `AuthProvider` (componente)
  - `useAuth(): { carregando: boolean; perfil: PerfilUsuario | null; permissoes: PermissaoModulo[]; sair: () => Promise<void> }`

- [ ] **Step 1: Definir `storageKey` explícito no cliente Supabase**

Em `src/services/supabase.ts`, substituir a criação do cliente por:

```ts
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    storageKey: 'aptus-flow-auth',
  },
})
```

(Mantém as linhas de validação das variáveis de ambiente acima, sem alteração.)

- [ ] **Step 2: Criar `src/contexts/AuthContext.tsx`**

```tsx
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
```

- [ ] **Step 3: Verificar a compilação de tipos**

Run: `npx tsc -b --noEmit`
Expected: sem erros nos novos arquivos.

- [ ] **Step 4: Commit**

```bash
git add src/services/supabase.ts src/contexts/AuthContext.tsx
git commit -m "feat: AuthProvider com sessão, perfil e permissões via Context"
```

---

### Task 5: react-router-dom + ProtectedRoute + reestruturação do App

**Files:**
- Modify: `package.json` (dependência `react-router-dom`)
- Create: `src/components/ProtectedRoute.tsx`
- Create: `src/pages/ModuloNaoMigrado.tsx`
- Modify: `src/App.tsx`

**Interfaces:**
- Consumes: `useAuth` de `src/contexts/AuthContext.tsx`; `Login`, `ResetPassword` de `src/pages/`; `ITENS_NAV` de `src/lib/navegacao.ts`.
- Produces: `ProtectedRoute` (wrapper de rota); `ModuloNaoMigrado` (placeholder); árvore de rotas em `App.tsx`.

- [ ] **Step 1: Instalar react-router-dom**

```bash
npm install react-router-dom@^7
```

Expected: `react-router-dom` adicionado a `dependencies` em `package.json`.

- [ ] **Step 2: Criar `src/components/ProtectedRoute.tsx`**

```tsx
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
```

- [ ] **Step 3: Criar `src/pages/ModuloNaoMigrado.tsx`**

```tsx
import { Link } from 'react-router-dom'

export default function ModuloNaoMigrado() {
  return (
    <div style={{ padding: '40px', textAlign: 'center', fontFamily: 'var(--font-body)', background: 'var(--bg)', color: 'var(--fg)', minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '16px' }}>Módulo Não Migrado</h1>
      <p style={{ color: 'var(--muted)', marginBottom: '24px', maxWidth: '400px' }}>
        Esta tela ainda não foi convertida para React. Use o Dashboard enquanto a migração avança.
      </p>
      <Link to="/dashboard" style={{ display: 'inline-block', padding: '10px 20px', background: 'var(--accent)', color: 'var(--accent-on)', borderRadius: 'var(--radius-md)', textDecoration: 'none', fontWeight: 'bold' }}>
        Ir para o Dashboard
      </Link>
    </div>
  )
}
```

- [ ] **Step 4: Reescrever `src/App.tsx` com as rotas**

```tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import { ProtectedRoute } from './components/ProtectedRoute'
import Login from './pages/Login'
import ResetPassword from './pages/ResetPassword'
import ModuloNaoMigrado from './pages/ModuloNaoMigrado'
import DashboardPage from './pages/DashboardPage'
import { ITENS_NAV } from './lib/navegacao'

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/reset-password" element={<ResetPassword />} />
          <Route element={<ProtectedRoute />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            {ITENS_NAV.filter((i) => i.modulo !== 'dashboard').map((i) => (
              <Route key={i.rota} path={i.rota} element={<ModuloNaoMigrado />} />
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
```

> Nota: `DashboardPage` é criado na Task 7. Até lá, a compilação falhará neste import — por isso a verificação de runtime desta task ocorre após a Task 7. Os passos 5–6 abaixo verificam apenas a árvore de rotas públicas.

- [ ] **Step 5: Tratar o recovery do ResetPassword via rota**

Em `src/pages/ResetPassword.tsx`, ajustar o redirecionamento final de sucesso de `window.location.href = '/login?reset_success=true'` para continuar funcionando com `BrowserRouter` — manter `window.location.href` aqui é aceitável (recarrega a app já autenticada/limpa). Nenhuma outra mudança necessária. Confirmar que o link de recovery (hash `type=recovery`) abre `ResetPassword`: adicionar no `App.tsx`, dentro de `<Routes>`, o tratamento por hash **não** é necessário se o e-mail de recovery apontar para `/reset-password`; garantir em `auth.service.resetPassword` que `redirectTo` use `/reset-password`.

Alterar em `src/services/auth.service.ts` a linha do `redirectUrl`:

```ts
const redirectUrl = `${window.location.origin}/reset-password`;
```

- [ ] **Step 6: Commit (estrutura de rotas)**

```bash
git add package.json package-lock.json src/components/ProtectedRoute.tsx src/pages/ModuloNaoMigrado.tsx src/App.tsx src/services/auth.service.ts
git commit -m "feat: react-router-dom, ProtectedRoute e árvore de rotas"
```

---

### Task 6: Login usa navegação do router (sem reload)

**Files:**
- Modify: `src/pages/Login.tsx`

**Interfaces:**
- Consumes: `useNavigate` de `react-router-dom`; `rotaInicialPorPerfil` de `src/lib/usuario.ts`.
- Produces: redirecionamento pós-login via `navigate(...)`.

- [ ] **Step 1: Importar hooks e utilitário no topo de `src/pages/Login.tsx`**

```tsx
import { useNavigate } from 'react-router-dom'
import { rotaInicialPorPerfil } from '../lib/usuario'
```

- [ ] **Step 2: Obter `navigate` dentro do componente**

Logo no início de `export const Login: React.FC = () => {`, adicionar:

```tsx
const navigate = useNavigate();
```

- [ ] **Step 3: Substituir o bloco de redirecionamento pós-login**

Trocar o `setTimeout` com o `switch` de `window.location.href` (dentro de `handleLoginSubmit`, no caminho de sucesso) por:

```tsx
      setTimeout(() => {
        navigate(rotaInicialPorPerfil(perfil.perfil_acesso), { replace: true });
      }, 1000);
```

- [ ] **Step 4: Verificar no navegador**

Com dev server rodando, abrir `/login`, entrar com `admin@aptusflow.local` / `SenhaDeTesteSegura123!`. Esperado: toast de sucesso e navegação para `/dashboard` sem recarregar a página. (O dashboard só renderiza completo após a Task 7.)

- [ ] **Step 5: Commit**

```bash
git add src/pages/Login.tsx
git commit -m "feat: redirecionamento pós-login via react-router"
```

---

### Task 7: AppShell + DashboardPage (conversão do dashboard.html)

**Files:**
- Create: `src/components/AppShell.tsx`
- Create: `src/pages/DashboardPage.tsx`
- Create: `src/components/icons.tsx`

**Interfaces:**
- Consumes: `useAuth` de `src/contexts/AuthContext.tsx`; `ITENS_NAV`, `filtrarNavPorPermissoes` de `src/lib/navegacao.ts`; `obterIniciais`, `saudacaoPorHora` de `src/lib/usuario.ts`; classes do `aptus.css`.
- Produces: `AppShell` (layout com sidebar+header) e `DashboardPage` (default export, usado em `App.tsx`).

Fonte de referência para o markup exato: `reference/legacy-html/dashboard.html`.

- [ ] **Step 1: Criar `src/components/icons.tsx` com os ícones SVG da sidebar**

Portar 1:1 cada `<svg class="nav-icon">` de `reference/legacy-html/dashboard.html` (linhas 58–108), convertendo atributos para JSX (`stroke-width` → `strokeWidth`, `class` → `className`). Exportar um mapa indexado pela chave `icone` de `ITENS_NAV`:

```tsx
import type { ReactNode } from 'react'

export const NAV_ICONS: Record<string, ReactNode> = {
  grid: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect></svg>
  ),
  activity: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
  ),
  pagar: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path></svg>
  ),
  receber: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M12 2v20M6 7l6-5 6 5"></path><path d="M6 17l6 5 6-5"></path></svg>
  ),
  users: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
  ),
  file: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="12" y1="18" x2="12" y2="12"></line><line x1="9" y1="15" x2="15" y2="15"></line></svg>
  ),
  contract: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M4 4h16v16H4z"></path><line x1="8" y1="9" x2="16" y2="9"></line><line x1="8" y1="13" x2="12" y2="13"></line><line x1="8" y1="17" x2="10" y2="17"></line></svg>
  ),
  clock: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
  ),
  kanban: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="2" y="3" width="20" height="14" rx="2"></rect><path d="M8 21h8M12 17v4"></path></svg>
  ),
  team: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
  ),
  report: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><circle cx="10" cy="13" r="2" fill="currentColor" opacity="0.3"></circle></svg>
  ),
  gear: (
    <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="12" cy="12" r="3"></circle><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"></path></svg>
  ),
}
```

- [ ] **Step 2: Criar `src/components/AppShell.tsx`**

Reproduz `<aside class="app-sidebar">` + `<header class="app-header">` de `reference/legacy-html/dashboard.html` (linhas 49–138), com:
- Sidebar dividida em seções "Principal" e "Gestão", renderizando **apenas** os itens retornados por `filtrarNavPorPermissoes(ITENS_NAV, permissoes)`. Item ativo: comparar `item.rota` com `location.pathname`.
- Card do usuário: iniciais (`obterIniciais(perfil.nome)`), `perfil.nome` e `perfil.perfil_acesso`.
- Popover do usuário com "Alternar tema" (toggle `data-theme` + localStorage `aptus-theme`) e "Sair" (`sair()` do `useAuth` → `navigate('/login')`).
- Toggle da sidebar (classe `sidebar-collapsed` em `.app-shell` + localStorage `aptus-sidebar`).
- `title`/`headerActions` recebidos por props; conteúdo da página via `children`.

```tsx
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
```

- [ ] **Step 3: Criar `src/pages/DashboardPage.tsx`**

Envolver com `<AppShell titulo="Dashboard" headerActions={...}>` e portar 1:1 o conteúdo de `<main class="app-content">` de `reference/legacy-html/dashboard.html` (linhas 141–268: `.greeting`, `.metric-grid`, `.dashboard-grid` com os 4 cards). Regras de conversão:
- `class` → `className`; `stroke-width` → `strokeWidth`; estilos inline `style="..."` → objeto JSX (`style={{ ... }}`); `data-clickable=""` → `data-clickable=""`.
- Os `onclick="window.location.href='X.html'"` viram `onClick={() => navigate('/X')}` usando `useNavigate` (ex.: `fluxo-caixa.html` → `/fluxo-caixa`).
- Saudação: `<h2 className="greeting">{saudacaoPorHora(new Date().getHours())}, {primeiroNome}</h2>`, onde `primeiroNome = perfil?.nome.split(' ')[0]`.
- Os estilos específicos do dashboard que no HTML estavam no `<style>` inline (linhas 7–34: `.metric-grid`, `.dashboard-grid`, `.recent-item`, `.greeting`, etc.) devem ser adicionados ao final de `aptus.css` (uma vez), pois são compartilháveis e não existem lá ainda. Conferir antes com `grep -n "metric-grid" aptus.css`; se ausente, anexar o bloco.
- O modal de notificações (linhas 272–283) é portado como estado React (`const [notifAberto, setNotifAberto]`), acionado pelo botão de sino em `headerActions`.

Esqueleto:

```tsx
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { useAuth } from '../contexts/AuthContext'
import { saudacaoPorHora } from '../lib/usuario'

export default function DashboardPage() {
  const navigate = useNavigate()
  const { perfil } = useAuth()
  const [notifAberto, setNotifAberto] = useState(false)
  const primeiroNome = perfil?.nome.split(' ')[0] ?? ''

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

      {/* metric-grid + dashboard-grid portados 1:1 das linhas 144-268 de
          reference/legacy-html/dashboard.html, com onClick={() => navigate('/...')} */}

      {/* modal de notificações controlado por notifAberto */}
    </AppShell>
  )
}
```

- [ ] **Step 4: Verificar a compilação**

Run: `npx tsc -b --noEmit`
Expected: sem erros (todos os imports de `App.tsx`, incluindo `DashboardPage`, resolvem).

- [ ] **Step 5: Commit**

```bash
git add src/components/AppShell.tsx src/components/icons.tsx src/pages/DashboardPage.tsx aptus.css
git commit -m "feat: AppShell e DashboardPage convertidos do dashboard.html"
```

---

### Task 8: Verificação fim-a-fim (guard + paridade visual)

**Files:** nenhum (verificação).

- [ ] **Step 1: Rodar a suíte de testes e o lint**

Run: `npm test && npm run lint`
Expected: testes passam; lint sem erros.

- [ ] **Step 2: Verificar o guard (acesso sem sessão)**

No navegador, em aba anônima ou após limpar `localStorage`, acessar `http://localhost:5173/dashboard`. Esperado: redireciona para `/login` (sem flash do dashboard).

- [ ] **Step 3: Verificar login válido → dashboard real**

Login com `admin@aptusflow.local` / `SenhaDeTesteSegura123!`. Esperado: navega para `/dashboard`; card do usuário mostra "Administrador Persona" e iniciais reais; sidebar mostra todos os módulos (Administrador tem `pode_ler` em tudo).

- [ ] **Step 4: Verificar filtragem de menu por perfil**

Login com `comercial@aptusflow.local` / `SenhaDeTesteSegura123!`. Esperado: sidebar mostra apenas Clientes, Propostas, Contratos, Cobranças e Configurações (módulos com `pode_ler = true` para Comercial); Dashboard **não** aparece e a rota inicial é `/clientes`.

- [ ] **Step 5: Verificar credenciais inválidas**

Em `/login`, entrar com `qualquercoisa@teste.com` / `senhaqualquer123`. Esperado: permanece no login com "E-mail ou senha inválidos."; nenhuma navegação.

- [ ] **Step 6: Verificar paridade visual do dashboard**

Comparar `/dashboard` (logado como Administrador) com `reference/legacy-html/dashboard.html`. Conferir: 4 metric-cards com valores idênticos, gráfico de barras, listas de lançamentos/contas, gráfico de pizza de composição de receita, sidebar e header. Diferença esperada e aceitável: nome/perfil do usuário (reais) e saudação por hora.

- [ ] **Step 7: Commit final (se houver ajustes de paridade)**

```bash
git add -A
git commit -m "test: verificação fim-a-fim de auth e paridade visual do dashboard"
```
