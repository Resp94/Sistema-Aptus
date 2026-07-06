# Contract: Documentation and Recovery

## Purpose

Garantir que toda mutacao operacional em producao seja rastreavel e tenha criterio de recuperacao.

## Required Documentation Targets

- `.agents/project-memory/009-promover-producao-supabase.md`
- `.sauron/wiki/knowledge/architecture.md`

## Required Fields

Every production execution record must include:
- Date/time of execution.
- Target project ref.
- Production classification.
- Backup/snapshot confirmation.
- Dry-run summary.
- Manual approval checkpoint.
- Applied migration summary.
- Edge Function deploy result.
- Secrets verification result without exposing values.
- Smoke test results.
- Temporary user cleanup result.
- `.env.local` switch result, if performed.
- Failures, rollbacks or pending actions.

## Recovery Rules

- No schema mutation without backup/snapshot confirmation.
- No `.env.local` switch when smoke test is partial or failed.
- No completion claim while temporary users remain active unintentionally.
- Any failure must record the last successful checkpoint and the next recovery action.

## Completion Criteria

The production promotion can be documented as complete only when:
- Schema promotion succeeded.
- Edge Function deploy succeeded.
- Smoke test approved.
- Temporary users were removed or disabled.
- `.env.local` was switched and locally validated, if that step was in scope for the execution.
- `.agents` and `.sauron` were updated in the same session.
