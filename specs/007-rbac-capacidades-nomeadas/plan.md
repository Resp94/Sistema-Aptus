# Implementation Plan: RBAC por Capacidades Nomeadas

**Branch**: `main` (spec dir `007-rbac-capacidades-nomeadas`) | **Date**: 2026-07-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-rbac-capacidades-nomeadas/spec.md`

## Summary

Introduzir capacidades nomeadas (`recurso.acao`) como fonte canonica de autorizacao de acoes sensiveis, preservando `obter_permissoes_usuario`/`permissao_modulo` para leitura, rota e navegacao. A fundacao cria `public.capacidades_perfil`, `tem_capacidade(p_capacidade text)` e `obter_capacidades_usuario()`. Todas as RPCs de escrita e acoes com efeito de negocio passam a validar capacidades; o frontend consome a mesma lista para exibir controles. A feature tambem corrige os bugs confirmados na validacao E2E: Tecnico com permissoes amplas demais em Projetos, Tecnico sem apontamento proprio, Tecnico sem visao dos colegas dos mesmos projetos, apontamento "sem tarefa" quebrando, detalhes sem fechar em Propostas/Contratos e cliente inativo sem reativacao por UI.

## Technical Context

**Language/Version**: SQL (PostgreSQL 17 / plpgsql) para schema, helpers e RPCs; TypeScript 6.0.x + React 19 para contexto de autenticacao, helpers de capacidade, pages e services; Node ESM para auditoria estatica.

**Primary Dependencies**: Supabase CLI 2.109.0 (migrations, `supabase test db`, `db lint`, `db advisors`), pgTAP nos testes de banco, `@supabase/supabase-js` 2.39.8, Vitest 1.3.1, Vite 8, React Router DOM 7.

**Storage**: PostgreSQL 17 via Supabase; migrations versionadas em `supabase/migrations/`; seeds em `supabase/seed.sql`; nova matriz em `public.capacidades_perfil`.

**Testing**: pgTAP via `npm run db:test`; Vitest via `npm run test`; auditorias Node via `npm run audit`; build via `npm run build`; validacao final Playwright/E2E nas 5 personas operacionais.

**Target Platform**: Web SPA interna em Cloudflare Pages; backend Supabase/Postgres local/cloud sem backend custom.

**Project Type**: Aplicacao web interna (frontend SPA + Supabase como backend-as-a-service). Esta feature e transversal: banco/autorizacao, frontend gates, testes e documentacao.

**Performance Goals**: Consulta de capacidades deve ser carregada junto ao perfil/permissoes na inicializacao da sessao sem adicionar fluxo perceptivel de espera; guardas `tem_capacidade` devem ser consultas indexadas por chave primaria; nenhuma tela em escopo deve exigir reload manual apos acao autorizada.

**Constraints**: RPC-first permanece obrigatorio; services de dominio continuam usando `supabase.rpc()` e nunca `supabase.from()`. Todas as novas funcoes expostas devem seguir guardrails da feature 006: `SECURITY DEFINER`, `SET search_path = public`, guarda de identidade, `REVOKE`/`GRANT` explicitos. Migrations sao hand-authored. O frontend usa capacidades para UX, mas a autorizacao real fica nas RPCs. Visualizador deixa de ser persona operacional, mas permanece como perfil tecnico minimo de signup com leitura restrita a relatorios e configuracoes proprias.

**Scale/Scope**: 1 nova tabela de capacidades; 2 novos helpers/RPCs de autorizacao; atualizacao da matriz de leitura por modulo; migracao de ~35 RPCs de escrita/efeito de negocio; ajuste de leitura de equipe; atualizacao de contexto/auth e gates em ~10 pages; testes pgTAP/Vitest/auditoria; documentacao de personas e arquitetura.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

A constituicao em `.specify/memory/constitution.md` ainda esta como template, sem principios ratificados. Aplicam-se as regras de fato do repositorio e do `AGENTS.md`.

| Diretriz de fato | Status | Justificativa |
|------------------|--------|---------------|
| Documentar mudancas arquiteturais em `.sauron` e `.agents` | Pass | Plano e artefatos registram a nova regra; memoria/wiki serao atualizadas no mesmo turno. |
| RPC-first | Pass | A feature preserva services via `supabase.rpc()` e reforca a auditoria contra `supabase.from()` em dominio. |
| Guardrails de RPC da feature 006 | Pass | `tem_capacidade` complementa `permissao_modulo`; `audit-rpc` passa a aceitar/verificar ambas conforme tipo de operacao. |
| RLS como defesa em profundidade | Pass | A nova tabela tem RLS habilitado e acesso direto bloqueado por padrao; leitura ocorre por RPC controlada. |
| Autorizacao nunca deriva de `user_metadata` | Pass | Capacidades derivam de `public.perfis` + `public.capacidades_perfil`. |
| Migrations hand-authored | Pass | Migrations devem ser criadas via `supabase migration new` e editadas manualmente. |
| Sem backend custom | Pass | Toda autorizacao permanece em Postgres/Supabase; frontend apenas consome contratos. |

Nenhuma violacao identificada.

## Project Structure

### Documentation (this feature)

```text
specs/007-rbac-capacidades-nomeadas/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── capability-matrix.md
│   ├── rpc-capability-contract.md
│   ├── frontend-capabilities.md
│   └── audit-and-tests.md
├── checklists/
│   └── requirements.md
└── tasks.md              # Criado depois por /speckit-tasks
```

### Source Code (repository root)

```text
supabase/
├── migrations/
│   ├── <ts>_rbac_capacidades_foundation.sql      # tabela, helpers, matriz, permissao de leitura por modulo
│   └── <ts>_rbac_capacidades_rpc_guards.sql      # RPCs de escrita/efeito + ownership + bugs funcionais de banco
├── seed.sql                                      # remover Visualizador das personas/seeds operacionais se aplicavel
└── tests/
    ├── 02_rbac_por_perfil.sql                    # ajustar para 5 personas + Visualizador minimo tecnico
    └── 05_capacidades.sql                        # matriz, ownership, apontamento, equipe do Tecnico

scripts/
└── audit-rpc.mjs                                 # aceitar/exigir tem_capacidade para escrita/efeito

src/
├── contexts/
│   └── AuthContext.tsx                           # carregar capacidades junto ao perfil/permissoes
├── types/
│   └── auth.ts                                   # CapacidadeUsuario / AuthState
├── lib/
│   ├── permissoes.ts                             # manter podeLer; reduzir uso de podeEscrever em acoes
│   ├── capacidades.ts                            # helper pode(caps, 'recurso.acao')
│   └── capacidades.test.ts
├── services/
│   ├── auth.service.ts                           # obterCapacidadesUsuario()
│   ├── equipe.service.ts                         # normalizar tarefa_id null para "sem tarefa"
│   └── *.service.ts                              # permanecem RPC-first
└── pages/
    ├── ClientesPage.tsx
    ├── PropostasPage.tsx
    ├── ContratosPage.tsx
    ├── CobrancasPage.tsx
    ├── ProjetosPage.tsx
    ├── EquipePage.tsx
    ├── RelatoriosPage.tsx
    ├── ConfiguracoesPage.tsx
    ├── FluxoCaixaPage.tsx
    ├── ContasPagarPage.tsx
    └── ContasReceberPage.tsx

docs/
├── personas.md
└── arquitetura-dados.md

.agents/
└── project-memory/007-rbac-capacidades-nomeadas.md

.sauron/
└── wiki/knowledge/architecture.md
```

**Structure Decision**: Manter a estrutura SPA + Supabase existente. A mudanca de autorizacao fica em duas migrations hand-authored: uma de fundacao/matriz e outra de recriacao de RPCs e correcoes funcionais. O frontend recebe um helper de capacidades separado de `permissoes.ts`, mantendo `podeLer` para rotas e reduzindo `podeEscrever` a compatibilidade/transicao. Contratos ficam na spec 007 para guiar tarefas e revisao.

## Phase 0 Research

Gerado em [research.md](./research.md). Decisoes principais:

- Capacidades nomeadas ficam em `public.capacidades_perfil` como texto auditavel `recurso.acao`, com PK `(perfil_acesso, capacidade)` e seed versionado por migration.
- `tem_capacidade(p_capacidade text)` e `obter_capacidades_usuario()` sao os contratos canonicos; a primeira protege banco, a segunda alimenta UX.
- Toda RPC de escrita e toda acao sensivel com efeito de negocio (`boleto`, `notificar`, `exportar`, `baixar`, `enviar`, `gerar`) exige capacidade.
- `permissao_modulo` e `obter_permissoes_usuario` continuam como fonte de leitura/rota; Visualizador passa a ter leitura minima em `relatorios` e `configuracoes`.
- Tecnico ganha ownership por capacidade propria, nao por hardcode de nome de perfil.
- `listar_membros_equipe` para Tecnico passa a retornar proprio membro + colegas dos mesmos projetos por `alocacoes_equipe`.
- Reativacao de cliente usa `atualizar_cliente` com branch de capacidade `clientes.reativar`; nao cria RPC nova.
- Auditoria estatica diferencia guard de leitura (`permissao_modulo`) e guard de acao (`tem_capacidade`).

## Phase 1 Design

Artefatos gerados:

- [data-model.md](./data-model.md)
- [contracts/capability-matrix.md](./contracts/capability-matrix.md)
- [contracts/rpc-capability-contract.md](./contracts/rpc-capability-contract.md)
- [contracts/frontend-capabilities.md](./contracts/frontend-capabilities.md)
- [contracts/audit-and-tests.md](./contracts/audit-and-tests.md)
- [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

| Diretriz de fato | Status | Resultado apos design |
|------------------|--------|-----------------------|
| Documentar `.sauron` e `.agents` | Pass | Memoria da feature e wiki de arquitetura atualizadas com o plano. |
| RPC-first | Pass | Contratos mantem services via RPC e reforcam `check-no-from`. |
| Guardrails de RPC | Pass | `rpc-capability-contract.md` define combinacao `permissao_modulo` + `tem_capacidade`; `audit-and-tests.md` trava. |
| RLS defesa em profundidade | Pass | `data-model.md` define RLS habilitado na tabela de capacidades sem acesso direto amplo. |
| Sem `user_metadata` em autorizacao | Pass | Capacidade deriva de tabelas canonicas de autorizacao. |
| Migrations hand-authored | Pass | Quickstart e plano orientam `supabase migration new`, sem `db pull`. |
| Sem backend custom | Pass | Toda logica server-side fica em Postgres/Supabase. |

Nenhuma violacao nova introduzida pelo design.

## Complexity Tracking

> Nenhuma violacao de constituicao a justificar. A nova tabela e os contratos de teste sao complexidade necessaria para remover a ambiguidade de `pode_escrever` por modulo e travar regressao.
