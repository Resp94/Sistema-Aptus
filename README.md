# Aptus ERP

Sistema de Gestão Administrativa e Financeira para o Aptus Flow.

---

## 🚀 Stack Tecnológica

O projeto utiliza uma stack moderna voltada para escalabilidade, manutenibilidade e desenvolvimento ágil:

- **Frontend**: SPA construída com [React 19](https://react.dev/), [Vite](https://vite.dev/) e [TypeScript](https://www.typescriptlang.org/).
- **Backend / Banco de Dados**: [Supabase](https://supabase.com/) (PostgreSQL 17, autenticação, armazenamento e APIs automáticas).
- **Desenvolvimento Local**: Orquestrado pelo [Supabase CLI](https://supabase.com/docs/guides/cli/local-development) via [Docker](https://www.docker.com/).
- **Hospedagem**: [Cloudflare Pages](https://pages.cloudflare.com/) com deploy contínuo integrado ao Git.

---

## 🛠️ Pré-requisitos

Para rodar o projeto localmente, você precisa ter instalado:

1. **Node.js** LTS (versão 20.x ou superior)
2. **Docker Desktop** (ativo e em execução)

---

## 💻 Como Iniciar o Projeto Localmente

### 1. Instalar as Dependências

```bash
npm install
```

### 2. Iniciar o Banco de Dados e Serviços do Supabase
Certifique-se de que o Docker está rodando e execute:

```bash
npm run supabase:start
```

*Este comando iniciará os containers locais do Postgres, Auth, Studio, etc. Ao concluir, as chaves de acesso anônimo local (`ANON_KEY`) e as URLs serão exibidas.*

### 3. Configurar as Variáveis de Ambiente
Crie um arquivo `.env.local` na raiz do projeto (se já não existir) e adicione a URL e a `ANON_KEY` local exibida no terminal:

```env
VITE_SUPABASE_URL=http://localhost:54321
VITE_SUPABASE_ANON_KEY=sua-chave-anonima-local-aqui
VITE_APP_ENV=local
```

### 4. Executar o Frontend em Modo de Desenvolvimento

```bash
npm run dev
```

Acesse a aplicação em [http://localhost:5173](http://localhost:5173).

---

## 🧪 Testes Automatizados

Os testes de integração e testes unitários são executados via **Vitest**:

```bash
npm run test
```

---

## 📁 Estrutura do Repositório

```text
/
├── src/                  # Código-fonte da aplicação React
│   ├── main.tsx          # Ponto de entrada da aplicação
│   ├── App.tsx           # Componente raiz
│   ├── components/       # Componentes reutilizáveis
│   ├── pages/            # Telas da aplicação (Login, Dashboard, etc.)
│   ├── services/         # Clientes de APIs e conexões (Supabase, etc.)
│   └── types/            # Tipos compartilhados do TypeScript
├── supabase/             # Arquivos de infraestrutura do BaaS local
│   ├── config.toml       # Configuração local do Supabase CLI
│   ├── migrations/       # Migrações versionadas do banco de dados
│   └── seed.sql          # Dados iniciais para desenvolvimento
├── docs/                 # Documentação de referência e guias
│   └── stack.md          # Fonte única da verdade da stack tecnológica
└── index.html            # Ponto de entrada do Vite para a aplicação React
```

---

## 📖 Documentação Adicional

Para mais detalhes sobre as decisões arquiteturais de infraestrutura, consulte a [Documentação da Stack Tecnológica](file:///C:/Users/respl/OneDrive/Aptus%20Flow/sistema-aptus/docs/stack.md) e o [Guia de Quickstart](file:///C:/Users/respl/OneDrive/Aptus%20Flow/sistema-aptus/specs/002-tech-stack-definition/quickstart.md).
