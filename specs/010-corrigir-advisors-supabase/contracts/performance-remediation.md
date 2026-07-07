# Contract: Performance Remediation

## Purpose

Definir o escopo e os criterios para corrigir warnings de performance ligados a RLS e RPC.

## Scope

Inclui:
- Warnings `auth_rls_initplan` em policies no escopo da feature.
- Warnings `multiple_permissive_policies` quando afetarem recursos centrais do RBAC.

Nao inclui:
- `unindexed_foreign_keys`
- `unused_index`
- Tuning amplo de consulta sem relacao com RLS/RPC

## Required Outcomes

1. **RLS Identity Evaluation**
   - Policies no escopo devem usar padrao equivalente a `(select auth.uid())` quando o warning atual vier de reavaliacao por linha.
   - Helpers de autorizacao usados em policies devem evitar chamadas repetitivas desnecessarias ao contexto de autenticacao.

2. **Policy Consolidation**
   - Em `public.perfis`, `SELECT` e `UPDATE` devem ser reavaliados para um modelo consolidado por acao quando isso reduzir o warning sem perder clareza ou comportamento.

3. **Behavior Preservation**
   - Nenhuma correcao de performance pode ampliar acesso de leitura ou escrita.
   - Nenhuma correcao pode remover capacidade valida de um perfil autorizado.

## Pass Criteria

- Advisors de performance deixam de apontar os casos corrigidos no escopo.
- Testes e validacoes funcionais confirmam ausencia de regressao de acesso.

## Failure Criteria

- O warning permanece no mesmo objeto sem justificativa.
- A correcao muda comportamento de autorizacao sem evidencia ou decisao aprovada.
