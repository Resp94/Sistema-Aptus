-- Feature 007 (RBAC por Capacidades Nomeadas): matriz de capacidades nomeadas.
-- Cobre T010, T011, T012, T013, T026-T031, T042, T061, T069.
--
-- IMPORTANTE (TDD): no momento em que este arquivo foi escrito, a migration
-- supabase/migrations/20260703000001_rbac_capacidades_foundation.sql (tabela
-- capacidades_perfil, tem_capacidade(), obter_capacidades_usuario(), seed da
-- matriz) já existe, mas supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql
-- (guardas de tem_capacidade(...) dentro das RPCs de escrita/efeito) ainda é um
-- placeholder vazio. Portanto é esperado que várias assertions abaixo (sobretudo
-- as de ownership do Técnico e as do mapeamento de RPCs em T069) falhem até essa
-- segunda migration ser implementada — isso é o comportamento desejado de um
-- teste escrito antes da implementação.
--
-- Convenções seguidas (ver supabase/tests/000_helpers.sql, 01_anon_rejeitado.sql,
-- 02_rbac_por_perfil.sql, 03_auditoria.sql):
--   - set_auth_by_email(email) autentica como a persona de teste.
--   - set_anon() simula um chamador anônimo (role 'anon').
--   - reset_auth() volta para o role padrão (necessário antes de qualquer leitura
--     direta de tabela protegida por RLS, já que os helpers trocam de role).
--   - throws_ok(sql, '42501') (forma de 2 argumentos) checa apenas o SQLSTATE
--     42501, que é o contrato objetivo de contracts/rpc-capability-contract.md
--     para os RAISE EXCEPTION 'Unauthorized'/'Forbidden'. A forma de 3
--     argumentos throws_ok(sql, code, message) desta instalação do pgTAP exige
--     que "message" bata com o texto EXATO da exceção (não é uma descrição
--     livre) — por isso este arquivo usa a forma de 2 argumentos e documenta a
--     intenção de cada assertion em um comentário logo acima da chamada.

SELECT * FROM no_plan();


-- ============================================================
-- 1. Catálogo completo de capacidades (T010, T011 parte 1)
-- ============================================================
-- Fonte canônica: specs/007-rbac-capacidades-nomeadas/data-model.md
-- ("Catálogo inicial") e contracts/capability-matrix.md. Esta lista é
-- espelhada por supabase/migrations/20260703000001_rbac_capacidades_foundation.sql
-- (comentário "Catalogo canonico (37 capacidades...)"). Qualquer capacidade
-- usada em capacidades_perfil que não pertença a esta lista reprova o teste.

CREATE TEMP TABLE _catalogo_capacidades (capacidade text PRIMARY KEY);

-- bag_eq() na seção 4 roda com role 'authenticated' (dentro de set_auth_by_email);
-- sem este GRANT explícito a leitura desta tabela temporária falharia com
-- "permission denied for table _catalogo_capacidades" quando comparada a
-- obter_capacidades_usuario() de cada persona autenticada.
GRANT SELECT ON _catalogo_capacidades TO authenticated;

INSERT INTO _catalogo_capacidades (capacidade) VALUES
  ('clientes.criar'),
  ('clientes.editar'),
  ('clientes.inativar'),
  ('clientes.reativar'),
  ('clientes.registrar_atendimento'),
  ('propostas.criar'),
  ('propostas.editar'),
  ('propostas.enviar'),
  ('propostas.gerar_contrato'),
  ('contratos.criar'),
  ('contratos.renovar'),
  ('contratos.encerrar'),
  ('cobrancas.emitir'),
  ('cobrancas.boleto'),
  ('cobrancas.notificar'),
  ('cobrancas.baixar'),
  ('projetos.criar'),
  ('projetos.editar'),
  ('projetos.excluir'),
  ('tarefas.criar'),
  ('tarefas.excluir'),
  ('tarefas.editar_qualquer'),
  ('tarefas.mover_qualquer'),
  ('tarefas.editar_propria'),
  ('tarefas.mover_propria'),
  ('equipe.adicionar_membro'),
  ('equipe.alocar'),
  ('equipe.inativar_membro'),
  ('apontamentos.registrar_proprio'),
  ('apontamentos.registrar_qualquer'),
  ('financeiro.lancar'),
  ('financeiro.editar_lancamento'),
  ('financeiro.baixar_lancamento'),
  ('configuracoes.gerenciar_usuarios'),
  ('configuracoes.editar_empresa'),
  ('configuracoes.editar_proprio_perfil'),
  ('relatorios.exportar');

SELECT is(
  (SELECT count(*)::int FROM _catalogo_capacidades),
  37,
  'catálogo canônico de referência do teste (data-model.md) tem 37 capacidades'
);

-- Formato recurso.acao (data-model.md: "Deve seguir ^[a-z0-9_-]+\.[a-z0-9_-]+$").
SELECT is(
  (SELECT count(*)::int FROM _catalogo_capacidades WHERE capacidade !~ '^[a-z0-9_-]+\.[a-z0-9_-]+$'),
  0,
  'todas as capacidades do catálogo seguem o formato recurso.acao'
);

-- Nenhuma linha em capacidades_perfil pode referenciar uma capacidade fora do catálogo.
-- Consulta direta à tabela: precisa do role padrão (capacidades_perfil não tem GRANT
-- para authenticated/anon), por isso reset_auth() garante que nenhuma troca de role
-- anterior atrapalhe esta leitura.
SELECT reset_auth();

SELECT is(
  (SELECT count(*)::int
   FROM public.capacidades_perfil cp
   WHERE NOT EXISTS (SELECT 1 FROM _catalogo_capacidades c WHERE c.capacidade = cp.capacidade)),
  0,
  'nenhuma capacidade em capacidades_perfil está fora do catálogo de 37'
);


-- ============================================================
-- 2. Matriz exata por perfil em public.capacidades_perfil (T010, T011 parte 2)
-- ============================================================
-- Fonte: contracts/capability-matrix.md ("Matriz Esperada"). Comparação por
-- bag_eq (multiset, independente de ordem) diretamente na tabela canônica.

SELECT bag_eq(
  $$SELECT capacidade FROM public.capacidades_perfil WHERE perfil_acesso = 'Administrador'$$,
  $$SELECT capacidade FROM _catalogo_capacidades$$,
  'Administrador possui exatamente a totalidade das 37 capacidades do catálogo'
);

SELECT is(
  (SELECT count(*)::int FROM public.capacidades_perfil WHERE perfil_acesso = 'Administrador'),
  37,
  'Administrador: contagem de capacidades = total do catálogo (37)'
);

SELECT bag_eq(
  $$SELECT capacidade FROM public.capacidades_perfil WHERE perfil_acesso = 'Financeiro'$$,
  $$VALUES
    ('financeiro.lancar'),
    ('financeiro.editar_lancamento'),
    ('financeiro.baixar_lancamento'),
    ('cobrancas.emitir'),
    ('cobrancas.baixar'),
    ('relatorios.exportar'),
    ('configuracoes.editar_proprio_perfil')$$,
  'Financeiro possui exatamente as 7 capacidades esperadas'
);

SELECT ok(
  NOT EXISTS (SELECT 1 FROM public.capacidades_perfil WHERE perfil_acesso = 'Financeiro' AND capacidade = 'cobrancas.boleto'),
  'Financeiro não possui cobrancas.boleto'
);

SELECT ok(
  NOT EXISTS (SELECT 1 FROM public.capacidades_perfil WHERE perfil_acesso = 'Financeiro' AND capacidade = 'cobrancas.notificar'),
  'Financeiro não possui cobrancas.notificar'
);

SELECT bag_eq(
  $$SELECT capacidade FROM public.capacidades_perfil WHERE perfil_acesso = 'Projetos'$$,
  $$VALUES
    ('projetos.criar'),
    ('projetos.editar'),
    ('projetos.excluir'),
    ('tarefas.criar'),
    ('tarefas.excluir'),
    ('tarefas.editar_qualquer'),
    ('tarefas.mover_qualquer'),
    ('equipe.adicionar_membro'),
    ('equipe.alocar'),
    ('equipe.inativar_membro'),
    ('apontamentos.registrar_qualquer'),
    ('relatorios.exportar'),
    ('configuracoes.editar_proprio_perfil')$$,
  'Projetos possui exatamente as 13 capacidades esperadas'
);

SELECT bag_eq(
  $$SELECT capacidade FROM public.capacidades_perfil WHERE perfil_acesso = 'Comercial'$$,
  $$VALUES
    ('clientes.criar'),
    ('clientes.editar'),
    ('clientes.inativar'),
    ('clientes.reativar'),
    ('clientes.registrar_atendimento'),
    ('propostas.criar'),
    ('propostas.editar'),
    ('propostas.enviar'),
    ('propostas.gerar_contrato'),
    ('contratos.criar'),
    ('contratos.renovar'),
    ('contratos.encerrar'),
    ('cobrancas.emitir'),
    ('cobrancas.boleto'),
    ('cobrancas.notificar'),
    ('configuracoes.editar_proprio_perfil')$$,
  'Comercial possui exatamente as 16 capacidades esperadas'
);

SELECT ok(
  NOT EXISTS (SELECT 1 FROM public.capacidades_perfil WHERE perfil_acesso = 'Comercial' AND capacidade = 'cobrancas.baixar'),
  'Comercial não possui cobrancas.baixar'
);

SELECT bag_eq(
  $$SELECT capacidade FROM public.capacidades_perfil WHERE perfil_acesso = 'Técnico'$$,
  $$VALUES
    ('tarefas.editar_propria'),
    ('tarefas.mover_propria'),
    ('apontamentos.registrar_proprio'),
    ('configuracoes.editar_proprio_perfil')$$,
  'Técnico possui exatamente as 4 capacidades esperadas'
);

SELECT is(
  (SELECT count(*)::int FROM public.capacidades_perfil WHERE perfil_acesso = 'Técnico'),
  4,
  'Técnico: contagem de capacidades = 4'
);

SELECT is(
  (SELECT count(*)::int FROM public.capacidades_perfil WHERE perfil_acesso = 'Visualizador'),
  0,
  'Visualizador: contagem de capacidades = 0'
);


-- ============================================================
-- 3. public.tem_capacidade(p_capacidade text) (T012)
-- ============================================================

-- 3a. Chamador anônimo: bloqueado na camada de GRANT do Postgres (a função só
-- tem GRANT EXECUTE para authenticated), que é a forma como um anônimo de fato
-- alcança esta função em produção. Resultado observável equivalente a "false":
-- a chamada nunca chega a produzir um capacidade=true.
SELECT set_anon();

SELECT throws_ok(
  $$SELECT public.tem_capacidade('clientes.criar')$$,
  '42501'
); -- tem_capacidade rejeita chamador anônimo (sem GRANT) com 42501

-- 3b. Sessão authenticated sem "sub" no JWT (auth.uid() IS NULL): exercita
-- diretamente o branch interno "retorna false para chamador anônimo/sem sessão"
-- descrito em contracts/rpc-capability-contract.md.
SELECT reset_auth();
SET role = 'authenticated';
SET "request.jwt.claims" = '{"role":"authenticated"}';

SELECT ok(
  NOT public.tem_capacidade('clientes.criar'),
  'tem_capacidade retorna false quando auth.uid() é null (authenticated sem sub)'
);

SELECT reset_auth();

-- 3c. Perfil autenticado: true para capacidade que possui, false para uma que não possui.
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT ok(
  public.tem_capacidade('tarefas.editar_propria'),
  'tem_capacidade retorna true para capacidade que o perfil possui (Técnico / tarefas.editar_propria)'
);

SELECT ok(
  NOT public.tem_capacidade('projetos.criar'),
  'tem_capacidade retorna false para capacidade que o perfil não possui (Técnico / projetos.criar)'
);

SELECT reset_auth();


-- ============================================================
-- 4. public.obter_capacidades_usuario() (T013)
-- ============================================================
-- Contrato: lista ORDENADA (ascendente) das capacidades do perfil ativo.

SELECT set_auth_by_email('admin@aptusflow.local');

SELECT bag_eq(
  $$SELECT unnest(public.obter_capacidades_usuario())$$,
  $$SELECT capacidade FROM _catalogo_capacidades$$,
  'obter_capacidades_usuario() do Administrador contém exatamente o catálogo completo'
);

SELECT ok(
  (SELECT public.obter_capacidades_usuario()) =
  (SELECT array_agg(x ORDER BY x) FROM unnest(public.obter_capacidades_usuario()) x),
  'obter_capacidades_usuario() do Administrador está ordenado ascendentemente'
);

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT is(
  public.obter_capacidades_usuario(),
  ARRAY[
    'cobrancas.baixar',
    'cobrancas.emitir',
    'configuracoes.editar_proprio_perfil',
    'financeiro.baixar_lancamento',
    'financeiro.editar_lancamento',
    'financeiro.lancar',
    'relatorios.exportar'
  ]::text[],
  'obter_capacidades_usuario() do Financeiro é a lista ordenada esperada'
);

SELECT reset_auth();
SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT is(
  public.obter_capacidades_usuario(),
  ARRAY[
    'apontamentos.registrar_qualquer',
    'configuracoes.editar_proprio_perfil',
    'equipe.adicionar_membro',
    'equipe.alocar',
    'equipe.inativar_membro',
    'projetos.criar',
    'projetos.editar',
    'projetos.excluir',
    'relatorios.exportar',
    'tarefas.criar',
    'tarefas.editar_qualquer',
    'tarefas.excluir',
    'tarefas.mover_qualquer'
  ]::text[],
  'obter_capacidades_usuario() de Projetos é a lista ordenada esperada'
);

SELECT reset_auth();
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT is(
  public.obter_capacidades_usuario(),
  ARRAY[
    'clientes.criar',
    'clientes.editar',
    'clientes.inativar',
    'clientes.reativar',
    'clientes.registrar_atendimento',
    'cobrancas.boleto',
    'cobrancas.emitir',
    'cobrancas.notificar',
    'configuracoes.editar_proprio_perfil',
    'contratos.criar',
    'contratos.encerrar',
    'contratos.renovar',
    'propostas.criar',
    'propostas.editar',
    'propostas.enviar',
    'propostas.gerar_contrato'
  ]::text[],
  'obter_capacidades_usuario() do Comercial é a lista ordenada esperada'
);

SELECT reset_auth();
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT is(
  public.obter_capacidades_usuario(),
  ARRAY[
    'apontamentos.registrar_proprio',
    'configuracoes.editar_proprio_perfil',
    'tarefas.editar_propria',
    'tarefas.mover_propria'
  ]::text[],
  'obter_capacidades_usuario() do Técnico é a lista ordenada esperada (4 itens)'
);

SELECT reset_auth();


-- ============================================================
-- 5. Fixture local: usuário Visualizador de teste
-- ============================================================
-- supabase/seed.sql NÃO cria um usuário 'visualizador@aptusflow.local' (esse
-- e-mail só aparece no DELETE de idempotência do seed, nunca em
-- criar_perfil_teste). Como Visualizador deixa de ser persona operacional
-- (US3/T041), criamos aqui um usuário mínimo dedicado a este arquivo,
-- replicando o INSERT em auth.users usado por criar_perfil_teste em
-- supabase/seed.sql. O trigger public.handle_auth_user_sync() cria
-- automaticamente a linha correspondente em public.perfis com
-- perfil_acesso = 'Visualizador' e status = 'Ativo' (comportamento de default
-- de novo cadastro, ver supabase/migrations/20260702000002_security_hardening_fase0.sql).

-- public.usuarios é um espelho de auth.users mantido só por trigger de
-- INSERT/UPDATE (sem ON DELETE CASCADE a partir de auth.users), então rodar
-- este arquivo mais de uma vez contra o mesmo banco (sem `supabase db reset`)
-- deixaria uma linhaórfã em public.usuarios com o mesmo e-mail. Limpa os dois
-- lados explicitamente para a fixture ser idempotente. public.perfis cai em
-- cascata via `usuario_id uuid ... REFERENCES public.usuarios(id) ON DELETE CASCADE`.
DELETE FROM auth.users WHERE email = 'visualizador_teste_005@aptusflow.local';
DELETE FROM public.usuarios WHERE email = 'visualizador_teste_005@aptusflow.local';

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  is_super_admin,
  email_change,
  email_change_token_current,
  phone_change,
  phone_change_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'visualizador_teste_005@aptusflow.local',
  crypt('SenhaDeTesteSegura123!', gen_salt('bf', 10)),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  jsonb_build_object('nome', 'Visualizador Teste 005'),
  now(),
  now(),
  '', '', '', false, '', '', '', ''
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.perfis p
    JOIN auth.users u ON u.id = p.usuario_id
    WHERE u.email = 'visualizador_teste_005@aptusflow.local'
      AND p.perfil_acesso = 'Visualizador'
      AND p.status = 'Ativo'
  ),
  'fixture local: usuário Visualizador de teste criado com perfil Visualizador/Ativo via trigger padrão'
);


-- ============================================================
-- 6. Visualizador como estado técnico mínimo (T042)
-- ============================================================

-- Consulta direta à tabela canônica: precisa do role padrão, já que
-- capacidades_perfil não concede SELECT a authenticated/anon (leitura só via
-- obter_capacidades_usuario()). Executada antes de autenticar como a persona.
SELECT is(
  (SELECT count(*)::int FROM public.capacidades_perfil WHERE perfil_acesso = 'Visualizador'),
  0,
  'Visualizador (estado técnico mínimo): zero capacidades na tabela canônica'
);

SELECT set_auth_by_email('visualizador_teste_005@aptusflow.local');

SELECT is(
  public.obter_capacidades_usuario(),
  ARRAY[]::text[],
  'Visualizador (estado técnico mínimo): obter_capacidades_usuario() retorna lista vazia'
);

-- Leitura restrita a `relatorios` e `configuracoes`; todos os demais módulos
-- devem ser (false, false); nenhuma escrita em módulo algum.
SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', false, false),
    ('clientes', false, false),
    ('propostas', false, false),
    ('contratos', false, false),
    ('cobrancas', false, false),
    ('projetos', false, false),
    ('equipe', false, false),
    ('financeiro', false, false),
    ('fluxo-caixa', false, false),
    ('contas-pagar', false, false),
    ('contas-receber', false, false),
    ('relatorios', true, false),
    ('configuracoes', true, false)$$,
  'Visualizador: leitura restrita a relatorios/configuracoes e nenhuma escrita em módulo algum'
);

SELECT is(
  (SELECT count(*)::int FROM public.obter_permissoes_usuario() WHERE pode_escrever = true),
  0,
  'Visualizador: nenhum módulo com pode_escrever = true'
);

SELECT reset_auth();


-- ============================================================
-- 7. User Story 2 — Técnico: ownership de tarefas e apontamentos (T026-T031)
-- ============================================================

-- --- 7.0 Fixtures locais e IDs pré-resolvidos -------------------------------
-- IMPORTANTE: `clientes`, `projetos`, `tarefas` e `lancamentos` NÃO concedem
-- SELECT direto a authenticated/anon (leitura só via RPC); `propostas`,
-- `contratos`, `cobrancas` e `membros_equipe` concedem SELECT mas com RLS
-- condicionada a permissao_modulo(...).pode_ler, que varia por persona. Um
-- subselect tipo `(SELECT id FROM public.projetos WHERE nome = ...)` embutido
-- como argumento de uma chamada de RPC roda no papel (role) de QUEM CHAMA a
-- consulta externa — ou seja, roda como 'authenticated' depois de
-- set_auth_by_email(...), não "dentro" da função SECURITY DEFINER. Isso
-- causaria "permission denied for table X" ou (pior, silenciosamente) um
-- argumento NULL filtrado por RLS. Por isso todo id necessário abaixo é
-- resolvido AQUI, enquanto o role ainda é o padrão (bypassa RLS/GRANT), e
-- guardado em GUCs de sessão `test.id_*` via set_config(...), lidas depois com
-- current_setting('test.id_*') em qualquer persona — o mesmo mecanismo que
-- request.jwt.claims já usa em 000_helpers.sql para atravessar trocas de role.

-- Tarefa cujo responsavel_id NÃO é o Técnico (para provar isolamento de
-- ownership). tarefas.responsavel_id referencia public.usuarios(id), que é o
-- mesmo id-space de auth.users/auth.uid(); "própria" para o Técnico significa
-- responsavel_id = (usuario_id do Técnico autenticado).
DELETE FROM public.tarefas WHERE titulo = '[FIXTURE 05] Tarefa de outro responsável';

INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, ordem)
VALUES (
  (SELECT id FROM public.projetos WHERE nome = 'Migração de Sistemas'),
  '[FIXTURE 05] Tarefa de outro responsável',
  'A Fazer',
  'Média',
  (SELECT id FROM auth.users WHERE email = 'comercial@aptusflow.local'),
  999
);

-- Alocação ativa de um colega ('Comercial Persona') no MESMO projeto em
-- andamento ('Reestruturação de Infraestrutura') onde o Técnico já está
-- alocado (ver supabase/seed.sql), para provar o caso positivo de
-- "colega com alocação ativa compartilhada" em listar_membros_equipe.
DELETE FROM public.alocacoes_equipe
WHERE membro_equipe_id = (SELECT id FROM public.membros_equipe WHERE nome = 'Comercial Persona')
  AND projeto_id = (SELECT id FROM public.projetos WHERE nome = 'Reestruturação de Infraestrutura');

INSERT INTO public.alocacoes_equipe (membro_equipe_id, projeto_id, data_inicio, data_fim, percentual_alocacao, funcao_no_projeto)
VALUES (
  (SELECT id FROM public.membros_equipe WHERE nome = 'Comercial Persona'),
  (SELECT id FROM public.projetos WHERE nome = 'Reestruturação de Infraestrutura'),
  current_date - 10,
  current_date + 30,
  30,
  'Suporte Comercial'
);
-- Nota: 'Financeiro Persona', 'Projetos Persona', 'Administrador Persona' e
-- 'Carlos Dev' permanecem SEM nenhuma linha em alocacoes_equipe (estado do
-- seed), servindo como fixture de isolamento negativo "sem projeto ativo
-- compartilhado com o Técnico" sem necessidade de INSERT adicional.

-- Dois projetos descartáveis independentes para excluir_projeto: um consumido
-- pelo teste negativo do Técnico (seção 7.1) e outro pela cadeia
-- negativo(Comercial)/positivo(Projetos) de T069 (seção 9.4). Não reaproveitar
-- o mesmo fixture entre as duas seções: como a guarda de capacidade ainda não
-- existe (rpc_guards ainda é placeholder), o Técnico hoje TEM
-- permissao_modulo('projetos').pode_escrever = true e portanto o teste
-- "Técnico não pode excluir_projeto" hoje FALHA e efetivamente apaga a linha —
-- se o mesmo fixture fosse reaproveitado, o teste positivo de "Projetos pode
-- excluir_projeto" em 9.4 quebraria por "Projeto não encontrado", mascarando o
-- resultado esperado. Criados por INSERT direto (não por RPC) enquanto ainda
-- estamos no role padrão, porque INSERT direto em public.projetos exige
-- privilégio de superusuário/dono (a tabela não concede INSERT a
-- authenticated/anon).
DELETE FROM public.projetos WHERE nome IN (
  '[FIXTURE 05] Projeto descartável (excluir_projeto Técnico)',
  '[FIXTURE 05] Projeto descartável (excluir_projeto T069)'
);
INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
VALUES
  ('[FIXTURE 05] Projeto descartável (excluir_projeto Técnico)', NULL, 'Planejamento', 0, 0.00, 0.00, false, current_date + 30, (SELECT id FROM auth.users WHERE email = 'admin@aptusflow.local')),
  ('[FIXTURE 05] Projeto descartável (excluir_projeto T069)', NULL, 'Planejamento', 0, 0.00, 0.00, false, current_date + 30, (SELECT id FROM auth.users WHERE email = 'admin@aptusflow.local'));

-- IDs estáveis (seed + fixtures acima), resolvidos uma única vez.
SELECT set_config('test.id_proj_migracao', (SELECT id::text FROM public.projetos WHERE nome = 'Migração de Sistemas'), false);
SELECT set_config('test.id_proj_infra', (SELECT id::text FROM public.projetos WHERE nome = 'Reestruturação de Infraestrutura'), false);
SELECT set_config('test.id_proj_descartavel_tecnico', (SELECT id::text FROM public.projetos WHERE nome = '[FIXTURE 05] Projeto descartável (excluir_projeto Técnico)'), false);
SELECT set_config('test.id_proj_descartavel_t069', (SELECT id::text FROM public.projetos WHERE nome = '[FIXTURE 05] Projeto descartável (excluir_projeto T069)'), false);
SELECT set_config('test.id_tarefa_outro_resp', (SELECT id::text FROM public.tarefas WHERE titulo = '[FIXTURE 05] Tarefa de outro responsável'), false);
SELECT set_config('test.id_tarefa_propria_1', (SELECT id::text FROM public.tarefas WHERE titulo = 'Migração dos Bancos de Dados'), false);
SELECT set_config('test.id_tarefa_propria_2', (SELECT id::text FROM public.tarefas WHERE titulo = 'Criação do Protótipo de Design'), false);
SELECT set_config('test.id_tarefa_setup', (SELECT id::text FROM public.tarefas WHERE titulo = 'Setup do Ambiente de Testes'), false);
SELECT set_config('test.id_membro_comercial', (SELECT id::text FROM public.membros_equipe WHERE nome = 'Comercial Persona'), false);
SELECT set_config('test.id_membro_tecnico', (SELECT id::text FROM public.membros_equipe WHERE nome = 'Técnico Persona'), false);
SELECT set_config('test.id_user_tecnico', (SELECT id::text FROM auth.users WHERE email = 'tecnico@aptusflow.local'), false);
SELECT set_config('test.id_cliente_techsupplies', (SELECT id::text FROM public.clientes WHERE empresa = 'TechSupplies'), false);
SELECT set_config('test.id_cliente_inovatec', (SELECT id::text FROM public.clientes WHERE empresa = 'Inovatec'), false);
SELECT set_config('test.id_cliente_dataflow', (SELECT id::text FROM public.clientes WHERE empresa = 'DataFlow'), false);
SELECT set_config('test.id_cliente_prime', (SELECT id::text FROM public.clientes WHERE empresa = 'Prime Solutions'), false);
SELECT set_config('test.id_proposta_chatbot', (SELECT id::text FROM public.propostas WHERE titulo = 'Chatbot Omnichannel'), false);
SELECT set_config('test.id_proposta_suporte24h', (SELECT id::text FROM public.propostas WHERE titulo = 'Suporte Premium 24h'), false);
SELECT set_config('test.id_proposta_automacao', (SELECT id::text FROM public.propostas WHERE titulo = 'Automação de Processos'), false);
SELECT set_config('test.id_contrato_devops', (SELECT id::text FROM public.contratos WHERE titulo = 'Contrato Temporário - DevOps'), false);
SELECT set_config('test.id_contrato_prestacao', (SELECT id::text FROM public.contratos WHERE titulo = 'Prestação de Serviços - Automação'), false);
SELECT set_config('test.id_contrato_suporte_legado', (SELECT id::text FROM public.contratos WHERE titulo = 'Suporte Mensal Legado'), false);
SELECT set_config('test.id_cobranca_5000_pendente', (SELECT id::text FROM public.cobrancas WHERE valor = 5000.00 AND status = 'Pendente'), false);
SELECT set_config('test.id_cobranca_3000_pendente', (SELECT id::text FROM public.cobrancas WHERE valor = 3000.00 AND status = 'Pendente'), false);
SELECT set_config('test.id_lancamento_segunda_parcela', (SELECT id::text FROM public.lancamentos WHERE descricao = 'Segunda Parcela - Reestruturação de Infra'), false);

-- --- 7.1 Projetos: Técnico não cria nem exclui (T026) ----------------------
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT throws_ok(
  $$SELECT public.criar_projeto('[FIXTURE 05] Projeto criado por Técnico', NULL, 1000.00, current_date + 30, 'Planejamento')$$,
  '42501'
); -- Técnico não pode criar_projeto (capacidade projetos.criar ausente)

SELECT throws_ok(
  format($$SELECT public.excluir_projeto(%L)$$, current_setting('test.id_proj_descartavel_tecnico')),
  '42501'
); -- Técnico não pode excluir_projeto (capacidade projetos.excluir ausente)

-- --- 7.2 Tarefas: ownership em atualizar_tarefa/mover_tarefa (T027, T028) --

-- Não consegue mover/editar tarefa alheia (responsavel_id = Comercial).
SELECT throws_ok(
  format(
    $$SELECT public.atualizar_tarefa(%L, 'Tarefa alheia editada pelo Técnico', 'Média', NULL, NULL, NULL)$$,
    current_setting('test.id_tarefa_outro_resp')
  ),
  '42501'
); -- Técnico não pode atualizar_tarefa de responsavel_id diferente do seu próprio (tarefas.editar_propria + ownership)

SELECT throws_ok(
  format($$SELECT public.mover_tarefa(%L, 'Em Andamento')$$, current_setting('test.id_tarefa_outro_resp')),
  '42501'
); -- Técnico não pode mover_tarefa de responsavel_id diferente do seu próprio (tarefas.mover_propria + ownership)

-- Consegue mover/editar tarefa própria (responsavel_id = usuário do próprio Técnico).
SELECT lives_ok(
  format(
    $$SELECT public.atualizar_tarefa(%L, 'Migração dos Bancos de Dados (editado pelo próprio Técnico)', 'Alta', NULL, NULL, 'Atualizado via teste 05_capacidades')$$,
    current_setting('test.id_tarefa_propria_1')
  ),
  'Técnico pode atualizar_tarefa de tarefa própria (tarefas.editar_propria + ownership)'
);

SELECT lives_ok(
  format($$SELECT public.mover_tarefa(%L, 'Em Andamento')$$, current_setting('test.id_tarefa_propria_2')),
  'Técnico pode mover_tarefa de tarefa própria (tarefas.mover_propria + ownership)'
);

-- --- 7.3 Apontamentos: ownership em registrar_apontamento_horas (T029, T030) --

SELECT throws_ok(
  format(
    $$SELECT public.registrar_apontamento_horas('{"projeto_id":"%s","membro_equipe_id":"%s","horas":2,"data":"%s","descricao":"Tentativa de apontar para colega"}'::jsonb)$$,
    current_setting('test.id_proj_infra'),
    current_setting('test.id_membro_comercial'),
    current_date
  ),
  '42501'
); -- Técnico não pode registrar_apontamento_horas para outro membro_equipe_id (apontamentos.registrar_proprio + ownership)

SELECT lives_ok(
  format(
    $$SELECT public.registrar_apontamento_horas('{"projeto_id":"%s","membro_equipe_id":"%s","horas":3,"data":"%s","descricao":"Apontamento próprio do Técnico"}'::jsonb)$$,
    current_setting('test.id_proj_infra'),
    current_setting('test.id_membro_tecnico'),
    current_date
  ),
  'Técnico pode registrar_apontamento_horas para o próprio membro_equipe_id'
);

SELECT reset_auth();

-- --- 7.4 listar_membros_equipe: equipe limitada do Técnico (T031) ----------
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT results_eq(
  $$SELECT nome FROM public.listar_membros_equipe() ORDER BY nome$$,
  $$VALUES ('Comercial Persona'), ('Técnico Persona')$$,
  'Técnico vê apenas o próprio membro + colegas com alocação ativa no mesmo projeto em andamento'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.listar_membros_equipe()
    WHERE nome IN ('Financeiro Persona', 'Projetos Persona', 'Administrador Persona', 'Carlos Dev')
  ),
  'Técnico não vê membros sem alocação ativa compartilhada em projeto em andamento'
);

SELECT ok(
  (SELECT perfil_id IS NULL FROM public.listar_membros_equipe() WHERE nome = 'Comercial Persona'),
  'listar_membros_equipe para Técnico não expõe perfil_id do colega'
);

SELECT ok(
  (SELECT custo_hora IS NULL FROM public.listar_membros_equipe() WHERE nome = 'Comercial Persona'),
  'listar_membros_equipe para Técnico não expõe custo_hora do colega'
);

SELECT reset_auth();


-- ============================================================
-- 8. Apontamento com tarefa_id nulo / sentinela inválida (T061)
-- ============================================================
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT lives_ok(
  format(
    $$SELECT public.registrar_apontamento_horas('{"projeto_id":"%s","membro_equipe_id":"%s","horas":1.5,"data":"%s","descricao":"Atividade geral do projeto - fixture 05"}'::jsonb)$$,
    current_setting('test.id_proj_infra'),
    current_setting('test.id_membro_tecnico'),
    current_date
  ),
  'registrar_apontamento_horas aceita tarefa_id ausente/nulo sem lançar erro'
);

-- apontamentos_horas não concede SELECT direto a authenticated (leitura só via
-- RPC); reset_auth() volta ao role padrão para inspecionar a linha gravada.
SELECT reset_auth();

SELECT ok(
  (SELECT tarefa_id IS NULL FROM public.apontamentos_horas WHERE descricao = 'Atividade geral do projeto - fixture 05'),
  'apontamento sem tarefa_id é gravado como atividade geral do projeto (tarefa_id NULL)'
);

SELECT set_auth_by_email('tecnico@aptusflow.local');

-- String sentinela "geral" é inválida no contrato de dados (data-model.md):
-- não existe tratamento especial para ela, então o cast para uuid deve falhar.
SELECT throws_ok(
  format(
    $$SELECT public.registrar_apontamento_horas('{"tarefa_id":"geral","projeto_id":"%s","membro_equipe_id":"%s","horas":1,"data":"%s"}'::jsonb)$$,
    current_setting('test.id_proj_infra'),
    current_setting('test.id_membro_tecnico'),
    current_date
  ),
  '22P02'
); -- registrar_apontamento_horas rejeita a string sentinela "geral" como tarefa_id (cast uuid inválido)

SELECT reset_auth();


-- ============================================================
-- 9. Mapeamento de capacidades das RPCs de escrita/efeito (T069)
-- ============================================================
-- Fonte: contracts/rpc-capability-contract.md ("Mapeamento de RPCs"). Para
-- cada RPC listada, ao menos um teste positivo (persona com a capacidade
-- consegue) e um negativo (persona sem a capacidade recebe Forbidden/42501).

-- --- 9.1 Clientes -----------------------------------------------------------

SELECT set_auth_by_email('comercial@aptusflow.local');
SELECT lives_ok(
  $$SELECT public.criar_cliente('[FIXTURE 05] Contato Teste', '[FIXTURE 05] Empresa Teste', 'fixture05@example.com', '11900000000', 'cliente')$$,
  'Comercial (clientes.criar) pode criar_cliente'
);

SELECT lives_ok(
  format(
    $$SELECT public.atualizar_cliente(%L, 'Suporte Vendas', 'TechSupplies', 'vendas@techsupplies.com', '(11) 3333-9999', 'fornecedor', 'Ativo')$$,
    current_setting('test.id_cliente_techsupplies')
  ),
  'Comercial (clientes.editar) pode atualizar_cliente'
);

SELECT lives_ok(
  format($$SELECT public.inativar_cliente(%L)$$, current_setting('test.id_cliente_techsupplies')),
  'Comercial (clientes.inativar) pode inativar_cliente'
);

-- Reativação (transição Inativo -> Ativo) via atualizar_cliente mapeia para clientes.reativar.
SELECT lives_ok(
  format(
    $$SELECT public.atualizar_cliente(%L, 'Suporte Vendas', 'TechSupplies', 'vendas@techsupplies.com', '(11) 3333-9999', 'fornecedor', 'Ativo')$$,
    current_setting('test.id_cliente_techsupplies')
  ),
  'Comercial (clientes.reativar) pode reativar cliente inativo via atualizar_cliente'
);

SELECT lives_ok(
  format(
    $$SELECT public.registrar_atendimento(%L, 'Atendimento fixture 05_capacidades', current_date)$$,
    current_setting('test.id_cliente_inovatec')
  ),
  'Comercial (clientes.registrar_atendimento) pode registrar_atendimento'
);

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT throws_ok(
  $$SELECT public.criar_cliente('[FIXTURE 05] Financeiro Sem Capacidade', '[FIXTURE 05] Empresa X', 'semcap@example.com', '11911111111', 'cliente')$$,
  '42501'
); -- Financeiro (sem clientes.criar) não pode criar_cliente

SELECT throws_ok(
  format(
    $$SELECT public.atualizar_cliente(%L, 'Lucas Andrade', 'Inovatec', 'lucas@inovatec.com', '(11) 99999-0001', 'cliente', 'Ativo')$$,
    current_setting('test.id_cliente_inovatec')
  ),
  '42501'
); -- Financeiro (sem clientes.editar) não pode atualizar_cliente

SELECT throws_ok(
  format($$SELECT public.inativar_cliente(%L)$$, current_setting('test.id_cliente_inovatec')),
  '42501'
); -- Financeiro (sem clientes.inativar) não pode inativar_cliente

SELECT throws_ok(
  format(
    $$SELECT public.registrar_atendimento(%L, 'Tentativa Financeiro', current_date)$$,
    current_setting('test.id_cliente_inovatec')
  ),
  '42501'
); -- Financeiro (sem clientes.registrar_atendimento) não pode registrar_atendimento

SELECT reset_auth();

-- --- 9.2 Propostas e Contratos ----------------------------------------------

SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT lives_ok(
  format(
    $$SELECT public.criar_proposta('{"cliente_id":"%s","titulo":"[FIXTURE 05] Proposta Teste","valor":1000}'::jsonb)$$,
    current_setting('test.id_cliente_inovatec')
  ),
  'Comercial (propostas.criar) pode criar_proposta'
);

SELECT lives_ok(
  format(
    $$SELECT public.atualizar_proposta(%L, '{"titulo":"Chatbot Omnichannel (editado)"}'::jsonb)$$,
    current_setting('test.id_proposta_chatbot')
  ),
  'Comercial (propostas.editar) pode atualizar_proposta'
);

SELECT lives_ok(
  format($$SELECT public.registrar_envio_proposta(%L)$$, current_setting('test.id_proposta_suporte24h')),
  'Comercial (propostas.enviar) pode registrar_envio_proposta'
);

SELECT lives_ok(
  format(
    $$SELECT public.criar_contrato('{"cliente_id":"%s","titulo":"[FIXTURE 05] Contrato Teste","data_inicio":"%s","data_fim":"%s","valor_recorrente":500}'::jsonb)$$,
    current_setting('test.id_cliente_dataflow'),
    current_date,
    current_date + 365
  ),
  'Comercial (contratos.criar) pode criar_contrato sem proposta vinculada'
);

-- criar_contrato a partir de proposta aprovada mapeia para propostas.gerar_contrato
-- (bundlada com contratos.criar para Comercial/Administrador na matriz atual).
SELECT lives_ok(
  format(
    $$SELECT public.criar_contrato('{"cliente_id":"%s","proposta_id":"%s","titulo":"[FIXTURE 05] Contrato Gerado de Proposta","data_inicio":"%s","data_fim":"%s","valor_recorrente":700}'::jsonb)$$,
    current_setting('test.id_cliente_prime'),
    current_setting('test.id_proposta_automacao'),
    current_date,
    current_date + 180
  ),
  'Comercial (propostas.gerar_contrato) pode criar_contrato a partir de proposta'
);

SELECT lives_ok(
  format(
    $$SELECT public.renovar_contrato(%L, %L)$$,
    current_setting('test.id_contrato_devops'),
    current_date + 400
  ),
  'Comercial (contratos.renovar) pode renovar_contrato'
);

SELECT lives_ok(
  format(
    $$SELECT public.encerrar_contrato(%L, 'Encerramento via fixture 05_capacidades')$$,
    current_setting('test.id_contrato_prestacao')
  ),
  'Comercial (contratos.encerrar) pode encerrar_contrato'
);

SELECT reset_auth();
SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT throws_ok(
  format(
    $$SELECT public.criar_proposta('{"cliente_id":"%s","titulo":"[FIXTURE 05] Proposta Projetos","valor":100}'::jsonb)$$,
    current_setting('test.id_cliente_inovatec')
  ),
  '42501'
); -- Projetos (sem propostas.criar) não pode criar_proposta

SELECT throws_ok(
  format(
    $$SELECT public.criar_contrato('{"cliente_id":"%s","titulo":"[FIXTURE 05] Contrato Projetos","data_inicio":"%s","data_fim":"%s"}'::jsonb)$$,
    current_setting('test.id_cliente_inovatec'),
    current_date,
    current_date + 30
  ),
  '42501'
); -- Projetos (sem contratos.criar) não pode criar_contrato

SELECT reset_auth();
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT throws_ok(
  format(
    $$SELECT public.atualizar_proposta(%L, '{"titulo":"Tentativa Técnico"}'::jsonb)$$,
    current_setting('test.id_proposta_chatbot')
  ),
  '42501'
); -- Técnico (sem propostas.editar) não pode atualizar_proposta

SELECT throws_ok(
  format(
    $$SELECT public.renovar_contrato(%L, %L)$$,
    current_setting('test.id_contrato_suporte_legado'),
    current_date + 400
  ),
  '42501'
); -- Técnico (sem contratos.renovar) não pode renovar_contrato

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT throws_ok(
  format($$SELECT public.registrar_envio_proposta(%L)$$, current_setting('test.id_proposta_suporte24h')),
  '42501'
); -- Financeiro (sem propostas.enviar) não pode registrar_envio_proposta

SELECT throws_ok(
  format(
    $$SELECT public.encerrar_contrato(%L, 'Tentativa Financeiro')$$,
    current_setting('test.id_contrato_devops')
  ),
  '42501'
); -- Financeiro (sem contratos.encerrar) não pode encerrar_contrato

SELECT reset_auth();

-- --- 9.3 Cobranças -----------------------------------------------------------

SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT lives_ok(
  format(
    $$SELECT public.criar_cobranca('{"cliente_id":"%s","valor":250,"data_vencimento":"%s","cria_lancamento":false}'::jsonb)$$,
    current_setting('test.id_cliente_dataflow'),
    current_date + 20
  ),
  'Comercial (cobrancas.emitir) pode criar_cobranca'
);

SELECT lives_ok(
  format($$SELECT public.solicitar_emissao_boleto(%L)$$, current_setting('test.id_cobranca_5000_pendente')),
  'Comercial (cobrancas.boleto) pode solicitar_emissao_boleto'
);

SELECT lives_ok(
  format($$SELECT public.solicitar_lembrete_cobranca(%L)$$, current_setting('test.id_cobranca_5000_pendente')),
  'Comercial (cobrancas.notificar) pode solicitar_lembrete_cobranca'
);

SELECT throws_ok(
  format($$SELECT public.registrar_pagamento_cobranca(%L, '{}'::jsonb)$$, current_setting('test.id_cobranca_3000_pendente')),
  '42501'
); -- Comercial (sem cobrancas.baixar) não pode registrar_pagamento_cobranca

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT lives_ok(
  format($$SELECT public.registrar_pagamento_cobranca(%L, '{}'::jsonb)$$, current_setting('test.id_cobranca_3000_pendente')),
  'Financeiro (cobrancas.baixar) pode registrar_pagamento_cobranca'
);

SELECT throws_ok(
  format($$SELECT public.solicitar_emissao_boleto(%L)$$, current_setting('test.id_cobranca_5000_pendente')),
  '42501'
); -- Financeiro (sem cobrancas.boleto) não pode solicitar_emissao_boleto

SELECT throws_ok(
  format($$SELECT public.solicitar_lembrete_cobranca(%L)$$, current_setting('test.id_cobranca_5000_pendente')),
  '42501'
); -- Financeiro (sem cobrancas.notificar) não pode solicitar_lembrete_cobranca

SELECT reset_auth();
SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT throws_ok(
  format(
    $$SELECT public.criar_cobranca('{"cliente_id":"%s","valor":100,"data_vencimento":"%s"}'::jsonb)$$,
    current_setting('test.id_cliente_dataflow'),
    current_date + 10
  ),
  '42501'
); -- Projetos (sem cobrancas.emitir) não pode criar_cobranca

SELECT reset_auth();

-- --- 9.4 Projetos e Tarefas ("_qualquer") ------------------------------------

SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.criar_projeto('[FIXTURE 05] Projeto por Projetos', NULL, 500.00, current_date + 60, 'Planejamento')$$,
  'Projetos (projetos.criar) pode criar_projeto'
);

SELECT lives_ok(
  $$SELECT public.criar_tarefa(current_setting('test.id_proj_migracao')::uuid, '[FIXTURE 05] Tarefa descartável (excluir_tarefa)')$$,
  'Projetos (tarefas.criar) pode criar_tarefa'
);

-- `projetos`/`tarefas` não concedem SELECT direto a authenticated (nem mesmo
-- para quem tem a capacidade de escrita); reset_auth() resolve os ids das
-- entidades recém-criadas acima pelo role padrão antes de continuar.
SELECT reset_auth();
SELECT set_config('test.id_proj_por_projetos', (SELECT id::text FROM public.projetos WHERE nome = '[FIXTURE 05] Projeto por Projetos'), false);
SELECT set_config('test.id_tarefa_descartavel', (SELECT id::text FROM public.tarefas WHERE titulo = '[FIXTURE 05] Tarefa descartável (excluir_tarefa)'), false);

SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT lives_ok(
  format(
    $$SELECT public.atualizar_projeto(%L, '[FIXTURE 05] Projeto por Projetos (editado)', NULL, 'Planejamento', 10, 500.00, 0.00, false, current_date + 60)$$,
    current_setting('test.id_proj_por_projetos')
  ),
  'Projetos (projetos.editar) pode atualizar_projeto'
);

-- Negativo primeiro (Comercial não pode excluir o projeto descartável T069);
-- depois o positivo consome o mesmo fixture, encerrando seu ciclo de vida.
SELECT reset_auth();
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT throws_ok(
  format($$SELECT public.excluir_projeto(%L)$$, current_setting('test.id_proj_descartavel_t069')),
  '42501'
); -- Comercial (sem projetos.excluir) não pode excluir_projeto

SELECT throws_ok(
  $$SELECT public.criar_projeto('[FIXTURE 05] Projeto por Comercial', NULL, 100.00, current_date + 10, 'Planejamento')$$,
  '42501'
); -- Comercial (sem projetos.criar) não pode criar_projeto

SELECT throws_ok(
  format($$SELECT public.criar_tarefa(%L, '[FIXTURE 05] Tarefa por Comercial')$$, current_setting('test.id_proj_migracao')),
  '42501'
); -- Comercial (sem tarefas.criar) não pode criar_tarefa

SELECT throws_ok(
  format($$SELECT public.excluir_tarefa(%L)$$, current_setting('test.id_tarefa_descartavel')),
  '42501'
); -- Comercial (sem tarefas.excluir) não pode excluir_tarefa

SELECT throws_ok(
  format(
    $$SELECT public.atualizar_tarefa(%L, 'Tarefa alheia editada pelo Comercial', 'Média', NULL, NULL, NULL)$$,
    current_setting('test.id_tarefa_setup')
  ),
  '42501'
); -- Comercial (sem tarefas.editar_qualquer) não pode atualizar_tarefa de outro responsável

SELECT throws_ok(
  format($$SELECT public.mover_tarefa(%L, 'Concluído')$$, current_setting('test.id_tarefa_setup')),
  '42501'
); -- Comercial (sem tarefas.mover_qualquer) não pode mover_tarefa de outro responsável

SELECT reset_auth();
SELECT set_auth_by_email('projetos@aptusflow.local');

-- Projetos (tarefas.editar_qualquer/mover_qualquer) pode alterar tarefa cujo
-- responsável é o Técnico, sem qualquer vínculo de ownership.
SELECT lives_ok(
  format(
    $$SELECT public.atualizar_tarefa(%L, 'Setup do Ambiente de Testes (editado por Projetos)', 'Média', NULL, NULL, NULL)$$,
    current_setting('test.id_tarefa_setup')
  ),
  'Projetos (tarefas.editar_qualquer) pode atualizar_tarefa de qualquer responsável'
);

SELECT lives_ok(
  format($$SELECT public.mover_tarefa(%L, 'Concluído')$$, current_setting('test.id_tarefa_setup')),
  'Projetos (tarefas.mover_qualquer) pode mover_tarefa de qualquer responsável'
);

SELECT lives_ok(
  format($$SELECT public.excluir_tarefa(%L)$$, current_setting('test.id_tarefa_descartavel')),
  'Projetos (tarefas.excluir) pode excluir_tarefa'
);

SELECT lives_ok(
  format($$SELECT public.excluir_projeto(%L)$$, current_setting('test.id_proj_descartavel_t069')),
  'Projetos (projetos.excluir) pode excluir_projeto'
);

SELECT reset_auth();

-- --- 9.5 Equipe e Apontamentos ("_qualquer") ---------------------------------

SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.criar_membro_equipe('{"nome":"[FIXTURE 05] Membro Descartável","funcao":"QA"}'::jsonb)$$,
  'Projetos (equipe.adicionar_membro) pode criar_membro_equipe'
);

-- A policy membros_equipe_select referencia public.perfis diretamente em um
-- subselect (não só via permissao_modulo(...)), e public.perfis também não
-- concede SELECT a authenticated — então mesmo Projetos (que tem leitura de
-- equipe) não consegue ler membros_equipe por SELECT direto. reset_auth()
-- resolve o id pelo role padrão antes de continuar.
SELECT reset_auth();
SELECT set_config('test.id_membro_descartavel', (SELECT id::text FROM public.membros_equipe WHERE nome = '[FIXTURE 05] Membro Descartável'), false);
SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT lives_ok(
  format($$SELECT public.atualizar_membro_equipe(%L, '{"funcao":"QA Sênior"}'::jsonb)$$, current_setting('test.id_membro_descartavel')),
  'Projetos (equipe.adicionar_membro) pode atualizar_membro_equipe'
);

SELECT lives_ok(
  format(
    $$SELECT public.alocar_membro_projeto('{"membro_equipe_id":"%s","projeto_id":"%s","data_inicio":"%s","percentual_alocacao":20}'::jsonb)$$,
    current_setting('test.id_membro_descartavel'),
    current_setting('test.id_proj_migracao'),
    current_date
  ),
  'Projetos (equipe.alocar) pode alocar_membro_projeto'
);

SELECT lives_ok(
  format(
    $$SELECT public.registrar_apontamento_horas('{"projeto_id":"%s","membro_equipe_id":"%s","horas":1,"data":"%s"}'::jsonb)$$,
    current_setting('test.id_proj_infra'),
    current_setting('test.id_membro_tecnico'),
    current_date
  ),
  'Projetos (apontamentos.registrar_qualquer) pode registrar_apontamento_horas para qualquer membro'
);

SELECT lives_ok(
  format($$SELECT public.inativar_membro_equipe(%L)$$, current_setting('test.id_membro_descartavel')),
  'Projetos (equipe.inativar_membro) pode inativar_membro_equipe'
);

SELECT reset_auth();
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT throws_ok(
  $$SELECT public.criar_membro_equipe('{"nome":"[FIXTURE 05] Membro Comercial","funcao":"QA"}'::jsonb)$$,
  '42501'
); -- Comercial (sem equipe.adicionar_membro) não pode criar_membro_equipe

SELECT throws_ok(
  format($$SELECT public.atualizar_membro_equipe(%L, '{"funcao":"Tentativa"}'::jsonb)$$, current_setting('test.id_membro_descartavel')),
  '42501'
); -- Comercial (sem equipe.adicionar_membro) não pode atualizar_membro_equipe

SELECT throws_ok(
  format(
    $$SELECT public.alocar_membro_projeto('{"membro_equipe_id":"%s","projeto_id":"%s","data_inicio":"%s","percentual_alocacao":10}'::jsonb)$$,
    current_setting('test.id_membro_descartavel'),
    current_setting('test.id_proj_migracao'),
    current_date
  ),
  '42501'
); -- Comercial (sem equipe.alocar) não pode alocar_membro_projeto

SELECT throws_ok(
  format($$SELECT public.inativar_membro_equipe(%L)$$, current_setting('test.id_membro_descartavel')),
  '42501'
); -- Comercial (sem equipe.inativar_membro) não pode inativar_membro_equipe

SELECT throws_ok(
  format(
    $$SELECT public.registrar_apontamento_horas('{"projeto_id":"%s","membro_equipe_id":"%s","horas":1,"data":"%s"}'::jsonb)$$,
    current_setting('test.id_proj_infra'),
    current_setting('test.id_membro_tecnico'),
    current_date
  ),
  '42501'
); -- Comercial (sem apontamentos.registrar_qualquer) não pode registrar_apontamento_horas para outro membro

SELECT reset_auth();

-- --- 9.6 Financeiro -----------------------------------------------------------

SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.criar_lancamento_financeiro('{"tipo":"despesa","natureza":"a_pagar","descricao":"[FIXTURE 05] Lançamento Teste","valor":300}'::jsonb)$$,
  'Financeiro (financeiro.lancar) pode criar_lancamento_financeiro'
);

-- `lancamentos` não concede SELECT direto a authenticated; reset_auth() resolve
-- o id do lançamento recém-criado antes de continuar.
SELECT reset_auth();
SELECT set_config('test.id_lancamento_teste', (SELECT id::text FROM public.lancamentos WHERE descricao = '[FIXTURE 05] Lançamento Teste'), false);
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT lives_ok(
  format(
    $$SELECT public.atualizar_lancamento_financeiro(%L, '{"descricao":"[FIXTURE 05] Lançamento Teste (editado)"}'::jsonb)$$,
    current_setting('test.id_lancamento_teste')
  ),
  'Financeiro (financeiro.editar_lancamento) pode atualizar_lancamento_financeiro'
);

SELECT lives_ok(
  format($$SELECT public.registrar_pagamento_lancamento(%L, current_date, 300)$$, current_setting('test.id_lancamento_teste')),
  'Financeiro (financeiro.baixar_lancamento) pode registrar_pagamento_lancamento'
);

SELECT reset_auth();
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT throws_ok(
  $$SELECT public.criar_lancamento_financeiro('{"tipo":"despesa","natureza":"a_pagar","descricao":"[FIXTURE 05] Comercial","valor":50}'::jsonb)$$,
  '42501'
); -- Comercial (sem financeiro.lancar) não pode criar_lancamento_financeiro

SELECT throws_ok(
  format(
    $$SELECT public.atualizar_lancamento_financeiro(%L, '{"valor":999}'::jsonb)$$,
    current_setting('test.id_lancamento_segunda_parcela')
  ),
  '42501'
); -- Comercial (sem financeiro.editar_lancamento) não pode atualizar_lancamento_financeiro

SELECT throws_ok(
  format(
    $$SELECT public.registrar_pagamento_lancamento(%L, current_date, 100)$$,
    current_setting('test.id_lancamento_segunda_parcela')
  ),
  '42501'
); -- Comercial (sem financeiro.baixar_lancamento) não pode registrar_pagamento_lancamento

SELECT reset_auth();

-- --- 9.7 Configurações e Relatórios --------------------------------------------

SELECT set_auth_by_email('admin@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.atualizar_configuracoes_empresa('{"razao_social":"[FIXTURE 05] Empresa LTDA"}'::jsonb)$$,
  'Administrador (configuracoes.editar_empresa) pode atualizar_configuracoes_empresa'
);

SELECT lives_ok(
  format(
    $$SELECT public.atualizar_usuario_perfil(%L, '{"departamento":"[FIXTURE 05] Depto"}'::jsonb)$$,
    current_setting('test.id_user_tecnico')
  ),
  'Administrador (configuracoes.gerenciar_usuarios) pode atualizar_usuario_perfil'
);

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT throws_ok(
  $$SELECT public.atualizar_configuracoes_empresa('{"razao_social":"Tentativa Financeiro"}'::jsonb)$$,
  '42501'
); -- Financeiro (sem configuracoes.editar_empresa) não pode atualizar_configuracoes_empresa

SELECT lives_ok(
  $$SELECT public.atualizar_minhas_configuracoes('{"departamento":"[FIXTURE 05] Meu Depto"}'::jsonb)$$,
  'Financeiro (configuracoes.editar_proprio_perfil) pode atualizar_minhas_configuracoes'
);

SELECT reset_auth();
SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT throws_ok(
  format(
    $$SELECT public.atualizar_usuario_perfil(%L, '{"departamento":"Tentativa Projetos"}'::jsonb)$$,
    current_setting('test.id_user_tecnico')
  ),
  '42501'
); -- Projetos (sem configuracoes.gerenciar_usuarios) não pode atualizar_usuario_perfil

SELECT lives_ok(
  $$SELECT public.solicitar_exportacao_relatorio('Projetos', 'PDF', '{}'::jsonb)$$,
  'Projetos (relatorios.exportar) pode solicitar_exportacao_relatorio'
);

SELECT reset_auth();
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.atualizar_preferencias_notificacoes('{"canal":"Email","tipo":"Lembretes","ativo":true}'::jsonb)$$,
  'Comercial (configuracoes.editar_proprio_perfil) pode atualizar_preferencias_notificacoes'
);

SELECT throws_ok(
  $$SELECT public.solicitar_exportacao_relatorio('Clientes', 'CSV', '{}'::jsonb)$$,
  '42501'
); -- Comercial (sem relatorios.exportar) não pode solicitar_exportacao_relatorio

SELECT throws_ok(
  $$SELECT public.agendar_relatorio('{"tipo":"Clientes","formato":"CSV","frequencia":"Uma vez"}'::jsonb)$$,
  '42501'
); -- Comercial (sem relatorios.exportar) não pode agendar_relatorio

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.agendar_relatorio('{"tipo":"Financeiro","formato":"PDF","frequencia":"Mensal"}'::jsonb)$$,
  'Financeiro (relatorios.exportar) pode agendar_relatorio'
);

SELECT reset_auth();
SELECT set_auth_by_email('visualizador_teste_005@aptusflow.local');

SELECT throws_ok(
  $$SELECT public.atualizar_minhas_configuracoes('{"departamento":"Tentativa Visualizador"}'::jsonb)$$,
  '42501'
); -- Visualizador (sem configuracoes.editar_proprio_perfil) não pode atualizar_minhas_configuracoes

SELECT throws_ok(
  $$SELECT public.atualizar_preferencias_notificacoes('{"canal":"Email","tipo":"Lembretes","ativo":true}'::jsonb)$$,
  '42501'
); -- Visualizador (sem configuracoes.editar_proprio_perfil) não pode atualizar_preferencias_notificacoes

SELECT reset_auth();

SELECT * FROM finish();
