# Contract: Local → Cloud Promotion

**Feature**: Definição da Stack Tecnológica do Aptus ERP  
**Date**: 2026-06-26

## Purpose

Define the contract for promoting validated local Supabase changes to the cloud environment.

## Parties

- **Local environment**: Supabase CLI + Docker on developer machine.
- **Cloud environment**: Supabase project hosted in Supabase Cloud.

## Preconditions

1. Local `supabase start` is running and healthy.
2. Database migrations are applied locally and tests pass.
3. The Supabase CLI is linked to the correct cloud project (`supabase link`).
4. No uncommitted changes exist in the migration files.

## Promotion Steps (max 2 manual steps)

1. **Validate locally**: run `supabase db reset` to ensure migrations and seeds apply cleanly.
2. **Push to cloud**: run `supabase db push` to apply migrations to the cloud project.

## Validation Criteria

- `supabase status` reports all services healthy locally.
- Migration logs show no errors after `supabase db reset`.
- Cloud project receives the new migration version without failures.

## Rollback

- If `supabase db push` fails, fix the migration locally and repeat the promotion steps.
- No automatic rollback is required for the initial stack setup.

## Notes

- Frontend deployment to Cloudflare Pages is independent and triggered by Git pushes.
- This contract covers database/schema promotion only.
