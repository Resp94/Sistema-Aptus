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

## 5. Current State

- **Frontend atual**: Aplicação SPA baseada em Vite + React + TypeScript instalada na raiz do repositório. As dependências (React 19, Supabase JS, ESLint, Prettier e Vitest) estão instaladas.
- **Telas legadas**: Arquivos HTML legados (ex.: `clientes.html`, `dashboard.html`) foram preservados e o `index.html` original foi renomeado para `index.legacy.html` para servir de referência durante a migração para componentes React.
- **Ambiente local de Banco/Backend**: Supabase CLI + Docker ativo e orquestrando o Postgres local, Auth, Storage e Studio.
- **Integração Frontend-Backend**: Conectados por meio do arquivo `src/services/supabase.ts`, inicializado a partir do arquivo de configuração `.env.local` que contém a chave anônima local.
- **Testes**: Vitest configurado para a pasta `src` com smoke test de integração REST passando.
- **CI/CD / Hospedagem**: Cloudflare Pages definida e documentada em `docs/stack.md` como o destino do deploy do frontend compilado (`dist/`).

## 6. Next Steps (Optional)

- Iniciar a migração das telas HTML legadas para componentes React e rotas internas.
- Criar a primeira migração de schema com as tabelas de negócio do ERP (`clientes`, `contas`, `projetos`, etc.) com base no `docs/banco-de-dados.md`.
- Conectar o repositório GitHub ao projeto do Cloudflare Pages para deploy automático.
- Vincular o projeto local ao Supabase Cloud e documentar o processo de `db push`.
- Atualizar esta página quando novas decisões arquiteturais forem tomadas.
