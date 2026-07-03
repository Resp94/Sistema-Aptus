# Contract: Assinaturas de RPC afetadas

Documenta as assinaturas antes/depois das funções alteradas. Só a função de auditoria muda de assinatura (impacta cliente); as demais preservam assinatura (Fase 1).

## `registrar_evento_auditoria` — ASSINATURA ALTERADA (FR-003, FR-003a, FR-003b)

**Antes**:

```text
registrar_evento_auditoria(p_evento text, p_usuario_id uuid, p_ip_origem text, p_user_agent text) RETURNS uuid
-- SECURITY DEFINER, sem search_path, sem REVOKE/GRANT, sem checagem de identidade
```

**Depois**:

```text
registrar_evento_auditoria(p_evento text, p_ip_origem text, p_user_agent text) RETURNS uuid
-- SECURITY DEFINER, SET search_path = public
-- REVOKE EXECUTE FROM PUBLIC; GRANT EXECUTE TO anon, authenticated
```

**Contrato de comportamento**:

| Condição | Resultado |
|----------|-----------|
| `auth.uid()` não nulo | grava `usuario_id = auth.uid()`; retorna id do log |
| `auth.uid()` nulo E `p_evento IN ('login_falha')` | grava `usuario_id = NULL`; retorna id do log |
| `auth.uid()` nulo E `p_evento` fora da whitelist | `RAISE EXCEPTION 'Unauthorized' USING ERRCODE='42501'` |

**Pontos de chamada no cliente a ajustar** (remover o argumento de autor):

| Arquivo | Linha | Evento | Antes | Depois |
|---------|-------|--------|-------|--------|
| `src/services/auth.service.ts` | ~55 | `login_falha` | `{ p_evento, p_usuario_id: null, p_ip_origem, p_user_agent }` | `{ p_evento, p_ip_origem, p_user_agent }` |
| `src/services/auth.service.ts` | ~88 | `login_sucesso` | `{ p_evento, p_usuario_id: data.user.id, ... }` | `{ p_evento, p_ip_origem, p_user_agent }` |
| `src/pages/ResetPassword.tsx` | ~69 | `senha_alterada` | `{ p_evento, p_usuario_id: user.id, ... }` | `{ p_evento, p_ip_origem, p_user_agent }` |

> Observação: `login_sucesso` e `senha_alterada` só ocorrem já autenticados, então o autor gravado (`auth.uid()`) é idêntico ao que era passado — nenhuma mudança de dado observável, só remoção do argumento.

## `criar_perfil_teste` — REMOVIDA de produção (FR-001, FR-002)

```text
DROP FUNCTION IF EXISTS public.criar_perfil_teste(text, text, text, text);
```

Definição realocada para `supabase/seed.sql` (criada → usada nas 6 personas → `DROP` ao fim do script). Não existe em nenhum ambiente publicado.

## `handle_auth_user_sync` — CORRIGIDA, assinatura de trigger inalterada (FR-004, FR-006)

```text
-- SET search_path = public (novo)
-- INSERT INTO perfis: perfil_acesso := 'Visualizador'  (fixo; NÃO lê raw_user_meta_data->>'perfil_acesso')
-- nome/departamento continuam de raw_user_meta_data
```

## `validar_perfil_update` — CORRIGIDA, assinatura de trigger inalterada (FR-007a)

```text
-- SET search_path = public (novo)
-- Mantém SET row_security = off e a guarda "IF auth.uid() IS NULL THEN RETURN new"
--   (contexto de sistema/seed precisa dela; ver research.md item 5)
-- Sem grants (função de trigger, não invocável diretamente)
```

## `existe_perfil_admin(uuid)` — ENDURECIDA, assinatura inalterada (FR-007)

```text
-- SET search_path = public (novo)
-- REVOKE EXECUTE ON FUNCTION public.existe_perfil_admin(uuid) FROM PUBLIC;
-- GRANT EXECUTE ON FUNCTION public.existe_perfil_admin(uuid) TO authenticated;
```

## 26 funções legadas — PADRONIZADAS, assinatura e comportamento preservados (FR-008..FR-011)

Para **cada** função abaixo: `CREATE OR REPLACE` idêntico + `SET search_path = public` + guarda `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE='42501'; END IF;` no topo + `REVOKE EXECUTE ... FROM PUBLIC` + `GRANT EXECUTE ... TO authenticated`.

**Domínio (23)**: `listar_clientes`, `criar_cliente`, `atualizar_cliente`, `inativar_cliente`, `registrar_atendimento`, `criar_projeto`, `atualizar_projeto`, `excluir_projeto`, `criar_tarefa`, `atualizar_tarefa`, `mover_tarefa`, `excluir_tarefa`, `listar_projetos`, `listar_tarefas_kanban`, `obter_metricas_dashboard`, `obter_fluxo_caixa_mensal`, `obter_composicao_receita`, `listar_ultimos_lancamentos`, `listar_contas_pagar_proximas`, `obter_cliente_detalhe`, `obter_estatisticas_clientes`, `obter_resumo_projetos`, `obter_distribuicao_clientes`.

**Helpers de permissão/perfil (3)**: `permissao_modulo`, `obter_permissoes_usuario`, `obter_perfil_usuario` (mantêm `SET row_security = off` já existente; recebem guarda + grants + search_path).

**Invariante**: assinatura, tipo de retorno e resultado para chamador autorizado idênticos ao estado anterior (SC-008). A única diferença observável é: anônimo agora recebe erro explícito `Unauthorized` em vez de resultado vazio silencioso.
