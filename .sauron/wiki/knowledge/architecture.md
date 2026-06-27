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
