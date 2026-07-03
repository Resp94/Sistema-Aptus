# Quickstart: Validação do Hardening de Segurança

Roteiro para provar, ponta a ponta, que as brechas foram fechadas e o padrão trava regressões. Detalhes de implementação ficam em `tasks.md`; aqui só o que rodar e o resultado esperado.

## Pré-requisitos

- Supabase local operante (`npm run supabase:start`); portas conforme `.env.local`.
- Node/deps instalados (`npm ci`).
- CLI Supabase ≥ 2.81.3 (`npx supabase --version`).

## Passo 1 — Reset com as novas migrations e seed

```bash
npm run supabase:reset
```

**Esperado**: reset conclui sem erro; as 6 personas (`admin@`, `financeiro@`, `projetos@`, `comercial@`, `tecnico@`, `visualizador@aptusflow.local`) são criadas. Confirma FR-002 (seed efêmero funciona sem `criar_perfil_teste` persistida).

## Passo 2 — `criar_perfil_teste` não existe no banco

```bash
npx supabase db query "SELECT to_regprocedure('public.criar_perfil_teste(text,text,text,text)') IS NULL AS removida;"
```

**Esperado**: `removida = true`. Confirma FR-001 / SC-002.

## Passo 3 — Suíte pgTAP (6 perfis + auditoria + anti-escalação)

```bash
npm run db:test    # npx supabase test db
```

**Esperado**: todos os arquivos verdes:
- `01_anon_rejeitado`: anônimo recebe `Unauthorized` em toda `SECURITY DEFINER` não-trigger, exceto a auditoria (SC-001).
- `02_rbac_por_perfil`: matriz de `(pode_ler, pode_escrever)` correta para os 6 perfis; escrita sem permissão falha (FR-015).
- `03_auditoria`: anônimo grava `login_falha` (autor nulo); anônimo é bloqueado em evento fora da whitelist; autenticado não consegue atribuir evento a terceiro (SC-004).
- `04_signup_sem_escalacao`: cadastro com `raw_user_meta_data->>'perfil_acesso'='Administrador'` resulta em perfil `Visualizador` (SC-005).

## Passo 4 — Auditoria estática de guardrails

```bash
npm run audit
```

**Esperado**:
- `audit:rpc` → `80/80` funções no padrão, exit 0 (SC-003 — 81 auditadas menos `criar_perfil_teste` removida).
- `audit:from` → nenhum `supabase.from(` em `src/services` além de `health-check.ts`, exit 0.
- `audit:metadata` → nenhum uso de `user_metadata` em autorização, exit 0.

## Passo 5 — Prova de regressão (deve reprovar)

Introduzir deliberadamente uma função `SECURITY DEFINER` sem `search_path`/`REVOKE` numa migration de teste e rodar `npm run audit:rpc`.

**Esperado**: exit ≠ 0, apontando a função. Reverter em seguida. Confirma SC-007 (o gate pega a regressão).

## Passo 6 — Lints nativos do Supabase

```bash
npx supabase db lint
npx supabase db advisors
```

**Esperado**: sem findings de segurança nas funções e políticas alteradas.

## Passo 7 — Cliente continua funcionando

```bash
npm run build && npm run test
```

**Esperado**: build e testes verdes. Fluxos de login (sucesso/falha) e redefinição de senha gravam auditoria com a nova assinatura (sem argumento de autor). Confirma FR-003b / SC-008.

## Critérios de aceite consolidados

| Passo | Requisito/Critério |
|-------|--------------------|
| 1 | FR-002 |
| 2 | FR-001, SC-002 |
| 3 | FR-003/003a/003b, FR-004, FR-015, SC-001, SC-004, SC-005, SC-006 |
| 4 | FR-012/013/014, SC-003 |
| 5 | FR-012, SC-007 |
| 6 | FR-017 (etapas de lint/advisors) |
| 7 | FR-003b, SC-008 |
