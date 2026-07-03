# Contract: Padrão de Guardrails

Define o padrão que toda função de banco deve cumprir e que `scripts/audit-rpc.mjs` valida (FR-012). É o critério objetivo de aprovação/reprovação no CI.

## Padrão canônico para RPC de domínio

```sql
CREATE OR REPLACE FUNCTION public.<nome>(<args>)
RETURNS <tipo>
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public          -- guardrail 1: escopo de busca fixo
AS $$
BEGIN
  IF auth.uid() IS NULL THEN       -- guardrail 2: guarda de identidade explícita
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (                  -- guardrail 3: RBAC do módulo (só domínio)
    SELECT 1 FROM public.permissao_modulo('<modulo>') WHERE pode_ler = true  -- ou pode_escrever
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- ... lógica ...
END;
$$;

REVOKE EXECUTE ON FUNCTION public.<nome>(<args>) FROM PUBLIC;   -- guardrail 4
GRANT  EXECUTE ON FUNCTION public.<nome>(<args>) TO authenticated;  -- guardrail 5
```

## Erros canônicos (para testes estáveis)

| Situação | Erro | ERRCODE |
|----------|------|---------|
| Chamador anônimo (sem sessão) | `Unauthorized` | `42501` |
| Autenticado sem permissão de módulo | `Forbidden` | `42501` |

O texto e o ERRCODE padronizados permitem que o teste guiado por catálogo (FR-016) case o resultado sem depender da assinatura de cada função.

## Regras do verificador `audit-rpc.mjs`

Para cada função `CREATE [OR REPLACE] FUNCTION public.<nome>` nas migrations, resolvendo a **última** definição (ordem cronológica dos arquivos):

| Verificação | Aplica a | Falha se |
|-------------|----------|----------|
| `SECURITY DEFINER` presente | todas as RPCs de dados | ausente |
| `SET search_path` presente | todas (inclui triggers) | ausente |
| `permissao_modulo(...)` no corpo | funções de domínio | ausente |
| `auth.uid()` / `existe_perfil_admin` no corpo | todas exceto whitelist | ausente |
| `REVOKE ... FROM PUBLIC` | todas as RPCs | ausente |
| `GRANT ... TO authenticated` (ou `anon` p/ auditoria) | todas as RPCs | ausente |

**Allowlists do verificador**:
- Funções de trigger (`RETURNS trigger`): exigem apenas `SECURITY DEFINER` + `search_path` (não têm grants nem RBAC de módulo).
- `registrar_evento_auditoria`: `GRANT` inclui `anon`; RBAC de módulo não se aplica; guarda é condicional (whitelist).
- Helpers de permissão/perfil (`permissao_modulo`, `obter_permissoes_usuario`, `obter_perfil_usuario`, `existe_perfil_admin`): não exigem `permissao_modulo` no corpo (são a base do RBAC), mas exigem os demais guardrails.
- `atualizar_usuario_perfil`: admin-only por design (FR-005), guardado por `existe_perfil_admin` em vez de `permissao_modulo` — não exige o guard de módulo, mas exige os demais guardrails.

**Saída**: código de saída ≠ 0 e relatório tabular das funções fora do padrão. Em verde, imprime contagem total conforme (meta: 80/80, SC-003 — 81 auditadas menos `criar_perfil_teste` removida).

**Tratamento de `DROP FUNCTION`**: ao resolver a "última definição" de cada função, o verificador MUST honrar `DROP FUNCTION [IF EXISTS] public.<nome>(...)` como remoção — uma função cuja última operação nas migrations é um `DROP` é **excluída** da contagem e das checagens. Sem isso, `criar_perfil_teste` (cujo último `CREATE` ainda vive na migration base) seria contada e reprovaria o padrão, dando 81 em vez de 80.
