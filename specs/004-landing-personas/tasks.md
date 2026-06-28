# Tasks: Telas de Redirecionamento por Persona (Landing Pages)

**Input**: Design documents from `/specs/004-landing-personas/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (clientes-rpc, projetos-rpc, dashboard-rpc), quickstart.md

**Tests**: Não solicitados como TDD. Incluídos apenas testes unitários leves para helpers puros (padrão do projeto) e validação manual via quickstart.

**Organization**: Tarefas agrupadas por user story. Arquitetura RPC-first. O schema é entregue em **migrações modulares por camada e por domínio/operação** (ver [research §D11](./research.md)); as user stories entregam o frontend por persona e a fiação do CRUD.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependências pendentes)
- **[Story]**: User story a que a tarefa pertence (US1–US5)
- Caminhos de arquivo exatos incluídos em cada tarefa

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Garantir ambiente de desenvolvimento e Supabase local prontos

- [x] T001 Verificar Docker Desktop e Supabase CLI ativos (`supabase status`); confirmar `.env.local` com `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SEED_USER_PASSWORD`
- [x] T002 [P] Confirmar baseline limpo executando `npx supabase db reset` (migração de login 003 aplica sem erro antes de iniciar)

---

## Phase 2: Foundational (Schema + RPCs + tipos + helpers)

**Purpose**: Criar todo o schema, RLS, RPCs e infraestrutura de frontend compartilhada que TODAS as user stories consomem

**⚠️ CRITICAL**: Nenhuma user story pode começar antes desta fase concluir

### Banco de dados (migrações modulares em `supabase/migrations/`, ordem por timestamp — ver [research §D11](./research.md))

- [x] T003 Criar `supabase/migrations/<ts1>_modulos_landing_schema.sql` com as 6 tabelas (`clientes`, `atendimentos`, `projetos`, `tarefas`, `alocacoes_projeto`, `lancamentos`): PKs, FKs (cascade/set null), CHECK constraints de enum e índices, conforme [data-model.md](./data-model.md)
- [x] T004 Criar `supabase/migrations/<ts2>_modulos_landing_security.sql` (após T003): habilitar RLS + políticas por operação (SELECT/INSERT/UPDATE/DELETE, sem `ALL`, `clientes` sem DELETE) nas 6 tabelas; criar helper `public.permissao_modulo(p_modulo text)` reaproveitando `obter_permissoes_usuario()`; estender o CHECK de `audit_log.evento` com `projeto_excluido`, `tarefa_excluida`, `cliente_inativado`, conforme [data-model.md §RLS e §Auditoria](./data-model.md)
- [x] T005 [P] Criar `supabase/migrations/<ts3>_modulos_landing_rpc_clientes_read.sql` (após T004) com as RPCs de **leitura** de clientes (gate `pode_ler`): `listar_clientes`, `obter_estatisticas_clientes`, `obter_cliente_detalhe`, conforme [contracts/clientes-rpc.md](./contracts/clientes-rpc.md) (retorno vazio, nunca null quebrado)
- [x] T006 [P] Criar `supabase/migrations/<ts4>_modulos_landing_rpc_clientes_write.sql` (após T004) com as RPCs de **escrita** de clientes (gate `pode_escrever`): `criar_cliente`, `atualizar_cliente`, `inativar_cliente`, `registrar_atendimento`. `inativar_cliente` chama `registrar_evento_auditoria('cliente_inativado', auth.uid(), null, null)`, conforme [contracts/clientes-rpc.md](./contracts/clientes-rpc.md)
- [x] T007 [P] Criar `supabase/migrations/<ts5>_modulos_landing_rpc_projetos_read.sql` (após T004) com as RPCs de **leitura** de projetos/tarefas (gate `pode_ler`): `listar_projetos` (escopo do Técnico via `alocacoes_projeto`), `obter_resumo_projetos`, `obter_distribuicao_clientes`, `listar_tarefas_kanban`, conforme [contracts/projetos-rpc.md](./contracts/projetos-rpc.md) (retorno vazio, nunca null quebrado)
- [x] T008 [P] Criar `supabase/migrations/<ts6>_modulos_landing_rpc_projetos_write.sql` (após T004) com as RPCs de **escrita** de projetos/tarefas (gate `pode_escrever`): `criar_projeto`, `atualizar_projeto`, `excluir_projeto`, `criar_tarefa`, `atualizar_tarefa`, `mover_tarefa`, `excluir_tarefa`. `excluir_projeto`/`excluir_tarefa` chamam `registrar_evento_auditoria(evento, auth.uid(), null, null)`, conforme [contracts/projetos-rpc.md](./contracts/projetos-rpc.md)
- [x] T009 [P] Criar `supabase/migrations/<ts7>_modulos_landing_rpc_dashboard_read.sql` (após T004) com as RPCs de agregação (leitura, gate `pode_ler`, Vencido derivado em consulta): `obter_metricas_dashboard`, `obter_fluxo_caixa_mensal`, `listar_ultimos_lancamentos`, `listar_contas_pagar_proximas`, `obter_composicao_receita`, conforme [contracts/dashboard-rpc.md](./contracts/dashboard-rpc.md) (retorno vazio/zerado, nunca null quebrado)
- [x] T010 Estender `supabase/seed.sql` com dados de módulo coerentes às personas: `clientes`/`atendimentos` (reuso dos nomes legados), `projetos`/`tarefas`, `alocacoes_projeto` (alocando a persona Técnico a um subconjunto de projetos) e `lancamentos` (receitas/despesas/a pagar/a receber vinculados a clientes) para alimentar o Dashboard, conforme [research §D9](./research.md)
- [x] T011 Executar `npx supabase db reset` and validar que as 7 migrações aplicam em ordem, criando 6 tabelas + RPCs + seeds sem erro de integridade (SC-010)

### Frontend compartilhado

- [x] T012 [P] Criar tipos em `src/types/clientes.ts` (Cliente, Atendimento, EstatisticasClientes, ClienteDetalhe) conforme [contracts/clientes-rpc.md](./contracts/clientes-rpc.md)
- [x] T013 [P] Criar tipos em `src/types/projetos.ts` (Projeto, Tarefa, ResumoProjetos, DistribuicaoCliente, TarefaKanban) conforme [contracts/projetos-rpc.md](./contracts/projetos-rpc.md)
- [x] T014 [P] Criar tipos em `src/types/dashboard.ts` (MetricasDashboard, FluxoCaixaMes, LancamentoResumo, ContaPagarProxima, ComposicaoReceita) conforme [contracts/dashboard-rpc.md](./contracts/dashboard-rpc.md)
- [x] T015 [P] Criar `src/lib/permissoes.ts` com helpers `podeLer(permissoes, modulo)` e `podeEscrever(permissoes, modulo)` derivados do array de permissões do `AuthContext`

**Checkpoint**: Schema + RPCs + seeds + tipos + helpers prontos — user stories podem começar

---

## Phase 3: User Story 1 - Projetos com dados reais (Priority: P1) 🎯 MVP

**Goal**: Gerente de Projetos e Técnico chegam a `/projetos` com indicadores, progresso, distribuição e Kanban vindos do banco (Técnico restrito aos projetos alocados).

**Independent Test**: Login como `projetos@aptusflow.local` → `/projetos` exibe dados reais dos seeds; login como `tecnico@aptusflow.local` vê apenas projetos alocados (quickstart C2/C3).

- [x] T016 [P] [US1] Criar `src/services/projetos.service.ts` encapsulando as RPCs de leitura de projetos (`listar_projetos`, `obter_resumo_projetos`, `obter_distribuicao_clientes`, `listar_tarefas_kanban`) via `supabase.rpc`
- [x] T017 [US1] Criar `src/pages/ProjetosPage.tsx` baseada em `reference/legacy-html/projetos.html` (cards de resumo, lista de progresso, pizza de distribuição, Kanban com 3 colunas) consumindo `projetos.service` — sem dados mockados
- [x] T018 [P] [US1] Criar `src/pages/ProjetosPage.css` com estilos específicos (progresso, kanban, colunas) reaproveitando variáveis do `aptus.css`
- [x] T019 [US1] Implementar estados de carregamento, vazio (padrão `empty-state`, incl. Técnico sem alocação) e erro recuperável em `ProjetosPage.tsx` (FR-007/008)
- [x] T020 [US1] Substituir a rota `/projetos` de `ModuloNaoMigrado` para `ProjetosPage` em `src/App.tsx`
- [x] T021 [US1] Validar US1 pelo quickstart (C2 dados reais + C3 escopo do Técnico)

**Checkpoint**: `/projetos` totalmente funcional e testável de forma independente

---

## Phase 4: User Story 2 - Clientes com dados reais (Priority: P1)

**Goal**: Consultor Comercial chega a `/clientes` com abas, stats, tabela e painel de detalhes (histórico) vindos do banco.

**Independent Test**: Login como `comercial@aptusflow.local` → `/clientes` exibe contatos, stats e detalhe reais; busca/filtro funcionam (quickstart C4).

- [x] T022 [P] [US2] Criar `src/services/clientes.service.ts` encapsulando as RPCs de leitura (`listar_clientes`, `obter_estatisticas_clientes`, `obter_cliente_detalhe`) via `supabase.rpc`
- [x] T023 [US2] Criar `src/pages/ClientesPage.tsx` baseada em `reference/legacy-html/clientes.html` (abas Clientes/Fornecedores, stats bar, tabela de contatos, painel de detalhes com histórico) consumindo `clientes.service` — sem dados mockados
- [x] T024 [P] [US2] Criar `src/pages/ClientesPage.css` com estilos específicos (abas/pills, painel de detalhes, timeline) reaproveitando o `aptus.css`
- [x] T025 [US2] Implementar busca/filtro de status + estados de carregamento, vazio ("Nenhum resultado encontrado") e erro recuperável em `ClientesPage.tsx` (FR-007/008)
- [x] T026 [US2] Substituir a rota `/clientes` de `ModuloNaoMigrado` para `ClientesPage` em `src/App.tsx`
- [x] T027 [US2] Validar US2 pelo quickstart (C4)

**Checkpoint**: `/clientes` totalmente funcional e testável de forma independente

---

## Phase 5: User Story 3 - Dashboard sem dados mockados (Priority: P2)

**Goal**: O Dashboard existente passa a exibir métricas, gráficos e listas derivados do banco; nenhum valor fixo permanece.

**Independent Test**: Login como `admin@aptusflow.local` → valores do Dashboard batem com os seeds; sem valores codificados (quickstart C5).

- [x] T028 [P] [US3] Criar `src/services/dashboard.service.ts` encapsulando as RPCs de agregação (`obter_metricas_dashboard`, `obter_fluxo_caixa_mensal`, `listar_ultimos_lancamentos`, `listar_contas_pagar_proximas`, `obter_composicao_receita`)
- [x] T029 [US3] Religar `src/pages/DashboardPage.tsx` aos dados reais via `dashboard.service`, removendo TODOS os valores mockados (cards, fluxo de caixa, últimos lançamentos, contas a pagar 7 dias, composição de receita) e o modal de notificações fictício (FR-004)
- [x] T030 [US3] Implementar estados de carregamento, vazio (valor zerado "Sem dados no período") e erro recuperável em `DashboardPage.tsx` (FR-007/008)
- [x] T031 [US3] Validar US3 pelo quickstart (C5 — 0 valores fictícios)

**Checkpoint**: Dashboard livre de mock, alimentado pelo banco

---

## Phase 6: User Story 4 - Redirecionamento correto por perfil (Priority: P2)

**Goal**: Cada persona cai na landing correta; acesso a landing sem permissão de leitura redireciona para rota permitida sem vazar dados.

**Independent Test**: Login com as 5 personas → cada uma na landing correta (quickstart C1); acesso direto a rota sem `pode_ler` redireciona.

- [x] T032 [US4] Implementar guarda de acesso por módulo: ao montar uma landing sem `podeLer(modulo)`, redirecionar para `rotaInicialPorPerfil(perfil)` ANTES de qualquer carregamento de dados (em `ProtectedRoute` ou wrapper por página), conforme FR-010
- [x] T033 [US4] Revisar `src/lib/usuario.ts` (`rotaInicialPorPerfil`) garantindo cobertura dos 6 perfis (incl. Visualizador → Dashboard) e consistência com o mapa de landing
- [x] T034 [P] [US4] Adicionar/atualizar testes unitários em `src/lib/usuario.test.ts` e `src/lib/navegacao.test.ts` cobrindo redirecionamento por perfil e filtragem de nav por permissão
- [x] T035 [US4] Validar US4 pelo quickstart (C1 redirecionamento + acesso negado)

**Checkpoint**: Redirecionamento por perfil consistente e seguro

---

## Phase 7: User Story 5 - Gerenciar registros (CRUD) com persistência (Priority: P2)

**Goal**: Usuários com permissão criam, editam e excluem registros nas landings, com persistência real, RBAC de escrita e auditoria das ações destrutivas.

**Independent Test**: Criar/editar/excluir em Projetos e Clientes persiste após recarregar; perfil sem escrita não vê ações e não persiste (quickstart C6/C7).

**Dependencies**: US1 e US2 (páginas existentes); RPCs de escrita já criadas em Foundational (T006 clientes, T008 projetos).

- [x] T036 [US5] Fiar no `ProjetosPage.tsx` os modais/ações de novo projeto, nova/editar tarefa, **mover tarefa (drag-and-drop → `mover_tarefa`, persistindo a coluna — FR-016/SC-012)** e excluir projeto/tarefa, chamando `projetos.service` (estender com as RPCs de escrita)
- [x] T037 [US5] Fiar no `ClientesPage.tsx` o modal de novo contato, edição, inativação (excluir) e registrar atendimento, chamando `clientes.service` (estender com as RPCs de escrita)
- [x] T038 [P] [US5] Ocultar ações de criar/editar/excluir quando `podeEscrever(modulo)` for falso, em `ProjetosPage.tsx` e `ClientesPage.tsx` (FR-013), usando `src/lib/permissoes.ts`
- [x] T039 [US5] Implementar validação de entrada e tratamento de erro nas ações de escrita (mensagens claras, tela não corrompida) em ambas as páginas (FR-014)
- [x] T040 [US5] Validar US5 pelo quickstart (C6 persistência + C7 RBAC de escrita + auditoria das exclusões/inativação)

**Checkpoint**: CRUD completo, com RBAC e auditoria

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Qualidade, testes e validação final

- [x] T041 [P] Criar testes unitários `src/lib/permissoes.test.ts` para `podeLer`/`podeEscrever`
- [x] T042 [P] Atualizar `docs/telas.md` (status das telas migradas) e nota de migração das HTML legadas
- [x] T043 Remover o uso de `ModuloNaoMigrado` nas rotas substituídas e limpar imports órfãos em `src/App.tsx`
- [x] T044 Executar a validação completa do [quickstart.md](./quickstart.md) (C1–C8), incluindo desempenho < 3 s (SC-003) e estados de carregamento/erro (C8)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências
- **Foundational (Phase 2)**: depende do Setup — BLOQUEIA todas as user stories. Migrações modulares: T003 (schema) → T004 (security: RLS + helper + enum) → **T005–T009 em paralelo** (5 arquivos de RPC por domínio/operação, todos dependem só de T004) → T010 (seeds) → T011 (db reset). T012–T015 (tipos + helper de frontend) podem rodar em paralelo a qualquer momento após o Setup
- **US1, US2, US3 (Phases 3–5)**: dependem da Foundational; independentes entre si (arquivos de página/serviço distintos) — podem ser feitas em paralelo
- **US4 (Phase 6)**: depende da Foundational; idealmente após existir ao menos uma landing real para testar
- **US5 (Phase 7)**: depende de US1 e US2 (páginas) + RPCs de escrita (T006 clientes, T008 projetos)
- **Polish (Phase 8)**: depende das user stories desejadas concluídas

### Within Each User Story

- Serviço antes da página; página antes do swap de rota; estados antes da validação

### Parallel Opportunities

- T005–T009 (5 migrações de RPC) em paralelo após T004
- T012, T013, T014, T015 (tipos + helper) em paralelo
- US1, US2, US3 inteiras em paralelo por devs diferentes após a Foundational
- Dentro de cada story: o `.css` ([P]) em paralelo com o `.tsx`; os serviços ([P]) antes das páginas

---

## Parallel Example: Foundational

```bash
# Após T004 (schema + security aplicados), as 5 migrações de RPC em paralelo:
Task: "Criar ..._rpc_clientes_read.sql"
Task: "Criar ..._rpc_clientes_write.sql"
Task: "Criar ..._rpc_projetos_read.sql"
Task: "Criar ..._rpc_projetos_write.sql"
Task: "Criar ..._rpc_dashboard_read.sql"

# E, em paralelo, os tipos e helper de frontend:
Task: "Criar src/types/clientes.ts"
Task: "Criar src/types/projetos.ts"
Task: "Criar src/types/dashboard.ts"
Task: "Criar src/lib/permissoes.ts"

# Depois, US1 e US2 (P1) por devs diferentes:
Dev A: ProjetosPage + projetos.service (T016–T021)
Dev B: ClientesPage + clientes.service (T022–T027)
```

---

## Implementation Strategy

### MVP First

1. Phase 1 Setup + Phase 2 Foundational (schema, RPCs, seeds, tipos, helpers)
2. Phase 3 US1 (Projetos) → **STOP e VALIDAR** (quickstart C2/C3)
3. Demonstrar a landing de Projetos por persona com dados reais

### Incremental Delivery

1. Foundational → base pronta
2. + US1 (Projetos, P1) → valida → demo
3. + US2 (Clientes, P1) → valida → demo
4. + US3 (Dashboard sem mock, P2) → valida → demo
5. + US4 (Redirecionamento, P2) → valida
6. + US5 (CRUD, P2) → valida
7. Polish

---

## Notes

- Arquitetura RPC-first: o frontend nunca usa `supabase.from()`; tudo via `supabase.rpc()`.
- O schema é entregue in **7 migrações modulares** (ver [research §D11](./research.md)): `schema` e `security` são sequenciais (T003→T004); as 5 migrações de RPC, separadas por domínio (clientes/projetos/dashboard) e por operação (leitura/escrita), são arquivos distintos e podem ser feitas em paralelo após T004.
- [P] = arquivos diferentes, sem dependências pendentes.
- Validar cada story de forma independente nos checkpoints antes de avançar.
- Commit após cada tarefa ou grupo lógico.
