# Spec 005 - Demais Telas por Perfil de Acesso

**Data**: 2026-06-28

## O que foi feito

Criada a especificacao `specs/005-demais-telas-perfis/spec.md` para cobrir as rotas ainda renderizadas como modulo nao migrado: Fluxo de Caixa, Contas a Pagar, Contas a Receber, Propostas, Contratos, Cobrancas, Equipe, Relatorios e Configuracoes.

Em 2026-06-28, o planejamento da feature foi gerado com `speckit-plan`, incluindo `plan.md`, `research.md`, `data-model.md`, `quickstart.md` e contratos RPC por dominio em `contracts/`.

Em 2026-06-28, foi criado o checklist `specs/005-demais-telas-perfis/checklists/requirements-readiness.md` com foco em qualidade dos requisitos antes da geracao de tarefas.

Em 2026-06-28, o checklist `requirements-readiness.md` foi verificado: 30 de 48 itens foram marcados como completos e 18 permaneceram abertos por gaps de requisitos.

Em 2026-06-28, os 18 gaps abertos do checklist foram corrigidos nos artefatos da feature e o checklist passou para 48/48 itens completos.

## Por que foi feito

As features anteriores entregaram autenticacao, redirecionamento por persona e as landings principais. O proximo passo e dar a todos os perfis de acesso seus fluxos completos dentro do sistema, preservando RBAC, dados reais e ausencia de mocks.

## Regras registradas

- As telas em `reference/legacy-html/` sao a fonte principal de exemplo visual e comportamento esperado.
- `docs/telas.md` e documentacao auxiliar de rotas, objetivos e permissao, nao a fonte principal dos exemplos.
- Cada tela em escopo deve carregar dados persistidos, sem valores de dominio mockados.
- Cada perfil visualiza somente rotas e acoes permitidas por RBAC.
- Acoes sem integracao externa configurada devem ser marcadas como pendentes ou indisponiveis, nunca como sucesso simulado.
- Acoes destrutivas e alteracoes sensiveis devem gerar auditoria.
- Tecnico e Visualizador operam com visoes restritas.
- `lancamentos` permanece a fonte financeira canonica; Fluxo de Caixa, Contas a Pagar e Contas a Receber sao projecoes/RPCs sobre essa tabela.
- Novas RPCs devem validar `auth.uid()`, RBAC, `search_path` fixo e grants explicitos.
- O checklist de readiness valida requisitos escritos, nao comportamento implementado; ele cobre completude, clareza, consistencia, mensurabilidade, cenarios, edge cases, requisitos nao funcionais, dependencias e ambiguidades.
- Gaps resolvidos antes de `/speckit-tasks`: matriz de seeds por perfil/rota, detalhamento de integracoes ausentes por comando, ownership de `cobrancas`, recovery, empty states por tipo de secao, resultado de filtros para graficos/cards/relatorios, comportamento de sessao apos mudanca de permissao, entidades relacionadas ausentes/inativas, duplicidade financeiro-comercial, classificacao de PII, acessibilidade, responsividade, performance por familia de rota, nomenclatura RBAC de `cobrancas`, diferenca entre `alocacoes_projeto` e `alocacoes_equipe`, e fonte unica de status vencido.

## Arquivos afetados

- `specs/005-demais-telas-perfis/spec.md`
- `specs/005-demais-telas-perfis/plan.md`
- `specs/005-demais-telas-perfis/research.md`
- `specs/005-demais-telas-perfis/data-model.md`
- `specs/005-demais-telas-perfis/quickstart.md`
- `specs/005-demais-telas-perfis/contracts/*.md`
- `specs/005-demais-telas-perfis/checklists/requirements.md`
- `specs/005-demais-telas-perfis/checklists/requirements-readiness.md`
- `AGENTS.md`
- `CLAUDE.md`
- `.specify/feature.json`
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/knowledge/architecture.md`
