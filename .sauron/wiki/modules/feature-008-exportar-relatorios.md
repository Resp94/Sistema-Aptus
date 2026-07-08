# Feature 008 / 011 — Exportacao de Relatorios e Padrao Enterprise

## Contexto

A feature 008 introduziu exportacao real de relatorios em PDF e CSV com bucket privado, signed URLs e historico. Em 2026-07-08, uma rodada exploratoria no navegador confirmou que o artefato PDF ainda nao atende o padrao executivo esperado e que o fluxo de download pode abrir preview no browser.

## Decisao complementar

Foi aprovada a feature 011 para evoluir a entrega da 008 sem reescrever a arquitetura de backend:

- o PDF passa a ser tratado como documento executivo oficial;
- o fluxo de PDF deve baixar sem preview;
- o renderer deixa de serializar chaves internas;
- a exportacao tabular continua operacional e distinta do documento executivo;
- o historico preserva estados e validade.

## Artefatos de planejamento

- `specs/011-padrao-enterprise-relatorios/spec.md`
- `specs/011-padrao-enterprise-relatorios/plan.md`
- `specs/011-padrao-enterprise-relatorios/research.md`
- `specs/011-padrao-enterprise-relatorios/data-model.md`
- `specs/011-padrao-enterprise-relatorios/quickstart.md`

## Impacto arquitetural

- Reaproveita frontend e Edge Function da feature 008.
- Nao cria novo subsistema de exportacao.
- Formaliza a separacao entre artefato executivo e artefato operacional.
