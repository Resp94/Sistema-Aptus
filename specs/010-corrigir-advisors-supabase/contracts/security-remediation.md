# Contract: Security Remediation

## Purpose

Definir o comportamento esperado das correcoes de seguranca ligadas aos advisors do Supabase.

## Scope

Inclui:
- Funcoes `SECURITY DEFINER` sinalizadas como executaveis por papeis nao previstos.
- Tabelas com RLS habilitado e sem policy coerente.
- Triagem de funcoes privilegiadas por dependencia viva.

Nao inclui:
- Refatoracao geral de todas as funcoes do banco.
- Ajustes de indice sem relacao com grants, RLS ou RPC.
- Mudancas em contratos de negocio fora do impacto direto da correcao.

## Required Outcomes

1. **Function Grant Outcome**
   - Toda funcao `SECURITY DEFINER` no escopo deve ter assinatura exata inventariada.
   - Toda funcao no escopo deve ter estado remoto esperado descrito em termos de `REVOKE` e `GRANT`.
   - Nenhuma funcao que nao deveria aceitar `anon` pode permanecer executavel por `anon`.

2. **Live Dependency Outcome**
   - Toda funcao no escopo deve ser classificada como `preservar`, `corrigir_grants`, `converter`, `remover` ou `investigar`.
   - Funcoes sem dependencia viva detectavel nao podem ser mantidas abertas por inercia.

3. **RLS Policy Outcome**
   - Toda tabela no escopo com RLS habilitado deve possuir policy coerente com seu modelo de acesso.
   - A policy precisa explicitar se a tabela e service-owned, interna ou cliente-facing.

## Pass Criteria

- Advisor de seguranca deixa de apontar exposicao indevida nos objetos corrigidos.
- `triagem.md` registra classificacao final para cada caso no escopo.
- Excecoes intencionais, se houver, ficam documentadas com justificativa, impacto e gatilho de revisao.

## Failure Criteria

- Funcao continua exposta a papel nao previsto sem excecao aprovada.
- Tabela continua com RLS sem policy coerente.
- Dependencia viva nao foi analisada antes de preservar funcao privilegiada.
