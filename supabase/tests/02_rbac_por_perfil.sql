-- FR-015: matriz de permissões por perfil e falha de escrita sem pode_escrever
--
-- Feature 007 (RBAC por Capacidades Nomeadas) / US3 (T041): este arquivo cobre
-- apenas as CINCO personas operacionais (Administrador, Financeiro, Projetos,
-- Comercial, Técnico). Visualizador deixou de ser persona operacional — ele é
-- validado separadamente como "estado técnico mínimo" (zero capacidades,
-- leitura restrita a relatorios/configuracoes, nenhuma escrita) em
-- supabase/tests/05_capacidades.sql, seção "Visualizador como estado técnico
-- mínimo". Ver specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md
-- e data-model.md ("Entidade: Visualizador").

SELECT * FROM no_plan();

-- Administrador
SELECT set_auth_by_email('admin@aptusflow.local');

SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', true, true),
    ('clientes', true, true),
    ('propostas', true, true),
    ('contratos', true, true),
    ('cobrancas', true, true),
    ('projetos', true, true),
    ('equipe', true, true),
    ('financeiro', true, true),
    ('fluxo-caixa', true, true),
    ('contas-pagar', true, true),
    ('contas-receber', true, true),
    ('relatorios', true, true),
    ('configuracoes', true, true)$$,
  'Administrador permissions match obter_permissoes_usuario'
);

SELECT lives_ok(
  $$SELECT public.criar_cliente('Admin Teste', 'Admin Empresa', 'admin_teste@aptusflow.local', '11999999999', 'cliente')$$,
  'Administrador can create cliente'
);

-- Financeiro
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', true, true),
    ('clientes', false, false),
    ('propostas', false, false),
    ('contratos', false, false),
    ('cobrancas', true, true),
    ('projetos', false, false),
    ('equipe', false, false),
    ('financeiro', true, true),
    ('fluxo-caixa', true, true),
    ('contas-pagar', true, true),
    ('contas-receber', true, true),
    ('relatorios', true, true),
    ('configuracoes', true, true)$$,
  'Financeiro permissions match obter_permissoes_usuario'
);

-- Projetos
SELECT set_auth_by_email('projetos@aptusflow.local');

SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', false, false),
    ('clientes', false, false),
    ('propostas', false, false),
    ('contratos', false, false),
    ('cobrancas', false, false),
    ('projetos', true, true),
    ('equipe', true, true),
    ('financeiro', false, false),
    ('fluxo-caixa', false, false),
    ('contas-pagar', false, false),
    ('contas-receber', false, false),
    ('relatorios', true, true),
    ('configuracoes', true, true)$$,
  'Projetos permissions match obter_permissoes_usuario'
);

-- Comercial
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', false, false),
    ('clientes', true, true),
    ('propostas', true, true),
    ('contratos', true, true),
    ('cobrancas', true, true),
    ('projetos', false, false),
    ('equipe', false, false),
    ('financeiro', false, false),
    ('fluxo-caixa', false, false),
    ('contas-pagar', false, false),
    ('contas-receber', false, false),
    ('relatorios', false, false),
    ('configuracoes', true, true)$$,
  'Comercial permissions match obter_permissoes_usuario'
);

SELECT lives_ok(
  $$SELECT public.criar_cliente('Comercial Teste', 'Comercial Empresa', 'comercial_teste@aptusflow.local', '11999999998', 'cliente')$$,
  'Comercial can create cliente'
);

-- Técnico
SELECT set_auth_by_email('tecnico@aptusflow.local');

SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', false, false),
    ('clientes', false, false),
    ('propostas', false, false),
    ('contratos', false, false),
    ('cobrancas', false, false),
    ('projetos', true, true),
    ('equipe', true, false),
    ('financeiro', false, false),
    ('fluxo-caixa', false, false),
    ('contas-pagar', false, false),
    ('contas-receber', false, false),
    ('relatorios', false, false),
    ('configuracoes', true, true)$$,
  'Técnico permissions match obter_permissoes_usuario'
);

-- =========================================================================
-- Validação de RLS Policies Otimizadas (Fase 4 - User Story 2)
-- =========================================================================

-- Garantir que as políticas antigas de perfis foram removidas
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'perfis' AND policyname = 'perfis_select_self'
  ),
  'A policy perfis_select_self nao deve mais existir'
);

SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'perfis' AND policyname = 'perfis_select_admin'
  ),
  'A policy perfis_select_admin nao deve mais existir'
);

SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'perfis' AND policyname = 'perfis_update_self'
  ),
  'A policy perfis_update_self nao deve mais existir'
);

SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'perfis' AND policyname = 'perfis_update_admin'
  ),
  'A policy perfis_update_admin nao deve mais existir'
);

-- Garantir que as novas políticas consolidadas e otimizadas existem
SELECT assert_has_policy('public', 'perfis', 'perfis_select');
SELECT assert_has_policy('public', 'perfis', 'perfis_update');
SELECT assert_has_policy('public', 'perfis', 'perfis_insert_admin');

-- Garantir que as políticas otimizadas com (select auth.uid()) nas outras tabelas existem
SELECT assert_has_policy('public', 'usuarios', 'usuarios_select_self');
SELECT assert_has_policy('public', 'audit_log', 'audit_log_select_admin');
SELECT assert_has_policy('public', 'membros_equipe', 'membros_equipe_select');
SELECT assert_has_policy('public', 'membros_equipe', 'membros_equipe_update');
SELECT assert_has_policy('public', 'alocacoes_equipe', 'alocacoes_equipe_select');
SELECT assert_has_policy('public', 'apontamentos_horas', 'apontamentos_horas_select');
SELECT assert_has_policy('public', 'apontamentos_horas', 'apontamentos_horas_insert');
SELECT assert_has_policy('public', 'configuracoes_empresa', 'configuracoes_empresa_select');
SELECT assert_has_policy('public', 'configuracoes_empresa', 'configuracoes_empresa_update');
SELECT assert_has_policy('public', 'preferencias_notificacoes', 'preferencias_notificacoes_select');
SELECT assert_has_policy('public', 'preferencias_notificacoes', 'preferencias_notificacoes_insert');
SELECT assert_has_policy('public', 'preferencias_notificacoes', 'preferencias_notificacoes_update');

SELECT reset_auth();

SELECT * FROM finish();

