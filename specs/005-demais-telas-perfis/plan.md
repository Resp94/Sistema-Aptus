# Implementation Plan: Demais Telas por Perfil de Acesso

**Branch**: `main` (spec dir `005-demais-telas-perfis`) | **Date**: 2026-06-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-demais-telas-perfis/spec.md`

## Summary

Converter as rotas ainda atendidas por `ModuloNaoMigrado` para telas React funcionais, usando `reference/legacy-html/` como fonte principal de layout e comportamento esperado. A implementacao deve completar os fluxos por perfil: financeiro (`/fluxo-caixa`, `/contas-pagar`, `/contas-receber`, `/cobrancas`), comercial (`/propostas`, `/contratos`, `/cobrancas`), equipe/projetos (`/equipe`), relatorios (`/relatorios`) e configuracoes (`/configuracoes`). O acesso a dados continua **RPC-first** via Supabase/Postgres, com RLS como segunda camada, RBAC por perfil, seeds por persona e zero dados mockados.

## Technical Context

**Language/Version**: TypeScript 6.0.x, React 19, ES modules

**Primary Dependencies**: Vite 8, React Router DOM 7, @supabase/supabase-js 2.39.8, Vitest 1.3.1

**Storage**: PostgreSQL 17 via Supabase local/cloud; Auth do Supabase; schema versionado em `supabase/migrations/`

**Testing**: Vitest para helpers e services puros; `npm run build`; validacao manual via `quickstart.md`; `npx supabase db reset` para validar migracoes/seeds

**Target Platform**: Web SPA, deploy estatico na Cloudflare Pages

**Project Type**: Aplicacao web interna (frontend SPA + Supabase como backend-as-a-service)

**Performance Goals**: Financeiro, Comercial, Equipe e Relatorios devem renderizar conteudo principal em ate 3 s com o volume inicial de seeds; Configuracoes deve renderizar dados proprios em ate 2 s e abas administrativas em ate 3 s; acoes de escrita devem atualizar indicadores/listas sem reload manual

**Constraints**: Sem backend customizado. Frontend nunca usa `supabase.from()` para dominio; todo acesso a dados passa por `supabase.rpc()`. Todas as tabelas novas em schema exposto devem ter RLS habilitado. RPCs devem validar `auth.uid()`, RBAC do modulo, `search_path` fixo e grants explicitos. Nenhuma tela pode simular envio, boleto, anexo, exportacao ou persistencia quando a integracao real nao existir.

**Scale/Scope**: 9 rotas, 5 familias de dominio, 13+ entidades de negocio, seeds por perfil/rota conforme matriz da spec, contratos RPC por dominio e telas derivadas dos HTML correspondentes em `reference/legacy-html/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

A constituicao em `.specify/memory/constitution.md` ainda esta como template, sem principios ratificados. Aplicam-se as regras de fato do repositorio e do `AGENTS.md`.

| Diretriz de fato | Status | Justificativa |
|------------------|--------|---------------|
| Documentar mudancas arquiteturais em `.sauron` e `.agents` | Pass | Plano, decisoes e registros serao documentados nos dois locais. |
| Stack Vite + React | Pass | As telas novas entram em `src/pages/` com CSS local e reuso do `AppShell`. |
| Supabase/Postgres com RLS | Pass | Tabelas novas terao RLS; tabelas existentes serao reaproveitadas quando forem a fonte canonica. |
| RPC-first | Pass | Services de frontend chamarao apenas `supabase.rpc()` para dados de dominio. |
| Sem dados mockados | Pass | Seeds alimentam os fluxos; estados vazios substituem mocks. |
| Cloudflare Pages, sem backend custom | Pass | Toda logica server-side fica em funcoes Postgres/Supabase. |

Nenhuma violacao identificada.

## Project Structure

### Documentation (this feature)

```text
specs/005-demais-telas-perfis/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── financeiro-rpc.md
│   ├── comercial-rpc.md
│   ├── equipe-rpc.md
│   ├── relatorios-configuracoes-rpc.md
│   └── ui-routes.md
└── tasks.md              # Criado depois por /speckit-tasks
```

### Source Code (repository root)

```text
src/
├── pages/
│   ├── FluxoCaixaPage.tsx / FluxoCaixaPage.css
│   ├── ContasPagarPage.tsx / ContasPagarPage.css
│   ├── ContasReceberPage.tsx / ContasReceberPage.css
│   ├── PropostasPage.tsx / PropostasPage.css
│   ├── ContratosPage.tsx / ContratosPage.css
│   ├── CobrancasPage.tsx / CobrancasPage.css
│   ├── EquipePage.tsx / EquipePage.css
│   ├── RelatoriosPage.tsx / RelatoriosPage.css
│   └── ConfiguracoesPage.tsx / ConfiguracoesPage.css
├── services/
│   ├── financeiro.service.ts
│   ├── comercial.service.ts
│   ├── equipe.service.ts
│   ├── relatorios.service.ts
│   └── configuracoes.service.ts
├── types/
│   ├── financeiro.ts
│   ├── comercial.ts
│   ├── equipe.ts
│   ├── relatorios.ts
│   └── configuracoes.ts
├── lib/
│   ├── permissoes.ts
│   └── navegacao.ts
└── App.tsx

supabase/
├── migrations/
│   ├── <ts1>_demais_telas_schema.sql
│   ├── <ts2>_demais_telas_security.sql
│   ├── <ts3>_demais_telas_rpc_financeiro_read.sql
│   ├── <ts4>_demais_telas_rpc_financeiro_write.sql
│   ├── <ts5>_demais_telas_rpc_comercial_read.sql
│   ├── <ts6>_demais_telas_rpc_comercial_write.sql
│   ├── <ts7>_demais_telas_rpc_equipe_read.sql
│   ├── <ts8>_demais_telas_rpc_equipe_write.sql
│   ├── <ts9>_demais_telas_rpc_relatorios_config_read.sql
│   └── <ts10>_demais_telas_rpc_config_write.sql
└── seed.sql

reference/legacy-html/
├── fluxo-caixa.html
├── contas-pagar.html
├── contas-receber.html
├── propostas.html
├── contratos.html
├── cobrancas.html
├── equipe.html
├── relatorios.html
└── configuracoes.html
```

**Structure Decision**: Manter a estrutura SPA existente. Cada rota em escopo ganha uma pagina propria, service proprio ou compartilhado por dominio, tipos em `src/types/` e CSS por pagina somente quando `aptus.css`/componentes existentes nao cobrirem o layout herdado. No banco, reaproveitar `clientes`, `projetos`, `tarefas` e `lancamentos` da feature 004 como fontes canonicas. Criar apenas as entidades que ainda nao existem: propostas, contratos, cobrancas, documentos, equipe, relatorios/exportacoes e configuracoes. As migrações seguem o padrao modular da feature 004 para facilitar revisao e permitir tarefas paralelas por dominio.

## Phase 0 Research

Gerado em [research.md](./research.md). Decisoes principais:

- `reference/legacy-html/` e fonte primaria de tela; `docs/telas.md` e auxiliar.
- `lancamentos` permanece a fonte financeira canonica; contas a pagar/receber e fluxo de caixa sao projecoes/RPCs sobre ela.
- RPCs publicas devem ter grants explicitos e validacao interna de `auth.uid()`/RBAC, considerando mudancas recentes da Data API do Supabase.
- Integracoes externas ausentes nao serao simuladas; ficarao como pendentes/indisponiveis.
- `cobrancas` e modulo compartilhado: Comercial controla origem/relacionamento/lembretes; Financeiro controla pagamento/conciliacao; Administrador cobre ambos.
- `alocacoes_projeto` segue como autorizacao minima do Tecnico; `alocacoes_equipe` cobre capacidade e historico operacional.
- Requisitos de acessibilidade, responsividade, empty states por tipo de secao, recovery e performance por familia de rota fazem parte do escopo de tarefas.

## Phase 1 Design

Artefatos gerados:

- [data-model.md](./data-model.md)
- [contracts/financeiro-rpc.md](./contracts/financeiro-rpc.md)
- [contracts/comercial-rpc.md](./contracts/comercial-rpc.md)
- [contracts/equipe-rpc.md](./contracts/equipe-rpc.md)
- [contracts/relatorios-configuracoes-rpc.md](./contracts/relatorios-configuracoes-rpc.md)
- [contracts/ui-routes.md](./contracts/ui-routes.md)
- [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

| Diretriz de fato | Status | Resultado apos design |
|------------------|--------|-----------------------|
| Documentar `.sauron` e `.agents` | Pass | Plano e decisao de referencia visual documentados. |
| Stack Vite + React | Pass | Estrutura de paginas/services/types definida. |
| Supabase/Postgres com RLS | Pass | Data model exige RLS e grants explicitos. |
| RPC-first | Pass | Contratos definem RPCs por dominio; frontend nao consulta tabela direta. |
| Sem dados mockados | Pass | Quickstart valida ausencia de mock e estados vazios. |
| Sem backend custom | Pass | Toda logica de dados fica em Postgres/Supabase. |

## Complexity Tracking

> Nenhuma violacao identificada na fase de planejamento.
