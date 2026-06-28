# Quickstart: Validação das Landings por Persona

Guia de validação ponta-a-ponta. Prova que as três landings (Dashboard, Projetos, Clientes) funcionam com **dados reais** e que cada persona é redirecionada corretamente, sem dados mockados.

## Pré-requisitos

- Docker Desktop ativo (≥ 4 GB RAM / 2 CPUs).
- Supabase CLI instalado.
- `.env.local` com `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` apontando para o Supabase local.
- `SEED_USER_PASSWORD` configurado (ou fallback do `seed.sql`).

## Setup

```bash
# 1. Reconstrói o banco: aplica as 7 migrações modulares (schema → security → rpc_{clientes,projetos}_{read,write} → rpc_dashboard_read) e seeds
npx supabase db reset

# 2. Sobe a aplicação
npm run dev
```

`supabase db reset` deve concluir sem erros de integridade, criando as 6 tabelas novas (`clientes`, `atendimentos`, `projetos`, `tarefas`, `alocacoes_projeto`, `lancamentos`), as RPCs e os seeds de módulo por persona.

## Credenciais de teste (personas)

| Persona | E-mail | Landing esperada |
|---------|--------|------------------|
| Administrador | admin@aptusflow.local | `/dashboard` |
| Financeiro | financeiro@aptusflow.local | `/dashboard` |
| Projetos | projetos@aptusflow.local | `/projetos` |
| Técnico | tecnico@aptusflow.local | `/projetos` (apenas alocados) |
| Comercial | comercial@aptusflow.local | `/clientes` |

Senha: valor de `SEED_USER_PASSWORD` (ou fallback do seed).

## Cenários de validação

### C1 — Redirecionamento por perfil (SC-001)
1. Faça login com cada persona da tabela.
2. **Esperado**: cada uma cai na landing correta sem passar pela tela "Módulo Não Migrado".

### C2 — Projetos com dados reais (US1, SC-002/SC-005)
1. Login como `projetos@aptusflow.local`.
2. **Esperado**: cards (projetos ativos, tarefas abertas, orçamento, em risco), lista de progresso, pizza de distribuição e Kanban refletem os seeds — nenhum valor fixo do mock legado.
3. Arraste um card entre colunas → recarregue a página.
4. **Esperado**: a tarefa permanece na nova coluna (persistido via `mover_tarefa`).

### C3 — Escopo do Técnico (US1 cenário 2, SC-006)
1. Login como `tecnico@aptusflow.local`.
2. **Esperado**: vê apenas os projetos em que está alocado (subconjunto menor que o do Gerente de Projetos).

### C4 — Clientes com dados reais (US2, SC-002)
1. Login como `comercial@aptusflow.local`.
2. **Esperado**: abas Clientes/Fornecedores, stats bar, tabela de contatos e painel de detalhes com histórico vêm do banco.
3. Use a busca/filtro de status → a tabela filtra; sem resultados, mostra estado vazio.

### C5 — Dashboard sem mock (US3, SC-002)
1. Login como `admin@aptusflow.local`.
2. **Esperado**: cards, fluxo de caixa, últimos lançamentos, contas a pagar (7 dias) e composição de receita derivam de `lancamentos`/`clientes`. Compare com os seeds.

### C6 — CRUD e persistência (US5, SC-008)
1. Como Comercial: crie um novo contato → recarregue → ele persiste.
2. Como Projetos: crie projeto e tarefa → recarregue → persistem.
3. Edite e exclua um registro → as mudanças persistem.

### C7 — RBAC de escrita (US5 cenário 3, SC-009)
1. Login como uma persona sem escrita no módulo (ex.: Comercial tentando criar projeto, ou um Visualizador).
2. **Esperado**: ações de criar/editar/excluir ocultas/desabilitadas; nenhuma alteração é persistida mesmo via chamada direta da RPC (gate `pode_escrever`).

### C8 — Estados de carregamento/erro (FR-008, SC-004)
1. Acesse uma landing com o banco vazio em alguma seção → estado vazio explícito.
2. Simule indisponibilidade (ex.: parar o Supabase) → estado de erro recuperável com "tentar novamente".

## Critérios de aceite (resumo)

- [ ] `supabase db reset` sem erros; 6 tabelas + RPCs criadas.
- [ ] 5 personas redirecionam para a landing correta (C1).
- [ ] Projetos, Clientes e Dashboard sem nenhum dado mockado (C2, C4, C5).
- [ ] Técnico restrito aos projetos alocados (C3).
- [ ] CRUD persiste e RBAC de escrita é imposto (C6, C7).
- [ ] Estados de carregamento, vazio e erro presentes (C8).

## Referências

- Contratos: [contracts/](./contracts/) · Modelo de dados: [data-model.md](./data-model.md) · Decisões: [research.md](./research.md)
