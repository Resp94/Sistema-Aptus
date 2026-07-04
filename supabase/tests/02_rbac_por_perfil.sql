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

SELECT reset_auth();

SELECT * FROM finish();
