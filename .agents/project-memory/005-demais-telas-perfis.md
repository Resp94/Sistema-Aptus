# Spec 005 - Demais Telas por Perfil de Acesso

**Data**: 2026-06-28

## O que foi feito

Criada a especificacao `specs/005-demais-telas-perfis/spec.md` para cobrir as rotas ainda renderizadas como modulo nao migrado: Fluxo de Caixa, Contas a Pagar, Contas a Receber, Propostas, Contratos, Cobrancas, Equipe, Relatorios e Configuracoes.

Em 2026-06-28, o planejamento da feature foi gerado com `speckit-plan`, incluindo `plan.md`, `research.md`, `data-model.md`, `quickstart.md` e contratos RPC por dominio em `contracts/`.

Em 2026-06-28, foi criado o checklist `specs/005-demais-telas-perfis/checklists/requirements-readiness.md` com foco em qualidade dos requisitos antes da geracao de tarefas.

Em 2026-06-28, o checklist `requirements-readiness.md` foi verificado: 30 de 48 itens foram marcados como completos e 18 permaneceram abertos por gaps de requisitos.

Em 2026-06-28, os 18 gaps abertos do checklist foram corrigidos nos artefatos da feature e o checklist passou para 48/48 itens completos.

Em 2026-06-28, foi gerado o `tasks.md` da feature com 104 tarefas executaveis, organizadas por setup, fundacao, seis user stories e polish. A lista inclui migracoes Supabase criadas via `supabase migration new`, RLS/grants/RPCs, seeds por perfil, services/types React, paginas por rota, testes por dominio e gates finais de quickstart.

Em 2026-06-28, apos `/speckit-analyze`, o backlog foi corrigido para 106 tarefas. As correcoes moveram a base compartilhada de `/cobrancas` para a US1 Financeiro, deixaram a US2 Comercial como extensao da mesma pagina, tornaram a remocao do loop de placeholder responsabilidade de cada wiring por historia, adicionaram medicao explicita de performance por familia de rota e removeram duplicidade textual de filtros sem resultado na spec.

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
- As tarefas da feature devem ser executadas na ordem: Setup, Foundational, US1 Financeiro como MVP com a base compartilhada de `CobrancasPage`, US2 Comercial estendendo a mesma pagina, US3 Equipe, US4 Configuracoes, US5 Relatorios, US6 Navegacao e Polish.
- As tarefas reforcam que migracoes Supabase devem ser criadas com `npx supabase migration new`, sem inventar nomes timestampados manualmente.
- Cada tarefa de wiring por historia deve remover seus modulos do loop de placeholder em `src/App.tsx`; US6 funciona como auditoria final para garantir que nenhuma rota em escopo ainda renderize `ModuloNaoMigrado`.

## Arquivos afetados

- `specs/005-demais-telas-perfis/spec.md`
- `specs/005-demais-telas-perfis/plan.md`
- `specs/005-demais-telas-perfis/research.md`
- `specs/005-demais-telas-perfis/data-model.md`
- `specs/005-demais-telas-perfis/quickstart.md`
- `specs/005-demais-telas-perfis/contracts/*.md`
- `specs/005-demais-telas-perfis/checklists/requirements.md`
- `specs/005-demais-telas-perfis/checklists/requirements-readiness.md`
- `specs/005-demais-telas-perfis/tasks.md`
- `AGENTS.md`
- `CLAUDE.md`
- `.specify/feature.json`
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/knowledge/architecture.md`

## 2026-07-07 - Correcao do primeiro acesso em Configuracoes

### O que foi feito

Foi corrigido o fluxo de primeiro acesso da aba `Dados da Empresa`. O problema ocorria quando `obter_configuracoes_empresa()` era chamada antes de existir a linha singleton `config_unica` em `public.configuracoes_empresa`. O backend agora garante esse bootstrap ja na leitura por meio da migration `supabase/migrations/20260708020859_bootstrap_configuracoes_empresa_read.sql`.

No frontend, `configuracoesService.obterConfiguracoesEmpresa()` passou a normalizar retorno nulo, indefinido ou vazio para uma estrutura inicial segura. Isso impede que a tela dependa de casts otimistas quando a RPC ainda nao entregou um objeto completo.

Tambem foi adicionado um teste de regressao em `src/services/configuracoes.service.test.ts` para fixar o comportamento esperado no primeiro acesso.

### Por que foi feito

A aba administrativa precisa abrir utilizavel no onboarding inicial. O comportamento antigo exigia que a primeira escrita criasse a linha base, mas a primeira interacao do usuario e justamente a leitura da tela. Isso gerava estado inconsistente e erro de comportamento antes do primeiro salvamento.

### Regras registradas

- `public.configuracoes_empresa` continua sendo um singleton identificado por `config_unica`.
- O bootstrap desse singleton deve acontecer antes da primeira leitura administrativa, nao apenas na primeira escrita.
- O service do frontend deve devolver um objeto utilizavel para a UI mesmo quando a RPC vier sem linha util, preservando defaults do dominio.

### Arquivos afetados

- `supabase/migrations/20260708020859_bootstrap_configuracoes_empresa_read.sql`
- `src/services/configuracoes.service.ts`
- `src/services/configuracoes.service.test.ts`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`
- `.sauron/wiki/knowledge/module-data-schema.md`

## 2026-07-07 - Cadastro direto de usuario por admin em Configuracoes

### O que foi feito

Foi implementado o fluxo ausente de criacao de usuario na aba `Contas e Acessos`. Em vez de depender de convite, o administrador agora pode abrir um modal na propria pagina `Configuracoes`, informar nome, e-mail, senha temporaria, perfil de acesso, status e departamento, e concluir o cadastro imediatamente.

No frontend, a pagina ganhou estado e formulario dedicados ao novo modal, alem do service `configuracoesService.criarUsuarioConfiguracoes()`. No banco, a migration `supabase/migrations/20260708025456_create_usuario_configuracoes.sql` adiciona a RPC `public.criar_usuario_configuracoes(payload jsonb)` para provisionar a conta diretamente em `auth.users` e `auth.identities`.

### Por que foi feito

O comportamento esperado do onboarding administrativo e que o primeiro administrador consiga estruturar a empresa e criar os demais acessos sem depender de convite externo ou fluxo fora da tela. O erro relatado nao era um problema de permissao do admin, e sim ausencia do fluxo real de criacao.

### Regras registradas

- O fluxo administrativo de criacao de usuarios em `Configuracoes` nao usa link de convite.
- Apenas administradores com a capacidade `configuracoes.gerenciar_usuarios` podem cadastrar contas.
- O payload minimo obrigatorio e `nome`, `email` e `senha_temporaria`.
- A senha temporaria deve ter no minimo 8 caracteres.
- O perfil deve ser um valor valido do RBAC oficial: `Administrador`, `Financeiro`, `Projetos`, `Comercial`, `Tecnico` ou `Visualizador`.
- O e-mail deve ser unico no `auth.users`.
- A trigger de sincronizacao de `auth.users` continua sendo a responsavel por materializar `public.usuarios` e `public.perfis`; a RPC apenas complementa os dados finais de perfil depois da criacao.

### Arquivos afetados

- `supabase/migrations/20260708025456_create_usuario_configuracoes.sql`
- `src/pages/ConfiguracoesPage.tsx`
- `src/pages/ConfiguracoesPage.css`
- `src/services/configuracoes.service.ts`
- `src/services/configuracoes.service.test.ts`
- `src/pages/ConfiguracoesPage.test.tsx`
- `src/types/configuracoes.ts`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`
- `.sauron/wiki/knowledge/module-data-schema.md`
- `.sauron/wiki/knowledge/login-e-autenticacao.md`

## 2026-07-08 - Descontinuacao do avatar/foto de perfil em Configuracoes

### O que foi feito

Foi registrada a descontinuacao definitiva do contrato de avatar/foto de perfil associado a `Configuracoes` e ao perfil do usuario. A feature nao sera migrada para Supabase Storage nem para outro mecanismo de upload. O estado-alvo passa a remover `avatar_url` da documentacao funcional e do modelo atual de dados, preservando apenas o historico da decisao.

Tambem foi consolidado que o shell continua representando o usuario apenas pelas iniciais do nome, sem fallback de imagem, sem upload manual e sem dependencia de URL externa de avatar.

### Por que foi feito

O campo `avatar_url` permaneceu como contrato vivo na documentacao apesar de nao sustentar uma experiencia real de produto e nao ter plano aprovado de persistencia/entrega. Manter esse campo como se estivesse ativo aumentava o risco de drift entre frontend, backend e memoria do projeto.

### Regras registradas

- A feature de avatar/foto de perfil foi descontinuada por decisao de produto e arquitetura.
- Nao deve haver migracao dessa feature para Supabase Storage.
- O contrato atual de perfil/configuracoes nao inclui `avatar_url`.
- O shell de autenticacao e navegacao continua exibindo apenas as iniciais do nome do usuario.
- O historico da decisao deve ser preservado em `.agents` e `.sauron`, sem reescrever entradas antigas.

### Arquivos afetados

- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/knowledge/architecture.md`
- `.sauron/wiki/knowledge/module-data-schema.md`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`
- `docs/banco-de-dados.md`
- `docs/telas.md`

## 2026-07-08 - Spec para estado "Em breve" em Preferencias de Notificacoes

### O que foi feito

Foi escrita a spec `docs/superpowers/specs/2026-07-08-notificacoes-em-breve-design.md` para redefinir a seção `Preferências de Notificações` da aba `Minha Conta` como um placeholder honesto de produto, em vez de uma configuração ativa.

A spec formaliza que a UI deve manter o card, remover os toggles e substituí-los por um estado estático `Em breve`, com mensagem curta explicando que notificações personalizadas por canal ainda não estão disponíveis.

### Por que foi feito

O comportamento atual sugere uma funcionalidade pronta, mas hoje nenhuma preferência salva entrega notificações reais no sistema. Isso transforma a seção em promessa falsa de produto e gera ruído adicional quando a lista aparece vazia por depender de seed.

### Regras registradas

- Enquanto não houver entrega real de notificações, a seção não deve exibir controles interativos.
- O card de notificações deve permanecer visível para preservar a intenção futura da funcionalidade.
- O estado aprovado para esta etapa e `Em breve`, sem data prometida.
- A experiência da tela não deve depender da existência de linhas em `public.preferencias_notificacoes`.
- A reativação futura dos toggles exige fluxo real de entrega e defaults explícitos para todos os perfis.

### Arquivos afetados

- `docs/superpowers/specs/2026-07-08-notificacoes-em-breve-design.md`
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`

## 2026-07-08 - Plano de implementacao para "Em breve" em Preferencias de Notificacoes

### O que foi feito

Foi escrito o plano `docs/superpowers/plans/2026-07-08-notificacoes-em-breve.md` para implementar a decisao aprovada na spec de notificacoes. O plano divide o trabalho em testes de regressao da pagina, troca da UI por placeholder estatico, limpeza da superficie morta do frontend e atualizacao da documentacao funcional.

### Por que foi feito

A spec aprovada ja fixou a direcao de produto. Faltava o desdobramento operacional em passos executaveis, pequenos e verificaveis, sem expandir o escopo para backend/schema que permanecem fora desta etapa.

### Regras registradas

- A implementacao desta iteracao fica restrita ao frontend e a documentacao.
- `public.preferencias_notificacoes` e suas RPCs permanecem intactas no backend nesta etapa.
- O frontend deve deixar de depender de leitura/escrita de preferencias para renderizar `Minha Conta`.
- A verificacao obrigatoria inclui teste direcionado da pagina, teste do service e build completo.

### Arquivos afetados

- `docs/superpowers/plans/2026-07-08-notificacoes-em-breve.md`
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`

## 2026-07-08 - Implementacao do placeholder "Em breve" em Preferencias de Notificacoes

### O que foi feito

Foi implementada a troca dos toggles interativos de `Preferências de Notificações` por um placeholder estático `Em breve` na aba `Minha Conta` de `Configurações`. Os métodos `listarPreferenciasNotificacoes` e `atualizarPreferenciasNotificacoes` foram removidos do service e do types do frontend, junto com o tipo `PreferenciaNotificacaoItem`. A interface agora exibe apenas o card informativo sem toggles e sem depender de RPCs/seed para essa seção.

### Por que foi feito

A seção anterior exibia controles interativos que sugeriam uma funcionalidade pronta, mas nenhuma preferência salva entrega notificações reais no sistema. O placeholder honesto evita promessa falsa de produto.

### Regras registradas

- A UI de notificacoes nao deve exibir toggles enquanto nao houver entrega real.
- O card permanece visivel para preservar a intencao futura da funcionalidade.
- O backend e schema de `public.preferencias_notificacoes` nao foram modificados.
- A reativacao futura exige fluxo real de entrega.

### Arquivos afetados

- `src/pages/ConfiguracoesPage.tsx`
- `src/pages/ConfiguracoesPage.css`
- `src/services/configuracoes.service.ts`
- `src/types/configuracoes.ts`
- `src/pages/ConfiguracoesPage.test.tsx`
- `docs/telas.md`
- `docs/banco-de-dados.md`
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`
