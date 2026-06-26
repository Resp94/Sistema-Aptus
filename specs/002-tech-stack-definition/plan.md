# Implementation Plan: Definição da Stack Tecnológica

**Branch**: `002-tech-stack-definition` | **Date**: 2026-06-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-tech-stack-definition/spec.md`

## Summary

Esta feature estabelece a fundação tecnológica do Aptus ERP. O objetivo é migrar o projeto de páginas estáticas HTML/CSS/JS para uma stack moderna e sustentável: frontend em Vite + React + TypeScript, backend/banco/autenticação via Supabase, hospedagem do frontend na Cloudflare, e desenvolvimento local reproduzível via Supabase CLI com Docker. O plano prioriza a configuração do ambiente local, a documentação das decisões e a criação de uma base sólida para as funcionalidades de negócio subsequentes.

## Technical Context

**Language/Version**: TypeScript 5.x, Node.js LTS (20.x+)

**Primary Dependencies**: React 18+, Vite 5+, Supabase JS client, Supabase CLI

**Storage**: PostgreSQL 15+ via Supabase (local e nuvem)

**Testing**: Vitest para frontend; testes de integração contra o Supabase local

**Target Platform**: Web (Cloudflare Pages)

**Project Type**: Web application (frontend SPA + BaaS backend)

**Performance Goals**: First Contentful Paint < 1,5 s; interação inicial < 3 s em conexão corporativa

**Constraints**:
- Ambiente local deve espelhar o ambiente de nuvem para backend/banco.
- Promoção local → nuvem deve ter no máximo 2 passos manuais documentados.
- Nenhum dado real da empresa pode ser necessário para rodar o ambiente local.

**Scale/Scope**: ERP interno de pequeno porte; dezenas de usuários simultâneos; dezenas de milhares de registros por ano.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

O arquivo `.specify/memory/constitution.md` está no formato de template e ainda não foi ratificado como constituição ativa do projeto. Portanto, **nenhum gate adicional se aplica** além das regras já presentes em `AGENTS.md` (obrigação de documentar mudanças arquiteturais na wiki Sauron).

- [x] Não há violações de constituição a justificar.

## Project Structure

### Documentation (this feature)

```text
specs/002-tech-stack-definition/
├── plan.md              # This file
├── research.md          # Decisões técnicas e justificativas
├── data-model.md        # Entidades de configuração/ambiente
├── quickstart.md        # Guia de validação do ambiente local
├── contracts/           # Contratos de promoção e integração
└── tasks.md             # Gerado em fase posterior (/speckit.tasks)
```

### Source Code (repository root)

```text
/
├── index.html           # Entry point Vite (nova aplicação React)
├── package.json         # Dependências do frontend e scripts
├── tsconfig.json        # Configuração TypeScript
├── vite.config.ts       # Configuração Vite
├── src/
│   ├── main.tsx         # Bootstrap React
│   ├── App.tsx          # Raiz da aplicação
│   ├── components/      # Componentes reutilizáveis
│   ├── pages/           # Telas do ERP
│   ├── services/        # Clientes Supabase e outras APIs
│   └── types/           # Tipos TypeScript
├── supabase/
│   ├── config.toml      # Configuração do Supabase CLI
│   ├── migrations/      # Migrações de banco (versionadas)
│   ├── seed.sql         # Dados de exemplo para dev local
│   └── functions/       # Edge Functions (futuro)
├── public/              # Assets estáticos
└── docs/
    └── stack.md         # Documento único da stack tecnológica
```

**Structure Decision**: Foi escolhida a estrutura de aplicação web com frontend SPA na raiz e pasta `supabase/` para configurações e migrações. Essa organização é a recomendada pelo Supabase CLI, mantém o frontend e o backend próximos para facilitar o desenvolvimento local e evita a complexidade de um monorepo para um time pequeno.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Nenhuma violação. Não aplicável.
