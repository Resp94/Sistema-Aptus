# Contrato RPC: Módulo Projetos / Tarefas

Funções `SECURITY DEFINER`, RBAC via `permissao_modulo('projetos')`, chamadas via `supabase.rpc(...)`. O perfil `Técnico` enxerga **apenas projetos em que está alocado** (`alocacoes_projeto`).

Módulo RBAC: `projetos`. Leitura exige `pode_ler`; escrita exige `pode_escrever`.

> **Retorno vazio**: todas as RPCs de leitura retornam conjunto vazio quando não há dados (incluindo o Técnico sem alocações) — nunca `null` quebrado —, sustentando o estado vazio das telas (FR-007, SC-004).

---

## Leitura

### `listar_projetos()`

- **Gate**: `pode_ler('projetos')`.
- **Escopo**: Administrador/Projetos → todos; **Técnico → somente onde há `alocacoes_projeto` com seu `usuario_id`**.
- **Retorno** `TABLE`: `id uuid, nome text, cliente text, status text, progresso int, orcamento numeric, orcamento_utilizado numeric, em_risco boolean, prazo date`.

### `obter_resumo_projetos()`

Cards de métricas da landing.

- **Gate**: `pode_ler('projetos')` (respeita o escopo do Técnico).
- **Retorno** `TABLE`: `projetos_ativos int, tarefas_abertas int, orcamento_total numeric, orcamento_utilizado_pct int, em_risco int`.

### `obter_distribuicao_clientes()`

Dados do gráfico "Distribuição por cliente" (pizza).

- **Gate**: `pode_ler('projetos')`.
- **Retorno** `TABLE`: `cliente text, percentual numeric` (participação por nº de projetos ou orçamento).

### `listar_tarefas_kanban()`

Tarefas para o quadro Kanban (respeita escopo do Técnico via projetos visíveis).

- **Gate**: `pode_ler('projetos')`.
- **Retorno** `TABLE`: `id uuid, projeto_id uuid, projeto text, titulo text, situacao text, prioridade text, responsavel text, prazo date, instrucoes text, ordem int`.
- **Agrupamento**: o frontend agrupa por `situacao` (`A Fazer`/`Em Andamento`/`Concluído`).

---

## Escrita

### `criar_projeto(p_nome text, p_cliente_id uuid, p_orcamento numeric, p_prazo date, p_status text default 'Planejamento')`

- **Gate**: `pode_escrever('projetos')`.
- **Validação**: `p_status` válido; `p_nome` não vazio; `p_orcamento >= 0`.
- **Efeito**: insere `projetos` (`progresso=0`, `created_by=auth.uid()`).
- **Retorno**: `uuid`.

### `atualizar_projeto(p_projeto_id uuid, p_nome text, p_cliente_id uuid, p_status text, p_progresso int, p_orcamento numeric, p_orcamento_utilizado numeric, p_em_risco boolean, p_prazo date)`

- **Gate**: `pode_escrever('projetos')`.
- **Validação**: `progresso` 0–100; `status` válido.
- **Retorno**: `void`. **Erro**: `Projeto não encontrado`.

### `excluir_projeto(p_projeto_id uuid)`

- **Gate**: `pode_escrever('projetos')`.
- **Efeito**: DELETE (cascade remove tarefas e alocações). **Audita**: chama `registrar_evento_auditoria('projeto_excluido', auth.uid(), null, null)` — `p_ip_origem`/`p_user_agent` são `null` (sem contexto HTTP em RPC `SECURITY DEFINER`) (FR-015).
- **Retorno**: `void`.

### `criar_tarefa(p_projeto_id uuid, p_titulo text, p_prioridade text default 'Média', p_responsavel_id uuid default null, p_prazo date default null, p_instrucoes text default null)`

- **Gate**: `pode_escrever('projetos')`.
- **Validação**: `prioridade` válida; `p_titulo` não vazio; projeto existe.
- **Efeito**: insere `tarefas` com `situacao='A Fazer'`.
- **Retorno**: `uuid`.

### `atualizar_tarefa(p_tarefa_id uuid, p_titulo text, p_prioridade text, p_responsavel_id uuid, p_prazo date, p_instrucoes text)`

- **Gate**: `pode_escrever('projetos')`.
- **Retorno**: `void`. **Erro**: `Tarefa não encontrada`.

### `mover_tarefa(p_tarefa_id uuid, p_situacao text)`

Persiste o arraste entre colunas do Kanban.

- **Gate**: `pode_escrever('projetos')`.
- **Validação**: `p_situacao` ∈ {`A Fazer`,`Em Andamento`,`Concluído`}.
- **Efeito**: atualiza `situacao` e `updated_at`.
- **Retorno**: `void`.

### `excluir_tarefa(p_tarefa_id uuid)`

- **Gate**: `pode_escrever('projetos')`.
- **Efeito**: DELETE da tarefa. **Audita**: chama `registrar_evento_auditoria('tarefa_excluida', auth.uid(), null, null)` — `p_ip_origem`/`p_user_agent` são `null` (sem contexto HTTP em RPC `SECURITY DEFINER`) (FR-015).
- **Retorno**: `void`.
