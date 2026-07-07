# Triagem Inicial dos Achados

**Projeto remoto**: `lpwnaxlczwntylcmgotm`  
**Data do baseline**: 2026-07-06

**Regra de normalizacao**: cada funcao `SECURITY DEFINER` deve virar uma linha propria por assinatura exata antes do inicio da implementacao. As linhas agrupadas abaixo representam apenas o baseline de planejamento.

| ID | Advisor | Objeto | Lint | Classificacao inicial | Acao planejada | Evidencia base | Resultado final |
|----|---------|--------|------|-----------------------|----------------|----------------|-----------------|
| SEC-001 | `security` | `public.capacidades_perfil` | `rls_enabled_no_policy` | `risco_real` | Adicionar policy coerente ao desenho service-owned e revalidar advisor | Advisor remoto + `20260703000001_rbac_capacidades_foundation.sql` | Em aberto |
| SEC-002 | `security` | Funcoes `SECURITY DEFINER` expostas a `anon` | `anon_security_definer_function_executable` | `risco_real` | Inventariar assinaturas, comparar grants remotos vs. versionados, corrigir grants indevidos e explodir a triagem por assinatura exata | Advisor remoto + migrations de RPCs e exportacao | Em aberto |
| SEC-003 | `security` | Funcoes `SECURITY DEFINER` expostas a `authenticated` | `authenticated_security_definer_function_executable` | `investigar` | Aplicar criterio de dependencia viva por assinatura exata e decidir preservar, endurecer ou remover acesso | Advisor remoto + busca em `src/`, `supabase/functions`, triggers, views e funcoes SQL | Em aberto |
| PERF-001 | `performance` | Policies com `auth.uid()` direto | `auth_rls_initplan` | `risco_real` | Reescrever policies no escopo com `(select auth.uid())` e equivalentes seguros | Advisor remoto + `00000000000000_usuarios_perfis.sql` | Em aberto |
| PERF-002 | `performance` | `public.perfis` | `multiple_permissive_policies` | `risco_real` | Consolidar `SELECT` e `UPDATE` sem regressao de acesso | Advisor remoto + `00000000000000_usuarios_perfis.sql` | Em aberto |
| PERF-OUT-001 | `performance` | FKs sem indice | `unindexed_foreign_keys` | `fora_escopo` | Registrar exclusao da feature 010; avaliar em backlog proprio | Advisor remoto | Fora do escopo |
| PERF-OUT-002 | `performance` | Indices nao usados | `unused_index` | `fora_escopo` | Registrar exclusao da feature 010; avaliar em backlog proprio | Advisor remoto | Fora do escopo |
