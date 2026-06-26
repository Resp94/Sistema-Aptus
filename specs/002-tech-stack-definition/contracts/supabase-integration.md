# Contract: Supabase Integration

**Feature**: Definição da Stack Tecnológica do Aptus ERP  
**Date**: 2026-06-26

## Purpose

Define the integration contract between the Vite + React frontend and the Supabase backend.

## Client Configuration

The frontend creates a single Supabase client using environment variables:

```ts
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)
```

## Authentication Contract

- The frontend uses Supabase Auth for session management.
- Session tokens are managed by the Supabase client (no custom token storage).
- Row Level Security (RLS) policies in PostgreSQL enforce authorization.

## Data Access Contract

- Reads: use `supabase.from('table').select(...)`.
- Writes: use `supabase.from('table').insert/update/delete(...)`.
- Real-time subscriptions may be used where live updates are required.

## Error Handling Contract

- All Supabase calls return `{ data, error }` and must check `error` before using `data`.
- Network errors are surfaced to the user with friendly messages.
- Auth errors redirect to the login flow.

## Environment Contract

| Environment | Supabase URL Source | Purpose |
|-------------|---------------------|---------|
| Local dev | `VITE_SUPABASE_URL=http://localhost:54321` | Desenvolvimento local via CLI |
| Production | `VITE_SUPABASE_URL=<cloud-project-url>` | Nuvem do Supabase |

## Notes

- No backend code is required for standard CRUD when RLS policies are in place.
- Edge Functions (Supabase Functions) may be added later for complex business logic.
