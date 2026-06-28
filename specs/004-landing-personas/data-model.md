# Data Model: Telas de Redirecionamento por Persona (Landing Pages)

Schema novo que alimenta as três landings em escopo (Dashboard, Projetos, Clientes). Entregue em **migrações modulares** sob `supabase/migrations/` (ordem por timestamp): `..._schema` (tabelas), `..._security` (RLS + `permissao_modulo` + extensão do enum de auditoria) e cinco migrações de RPC por domínio + operação (`..._rpc_clientes_read`, `..._rpc_clientes_write`, `..._rpc_projetos_read`, `..._rpc_projetos_write`, `..._rpc_dashboard_read`) — ver [plan.md §Project Structure](./plan.md) e [research §D11](./research.md). Todas as tabelas têm RLS habilitado; o acesso do frontend é exclusivamente via RPCs (RPC-first).

Convenções: `id uuid pk default gen_random_uuid()`, `created_at`/`updated_at timestamptz default now()`, `created_by uuid` referencia `auth.uid()` quando aplicável.

---

## Entities

### `clientes`

Clientes e fornecedores da empresa. Base das landing de Clientes e das contrapartes financeiras.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador | Interno |
| nome_contato | text not null | Nome da pessoa de contato | **PII** |
| empresa | text not null | Razão social / nome da empresa | Interno |
| email | text | E-mail de contato | **PII** |
| telefone | text | Telefone de contato | **PII** |
| tipo | text not null | `cliente` ou `fornecedor` | Interno |
| status | text not null default `Ativo` | `Ativo` ou `Inativo` | Interno |
| created_by | uuid | Usuário que cadastrou | Interno |
| created_at / updated_at | timestamptz | Controle | Interno |

> `receita_acumulada` **não** é coluna: é derivada da soma dos `lancamentos` do tipo receita vinculados ao cliente (RPC `obter_cliente_detalhe` / `obter_estatisticas_clientes`).

### `atendimentos`

Histórico de interações/atendimento de um cliente (timeline do painel de detalhes).

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador | Interno |
| cliente_id | uuid fk → clientes(id) ON DELETE CASCADE | Cliente relacionado | Interno |
| data | date not null default current_date | Data do atendimento | Interno |
| descricao | text not null | Resumo da interação | Interno |
| responsavel_id | uuid fk → usuarios(id) ON DELETE SET NULL | Quem atendeu | Interno |
| created_at | timestamptz | Controle | Interno |

### `projetos`

Projetos gerenciados pela equipe.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador | Interno |
| nome | text not null | Nome do projeto | Interno |
| cliente_id | uuid fk → clientes(id) ON DELETE SET NULL | Cliente do projeto | Interno |
| status | text not null default `Planejamento` | `Planejamento`, `Em andamento`, `Concluído` | Interno |
| progresso | int not null default 0 (0–100) | Percentual de conclusão | Interno |
| orcamento | numeric(14,2) default 0 | Orçamento total | Interno |
| orcamento_utilizado | numeric(14,2) default 0 | Valor já consumido | Interno |
| em_risco | boolean not null default false | Sinalização de risco/atraso | Interno |
| prazo | date | Data limite | Interno |
| created_by | uuid | Criador | Interno |
| created_at / updated_at | timestamptz | Controle | Interno |

### `tarefas`

Tarefas de um projeto exibidas no Kanban.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador | Interno |
| projeto_id | uuid fk → projetos(id) ON DELETE CASCADE | Projeto da tarefa | Interno |
| titulo | text not null | Título da tarefa | Interno |
| situacao | text not null default `A Fazer` | `A Fazer`, `Em Andamento`, `Concluído` | Interno |
| prioridade | text not null default `Média` | `Alta`, `Média`, `Baixa` | Interno |
| responsavel_id | uuid fk → usuarios(id) ON DELETE SET NULL | Responsável | Interno |
| prazo | date | Prazo da tarefa | Interno |
| instrucoes | text | Instruções/observações | Interno |
| ordem | int default 0 | Ordem dentro da coluna | Interno |
| created_at / updated_at | timestamptz | Controle | Interno |

### `alocacoes_projeto`

Vínculo N:N entre usuários e projetos. Define o que o perfil `Técnico` enxerga.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador | Interno |
| projeto_id | uuid fk → projetos(id) ON DELETE CASCADE | Projeto | Interno |
| usuario_id | uuid fk → usuarios(id) ON DELETE CASCADE | Membro alocado | Interno |
| papel | text | Papel no projeto (ex.: Dev, PO) | Interno |
| created_at | timestamptz | Controle | Interno |

> Restrição única `(projeto_id, usuario_id)` evita alocação duplicada.

### `lancamentos`

Movimentações financeiras que alimentam o Dashboard.

| Campo | Tipo | Descrição | Classificação |
|-------|------|-----------|---------------|
| id | uuid pk | Identificador | Interno |
| tipo | text not null | `receita` ou `despesa` | Interno |
| natureza | text not null | `a_receber`, `a_pagar`, `realizado` | Interno |
| descricao | text not null | Descrição do lançamento | Interno |
| valor | numeric(14,2) not null | Valor (sempre positivo) | Interno |
| categoria | text | Categoria (ex.: Projetos, Consultoria, Suporte) — base da composição de receita | Interno |
| cliente_id | uuid fk → clientes(id) ON DELETE SET NULL | Contraparte | Interno |
| data_competencia | date not null default current_date | Competência | Interno |
| data_vencimento | date | Vencimento (contas a pagar/receber) | Interno |
| status | text not null default `Pendente` | `Pendente`, `Pago`, `Vencido` | Interno |
| created_at / updated_at | timestamptz | Controle | Interno |

---

## Relationships

- `atendimentos.cliente_id → clientes.id` (N:1, cascade)
- `projetos.cliente_id → clientes.id` (N:1, set null)
- `tarefas.projeto_id → projetos.id` (N:1, cascade)
- `alocacoes_projeto.(projeto_id, usuario_id)` → `projetos.id` / `usuarios.id` (N:N, cascade)
- `lancamentos.cliente_id → clientes.id` (N:1, set null)

## Validation Rules

- `clientes.tipo` ∈ {`cliente`, `fornecedor`}; `clientes.status` ∈ {`Ativo`, `Inativo`} (CHECK).
- `projetos.status` ∈ {`Planejamento`, `Em andamento`, `Concluído`}; `progresso` entre 0 e 100 (CHECK).
- `tarefas.situacao` ∈ {`A Fazer`, `Em Andamento`, `Concluído`}; `prioridade` ∈ {`Alta`, `Média`, `Baixa`} (CHECK).
- `lancamentos.tipo` ∈ {`receita`, `despesa`}; `natureza` ∈ {`a_receber`, `a_pagar`, `realizado`}; `status` ∈ {`Pendente`, `Pago`, `Vencido`}; `valor > 0` (CHECK).
- `alocacoes_projeto` única por `(projeto_id, usuario_id)`.

## State Transitions

- **Cliente**: `Ativo` ⇄ `Inativo` (excluir = inativar; soft delete). Inativo some das listas ativas, mantém histórico.
- **Tarefa**: `A Fazer` → `Em Andamento` → `Concluído` (e movimentos reversos), via `mover_tarefa`.
- **Lançamento**: `Pendente` → `Pago` (persistido). O estado `Vencido` **não é persistido**: é derivado em tempo de consulta (`status='Pendente' AND data_vencimento < current_date`). A coluna `status` armazena apenas `Pendente`/`Pago`; o CHECK aceita também `Vencido` para flexibilidade futura, mas as RPCs não o gravam.
- **Projeto**: `Planejamento` → `Em andamento` → `Concluído`.

## Row Level Security (RLS)

Todas as tabelas têm RLS habilitado. O acesso do frontend ocorre via RPCs `SECURITY DEFINER`, que rodam com `row_security = off` e impõem o RBAC explicitamente. As políticas de tabela abaixo são a **segunda camada** de defesa para qualquer acesso direto (que o frontend não faz). Nenhuma política usa `ALL`.

Padrão por tabela (`clientes`, `atendimentos`, `projetos`, `tarefas`, `alocacoes_projeto`, `lancamentos`):

| Operação | Regra (política) |
|----------|------------------|
| SELECT | `authenticated` cujo perfil tem `pode_ler` no módulo correspondente |
| INSERT | `authenticated` cujo perfil tem `pode_escrever` no módulo correspondente |
| UPDATE | idem INSERT |
| DELETE | idem INSERT (apenas tabelas com hard delete: `projetos`, `tarefas`, `atendimentos`, `alocacoes_projeto`) |

> `clientes` não concede DELETE (soft delete via `status`). Mapeamento módulo RBAC→tabela: Clientes/atendimentos → módulo `clientes`; Projetos/tarefas/alocações → módulo `projetos`; `lancamentos` → módulo `dashboard` (somente leitura nesta feature; escrita de lançamentos está fora de escopo e será regida por um módulo financeiro próprio em feature futura).

## Auditoria de ações destrutivas

As ações destrutivas dos módulos em escopo são registradas em `public.audit_log` (tabela já existente), atendendo FR-015/SC-011. A migração `..._security` desta feature **estende o CHECK da coluna `audit_log.evento`** para incluir os novos eventos, sem alterar a migração de login:

| Ação (RPC) | Evento registrado |
|-----------|-------------------|
| `excluir_projeto` | `projeto_excluido` |
| `excluir_tarefa` | `tarefa_excluida` |
| `inativar_cliente` | `cliente_inativado` |

Cada RPC destrutiva chama a RPC existente com sua assinatura completa de 4 argumentos: `registrar_evento_auditoria(p_evento, p_usuario_id := auth.uid(), p_ip_origem := null, p_user_agent := null)`. Como são funções `SECURITY DEFINER` sem contexto HTTP, `p_ip_origem` e `p_user_agent` são passados como `null` (o IP/User-Agent reais só existem no fluxo de auth do GoTrue, não em chamadas RPC de módulo). Ações de criação/edição não destrutivas **não** são auditadas, mantendo a trilha consistente com o uso atual (eventos de segurança e irreversíveis).

```sql
-- Na migração ..._security.sql, estender o domínio de evento:
ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_evento_check;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_evento_check CHECK (
  evento IN (
    'login_sucesso','login_falha','senha_alterada','usuario_criado',
    'conta_desativada','conta_ativada',
    'projeto_excluido','tarefa_excluida','cliente_inativado'
  )
);
```

### Função auxiliar de permissão

```sql
-- Retorna (pode_ler, pode_escrever) do auth.uid() atual para um módulo.
-- Fonte única de RBAC, derivada da mesma matriz de obter_permissoes_usuario().
CREATE OR REPLACE FUNCTION public.permissao_modulo(p_modulo text)
RETURNS TABLE (pode_ler boolean, pode_escrever boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  RETURN QUERY
  SELECT p.pode_ler, p.pode_escrever
  FROM public.obter_permissoes_usuario() p
  WHERE p.modulo = p_modulo;
END;
$$;
```

> Reaproveita `obter_permissoes_usuario()` (já existente), garantindo que a matriz de permissões permaneça em um único lugar.

## RPC Functions (PostgreSQL)

Seguindo RPC-first. Detalhes de assinatura, parâmetros e payloads nos contratos:
[contracts/clientes-rpc.md](./contracts/clientes-rpc.md), [contracts/projetos-rpc.md](./contracts/projetos-rpc.md), [contracts/dashboard-rpc.md](./contracts/dashboard-rpc.md).

| Domínio | Leitura | Escrita |
|---------|---------|---------|
| Clientes | `listar_clientes`, `obter_cliente_detalhe`, `obter_estatisticas_clientes` | `criar_cliente`, `atualizar_cliente`, `inativar_cliente`, `registrar_atendimento` |
| Projetos | `listar_projetos`, `obter_resumo_projetos`, `obter_distribuicao_clientes`, `listar_tarefas_kanban` | `criar_projeto`, `atualizar_projeto`, `excluir_projeto`, `criar_tarefa`, `atualizar_tarefa`, `mover_tarefa`, `excluir_tarefa` |
| Dashboard | `obter_metricas_dashboard`, `obter_fluxo_caixa_mensal`, `listar_ultimos_lancamentos`, `listar_contas_pagar_proximas`, `obter_composicao_receita` | — (consome dados criados por outros módulos) |
| Comum | `permissao_modulo` | — |
