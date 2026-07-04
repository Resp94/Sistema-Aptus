# RBAC Requirements Checklist: RBAC por Capacidades Nomeadas

**Purpose**: Validate the clarity, completeness, consistency, and measurability of RBAC/capability requirements before task generation
**Created**: 2026-07-03
**Feature**: [spec.md](../spec.md)

**Note**: This checklist tests the requirements and design artifacts themselves. It is not an implementation test plan.

## Capability Model Completeness

- [x] CHK001 Are all capability resources and actions listed in the spec also represented in the capability matrix contract? [Completeness, Spec §FR-007..FR-024, Contract capability-matrix]
- [x] CHK002 Are the canonical capability naming rules specified consistently across spec, data model, and contracts? [Consistency, Spec §Key Entities, Data Model §Capacidade Nomeada]
- [x] CHK003 Are duplicate capability prevention requirements defined at both business-rule and data-model levels? [Completeness, Spec §FR-002, Data Model §Matriz de Capacidades por Perfil]
- [x] CHK004 Is the expected behavior for unknown, misspelled, or absent capabilities explicitly specified? [Edge Case, Spec §Edge Cases]
- [x] CHK005 Are future administrative edits to the capability matrix clearly marked out of scope while preserving the expected future extension point? [Scope, Spec §Out of Scope, Research §Decision: Capacidades em tabela auditavel]

## Profile Matrix Quality

- [x] CHK006 Are all six technical profiles accounted for in the capability matrix, including Visualizador as a technical minimum profile? [Completeness, Spec §FR-008..FR-013a, Contract capability-matrix]
- [x] CHK007 Are the five operational personas clearly distinguished from the Visualizador technical state across requirements and success criteria? [Clarity, Spec §US3, Spec §SC-006]
- [x] CHK008 Are Financeiro and Comercial cobrança responsibilities differentiated unambiguously between baixar, emitir, boleto, and notificar? [Clarity, Spec §FR-009, Spec §FR-011, Contract capability-matrix]
- [x] CHK009 Are Projetos and Técnico task permissions differentiated unambiguously between qualquer and propria/proprio actions? [Clarity, Spec §FR-010..FR-012, Contract rpc-capability-contract]
- [x] CHK010 Are module-read permissions documented separately from action capabilities for every profile affected by the feature? [Completeness, Contract capability-matrix §Leitura por Modulo]

## RPC Authorization Requirements

- [x] CHK011 Are all state-changing RPCs and business-effect actions mapped to a named capability? [Completeness, Spec §FR-025, Contract rpc-capability-contract]
- [x] CHK012 Is the definition of "business-effect action" specific enough to classify boleto, notificacao, exportacao, baixa, envio, and geracao without ambiguity? [Clarity, Spec §Clarifications, Spec §Operacao protegida]
- [x] CHK013 Are helper RPCs and authorization helpers distinguished from domain RPCs so audit rules do not conflict? [Consistency, Contract audit-and-tests, Contract rpc-capability-contract]
- [x] CHK014 Are expected Unauthorized vs Forbidden outcomes specified sufficiently for requirements and tests to align? [Measurability, Contract rpc-capability-contract]
- [x] CHK015 Are admin-only user-management requirements reconciled with capability-based authorization without contradicting the existing admin guard? [Consistency, Spec §FR-023, Contract rpc-capability-contract]

## Ownership and Scoped Access

- [x] CHK016 Are ownership rules defined for every propria/proprio capability used in the feature? [Completeness, Spec §FR-026, Data Model §Ownership]
- [x] CHK017 Is task ownership defined with enough precision to distinguish assigned tasks from visible project tasks? [Clarity, Data Model §Ownership, Spec §FR-031]
- [x] CHK018 Is apontamento ownership defined with enough precision to prevent forged member IDs while still allowing project managers to register any member? [Clarity, Spec §FR-029..FR-030, Contract rpc-capability-contract]
- [x] CHK019 Are Técnico team-visibility requirements specific enough to determine which colleagues are included and which data remains limited? [Ambiguity, Spec §FR-033..FR-034, Research §Leitura de equipe]
- [x] CHK020 Are legacy Visualizador users covered as a transition/edge case without being treated as active personas? [Edge Case, Spec §Edge Cases, Spec §FR-035..FR-036]

## Frontend Requirements Quality

- [x] CHK021 Are frontend capability-loading requirements clear about when capabilities are refreshed relative to session/profile changes? [Clarity, Spec §Edge Cases, Contract frontend-capabilities]
- [x] CHK022 Are requirements clear that frontend capability gates are UX only and backend RPCs remain the authorization source? [Consistency, Spec §Contexto e Motivacao, Spec §Assumptions]
- [x] CHK023 Are all action-bearing pages listed in the frontend contract with the capability gates they must consume? [Completeness, Contract frontend-capabilities §Uso por Pagina]
- [x] CHK024 Are requirements clear about the migration boundary from `podeEscrever` to `pode()` so new action gates do not keep using module write flags? [Clarity, Spec §FR-005, Spec §FR-039]
- [x] CHK025 Are UI recovery/feedback requirements specified for cases where a button is visible but backend ownership rejects the action? [Coverage, Contract frontend-capabilities §Estados de UI]

## Functional Bug Requirement Coverage

- [x] CHK026 Are requirements for "sem tarefa" explicitly tied to null payload semantics rather than a textual sentinel? [Clarity, Spec §FR-040, Data Model §Apontamento de horas]
- [x] CHK027 Are close behavior requirements for Propostas and Contratos specified for both visible control and Esc? [Completeness, Spec §FR-041]
- [x] CHK028 Are cliente inactivation and reactivation state transitions specified with the required capability distinction? [Completeness, Spec §FR-042, Data Model §Cliente]
- [x] CHK029 Are functional bug fixes scoped so they do not imply unrelated redesign of page layouts or integrations? [Scope, Spec §US5, Spec §Out of Scope]

## Audit and Quality Guardrail Requirements

- [x] CHK030 Are audit requirements specific enough to classify read guards, action guards, helper allowlists, and admin-only exceptions? [Clarity, Spec §FR-043..FR-044, Contract audit-and-tests]
- [x] CHK031 Are pgTAP coverage requirements complete for capability matrix, ownership, Visualizador minimum state, and Técnico shared-team visibility? [Completeness, Spec §FR-045..FR-048, Contract audit-and-tests]
- [x] CHK032 Are frontend unit-test requirements limited to requirement-relevant helpers and payload normalization rather than broad UI behavior? [Scope, Spec §FR-049, Contract audit-and-tests]
- [x] CHK033 Are E2E/persona validation requirements consistent with the removal of Visualizador as an operational persona? [Consistency, Spec §FR-050, Contract audit-and-tests]
- [x] CHK034 Are final gate requirements traceable to build, unit, database, and audit checks without depending on undocumented commands? [Traceability, Quickstart §1..§3, Plan §Technical Context]

## Documentation and Traceability

- [x] CHK035 Are docs/personas and docs/arquitetura-dados update requirements specific about which business rules must change? [Completeness, Spec §FR-051..FR-053]
- [x] CHK036 Are Dashboard access decisions documented consistently between spec, plan, and capability/read matrix? [Consistency, Spec §FR-053, Contract capability-matrix]
- [x] CHK037 Are out-of-scope boundaries explicit enough to prevent implementation tasks for admin capability UI or page-aggregator RPCs? [Scope, Spec §Out of Scope]
- [x] CHK038 Are success criteria measurable enough to determine readiness without inspecting implementation internals? [Measurability, Spec §SC-001..SC-012]
- [x] CHK039 Are requirement IDs, contract sections, and quickstart scenarios traceable enough for `/speckit-tasks` to generate independently testable tasks? [Traceability, Spec §Requirements, Plan §Phase 1 Design]
