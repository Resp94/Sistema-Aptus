# Documentação da Stack Tecnológica — Aptus ERP

Este documento serve como a **única fonte de verdade (Single Source of Truth)** para a stack tecnológica, decisões de design arquitetural e contratos de integração e promoção de ambiente do Aptus ERP.

---

## 1. Visão Geral da Stack

O Aptus ERP foi migrado de uma arquitetura estática baseada em arquivos HTML/CSS/JS soltos para uma stack moderna, robusta e escalável, estruturada da seguinte forma:

- **Frontend**: Single Page Application (SPA) construída com **React 19**, **Vite** e **TypeScript**, proporcionando uma experiência de usuário (UX) extremamente rápida e com tipagem estática segura.
- **Backend / Banco de Dados**: **Supabase**, que disponibiliza um banco relacional **PostgreSQL 17** completo com mecanismos nativos de autenticação, armazenamento de arquivos, APIs REST geradas automaticamente a partir do schema e suporte a tempo real.
- **Desenvolvimento Local**: Orquestrado pelo **Supabase CLI** integrado ao **Docker**, garantindo paridade absoluta de infraestrutura entre as máquinas locais dos desenvolvedores e o ambiente em nuvem.
- **Hospedagem / Deploy**: O frontend estático é compilado para a pasta `dist/` e publicado de forma automatizada na **Cloudflare Pages**.

---

## 2. Decisões Arquiteturais (ADRs)

### DEC-001 — Hospedagem do Frontend na Cloudflare Pages
* **Problema**: Onde hospedar o frontend estático do ERP de forma segura, com baixo custo operacional, baixa latência e integração com Git?
* **Opções Consideradas**:
  1. *Vercel*: Boa integração e suporte, mas mais focada no ecossistema Next.js.
  2. *Hospedagem Própria (VPS/Nginx)*: Alta manutenção e custos desnecessários para um frontend estático.
  3. *Cloudflare Pages*: CDN global ultraveloz embutida, suporte integrado a Git, previews automatizados de branches e generoso limite gratuito.
* **Escolha**: **Cloudflare Pages**.
* **Justificativa**: Garante deploy automatizado a cada push de Git, latência mínima no acesso corporativo e custo operacional nulo para o volume do projeto.

### DEC-002 — Backend, Banco de Dados e Autenticação via Supabase
* **Problema**: Como gerenciar banco de dados, autenticação de usuários e APIs de forma ágil sem criar um backend monolítico complexo?
* **Opções Consideradas**:
  1. *Backend Customizado (Node.js/Express + Postgres)*: Oferece controle total, mas exige muito tempo para codificar autenticação, migrações, endpoints de CRUD e segurança.
  2. *Firebase*: Banco não-relacional, inviável para queries complexas e relatórios necessários em um ERP.
  3. *Supabase*: Banco relacional PostgreSQL puro com controle de acesso granular via Row Level Security (RLS) e autenticação pronta.
* **Escolha**: **Supabase**.
* **Justificativa**: Permite usar PostgreSQL com todo seu poder relacional, economiza semanas de trabalho em autenticação e segurança de endpoints (via RLS) e fornece APIs REST instantâneas e seguras.

### DEC-003 — Frontend com Vite + React + TypeScript
* **Problema**: Qual biblioteca de componentes e build tool usar para manter o desenvolvimento rápido e manutenível?
* **Opções Consideradas**:
  1. *HTML/JS Legado*: Inviável para manter e atualizar o estado de formulários complexos do ERP.
  2. *Next.js (React)*: Adiciona complexidade de SSR/SSG desnecessária para um ERP corporativo interno.
  3. *Vite + React + TypeScript*: Leve, rápido (Hot Module Replacement instantâneo) e atende à diretriz global do projeto.
* **Escolha**: **Vite + React + TypeScript**.
* **Justificativa**: Alinhado com a diretriz do projeto definida no `AGENTS.md` e melhora a qualidade do código com tipagem estática e componentes modulares.

### DEC-004 — Desenvolvimento Local via Supabase CLI + Docker
* **Problema**: Como garantir que todos os desenvolvedores rodem o banco e a autenticação de forma idêntica à produção sem conectar à internet ou corromper dados reais?
* **Opções Consideradas**:
  1. *Conectar direto à Nuvem (Dev/Staging)*: Risco de sobrescrever dados e lentidão na conexão.
  2. *Postgres local instalado na máquina*: Complexidade de manter a mesma versão de extensões e configurações.
  3. *Supabase CLI + Docker*: Containers idênticos aos da nuvem sobem em segundos localmente.
* **Escolha**: **Supabase CLI + Docker**.
* **Justificativa**: Dá autonomia total ao desenvolvedor para fazer testes destrutivos de migrações e seeds em milissegundos sem custos de cloud.

---

## 3. Contratos e Fluxos de Trabalho

### A. Fluxo de Promoção Local → Nuvem (Database)
As atualizações de schema do banco seguem um fluxo estrito de promoção com no máximo **2 passos manuais**:

1. **Validação Local**: O desenvolvedor aplica e testa as migrações localmente executando:
   ```bash
   npx supabase db reset
   ```
   Isso reconstrói o banco de dados local do zero, aplicando todas as migrações na pasta `supabase/migrations/` e os dados de teste em `supabase/seed.sql` para garantir que o schema está livre de erros de integridade.

2. **Push para a Nuvem**: Uma vez validadas as migrações locais e passados os testes, as alterações são promovidas para o projeto de nuvem executando:
   ```bash
   npx supabase db push
   ```
   Isso aplica apenas as migrações pendentes de forma segura no ambiente de produção.

### B. Contrato de Integração Frontend ↔ Supabase
O frontend consome os serviços do Supabase através de um cliente único inicializado na pasta de serviços:

* **Configuração do Cliente (`src/services/supabase.ts`)**:
  ```ts
  import { createClient } from '@supabase/supabase-js'

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error('As variáveis de ambiente do Supabase não foram configuradas!')
  }

  export const supabase = createClient(supabaseUrl, supabaseAnonKey)
  ```

* **Tratamento de Erros**:
  Qualquer chamada ao Supabase retorna `{ data, error }`. É obrigatório verificar se o objeto `error` existe antes de manipular `data`:
  ```ts
  const { data, error } = await supabase.from('clientes').select('*')
  if (error) {
    console.error('Erro ao buscar clientes:', error.message)
    // Exibir feedback visual ao usuário
    return
  }
  // Utilizar data com segurança
  ```

* **Segurança e RLS**:
  Toda tabela criada deve possuir políticas de **Row Level Security (RLS)** ativas. O frontend não executa queries com bypass de segurança. A autorização é controlada diretamente nas políticas baseadas na sessão do usuário autenticado.

---

## 4. Processo de Deploy na Cloudflare Pages

O deploy do frontend é totalmente automatizado via integração contínua (CI/CD) com o Git na Cloudflare Pages.

### A. Integração com Git e Criação do Projeto
1. Acesse o painel da **Cloudflare** e vá em **Workers & Pages**.
2. Clique em **Create application** -> **Pages** -> **Connect to Git**.
3. Selecione o repositório `sistema-aptus` (conectando sua conta GitHub/GitLab).
4. Escolha a branch de produção principal: `main`.

### B. Configurações de Build na Cloudflare
Configure os seguintes parâmetros de build no painel da Cloudflare:
- **Framework preset**: `Vite`
- **Build command**: `npm run build`
- **Build output directory**: `dist`
- **Node.js version** (em Environment variables): `NODE_VERSION=20`

### C. Configuração de Variáveis de Ambiente na Cloudflare
Para o frontend se comunicar com o Supabase de produção, configure as seguintes variáveis sob as configurações do projeto de Pages (**Settings -> Environment variables**):
- `VITE_SUPABASE_URL`: A URL do seu projeto Supabase na Nuvem.
- `VITE_SUPABASE_ANON_KEY`: A chave anônima (anon key) do projeto Supabase na Nuvem.
- `VITE_APP_ENV`: `production`

### D. Domínio Personalizado e Estratégia de Branches
* **Domínio**: Um domínio próprio da empresa (ex.: `fluxo.aptus.com`) pode ser associado em **Custom domains** no painel da Pages.
* **Previews**: Cada push em branches diferentes de `main` gera automaticamente uma URL de preview isolada para testes, permitindo validar alterações antes de realizar o merge.

### E. Checklist de Deploy (Deploy Checklist)
Antes de mesclar código na branch `main`:
- [ ] Rodar testes locais com `npm run test` e verificar se passam de forma limpa.
- [ ] Rodar `npm run build` localmente para garantir que o compilador TypeScript e o bundler do Vite não reportam erros.
- [ ] Garantir que todas as migrações necessárias de banco de dados foram promovidas para a nuvem usando `npx supabase db push` para evitar inconsistências entre o novo frontend e a base de dados.

---

## 5. Estratégia de Migração das Páginas HTML Legadas

Os arquivos HTML existentes na raiz do repositório (ex.: `login.html`, `dashboard.html`, `clientes.html`) servem como referência de design e comportamento para as novas telas React. A migração ocorrerá em etapas:

1. **Preservação Inicial**: Os arquivos legados são mantidos temporariamente na raiz do repositório.
2. **Desenvolvimento de Componentes**: Cada página será recriada como um componente React dentro de `src/pages/` (ex.: `src/pages/Login.tsx`), reaproveitando o CSS corporativo em `aptus.css`.
3. **Substituição e Limpeza**: Após a validação da nova tela no ecossistema React/Vite, o arquivo `.html` correspondente na raiz será deletado.
4. **Página de Entrada Legacy**: O arquivo [index.legacy.html](file:///C:/Users/respl/OneDrive/Aptus%20Flow/sistema-aptus/index.legacy.html) registra todos os links originais para garantir rastreabilidade durante a transição.

---

## 6. Resolução de Problemas (Troubleshooting)

### A. Docker Indisponível ou Não Iniciado
* **Erro**: Mensagem de falha ao rodar `npm run supabase:start` indicando que o daemon do Docker não está rodando.
* **Solução**: Certifique-se de que o **Docker Desktop** esteja aberto e ativo. No Windows/macOS, verifique o ícone do Docker na barra de tarefas (deve estar verde/running).

### B. Conflito de Portas (Portas 54321 / 54322 em uso)
* **Erro**: Falha ao iniciar serviços do Supabase porque uma porta específica já está ocupada.
* **Solução**: Geralmente, isso ocorre se você já tiver uma instalação local do PostgreSQL rodando como serviço do Windows. 
  - Abra o console de Serviços (`services.msc`), localize o serviço `postgresql` e pare-o temporariamente.
  - Alternativamente, você pode alterar a porta de conexão em `supabase/config.toml` na seção `[db].port`.

### C. Limitação de Recursos de Máquina
* **Erro**: Containers do Supabase falhando na inicialização com erros de timeout ou falta de memória.
* **Solução**: O Supabase local orquestra vários containers Docker (Postgres, GoTrue, PostgREST, Kong, Storage, Studio, Inbucket). Certifique-se de que o Docker Desktop possui pelo menos **4 GB de RAM** e **2 CPUs** alocados em suas configurações (`Settings -> Resources`).
