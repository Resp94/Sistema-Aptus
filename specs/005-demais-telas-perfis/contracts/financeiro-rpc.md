# Contract: Financeiro RPC

Todas as funcoes exigem usuario autenticado e permissao no modulo correspondente. O frontend chama apenas `supabase.rpc()`.

## Leitura

### `obter_resumo_fluxo_caixa(p_data_inicio date, p_data_fim date)`

Retorna objeto:

```json
{
  "saldo_inicial": 0,
  "entradas": 0,
  "saidas": 0,
  "saldo_final_projetado": 0
}
```

### `listar_fluxo_caixa(p_data_inicio date, p_data_fim date, p_categoria text, p_busca text)`

Retorna lista de lancamentos financeiros com status derivado.

Campos: `id`, `tipo`, `natureza`, `descricao`, `valor`, `categoria`, `cliente`, `data_competencia`, `data_vencimento`, `status_exibicao`.

### `obter_fluxo_caixa_series(p_data_inicio date, p_data_fim date)`

Retorna serie mensal/diaria para grafico: `periodo`, `receitas`, `despesas`, `saldo`.

### `listar_contas_pagar(p_status text, p_fornecedor text, p_data_inicio date, p_data_fim date)`

Filtro sobre `lancamentos` com `tipo = 'despesa'` e `natureza = 'a_pagar'`.

### `listar_contas_receber(p_status text, p_cliente_id uuid, p_data_inicio date, p_data_fim date)`

Filtro sobre `lancamentos` com `tipo = 'receita'` e `natureza = 'a_receber'`.

### `obter_metricas_contas(p_natureza text, p_data_inicio date, p_data_fim date)`

`p_natureza`: `a_pagar` ou `a_receber`.

Retorna `total`, `vencidas`, `vencem_hoje`, `proximos_7_dias`.

## Escrita

### `criar_lancamento_financeiro(payload jsonb)`

Cria receita/despesa/a pagar/a receber.

Validacoes:
- `tipo` em `receita`, `despesa`
- `natureza` em `realizado`, `a_pagar`, `a_receber`
- `valor > 0`
- `descricao` obrigatoria

### `atualizar_lancamento_financeiro(p_id uuid, payload jsonb)`

Atualiza campos editaveis de lancamento financeiro.

### `registrar_pagamento_lancamento(p_id uuid, p_data_pagamento date, p_valor numeric)`

Marca lancamento como pago quando o valor cobre o saldo previsto. Atualiza indicadores apos sucesso.

## Regras de dominio

- `Vencido` e sempre derivado por consulta; a RPC deve retornar `status_exibicao`, sem depender de status persistido como fonte primaria.
- Filtros sem resultado devem retornar listas vazias e metricas zeradas para o recorte filtrado.
- Escritas com erro devem retornar erro tipado e nao criar registros parciais.
- Se uma cobranca ja estiver vinculada a um lancamento, a criacao de novo recebivel para a mesma cobranca deve ser rejeitada ou reaproveitar o `lancamento_id` existente.

## Erros esperados

- `permission_denied`: perfil sem leitura/escrita no modulo.
- `validation_error`: payload invalido.
- `not_found`: registro inexistente ou fora do escopo do usuario.
