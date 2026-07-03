# Implementation Plan: Hardening de Segurança das RPCs e Padronização Retroativa do Banco

**Branch**: `main` (spec dir `006-rpc-security-hardening`) | **Date**: 2026-07-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-rpc-security-hardening/spec.md`

## Summary

Fechar as brechas de segurança encontradas na auditoria de 2026-07-02 e uniformizar o padrão de guardrails de todas as funções do banco, sem alterar a arquitetura RPC-first já vigente. O trabalho se divide em: **Fase 0** (correções críticas: remover `criar_perfil_teste`, blindar `registrar_evento_auditoria`, corrigir a escalação de privilégio no trigger `handle_auth_user_sync`, restringir `existe_perfil_admin`); **Fase 1** (padronizar as 26 funções legadas — `search_path` fixo, `REVOKE`/`GRANT` explícitos e guarda `auth.uid()` — sem mudar assinatura nem comportamento); **Fase 2** (testes pgTAP por perfil via `supabase test db`); **Fase 3** (scripts de auditoria + pipeline GitHub Actions); **Fase 4** (documentar diretrizes arquiteturais, incluindo a rejeição da RPC agregadora por página). O único toque no cliente é o ajuste dos 3 pontos de chamada da função de auditoria (remoção do parâmetro de autor).

## Technical Context

**Language/Version**: SQL (PostgreSQL 17 / plpgsql) como superfície principal; TypeScript 6 / React 19 apenas nos 3 pontos de chamada da auditoria; Node ESM para scripts de auditoria.

**Primary Dependencies**: Supabase CLI 2.109.0 (`supabase test db`, `supabase db lint`, `supabase db advisors`), pgTAP (bundlado no ambiente de testes do Supabase), @supabase/supabase-js 2.39.8, Vitest.

**Storage**: PostgreSQL 17 via Supabase; schema versionado em `supabase/migrations/`; seeds em `supabase/seed.sql`.

**Testing**: pgTAP via `supabase test db` para o comportamento de segurança por perfil; Vitest (`npm run test`) para os services do cliente; scripts Node de auditoria estática das migrations.

**Target Platform**: Web SPA (deploy Cloudflare Pages); banco Postgres gerenciado pelo Supabase. CI em GitHub Actions (repositório `Resp94/Sistema-Aptus`).

**Project Type**: Aplicação web interna (frontend SPA + Supabase como backend-as-a-service). Esta feature é predominantemente de banco/segurança e tooling.

**Performance Goals**: N/A — a padronização preserva o plano de execução das funções; o guard `auth.uid()` é O(1). Sem meta de latência nesta feature.

**Constraints**: Fase 1 **não pode** alterar assinatura nem comportamento observável das 26 funções (zero mudança no cliente). A função de auditoria muda de assinatura (remoção do parâmetro de autor) e os 3 pontos de chamada devem ser ajustados no mesmo lote. Nenhuma função `SECURITY DEFINER` pode ficar sem guarda de identidade explícita, exceto a exceção catalogada da auditoria (lista fixa de eventos pré-auth). Migrations são **hand-authored** (convenção do repositório), nunca geradas por diff. `criar_perfil_teste` não pode existir em produção, mas o `supabase db reset` local deve continuar criando os 6 usuários de teste.

**Scale/Scope**: 81 funções auditadas (79 RPCs + 2 triggers); 4 correções críticas; 26 funções a padronizar; 1 suíte pgTAP cobrindo 6 perfis; 3 scripts de auditoria; 1 workflow de CI; 1 documento de diretrizes; 3 pontos de chamada no cliente.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

A constituição em `.specify/memory/constitution.md` continua como template, sem princípios ratificados. Aplicam-se as regras de fato do repositório (padrão de guardrails da geração nova de migrations, RPC-first, RLS como defesa em profundidade) e as boas práticas oficiais do Supabase.

| Diretriz de fato | Status | Justificativa |
|------------------|--------|---------------|
| RPC-first (frontend nunca usa `supabase.from()` para domínio) | Pass | Feature reforça a regra com check automático; não introduz consulta direta. |
| Guardrails padrão em toda RPC (`SECURITY DEFINER` + `search_path` + RBAC + `REVOKE`/`GRANT`) | Pass | É exatamente o objetivo da feature; a Fase 3 trava contra regressão. |
| RLS por operação como defesa em profundidade | Pass | Mantida; documentada com armadilhas na Fase 4. |
| Autorização nunca derivada de `user_metadata` | Pass | Fase 0 corrige o trigger; Fase 3 adiciona check proibindo o padrão. |
| Migrations hand-authored e modulares | Pass | Novas migrations seguem a convenção `AAAAMMDD*_descricao.sql`. |
| Sem backend custom | Pass | Toda lógica permanece em Postgres/Supabase; CI apenas orquestra verificação. |

Nenhuma violação identificada.

## Project Structure

### Documentation (this feature)

```text
specs/006-rpc-security-hardening/
├── plan.md              # Este arquivo
├── research.md          # Fase 0 — decisões e resolução de incógnitas
├── data-model.md        # Fase 1 — entidades de segurança e transições
├── quickstart.md        # Fase 1 — roteiro de validação ponta a ponta
├── contracts/
│   ├── rpc-signatures.md        # Assinaturas afetadas (antes/depois) + contrato da auditoria
│   ├── guardrail-standard.md    # O padrão de guardrails que toda função deve cumprir
│   └── ci-and-audit.md          # Contratos dos scripts de auditoria e do pipeline de CI
├── checklists/
│   └── requirements.md          # Já criado por /speckit-specify
└── tasks.md             # Criado depois por /speckit-tasks
```

### Source Code (repository root)

```text
supabase/
├── migrations/
│   ├── 20260702000002_security_hardening_fase0.sql        # Correções críticas (FR-001..FR-007a): inclui os 2 triggers (handle_auth_user_sync, validar_perfil_update)
│   └── 20260702000003_security_hardening_padronizacao.sql # 26 funções legadas (FR-008..FR-011)
├── seed.sql                                               # Refatorado: criar_perfil_teste efêmero (FR-002)
└── tests/
    ├── 00_helpers.sql            # Helpers pgTAP: set_auth(uuid)/set_anon(), lookup de perfil
    ├── 01_anon_rejeitado.sql     # Catálogo pg_proc: anônimo bloqueado em toda SECURITY DEFINER (FR-015/016)
    ├── 02_rbac_por_perfil.sql    # Matriz dos 6 perfis: ler/escrever por módulo (FR-015)
    ├── 03_auditoria.sql          # Anon whitelist + autor forçado + falsificação impossível (FR-003/003a/003b)
    └── 04_signup_sem_escalacao.sql # Regressão: metadata 'Administrador' -> Visualizador (FR-004)

scripts/
├── audit-rpc.mjs                 # Guardrails das funções nas migrations (FR-012)
├── check-no-from.mjs             # Proíbe supabase.from() em src/services (FR-013)
└── check-no-user-metadata.mjs    # Proíbe user_metadata em autorização (FR-014)

.github/workflows/
└── ci.yml                        # Pipeline: build -> test -> db lint -> advisors -> auditorias (FR-017)

docs/
└── arquitetura-dados.md          # Diretrizes: RPC granular, agregadora rejeitada, views, RLS (FR-018..FR-020)

src/                              # Único toque no cliente (FR-003b):
├── services/auth.service.ts      # 2 chamadas de registrar_evento_auditoria (login falha/sucesso)
└── pages/ResetPassword.tsx       # 1 chamada de registrar_evento_auditoria (senha alterada)

package.json                      # Novos scripts: db:test, audit:rpc, audit:from, audit:metadata
```

**Structure Decision**: Manter a estrutura existente. Toda a carga da feature está em `supabase/` (migrations + seed + tests), `scripts/` (auditoria estática), `.github/workflows/` (CI) e `docs/` (diretrizes). O cliente só é tocado nos 3 pontos de chamada da auditoria. Duas migrations separam correção crítica (Fase 0) de padronização de baixo risco (Fase 1), permitindo revisão e rollback independentes.

## Phase 0 Research

Gerado em [research.md](./research.md). Decisões principais:

- **Perfis reais**: `Administrador, Financeiro, Projetos, Comercial, Técnico, Visualizador` (não "Gestor"). A matriz pgTAP usa esses nomes.
- **Simulação de auth em pgTAP**: `SET LOCAL role` + `SET LOCAL request.jwt.claims` para materializar `auth.uid()`/`auth.role()` dentro dos testes; helper reutilizável em `00_helpers.sql`.
- **Auditoria anônima**: detecção via `auth.uid() IS NULL`; lista fixa de eventos pré-auth (`login_falha`) como constante na função; autor sempre `auth.uid()` para autenticado, `NULL` para o whitelist anônimo.
- **Estratégia de migration**: hand-authored (convenção do repo), não `db pull`. `existe_perfil_admin` e `registrar_evento_auditoria` entram na Fase 0; os 3 helpers de permissão/perfil entram na Fase 1 (26 funções).
- **Seed**: `criar_perfil_teste` passa a ser definida, usada e descartada dentro do próprio `seed.sql`, nunca persistida.
- **CI com Supabase**: GitHub Actions usando `supabase/setup-cli` + `supabase db start` para rodar `db lint`, `db advisors` e `supabase test db` em container.
- **Teste guiado por catálogo**: `pg_proc` filtrando `prosecdef = true`, schema `public`, excluindo funções de trigger (`prorettype = 'trigger'`) e a exceção `registrar_evento_auditoria`.

## Phase 1 Design

Artefatos gerados:

- [data-model.md](./data-model.md) — entidades de segurança (função com privilégio elevado, evento de auditoria, perfil, permissão de módulo) e transições relevantes.
- [contracts/rpc-signatures.md](./contracts/rpc-signatures.md) — assinaturas antes/depois das funções alteradas e contrato da nova função de auditoria.
- [contracts/guardrail-standard.md](./contracts/guardrail-standard.md) — o padrão que toda função deve cumprir e que o script de auditoria valida.
- [contracts/ci-and-audit.md](./contracts/ci-and-audit.md) — contratos dos 3 scripts de auditoria e do pipeline de CI.
- [quickstart.md](./quickstart.md) — roteiro de validação ponta a ponta.

## Post-Design Constitution Check

| Diretriz de fato | Status | Resultado após design |
|------------------|--------|-----------------------|
| RPC-first | Pass | Nenhuma consulta direta introduzida; check `check-no-from.mjs` formaliza. |
| Guardrails padrão | Pass | `guardrail-standard.md` + `audit-rpc.mjs` definem e travam o padrão. |
| RLS defesa em profundidade | Pass | Preservada; armadilhas documentadas em `docs/arquitetura-dados.md`. |
| Sem `user_metadata` em autorização | Pass | Trigger corrigido; `check-no-user-metadata.mjs` trava regressão. |
| Migrations hand-authored | Pass | Duas migrations nomeadas seguindo convenção. |
| Sem backend custom | Pass | Toda lógica em Postgres; CI apenas verifica. |

Nenhuma violação nova introduzida pelo design.

## Complexity Tracking

> Nenhuma violação de constituição a justificar. A separação em duas migrations e a criação de `scripts/` + `.github/workflows/` são estruturas mínimas exigidas pelos requisitos (FR-012..FR-017), não complexidade adicional.
