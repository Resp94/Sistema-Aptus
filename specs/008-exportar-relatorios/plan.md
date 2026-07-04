# Implementation Plan: Exportar Relatorios

**Branch**: `008-exportar-relatorios` | **Date**: 2026-07-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-exportar-relatorios/spec.md`

## Summary

Implementar exportacao real e imediata de relatorios completos na pagina Relatorios, em PDF e CSV, sempre para a categoria selecionada e para um periodo informado. O fluxo tecnico sera centralizado em uma Supabase Edge Function (`relatorios-exportacao`) que valida o JWT do usuario, chama RPCs com autorizacao por capacidades, gera o arquivo, salva em Storage privado, registra o historico e retorna um link assinado temporario para download imediato. O historico usara os mesmos contratos de autorizacao para permitir re-download por 12 meses: Administrador acessa exportacoes validas de todos; Financeiro e Projetos apenas as proprias; Visualizador, Comercial e Tecnico nao exportam.

## Technical Context

**Language/Version**: TypeScript no frontend Vite/React e Supabase Edge Functions em TypeScript/Deno; SQL PostgreSQL para schema, RLS e RPCs.

**Primary Dependencies**: React 19, Vite, `@supabase/supabase-js`, Supabase CLI, PostgreSQL/RLS/RPCs, Supabase Storage, `pdf-lib` para PDF, `fflate` para ZIP e serializador CSV interno.

**Storage**: PostgreSQL para historico em `public.exportacoes_relatorios`; Storage privado no bucket `relatorios-exportados` para PDF e ZIP CSV; sem URL publica permanente.

**Testing**: pgTAP via `npm run db:test`, Vitest via `npm run test`, build via `npm run build`, auditoria via `npm run audit`, e validacao manual/local da Edge Function com `supabase functions serve`.

**Target Platform**: SPA web Vite/React hospedada em Cloudflare Pages; backend Supabase local/cloud com Edge Functions, Postgres e Storage.

**Project Type**: Web application com frontend React, backend Supabase RPC-first e funcao serverless para geracao de arquivos.

**Performance Goals**: 100% das exportacoes bem-sucedidas retornam download imediato em ate 10 segundos para volumes operacionais comuns, definidos como ate 5.000 linhas detalhadas ou 10 MB antes de compressao; historico ordenado por solicitacoes recentes; download posterior deve depender apenas de autorizacao e assinatura temporaria.

**Constraints**: Exportacao limitada a periodo maximo de 12 meses com datas inclusivas (`2026-01-01` a `2026-12-31` permitido; `2026-01-01` a `2027-01-01` bloqueado); arquivos validos por 12 meses a partir da geracao; signed URLs curtos e gerados sob demanda; service role nunca exposto ao navegador; RPCs validam `auth.uid()` e `tem_capacidade('relatorios.exportar')`; nao usar links publicos permanentes; Edge Function deve ser curta/idempotente e sem chamadas recursivas/nested a Edge Functions.

**Scale/Scope**: Exportacao inicial somente para Financeiro, DRE, Clientes e Projetos. `Personalizado` fica fora do escopo 008 ate possuir contrato completo proprio. Uma exportacao por solicitacao; duplicadas sao permitidas como eventos separados.

**Environment Notes**: Supabase CLI local verificado em `2.75.0`; a CLI informou versao mais nova `2.109.0`. Antes da implementacao, conferir `supabase functions --help` e considerar upgrade para alinhar recursos locais, especialmente comandos de functions e advisors.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Spec-driven delivery**: PASS. A feature tem spec, checklist e decisoes de clarificacao antes do plano.
- **RPC-first / backend authorization**: PASS. A UI somente inicia fluxos; geracao, autorizacao e download historico dependem de RPCs e Edge Function autenticada.
- **RBAC by named capabilities**: PASS. Exportacao usa `relatorios.exportar`; leitura de Relatorios continua separada da extracao de arquivos.
- **No mock success**: PASS. A implementacao deve gerar arquivo real, persistir Storage e registrar status `Pronto` somente apos upload concluido.
- **Auditability/documentation**: PASS. Planejamento registra arquitetura e regras em `specs/`, `.agents/` e `.sauron/`.
- **Supabase security**: PASS. Arquivos ficam em bucket privado, Storage usa RLS/politicas, e service role fica restrito ao ambiente da funcao.

**Re-check after Phase 1 design**: PASS. Os artefatos de modelo, contratos e quickstart preservam os gates acima e nao introduzem excecoes de complexidade.

## Project Structure

### Documentation (this feature)

```text
specs/008-exportar-relatorios/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── edge-function-exportacao.md
│   ├── rpc-exportacao-relatorios.md
│   ├── storage-and-retention.md
│   ├── frontend-relatorios.md
│   └── audit-and-tests.md
└── tasks.md              # Criado depois por /speckit-tasks
```

### Source Code (repository root)

```text
src/
├── pages/
│   └── RelatoriosPage.tsx
├── services/
│   ├── relatorios.service.ts
│   └── supabase.ts
├── types/
│   ├── relatorios.ts
│   └── common.ts
└── test/

supabase/
├── functions/
│   └── relatorios-exportacao/
│       └── index.ts
├── migrations/
│   └── [timestamp]_exportar_relatorios.sql
└── tests/
    └── 008_exportar_relatorios.sql
```

**Structure Decision**: Manter a arquitetura atual Vite/React + Supabase. O frontend concentra UX e download; a Edge Function concentra geracao de arquivo e assinatura de Storage; as RPCs concentram leitura completa, autorizacao e transicoes de historico.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Edge Function alem de RPCs | Geracao de PDF/ZIP e upload privado exigem ambiente server-side com segredo de Storage | Gerar no navegador exporia dados/contratos, dificultaria historico confiavel e nao permitiria service role seguro |
| Bucket privado com links assinados | Relatorios sao artefatos sensiveis e precisam de re-download temporario | `arquivo_url` publico permanente viola FR-021 e nao permite expirar acesso corretamente |

## Closed Checklist Decisions

- **Categorias exportaveis**: Financeiro, DRE, Clientes e Projetos. `Personalizado` permanece apenas leitura/preview quando existente, sem exportacao 008.
- **Fonte canonica**: `listar_categorias_relatorios` continua fonte de leitura/preview; a exportacao adiciona helper/RPC de categoria exportavel por persona derivada da mesma matriz.
- **Escopo por persona**: Administrador exporta as quatro categorias; Financeiro exporta Financeiro e DRE; Projetos exporta Projetos; Visualizador, Comercial e Tecnico nao exportam nem baixam historico.
- **Conteudo completo**: cada categoria possui resumo executivo e linhas detalhadas definidas em `spec.md` e `data-model.md`; preview nunca e fonte suficiente para arquivo exportado.
- **Periodo**: datas inclusivas; um dia e permitido; `2026-01-01` a `2026-12-31` permitido; `2026-01-01` a `2027-01-01` bloqueado.
- **Performance**: volume operacional comum e ate 5.000 linhas detalhadas ou 10 MB antes de compressao.
- **Bibliotecas**: `pdf-lib` para PDF, `fflate` para ZIP e serializador CSV interno.
- **Acessibilidade/responsividade**: modal e historico devem atender teclado, labels, foco, Esc, status nao apenas por cor e largura minima de 320px.
- **Observabilidade**: registrar `exportacao_id`, usuario, categoria, formato, periodo, status, duracao, tamanho e erro sanitizado.
- **RPC legada**: `solicitar_exportacao_relatorio` nao sera usada pelo frontend novo; permanece apenas compatibilidade legada sem sucesso simulado.

## Phase 0 Output

Pesquisa registrada em [research.md](./research.md), cobrindo Edge Functions, Storage/RLS, historico, validade, status, CSV ZIP, periodo por categoria e limites da Supabase CLI local.

## Phase 1 Output

- Modelo de dados: [data-model.md](./data-model.md)
- Contrato da Edge Function: [contracts/edge-function-exportacao.md](./contracts/edge-function-exportacao.md)
- Contrato das RPCs: [contracts/rpc-exportacao-relatorios.md](./contracts/rpc-exportacao-relatorios.md)
- Contrato Storage/retencao: [contracts/storage-and-retention.md](./contracts/storage-and-retention.md)
- Contrato frontend: [contracts/frontend-relatorios.md](./contracts/frontend-relatorios.md)
- Contrato de auditoria/testes: [contracts/audit-and-tests.md](./contracts/audit-and-tests.md)
- Quickstart: [quickstart.md](./quickstart.md)

## Phase 2 Direction

`/speckit-tasks` deve gerar tarefas test-first para:

1. Criar migracao de schema/RLS/RPCs e bucket privado.
2. Cobrir RBAC e ownership com pgTAP por persona.
3. Implementar Edge Function com `gerar` e `download`.
4. Atualizar service/types e pagina Relatorios com datas, PDF/CSV, estados e historico.
5. Validar CSV ZIP, PDF completo, expiracao, falha e sem dados.
6. Rodar `npm run db:test`, `npm run test`, `npm run build` e `npm run audit`.
