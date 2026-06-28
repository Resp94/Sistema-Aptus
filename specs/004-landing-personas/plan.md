# Implementation Plan: Telas de Redirecionamento por Persona (Landing Pages)

**Branch**: `main` (spec dir `004-landing-personas`) | **Date**: 2026-06-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-landing-personas/spec.md`

## Summary

Converter as telas iniciais (landing) que faltam para cada persona — **Projetos** (`/projetos`) e **Clientes/Fornecedores** (`/clientes`) — a partir das referências em `reference/legacy-html/`, e **substituir todos os dados mockados** dessas telas e do **Dashboard** já existente por dados reais persistidos no Supabase. O escopo inclui **criar o schema** (tabelas, RLS e seeds) que alimenta as três landings e expor todo o acesso a dados — leitura e escrita (CRUD completo) — via **funções RPC do PostgreSQL**, seguindo a arquitetura RPC-first já adotada na feature de login. As ações de escrita respeitam o RBAC por perfil.

## Technical Context

**Language/Version**: TypeScript 5.5+ (es2023), React 19

**Primary Dependencies**: Vite 6, React 19, React-DOM 19, React Router DOM, @supabase/supabase-js 2.39.8

**Storage**: PostgreSQL 17 via Supabase

**Testing**: Vitest 1.3.1 (unit/lib) + validação manual via quickstart com `supabase db reset`

**Target Platform**: Web (SPA), deploy estático na Cloudflare Pages

**Project Type**: Web application (frontend SPA + backend-as-a-service)

**Performance Goals**: Cada landing carrega e exibe dados reais em < 3 s em condições normais de rede (SC-003)

**Constraints**: Sem backend customizado. **RPC-first**: todo acesso a dados (leitura e escrita) é feito via `supabase.rpc()` (PostgreSQL Functions), nunca por queries diretas a tabelas. RLS obrigatório em todas as tabelas novas como segunda camada de defesa; a camada primária de autorização são as RPCs `SECURITY DEFINER` que validam o RBAC do perfil autenticado. Nenhum dado mockado pode permanecer nas telas em escopo. Telas legadas em `reference/legacy-html/` servem apenas como referência de design.

**Scale/Scope**: 3 landings (Dashboard religado, Projetos novo, Clientes novo); 6 tabelas novas; ~5 personas de teste já existentes recebem seeds de dados de módulo coerentes ao perfil.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

A constituição do projeto (`.specify/memory/constitution.md`) está em estado de template (não ratificada), portanto não há princípios formais a violar. Aplicam-se as diretrizes de fato do projeto, derivadas de `docs/stack.md` e da feature 003:

| Diretriz de fato | Status | Justificativa |
|------------------|--------|---------------|
| Stack Vite + React 19 + TypeScript | ✅ Pass | Telas serão componentes React em `src/pages/`. |
| Banco PostgreSQL via Supabase com RLS em toda tabela | ✅ Pass | As 6 tabelas novas terão RLS por operação (sem `ALL`). |
| Arquitetura RPC-first (frontend → `supabase.rpc()`) | ✅ Pass | Leitura e escrita expostas como RPCs `SECURITY DEFINER`. |
| Migrações em `supabase/migrations/` + seeds em `supabase/seed.sql` | ✅ Pass | Schema versionado via nova migração; seeds estendem as personas existentes. |
| Deploy estático Cloudflare Pages, sem backend custom | ✅ Pass | Frontend SPA consome apenas o Supabase. |
| Sem dados mockados nas telas | ✅ Pass | Dashboard religado a RPCs; Projetos/Clientes nascem com dados reais. |

Nenhuma violação identificada. Complexity Tracking não se aplica.

## Project Structure

### Documentation (this feature)

```text
specs/004-landing-personas/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (contratos das RPCs)
│   ├── clientes-rpc.md
│   ├── projetos-rpc.md
│   └── dashboard-rpc.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── pages/
│   ├── DashboardPage.tsx      # Religar a dados reais (remover mock)
│   ├── ProjetosPage.tsx       # NOVA — baseada em reference/legacy-html/projetos.html
│   ├── ProjetosPage.css       # NOVA — estilos específicos (kanban, progresso)
│   ├── ClientesPage.tsx       # NOVA — baseada em reference/legacy-html/clientes.html
│   └── ClientesPage.css       # NOVA — estilos específicos (abas, painel detalhe)
├── services/
│   ├── dashboard.service.ts   # NOVA — RPCs de métricas/fluxo/lançamentos
│   ├── projetos.service.ts    # NOVA — RPCs de projetos/tarefas/alocações
│   └── clientes.service.ts    # NOVA — RPCs de clientes/atendimentos
├── types/
│   ├── dashboard.ts           # NOVA — tipos das métricas/séries
│   ├── projetos.ts            # NOVA — Projeto, Tarefa, Alocacao
│   └── clientes.ts            # NOVA — Cliente, Atendimento
├── lib/
│   └── permissoes.ts          # NOVA — helpers de pode_ler/pode_escrever no frontend
├── components/
│   └── AppShell.tsx           # Reuso (sem alteração estrutural)
└── App.tsx                    # Trocar ModuloNaoMigrado por ProjetosPage/ClientesPage nas rotas

supabase/
├── migrations/                                            # NOVAS — migrações modulares (ordem por timestamp)
│   ├── <ts1>_modulos_landing_schema.sql                   # 6 tabelas + CHECKs + FKs + índices
│   ├── <ts2>_modulos_landing_security.sql                 # RLS por operação + helper permissao_modulo + extensão do enum audit_log.evento
│   ├── <ts3>_modulos_landing_rpc_clientes_read.sql        # RPCs de leitura de clientes/atendimentos
│   ├── <ts4>_modulos_landing_rpc_clientes_write.sql       # RPCs de escrita de clientes/atendimentos
│   ├── <ts5>_modulos_landing_rpc_projetos_read.sql        # RPCs de leitura de projetos/tarefas/alocações
│   ├── <ts6>_modulos_landing_rpc_projetos_write.sql       # RPCs de escrita de projetos/tarefas
│   └── <ts7>_modulos_landing_rpc_dashboard_read.sql       # RPCs de agregação do Dashboard (leitura)
└── seed.sql                                               # Estender com dados de módulo das personas
```

**Structure Decision**: Mantém-se a estrutura SPA Vite+React existente e os padrões da feature 003 (serviços encapsulando RPCs, tipos em `src/types/`, páginas em `src/pages/`, helpers em `src/lib/`, CSS corporativo em `aptus.css` + CSS por página quando necessário). O schema é entregue em **migrações modulares** — separadas por camada (schema, segurança) e por domínio + operação (RPCs de leitura/escrita de clientes, projetos e leitura do dashboard) — em vez de um único arquivo grande, melhorando legibilidade, revisão e isolamento de mudanças. A ordem lexical por timestamp garante as dependências: `schema` → `security` (cria `permissao_modulo` e estende o enum de auditoria, usados pelas RPCs) → as 5 migrações de RPC (independentes entre si, dependem só de `security`). Os dados de teste estendem o `seed.sql` existente, mantendo o fluxo `supabase db reset` como validação local.

## Complexity Tracking

> Nenhuma violação identificada na fase de planejamento.
