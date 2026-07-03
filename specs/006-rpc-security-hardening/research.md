# Phase 0 Research: Hardening de Segurança das RPCs

Consolidação das decisões técnicas. Cada item resolve uma incógnita do Technical Context.

## 1. Nomes reais dos perfis de acesso

- **Decisão**: A matriz de testes e qualquer referência a perfis usa exatamente os 6 valores existentes no banco: `Administrador`, `Financeiro`, `Projetos`, `Comercial`, `Técnico`, `Visualizador`.
- **Rationale**: A função `obter_permissoes_usuario()` em `00000000000000_usuarios_perfis.sql` ramifica por esses literais (linhas 234–314) e o `seed.sql` cria personas com eles. A spec havia citado "Gestor", que **não existe** no sistema — o perfil equivalente é `Projetos`.
- **Alternativas consideradas**: Introduzir "Gestor" como novo perfil — rejeitado: fora de escopo (novas funcionalidades) e criaria divergência entre teste e realidade.

## 2. Simulação de identidade autenticada em pgTAP

- **Decisão**: Nos testes, materializar a identidade com `SET LOCAL role` + `SET LOCAL request.jwt.claims`, encapsulados em helpers:
  - `set_auth(p_uuid uuid)`: `SET LOCAL role authenticated;` e `SET LOCAL request.jwt.claims = json_build_object('sub', p_uuid, 'role','authenticated')::text;`
  - `set_anon()`: `SET LOCAL role anon;` e `SET LOCAL request.jwt.claims = '{"role":"anon"}';`
  - `reset_auth()`: `RESET role;` `SET LOCAL request.jwt.claims = '';`
- **Rationale**: `auth.uid()` do Supabase resolve `sub` de `request.jwt.claims`; `auth.role()`/RLS por `TO` resolvem o role do Postgres. Definir ambos reproduz fielmente o contexto de um usuário real dentro da transação de teste. `SET LOCAL` garante isolamento por transação pgTAP.
- **Alternativas consideradas**: Criar JWTs reais e autenticar via API — rejeitado: pesado e desnecessário para testes de banco; `supabase test db` roda SQL puro.
- **A verificar na implementação**: confirmar, contra a versão corrente, se o claim `sub` é lido de `request.jwt.claims` (JSON) e/ou de `request.jwt.claim.sub` (legado). O helper define ambos por segurança.

## 3. Teste "anônimo é rejeitado" guiado por catálogo

- **Decisão**: Enumerar dinamicamente as funções-alvo via `pg_proc`:
  - `pronamespace = 'public'::regnamespace`
  - `prosecdef = true` (apenas `SECURITY DEFINER`)
  - excluir funções de gatilho: `prorettype <> 'pg_catalog.trigger'::regtype`
  - excluir a exceção documentada: nome `<> 'registrar_evento_auditoria'`
  - Para cada função, sob `set_anon()`, afirmar que a invocação levanta exceção (não-autorizado). Como as assinaturas variam, a chamada usa argumentos nulos por posição derivados de `pg_get_function_arguments`, e o teste considera sucesso qualquer erro de autorização (`throws_ok` sem casar mensagem exata, ou casando o `SQLSTATE`/texto padronizado da guarda).
- **Rationale**: Guiar pelo catálogo (e não por lista manual) garante que uma função nova criada sem guarda seja automaticamente coberta e reprovada (FR-016). É a rede de segurança contra a regressão que originou a feature.
- **Alternativas consideradas**: Lista manual de funções no teste — rejeitado: a lista desatualiza e reabre a brecha; contradiz FR-016.
- **Nota de padronização da guarda**: para o teste casar de forma estável, todas as funções guardadas devem levantar o mesmo erro canônico de anônimo (ver contrato de guardrails — `RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501'`).

## 4. Função de auditoria: whitelist anônima e autor forçado

- **Decisão**: `registrar_evento_auditoria` recriada com:
  - nova assinatura **sem** `p_usuario_id` (FR-003b): `(p_evento text, p_ip_origem text, p_user_agent text)`;
  - `SECURITY DEFINER` + `SET search_path = public` + `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO anon, authenticated` (anon precisa executar para o whitelist);
  - lógica: se `auth.uid() IS NOT NULL` → grava com `usuario_id = auth.uid()`; senão, se `p_evento` ∈ lista fixa pré-auth (`ARRAY['login_falha']`) → grava com `usuario_id = NULL`; senão → `RAISE EXCEPTION 'Unauthorized'`.
- **Rationale**: Preserva a auditoria de falha de login (evento sem sessão) sem reabrir a falsificação: um autenticado nunca escolhe o autor, e um anônimo só registra eventos pré-auth conhecidos. A remoção do parâmetro torna a falsificação impossível por construção.
- **Alternativas consideradas**: exigir autenticação estrita (perde `login_falha`); manter parâmetro e ignorar (deixa parâmetro morto enganoso). Ambas rejeitadas na clarificação (Session 2026-07-02).
- **Impacto no cliente**: 3 pontos de chamada perdem o argumento de autor:
  - `src/services/auth.service.ts:55` (`login_falha`) e `:88` (`login_sucesso`);
  - `src/pages/ResetPassword.tsx:69` (`senha_alterada`).

## 5. Correção do trigger `handle_auth_user_sync` (anti-escalação)

- **Decisão**: Recriar o trigger com `SET search_path = public` e substituir `coalesce(new.raw_user_meta_data->>'perfil_acesso', 'Visualizador')` por `'Visualizador'` fixo no INSERT do perfil. `nome` e `departamento` continuam vindo de `raw_user_meta_data` (dados do próprio usuário, não autorização). Promoção só via `atualizar_usuario_perfil` (RPC admin já existente).
- **Rationale**: `user_metadata` é editável pelo usuário no cadastro — regra oficial do Supabase proíbe derivar autorização dele. `search_path` fixo elimina o risco de resolução de nome em `SECURITY DEFINER`.
- **Alternativas consideradas**: mover `perfil_acesso` para `raw_app_meta_data` — rejeitado por ora: exigiria fluxo de escrita de app_metadata no cadastro; o default seguro (`Visualizador` + promoção via RPC) resolve o requisito sem nova superfície.
- **Segundo trigger — `validar_perfil_update`** (FR-007a): também `SECURITY DEFINER` sem `search_path` (linha 167 do arquivo base). Entra na mesma migration da Fase 0 apenas para fixar `SET search_path = public`. A guarda `IF auth.uid() IS NULL THEN RETURN new` é **preservada de propósito**: os processos de sincronização (`handle_auth_user_sync`) e o `seed.sql` (que roda como `postgres`, sem sessão) precisam definir perfil/status em contexto de sistema. Sem essa guarda, o seed não conseguiria promover as 6 personas.

## 6. `criar_perfil_teste`: remoção de produção + seed efêmero

- **Decisão**: `DROP FUNCTION public.criar_perfil_teste(text,text,text,text)` na migration da Fase 0. A definição da função é **movida para dentro do `supabase/seed.sql`**: criada no início do bloco de seed, usada para gerar as 6 personas, e removida (`DROP`) ao final do mesmo script.
- **Rationale**: `seed.sql` só roda em `supabase db reset` local — nunca em produção. Assim a função nunca existe num ambiente publicado (FR-001/SC-002) e o fluxo local continua intacto (FR-002). As 6 chamadas atuais em `seed.sql:81-86` permanecem válidas.
- **Alternativas consideradas**: apenas adicionar guarda de admin — rejeitado pelo responsável (decisão: remover). Recriar personas via API no seed — rejeitado: o seed é SQL puro e a função efêmera é o caminho mais simples.

## 7. Padronização das 26 funções legadas (comportamento preservado)

- **Decisão**: `CREATE OR REPLACE` de cada uma das 26 funções acrescentando `SET search_path = public`, precedido/seguido de `REVOKE EXECUTE ... FROM PUBLIC` + `GRANT EXECUTE ... TO authenticated`, e inserindo no topo do corpo a guarda canônica `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE='42501'; END IF;`. Assinaturas e retornos idênticos aos atuais.
- **Rationale**: Alinha ao padrão da geração nova sem mudar contrato (FR-011) — zero mudança no cliente (SC-008). A guarda explícita substitui o bloqueio indireto (hoje `permissao_modulo()` retorna vazio) por um erro claro e testável.
- **Escopo exato (26)**: 23 funções do batch `20260628*` (clientes, projetos, tarefas, dashboard) + 3 helpers base (`permissao_modulo`, `obter_permissoes_usuario`, `obter_perfil_usuario`). `existe_perfil_admin` e `registrar_evento_auditoria` são tratadas na Fase 0; `criar_perfil_teste` é removida.
- **Cuidado**: `permissao_modulo`/`obter_permissoes_usuario` são chamadas dentro de outras `SECURITY DEFINER` e por políticas RLS. `auth.uid()` continua resolvendo o chamador original mesmo dentro de `SECURITY DEFINER`, então a guarda é segura nesses contextos. Manter o `SET row_security = off` já existente nessas funções.

## 8. Scripts de auditoria estática

- **Decisão**: 3 scripts Node ESM em `scripts/`, executáveis via `npm run` e no CI:
  - `audit-rpc.mjs`: parseia `supabase/migrations/*.sql`, resolve a última definição de cada função e verifica os 5 guardrails; sai com código ≠ 0 se alguma função `SECURITY DEFINER` não-trigger estiver fora do padrão (com allowlist para a auditoria). Baseado no protótipo já validado nesta investigação.
  - `check-no-from.mjs`: falha se encontrar `supabase.from(` em `src/services/**`, com allowlist `health-check.ts`.
  - `check-no-user-metadata.mjs`: falha se encontrar `raw_user_meta_data`/`user_metadata` associado a decisão de autorização em migrations e em `src/**` (heurística: uso em contexto de `perfil`/`role`/`permiss`).
- **Rationale**: São a trava anti-regressão (FR-012/013/014). Node ESM porque o projeto já é Node/Vite e não requer dependências novas.
- **Alternativas consideradas**: regra ESLint custom para `check-no-from` — viável, mas um script único cobre SQL + TS uniformemente e roda igual no CI.

## 9. Pipeline de CI (GitHub Actions)

- **Decisão**: `.github/workflows/ci.yml` com um job que: faz checkout, instala Node e dependências, roda `npm run build`, `npm run test`, sobe o Supabase local (`supabase/setup-cli` + `supabase db start`), roda `supabase db lint`, `supabase db advisors`, `supabase test db`, e por fim os 3 scripts de auditoria. Qualquer etapa que falhe reprova o merge (FR-017).
- **Rationale**: O repositório é GitHub (`Resp94/Sistema-Aptus`); `db advisors` traz os lints nativos de segurança do Supabase (distintos de `db lint`) e pegaria parte das divergências automaticamente.
- **Alternativas consideradas**: rodar advisors só contra cloud — rejeitado: CI deve ser hermético e local; o container local cobre o schema das migrations.
- **A verificar na implementação**: disponibilidade de `supabase db advisors` na versão da CLI usada no runner (CLI local é 2.109.0; requisito mínimo 2.81.3 — OK). Se indisponível no runner, usar `get_advisors` via MCP como fallback documentado.

## 11. Segurança das migrations e do seed (idempotência/rollback)

- **Decisão**: As migrations corretivas são seguras por construção, sem necessidade de requisito adicional: (a) toda função é recriada com `CREATE OR REPLACE` e a remoção usa `DROP FUNCTION IF EXISTS`, o que as torna reexecutáveis sem erro; (b) DDL no PostgreSQL é transacional — se qualquer comando da migration falhar, a migration inteira reverte atomicamente, então não há estado parcial (endereça a preocupação de rollback da Fase 1); (c) no `seed.sql`, o `DROP` da função efêmera de criação de perfil deve ser garantido ao final do bloco (executar sempre, mesmo após erro) para não deixar a função residual em caso de falha do reset local.
- **Rationale**: Migrations do Supabase são aplicadas uma única vez e rastreadas; a combinação `CREATE OR REPLACE`/`DROP IF EXISTS` + transacionalidade do DDL cobre idempotência e falha parcial sem inventar mecanismo novo.

## 10. Documento de diretrizes arquiteturais

- **Decisão**: `docs/arquitetura-dados.md` registra: (a) RPC granular como regra para leitura e escrita; (b) agregadora por página **descartada do caminho crítico**, permitida só por latência medida (Dashboard como único candidato); (c) views apenas como read models internos `security_invoker = true`, nunca chamadas pelo frontend; (d) RLS por operação como defesa em profundidade, com as armadilhas: `UPDATE` exige `USING` **e** `WITH CHECK`, e `UPDATE` exige política de `SELECT` correspondente.
- **Rationale**: Evita retomar a proposta já avaliada e negada, e preserva o racional para decisões futuras (FR-018..FR-020).
