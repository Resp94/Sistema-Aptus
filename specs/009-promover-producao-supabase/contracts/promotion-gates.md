# Contract: Promotion Gates

## Purpose

Definir os gates obrigatorios antes, durante e depois da promocao do backend Supabase para producao.

## Scope

Inclui:
- Confirmacao de destino `lpwnaxlczwntylcmgotm`.
- Confirmacao de backup/snapshot recuperavel.
- Revisao de migrations remotas.
- `db push --dry-run`.
- Aprovacao manual explicita.
- Aplicacao de migrations sem seed/dados locais.

Nao inclui:
- Seed de desenvolvimento.
- Dump completo ou data-only.
- Criacao de usuarios reais permanentes.
- Alteracao de `.env.local`.

## Gate Sequence

1. **Destination Gate**
   - Must show project ref: `lpwnaxlczwntylcmgotm`.
   - Must identify it as producao real.
   - Must stop if project ref differs.

2. **Backup Gate**
   - Must confirm backup/snapshot recuperavel before schema mutation.
   - Must record the minimum evidence in operational documentation: backup/snapshot type, timestamp, confirmation source, responsible approver and recoverability statement.
   - Must stop if backup status is unknown.
   - Must stop if the evidence is generic, missing timestamp, missing source, missing approver or does not state recoverability.

3. **Migration State Gate**
   - Must inspect local and remote migration history.
   - Must stop on conflicting history, missing unexpected migrations or remote drift.
   - Must stop if the target project cannot be proven to be `lpwnaxlczwntylcmgotm`.
   - Must stop if a remote migration is absent from the local migration set.
   - Must stop if a local migration appears remotely with conflicting status or order.
   - Must stop if authentication, permission or network errors prevent a reliable remote-state review.

4. **Dry-Run Gate**
   - Must run dry-run before `db push`.
   - Must show exactly which migrations would be applied.
   - Must stop if output includes seed/data/dump or unexpected files.
   - Must stop if output includes any object outside the approved scope of versioned schema, access rules, private Storage, RPCs and `relatorios-exportacao`.

5. **Manual Approval Gate**
   - Must stop after dry-run.
   - Must require explicit human approval before applying migrations.
   - Approval before dry-run does not satisfy this gate.

6. **Apply Gate**
   - Must apply migrations without seed.
   - Must capture result.
   - Must stop the workflow if application fails.

## Pass Criteria

- Target confirmed.
- Backup/snapshot confirmed.
- Backup/snapshot evidence includes type, timestamp, confirmation source, approver and recoverability statement.
- Migration state reviewed.
- Dry-run reviewed.
- Manual approval captured after dry-run.
- Migrations applied without seed/dump/data-local scope.

## Failure Criteria

- Target mismatch.
- No backup/snapshot confirmation with required evidence.
- Unexpected migration.
- Remote migration absent locally.
- Local migration has conflicting remote status or order.
- Remote-state review is inconclusive because of authentication, permission or network failure.
- Object outside approved scope appears in dry-run.
- Seed/dump/data-local in scope.
- No manual approval after dry-run.
- Apply command fails.
