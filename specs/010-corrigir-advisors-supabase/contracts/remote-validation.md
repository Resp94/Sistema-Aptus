# Contract: Remote Validation

## Purpose

Padronizar a validacao remota pos-aplicacao para distinguir correcao real, drift remoto e excecoes intencionais.

## Scope

Inclui:
- Snapshot remoto dos advisors `security` e `performance`
- Comparacao antes/depois
- Classificacao de achados remanescentes
- Registro operacional em `triagem.md`, `runbook-validacao.md`, `.agents` e `.sauron`

## Validation Sequence

1. **Baseline Snapshot**
   - Registrar `get_project_url`
   - Registrar `get_advisors(type=security)`
   - Registrar `get_advisors(type=performance)`

2. **Expected State Snapshot**
   - Registrar migrations locais relevantes
   - Registrar o escopo da correcao versionada

3. **Post-Apply Snapshot**
   - Reexecutar os mesmos advisors apos aplicacao
   - Comparar com o baseline por objeto e tipo de lint

4. **Residual Classification**
   - Cada achado remanescente deve ser classificado como:
     - `resolvido`
     - `drift_remoto`
     - `concessao_residual`
     - `excecao_intencional`
     - `fora_escopo`
     - `pendencia_bloqueadora`

## Pass Criteria

- O projeto remoto validado e `lpwnaxlczwntylcmgotm`
- Existe snapshot antes e depois
- Todo achado remanescente no escopo possui classificacao final registrada
- Nenhum risco real de seguranca permanece sem correcao ou excecao aprovada

## Failure Criteria

- Projeto remoto nao pode ser confirmado
- Advisors nao puderam ser executados antes ou depois
- Achado remanescente ficou sem classificacao final
- Persistiu risco real de seguranca sem resolucao
- Persistiu `concessao_residual` sem plano de encerramento ou reclassificacao formal
