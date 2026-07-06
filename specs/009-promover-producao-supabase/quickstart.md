# Quickstart: Promover Producao Supabase

This guide is the execution checklist for the future implementation phase. It does not authorize running production commands by itself.

## Preconditions

- Feature 008 local gates are still valid:
  - `npm run db:test`
  - `npm run test`
  - `npm run build`
  - `npm run audit`
- Project ref confirmed: `lpwnaxlczwntylcmgotm`.
- Backup/snapshot recuperavel confirmed for production with documented type, timestamp, confirmation source, responsible approver and recoverability statement.
- Supabase CLI authenticated.
- Production public key available for the final `.env.local` switch.
- No service role or secret key will be placed in `.env.local`.

## Phase 1 - Local Verification

Run local verification before touching production:

```powershell
npm run db:test
npm run test
npm run build
npm run audit
```

Expected:
- All commands exit 0.
- Any failure blocks production promotion.

## Phase 2 - Link and Inspect Production

Confirm the target project:

```powershell
supabase link --project-ref lpwnaxlczwntylcmgotm
supabase migration list
```

Expected:
- Output references `lpwnaxlczwntylcmgotm`.
- Remote migration state is understood.
- Any mismatch, remote migration absent locally, local migration with conflicting remote status/order, target uncertainty or authentication/permission/network failure that prevents reliable review blocks the workflow.

## Phase 3 - Dry Run Gate

Run dry-run only:

```powershell
supabase db push --dry-run
```

Expected:
- Output lists only expected local migrations.
- No seed/dump/data-local operation appears.
- No object outside the approved scope of versioned schema, access rules, private Storage, RPCs and `relatorios-exportacao` appears.
- Stop here and request manual approval before applying.

## Phase 4 - Apply Schema After Approval

Only after backup confirmation, dry-run review and explicit manual approval:

```powershell
supabase db push
```

Expected:
- Migrations apply successfully.
- No `--include-seed` is used.
- Any failure stops the workflow and is documented.

## Phase 5 - Deploy Edge Function

Deploy the report export function:

```powershell
supabase functions deploy relatorios-exportacao --project-ref lpwnaxlczwntylcmgotm
```

Expected:
- Function deploy succeeds.
- JWT verification remains enabled.

## Phase 6 - Verify Secrets

Verify production Edge Function secrets without printing values into docs or chat:

```powershell
supabase secrets list --project-ref lpwnaxlczwntylcmgotm
```

Expected:
- Required secrets/default secrets are available to the function.
- No secret values are copied into repository files.

## Phase 7 - Remote Smoke Test

Create temporary validation users in production:
- One authorized to export reports.
- One without export permission.

Validate:
- Authorized user can generate/download a permitted export.
- Unauthorized user is blocked.
- File access does not rely on public permanent URL.
- Temporary users are removed or disabled after the test.

Expected:
- All smoke scenarios pass.
- Any failure blocks `.env.local` switch.

## Phase 8 - Switch `.env.local`

Only after smoke test approval:

```text
VITE_SUPABASE_URL=https://lpwnaxlczwntylcmgotm.supabase.co
VITE_SUPABASE_ANON_KEY=<production public/anon key>
VITE_APP_ENV=production
```

Expected:
- No service role, secret key, database password or management token in `.env.local`.

## Phase 9 - Local App Validation Against Production

Run the app locally after `.env.local` switch:

```powershell
npm run dev
```

Validate:
- Login works.
- Initial authorized screen loads.
- Report export flow works for authorized user/session.
- Unauthorized behavior remains blocked.

## Phase 10 - Documentation

Update:
- `.agents/project-memory/009-promover-producao-supabase.md`
- `.sauron/wiki/knowledge/architecture.md`

Record:
- Target project.
- Backup/snapshot confirmation, including type, timestamp, confirmation source, responsible approver and recoverability statement.
- Dry-run summary.
- Approval checkpoint.
- Schema apply result.
- Function deploy result.
- Secrets verification result without values.
- Smoke test result.
- Temporary user cleanup.
- `.env.local` switch and validation result.
