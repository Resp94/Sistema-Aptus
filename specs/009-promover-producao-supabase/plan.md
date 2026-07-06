# Implementation Plan: Promover Producao Supabase

**Branch**: `009-promover-producao-supabase` | **Date**: 2026-07-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-promover-producao-supabase/spec.md`

## Summary

Promover para o projeto Supabase de producao `lpwnaxlczwntylcmgotm` somente o backend versionado e validado localmente, com gates explicitos antes de qualquer mutacao: confirmar destino, confirmar backup/snapshot recuperavel, revisar migrations remotas, executar dry-run, parar para aprovacao manual, aplicar schema sem seed/dados locais, publicar a Edge Function `relatorios-exportacao`, configurar/verificar secrets, executar smoke test remoto com usuarios temporarios e limpar esses usuarios. O arquivo `.env.local` so deve apontar para producao depois de smoke test remoto completo aprovado.

## Technical Context

**Language/Version**: TypeScript no frontend Vite/React e Supabase Edge Functions em Deno/TypeScript; SQL PostgreSQL via migrations Supabase.

**Primary Dependencies**: Supabase CLI, Supabase Cloud project `lpwnaxlczwntylcmgotm`, migrations em `supabase/migrations`, Edge Function `supabase/functions/relatorios-exportacao`, Supabase Auth, Storage privado, `@supabase/supabase-js`, `pdf-lib`, `fflate`.

**Storage**: Supabase Postgres em producao, Supabase Storage privado (`relatorios-exportados`) criado por migration, e `.env.local` apenas como configuracao local do frontend.

**Testing**: Revalidacao local antes da promocao (`npm run db:test`, `npm run test`, `npm run build`, `npm run audit`), revisao remota (`supabase migration list`, `supabase db push --dry-run`), smoke test remoto com usuarios temporarios e verificacao da aplicacao local apos troca de `.env.local`.

**Target Platform**: Supabase Cloud em producao para banco/Auth/Storage/Edge Functions; frontend Vite/React rodando localmente durante validacao e posteriormente hospedado em Cloudflare Pages.

**Project Type**: Web application com backend Supabase RPC-first e Edge Function server-side.

**Performance Goals**: A promocao deve ser executada em janela controlada e so avanca entre checkpoints com evidencia. O smoke test remoto de exportacao deve respeitar os limites ja validados da feature 008: download imediato para volumes comuns em ate 10 segundos.

**Constraints**: Producao real; sem seed/dados locais/dump; sem chaves privilegiadas no frontend; service role apenas em ambiente server-side; `db push` bloqueado ate backup/snapshot recuperavel, dry-run revisado e aprovacao manual explicita; `.env.local` bloqueado ate smoke test remoto completo aprovado.

**Scale/Scope**: Promocao inicial do schema versionado completo existente e da Edge Function `relatorios-exportacao`; validacao minima com um usuario temporario autorizado e um usuario temporario sem permissao; atualizacao posterior de `.env.local` para `https://lpwnaxlczwntylcmgotm.supabase.co` e chave publica de producao.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Spec-driven delivery**: PASS. A feature 009 possui spec e clarificacoes antes do plano.
- **Production safety**: PASS. O plano separa revisao, dry-run, aprovacao manual, backup/snapshot, aplicacao, deploy de funcao, smoke test e troca de `.env.local`.
- **No data promotion by accident**: PASS. Seed, dump e dados locais ficam explicitamente fora do escopo.
- **Supabase security**: PASS. Chaves privilegiadas nao entram no frontend; secrets server-side ficam na Edge Function; RLS/RPC/Storage privado permanecem como fonte de seguranca.
- **Auditability/documentation**: PASS. A mutacao operacional deve ser registrada em `.agents` e `.sauron` na mesma sessao da execucao.
- **Rollback/recovery posture**: PASS. A aplicacao de schema exige confirmacao previa de backup/snapshot recuperavel; falhas bloqueiam a troca de `.env.local`.

**Re-check after Phase 1 design**: PASS. Os contratos e quickstart preservam os gates acima e tratam a promocao como workflow com checkpoints, nao como comando unico.

## Project Structure

### Documentation (this feature)

```text
specs/009-promover-producao-supabase/
- spec.md
- plan.md
- research.md
- data-model.md
- quickstart.md
- contracts/
  - promotion-gates.md
  - smoke-test.md
  - env-local-switch.md
  - documentation-and-recovery.md
- tasks.md              # Criado depois por /speckit-tasks
```

### Source Code (repository root)

```text
supabase/
- migrations/
- functions/
  - relatorios-exportacao/
- tests/

src/
- services/
  - supabase.ts
  - relatorios.service.ts
- pages/
  - RelatoriosPage.tsx

.env.local              # Alterado somente apos smoke test remoto aprovado
.agents/project-memory/
.sauron/wiki/
```

**Structure Decision**: Nao criar codigo novo para promocao. A feature 009 organiza um workflow operacional sobre artefatos existentes: migrations Supabase, Edge Function ja implementada, testes locais, configuracao local e documentacao obrigatoria. Qualquer automacao futura deve nascer de tarefas posteriores, nao deste plano.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Nenhuma | N/A | N/A |

## Phase 0 Output

Pesquisa registrada em [research.md](./research.md), cobrindo dry-run de migrations, bloqueio de seed/dados locais, backup/snapshot, deploy de Edge Function, secrets de producao, smoke test com usuarios temporarios, troca de `.env.local` e documentacao obrigatoria.

## Phase 1 Output

- Modelo operacional: [data-model.md](./data-model.md)
- Gate de promocao: [contracts/promotion-gates.md](./contracts/promotion-gates.md)
- Smoke test remoto: [contracts/smoke-test.md](./contracts/smoke-test.md)
- Troca de `.env.local`: [contracts/env-local-switch.md](./contracts/env-local-switch.md)
- Recuperacao e documentacao: [contracts/documentation-and-recovery.md](./contracts/documentation-and-recovery.md)
- Quickstart operacional: [quickstart.md](./quickstart.md)

## Phase 2 Direction

`/speckit-tasks` deve gerar tarefas executaveis e ordenadas para:

1. Confirmar autenticacao CLI e destino `lpwnaxlczwntylcmgotm` sem mutar producao.
2. Confirmar backup/snapshot recuperavel.
3. Validar localmente o estado ja implementado.
4. Rodar `migration list` e `db push --dry-run`, capturar saida e parar para aprovacao manual.
5. Aplicar migrations sem seed/dados locais apenas apos aprovacao.
6. Deployar `relatorios-exportacao` e verificar secrets.
7. Criar usuarios temporarios de smoke test, validar autorizado e nao autorizado, e limpar/desativar usuarios.
8. Atualizar `.env.local` somente apos smoke test completo aprovado.
9. Rodar validacao local contra producao e registrar a mutacao em `.agents` e `.sauron`.
