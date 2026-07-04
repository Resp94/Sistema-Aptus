# Spec 007 - RBAC por Capacidades Nomeadas

**Data**: 2026-07-03

## O que foi especificado

Criada a feature Spec Kit `007-rbac-capacidades-nomeadas` para alinhar frontend e backend em torno de capacidades nomeadas de acao. A permissao por modulo continua como base de leitura, rota e navegacao, mas acoes sensiveis passam a depender de capacidades explicitas consumidas pelo frontend e validadas pelas RPCs. A fundacao especificada usa `public.capacidades_perfil`, `tem_capacidade(p_capacidade text)` e `obter_capacidades_usuario()` como contratos canonicos.

## Por que foi feito

A validacao E2E das personas mostrou que `pode_ler`/`pode_escrever` por modulo nao representa bem as historias reais. O perfil Tecnico precisa mover tarefas proprias e apontar horas proprias, mas nao pode criar/excluir projetos nem gerenciar equipe. A mesma validacao confirmou que Visualizador esta ambíguo como persona ativa e deve permanecer apenas como estado tecnico minimo de signup.

## Decisoes registradas

- Capacidade nomeada vira a fonte canonica de autorizacao de acoes.
- `obter_permissoes_usuario` permanece para leitura, rota e navegacao.
- `pode_escrever` deixa de ser a fonte principal para exibicao de botoes no frontend.
- Visualizador deixa de ser persona operacional e permanece como perfil tecnico minimo anti-escalacao.
- Tecnico deve ter somente tarefas proprias, apontamento proprio e edicao do proprio perfil como capacidades de escrita.
- Frontend usa capacidades para UX; RPCs usam as mesmas capacidades para autorizacao real.

## Artefatos criados

- `specs/007-rbac-capacidades-nomeadas/spec.md`
- `specs/007-rbac-capacidades-nomeadas/checklists/requirements.md`

## Planejamento

Executado `/speckit-plan` para a feature 007, gerando o plano tecnico e artefatos de design:

- `specs/007-rbac-capacidades-nomeadas/plan.md`
- `specs/007-rbac-capacidades-nomeadas/research.md`
- `specs/007-rbac-capacidades-nomeadas/data-model.md`
- `specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md`
- `specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md`
- `specs/007-rbac-capacidades-nomeadas/contracts/frontend-capabilities.md`
- `specs/007-rbac-capacidades-nomeadas/contracts/audit-and-tests.md`
- `specs/007-rbac-capacidades-nomeadas/quickstart.md`

Decisoes de planejamento:

- `public.capacidades_perfil` tera RLS habilitado e nao sera contrato direto para o frontend; leitura ocorre por `obter_capacidades_usuario()`.
- `tem_capacidade` complementa `permissao_modulo`: leitura/rota continuam por modulo; acoes sensiveis usam capacidade.
- Acoes com efeito de negocio (boleto, notificacao, exportacao, baixa, envio, geracao) tambem exigem capacidade, mesmo quando nao parecem escrita direta.
- Visualizador permanece como perfil tecnico minimo com zero capacidades e leitura restrita a relatorios/configuracoes proprias.
- Tecnico passa a depender de ownership para tarefas/apontamentos proprios, sem hardcode de perfil como regra principal.
- `audit-rpc.mjs` deve diferenciar guard de leitura (`permissao_modulo`) e guard de acao (`tem_capacidade`).

## Checklist de qualidade

Executado `/speckit-checklist` para a feature 007 com foco em qualidade dos requisitos de RBAC/capacidades antes da geração de tarefas.

Artefato criado:

- `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md`

O checklist valida completude, clareza, consistência, mensurabilidade e rastreabilidade dos requisitos sobre matriz de capacidades, perfis, RPCs, ownership, frontend, bugs funcionais, auditoria/testes e documentação.

## Verificacao do checklist

Verificado o checklist `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md` contra `spec.md`, `plan.md`, `data-model.md`, contratos e quickstart. Resultado inicial: 38 de 39 itens marcados como atendidos.

Lacuna CHK019 fechada em seguida:

- Tecnico ve o proprio membro e colegas com alocacao ativa nos mesmos projetos em andamento.
- Alocacao ativa significa `data_fim` nula ou maior/igual a data atual.
- Para colegas, a leitura limitada pode expor somente `id`, `nome`, `funcao`, `habilidades`, `status`, `capacidade` e `projeto_atual` restrito ao projeto compartilhado.
- `perfil_id`, `custo_hora`, permissoes, contatos sensiveis, historico de apontamentos e alocacoes fora dos projetos compartilhados ficam ocultos ou nulos.

Resultado atualizado: 39 de 39 itens do checklist marcados como atendidos.

## Geracao de tarefas

Executado `/speckit-tasks` para a feature 007 e criado `specs/007-rbac-capacidades-nomeadas/tasks.md`.

Resumo do backlog gerado inicialmente:

- Total: 90 tarefas.
- Setup compartilhado: 5 tarefas.
- Fundacao bloqueante: 5 tarefas.
- US1 - Autorizar acoes por capacidade nomeada: 15 tarefas.
- US2 - Corrigir trabalho diario do Tecnico: 15 tarefas.
- US3 - Remover Visualizador como persona operacional: 6 tarefas.
- US4 - Alinhar controles do frontend as capacidades: 13 tarefas.
- US5 - Corrigir fluxos funcionais afetados pela validacao: 8 tarefas.
- US6 - Impedir regressao por testes e auditoria: 8 tarefas.
- US7 - Documentar nova regra de autorizacao: 5 tarefas.
- Validacao final/polish: 10 tarefas.

Decisoes de tasking:

- MVP recomendado: Setup + Fundacao + US1, seguido por US2 e US3 antes dos demais P2.
- Testes foram incluidos antes da implementacao porque a spec exige pgTAP, Vitest, auditoria e validacao E2E.
- Tarefas mantem RPC-first, `tem_capacidade` como guarda de acao e `podeLer` separado de `pode()` no frontend.
- Migrations alvo definidas no backlog: `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql` e `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`.

## Correcao pos-analise

Executado `/speckit-analyze` e corrigidos os pontos levantados no backlog e artefatos de design:

- C1: US6 passou a ter tarefas explicitas por dominio para migrar RPCs de Clientes, Propostas/Contratos, Cobrancas, Equipe gerencial, Financeiro e Configuracoes/Relatorios.
- I1: ownership de tarefa propria corrigido para comparar `tarefas.responsavel_id` com o `membros_equipe.id` vinculado ao perfil do usuario autenticado.
- U1: validacao das cinco personas definida como Playwright/E2E, removendo a ambiguidade "manual ou Playwright".
- I2: tarefas de migration agora orientam criar o arquivo alvo ou renomear o arquivo gerado pelo Supabase CLI antes da edicao.
- U2: tarefas de criacao de testes deixam de ser "placeholder" e passam a pedir skeletons de testes falhando.

Resultado atualizado do backlog:

- Total: 96 tarefas.
- Setup compartilhado: 5 tarefas.
- Fundacao bloqueante: 5 tarefas.
- US1: 15 tarefas.
- US2: 15 tarefas.
- US3: 6 tarefas.
- US4: 13 tarefas.
- US5: 8 tarefas.
- US6: 14 tarefas.
- US7: 5 tarefas.
- Validacao final/polish: 10 tarefas.

## Proxima etapa

Executar `/speckit-implement` quando a implementacao da feature 007 for aprovada.
