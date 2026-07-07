# Contract: Triage Governance

## Purpose

Definir como os achados entram, evoluem e saem da triagem da feature 010.

## Triage States

- `risco_real`
- `drift_remoto`
- `concessao_residual`
- `excecao_intencional`
- `fora_escopo`
- `resolvido`

## Mandatory Fields Per Triage Row

- Identificador
- Tipo de advisor
- Objeto afetado
- Assinatura exata quando o objeto for funcao
- Lint
- Classificacao atual
- Acao planejada
- Evidencia base
- Resultado final

## Row Normalization Rule

- Cada tabela ou objeto nao-funcional deve ocupar uma linha propria.
- Cada funcao deve ocupar uma linha propria por assinatura exata antes do inicio da implementacao.
- Linhas agrupadas so podem existir como baseline provisoria de planejamento e devem ser explodidas antes da rodada de correcao.

## Governance Rules

1. Nenhum achado entra como `excecao_intencional` sem justificativa escrita.
2. Nenhum achado sai do estado `risco_real` sem evidencia de correcao ou aprovacao formal de excecao.
3. Itens `fora_escopo` devem apontar a razao de exclusao e nao podem ser declarados como resolvidos.
4. `drift_remoto` exige diferenca observavel entre estado remoto e estado esperado versionado.
5. `concessao_residual` e estado transitorio: nao fecha a feature sem reclassificacao posterior ou correcao.

## Completion Rule

A feature so pode ser considerada pronta para implementacao completa quando a triagem inicial estiver registrada em `triagem.md` e todos os grupos de achado no escopo tiverem acao planejada clara.
