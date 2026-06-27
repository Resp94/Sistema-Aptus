# Design — Migração incremental HTML → React + proteção de rotas

**Data:** 2026-06-27
**Contexto:** Spec [003-login-autenticacao](../../../specs/003-login-autenticacao/)

## Problema

Ao testar manualmente após `npm run dev`, era possível acessar os painéis com qualquer
credencial. A investigação (debugging sistemático) revelou que **o backend e o fluxo de
login validam corretamente**:

- GoTrue rejeita credenciais inválidas (`invalid_credentials`) e só emite token com a senha correta.
- O `Login.tsx` trata o erro e exibe "E-mail ou senha inválidos" sem redirecionar.

A causa raiz é outra: os 13 painéis (`dashboard.html`, `projetos.html`, ...) são **arquivos
HTML estáticos na raiz do projeto**, servidos diretamente pelo Vite dev server por URL
(`/dashboard.html`), **fora da aplicação React e sem nenhuma verificação de sessão**. Qualquer
pessoa acessa qualquer painel digitando a URL, sem login.

Em paralelo, a tela de login da SPA (`http://localhost:5173/`) está **visualmente quebrada**:
o `aptus.css` (design system, com as classes `.login-page`, `.login-brand`, `.input`, `.btn` e
as variáveis de tema) **não é importado em lugar nenhum** da app React. O que o `main.tsx`
carrega é o `index.css`/`App.css` boilerplate do template Vite, que inclusive centraliza todo o
conteúdo no `body`.

## Objetivo

Eliminar o acesso não autenticado e estabelecer o padrão de migração: cada `.html` legado vira
o **exemplo de referência** para um componente React **visualmente idêntico**, servido dentro da
SPA e atrás de um route guard. A migração é **incremental**, começando pelo Dashboard.

## Decisões

| Tema | Decisão |
|------|---------|
| Escopo | Incremental: corrigir login → fechar furo → guard → converter Dashboard. Demais painéis em iterações futuras. |
| Roteamento | Adotar `react-router-dom`. |
| Dados do Dashboard | Usuário (nome/perfil/iniciais) e menu lateral vêm de dados reais (`obter_perfil_usuario` / `obter_permissoes_usuario`). Números financeiros e lançamentos permanecem **mock idênticos ao HTML** (não há tabela fonte). |
| Legados `.html` | Movidos para `reference/legacy-html/` — deixam de ser servidos como rota e passam a ser a referência visual da conversão. |

## Arquitetura

### 1. CSS global / design system

- Importar `aptus.css` globalmente no `main.tsx`. Isso restaura o login ao visual do `login.html`
  e serve de base para todas as telas.
- Remover/esvaziar o boilerplate do Vite (`App.css` e o `index.css` default) que conflita com o
  layout. `aptus.css` passa a ser a fonte única de estilo.

### 2. Reorganização dos legados

- Mover os `.html` de painel + `login.html` + `index.legacy.html` para `reference/legacy-html/`.
- Resultado: nenhum painel acessível por URL direta; o furo de segurança fecha imediatamente
  para os 13 painéis. A única forma de ver qualquer tela passa a ser a SPA React, atrás do guard.

### 3. Rotas + route guard

```
<BrowserRouter>
  <Routes>
    /login           → <Login />            (público)
    /reset-password  → <ResetPassword />    (público)
    /                → <ProtectedRoute>     (guard)
        /dashboard   → <DashboardPage />    (convertido nesta etapa)
        /projetos, /clientes, ...           → <ModuloNaoMigrado /> (placeholder)
    *                → redirect p/ /dashboard ou /login
  </Routes>
</BrowserRouter>
```

**`<ProtectedRoute>`** (o coração da correção):
- Ao montar, chama `supabase.auth.getSession()`; enquanto resolve, exibe estado de carregamento
  (evita flash de conteúdo protegido).
- Sem sessão válida → `<Navigate to="/login" />`.
- Com sessão → busca o perfil (`obter_perfil_usuario`); se inexistente ou `Inativo`, força
  `signOut` e redireciona para `/login` (reaproveita a lógica de `auth.service.ts`).
- Expõe `perfil` e `permissões` às páginas filhas via Context, evitando refetch por tela.

**Login pós-sucesso:** troca `window.location.href = '/dashboard.html'` por `navigate('/dashboard')`
(e a rota apropriada ao perfil), sem reload, preservando a sessão em memória.

**Sessão:** o cliente Supabase usa `persistSession` com storage explícito, para a sessão
sobreviver ao refresh de página de forma previsível.

### 4. Conversão do Dashboard

Componentes com responsabilidade única, **visualmente idênticos** ao `dashboard.html`
(mesmo markup/classes; `aptus.css` continua sendo o estilo):

- **`<AppShell>`** — layout compartilhado (sidebar + header) reutilizável pelos próximos painéis;
  recebe o conteúdo via `children`.
  - **Sidebar**: navegação renderizada a partir das permissões reais (`obter_permissoes_usuario`)
    — só aparecem módulos com `pode_ler = true` para o perfil logado; links via `<Link>`.
  - **Card do usuário**: nome, perfil e iniciais de `obter_perfil_usuario` (substitui o
    "Ana Martins / Administradora" hardcoded).
- **`<DashboardPage>`** — corpo: cards de saldo, gráfico de fluxo, lançamentos, contas a pagar,
  composição de receita. Conteúdo **mock idêntico ao HTML**, portado para JSX.

Dados reais (perfil + permissões) vêm do Context do `<ProtectedRoute>` — sem novo fetch.

## Verificação

- Comparar lado a lado, no navegador (Chrome DevTools), `/` (login React) vs `login.html`, e
  `/dashboard` vs `dashboard.html` — confirmar paridade visual.
- Testar o guard: acessar `/dashboard` sem sessão → redirect para `/login`.
- Testar login com persona de teste (`admin@aptusflow.local`) → entra no dashboard; com
  credenciais inválidas → permanece no login com mensagem de erro.

## Fora de escopo

- Conversão dos outros 12 painéis (iterações futuras, mesmo padrão).
- Modelagem de tabelas financeiras (contas, lançamentos, clientes) e dados reais no corpo do
  dashboard.
- Controle de acesso por módulo no nível de rota (além de exibir/ocultar no menu) — pode ser
  endurecido depois, junto com RLS já existente.

## Limitações conhecidas

- Enquanto um painel não for convertido, sua rota mostra o placeholder "Módulo não migrado".
- O furo de segurança dos painéis estáticos é resolvido pela movimentação para
  `reference/legacy-html/`; nada em `reference/` deve ser referenciado por `<script src>` servível.
