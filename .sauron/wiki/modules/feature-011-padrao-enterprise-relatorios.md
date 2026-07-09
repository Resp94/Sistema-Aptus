# Feature 011 — Padrao Enterprise Relatorios

## Objetivo

Evoluir a exportacao de relatorios da feature 008 para um padrao enterprise, com foco em:

- PDF como documento executivo oficial
- download sem preview
- linguagem PT-BR correta
- identidade visual consistente
- separacao clara entre artefato executivo e exportacao operacional

## Decisoes aprovadas

- O PDF nao deve abrir preview no fluxo normal.
- O renderer deixa de serializar chaves tecnicas.
- Cada categoria passa a ter template executivo proprio.
- CSV/ZIP continua operacional, com BOM UTF-8, headers traduzidos e nomenclatura clara.
- Itens expirados permanecem visiveis no historico sem download.

## Artefatos de planejamento

- `specs/011-padrao-enterprise-relatorios/spec.md`
- `specs/011-padrao-enterprise-relatorios/plan.md`
- `specs/011-padrao-enterprise-relatorios/research.md`
- `specs/011-padrao-enterprise-relatorios/data-model.md`
- `specs/011-padrao-enterprise-relatorios/quickstart.md`
- `specs/011-padrao-enterprise-relatorios/tasks.md`

## Estado atual

A feature permanece em deliberacao. O backlog de implementacao foi gerado, mas ainda nao houve execucao de codigo para o escopo 011.
