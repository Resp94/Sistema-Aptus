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

### 2026-06-26 — Definição e planejamento da stack tecnológica do Aptus ERP
- **What was done**: Foi criada a especificação `specs/002-tech-stack-definition` e o plano de implementação definindo a stack base do projeto: Cloudflare para hospedagem do frontend, Supabase para backend/banco/autenticação, Vite + React para o frontend, e desenvolvimento local via Supabase CLI com Docker. Foram gerados artefatos de pesquisa, modelo de dados, contratos e guia quickstart.
- **Why it was done**: O projeto precisava de uma decisão arquitetural clara e de um plano executável para suportar persistência, autenticação e deploy, além de um ambiente local reproduzível que proteja os dados de produção.
- **Impact on the system**: Nenhum impacto funcional imediato. A decisão e o plano orientam a próxima fase de implementação do backend e da migração do frontend para Vite + React.
- **Files affected**:
  - Criado: `specs/002-tech-stack-definition/spec.md`
  - Criado: `specs/002-tech-stack-definition/.spec-context.json`
  - Criado: `specs/002-tech-stack-definition/plan.md`
  - Criado: `specs/002-tech-stack-definition/research.md`
  - Criado: `specs/002-tech-stack-definition/data-model.md`
  - Criado: `specs/002-tech-stack-definition/quickstart.md`
  - Criado: `specs/002-tech-stack-definition/contracts/local-cloud-promotion.md`
  - Criado: `specs/002-tech-stack-definition/contracts/supabase-integration.md`
  - Criado: `specs/002-tech-stack-definition/checklists/requirements.md`
  - Criado: `specs/002-tech-stack-definition/checklists/stack-definition.md`
  - Criado: `specs/002-tech-stack-definition/tasks.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`
  - Alterado: `AGENTS.md`

### 2026-06-26 — Remediação pós-análise dos artefatos da stack
- **What was done**: Após análise dos artefatos `spec.md`, `plan.md` e `tasks.md`, foram aplicadas correções: versão do PostgreSQL no plano ajustada para 17 (igual ao `supabase/config.toml`), adicionadas tarefas de teste de integração com Vitest e validação real do `supabase db push`, e ajustadas tarefas de escopo no `tasks.md`.
- **Why it was done**: Eliminar inconsistências e gaps de cobertura identificados na análise antes da implementação.
- **Impact on the system**: Nenhum impacto funcional. Apenas ajustes documentacionais e de planejamento.
- **Files affected**:
  - Alterado: `specs/002-tech-stack-definition/plan.md`
  - Alterado: `specs/002-tech-stack-definition/tasks.md`
  - Alterado: `.sauron/wiki/knowledge/architecture.md`
  - Alterado: `.sauron/wiki/summary.json`

### 2026-06-26 — Remoção das configurações do Supabase CLI
- **What was done**: Foram removidos do sistema de arquivos a pasta `supabase/`, o `package.json`, o `package-lock.json` e a pasta `node_modules/`.
- **Why it was done**: As configurações do Supabase CLI não estavam sendo utilizadas e o projeto ainda não possui integração ativa com Supabase. O comando `supabase link` falhava por falta do CLI no PATH.
- **Impact on the system**: Nenhum impacto funcional. O projeto continua como conjunto de páginas estáticas sem backend ativo.
- **Files affected**:
  - Removido: `supabase/config.toml`
  - Removido: `supabase/.gitignore`
  - Removido: `supabase/.temp/`
  - Removido: `package.json`
  - Removido: `package-lock.json`
  - Removido: `node_modules/`

### 2026-06-26 — Sincronização da documentação com as telas HTML
- **What was done**: As documentações de telas, personas e banco de dados foram refatoradas para refletir as 13 telas HTML ativas na raiz do projeto. Telas legadas (`index.html`, `financeiro.html`) foram removidas da documentação ativa. Foi adicionada a persona Profissional Técnico para representar desenvolvedores alocados em projetos. O schema de banco de dados foi expandido com tabelas em pt-BR para fornecedores, contas a pagar/receber, fluxo de caixa, equipe, alocações, relatórios e configurações, e a tabela `usuarios` foi definida como espelho do auth provider.
- **Why it was done**: A documentação estava desatualizada em relação ao estado real das telas HTML, o que gerava inconsistência entre telas, personas e modelo de dados.
- **Impact on the system**: Nenhum impacto funcional imediato, pois as mudanças são documentacionais. O modelo de dados planejado agora suporta todos os módulos visíveis nas telas.
- **Files affected**:
  - Alterado: `docs/telas.md`
  - Alterado: `docs/personas.md`
  - Alterado: `docs/banco-de-dados.md`
  - Alterado: `docs/aptus-prd.md`

## 5. Current State

- **Frontend atual**: Páginas estáticas em HTML/CSS/JS com 13 telas ativas (`login.html`, `dashboard.html`, `fluxo-caixa.html`, `contas-pagar.html`, `contas-receber.html`, `clientes.html`, `propostas.html`, `contratos.html`, `cobrancas.html`, `projetos.html`, `equipe.html`, `relatorios.html`, `configuracoes.html`).
- **Telas legadas**: `index.html` e `financeiro.html` não fazem parte da documentação ativa.
- **Stack definida (em definição/adoção)**:
  - **Hospedagem frontend**: Cloudflare.
  - **Backend/Banco/Auth**: Supabase (PostgreSQL + Auth + APIs).
  - **Frontend (direção futura)**: Vite + React.
  - **Desenvolvimento local**: Supabase CLI com Docker.
- **Backend/Banco de dados ativo**: Ambiente local Supabase já inicializado via Docker (`supabase/config.toml` presente, serviços rodando localmente). Schema ainda não versionado em `supabase/migrations/`.
- **Dependências**: Nenhuma dependência Node.js ativa no projeto.
- **Direção futura**: Criar o projeto Vite + React, integrar com o Supabase local já rodando e iniciar a migração/integração das telas com persistência real.

## 6. Next Steps (Optional)

- Criar baseline migration a partir do banco local já existente.
- Inicializar o projeto Vite + React na raiz do repositório.
- Configurar o deploy contínuo na Cloudflare Pages.
- Vincular o projeto local ao Supabase Cloud e documentar o processo de `db push`.
- Atualizar esta página quando novas decisões arquiteturais forem tomadas.
