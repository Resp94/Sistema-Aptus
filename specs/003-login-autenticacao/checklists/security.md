# Security Requirements Checklist: Login e Autenticação

**Purpose**: Validate security requirements quality, completeness, and clarity before implementation
**Created**: 2026-06-27 | **Validated**: 2026-06-27 | **Resolved**: 2026-06-27
**Feature**: [spec.md](../spec.md)
**Focus**: Security & Authentication
**Result**: 30 PASS / 2 DEFERRED (94%)

## Requirement Completeness

- [x] CHK001 — Are password complexity requirements explicitly defined (minimum length, character classes, blocklist of common passwords)? [Gap, Spec §Requirements]
  **PASS** — FR-009: min 8 chars, upper, lower, digit, special. Common passwords rejected.

- [x] CHK002 — Are brute-force protection requirements specified with concrete thresholds (max attempts per time window, lockout duration)? [Gap, Spec §Edge Cases]
  **PASS** — FR-010: GoTrue 5 attempts/min/IP + client-side 3s button disable. Research.md documents GoTrue defaults.

- [x] CHK003 — Are session security requirements defined (JWT expiration, refresh token rotation, session invalidation on logout)? [Gap, Spec §FR-002]
  **PASS** — FR-011: JWT 1h expiry, refresh token rotation, invalidation on logout.

- [ ] CHK004 — Are requirements defined for what happens when an authenticated session token is compromised or replayed? [Gap, Exception Flow]
  **DEFERRED** — Token blacklisting/real-time revocation beyond logout invalidation requires infrastructure not available in current Supabase tier. Accepted risk for v1. FR-011 covers logout-based invalidation.

- [x] CHK005 — Are requirements specified for the password reset token lifecycle (generation, expiration time, one-time use, invalidation after use)? [Gap, Spec §FR-007]
  **PASS** — Research.md documents GoTrue defaults: 1h expiry, one-time use. SC-007 enforces.

- [x] CHK006 — Are audit logging requirements defined for security events (failed login, password change, account lockout, admin actions)? [Gap]
  **PASS** — FR-012 + data-model.md §audit_log: 6 event types, append-only, admin-read via RPC.

## Requirement Clarity

- [x] CHK007 — Is "mensagem clara de erro" qualified with specific constraints on what information must NOT be exposed? [Clarity, Spec §FR-008]
  **PASS** — FR-008 explicitly requires "E-mail ou senha inválidos" for both cases.

- [x] CHK008 — Is the "não revelar a existência da conta" requirement in password reset consistently applied to the login error path as well? [Consistency, Spec §US2-Scenario2 vs §FR-008]
  **PASS** — FR-008 now mandates generic message for login errors, matching reset privacy.

- [x] CHK009 — Are the RPC SECURITY DEFINER functions authorization rules within each function body explicitly specified? [Clarity, Spec data-model.md §RPC Functions]
  **PASS** — Contracts RPC table: Authorization column with per-function rules and exception messages.

- [x] CHK010 — Is the term "lembrar de mim" quantified with specific session persistence duration and security implications? [Clarity, Spec §FR-001]
  **PASS** — Contracts "Lembrar de mim" Contract: JWT 1h, refresh rotation, browser-session vs persistent.

## Requirement Consistency

- [x] CHK011 — Do the granular RLS policies align with FR-004 ("manter a tabela usuarios")? [Consistency]
  **PASS** — Mirroring via triggers only; consistent.

- [x] CHK012 — Are RPC endpoints consistent between contracts and data-model? [Consistency]
  **PASS** — Same 3 functions in both artifacts.

- [x] CHK013 — Does RPC-first constraint conflict with supabase.auth.signInWithPassword()? [Consistency]
  **PASS** — Auth (GoTrue SDK) vs data (RPC) are separate domains.

## Acceptance Criteria Quality

- [x] CHK014 — Can SC-001 be measured independently of test account provisioning? [Measurability, Spec §SC-001]
  **PASS** — SC-001 now includes prerequisite: "após execução bem-sucedida de supabase db reset."

- [x] CHK015 — Are security-specific success criteria defined? [Gap, Spec §Success Criteria]
  **PASS** — SC-005–SC-008: no enumeration, password enforcement, token lifecycle, audit log.

- [x] CHK016 — Is "mensagem de erro compreensível" measurable? [Measurability, Spec §SC-003]
  **PASS** — SC-003 specifies exact message text. Objectively verifiable.

## Scenario Coverage

- [x] CHK017 — Are requirements defined for inactive account login? [Coverage]
  **PASS** — US3-Scenario2 + Edge Cases.

- [x] CHK018 — Are requirements defined for concurrent login attempts from different devices? [Coverage, Gap]
  **PASS** — Edge Cases: permitted, each device gets own refresh token.

- [x] CHK019 — Are requirements specified for what happens after password reset? [Coverage, Gap]
  **PASS** — FR-014: forced re-authentication. Contracts "Password Reset Post-Flow."

- [x] CHK020 — Is the admin auth check inside the RPC body specified? [Coverage]
  **PASS** — Contracts: existe_perfil_admin() check, raises on failure.

## Edge Case Coverage

- [x] CHK021 — Is the behavior specified when Supabase Auth is unreachable? [Edge Case, Gap]
  **PASS** — Edge Cases: toast message, form stays enabled for retry.

- [x] CHK022 — Is the behavior specified when obter_perfil_usuario() returns null? [Edge Case, Gap]
  **PASS** — Contracts "Null Profile Contract": error, force logout, redirect.

- [x] CHK023 — Are requirements defined for email confirmation status? [Edge Case, Gap]
  **PASS** — FR-013 + data-model Email Confirmation Policy: dev/prod/test paths.

- [x] CHK024 — Is the behavior specified when password reset email bounces? [Edge Case, Gap]
  **PASS** — Edge Cases: logged, no proactive notification, user can re-request.

## Non-Functional Requirements — Security

- [x] CHK025 — Are HTTPS/TLS requirements explicitly stated? [Gap, Security]
  **PASS** — Assumptions: "exclusivamente via HTTPS."

- [ ] CHK026 — Are CSP header requirements defined to prevent XSS on the login page? [Gap, Security]
  **DEFERRED** — CSP is a deployment/infrastructure concern (Cloudflare _headers or Vite plugin). Not a login feature requirement. Addressed in deploy phase.

- [x] CHK027 — Are CSRF protection requirements specified? [Gap, Security]
  **PASS** — Research.md: GoTrue manages CSRF tokens internally. Documented.

- [x] CHK028 — Are requirements defined for secure storage of Supabase anon_key? [Gap, Security]
  **PASS** — Stack.md: build-time env injection.

- [x] CHK029 — Are data classification requirements defined for usuarios and perfis tables? [Gap, Security]
  **PASS** — Data-model: PII (email, phone, nome, ip_origem) vs Interno columns.

## Dependencies & Assumptions

- [x] CHK030 — Is the assumption about test user passwords validated against hardcoded credentials risk? [Assumption]
  **PASS** — SEED_USER_PASSWORD env var. Quickstart: no hardcoded passwords.

- [x] CHK031 — Is the email service dependency documented with security requirements? [Dependency]
  **PASS** — TLS + SMTP auth required for production email service.

- [x] CHK032 — Are security boundaries between auth.users and public.usuarios clearly specified? [Dependency]
  **PASS** — Trigger-based sync, one-way. Boundary documented.

---

## Resolution Summary

| Dimension | PASS | DEFERRED | Rate |
|-----------|------|----------|------|
| Requirement Completeness | 5 | 1 | 83% |
| Requirement Clarity | 4 | 0 | 100% |
| Requirement Consistency | 3 | 0 | 100% |
| Acceptance Criteria Quality | 3 | 0 | 100% |
| Scenario Coverage | 4 | 0 | 100% |
| Edge Case Coverage | 4 | 0 | 100% |
| Non-Functional Requirements | 4 | 1 | 80% |
| Dependencies & Assumptions | 3 | 0 | 100% |
| **Total** | **30** | **2** | **94%** |

### Deferred (accepted for v1)

- **CHK004** — Token compromise recovery: GoTrue free tier limitation. Mitigated by logout invalidation + 1h JWT expiry.
- **CHK026** — CSP headers: deploy/infra concern; configured in Cloudflare Pages _headers, not a login spec requirement.

### Artifacts Updated

| File | Changes |
|------|---------|
| `spec.md` | +FR-009–FR-014, 9 Edge Cases, +SC-005–SC-008, Assumptions rewritten |
| `contracts/login-flow.md` | RPC Authorization column, Null Profile, Lembrar de mim, Password Reset Post-Flow, input sanitization |
| `data-model.md` | Classification column on tables, +audit_log, +Email Confirmation Policy |
| `research.md` | GoTrue security defaults (bcrypt, rate limit, JWT, refresh rotation, reset token, CSRF, HTTPS) |
| `quickstart.md` | Hardcoded passwords → SEED_USER_PASSWORD env var |
