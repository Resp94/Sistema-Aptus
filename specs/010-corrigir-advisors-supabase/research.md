# Research: Corrigir Advisors Supabase

## Decision 1: Tratar `public.capacidades_perfil` como catalogo service-owned com policy explicita

**Decision**: A tabela `public.capacidades_perfil` deve permanecer sob postura de acesso restrito e ganhar policy explicita coerente com esse desenho, em vez de permanecer com RLS habilitado sem nenhuma policy.

**Rationale**:
- O advisor remoto atual sinaliza `rls_enabled_no_policy` para `public.capacidades_perfil`.
- O SQL versionado em `supabase/migrations/20260703000001_rbac_capacidades_foundation.sql` ja mostra a intencao de restringir a tabela: `ENABLE ROW LEVEL SECURITY`, `REVOKE ALL` de `PUBLIC` e `authenticated`, e `GRANT ALL` apenas a `service_role`.
- Mesmo sem grants amplos para o cliente, a ausencia de policy deixa a intencao incompleta do ponto de vista de conformidade e nao satisfaz a meta da feature.

**Alternatives considered**:
- Manter como esta e aceitar o lint. Rejeitado porque a spec exige policy coerente e triagem explicita.
- Desabilitar RLS. Rejeitado porque a tabela fica em schema exposto e perderia defesa em profundidade.
- Abrir leitura para `authenticated`. Rejeitado porque mudaria o modelo de seguranca sem necessidade funcional.

## Decision 2: Tratar os achados de `SECURITY DEFINER` como problema de grants efetivos e assinaturas, nao como conversao cega para `SECURITY INVOKER`

**Decision**: A correcao principal deve auditar grants efetivos por assinatura exata, identificar overloads ou funcoes remotas residuais e reassertar o estado esperado por migration. Converter funcoes para `SECURITY INVOKER` so entra quando a propria funcao nao depender de privilegios elevados.

**Rationale**:
- O advisor remoto sinaliza `anon_security_definer_function_executable` e `authenticated_security_definer_function_executable` para varias RPCs.
- O SQL versionado ja tenta restringir varias delas. Exemplos:
  - `public.agendar_relatorio(jsonb)` em `supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql`
  - `public.concluir_exportacao_relatorio(...)` e `public.autorizar_download_exportacao_relatorio(uuid)` em `supabase/migrations/20260704235640_exportar_relatorios.sql`
- Como o remoto continua acusando exposicao, o problema mais provavel e drift de grants, assinatura residual, overload antigo ou estado remoto nao alinhado, e nao simplesmente a palavra-chave `SECURITY DEFINER`.

**Alternatives considered**:
- Converter todas as funcoes para `SECURITY INVOKER`. Rejeitado porque varias RPCs existem justamente para encapsular validacao e acesso controlado.
- Aceitar todos os warnings como falso positivo. Rejeitado porque ha pelo menos um grant versionado para `anon` e nao ha evidencia de que todos os warnings sejam intencionais.

## Decision 3: Preservar funcoes privilegiadas apenas quando houver dependencia viva detectavel

**Decision**: Cada funcao privilegiada sinalizada deve ser classificada por dependencia viva. Funcoes referenciadas pelo frontend, Edge Functions ou outros objetos do banco podem ser preservadas com grants e guardas corretos; funcoes sem dependencia viva detectavel devem ser corrigidas ou removidas do caminho publico.

**Rationale**:
- A spec 010 define dependencia viva como criterio formal para preservar funcoes `SECURITY DEFINER`.
- O repositório tem tres superficies relevantes de uso: `src/services/`, `src/lib/` e `supabase/functions/`.
- O banco tambem pode depender de funcoes via triggers, outras funcoes ou views.

**Alternatives considered**:
- Preservar todas por precaucao. Rejeitado porque perpetua superficie de ataque.
- Remover todas por simplificacao. Rejeitado porque pode quebrar rotas e fluxos reais.

## Decision 4: Corrigir `auth_rls_initplan` com padrao `(select auth.uid())` e equivalentes em helpers

**Decision**: Policies no escopo da feature devem ser reescritas para usar `(select auth.uid())` e, quando aplicavel, helpers com o `auth.uid()` encapsulado uma unica vez por consulta.

**Rationale**:
- O advisor remoto atual sinaliza `auth_rls_initplan` em `public.usuarios`, `public.perfis`, `public.audit_log`, `public.membros_equipe`, `public.alocacoes_equipe`, `public.apontamentos_horas`, `public.configuracoes_empresa` e `public.preferencias_notificacoes`.
- O SQL base em `supabase/migrations/00000000000000_usuarios_perfis.sql` usa `auth.uid()` diretamente em policies antigas.
- A documentacao oficial de RLS do Supabase recomenda chamar `auth.uid()` com `select` para evitar reavaliacao por linha.

**Alternatives considered**:
- Aceitar o warning porque nao e seguranca. Rejeitado porque a feature inclui performance ligada a RLS/RPC.
- Trocar tudo por funcoes customizadas sem selecionar `auth.uid()`. Rejeitado porque adiciona indirecao sem necessidade inicial.

## Decision 5: Consolidar apenas as policies duplicadas relevantes em `public.perfis`

**Decision**: O plano deve consolidar as policies duplicadas de `SELECT` e `UPDATE` em `public.perfis` num formato unificado por acao, preservando semantica e reduzindo `multiple_permissive_policies`.

**Rationale**:
- O advisor remoto atual aponta `multiple_permissive_policies` para `public.perfis` em `SELECT` e `UPDATE`.
- O SQL base tem pares separados como `perfis_select_self` e `perfis_select_admin`, alem de `perfis_update_self` e `perfis_update_admin`.
- Esse caso esta no coracao do RBAC do sistema e entra diretamente no escopo da feature.

**Alternatives considered**:
- Consolidar todas as policies duplicadas do sistema. Rejeitado porque amplia demais o escopo.
- Tratar `public.perfis` como excecao permanente. Rejeitado porque o warning e diretamente ligado ao modelo central de autorizacao.

## Decision 6: Manter FKs sem indice e indices nao usados fora do escopo

**Decision**: `unindexed_foreign_keys` e `unused_index` permanecem explicitamente fora da feature, salvo se um caso demonstrar dependencia direta com os fluxos de RLS/RPC em correção.

**Rationale**:
- A decisao de escopo aprovada para a feature 010 foi seguranca + performance ligada a RLS/RPC, nao tuning geral.
- Os advisors remotos mostram varios casos de FKs sem indice e indices nao usados, mas eles nao sao os principais riscos desta feature.

**Alternatives considered**:
- Corrigir tudo agora. Rejeitado porque mistura hardening com faxina de performance ampla.
- Ignorar sem registrar. Rejeitado porque o plano precisa documentar explicitamente o que fica fora do escopo.

## Decision 7: Validar remotamente via MCP e classificar persistencias antes de concluir

**Decision**: A conclusao da feature exige rodada remota dos advisors via MCP antes e depois da aplicacao, mais classificacao explicita de qualquer achado remanescente em `triagem.md` e no `runbook-validacao.md`.

**Rationale**:
- O MCP do Supabase ja esta conectado ao projeto `lpwnaxlczwntylcmgotm`.
- A feature nasce de discrepancias entre o SQL versionado e o estado remoto efetivo; por isso, validacao local sozinha nao fecha conformidade.
- O advisor remoto atual continua acusando `anon` em funcoes cujo SQL versionado ja faz `REVOKE ... FROM PUBLIC` e `GRANT ... TO authenticated`, o que reforca a necessidade de validar o estado real.

**Alternatives considered**:
- Concluir pela leitura do repositório apenas. Rejeitado porque nao detecta drift remoto.
- Depender de validacao manual fora do repositório. Rejeitado porque a feature exige repetibilidade e auditabilidade.
