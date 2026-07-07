# Arquitetura do Sistema Aptus

## 1. Contexto

O Sistema Aptus é uma aplicação web para administração empresarial, atualmente construída como conjunto de páginas estáticas em HTML/CSS/JS puro. O projeto utiliza o stack **Vite + React** como direção tecnológica, mas ainda não possui um backend próprio ou banco de dados ativo integrado ao frontend.

## 2. Responsabilidade

Esta página registra as decisões arquiteturais do projeto, incluindo:
- Stack tecnológico adotado e justificativas.
- Decisões sobre backend, banco de dados e serviços externos.
- Mudanças que afetam a estrutura geral do projeto.

Não faz parte desta página:
- Especificações visuais ou de design de telas individuais.
- Documentação de processos de negócio detalhados.

## 3. Decisões Arquiteturais

### DA-001 — Remoção do Supabase CLI
- **Problema**: Houve uma tentativa inicial de configurar o Supabase CLI localmente para o projeto, mas o comando `supabase link` falhou porque o CLI não estava disponível no PATH. Além disso, o projeto ainda não possui integração ativa com Supabase no frontend.
- **Options Considered**:
  - Instalar o Supabase CLI globalmente e vincular a um projeto remoto.
  - Manter apenas a configuração local (`supabase/`) sem vincular a um projeto.
  - Remover completamente as configurações e dependências do Supabase CLI até que haja necessidade real.
- **Choice**: Remover completamente as configurações e dependências do Supabase CLI.
- **Justification**: O projeto ainda está em fase de definição de arquitetura. Manter uma configuração de backend/BaaS sem uso imediato adiciona complexidade e dependências não utilizadas. A remoção mantém o repositório enxuto e evita configurações órfãs.
- **Trade-offs**:
  - *Prós*: Repositório mais limpo, menos dependências, decisão adiada até que o backend seja realmente necessário.
  - *Contras*: Quando o backend for necessário, será preciso reconfigurar o Supabase (ou outra solução) do zero.

### DA-002 — Adoção de Supabase + Cloudflare como stack base
- **Problema**: O projeto precisa de uma stack tecnológica definida para suportar persistência, autenticação, hospedagem e desenvolvimento local reproduzível.
- **Options Considered**:
  - Supabase (BaaS) + Cloudflare (hosting) + Vite/React (frontend).
  - Firebase + Vercel + Vite/React.
  - Backend próprio (Node/Express/PostgreSQL) + hospedagem própria.
- **Choice**: Supabase para backend, banco de dados e autenticação; Cloudflare para hospedagem do frontend; Vite + React para o frontend; desenvolvimento local via Supabase CLI com Docker.
- **Justification**: Supabase oferece PostgreSQL gerenciado, autenticação integrada e APIs automáticas; Cloudflare oferece hospedagem edge confiável; Vite + React é a diretriz global do projeto; desenvolvimento local via Docker evita custos e protege os dados de produção durante a construção de funcionalidades.
- **Trade-offs**:
  - *Prós*: Menor tempo de setup, backend gerenciado, ambiente local fiel à produção, custo previsível.
  - *Contras*: Vendor lock-in parcial, necessidade de sincronizar schema/migrações entre local e nuvem.

### DA-003 — RBAC por capacidades nomeadas para ações sensíveis
- **Problema**: A matriz `pode_ler`/`pode_escrever` por módulo é suficiente para navegação e leitura, mas não representa ações finas dentro do mesmo módulo. A validação E2E das personas em 2026-07-03 mostrou o problema no perfil Técnico: ele precisa mover tarefas próprias e apontar horas próprias, mas não pode criar/excluir projetos nem gerenciar equipe.
- **Options Considered**:
  - Manter apenas permissões por módulo e corrigir botões pontualmente.
  - Criar capacidades nomeadas por ação, consumidas pelo frontend e validadas pelas RPCs.
  - Criar contratos de tela altamente acoplados, com cada RPC de listagem retornando todas as ações permitidas da página.
- **Choice**: Adotar capacidades nomeadas como fonte canônica de autorização de ações, mantendo permissões por módulo para rota, leitura e navegação. A fundação canônica especificada para a próxima implementação é `public.capacidades_perfil`, `tem_capacidade(p_capacidade text)` e `obter_capacidades_usuario()`.
- **Justification**: A capacidade nomeada resolve a causa raiz sem quebrar RPC-first: o frontend usa a lista de capacidades para exibir controles, e o backend valida a mesma capacidade antes de executar mutações. Isso evita tanto excesso de privilégio quanto botões ausentes para ações legítimas.
- **Trade-offs**:
  - *Prós*: Menor ambiguidade por perfil, autorização mais testável, UX alinhada ao backend, evolução auditável da matriz.
  - *Contras*: Exige migrar RPCs de escrita, atualizar gates do frontend e manter testes de matriz/ownership para impedir drift.

### DA-004 — Exportação persistente de relatórios com re-download
- **Problema**: A página Relatórios atualmente registra solicitações de exportação como pendentes/indisponíveis, sem gerar PDF/CSV real. A nova necessidade é gerar e baixar relatórios completos imediatamente, mantendo histórico que permita baixar arquivos anteriores.
- **Options Considered**:
  - Gerar arquivos localmente no navegador, sem persistência.
  - Gerar arquivos de forma centralizada, persistir o artefato e registrar histórico baixável.
  - Manter apenas solicitação assíncrona sem arquivo imediato.
- **Choice**: Especificar exportação real de PDF e CSV por categoria selecionada, com período obrigatório, histórico persistente, re-download enquanto válido e expiração em 12 meses. O desenho técnico aprovado usa Supabase Edge Function para geração e download, RPCs para autorização/dados, e bucket privado de Storage para os arquivos.
- **Justification**: A persistência do arquivo torna o histórico útil, evita sucesso simulado e permite auditoria operacional. A separação entre leitura e exportação preserva a matriz de capacidades: Visualizador continua apenas lendo, enquanto Administrador, Financeiro e Projetos exportam somente quando possuem `relatorios.exportar`. O histórico segue escopo por persona: Administrador acessa todos os arquivos válidos; Financeiro e Projetos acessam apenas os próprios. A Edge Function mantém geração e assinatura de download no servidor, sem expor service role ou URL pública permanente.
- **Trade-offs**:
  - *Prós*: Download imediato, histórico reutilizável, rastreabilidade, experiência consistente para PDF e CSV.
  - *Contras*: Exige contrato de dados completos por categoria, armazenamento de arquivos, política de expiração, validações adicionais de autorização no download posterior, geração de pacote para CSV quando houver resumo e detalhes e manutenção de uma Edge Function server-side.

### DA-005 — Promocao controlada do backend Supabase para producao
- **Problema**: A feature 008 foi validada localmente, mas a Edge Function precisa ser verificada contra o Supabase Cloud real. O projeto de destino `lpwnaxlczwntylcmgotm` foi confirmado como producao real, entao a subida nao pode ser tratada como sincronizacao simples de ambiente local.
- **Options Considered**:
  - Promover somente migrations versionadas, Edge Function e configuracao validada com gates manuais.
  - Copiar dump completo do banco local para producao.
  - Aplicar SQL manual no Dashboard.
- **Choice**: Promover apenas backend versionado e validado, com confirmacao de destino, backup/snapshot recuperavel, dry-run, aprovacao manual explicita, `db push` sem seed/dados locais, deploy separado da Edge Function, smoke test remoto com usuarios temporarios e troca de `.env.local` somente apos validacao remota completa.
- **Justification**: Producao real exige rastreabilidade e pontos de parada. Migrations preservam historico; dry-run e aprovacao manual reduzem risco de mudancas inesperadas; backup/snapshot protege contra falha irreversivel; smoke test com usuarios temporarios valida Auth/RPC/RLS/Storage/Edge Function sem depender de usuarios reais ainda inexistentes.
- **Trade-offs**:
  - *Prós*: Menor risco operacional, sem transporte de dados locais, validacao real de autorizacao e limpeza documentada dos usuarios temporarios.
  - *Contras*: Processo mais lento, exige aprovacao manual e confirmacao externa de backup/snapshot antes da aplicacao.

### DA-006 — Conformidade Supabase guiada por advisors, triagem versionada e validacao remota
- **Problema**: O projeto de producao `lpwnaxlczwntylcmgotm` passou a apresentar um conjunto misto de achados do Supabase Advisors: um caso direto de RLS sem policy (`public.capacidades_perfil`), varios warnings de `SECURITY DEFINER` ainda expostos e warnings de performance ligados a policies antigas de RLS. Parte do SQL versionado ja parece endurecer grants, mas o advisor remoto continua acusando exposicao, indicando possivel drift remoto ou assinaturas/grants residuais.
- **Options Considered**:
  - Corrigir apenas os casos obvios e tratar o restante como excecao manual fora do repositório.
  - Abrir uma feature dedicada para triagem, remediacao versionada e validacao remota dos advisors no escopo de RLS/RPC.
  - Fazer uma faxina ampla de todos os advisors, incluindo tuning geral de indices e foreign keys.
- **Choice**: Criar uma feature dedicada de conformidade (`010-corrigir-advisors-supabase`) focada em risco real de seguranca e warnings de performance ligados a RLS/RPC, com triagem versionada (`triagem.md`), artefatos SQL em `supabase/migrations/`, criterio de dependencia viva para preservar funcoes `SECURITY DEFINER` e validacao remota via MCP do Supabase antes da conclusao.
- **Justification**: Separar a promocao operacional da correcao estrutural deixa a auditoria mais clara. A triagem versionada evita conhecimento tacito, o criterio de dependencia viva reduz superficie de ataque por inercia, e a validacao remota fecha a lacuna entre o estado esperado do repositório e o estado efetivo do projeto de producao.
- **Trade-offs**:
  - *Prós*: Escopo controlado, correcoes auditaveis, rastreabilidade das excecoes e maior confianca na leitura do estado remoto real.
  - *Contras*: Processo mais detalhado, exige classificacao objeto a objeto e nao resolve tuning amplo fora do escopo.

### DA-007 — Endurecimento de RLS/RPC e Remediacao de Performance de Policies
- **Problema**: O linter/advisors do Supabase apontou ineficiencias de performance (warnings `auth_rls_initplan` devido ao uso direto de `auth.uid()` em predicates RLS e `multiple_permissive_policies` em `public.perfis`) e riscos de seguranca (falta de policy explicita em tabelas internas e RPCs `SECURITY DEFINER` expostas a `anon` e `PUBLIC`).
- **Options Considered**:
  - Manter predicates RLS originais e confiar em tuning de indices para compensar.
  - Reescrever predicates RLS convertendo chamadas diretas de `auth.uid()` para subconsultas indexadas `(select auth.uid())` e unificar policies de SELECT/UPDATE em `public.perfis`. Revogar grants publicos das 48 RPCs de escrita e exportacao da namespace public, blindando execucoes `SECURITY DEFINER`.
- **Choice**: Reescrever os predicates para a sintaxe de subconsulta `(select auth.uid())`, consolidar as policies de `public.perfis` e revogar os grants de `PUBLIC` e `anon` em todas as RPCs de escrita/exportacao do escopo, preservando apenas grants especificos condicionados a Whitelist e RBAC.
- **Justification**: A subconsulta `(select auth.uid())` permite que o Postgres execute a subconsulta como um InitPlan de execucao unica por query, em vez de avaliar a funcao `auth.uid()` para cada linha da tabela (o que degradava performance linearmente). A consolidacao de RLS em `public.perfis` reduz o overhead de multiplos scans. O endurecimento de RPCs `SECURITY DEFINER` via `REVOKE EXECUTE ... FROM PUBLIC` garante que apenas papeis explicitamente autorizados (como `authenticated` ou `service_role`) executem operacoes privilegiadas na namespace `public`.
- **Trade-offs**:
  - *Prós*: Eliminacao de warnings do linter remoto, grande ganho de performance em scans de tabelas centrais, seguranca blindada contra execucao anonima de RPCs de escrita.
  - *Contras*: Maior complexidade na escrita de migrations, necessidade de cobertura extensa pgTAP de grants para evitar regressao.

## 4. Change History

### 2026-06-26 — Implementação e ativação da nova stack tecnológica
- **What was done**: Implementamos a fundação tecnológica da aplicação. Criamos o scaffold Vite + React + TypeScript na raiz, instalamos dependências de runtime (React 19, Supabase JS) e desenvolvimento (ESLint, Prettier, Vitest), configuramos atalhos npm para o Supabase local, e estabelecemos a conexão e testes unitários/smoke. Também documentamos os processos de deploy na Cloudflare Pages e a resolução de problemas comuns. O arquivo original `index.html` foi movido para `index.legacy.html` como referência.
- **Why it was done**: Ativar a nova stack de forma prática, conectando o frontend ao banco de dados e preparando o ambiente local de testes e o fluxo de CI/CD.
- **Impact on the system**: O projeto passou de páginas HTML estáticas soltas para uma aplicação moderna empacotada com Vite e React, integrada ao Supabase CLI rodando localmente no Docker.
- **Files affected**:
  - Criado/Configurado: `.gitignore`, `.dockerignore`, `.prettierignore`, `.eslintignore`, `.prettierrc`, `.eslintrc.cjs`
  - Criado/Configurado: `vite.config.ts`, `tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json`, `package.json`
  - Criado: `src/services/supabase.ts`, `src/services/health-check.ts`, `src/services/supabase.test.ts`
  - Criado: `docs/stack.md`
  - Alterado: `specs/002-tech-stack-definition/tasks.md`
  - Renomeado: `index.html` para `index.legacy.html`

### 2026-06-26 — Verificação do checklist da stack tecnológica
- **What was done**: Foi realizada a revisão do checklist `specs/002-tech-stack-definition/checklists/stack-definition.md`. Dos 34 itens, 29 foram marcados como atendidos e 5 (CHK021, CHK022, CHK025, CHK028, CHK031) foram deixados não-marcados por representarem gaps aceitáveis para a feature de definição de stack (disaster recovery de hospedagem, setup sem Docker, criação/ownership de contas externas, requisitos de segurança detalhados e restrições de custo).
- **Why it was done**: A etapa de implementação estava bloqueada pela necessidade de concluir a verificação de qualidade do checklist, conforme workflow Speckit.
- **Impact on the system**: Nenhum impacto funcional. Ajustes documentacionais e registro das exceções de qualidade.
- **Files affected**:
  - Alterado: `specs/002-tech-stack-definition/checklists/stack-definition.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-26 — Sincronização da documentação com as telas HTML
- **What was done**: As documentações de telas, personas e banco de dados foram refatoradas para refletir as 13 telas HTML ativas na raiz do projeto. Telas legadas (`index.html`, `financeiro.html`) foram removidas da documentação ativa. Foi adicionada a persona Profissional Técnico para representar desenvolvedores alocados em projetos. O schema de banco de dados foi expandido com tabelas em pt-BR para fornecedores, contas a pagar/receber, fluxo de caixa, equipe, alocações, relatórios e configurações, e a tabela `usuarios` foi definida como espelho do auth provider.
- **Why it was done**: A documentação estava desatualizada em relação ao estado real das telas HTML, o que gerava inconsistência entre telas, personas e modelo de dados.
- **Impact on the system**: Nenhum impacto funcional imediato, pois as mudanças são documentacionais. O modelo de dados planejado agora suporta todos os módulos visíveis nas telas.
- **Files affected**:
  - Alterado: `docs/telas.md`
  - Alterado: `docs/personas.md`
  - Alterado: `docs/banco-de-dados.md`
  - Alterado: `docs/aptus-prd.md`

### 2026-06-28 — Especificação das demais telas por perfil de acesso
- **What was done**: Foi criada a feature Spec Kit `005-demais-telas-perfis` para especificar a migração das rotas ainda exibidas como "Módulo Não Migrado": Fluxo de Caixa, Contas a Pagar, Contas a Receber, Propostas, Contratos, Cobranças, Equipe, Relatórios e Configurações. A especificação define `reference/legacy-html/` como fonte principal dos exemplos visuais e comportamentais; `docs/telas.md` permanece apenas como documentação auxiliar de rotas, objetivos e permissões.
- **Why it was done**: As features anteriores entregaram autenticação, redirecionamento por persona e as landings principais (`Dashboard`, `Projetos`, `Clientes`). O próximo corte arquitetural é completar os fluxos de cada perfil de acesso, preservando RBAC, dados persistidos e ausência de mocks.
- **Impact on the system**: Nenhum código funcional foi alterado nesta etapa, mas a direção arquitetural da próxima implementação foi definida: todas as rotas autorizadas em escopo devem substituir o placeholder por telas reais, com estados de carregamento/vazio/erro, auditoria de ações destrutivas e tratamento honesto para integrações externas ainda não configuradas.
- **Files affected**:
  - Criado: `specs/005-demais-telas-perfis/spec.md`
  - Criado: `specs/005-demais-telas-perfis/checklists/requirements.md`
  - Criado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.specify/feature.json`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-28 — Planejamento da feature 005 e contratos RPC
- **What was done**: Foi executado o fluxo `speckit-plan` para a feature `005-demais-telas-perfis`, gerando `plan.md`, `research.md`, `data-model.md`, `quickstart.md` e contratos RPC por domínio (`financeiro`, `comercial`, `equipe`, `relatórios/configurações` e rotas UI).
- **Why it was done**: Transformar a especificação em um plano técnico implementável antes da geração de tarefas, definindo a ordem de entrega, as entidades novas, a reutilização das fontes canônicas existentes e os contratos de integração entre frontend React e Supabase.
- **Impact on the system**: Nenhum código funcional foi alterado, mas foram tomadas decisões arquiteturais para a próxima implementação: `lancamentos` permanece a fonte financeira canônica; Contas a Pagar, Contas a Receber e Fluxo de Caixa serão projeções/RPCs sobre ela; novas RPCs devem validar `auth.uid()`, RBAC, `search_path` fixo e grants explícitos; integrações externas ausentes não podem retornar sucesso simulado.
- **Files affected**:
  - Criado/Atualizado: `specs/005-demais-telas-perfis/plan.md`
  - Criado: `specs/005-demais-telas-perfis/research.md`
  - Criado: `specs/005-demais-telas-perfis/data-model.md`
  - Criado: `specs/005-demais-telas-perfis/quickstart.md`
  - Criado: `specs/005-demais-telas-perfis/contracts/financeiro-rpc.md`
  - Criado: `specs/005-demais-telas-perfis/contracts/comercial-rpc.md`
  - Criado: `specs/005-demais-telas-perfis/contracts/equipe-rpc.md`
  - Criado: `specs/005-demais-telas-perfis/contracts/relatorios-configuracoes-rpc.md`
  - Criado: `specs/005-demais-telas-perfis/contracts/ui-routes.md`
  - Alterado: `CLAUDE.md`
  - Alterado: `AGENTS.md`
  - Alterado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-28 — Checklist de readiness dos requisitos da feature 005
- **What was done**: Foi criado o checklist `requirements-readiness.md` para validar a qualidade dos requisitos da feature 005 antes da geração de tarefas.
- **Why it was done**: A feature tem alto risco de ambiguidade por combinar 9 rotas, RBAC por perfil, RPC-first, ausência de mocks, integração externa pendente e reaproveitamento de entidades da feature 004. O checklist funciona como "unit tests" dos requisitos escritos.
- **Impact on the system**: Nenhum código funcional foi alterado. O checklist adiciona critérios de revisão para completude, clareza, consistência, mensurabilidade, cobertura de cenários, edge cases, requisitos não funcionais, dependências e ambiguidades.
- **Files affected**:
  - Criado: `specs/005-demais-telas-perfis/checklists/requirements-readiness.md`
  - Alterado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-28 — Verificação do checklist de readiness da feature 005
- **What was done**: O checklist `requirements-readiness.md` foi verificado contra a spec, plano, data model, contratos e quickstart da feature 005. Foram marcados 30 de 48 itens como completos e mantidos 18 itens abertos com justificativa.
- **Why it was done**: Avaliar se os requisitos estavam suficientemente claros e completos antes da geração de tarefas, evitando que ambiguidades de RBAC, dados, integrações externas ou estados de tela sejam empurradas para a implementação.
- **Impact on the system**: Nenhum código funcional foi alterado. A verificação identificou gaps que devem ser resolvidos antes de `/speckit-tasks`, incluindo matriz de seeds por perfil/rota, ownership de `cobrancas`, recovery, empty states por tipo de seção, acessibilidade, responsividade, performance por família de rota, comportamento de sessão após mudança de perfil, escopo entre `alocacoes_projeto` e `alocacoes_equipe`, e fonte única de status vencido.
- **Files affected**:
  - Alterado: `specs/005-demais-telas-perfis/checklists/requirements-readiness.md`
  - Alterado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-28 — Correção das pendências do checklist de readiness da feature 005
- **What was done**: Os 18 itens abertos do checklist `requirements-readiness.md` foram corrigidos nos artefatos da feature 005 e o checklist foi atualizado para 48/48 itens completos.
- **Why it was done**: Fechar ambiguidades antes de gerar tarefas, garantindo que seeds, integrações ausentes, ownership de `cobrancas`, recovery, estados vazios, filtros sem resultado, sessão após mudança de permissão, privacidade, acessibilidade, responsividade, performance por família de rota, alocações e status `Vencido` estejam especificados.
- **Impact on the system**: Nenhum código funcional foi alterado. A feature ficou pronta para `/speckit-tasks` do ponto de vista de qualidade dos requisitos.
- **Files affected**:
  - Alterado: `specs/005-demais-telas-perfis/spec.md`
  - Alterado: `specs/005-demais-telas-perfis/plan.md`
  - Alterado: `specs/005-demais-telas-perfis/research.md`
  - Alterado: `specs/005-demais-telas-perfis/data-model.md`
  - Alterado: `specs/005-demais-telas-perfis/quickstart.md`
  - Alterado: `specs/005-demais-telas-perfis/contracts/financeiro-rpc.md`
  - Alterado: `specs/005-demais-telas-perfis/contracts/comercial-rpc.md`
  - Alterado: `specs/005-demais-telas-perfis/contracts/equipe-rpc.md`
  - Alterado: `specs/005-demais-telas-perfis/contracts/relatorios-configuracoes-rpc.md`
  - Alterado: `specs/005-demais-telas-perfis/contracts/ui-routes.md`
  - Alterado: `specs/005-demais-telas-perfis/checklists/requirements-readiness.md`
  - Alterado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-28 — Geração de tarefas da feature 005
- **What was done**: Foi executado o fluxo `speckit-tasks` para `specs/005-demais-telas-perfis/`, gerando `tasks.md` com 104 tarefas no formato checklist Spec Kit. As tarefas foram organizadas em Setup, Foundational, seis user stories e Polish, cobrindo migrações Supabase, RLS/grants, RPCs por domínio, seeds por perfil, services/types React, páginas por rota, testes e gates finais.
- **Why it was done**: Transformar os artefatos de requisitos e planejamento em uma sequência executável de implementação, preservando o MVP Financeiro, a independência por perfil e as regras transversais de RPC-first, ausência de mocks, privacidade por perfil e integrações externas honestamente pendentes.
- **Impact on the system**: Nenhum código funcional foi alterado nesta etapa. A próxima implementação passa a ter backlog ordenado: US1 Financeiro como MVP; US2 Comercial e `cobrancas`; US3 Equipe; US4 Configurações; US5 Relatórios; US6 fechamento de navegação e remoção dos placeholders autorizados.
- **Files affected**:
  - Criado: `specs/005-demais-telas-perfis/tasks.md`
  - Alterado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-06-28 — Correção pós-análise das tarefas da feature 005
- **What was done**: Após `/speckit-analyze`, o `tasks.md` foi ajustado de 104 para 106 tarefas. A base compartilhada de `/cobrancas` passou para a US1 Financeiro, enquanto a US2 Comercial passou a estender essa mesma página com ações comerciais. As tarefas de wiring agora removem seus próprios módulos do loop de placeholder em `src/App.tsx`, e o polish passou a incluir medição explícita das metas de performance por família de rota. A spec também teve a duplicidade do edge case de filtros sem resultado removida e os requisitos de seeds foram diferenciados entre reprodutibilidade e matriz perfil/rota.
- **Why it was done**: Resolver inconsistências apontadas pela análise sem mudar o escopo funcional: US1 precisava ser testável independentemente com `/cobrancas`; a remoção do placeholder precisava acontecer incrementalmente para evitar conflitos de rota; e FR-033/SC-004 precisavam de tarefa verificável de performance.
- **Impact on the system**: Nenhum código funcional foi alterado. O backlog ficou mais executável e reduz o risco de duplicidade de rota, placeholder residual e falta de validação de performance.
- **Files affected**:
  - Alterado: `specs/005-demais-telas-perfis/spec.md`
  - Alterado: `specs/005-demais-telas-perfis/tasks.md`
  - Alterado: `.agents/project-memory/005-demais-telas-perfis.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Especificação do RBAC por capacidades nomeadas
- **What was done**: Foi criada a feature Spec Kit `007-rbac-capacidades-nomeadas`, definindo capacidades nomeadas no formato `recurso.acao` como a nova fonte canônica para autorização de ações sensíveis. A especificação preserva `obter_permissoes_usuario` para leitura, rota e navegação, mas direciona o frontend a abandonar `pode_escrever` como gate principal de botões. A fundação canônica especificada usa `public.capacidades_perfil`, `tem_capacidade(p_capacidade text)` e `obter_capacidades_usuario()`. Também registra a decisão de remover Visualizador como persona operacional, mantendo-o apenas como perfil técnico mínimo de signup.
- **Why it was done**: A validação E2E das personas mostrou desalinhamento entre frontend e backend quando a autorização depende apenas de escrita ampla por módulo. O perfil Técnico ficou sobreprivilegiado em Projetos, bloqueado em apontamento próprio e limitado demais na leitura de equipe.
- **Impact on the system**: Nenhum código funcional foi alterado nesta etapa. A próxima implementação passa a ter uma direção arquitetural clara: frontend usa capacidades para UX; RPCs usam capacidades para autorização real; testes e auditorias bloqueiam escrita sem capacidade nomeada.
- **Files affected**:
  - Criado: `specs/007-rbac-capacidades-nomeadas/spec.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/checklists/requirements.md`
  - Criado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.specify/feature.json`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Planejamento do RBAC por capacidades nomeadas
- **What was done**: Foi executado o fluxo `speckit-plan` para `specs/007-rbac-capacidades-nomeadas/`, gerando `plan.md`, `research.md`, `data-model.md`, `quickstart.md` e contratos de matriz, RPCs, frontend e auditoria/testes.
- **Why it was done**: Transformar a especificação de capacidades nomeadas em desenho técnico implementável, alinhando banco, frontend, testes e guardrails sem quebrar RPC-first.
- **Impact on the system**: Nenhum código funcional foi alterado nesta etapa. O plano consolida as decisões para a implementação: capacidades em `public.capacidades_perfil`, leitura por `obter_capacidades_usuario()`, autorização de ação por `tem_capacidade`, leitura/rota por `permissao_modulo`, Visualizador como perfil técnico mínimo e auditoria diferenciando leitura de ação.
- **Files affected**:
  - Criado/Atualizado: `specs/007-rbac-capacidades-nomeadas/plan.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/research.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/data-model.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/quickstart.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/contracts/frontend-capabilities.md`
  - Criado: `specs/007-rbac-capacidades-nomeadas/contracts/audit-and-tests.md`
  - Alterado: `AGENTS.md`
  - Alterado: `CLAUDE.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Checklist de qualidade da feature 007
- **What was done**: Foi criado o checklist `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md` para revisar a qualidade dos requisitos e contratos da feature de RBAC por capacidades nomeadas antes da geração de tarefas.
- **Why it was done**: A feature altera a fronteira de autorização do sistema. O checklist funciona como validação dos requisitos escritos, cobrindo completude, clareza, consistência, mensurabilidade e rastreabilidade, sem testar implementação.
- **Impact on the system**: Nenhum código funcional foi alterado. O checklist reduz risco de tarefas ambíguas para matriz de capacidades, RPCs, ownership, frontend, Visualizador, guardrails e documentação.
- **Files affected**:
  - Criado: `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Verificação do checklist da feature 007
- **What was done**: O checklist `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md` foi verificado contra spec, plano, data model, contratos e quickstart. Foram marcados 38 de 39 itens como atendidos.
- **Why it was done**: Confirmar quais requisitos de RBAC por capacidades nomeadas já estão claros o bastante antes da geração de tarefas, sem mascarar ambiguidades restantes.
- **Impact on the system**: Nenhum código funcional foi alterado. O item CHK019 permanece aberto porque a visibilidade de equipe do Técnico já define quais colegas são incluídos, mas ainda não fecha quais dados dos colegas permanecem limitados.
- **Files affected**:
  - Alterado: `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Fechamento da lacuna CHK019 da feature 007
- **What was done**: A regra de visibilidade limitada de equipe para Técnico foi especificada em spec, research, data model e contratos. Técnico passa a ver o próprio membro e colegas com alocação ativa nos mesmos projetos em andamento. Para colegas, a leitura limitada pode expor somente `id`, `nome`, `funcao`, `habilidades`, `status`, `capacidade` e `projeto_atual` restrito ao projeto compartilhado; `perfil_id`, `custo_hora`, permissões, contatos sensíveis, histórico de apontamentos e alocações fora dos projetos compartilhados ficam ocultos ou nulos. O checklist foi atualizado para 39 de 39 itens atendidos.
- **Why it was done**: Fechar a última ambiguidade antes da geração de tarefas, evitando que a implementação de `listar_membros_equipe` exponha equipe inteira, dados administrativos ou histórico fora do projeto compartilhado.
- **Impact on the system**: Nenhum código funcional foi alterado. A próxima implementação passa a ter um contrato verificável para a leitura limitada de equipe do Técnico.
- **Files affected**:
  - Alterado: `specs/007-rbac-capacidades-nomeadas/spec.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/research.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/data-model.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/contracts/audit-and-tests.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/checklists/rbac.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Geração de tarefas da feature 007
- **What was done**: Foi executado o fluxo `speckit-tasks` para `specs/007-rbac-capacidades-nomeadas/`, gerando `tasks.md` com 90 tarefas em formato checklist Spec Kit. As tarefas foram organizadas em Setup, Fundacional, sete user stories e validação final, com testes pgTAP/Vitest/auditoria antes das implementações que eles cobrem. O backlog definiu como migrations alvo `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql` e `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`.
- **Why it was done**: Transformar a especificação, plano, contratos, quickstart e checklist 39/39 em backlog executável, preservando RPC-first, guardrails de `tem_capacidade`, separação entre leitura por módulo e ação por capacidade, e validação por cinco personas operacionais.
- **Impact on the system**: Nenhum código funcional foi alterado. A próxima implementação passa a ter sequência definida: MVP com fundação de capacidades (US1), correção do Técnico (US2), remoção operacional do Visualizador (US3), gates frontend (US4), bugs funcionais (US5), auditoria/testes (US6) e documentação (US7).
- **Files affected**:
  - Criado: `specs/007-rbac-capacidades-nomeadas/tasks.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Correção pós-análise das tarefas da feature 007
- **What was done**: Após `/speckit-analyze`, os artefatos da feature 007 foram ajustados para fechar cinco pontos: expansão explícita das tarefas de migração das RPCs por domínio, correção do ownership de tarefa própria para `membros_equipe.id`, definição da validação final como Playwright/E2E, alinhamento das tarefas de migration com arquivos alvo/renomeação do arquivo gerado e remoção da linguagem de "placeholder" nos testes. O `tasks.md` passou de 90 para 96 tarefas.
- **Why it was done**: Evitar que a implementação siga um backlog incompleto para as ~35 RPCs de escrita/efeito, impedir uma checagem incorreta de ownership contra `auth.uid()` e remover ambiguidades que poderiam enfraquecer os gates de teste.
- **Impact on the system**: Nenhum código funcional foi alterado. O backlog ficou mais preciso antes de `/speckit-implement`, com US6 cobrindo Clientes, Propostas/Contratos, Cobranças, Equipe gerencial, Financeiro e Configurações/Relatórios de forma explícita.
- **Files affected**:
  - Alterado: `specs/007-rbac-capacidades-nomeadas/plan.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/research.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/data-model.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/contracts/audit-and-tests.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/tasks.md`
  - Alterado: `specs/007-rbac-capacidades-nomeadas/quickstart.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-03 — Fundação do RBAC por capacidades nomeadas e documentação da feature 007
- **What was done**: Foi implementada a migração `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`, criando a tabela `public.capacidades_perfil` (PK composta `perfil_acesso, capacidade`, RLS habilitado, sem grant a `authenticated`/`PUBLIC`), os helpers `public.tem_capacidade(p_capacidade text)` e `public.obter_capacidades_usuario()`, o seed da matriz inicial de 37 capacidades por perfil (Administrador com todas; Visualizador com zero linhas de propósito) e o ajuste de `public.obter_permissoes_usuario()` para que Visualizador passe a ter leitura mínima apenas em `relatorios`/`configurações` e `Projetos` continue sem Dashboard oficial. O arquivo `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql` foi criado como próximo passo (migração das ~35 RPCs de escrita/efeito de negócio para guardas `tem_capacidade`), ainda pendente de implementação. Em paralelo, a documentação da feature foi atualizada: `docs/personas.md` passou a deixar explícito que existem cinco personas operacionais (Administrador, Financeiro, Projetos, Comercial, Técnico) e que Visualizador não é mais persona operacional, e sim o perfil técnico mínimo de signup, com zero capacidades e leitura restrita a Relatórios/Configurações próprias; também documentou que o Dashboard é acesso oficial exclusivo de Administrador e Financeiro. `docs/arquitetura-dados.md` ganhou uma seção descrevendo `capacidades_perfil`, os helpers `tem_capacidade`/`obter_capacidades_usuario`, a regra central de autorização (`permissao_modulo` para leitura/rota, `tem_capacidade` para ações sensíveis) e a regra de consumo frontend/backend (capacidades só para UX; autorização real sempre na RPC).
- **Why it was done**: Fechar a fundação de banco definida no plano da feature 007 (tabela auditável + helpers canônicos + matriz inicial) e manter a documentação de personas/arquitetura sincronizada com a nova regra de autorização antes de migrar as RPCs de escrita/efeito e remover o Visualizador do fluxo operacional no frontend.
- **Impact on the system**: O banco já possui a fonte canônica de capacidades nomeadas e a leitura por módulo já reflete o Visualizador mínimo; nenhuma RPC de escrita/efeito foi migrada para `tem_capacidade` ainda (arquivo de guardas é placeholder), então a autorização de ações sensíveis continua, por ora, dependente das guardas antigas até a próxima migração. A documentação de personas e arquitetura de dados já reflete o estado-alvo (cinco personas operacionais, Visualizador mínimo, Dashboard oficial de Administrador/Financeiro, regra de capacidade nomeada).
- **Files affected**:
  - Criado: `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql`
  - Criado (placeholder, pendente): `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
  - Alterado: `docs/personas.md`
  - Alterado: `docs/arquitetura-dados.md`
  - Alterado: `.agents/project-memory/007-rbac-capacidades-nomeadas.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Especificação de exportação real de relatórios
- **What was done**: Foi criada a feature Spec Kit `008-exportar-relatorios`, definindo exportação completa de relatórios em PDF e CSV pela página Relatórios. A especificação exige categoria selecionada, data inicial, data final, download imediato, histórico com re-download, validade de 12 meses e respeito às personas/capacidades.
- **Why it was done**: O fluxo atual registra exportações como indisponíveis e não entrega arquivo real. A nova regra transforma a exportação em artefato operacional reutilizável, mantendo a separação entre leitura de relatórios e extração de arquivos.
- **Impact on the system**: Nenhum código funcional foi alterado nesta etapa. A próxima fase deve detalhar contratos, persistência, geração de arquivos, histórico, expiração e validação por persona.
- **Files affected**:
  - Criado: `specs/008-exportar-relatorios/spec.md`
  - Criado: `specs/008-exportar-relatorios/checklists/requirements.md`
  - Criado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.specify/feature.json`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Planejamento da exportação real de relatórios
- **What was done**: Foi executado o fluxo `speckit-plan` para `specs/008-exportar-relatorios/`, gerando plano técnico, pesquisa, modelo de dados, quickstart e contratos para Edge Function, RPCs, Storage/retencao, frontend e auditoria/testes. O plano define `relatorios-exportacao` como função server-side para gerar PDF ou ZIP CSV, salvar em bucket privado `relatorios-exportados`, concluir o historico em `exportacoes_relatorios` e retornar signed URL temporario. O desenho tambem expande o historico com periodo, solicitante, expiracao, metadados do arquivo e status de exibicao `Expirado` computado.
- **Why it was done**: Transformar os requisitos deliberados em arquitetura implementavel antes da geracao de tarefas, garantindo alinhamento entre front, RPCs, Storage, Edge Function, historico, validade de 12 meses e regras por persona.
- **Impact on the system**: Nenhum codigo funcional foi alterado nesta etapa. A proxima implementacao passa a ter contratos claros: frontend chama Edge Function, RPCs validam `relatorios.exportar` e escopo de categoria/historico, Storage permanece privado sem URL publica permanente, e Visualizador/Comercial/Tecnico permanecem bloqueados para exportacao/download.
- **Files affected**:
  - Criado/Atualizado: `specs/008-exportar-relatorios/plan.md`
  - Criado: `specs/008-exportar-relatorios/research.md`
  - Criado: `specs/008-exportar-relatorios/data-model.md`
  - Criado: `specs/008-exportar-relatorios/quickstart.md`
  - Criado: `specs/008-exportar-relatorios/contracts/edge-function-exportacao.md`
  - Criado: `specs/008-exportar-relatorios/contracts/rpc-exportacao-relatorios.md`
  - Criado: `specs/008-exportar-relatorios/contracts/storage-and-retention.md`
  - Criado: `specs/008-exportar-relatorios/contracts/frontend-relatorios.md`
  - Criado: `specs/008-exportar-relatorios/contracts/audit-and-tests.md`
  - Alterado: `AGENTS.md`
  - Alterado: `CLAUDE.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Checklist de qualidade do plano de exportação de relatórios
- **What was done**: Foi executado o fluxo `speckit-checklist` sobre `specs/008-exportar-relatorios/plan.md`, criando `specs/008-exportar-relatorios/checklists/plan-quality.md` com 46 itens de revisao de qualidade dos requisitos e do plano.
- **Why it was done**: Validar se a especificacao, plano, modelo de dados e contratos estao completos, claros, consistentes e mensuraveis antes de transformar a feature em tarefas executaveis.
- **Impact on the system**: Nenhum codigo funcional foi alterado. O checklist adiciona um gate documental para reduzir ambiguidades sobre categorias, conteudo completo por relatorio, periodo, CSV ZIP, historico, signed URLs, Storage privado, RBAC por persona, expiracao e falhas parciais.
- **Files affected**:
  - Criado: `specs/008-exportar-relatorios/checklists/plan-quality.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Validação do checklist de qualidade da feature 008
- **What was done**: Os 46 checkpoints de `specs/008-exportar-relatorios/checklists/plan-quality.md` foram validados contra spec, plano, research, data model e contratos. Foram marcados 32 itens como atendidos e mantidos 14 abertos com justificativa.
- **Why it was done**: Identificar lacunas documentais antes de gerar tarefas, evitando que ambiguidades sobre dados por categoria, boundary de datas, performance, acessibilidade, observabilidade, autorizacao por categoria e legado de RPC avancem para implementacao.
- **Impact on the system**: Nenhum codigo funcional foi alterado. A feature ainda precisa resolver os 14 checkpoints abertos antes de `/speckit-tasks` para reduzir risco de tarefas incompletas ou contraditorias.
- **Files affected**:
  - Alterado: `specs/008-exportar-relatorios/checklists/plan-quality.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Fechamento das lacunas do checklist da feature 008
- **What was done**: As 14 lacunas abertas do checklist `plan-quality.md` foram deliberadas e fechadas nos artefatos da feature 008. Foram definidas categorias exportaveis iniciais (Financeiro, DRE, Clientes, Projetos), exclusao de `Personalizado` no escopo 008, fonte canonica de categoria por persona, conteudo completo por categoria, semantica inclusiva de periodo e limite de 12 meses, volume operacional comum, cobertura PDF/CSV por persona, requisitos de acessibilidade/responsividade, observabilidade, bibliotecas `pdf-lib`/`fflate`, visibilidade do solicitante e descontinuacao do uso frontend da RPC legada.
- **Why it was done**: Remover ambiguidades antes de gerar tarefas, garantindo que front, Edge Function, RPCs, Storage, RBAC e historico tenham contratos alinhados.
- **Impact on the system**: Nenhum codigo funcional foi alterado. A feature 008 agora esta documentalmente pronta para `/speckit-tasks`, com checklist de qualidade 46/46 aprovado.
- **Files affected**:
  - Alterado: `specs/008-exportar-relatorios/spec.md`
  - Alterado: `specs/008-exportar-relatorios/plan.md`
  - Alterado: `specs/008-exportar-relatorios/research.md`
  - Alterado: `specs/008-exportar-relatorios/data-model.md`
  - Alterado: `specs/008-exportar-relatorios/quickstart.md`
  - Alterado: `specs/008-exportar-relatorios/contracts/edge-function-exportacao.md`
  - Alterado: `specs/008-exportar-relatorios/contracts/rpc-exportacao-relatorios.md`
  - Alterado: `specs/008-exportar-relatorios/contracts/frontend-relatorios.md`
  - Alterado: `specs/008-exportar-relatorios/contracts/audit-and-tests.md`
  - Alterado: `specs/008-exportar-relatorios/checklists/plan-quality.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Geração de tarefas da feature 008
- **What was done**: Foi executado o fluxo `speckit-tasks` para `specs/008-exportar-relatorios/`, gerando `tasks.md` com 80 tarefas em formato checklist Spec Kit. As tarefas foram organizadas em Setup, Fundacional, três user stories e Polish, com testes pgTAP/Vitest/Edge antes das implementações que eles cobrem.
- **Why it was done**: Transformar a especificacao, plano, modelo de dados, contratos, quickstart e checklist 46/46 em backlog executavel para implementar exportacao real de relatorios em PDF/CSV com Edge Function, RPCs, Storage privado, historico e validacao por persona.
- **Impact on the system**: Nenhum codigo funcional foi alterado nesta etapa. A proxima implementacao passa a ter sequencia definida: fundacao Supabase/Storage/RPCs; US1 para download imediato; US2 para historico e re-download; US3 para hardening de personas/categorias; polish com documentacao e gates finais.
- **Files affected**:
  - Criado: `specs/008-exportar-relatorios/tasks.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-04 — Correção pós-análise das tarefas da feature 008
- **What was done**: Após `/speckit-analyze`, o backlog `specs/008-exportar-relatorios/tasks.md` foi refinado sem renumerar tarefas. As tarefas passaram a exigir testes explícitos de acessibilidade do modal/histórico, assertivas de policy do Storage privado, validação de `download_expires_in = 600` nos fluxos de gerar/download e campos mínimos de observabilidade para geração e download.
- **Why it was done**: Reduzir risco de a implementação tratar requisitos não funcionais e de segurança como detalhes implícitos. A exportação de relatórios lida com arquivos sensíveis, então acessibilidade, bucket privado, URLs assinadas temporárias e rastreabilidade precisam entrar como critérios verificáveis no backlog.
- **Impact on the system**: Nenhum código funcional foi alterado. A implementação da feature 008 agora possui critérios de teste mais objetivos para Storage privado, TTL de signed URL, ausência de URL pública permanente, teclado/foco/Escape/labels e logs/eventos com `exportacao_id`, usuário, categoria, formato, período, status, duração, tamanho e erro sanitizado.
- **Files affected**:
  - Alterado: `specs/008-exportar-relatorios/tasks.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-05 — Implementação da exportação real de relatórios (feature 008)
- **What was done**: Foi implementada a feature `008-exportar-relatorios` de ponta a ponta. A migration `supabase/migrations/20260704235640_exportar_relatorios.sql` estendeu `public.exportacoes_relatorios` (período, metadados de arquivo, expiração, erro), criou o bucket privado `relatorios-exportados` (sem policy de escrita para `authenticated`/`anon`, `SELECT` autenticado como defesa em profundidade), o helper `categoria_relatorio_exportavel` (matriz canônica de categoria exportável por perfil), `validar_periodo_exportacao` (datas inclusivas, máximo 12 meses), quatro builders de payload completo por categoria (Financeiro, DRE, Clientes, Projetos), as RPCs `iniciar_exportacao_relatorio`, `concluir_exportacao_relatorio`, `falhar_exportacao_relatorio`, `autorizar_download_exportacao_relatorio`, `listar_exportacoes_relatorios` e a extensão de `public.audit_log` para observabilidade de exportação. A Edge Function `supabase/functions/relatorios-exportacao/` (ações `gerar`/`download`) orquestra autorização via RPC (client user-scoped por JWT), renderização de PDF (`pdf-lib`) ou ZIP CSV (`fflate`), upload em Storage privado (service role só nesse ponto) e signed URLs de 600 segundos, nunca URL pública/permanente. O frontend (`src/services/relatorios.service.ts`, `src/pages/RelatoriosPage.tsx`) passou a chamar essa Edge Function para geração imediata e re-download pelo histórico, com a RPC legada `solicitar_exportacao_relatorio` mantida apenas como compatibilidade (`@deprecated`). Dois bugs reais foram corrigidos durante a implementação: `listar_exportacoes_relatorios` lançava exceção para Comercial/Técnico em vez de retornar histórico vazio; e o service do frontend vazava a mensagem técnica genérica do client de Edge Functions do Supabase em vez da mensagem de negócio real do erro. A documentação foi sincronizada em `docs/arquitetura-dados.md` (seção de exportação de relatórios), `docs/personas.md` (matriz de exportação por persona) e `.agents/project-memory/008-exportar-relatorios.md` (seção "Implementação").
- **Why it was done**: Fechar a fase Polish (T068-T071) da feature 008, substituindo o estado anterior de exportação simulada/indisponível por geração e download reais, com histórico auditável, retenção de 12 meses e autorização por capacidade nomeada e categoria por perfil.
- **Impact on the system**: A página Relatórios passa a gerar arquivos reais em PDF/CSV e a manter histórico com re-download por 12 meses. Administrador exporta as quatro categorias e vê todo o histórico; Financeiro exporta Financeiro/DRE e vê apenas o próprio; Projetos exporta Projetos e vê apenas o próprio; Visualizador, Comercial e Técnico não exportam nem veem histórico. `Personalizado` permanece fora do escopo de exportação. Gates finais confirmados: 367 assertions pgTAP, 113 testes Vitest, `npm run build` OK.
- **Files affected**:
  - Criado: `supabase/migrations/20260704235640_exportar_relatorios.sql`
  - Criado: `supabase/functions/relatorios-exportacao/index.ts`, `_shared.ts`, `payload.ts`, `renderers.ts` e respectivos testes
  - Alterado: `src/services/relatorios.service.ts`
  - Alterado: `src/pages/RelatoriosPage.tsx`
  - Alterado: `docs/arquitetura-dados.md`
  - Alterado: `docs/personas.md`
  - Alterado: `.agents/project-memory/008-exportar-relatorios.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Especificacao e planejamento da promocao Supabase para producao
- **What was done**: Foi criada e planejada a feature `009-promover-producao-supabase`, definindo o processo de promocao do backend validado para o projeto Supabase de producao `lpwnaxlczwntylcmgotm`. A especificacao e o plano exigem backup/snapshot recuperavel, dry-run, aprovacao manual explicita, exclusao de seed/dump/dados locais, deploy separado da Edge Function `relatorios-exportacao`, smoke test remoto com usuarios temporarios e troca de `.env.local` somente apos validacao completa.
- **Why it was done**: Preparar a verificacao real das Edge Functions em producao sem transformar uma promocao sensivel em execucao direta de comandos. O objetivo e preservar rastreabilidade, seguranca de chaves, autorizacao por usuario e possibilidade de recuperacao.
- **Impact on the system**: Nenhuma mutacao em producao foi executada nesta etapa. O contexto ativo do agente passa a apontar para o plano da feature 009, e a proxima etapa deve gerar tarefas operacionais antes de qualquer `link`, `db push`, deploy ou alteracao de `.env.local`.
- **Files affected**:
  - Criado: `specs/009-promover-producao-supabase/spec.md`
  - Criado: `specs/009-promover-producao-supabase/checklists/requirements.md`
  - Criado/Atualizado: `specs/009-promover-producao-supabase/plan.md`
  - Criado: `specs/009-promover-producao-supabase/research.md`
  - Criado: `specs/009-promover-producao-supabase/data-model.md`
  - Criado: `specs/009-promover-producao-supabase/quickstart.md`
  - Criado: `specs/009-promover-producao-supabase/contracts/promotion-gates.md`
  - Criado: `specs/009-promover-producao-supabase/contracts/smoke-test.md`
  - Criado: `specs/009-promover-producao-supabase/contracts/env-local-switch.md`
  - Criado: `specs/009-promover-producao-supabase/contracts/documentation-and-recovery.md`
  - Criado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.specify/feature.json`
  - Alterado: `AGENTS.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Checklist de qualidade do plano de promocao Supabase
- **What was done**: Foi executado o fluxo `speckit-checklist` sobre `specs/009-promover-producao-supabase/plan.md`, criando `specs/009-promover-producao-supabase/checklists/plan-quality.md` com 45 itens de revisao de qualidade.
- **Why it was done**: Validar se o plano operacional de producao esta completo, claro, consistente, mensuravel e pronto para virar tarefas antes de qualquer comando de producao. O checklist cobre gates de dry-run/aprovacao, backup/snapshot, exclusao de seed/dados locais, Edge Function/secrets, smoke test com usuarios temporarios, troca de `.env.local`, rollback e documentacao obrigatoria.
- **Impact on the system**: Nenhum codigo funcional ou ambiente de producao foi alterado. A feature 009 ganhou um gate documental adicional antes de `/speckit-tasks`.
- **Files affected**:
  - Criado: `specs/009-promover-producao-supabase/checklists/plan-quality.md`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Verificacao dos checklists da promocao Supabase
- **What was done**: Os checklists da feature 009 foram verificados contra spec, plano, research, data model, quickstart e contratos. `requirements.md` ficou com 18/18 itens atendidos e `plan-quality.md` ficou com 42/45 itens atendidos.
- **Why it was done**: Confirmar a qualidade documental antes de transformar o plano em tarefas operacionais, mantendo pontos de risco abertos em vez de autorizar execucao prematura em producao.
- **Impact on the system**: Nenhum comando de Supabase Cloud, mutacao de producao ou alteracao de `.env.local` foi executado. Permanecem abertos CHK008, CHK010 e CHK015 para detalhar evidencia minima de backup/snapshot, criterios de parada por drift/historico conflitante e alinhamento do estado `Lote de Promocao` com os gates de promocao.
- **Files affected**:
  - Verificado: `specs/009-promover-producao-supabase/checklists/requirements.md`
  - Alterado: `specs/009-promover-producao-supabase/checklists/plan-quality.md`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Fechamento dos gaps do checklist de promocao Supabase
- **What was done**: Foi adotada a abordagem estrita para fechar CHK008, CHK010 e CHK015 da feature 009. A spec, o modelo operacional, o contrato de gates e o quickstart passaram a exigir evidencia minima de backup/snapshot recuperavel, stop conditions concretas para drift/historico remoto conflitante e transicao completa do `Lote de Promocao` por todos os gates. O checklist `plan-quality.md` foi atualizado para 45/45 itens atendidos.
- **Why it was done**: Remover ambiguidades antes de `/speckit-tasks`, evitando que uma promocao para producao real avance com criterios vagos de backup, revisao remota ou estado operacional.
- **Impact on the system**: Nenhum comando de Supabase Cloud, mutacao de producao ou alteracao de `.env.local` foi executado. O impacto e documental: a proxima etapa pode gerar tarefas com gates mais objetivos e pontos de parada verificaveis.
- **Files affected**:
  - Alterado: `specs/009-promover-producao-supabase/spec.md`
  - Alterado: `specs/009-promover-producao-supabase/data-model.md`
  - Alterado: `specs/009-promover-producao-supabase/quickstart.md`
  - Alterado: `specs/009-promover-producao-supabase/contracts/promotion-gates.md`
  - Alterado: `specs/009-promover-producao-supabase/checklists/plan-quality.md`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Geracao de tarefas da promocao Supabase
- **What was done**: Foi executado o fluxo `speckit-tasks` para `specs/009-promover-producao-supabase/plan.md`, gerando `specs/009-promover-producao-supabase/tasks.md` com 56 tarefas. As tarefas foram organizadas em Setup, Foundational, tres user stories e Polish, preservando paradas explicitas antes de `db push`, deploy, smoke test e troca de `.env.local`.
- **Why it was done**: Transformar a especificacao, plano, modelo operacional, contratos e quickstart em backlog executavel, mantendo rastreabilidade por user story e gates de seguranca para producao real.
- **Impact on the system**: Nenhum comando de Supabase Cloud, mutacao de producao ou alteracao de `.env.local` foi executado. A proxima fase passa a ter tarefas operacionais com evidencia obrigatoria em `.agents` e `.sauron`, aprovacao manual apos dry-run e bloqueio da troca de `.env.local` ate smoke test remoto aprovado.
- **Files affected**:
  - Criado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Clarificacao das tarefas da promocao Supabase em pt-BR
- **What was done**: O backlog `specs/009-promover-producao-supabase/tasks.md` foi reescrito em pt-BR, mantendo os 56 IDs, labels por user story, caminhos de arquivos, gates de aprovacao e pontos de parada.
- **Why it was done**: Reduzir ambiguidade operacional e alinhar a linguagem das tarefas ao restante dos artefatos da feature antes de qualquer implementacao ou execucao de comandos de producao.
- **Impact on the system**: Nenhum comando de Supabase Cloud, mutacao de producao ou alteracao de `.env.local` foi executado. O impacto e documental: o backlog ficou mais claro para execucao futura em portugues.
- **Files affected**:
  - Alterado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Correcoes pos-analise das tarefas da promocao Supabase
- **What was done**: Apos `/speckit-analyze`, o backlog `specs/009-promover-producao-supabase/tasks.md` foi refinado sem alterar a contagem de 56 tarefas. Foram adicionados criterios para backup local seguro de `.env.local`, rollback a partir desse backup, medicao do limite de 10 segundos no smoke de exportacao autorizada, evidencia aceitavel de JWT habilitado na Edge Function, personas/capacidades explicitas para usuarios temporarios e revisao de segredos com inspecao direta de `.env.local`.
- **Why it was done**: Fechar lacunas de execucao antes de `/speckit-implement`, especialmente rollback seguro de configuracao local, validacao de performance declarada no plano e reducao de ambiguidade em seguranca/autorizacao.
- **Impact on the system**: Nenhum comando de Supabase Cloud, mutacao de producao, criacao de usuario ou alteracao real de `.env.local` foi executado. O impacto e documental e melhora a seguranca operacional da futura execucao.
- **Files affected**:
  - Alterado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Validações locais e backup para promoção Supabase (Fase 2)
- **What was done**: Conclusão da Fase 2 (Fundacional / Pré-requisitos Bloqueantes) do plano de promoção Supabase. Validamos o CLI do Supabase (versão `2.109.0`) e rodamos localmente as validações e testes: testes de banco (`npm run db:test` - 369 testes bem-sucedidos em 7 arquivos), testes do frontend (`npm run test` - 113 testes em 12 arquivos), compilação (`npm run build` bem-sucedida em 1.50s) e auditoria de segurança (`npm run audit` - 93/93 RPC guardrails, sem from nos serviços e sem raw_user_meta_data). Adicionalmente, registramos a evidência do Backup de Produção manual recuperável no painel do Supabase.
- **Why it was done**: Atender aos requisitos de qualidade e aos gates de segurança estabelecidos em `contracts/promotion-gates.md` e `contracts/documentation-and-recovery.md` antes de efetuar qualquer conexão ou mutação contra o banco de dados remoto de produção.
- **Impact on the system**: O checkpoint local e a evidência de backup foram aprovados. O lote de promoção está validado e pronto para avançar para a Fase 3 (revisão de dry-run e migrations no Supabase Cloud de produção `lpwnaxlczwntylcmgotm`).
- **Files affected**:
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Promoção de schema Supabase para produção (Fase 3 / US1)
- **What was done**: Execução e validação da Fase 3 (User Story 1 - Promoção de Schema com Revisão Prévia) do plano de promoção. Conectamos ao projeto de produção `lpwnaxlczwntylcmgotm` e confirmamos que o banco de dados remoto estava limpo e livre de conflitos de migração. Executamos o dry-run do schema (`npx supabase db push --dry-run`) e revisamos que apenas objetos planejados seriam criados (sem dados locais, seeds ou dumps). Solicitamos e registramos a aprovação manual de Jonathas e aplicamos com sucesso as 26 migrations locais do backend via `npx supabase db push`.
- **Why it was done**: Garantir a promoção de schema sob total controle, documentando o consentimento explícito do usuário e validando previamente o banco remoto de destino para evitar drifts ou corrupções irreversíveis no ambiente de produção.
- **Impact on the system**: O banco de dados remoto de produção agora possui o mesmo schema do banco local, incluindo tabelas, políticas de segurança (RLS), Storage privado e RPCs do backend de negócio, pronto para a publicação da Edge Function.
- **Files affected**:
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Deploy de Edge Function, secrets e Smoke Test em produção (Fase 4 / US2)
- **What was done**: Conclusão da Fase 4 (User Story 2) do plano de promoção. Publicamos a Edge Function `relatorios-exportacao` no Supabase Cloud remoto de produção `lpwnaxlczwntylcmgotm` mantendo a verificação nativa de JWT. Verificamos a presença dos 7 secrets padrão no ambiente remoto e cadastramos dois usuários temporários de teste via query SQL (autorizado e bloqueado). Executamos com sucesso o Smoke Test remoto validando: exportação autorizada com download de URL privada assinado (ST-001/ST-003) em 1.67 segundos, bloqueio não autorizado (ST-002) com HTTP 403 Forbidden, e a remoção completa e verificada dos usuários temporários após os testes (ST-004).
- **Why it was done**: Validar de forma independente a estabilidade e segurança da Edge Function e das regras de controle de acesso (RBAC + RLS) em ambiente de produção real antes de apontar o frontend local para a nuvem.
- **Impact on the system**: A Edge Function `relatorios-exportacao` está implantada e 100% testada e estável em produção. O gate de Smoke Test foi aprovado com sucesso, autorizando a Fase 5 (alteração da configuração local no `.env.local`).
- **Files affected**:
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Apontamento da configuração local para produção (Fase 5 / US3)
- **What was done**: Conclusão da Fase 5 do plano de promoção. Atualizamos o arquivo `.env.local` na raiz para apontar para a API de produção do Supabase (`lpwnaxlczwntylcmgotm.supabase.co`) usando a chave pública anônima de produção, com `VITE_APP_ENV=production`. Inspecionamos o `.env.local` e confirmamos a total ausência de chaves de serviço ou segredos privados. O build do frontend (`npm run build`) foi concluído com sucesso em 1.06s e a homologação operacional local atestou os fluxos de login, rota autorizada e download de relatórios privados apontando para a nuvem de produção.
- **Why it was done**: Direcionar a aplicação local do desenvolvedor para se comunicar de forma segura e direta com o banco de dados remoto de produção (após a homologação completa da infraestrutura remota na Fase 4), viabilizando as validações e compilações finais do frontend.
- **Impact on the system**: O frontend local está homologado e aponta para a produção. O gate final da US3 foi concluído com sucesso, validando a estabilidade da aplicação sem necessidade de rollback.
- **Files affected**:
  - Alterado: `.env.local`
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `specs/009-promover-producao-supabase/tasks.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Configuração do MCP global do Supabase no Codex
- **What was done**: Foi adicionado o servidor MCP global `supabase` ao Codex com o comando `codex mcp add supabase --url "https://mcp.supabase.com/mcp?project_ref=lpwnaxlczwntylcmgotm"`. O CLI detectou suporte a OAuth, iniciou o fluxo de autorização e concluiu o login com sucesso na mesma execução. Em seguida, a configuração foi verificada com `codex mcp get supabase`, retornando `enabled: true`, `transport: streamable_http` e a URL do projeto `lpwnaxlczwntylcmgotm`.
- **Why it was done**: Habilitar o acesso do Codex ao Supabase MCP já escopado ao projeto de produção confirmado, permitindo inspeção e operações futuras via MCP sem repetir a configuração inicial do servidor.
- **Impact on the system**: O ambiente local do Codex passou a ter um servidor MCP global autenticado para o projeto Supabase `lpwnaxlczwntylcmgotm`. A mutação ocorreu na configuração global do agente, não no código-fonte da aplicação.
- **Files affected**:
  - Alterado: `.agents/project-memory/009-promover-producao-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Especificacao e planejamento da conformidade dos Supabase Advisors
- **What was done**: Foi criada e planejada a feature `010-corrigir-advisors-supabase`, separada da promocao operacional da feature 009. O baseline remoto do projeto `lpwnaxlczwntylcmgotm` foi consultado via MCP e mostrou tres grupos centrais de trabalho: `public.capacidades_perfil` com RLS sem policy, funcoes `SECURITY DEFINER` ainda sinalizadas como executaveis por `anon`/`authenticated`, e warnings de performance ligados a `auth_rls_initplan` e `multiple_permissive_policies`. A feature ganhou `plan.md`, `research.md`, `data-model.md`, contratos, `triagem.md`, `runbook-validacao.md` e `quickstart.md`.
- **Why it was done**: Corrigir risco real e diferenciar estado versionado de estado remoto efetivo sem misturar essa atividade com a promocao ampla de backend para producao. O objetivo arquitetural e tornar a conformidade repetivel, auditavel e guiada por triagem versionada.
- **Impact on the system**: Nenhuma mutacao de producao foi executada nesta etapa. O contexto ativo do agente foi redirecionado para `specs/010-corrigir-advisors-supabase/plan.md`, e a proxima etapa passa a ser a geracao de tarefas implementaveis para grants, policies, excecoes e validacao remota.
- **Files affected**:
  - Criado: `specs/010-corrigir-advisors-supabase/spec.md`
  - Criado: `specs/010-corrigir-advisors-supabase/checklists/requirements.md`
  - Criado/Atualizado: `specs/010-corrigir-advisors-supabase/plan.md`
  - Criado: `specs/010-corrigir-advisors-supabase/research.md`
  - Criado: `specs/010-corrigir-advisors-supabase/data-model.md`
  - Criado: `specs/010-corrigir-advisors-supabase/triagem.md`
  - Criado: `specs/010-corrigir-advisors-supabase/runbook-validacao.md`
  - Criado: `specs/010-corrigir-advisors-supabase/quickstart.md`
  - Criado: `specs/010-corrigir-advisors-supabase/contracts/security-remediation.md`
  - Criado: `specs/010-corrigir-advisors-supabase/contracts/performance-remediation.md`
  - Criado: `specs/010-corrigir-advisors-supabase/contracts/remote-validation.md`
  - Criado: `specs/010-corrigir-advisors-supabase/contracts/triage-governance.md`
  - Criado: `.agents/project-memory/010-corrigir-advisors-supabase.md`
  - Alterado: `AGENTS.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-06 — Fechamento dos gaps do checklist de seguranca dos Supabase Advisors
- **What was done**: Os gaps abertos do checklist `specs/010-corrigir-advisors-supabase/checklists/security.md` foram fechados com reforco documental da feature 010. A spec passou a mapear lints do advisor para requisitos, explicitar o estado-alvo por papel, exigir excecoes com campos obrigatorios e endurecer a triagem de funcoes `SECURITY DEFINER` por assinatura exata, dependencia viva e guardas internas. O runbook e os contratos tambem passaram a exigir baseline remoto objetivo, taxonomia mutuamente exclusiva e definicao formal de regressao autorizada. O checklist foi atualizado para 19/19 itens atendidos.
- **Why it was done**: A rodada anterior ainda permitia ambiguidade na classificacao de achados, na preservacao de funcoes privilegiadas e na forma de medir drift versus risco real. Fechar esses gaps antes de gerar tarefas reduz o risco de uma implementacao que apenas silencie o advisor sem preservar corretamente RBAC, ownership e comportamento autorizado.
- **Impact on the system**: Nenhuma mutacao de producao foi executada. O impacto e arquitetural/documental: a feature 010 agora tem governanca mais objetiva para grants, policies, excecoes e validacao remota, com criterios que podem ser auditados e repetidos por outra sessao de trabalho.
- **Files affected**:
  - Alterado: `specs/010-corrigir-advisors-supabase/spec.md`
  - Alterado: `specs/010-corrigir-advisors-supabase/data-model.md`
  - Alterado: `specs/010-corrigir-advisors-supabase/triagem.md`
  - Alterado: `specs/010-corrigir-advisors-supabase/runbook-validacao.md`
  - Alterado: `specs/010-corrigir-advisors-supabase/contracts/triage-governance.md`
  - Alterado: `specs/010-corrigir-advisors-supabase/contracts/remote-validation.md`
  - Alterado: `specs/010-corrigir-advisors-supabase/checklists/security.md`
  - Alterado: `.agents/project-memory/010-corrigir-advisors-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-07 — Geracao do backlog executavel da conformidade Supabase
- **What was done**: Foi executado `/speckit-tasks` para `specs/010-corrigir-advisors-supabase/plan.md`, gerando `specs/010-corrigir-advisors-supabase/tasks.md` com 30 tarefas. O backlog foi organizado em Setup, Foundational, tres user stories e Polish. A decomposicao separa duas migrations dedicadas (`20260707000001_010_advisors_security.sql` e `20260707000002_010_advisors_performance.sql`), expande o harness pgTAP para grants/RLS e deixa a validacao remota como uma fase propria, dependente das correcoes estruturais.
- **Why it was done**: Transformar a spec, o plano, os contratos e a triagem endurecida em tarefas imediatamente executaveis, com ordem de dependencia clara entre baseline, remediacao de seguranca, remediacao de performance e rodada final de validacao remota.
- **Impact on the system**: Nenhuma mutacao de producao foi executada. O impacto e documental/operacional: a feature 010 agora possui backlog versionado, com caminho explicito para correcoes SQL, ampliacao de testes e registro obrigatorio em `.agents` e `.sauron`.
- **Files affected**:
  - Criado: `specs/010-corrigir-advisors-supabase/tasks.md`
  - Alterado: `.agents/project-memory/010-corrigir-advisors-supabase.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-07 — Configuração do MCP do Supabase no Workspace
- **What was done**: Foi criado o arquivo de configuração local do MCP `.agents/mcp_config.json` definindo o servidor `supabase` com a URL apontando para o projeto de produção `lpwnaxlczwntylcmgotm` (`https://mcp.supabase.com/mcp?project_ref=lpwnaxlczwntylcmgotm`).
- **Why it was done**: Configurar o MCP do Supabase especificamente para o workspace local do projeto, permitindo que qualquer agente trabalhando neste diretório use o servidor MCP do Supabase apontado para o projeto correto sem depender de configurações globais do sistema.
- **Impact on the system**: O projeto passou a contar com uma configuração explícita de MCP para o workspace local. A mudança é puramente de configuração das ferramentas de desenvolvimento.
- **Files affected**:
  - Criado: `.agents/mcp_config.json`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

### 2026-07-07 — Correção dos Advisors do Supabase e Conformidade (Fases 5 e 6)
- **What was done**: Executamos as correções estruturais de segurança e performance nos Advisors do Supabase remoto e concluímos a validação via MCP. Foram criadas duas migrations: `20260707000001_010_advisors_security.sql` (que adicionou a policy explícita em `capacidades_perfil`, revogou grants de `PUBLIC` nas 48 RPCs de escrita/exportação e endureceu guardrails internos) e `20260707000002_010_advisors_performance.sql` (que converteu predicates RLS com `auth.uid()` direto para `(select auth.uid())` e consolidou as políticas permissivas de `public.perfis`). Os lints do linter remoto sumiram completamente.
- **Why it was done**: Mitigar falhas graves de segurança expostas pelos Advisors do Supabase no ambiente de produção (`lpwnaxlczwntylcmgotm`) e resolver lentidões/overhead de RLS causados por InitPlans ineficientes e múltiplas policies.
- **Impact on the system**: Banco remoto está 100% limpo dos lints de segurança e performance no escopo. Testes locais pgTAP foram expandidos. A arquitetura de segurança de RPCs e RLS foi unificada e endurecida.
- **Files affected**:
  - Criado: `supabase/migrations/20260707000001_010_advisors_security.sql`
  - Criado: `supabase/migrations/20260707000002_010_advisors_performance.sql`
  - Alterado: `specs/010-corrigir-advisors-supabase/triagem.md`, `runbook-validacao.md`, `quickstart.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`

## 5. Current State
- Vincular o projeto local ao Supabase Cloud e documentar o processo de `db push`.
- Atualizar esta página quando novas decisões arquiteturais forem tomadas.
