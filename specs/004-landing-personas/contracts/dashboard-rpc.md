# Contrato RPC: Dashboard

Funções de agregação `SECURITY DEFINER`, RBAC via `permissao_modulo('dashboard')`, chamadas via `supabase.rpc(...)`. Substituem 100% dos valores mockados de `DashboardPage.tsx`. Todas derivam de `lancamentos` e `clientes`.

Módulo RBAC: `dashboard` (somente leitura nesta feature).

---

### `obter_metricas_dashboard()`

Cards: Saldo em conta, Contas a receber, Contas a pagar, Clientes ativos.

- **Gate**: `pode_ler('dashboard')`.
- **Retorno** `TABLE`:
  `saldo_em_conta numeric, contas_receber numeric, cobrancas_pendentes int, contas_pagar numeric, faturas_abertas int, clientes_ativos int, clientes_novos_mes int`.
  - `saldo_em_conta` = Σ receitas `realizado` − Σ despesas `realizado`.
  - `contas_receber` = Σ `natureza='a_receber'` com `status='Pendente'`; `cobrancas_pendentes` = contagem.
  - `contas_pagar` = Σ `natureza='a_pagar'` com `status='Pendente'`; `faturas_abertas` = contagem.
  - `clientes_ativos` = contagem `clientes` `tipo='cliente'` `status='Ativo'`.

### `obter_fluxo_caixa_mensal(p_meses int default 6)`

Barras do gráfico de fluxo de caixa.

- **Gate**: `pode_ler('dashboard')`.
- **Retorno** `TABLE`: `mes text, ano int, total numeric` (uma linha por mês, ordem cronológica).

### `listar_ultimos_lancamentos(p_limite int default 5)`

Lista "Últimos Lançamentos".

- **Gate**: `pode_ler('dashboard')`.
- **Retorno** `TABLE`: `id uuid, descricao text, valor numeric, tipo text, data date`.
  - `valor` positivo para receita, negativo (ou sinalizado por `tipo`) para despesa — o frontend formata o sinal/cor.

### `listar_contas_pagar_proximas(p_dias int default 7)`

Lista "Contas a pagar: próximos N dias".

- **Gate**: `pode_ler('dashboard')`.
- **Retorno** `TABLE`: `id uuid, descricao text, valor numeric, data_vencimento date`.
  - Filtra `natureza='a_pagar'`, `status='Pendente'`, `data_vencimento` entre hoje e hoje+N.

### `obter_composicao_receita()`

Gráfico de pizza "Composição de receita".

- **Gate**: `pode_ler('dashboard')`.
- **Retorno** `TABLE`: `categoria text, percentual numeric` (participação por categoria das receitas).

---

## Notas de implementação

- Todas as funções retornam conjuntos vazios / zeros quando não há dados, permitindo o **estado vazio** das seções (FR-007, SC-004) sem valores fictícios.
- **Vencido é sempre derivado em tempo de consulta**: um lançamento conta como vencido quando `status='Pendente' AND data_vencimento < current_date`. A coluna `status` armazena apenas `Pendente`/`Pago` — nenhuma rotina grava `Vencido`. Essa é a regra única adotada (sem normalização por seed), garantindo consistência sem job de atualização.
