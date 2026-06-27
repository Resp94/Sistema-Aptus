# Implementation Plan: Login e Autenticação

**Branch**: `003-login-autenticacao` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-login-autenticacao/spec.md`

## Summary

Implementar a primeira página React do sistema a partir do layout legado `login.html`, integrando-a à autenticação do Supabase. Criar o schema das tabelas `usuarios` (espelho do auth) e `perfis` (dados aplicacionais e RBAC), popular usuários de teste para todas as personas do projeto e validar o login de cada perfil.

## Technical Context

**Language/Version**: TypeScript 5.5+ (es2023), React 19

**Primary Dependencies**: Vite 6, React 19, React-DOM 19, @supabase/supabase-js 2.39.8

**Storage**: PostgreSQL 17 via Supabase (GoTrue para autenticação)

**Testing**: Vitest 1.3.1

**Target Platform**: Web (SPA), deploy estático na Cloudflare Pages

**Project Type**: Web application (frontend SPA + backend-as-a-service)

**Performance Goals**: Carregamento da página de login < 2 s; login + redirecionamento < 5 s em ambiente local

**Constraints**: Sem backend customizado; comunicação exclusiva via Supabase client. **RPC-first**: todo acesso a dados pelo frontend é feito via `supabase.rpc()` (PostgreSQL Functions), nunca por queries diretas a tabelas. RLS obrigatório em todas as tabelas novas — o RLS atua como segunda camada de defesa, mas a camada primária são as RPCs. Telas legadas ainda existem na raiz e servem apenas como referência.

**Scale/Scope**: 5 usuários de teste iniciais, autenticação interna da empresa.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Justificativa |
|-----------|--------|---------------|
| Documentar mudanças arquiteturais em `.sauron` / `.agents` | ✅ Pass | Criar documentação dos testes/personas e do schema em `.agents` ao final da implementação. |
| Stack tecnológica (Vite + React + TypeScript) | ✅ Pass | A página será React/Vite/TS. |
| Banco PostgreSQL via Supabase com RLS | ✅ Pass | Tabelas `usuarios` e `perfis` seguirão o schema do projeto e terão RLS. |
| Deploy estático Cloudflare Pages | ✅ Pass | Frontend SPA, sem backend customizado. |

## Project Structure

### Documentation (this feature)

```text
specs/003-login-autenticacao/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
src/
├── pages/
│   └── Login.tsx        # Tela de login React baseada em login.html
├── components/
│   └── ui/              # Componentes reutilizáveis se necessário
├── services/
│   └── supabase.ts      # Cliente Supabase já existente
├── types/
│   └── auth.ts          # Tipagens de perfil/usuário
└── main.tsx             # Ponto de entrada da SPA

supabase/
├── migrations/
│   └── 00000000000000_usuarios_perfis.sql   # Tabelas + triggers + RPCs
└── seed.sql             # Usuários de teste das personas

public/
└── mqu1bpo3-Logo-Fundo-removido.png  # Logo da marca (se ainda não estiver)
```

**Structure Decision**: Mantém-se a estrutura SPA Vite+React existente. A página de login será o primeiro componente em `src/pages/Login.tsx`, reaproveitando o `aptus.css` para identidade visual. O schema é gerenciado via migrations do Supabase e seeds para testes.

## Complexity Tracking

> Nenhuma violação identificada na fase de planejamento.
