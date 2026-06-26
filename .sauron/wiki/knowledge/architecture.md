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

## 4. Change History

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

- **Frontend**: Páginas estáticas em HTML/CSS/JS com 13 telas ativas (`login.html`, `dashboard.html`, `fluxo-caixa.html`, `contas-pagar.html`, `contas-receber.html`, `clientes.html`, `propostas.html`, `contratos.html`, `cobrancas.html`, `projetos.html`, `equipe.html`, `relatorios.html`, `configuracoes.html`).
- **Telas legadas**: `index.html` e `financeiro.html` não fazem parte da documentação ativa.
- **Backend/Banco de dados**: Nenhum ativo. As definições de schema permanecem documentadas em `docs/banco-de-dados.md` apenas como especificação, com tabelas nomeadas em pt-BR.
- **Dependências**: Nenhuma dependência Node.js ativa no projeto.
- **Direção futura**: Avaliar se o backend será implementado com Supabase, outro BaaS ou solução própria quando as telas exigirem persistência real.

## 6. Next Steps (Optional)

- Definir momento de integração de backend.
- Escolher entre Supabase, Firebase, backend próprio ou outra alternativa quando o projeto exigir persistência.
- Atualizar esta página quando novas decisões arquiteturais forem tomadas.
