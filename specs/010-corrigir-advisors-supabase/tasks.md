# Tasks: Corrigir Advisors Supabase

**Input**: Design documents from `/specs/010-corrigir-advisors-supabase/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`

**Tests**: Esta feature exige ampliacao de cobertura pgTAP e validacoes finais (`npm run db:test`, `npm run test`, `npm run build`, `npm run audit`) porque o plano explicita testes de grants, RLS, RPC e nao-regressao.

**Organization**: Tasks agrupadas por user story para permitir implementacao incremental, testes independentes e validacao remota auditavel.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependencia direta)
- **[Story]**: User story associada (`US1`, `US2`, `US3`)
- Toda task inclui caminho(s) concreto(s) de arquivo

## Phase 1: Setup (Baseline e Scaffolding)

**Purpose**: Congelar o baseline remoto e preparar os arquivos versionados que receberao as correcoes

- [X] T001 Normalizar as linhas agrupadas de `SECURITY DEFINER` em uma linha por assinatura exata em `specs/010-corrigir-advisors-supabase/triagem.md`
- [X] T002 Registrar o baseline remoto objetivo via MCP do Supabase (`get_project_url`, `get_advisors(type=security)`, `get_advisors(type=performance)`, `list_migrations`) em `specs/010-corrigir-advisors-supabase/triagem.md` — nao usar Supabase CLI para capturar o baseline.
- [X] T003 Criar a migration de remediacao de seguranca em `supabase/migrations/20260707000001_010_advisors_security.sql`
- [X] T004 [P] Criar a migration de remediacao de performance em `supabase/migrations/20260707000002_010_advisors_performance.sql`

---

## Phase 2: Foundational (Prerequisitos Bloqueantes)

**Purpose**: Preparar a matriz de triagem, a cobertura base de testes e o inventario de dependencias vivas antes de alterar grants ou policies

**⚠️ CRITICAL**: Nenhuma remediacao de user story deve comecar antes do fechamento desta fase

- [X] T005 [P] Adicionar helpers reutilizaveis de assert de grants e presenca de policy em `supabase/tests/000_helpers.sql`
- [X] T006 [P] Expandir a varredura de rejeicao anonima para assinaturas `SECURITY DEFINER` em `supabase/tests/01_anon_rejeitado.sql`
- [X] T007 [P] Expandir fixtures e asserts de tabela service-owned em `supabase/tests/05_capacidades.sql`
- [X] T008 Inventariar os chamadores vivos em `src/services/auth.service.ts`, `src/services/clientes.service.ts`, `src/services/comercial.service.ts`, `src/services/configuracoes.service.ts`, `src/services/dashboard.service.ts`, `src/services/equipe.service.ts`, `src/services/financeiro.service.ts`, `src/services/projetos.service.ts`, `src/services/relatorios.service.ts` e `supabase/functions/relatorios-exportacao/index.ts`, registrando o resultado em `specs/010-corrigir-advisors-supabase/triagem.md`
- [X] T009 Definir a matriz esperada por assinatura, disposicao inicial e candidatas a excecao em `specs/010-corrigir-advisors-supabase/triagem.md`

**Checkpoint**: Baseline, matriz de triagem e harness de teste prontos; US1 e US2 podem iniciar

---

## Phase 3: User Story 1 - Fechar exposicoes indevidas detectadas pelos advisors (Priority: P1) 🎯 MVP

**Goal**: Eliminar exposicoes indevidas em funcoes privilegiadas e fechar o caso de RLS sem policy em `public.capacidades_perfil`

**Independent Test**: Aplicar apenas a migration de seguranca em ambiente controlado e confirmar via pgTAP + advisors que `public.capacidades_perfil` nao fica sem policy e que funcoes fora da matriz esperada deixam de estar expostas a `anon` ou a grants excessivos

### Tests for User Story 1

- [X] T010 [US1] Adicionar cobertura pgTAP para a policy service-owned de `public.capacidades_perfil` em `supabase/tests/05_capacidades.sql`
- [X] T011 [P] [US1] Adicionar cobertura pgTAP de negacao por assinatura exata para exposicoes indevidas a `anon` em `supabase/tests/01_anon_rejeitado.sql`
- [X] T012 [P] [US1] Adicionar cobertura pgTAP para a excecao intencional de `public.registrar_evento_auditoria(text, text, text)` em `supabase/tests/03_auditoria.sql`
- [X] T031 [P] [US1] Adicionar cobertura pgTAP para garantir que `service_role` mantem acesso a objetos service-owned (`public.capacidades_perfil` e funcoes internas preservadas) sem indevida restricao causada pela migration de seguranca em `supabase/tests/05_capacidades.sql`

### Implementation for User Story 1

- [X] T013 [US1] Implementar a policy explicita service-owned de `public.capacidades_perfil` em `supabase/migrations/20260707000001_010_advisors_security.sql`
- [X] T014 [US1] Revogar grants residuais de `anon` por assinatura exata em `supabase/migrations/20260707000001_010_advisors_security.sql`
- [X] T015 [US1] Reassertar grants minimos de `authenticated` por assinatura exata em `supabase/migrations/20260707000001_010_advisors_security.sql`
- [X] T016 [US1] Endurecer funcoes `SECURITY DEFINER` preservadas com guardas explicitas de identidade, papel, capacidade ou ownership em `supabase/migrations/20260707000001_010_advisors_security.sql`
- [X] T017 [US1] Registrar a classificacao final por assinatura, excecoes aprovadas e evidencias de dependencia viva em `specs/010-corrigir-advisors-supabase/triagem.md`

**Checkpoint**: User Story 1 funcional; nenhum objeto no escopo de seguranca deve permanecer como `risco_real` sem acao concreta

---

## Phase 4: User Story 2 - Reduzir warnings de performance que afetam RLS e RPC (Priority: P2)

**Goal**: Remover warnings `auth_rls_initplan` e `multiple_permissive_policies` no escopo da feature sem afrouxar RBAC ou ownership

**Independent Test**: Aplicar apenas a migration de performance em ambiente controlado e confirmar via pgTAP + advisors que os objetos no escopo deixam de sinalizar os warnings ou ficam explicitamente justificados, sem regressao de leitura/escrita

### Tests for User Story 2

- [X] T018 [US2] Adicionar cobertura pgTAP para o comportamento consolidado de `SELECT` e `UPDATE` em `public.perfis` em `supabase/tests/02_rbac_por_perfil.sql`
- [X] T019 [US2] Adicionar cobertura pgTAP para policies convertidas ao padrao `(select auth.uid())` em `supabase/tests/02_rbac_por_perfil.sql`

### Implementation for User Story 2

- [X] T020 [US2] Reescrever predicates RLS no escopo para evitar reavaliacao por linha de `auth.uid()` em `supabase/migrations/20260707000002_010_advisors_performance.sql`
- [X] T021 [US2] Consolidar policies permissivas de `public.perfis` para `SELECT` e `UPDATE` em `supabase/migrations/20260707000002_010_advisors_performance.sql`
- [X] T022 [US2] Atualizar a classificacao e a evidencia de nao-regressao dos achados `auth_rls_initplan` e `multiple_permissive_policies` em `specs/010-corrigir-advisors-supabase/triagem.md`

**Checkpoint**: User Story 2 funcional; os warnings de performance no escopo devem estar resolvidos ou formalmente classificados

---

## Phase 5: User Story 3 - Validar o estado remoto apos a correcao (Priority: P3)

**Goal**: Executar uma rodada repetivel de validacao remota que diferencie correcao efetiva, drift remoto, concessao residual e excecao intencional

**Independent Test**: Seguir `runbook-validacao.md` do baseline ao pos-aplicacao e obter classificacao final para todos os achados remanescentes no escopo

### Implementation for User Story 3

- [X] T023 [P] [US3] Alinhar os passos do `runbook-validacao.md` para execucao via MCP do Supabase (sem Supabase CLI), incluindo os comandos MCP esperados (`get_project_url`, `get_advisors`, `list_migrations`) e a matriz por assinatura.
- [X] T024 [P] [US3] Alinhar o fluxo local/remoto de validacao e gates finais em `specs/010-corrigir-advisors-supabase/quickstart.md`
- [X] T025 [US3] Registrar snapshots baseline, expected state e post-apply via MCP do Supabase em `specs/010-corrigir-advisors-supabase/triagem.md`.
- [X] T026 [US3] Classificar achados remanescentes e fechar a rodada usando os snapshots obtidos via MCP do Supabase em `specs/010-corrigir-advisors-supabase/triagem.md` e `specs/010-corrigir-advisors-supabase/runbook-validacao.md`.
- [X] T027 [US3] Registrar a decisao operacional final em `.agents/project-memory/010-corrigir-advisors-supabase.md` e `.sauron/wiki/knowledge/architecture.md`
- [X] T032 [US3] Definir e documentar em `specs/010-corrigir-advisors-supabase/runbook-validacao.md` os gatilhos de reavaliacao de excecoes (mudanca de grant, policy, assinatura, dependencia viva, regra RBAC/Auth ou novo achado relacionado) e o responsavel pela reavaliacao, atendendo FR-019

**Checkpoint**: User Story 3 funcional; a validacao remota consegue explicar cada persistencia sem ambiguidade

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Consolidar evidencias, gates finais e consistencia documental entre backend, runbook e memoria obrigatoria

- [X] T028 Rodar `npm run db:test` e anexar o resultado em `.agents/project-memory/010-corrigir-advisors-supabase.md`
- [X] T029 Rodar `npm run test`, `npm run build` e `npm run audit`, coletar as evidencias de nao-regressao (nenhum novo teste de seguranca/RLS quebrado; nenhum teste de autorizacao revertido; build sem erros; audit sem novos warnings de seguranca) e anexar o resultado em `.agents/project-memory/010-corrigir-advisors-supabase.md`.
- [X] T030 Reconciliar a documentacao final entre `specs/010-corrigir-advisors-supabase/spec.md`, `specs/010-corrigir-advisors-supabase/plan.md`, `specs/010-corrigir-advisors-supabase/triagem.md`, `specs/010-corrigir-advisors-supabase/runbook-validacao.md` e `specs/010-corrigir-advisors-supabase/quickstart.md`
- [X] T033 [Polish] Registrar em `specs/010-corrigir-advisors-supabase/triagem.md` e `specs/010-corrigir-advisors-supabase/quickstart.md` quais lints de tuning geral (`unindexed_foreign_keys`, `unused_index` e similares) foram explicitamente excluidos do escopo da feature, conforme FR-008

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1: Setup**: sem dependencias; inicia imediatamente
- **Phase 2: Foundational**: depende da Setup; bloqueia US1, US2 e US3
- **Phase 3: US1**: depende da Foundational
- **Phase 4: US2**: depende da Foundational
- **Phase 5: US3**: depende da conclusao de US1 e US2, porque a validacao remota exige o conjunto final de migrations e classificacoes
- **Phase 6: Polish**: depende das user stories que serao entregues nesta rodada

### User Story Dependencies

- **US1 (P1)**: pode comecar assim que a matriz de triagem e o harness de teste estiverem prontos; nao depende de US2
- **US2 (P2)**: pode comecar assim que a matriz de triagem e o harness de teste estiverem prontos; nao depende de US1, mas compartilha a necessidade de manter `triagem.md` consistente
- **US3 (P3)**: depende de US1 e US2 porque mede o estado remoto apos as correcoes de grants e policies

### Within Each User Story

- Testes pgTAP devem ser escritos antes das mudancas de migration correspondentes
- `triagem.md` deve refletir a matriz por assinatura antes de qualquer classificacao final
- Cada migration deve permanecer focada em um tipo de remediacao: seguranca em `20260707000001_010_advisors_security.sql`, performance em `20260707000002_010_advisors_performance.sql`
- Nenhuma excecao pode fechar um achado sem justificativa, impacto, gatilho de revisao, responsavel e aprovador

### Parallel Opportunities

- `T003` e `T004` podem ser executadas em paralelo
- `T005`, `T006` e `T007` podem ser executadas em paralelo
- `T011` e `T012` podem ser executadas em paralelo
- `T023` e `T024` podem ser executadas em paralelo
- US1 e US2 podem ser implementadas em paralelo por pessoas diferentes apos a Foundational, desde que coordenem atualizacoes em `specs/010-corrigir-advisors-supabase/triagem.md`

---

## Parallel Example: User Story 1

```bash
# Testes independentes de seguranca:
Task: "Adicionar cobertura pgTAP de negacao por assinatura exata para exposicoes indevidas a anon em supabase/tests/01_anon_rejeitado.sql"
Task: "Adicionar cobertura pgTAP para a excecao intencional de public.registrar_evento_auditoria(text, text, text) em supabase/tests/03_auditoria.sql"
```

## Parallel Example: Foundational

```bash
# Harness base antes das migrations:
Task: "Adicionar helpers reutilizaveis de assert de grants e presenca de policy em supabase/tests/000_helpers.sql"
Task: "Expandir a varredura de rejeicao anonima para assinaturas SECURITY DEFINER em supabase/tests/01_anon_rejeitado.sql"
Task: "Expandir fixtures e asserts de tabela service-owned em supabase/tests/05_capacidades.sql"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational
3. Completar Phase 3: US1
4. Validar US1 com pgTAP e advisors antes de avancar

### Incremental Delivery

1. Setup + Foundational fecham baseline, matriz por assinatura e harness
2. US1 fecha exposicoes indevidas e o caso de `public.capacidades_perfil`
3. US2 reduz warnings de performance sem mudar autorizacao
4. US3 confirma o estado remoto e fecha classificacoes residuais
5. Polish consolida evidencias e documentacao obrigatoria

### Parallel Team Strategy

1. Uma pessoa fecha Setup + Foundational
2. Depois:
   - Pessoa A: US1 (migration de seguranca + testes correlatos)
   - Pessoa B: US2 (migration de performance + testes correlatos)
3. Com US1 e US2 concluidas, uma terceira rodada fecha US3 e o Polish

---

## Notes

- `[P]` significa arquivos diferentes e ausencia de dependencia direta
- As tasks de migration assumem criacao via `supabase migration new`, mas o conteudo final deve ficar nos arquivos nomeados acima
- `triagem.md` e a fonte canonica para baseline, matriz por assinatura, classificacao residual e evidencias remotas
- `.agents` e `.sauron` devem ser atualizados na mesma sessao que concluir a rodada operacional
