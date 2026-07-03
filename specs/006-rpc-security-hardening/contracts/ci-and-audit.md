# Contract: Scripts de Auditoria e Pipeline de CI

## Scripts de auditoria estática (`scripts/`)

### `audit-rpc.mjs` (FR-012)

- **Entrada**: `supabase/migrations/*.sql`.
- **Saída**: relatório tabular; exit code `0` se todas as funções cumprem o [padrão de guardrails](./guardrail-standard.md), `1` caso contrário.
- **Contrato**: nenhuma função `SECURITY DEFINER` não-trigger pode faltar `search_path`, `REVOKE`, `GRANT` ou guarda de identidade (respeitando as allowlists). Base: protótipo já validado na auditoria de 2026-07-02.

### `check-no-from.mjs` (FR-013)

- **Entrada**: `src/services/**/*.ts`.
- **Contrato**: exit `1` se encontrar `supabase.from(` fora da allowlist. **Allowlist**: `src/services/health-check.ts`.

### `check-no-user-metadata.mjs` (FR-014)

- **Entrada**: `supabase/migrations/**/*.sql` e `src/**/*.{ts,tsx}`.
- **Contrato**: exit `1` se encontrar `raw_user_meta_data` ou `user_metadata` em contexto de autorização (mesma linha/bloco que `perfil`, `role`, `permiss`, `admin`). Uso para `nome`/`departamento` é permitido (não é autorização).
- **Estratégia para evitar heurística frágil (CHK027)**: em vez de confiar apenas na heurística de contexto (sujeita a falso positivo/negativo), o check usa uma **allowlist explícita de ocorrências conhecidas e legítimas** (linha:arquivo) — hoje os acessos a `nome`/`departamento` em `handle_auth_user_sync` e `atualizar_minhas_configuracoes`. Qualquer ocorrência **nova** fora da allowlist reprova o CI e exige revisão humana + inclusão consciente na allowlist. Assim o default é seguro (nega o novo) e a decisão de "é autorização ou não?" é sempre explícita, não inferida.

### Scripts npm (package.json)

```json
{
  "db:test": "npx supabase test db",
  "audit:rpc": "node scripts/audit-rpc.mjs",
  "audit:from": "node scripts/check-no-from.mjs",
  "audit:metadata": "node scripts/check-no-user-metadata.mjs",
  "audit": "npm run audit:rpc && npm run audit:from && npm run audit:metadata"
}
```

## Pipeline de CI — `.github/workflows/ci.yml` (FR-017)

Ordem obrigatória; qualquer falha reprova o merge:

```text
1. checkout + setup-node + npm ci
2. npm run build            # compila TS + Vite
3. npm run test             # Vitest (services do cliente)
4. supabase/setup-cli + supabase db start   # sobe Postgres local com as migrations
5. supabase db lint         # qualidade do schema
6. supabase db advisors     # lints de segurança nativos (distinto de db lint)
7. supabase test db         # suíte pgTAP (6 perfis + auditoria + anti-escalação)
8. npm run audit            # audit-rpc + check-no-from + check-no-user-metadata
```

**Gate de merge**: o workflow roda em `pull_request` para `main` e é marcado como required check. Uma função nova fora do padrão (passo 8) ou um teste de perfil vermelho (passo 7) bloqueia a integração (SC-007).

**Notas de execução**:
- `supabase db advisors` exige CLI ≥ 2.81.3 (runner usa a versão do `setup-cli`); fallback documentado: `get_advisors` via MCP se indisponível no runner.
- `supabase test db` aplica migrations + executa `supabase/tests/*.sql` em ordem alfabética.
