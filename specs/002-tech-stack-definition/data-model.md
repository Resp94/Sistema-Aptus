# Data Model: Definição da Stack Tecnológica

**Feature**: Definição da Stack Tecnológica do Aptus ERP  
**Date**: 2026-06-26  
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

> Esta feature não define entidades de negócio do ERP. O documento descreve as entidades de configuração, ambiente e versionamento necessárias para implementar e manter a stack tecnológica.

## Environment Configuration

Representa os parâmetros necessários para conectar o frontend aos ambientes Supabase.

| Field | Type | Description |
|-------|------|-------------|
| `VITE_SUPABASE_URL` | string | URL do projeto Supabase (local ou nuvem) |
| `VITE_SUPABASE_ANON_KEY` | string | Chave anônima do Supabase para o frontend |
| `VITE_APP_ENV` | string | Ambiente da aplicação: `local` ou `production` |

## Supabase Project Metadata

Representa a vinculação entre o repositório e o projeto Supabase na nuvem.

| Field | Type | Description |
|-------|------|-------------|
| `project_id` | string | ID do projeto Supabase na nuvem |
| `linked_at` | timestamp | Data em que o projeto foi vinculado via `supabase link` |
| `cli_version` | string | Versão mínima/recomendada do Supabase CLI |

## Database Migration

Representa o controle de migrações do banco de dados.

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Identificador da migração (ex.: `YYYYMMDDHHMMSS_description`) |
| `name` | string | Nome descritivo da migração |
| `applied_at_local` | timestamp | Data de aplicação no ambiente local |
| `applied_at_cloud` | timestamp | Data de aplicação no ambiente de nuvem |
| `status` | string | `pending`, `applied`, `failed`, `rolled_back` |

## Local Environment Health Check

Representa os critérios mínimos para considerar o ambiente local saudável.

| Field | Type | Description |
|-------|------|-------------|
| `service` | string | Nome do serviço: `postgres`, `auth`, `rest`, `storage` |
| `expected_status` | string | Status esperado: `healthy` |
| `check_command` | string | Comando ou endpoint usado para validação |

## Relationships

```text
Environment Configuration ──► Supabase Project Metadata
        │                              │
        │                              │
        ▼                              ▼
   Frontend App              Database Migration
                                     │
                                     ▼
                         Local Environment Health Check
```

## Notes

- As entidades de negócio do ERP (clientes, contas, propostas, etc.) permanecem definidas em `docs/banco-de-dados.md` e serão implementadas em features futuras.
- A migração inicial da stack pode incluir apenas tabelas de sistema do Supabase (`auth.users`, etc.) e seeds de exemplo.
