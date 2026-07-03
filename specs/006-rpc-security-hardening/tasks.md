---
description: "Task list for RPC Security Hardening"
---

# Tasks: Hardening de Segurança das RPCs e Padronização Retroativa do Banco

**Input**: Design documents from `/specs/006-rpc-security-hardening/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: A suíte pgTAP e os scripts de auditoria **são deliverables explícitos** desta feature (FR-012–FR-016, User Story 5) e aparecem como tarefas de implementação na Fase 7 — não como testes TDD opcionais. Cada história P1/P2 tem uma tarefa de validação via [quickstart.md](./quickstart.md).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: A qual user story a tarefa pertence (US1..US6)
- Caminhos de arquivo são absolutos a partir da raiz do repositório

## Convenções de caminho

- Migrations: `supabase/migrations/`
- Testes de banco (pgTAP): `supabase/tests/`
- Scripts de auditoria: `scripts/`
- CI: `.github/workflows/`
- Diretrizes: `docs/`
- Cliente: `src/`

⚠️ **Restrição de arquivo compartilhado**: US1, US2 e US3 escrevem SQL na **mesma** migration da Fase 0 (`20260702000002_security_hardening_fase0.sql`). Por isso o arquivo é criado na fase Foundational (T004) e as tarefas SQL dele são **sequenciais** (nunca `[P]` entre si). Cada história continua **testável independentemente** após sua parte ser aplicada.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Estrutura e scripts npm compartilhados por várias histórias.

- [X] T001 [P] Adicionar scripts npm (`db:test`, `audit:rpc`, `audit:from`, `audit:metadata`, `audit`) em `package.json` conforme [contracts/ci-and-audit.md](./contracts/ci-and-audit.md)
- [X] T002 [P] Criar diretório `scripts/` (placeholder `.gitkeep` se necessário)
- [X] T003 [P] Criar diretório `supabase/tests/` (placeholder `.gitkeep` se necessário)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Artefato compartilhado pelas três histórias P1.

**⚠️ CRITICAL**: A migration da Fase 0 é escrita por US1, US2 e US3. Criar o arquivo primeiro evita conflitos e fixa a ordem de edição.

- [X] T004 Criar a migration da Fase 0 vazia com cabeçalho em `supabase/migrations/20260702000002_security_hardening_fase0.sql` (comentário de escopo: FR-001, FR-003/003a/003b, FR-004/005/006, FR-007, FR-007a)

**Checkpoint**: Arquivo da Fase 0 pronto para receber as correções críticas.

---

## Phase 3: User Story 1 - Eliminar a criação anônima de administradores (Priority: P1) 🎯 MVP

**Goal**: Remover `criar_perfil_teste` de produção sem quebrar o seed local.

**Independent Test**: `to_regprocedure('public.criar_perfil_teste(text,text,text,text)')` retorna NULL após reset; `npm run supabase:reset` cria as 6 personas.

- [X] T005 [US1] Adicionar `DROP FUNCTION IF EXISTS public.criar_perfil_teste(text,text,text,text);` na migration `supabase/migrations/20260702000002_security_hardening_fase0.sql` (depende de T004)
- [X] T006 [US1] Refatorar `supabase/seed.sql`: definir `criar_perfil_teste` de forma efêmera no início do bloco de seed, manter as 6 chamadas de persona existentes e `DROP` a função ao final — garantindo que o `DROP` execute mesmo em caso de erro (ver [research.md](./research.md) item 11)
- [X] T007 [US1] Validar US1 via [quickstart.md](./quickstart.md) passos 1–2 (reset cria personas; `to_regprocedure` NULL) — confirmado via `npx supabase db reset` (6 personas) + `to_regprocedure('public.criar_perfil_teste(text,text,text,text)')` retornando NULL

**Checkpoint**: A vulnerabilidade crítica (criação anônima de admin) está fechada e o fluxo local intacto.

---

## Phase 4: User Story 2 - Impedir falsificação da trilha de auditoria (Priority: P1)

**Goal**: Recriar `registrar_evento_auditoria` com autor forçado pela sessão, whitelist anônima fechada e sem parâmetro de autor.

**Independent Test**: anônimo grava `login_falha` (autor nulo); anônimo é rejeitado em evento fora da whitelist; autenticado não consegue atribuir evento a terceiro.

- [X] T008 [US2] Na migration `supabase/migrations/20260702000002_security_hardening_fase0.sql`, recriar `registrar_evento_auditoria(p_evento text, p_ip_origem text, p_user_agent text)` conforme [contracts/rpc-signatures.md](./contracts/rpc-signatures.md): `SET search_path`, whitelist fechada `['login_falha']` (autor nulo), autor = `auth.uid()` quando autenticado, `Unauthorized` caso contrário, `REVOKE ... FROM PUBLIC` + `GRANT ... TO anon, authenticated` (depende de T004; sequencial após T005)
- [X] T009 [P] [US2] Ajustar `src/services/auth.service.ts`: remover `p_usuario_id` das chamadas `login_falha` (~linha 55) e `login_sucesso` (~linha 88)
- [X] T010 [P] [US2] Ajustar `src/pages/ResetPassword.tsx`: remover `p_usuario_id` da chamada `senha_alterada` (~linha 69)
- [X] T011 [US2] Validar US2: registrar `login_falha` anônimo (autor nulo), evento anônimo fora da whitelist rejeitado, e tentativa autenticada de forjar autor grava `auth.uid()` — confirmado via `supabase/tests/03_auditoria.sql` (5/5 subtestes passando)

**Checkpoint**: Trilha de auditoria não-falsificável; cliente continua registrando eventos com a nova assinatura.

---

## Phase 5: User Story 3 - Impedir escalação de privilégio no cadastro (Priority: P1)

**Goal**: Corrigir o trigger de cadastro para sempre atribuir `Visualizador`, fixar `search_path` nos dois triggers e endurecer `existe_perfil_admin`.

**Independent Test**: cadastro com metadata `perfil_acesso='Administrador'` resulta em `Visualizador`; nome/departamento preservados; promoção admin via `atualizar_usuario_perfil` continua funcionando.

- [X] T012 [US3] Na migration da Fase 0, recriar `handle_auth_user_sync`: `perfil_acesso := 'Visualizador'` fixo (nunca de `raw_user_meta_data`), preservar nome/departamento, adicionar `SET search_path = public` (FR-004/006; depende de T004; sequencial após T008)
- [X] T013 [US3] Na migration da Fase 0, recriar `validar_perfil_update` apenas para adicionar `SET search_path = public`, preservando a guarda de contexto de sistema (`auth.uid() IS NULL → RETURN new`) exigida pelo seed (FR-007a; sequencial após T012)
- [X] T014 [US3] Na migration da Fase 0, endurecer `existe_perfil_admin(uuid)`: `SET search_path = public` + `REVOKE ... FROM PUBLIC` + `GRANT ... TO authenticated` (FR-007; sequencial após T013)
- [X] T015 [US3] Validar US3: simular cadastro com metadata privilegiada → perfil `Visualizador`; confirmar promoção via `atualizar_usuario_perfil` por admin — confirmado via `supabase/tests/04_signup_sem_escalacao.sql` (3/3). **Nota (FR-005)**: `atualizar_usuario_perfil` já existe e já cumpre o padrão (admin-only via `existe_perfil_admin`, `search_path`, `REVOKE`/`GRANT`) — FR-005 é um invariante existente e **não requer código novo** além de um bugfix pontual (referência a `departamento` inexistente em `auth.users`, achado pelo `db lint` e corrigido usando o valor antigo já lido de `public.perfis`)

**Checkpoint**: Fase 0 completa — todas as correções críticas na migration `20260702000002`. As 3 vulnerabilidades P1 estão fechadas.

---

## Phase 6: User Story 4 - Padronizar as 26 funções legadas sem quebrar o cliente (Priority: P2)

**Goal**: Alinhar as 26 funções antigas ao padrão de guardrails sem mudar assinatura/comportamento para chamadores legítimos.

**Independent Test**: cada função apresenta `search_path` fixo, `REVOKE`/`GRANT` e guarda `auth.uid()`; telas de clientes/projetos/dashboard funcionam idênticas; anônimo recebe `Unauthorized` explícito.

- [X] T016 [US4] Criar a migration da Fase 1 `supabase/migrations/20260702000003_security_hardening_padronizacao.sql` com cabeçalho de escopo (FR-008/009/010/011)
- [X] T017 [US4] Padronizar as funções de **clientes** (`listar_clientes`, `criar_cliente`, `atualizar_cliente`, `inativar_cliente`, `registrar_atendimento`, `obter_cliente_detalhe`, `obter_estatisticas_clientes`) na migration da Fase 1: `CREATE OR REPLACE` idêntico + `SET search_path` + guarda `Unauthorized` + `REVOKE`/`GRANT` (sequencial após T016)
- [X] T018 [US4] Padronizar as funções de **projetos/tarefas** (`criar_projeto`, `atualizar_projeto`, `excluir_projeto`, `criar_tarefa`, `atualizar_tarefa`, `mover_tarefa`, `excluir_tarefa`, `listar_projetos`, `listar_tarefas_kanban`, `obter_resumo_projetos`, `obter_distribuicao_clientes`) na migration da Fase 1 (sequencial após T017)
- [X] T019 [US4] Padronizar as funções de **dashboard** (`obter_metricas_dashboard`, `obter_fluxo_caixa_mensal`, `obter_composicao_receita`, `listar_ultimos_lancamentos`, `listar_contas_pagar_proximas`) na migration da Fase 1 (sequencial após T018)
- [X] T020 [US4] Padronizar os **helpers de permissão/perfil** (`permissao_modulo`, `obter_permissoes_usuario`, `obter_perfil_usuario`) na migration da Fase 1, mantendo `SET row_security = off` e sem exigir `permissao_modulo` no corpo (ver [contracts/guardrail-standard.md](./contracts/guardrail-standard.md); sequencial após T019)
- [X] T021 [US4] Validar US4: telas de clientes/projetos/dashboard inalteradas para um perfil com permissão; anônimo recebe `Unauthorized` explícito (base para [quickstart.md](./quickstart.md) passo 4) — validado via Playwright: `/clientes` (Comercial) e `/dashboard`+`/projetos` (Administrador) renderizam dados reais sem erro de RPC; `/dashboard` bloqueado para Comercial (redirect para `/clientes`); rota protegida sem sessão redireciona para `/login`

**Checkpoint**: Todas as funções legadas no padrão; contrato do cliente preservado (SC-008).

---

## Phase 7: User Story 5 - Travar o padrão contra regressões futuras (Priority: P2)

**Goal**: Scripts de auditoria estática, suíte pgTAP por perfil e pipeline de CI que reprova regressões.

**Independent Test**: injetar uma função sem guardrails → auditoria falha; injetar `supabase.from()` em serviço de domínio → falha; suíte pgTAP verde cobrindo os 6 perfis.

**⚠️ Dependência**: Esta história só passa em verde após US1–US4 aplicadas.

- [X] T022 [P] [US5] Implementar `scripts/audit-rpc.mjs` (extrai funções das migrations e valida os 5 guardrails com allowlists de trigger/auditoria/helpers) conforme [contracts/guardrail-standard.md](./contracts/guardrail-standard.md). **Aceitação**: o script MUST honrar `DROP FUNCTION [IF EXISTS]` como remoção (excluir a função da contagem e das checagens), de modo que `criar_perfil_teste` não seja contada e o alvo resolva para 80/80 — allowlist ampliada para incluir `atualizar_usuario_perfil` como admin-gated (guardado por `existe_perfil_admin`, não por `permissao_modulo`; ver contracts/guardrail-standard.md)
- [X] T023 [P] [US5] Implementar `scripts/check-no-from.mjs` (reprova `supabase.from(` em `src/services/**`, allowlist `health-check.ts`) — FR-013
- [X] T024 [P] [US5] Implementar `scripts/check-no-user-metadata.mjs` com allowlist explícita de ocorrências legítimas (ver [contracts/ci-and-audit.md](./contracts/ci-and-audit.md)) — FR-014
- [X] T025 [US5] Criar `supabase/tests/00_helpers.sql` com `set_auth(uuid)` / `set_anon()` / `reset_auth()` conforme [research.md](./research.md) item 2 — acrescentado `set_auth_by_email(text)` (sem `SECURITY DEFINER`, que é proibido junto de `SET ROLE` e faria o helper ser varrido pelo teste de catálogo) para resolver o UUID com `RESET` prévio, evitando que a troca de role de uma persona anterior bloqueasse a leitura de `auth.users` da próxima
- [X] T026 [P] [US5] Criar `supabase/tests/01_anon_rejeitado.sql`: teste guiado por `pg_proc` (só `SECURITY DEFINER`, exclui triggers e `registrar_evento_auditoria`), anônimo recebe `Unauthorized` (FR-016; depende de T025) — corrigido para comparar apenas o SQLSTATE 42501 via `throws_ok(sql, '42501')`; a maioria das funções (GRANT só a `authenticated`) é barrada pelo Postgres antes do corpo rodar, com a mensagem nativa "permission denied for function X", não o texto customizado — 77/77 passando
- [X] T027 [P] [US5] Criar `supabase/tests/02_rbac_por_perfil.sql`: matriz dos 6 perfis comparada com `obter_permissoes_usuario`; escrita sem `pode_escrever` falha (FR-015; depende de T025) — corrigido para usar `set_auth_by_email` em vez de `set_auth((SELECT id FROM auth.users WHERE email=...))`, que quebrava a partir da 2ª persona — 10/10 passando
- [X] T028 [P] [US5] Criar `supabase/tests/03_auditoria.sql`: whitelist anônima, autor forçado, falsificação rejeitada (SC-004; depende de T025) — corrigido para dar `reset_auth()` antes de ler `public.audit_log` diretamente (nem `anon` nem `authenticated` têm SELECT na tabela, por design RPC-first) — 5/5 passando
- [X] T029 [P] [US5] Criar `supabase/tests/04_signup_sem_escalacao.sql`: cadastro com metadata `Administrador` → `Visualizador` (SC-005; depende de T025) — corrigido para limpar o usuário fixo de teste antes de inserir (idempotência ao rodar `npm run db:test` mais de uma vez sem `db reset`) — 3/3 passando
- [X] T030 [US5] Criar `.github/workflows/ci.yml` com o pipeline ordenado (build → test → db lint → advisors → db test → audit) conforme [contracts/ci-and-audit.md](./contracts/ci-and-audit.md) (depende de T022–T029)
- [X] T031 [US5] Validar US5: `npm run audit` verde (80/80), `npm run db:test` verde, e prova de regressão ([quickstart.md](./quickstart.md) passo 5 — injetar função fora do padrão faz `audit:rpc` falhar; reverter) — confirmado: `npm run db:test` 96/96 (`Result: PASS`, exit 0, idempotente sem `db reset` prévio); regressão testada injetando `funcao_sem_guardrails_temp()` (reprovou com as 6 falhas esperadas) e revertendo (voltou a 80/80). Também corrigido: arquivos usavam `no_plan()` sem `finish()`, deixando o stream TAP incompleto e o `Result` sempre `FAIL` mesmo com todos os asserts passando — adicionado `SELECT * FROM finish();` nos 5 arquivos

**Checkpoint**: Regressões de padrão passam a ser bloqueadas no CI.

---

## Phase 8: User Story 6 - Registrar as diretrizes arquiteturais (Priority: P3)

**Goal**: Documentar as decisões arquiteturais para orientar trabalho futuro.

**Independent Test**: o documento existe e cobre RPC granular, agregadora rejeitada, views internas e armadilhas de RLS.

- [X] T032 [P] [US6] Criar `docs/arquitetura-dados.md` cobrindo: RPC granular como regra; agregadora por página descartada (permitida só por latência medida); views apenas como read models internos `security_invoker = true`; RLS por operação com as armadilhas (`UPDATE` exige `USING`+`WITH CHECK` e política de `SELECT`) — FR-018/019/020

**Checkpoint**: Diretrizes registradas; proposta da agregadora não retornará por engano.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Validação final ponta a ponta e lints nativos.

- [ ] T033 Rodar [quickstart.md](./quickstart.md) completo (7 passos) e confirmar todos os critérios de aceite — **pendente**: passos automatizáveis foram validados via `npm run audit`/`npm run db:test`, mas o roteiro completo (incluindo checagem visual das telas, passo 4) não foi percorrido manualmente no navegador
- [X] T034 [P] Rodar `npx supabase db lint` e `npx supabase db advisors` e confirmar ausência de findings de segurança nas funções/políticas alteradas (passo 6) — `db lint`: 0 erros (restam 2 warnings pré-existentes de parâmetro não usado, fora do escopo desta feature); `db advisors`: sem findings de segurança nas funções/políticas desta feature (os únicos warnings de SECURITY são nos helpers de teste `set_auth`/`set_anon`/`reset_auth`/`set_auth_by_email`, que não são RPCs expostas nem fazem parte das migrations); os warnings de PERFORMANCE (`auth_rls_initplan`, `multiple_permissive_policies`) são pré-existentes e fora do escopo desta feature. **Bug real corrigido nesse processo**: `atualizar_usuario_perfil` referenciava a coluna `departamento` (que não existe em `auth.users`) em vez do valor antigo lido de `public.perfis`
- [X] T035 [P] Rodar `npm run build && npm run test` e confirmar que os fluxos de login/senha gravam auditoria com a nova assinatura (passo 7 / SC-008) — build ok; 42/42 testes Vitest; a gravação de auditoria com a nova assinatura é coberta por `supabase/tests/03_auditoria.sql`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — pode começar imediatamente.
- **Foundational (Phase 2 / T004)**: depende do Setup; **bloqueia US1, US2, US3** (arquivo compartilhado da Fase 0).
- **US1 → US2 → US3 (Phases 3–5)**: escrevem no mesmo arquivo da Fase 0 → **sequenciais entre si** no SQL (T005 → T008 → T012 → T013 → T014). As tarefas de cliente (T009, T010) e validação são independentes.
- **US4 (Phase 6)**: depende do Setup; arquivo próprio da Fase 1; independente de US1–US3 no conteúdo, mas recomenda-se após as P1 por ordem de risco. Tarefas SQL internas sequenciais (mesmo arquivo).
- **US5 (Phase 7)**: scripts e testes podem ser escritos a qualquer momento, mas **passam em verde apenas após US1–US4 aplicadas**. `ci.yml` (T030) depende dos scripts/testes existirem.
- **US6 (Phase 8)**: independente; pode ser feita em paralelo a qualquer fase.
- **Polish (Phase 9)**: depende de todas as histórias desejadas concluídas.

### Within Each User Story

- Migrations no mesmo arquivo são sequenciais.
- Tarefas de cliente e de documentação em arquivos distintos podem ser `[P]`.
- Cada história é validada por seu passo de quickstart antes de avançar.

### Parallel Opportunities

- Setup: T001, T002, T003 em paralelo.
- US2: T009 e T010 (arquivos de cliente distintos) em paralelo.
- US5: T022, T023, T024 (scripts distintos) em paralelo; T026–T029 (arquivos de teste distintos) em paralelo após T025.
- US6 (T032) em paralelo com qualquer fase.
- Polish: T034 e T035 em paralelo.

---

## Parallel Example: User Story 5

```bash
# Scripts de auditoria (arquivos distintos) em paralelo:
Task: "Implementar scripts/audit-rpc.mjs"
Task: "Implementar scripts/check-no-from.mjs"
Task: "Implementar scripts/check-no-user-metadata.mjs"

# Após 00_helpers.sql, os arquivos de teste em paralelo:
Task: "Criar supabase/tests/01_anon_rejeitado.sql"
Task: "Criar supabase/tests/02_rbac_por_perfil.sql"
Task: "Criar supabase/tests/03_auditoria.sql"
Task: "Criar supabase/tests/04_signup_sem_escalacao.sql"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 (Setup) → Phase 2 (T004) → Phase 3 (US1).
2. **PARE e VALIDE**: `criar_perfil_teste` removida e seed funcionando. A vulnerabilidade crítica está fechada — já é valor entregável.

### Incremental Delivery (ordem por risco)

1. Fase 0 completa (US1 → US2 → US3) → as 3 vulnerabilidades exploráveis fechadas (deploy atômico da migration `20260702000002`).
2. US4 → padronização retroativa (migration `20260702000003`).
3. US5 → auditoria + testes + CI travando regressões (verde só após 1 e 2).
4. US6 → diretrizes documentadas.

### Sugestão de MVP

- **MVP = User Story 1** (remoção da criação anônima de admin) — a falha mais grave, entregável e testável isoladamente. Idealmente entregar as três P1 juntas, pois compartilham a mesma migration da Fase 0.

---

## Notes

- `[P]` = arquivos diferentes, sem dependência.
- As tarefas SQL da Fase 0 (T005, T008, T012–T014) compartilham um arquivo e são **sequenciais** por design (deploy atômico das correções críticas).
- Migrations são hand-authored (convenção do repositório), nunca geradas por diff.
- Commit após cada tarefa ou grupo lógico; validar cada história no seu checkpoint.
- Meta de auditoria: 80/80 funções no padrão após US4 (SC-003).

## Nota de rastreabilidade (validação pós-implementação, 2026-07-03)

- Uma migration adicional não prevista neste documento — `supabase/migrations/20260703000000_security_hardening_fase2.sql` — foi criada fora do fluxo de tasks para padronizar 32 funções de domínio dos módulos financeiro/comercial/equipe/relatórios/configurações (fora da lista de "26 funções legadas" de US4/T017-T020), que a auditoria estática também reprovava. Ela não tem tarefa própria aqui porque o escopo real de funções legadas do repositório é maior do que o mapeado originalmente em US4.
- Nessa mesma migration havia duas funções duplicadas/triplicadas entre arquivos (`atualizar_usuario_perfil` recriada sem necessidade, contrariando a nota de T015; `listar_responsaveis_tarefas` definida duas vezes com corpos divergentes) — consolidadas para uma única fonte de verdade por função.
- Os arquivos `supabase/tests/01_anon_rejeitado.sql`, `02_rbac_por_perfil.sql`, `03_auditoria.sql` e `04_signup_sem_escalacao.sql` tinham bugs que faziam `npm run db:test` falhar (comparação de mensagem de erro incompatível com o guardrail de GRANT, troca de role bloqueando leituras subsequentes de `auth.users`/`audit_log`, e falta de idempotência) — corrigidos; suíte completa validada em 96/96 (`Result: PASS`, exit 0), inclusive rodando duas vezes seguidas sem `db reset` entre as execuções.
