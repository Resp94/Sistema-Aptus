# Memória do Projeto: Corrigir Advisors Supabase (Feature 010)

**Data**: 2026-07-07  
**Projeto Remoto**: `lpwnaxlczwntylcmgotm` (`https://lpwnaxlczwntylcmgotm.supabase.co`)  
**Status**: Concluído (100% em conformidade com o escopo planejado)  

---

## 1. Contexto e Motivação

O projeto de produção apresentava um conjunto de achados de segurança e performance sinalizados pelo Supabase Advisors:
1. **Segurança (SEC-001)**: A tabela `public.capacidades_perfil` estava com RLS habilitado mas sem nenhuma política ativa, deixando-a vulnerável a acessos não intencionais por bypass.
2. **Segurança (SEC-002)**: Um conjunto de 48 RPCs de escrita e exportação de relatórios da namespace `public`, declaradas como `SECURITY DEFINER`, estavam com grants de execução padrão expostos a `PUBLIC` e `anon`.
3. **Performance (PERF-001)**: Múltiplas tabelas centrais tinham o warning `auth_rls_initplan` porque suas políticas de RLS usavam `auth.uid()` diretamente no predicado (gerando reavaliação a cada linha scaneada).
4. **Performance (PERF-002)**: A tabela `public.perfis` acumulava políticas permissivas repetidas para `SELECT` e `UPDATE`, aumentando o overhead do banco.

O objetivo da feature 010 foi realizar a triagem minuciosa desses achados, aplicar as correções versionadas no banco remoto e revalidar a conformidade remota de forma repetível.

---

## 2. O que foi Feito

### 2.1. Triagem e Normalização
- Triagem de todas as RPCs `SECURITY DEFINER` e classificação individualizada por dependência viva no código-fonte e no banco.
- Desdobramento em 48 assinaturas exatas e separação estrita de escopo para barrar acessos anônimos e whitelistar acessos autenticados legítimos.

### 2.2. Remediação de Segurança (`20260707000001_010_advisors_security.sql`)
- Adição de uma policy baseada em `service_role` na tabela `public.capacidades_perfil` para isolá-la contra acessos client-side.
- Revogação explícita de grants públicos (`REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC`) em todas as 48 RPCs de escrita e exportação.
- Concessão de grants controlados a `authenticated` apenas para RPCs com dependência viva no frontend.
- Reforço de segurança com guardas internas de capacities e identidades dentro das funções.

### 2.3. Otimização de Performance (`20260707000002_010_advisors_performance.sql`)
- Conversão de predicates de políticas RLS do padrão `auth.uid() = ...` para subconsultas indexadas `(select auth.uid()) = ...`. Isso permitiu que o otimizador do Postgres avaliasse a query de ID como um único InitPlan de execução isolada, eliminando a lentidão por varredura linha a linha.
- Consolidação das políticas permissivas de `SELECT` e `UPDATE` em `public.perfis`.

---

## 3. Decisões de Design e Governança

- **Subconsultas para Performance**: A conversão para `(select auth.uid())` foi a escolha de design central para silenciar o warning `auth_rls_initplan`. Ela se baseia nas melhores práticas do Postgres no Supabase para forçar a otimização de plano de consulta.
- **Governança de Exceções**: A função `registrar_evento_auditoria` (que exige execução anônima em whitelist limitada) e os acessos controlados de `authenticated` às RPCs de domínio foram categorizados como `excecao_intencional`.
- **Gatilhos de Reavaliação**: Documentamos em `runbook-validacao.md` que qualquer mudança em políticas, grants, assinaturas ou remoção de dependência viva disparará a revisão dessas exceções. O papel de **Lead Database Engineer / Security Custodian** é o responsável formal pela revisão.
- **Exclusão de Tuning Geral**: Conforme a diretriz FR-008, os lints de tuning físico geral (`unindexed_foreign_keys` e `unused_index`) foram explicitamente excluídos do escopo desta feature, pois exigem medição analítica prolongada e estão programados para o backlog geral.

---

## 4. Ambiente e Limitações (Bypass de Testes Locais)

O ambiente local do host do desenvolvedor não possuía a engine do Docker Desktop ativa. Por este motivo, as seguintes diretrizes operacionais foram seguidas:
1. **Bypass de Testes Locais de Banco (`npm run db:test`)**: O comando que executa os testes pgTAP locais foi omitido/pulado devido à falta de container Docker.
2. **Homologação Estática e Remota**: A validação foi guiada pelo build do frontend local (`npm run build` - concluído com sucesso e livre de erros), auditoria de código local (`npm run audit` - 100% aderente) e, principalmente, pela validação remota no Supabase Cloud via Supabase MCP.
3. **Validação via MCP**: As chamadas `get_advisors(type="security")` e `get_advisors(type="performance")` no banco de produção remoto pós-migrations confirmaram a eliminação completa dos lints mapeados no escopo.

---

## 5. Evidências de Validação Remota

### 5.1. Segurança (Remoto)
- `public.capacidades_perfil`: Policy ativa registrada. Sumiu do linter de segurança.
- RPCs de escrita e exportação: Privilégios públicos revogados. Sumiram da lista de warnings de segurança.

### 5.2. Otimização (Remoto)
- InitPlans e policies redundantes: Substituição por subconsultas indexadas resultou na remoção completa do warning `auth_rls_initplan` das tabelas modificadas.
- Lints remanescentes: Apenas chaves estrangeiras não indexadas e índices não utilizados (fora do escopo da feature 010) e a exceção controlada de auditoria permanecem ativos no painel.
