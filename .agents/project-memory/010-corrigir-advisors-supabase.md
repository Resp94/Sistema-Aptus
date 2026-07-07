# Spec 010 - Corrigir Advisors Supabase

**Data**: 2026-07-06

## O que foi especificado

Criada a feature Spec Kit `010-corrigir-advisors-supabase` para tratar os achados atuais do Supabase Advisors com foco em risco real de seguranca e warnings de performance ligados a RLS/RPC no projeto de producao `lpwnaxlczwntylcmgotm`.

## Decisoes registradas

- A feature e separada da `009-promover-producao-supabase`.
- O escopo cobre seguranca e performance ligada a RLS/RPC, nao tuning amplo de indices/FKs.
- O fluxo inclui artefatos versionados de correcao em `supabase/migrations/`.
- A validacao remota sera feita via MCP do Supabase conectado ao projeto de producao.
- Funcoes `SECURITY DEFINER` so podem permanecer quando houver dependencia viva e justificativa documentada.
- `public.capacidades_perfil` entra no escopo por estar com RLS habilitado sem policy.
- Itens como `unindexed_foreign_keys` e `unused_index` ficam explicitamente fora do escopo desta feature.

## Artefatos criados

- `specs/010-corrigir-advisors-supabase/spec.md`
- `specs/010-corrigir-advisors-supabase/checklists/requirements.md`
- `specs/010-corrigir-advisors-supabase/plan.md`
- `specs/010-corrigir-advisors-supabase/research.md`
- `specs/010-corrigir-advisors-supabase/data-model.md`
- `specs/010-corrigir-advisors-supabase/triagem.md`
- `specs/010-corrigir-advisors-supabase/runbook-validacao.md`
- `specs/010-corrigir-advisors-supabase/quickstart.md`
- `specs/010-corrigir-advisors-supabase/contracts/security-remediation.md`
- `specs/010-corrigir-advisors-supabase/contracts/performance-remediation.md`
- `specs/010-corrigir-advisors-supabase/contracts/remote-validation.md`
- `specs/010-corrigir-advisors-supabase/contracts/triage-governance.md`

## Planejamento tecnico

Executado `/speckit-plan` para transformar a spec em plano de correcao e validacao. O plano divide a feature em triagem dos achados, correcoes versionadas de grants/policies, classificacao de dependencia viva para funcoes privilegiadas, remediacao de warnings `auth_rls_initplan` e `multiple_permissive_policies`, e validacao remota obrigatoria via MCP do Supabase.

## Baseline remoto usado no plano

- Projeto remoto confirmado: `https://lpwnaxlczwntylcmgotm.supabase.co`
- Security advisor atual:
  - `public.capacidades_perfil` com `rls_enabled_no_policy`
  - Varias funcoes `SECURITY DEFINER` ainda sinalizadas como executaveis por `anon` e `authenticated`
- Performance advisor atual:
  - `auth_rls_initplan` em policies antigas
  - `multiple_permissive_policies` em `public.perfis`
  - `unindexed_foreign_keys` e `unused_index` fora do escopo da feature

## Proxima etapa

Executar `/speckit-tasks` para gerar backlog implementavel, mantendo a separacao entre:
- correcao estrutural do backend
- triagem/registro de excecoes
- validacao remota pos-aplicacao

Nenhuma mutacao de producao foi executada nesta etapa de planejamento.

## Fechamento dos gaps do checklist de seguranca

- O checklist `specs/010-corrigir-advisors-supabase/checklists/security.md` foi fechado para 19/19 itens atendidos em 2026-07-06.
- A spec passou a mapear explicitamente os lints do Supabase Advisors para requisitos e criterios de triagem.
- O estado-alvo por papel (`anon`, `authenticated`, `service_role`) foi tornado explicito para evitar interpretacao ambigua de grants residuais.
- Excecoes agora exigem justificativa, impacto residual, gatilho de revisao, responsavel pela reavaliacao e aprovador nomeado.
- A triagem de funcoes `SECURITY DEFINER` foi endurecida com normalizacao por assinatura exata, criterio de dependencia viva em codigo/SQL e regra de precedencia para corrigir exposicao antes de preservar comportamento legitimo.
- O baseline remoto obrigatorio passou a incluir `get_project_url`, advisors de seguranca/performance e `list_migrations`, servindo como referencia objetiva para resolucao, drift e regressao.
- A taxonomia final foi fechada como mutuamente exclusiva: `risco_real`, `drift_remoto`, `concessao_residual`, `excecao_intencional`, `fora_escopo` e `resolvido`.
- A definicao de regressao agora cobre ampliacao de acesso indevido, bloqueio de acesso legitimo e alteracao indevida de ownership/regra de negocio.

## Artefatos reforcados nesta rodada

- `specs/010-corrigir-advisors-supabase/spec.md`
- `specs/010-corrigir-advisors-supabase/data-model.md`
- `specs/010-corrigir-advisors-supabase/triagem.md`
- `specs/010-corrigir-advisors-supabase/runbook-validacao.md`
- `specs/010-corrigir-advisors-supabase/contracts/triage-governance.md`
- `specs/010-corrigir-advisors-supabase/contracts/remote-validation.md`
- `specs/010-corrigir-advisors-supabase/checklists/security.md`
