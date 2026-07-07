# Implementation Plan: Corrigir Advisors Supabase

**Branch**: `010-corrigir-advisors-supabase` | **Date**: 2026-07-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-corrigir-advisors-supabase/spec.md`

## Summary

Corrigir a conformidade do backend Supabase do projeto de producao `lpwnaxlczwntylcmgotm` com foco em achados reais dos advisors de seguranca e nos warnings de performance ligados a RLS/RPC. A abordagem aprovada e versionar as correcoes em migrations SQL, manter uma triagem explicita dos achados, separar risco real de excecao intencional e validar remotamente o resultado via MCP do Supabase antes de declarar conformidade.

## Technical Context

**Language/Version**: SQL PostgreSQL em migrations Supabase; TypeScript no frontend Vite/React; Deno/TypeScript na Edge Function `relatorios-exportacao`

**Primary Dependencies**: Supabase MCP (`get_advisors`, `list_migrations`, `get_project_url`), migrations em `supabase/migrations`, testes pgTAP em `supabase/tests`, frontend RPC-first em `src/services`, Edge Function `supabase/functions/relatorios-exportacao`

**Storage**: Supabase Postgres no projeto de producao `lpwnaxlczwntylcmgotm`; Supabase Storage privado para exportacoes de relatorios

**Testing**: `npm run db:test`, `npm run test`, `npm run build`, `npm run audit`, validacao remota com advisors `security` e `performance`, e inspecao remota de grants/dependencias quando necessario

**Target Platform**: Banco Supabase Cloud de producao, frontend React local e ambiente de desenvolvimento com MCP Supabase ja conectado

**Project Type**: Web application com backend Supabase RPC-first e Edge Functions

**Performance Goals**: Reduzir os warnings `auth_rls_initplan` e `multiple_permissive_policies` no escopo de RLS/RPC sem regressao de autorizacao e sem ampliar o escopo para tuning geral

**Constraints**: Producao real; correcoes entregues como arquivos `.sql` individuais em `supabase/migrations/`; fora do escopo broad tuning de indices e FKs sem relacao direta com RLS/RPC; funcoes `SECURITY DEFINER` so podem permanecer se houver dependencia viva e justificativa documentada; validacao remota obrigatoria antes da conclusao

**Scale/Scope**: 1 projeto Supabase de producao, 26 migrations ja aplicadas, uma tabela catalogo (`public.capacidades_perfil`) sem policy, dezenas de funcoes `SECURITY DEFINER` sinalizadas remotamente, e um subconjunto de policies antigas com padrao `auth.uid()` e duplicidade permissiva em `public.perfis`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Constituicao do Spec Kit**: PASS com fallback. O arquivo `.specify/memory/constitution.md` esta em estado placeholder e nao traz principios executaveis; por isso os gates desta feature seguem `AGENTS.md`, o skill de Supabase e a propria spec 010.
- **Seguranca de producao**: PASS. O plano trata `lpwnaxlczwntylcmgotm` como producao real e exige que qualquer conclusao de conformidade dependa de validacao remota via advisors.
- **Versionamento auditavel**: PASS. O plano restringe as correcoes a migrations SQL versionadas, artefatos de triagem e runbook no diretorio da feature.
- **Escopo controlado**: PASS. O plano exclui explicitamente tuning geral de FKs/indices e mantém a feature focada em RLS, grants, `SECURITY DEFINER`, triagem de excecoes e validacao remota.
- **Memoria obrigatoria do projeto**: PASS. O plano inclui atualizacao de `.agents` e `.sauron` como parte da propria entrega.

**Re-check after Phase 1 design**: PASS. Os artefatos de design mantem o foco em conformidade de RLS/RPC, validacao remota e separacao entre excecao intencional, drift remoto e correcao estrutural.

## Project Structure

### Documentation (this feature)

```text
specs/010-corrigir-advisors-supabase/
- spec.md
- plan.md
- research.md
- data-model.md
- triagem.md
- runbook-validacao.md
- quickstart.md
- contracts/
  - security-remediation.md
  - performance-remediation.md
  - remote-validation.md
  - triage-governance.md
- tasks.md
```

### Source Code (repository root)

```text
supabase/
- migrations/
- tests/
- functions/
  - relatorios-exportacao/

src/
- services/
- lib/
- pages/

.agents/
- project-memory/

.sauron/
- wiki/
  - knowledge/

AGENTS.md
```

**Structure Decision**: A feature concentra a correcao no backend Supabase versionado. O frontend e a Edge Function so entram no plano como superficie de dependencia viva para decidir quais funcoes `SECURITY DEFINER` precisam ser preservadas. O workflow operacional e documentado dentro do proprio diretorio da feature por meio de `triagem.md` e `runbook-validacao.md`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Nenhuma | N/A | N/A |

## Phase 0 Output

Pesquisa registrada em [research.md](./research.md), cobrindo: `public.capacidades_perfil` sem policy, drift potencial entre grants versionados e grants remotos, criterio de dependencia viva para funcoes privilegiadas, padrao `(select auth.uid())` em policies, consolidacao pontual de policies permissivas e exclusao explicita de tuning amplo fora do escopo.

## Phase 1 Output

- Modelo operacional de triagem e execucao: [data-model.md](./data-model.md)
- Contrato de remediacao de seguranca: [contracts/security-remediation.md](./contracts/security-remediation.md)
- Contrato de remediacao de performance em RLS/RPC: [contracts/performance-remediation.md](./contracts/performance-remediation.md)
- Contrato de validacao remota: [contracts/remote-validation.md](./contracts/remote-validation.md)
- Contrato de governanca da triagem: [contracts/triage-governance.md](./contracts/triage-governance.md)
- Registro inicial de triagem: [triagem.md](./triagem.md)
- Runbook remoto: [runbook-validacao.md](./runbook-validacao.md)
- Guia de validacao da feature: [quickstart.md](./quickstart.md)

## Phase 2 Direction

`/speckit-tasks` deve gerar tarefas executaveis e ordenadas para:

1. Inventariar os achados remotos em `triagem.md` e fixar o baseline a partir dos advisors atuais.
2. Criar migrations SQL para eliminar grants indevidos e reassertar grants corretos por assinatura exata.
3. Corrigir `public.capacidades_perfil` para deixar a policy coerente com o seu uso service-owned.
4. Executar a triagem por dependencia viva para cada funcao `SECURITY DEFINER` ainda sinalizada.
5. Reescrever policies no escopo para o padrao `(select auth.uid())` e equivalentes em helpers.
6. Consolidar policies duplicadas relevantes em `public.perfis` sem regressao de autorizacao.
7. Atualizar ou ampliar os testes pgTAP e testes de integracao necessarios para grants, RLS e regressao de comportamento.
8. Aplicar as migrations no ambiente controlado apropriado e revalidar advisors remotamente via MCP.
9. Classificar qualquer achado remanescente como resolvido, drift remoto, concessao residual ou excecao intencional antes do encerramento.
