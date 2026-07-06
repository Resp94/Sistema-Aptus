# Plan Quality Checklist: Promover Producao Supabase

**Purpose**: Validate whether the production promotion plan is complete, clear, consistent, measurable and ready to become operational tasks.
**Created**: 2026-07-06
**Feature**: [spec.md](../spec.md) and [plan.md](../plan.md)

**Note**: This checklist validates the quality of the written requirements and plan. It does not validate production execution.

## Requirement Completeness

- [x] CHK001 Are all production promotion checkpoints explicitly represented from local validation through final documentation? [Completeness, Plan §Phase 2 Direction]
- [x] CHK002 Are the exact in-scope artifacts for promotion defined, including migrations, access rules, Storage, RPCs and `relatorios-exportacao`? [Completeness, Spec §FR-004]
- [x] CHK003 Are out-of-scope artifacts explicitly excluded, including seed, dumps, local data and permanent test users? [Completeness, Spec §FR-005, Research Decision 2]
- [x] CHK004 Are prerequisites for production mutation complete, including destination, backup/snapshot, remote migration state, dry-run and manual approval? [Completeness, Contract §Promotion Gates]
- [x] CHK005 Are prerequisites for `.env.local` switching complete, including schema, function, secrets, smoke test, temporary user cleanup and documentation? [Completeness, Contract §env-local-switch]
- [x] CHK006 Are required documentation targets and required execution record fields fully specified? [Completeness, Contract §documentation-and-recovery]

## Requirement Clarity

- [x] CHK007 Is "producao real" consistently tied to the project ref `lpwnaxlczwntylcmgotm` with no alternate target ambiguity? [Clarity, Spec §FR-001]
- [x] CHK008 Is "backup/snapshot recuperavel" defined clearly enough to know what evidence must exist before schema mutation? [Clarity, Spec §FR-019, Data Model §Ambiente de Producao]
- [x] CHK009 Is "aprovacao manual explicita" clear enough to distinguish approval before dry-run from approval after dry-run? [Clarity, Spec §FR-016, Contract §Promotion Gates]
- [x] CHK010 Are "mudancas inesperadas", "remote drift" and conflicting migration history defined sufficiently for a reviewer to stop the workflow? [Clarity, Spec §FR-003, Contract §Promotion Gates]
- [x] CHK011 Is the required production public key for `.env.local` distinguished unambiguously from service role, secret key and management tokens? [Clarity, Contract §env-local-switch]
- [x] CHK012 Are temporary smoke test users defined clearly enough to identify purpose, permitted persona, blocked persona and cleanup expectation? [Clarity, Spec §FR-014/FR-015, Data Model §Usuario Temporario de Smoke Test]

## Requirement Consistency

- [x] CHK013 Do the spec, plan, quickstart and contracts consistently keep seed/dump/local data outside scope? [Consistency, Spec §FR-005, Plan §Constraints, Quickstart §Phase 4]
- [x] CHK014 Do the spec, plan and env contract consistently block `.env.local` until smoke test completion? [Consistency, Spec §FR-017/FR-018, Plan §Constraints, Contract §env-local-switch]
- [x] CHK015 Do the data model state transitions align with the gate sequence in `promotion-gates.md`? [Consistency, Data Model §Lote de Promocao, Contract §Promotion Gates]
- [x] CHK016 Do the smoke test pass/block criteria align with success criteria SC-004, SC-005, SC-010 and SC-013? [Consistency, Spec §Success Criteria, Contract §smoke-test]
- [x] CHK017 Are Edge Function deployment and secret verification consistently described as separate checkpoints after schema application? [Consistency, Plan §Phase 2 Direction, Research Decisions 4/5]
- [x] CHK018 Are documentation obligations consistent between `AGENTS.md`, the spec, the plan and the documentation contract? [Consistency, Spec §FR-011, Contract §documentation-and-recovery]

## Acceptance Criteria Quality

- [x] CHK019 Are all success criteria objectively measurable without relying on vague terms like "validado" without pass criteria? [Measurability, Spec §Success Criteria]
- [x] CHK020 Are manual approval, backup confirmation and dry-run review represented as measurable completion gates? [Measurability, Spec §SC-011/SC-014, Contract §Promotion Gates]
- [x] CHK021 Are smoke test pass criteria expressed as a complete set of required scenario outcomes rather than an informal judgement? [Measurability, Contract §smoke-test]
- [x] CHK022 Is temporary user cleanup measurable enough to prove no intended smoke test users remain active? [Measurability, Spec §SC-010, Data Model §Usuario Temporario de Smoke Test]
- [x] CHK023 Are `.env.local` safety criteria measurable enough to detect privileged key exposure? [Measurability, Spec §SC-006, Contract §env-local-switch]
- [x] CHK024 Are rollback and recovery completion signals clear enough to decide whether the feature can be marked complete after a failure? [Measurability, Contract §documentation-and-recovery]

## Scenario Coverage

- [x] CHK025 Are primary flow requirements complete for local validation, production inspection, dry-run, manual approval, schema apply, function deploy, smoke test and env switch? [Coverage, Plan §Phase 2 Direction]
- [x] CHK026 Are alternate flow requirements defined for a remote project with existing or partial migration history? [Coverage, Spec §Edge Cases]
- [x] CHK027 Are exception flow requirements defined for command failure, network/credential failure, migration apply failure and Edge Function deploy failure? [Coverage, Spec §Edge Cases, Contract §documentation-and-recovery]
- [x] CHK028 Are recovery requirements defined for failed local validation after `.env.local` is switched? [Coverage, Contract §env-local-switch]
- [x] CHK029 Are requirements defined for partial smoke test success, where login/read works but export or unauthorized blocking fails? [Coverage, Spec §Edge Cases]
- [x] CHK030 Are requirements defined for temporary user cleanup failure after smoke test execution? [Coverage, Spec §Edge Cases, Contract §smoke-test]

## Security And Privacy Requirements

- [x] CHK031 Are requirements complete for preventing service role, secret key, database password and management token exposure in frontend-consumed configuration? [Security, Contract §env-local-switch]
- [x] CHK032 Are requirements clear that privileged secrets belong only in server-side Edge Function configuration? [Security, Research Decision 5]
- [x] CHK033 Are requirements sufficient to prove smoke tests exercise user-scoped authorization rather than only admin/service-role access? [Security, Research Decision 6, Contract §smoke-test]
- [x] CHK034 Are requirements defined for preserving private Storage and avoiding public permanent report URLs during production validation? [Security, Spec §FR-006, Contract §smoke-test]
- [x] CHK035 Are requirements defined for blocking unauthorized export and download attempts as part of the production gate? [Security, Spec §FR-008, Contract §smoke-test]
- [x] CHK036 Are requirements clear enough to prevent test credentials or temporary users from becoming long-lived production access paths? [Security, Spec §FR-015, Data Model §Usuario Temporario de Smoke Test]

## Dependencies And Assumptions

- [x] CHK037 Are assumptions about feature 008 local validation traceable to concrete required local gates? [Assumption, Spec §Assumptions, Quickstart §Phase 1]
- [x] CHK038 Are assumptions about Supabase CLI authentication, production public key availability and backup availability documented as prerequisites? [Dependency, Quickstart §Preconditions]
- [x] CHK039 Are dependencies on current Supabase CLI behavior and official docs captured with sufficient source references? [Dependency, Research Decisions 1/4/5]
- [x] CHK040 Are assumptions about missing real users resolved by requirements for temporary users rather than left implicit? [Assumption, Spec §Clarifications, Contract §smoke-test]

## Traceability And Task Readiness

- [x] CHK041 Does every major Phase 2 task direction trace back to a spec requirement, contract or data model entity? [Traceability, Plan §Phase 2 Direction]
- [x] CHK042 Are task boundaries clear enough to keep production-inspection commands separate from production-mutating commands? [Clarity, Plan §Phase 2 Direction, Contract §Promotion Gates]
- [x] CHK043 Are stop points explicit enough for future tasks to pause after dry-run and after smoke test failure? [Traceability, Spec §FR-016/FR-018]
- [x] CHK044 Are documentation tasks specified strongly enough to satisfy the `.agents` and `.sauron` write obligation? [Traceability, Contract §documentation-and-recovery]
- [x] CHK045 Are future tasks prevented from changing `.env.local` before all upstream gates have passed? [Traceability, Spec §FR-017, Contract §env-local-switch]

## Notes

- Verified on 2026-07-06 against `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md` and contracts.
- Initial result: 42/45 items passing.
- Closed on 2026-07-06 after updating `spec.md`, `data-model.md`, `quickstart.md` and `contracts/promotion-gates.md`.
- Final result: 45/45 items passing.
- CHK008 closed by defining required backup/snapshot evidence: type, timestamp, confirmation source, responsible approver and recoverability statement.
- CHK010 closed by defining concrete stop conditions for target mismatch, remote/local migration conflicts, drift, out-of-scope dry-run output and authentication, permission or network failures that prevent reliable review.
- CHK015 closed by aligning `Lote de Promocao` transitions with the full promotion gate sequence through destination, backup, migration state, dry-run, manual approval, schema apply, function deploy, secrets, smoke test and `.env.local` validation.
