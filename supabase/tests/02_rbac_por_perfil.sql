-- FR-015: matriz de permissões por perfil e falha de escrita sem pode_escrever

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

-- Visualizador
SELECT set_auth_by_email('visualizador@aptusflow.local');

SELECT set_eq(
  'SELECT modulo, pode_ler, pode_escrever FROM public.obter_permissoes_usuario()',
  $$VALUES
    ('dashboard', false, false),
    ('clientes', true, false),
    ('propostas', true, false),
    ('contratos', true, false),
    ('cobrancas', true, false),
    ('projetos', true, false),
    ('equipe', true, false),
    ('financeiro', true, false),
    ('fluxo-caixa', true, false),
    ('contas-pagar', true, false),
    ('contas-receber', true, false),
    ('relatorios', true, false),
    ('configuracoes', true, false)$$,
  'Visualizador permissions match obter_permissoes_usuario'
);

SELECT lives_ok(
  $$SELECT public.listar_clientes()$$,
  'Visualizador can read clientes'
);

SELECT throws_ok(
  $$SELECT public.criar_cliente('Visualizador Teste', 'Vis Empresa', 'vis_teste@aptusflow.local', '11999999997', 'cliente')$$,
  'Sem permissão de escrita',
  'Visualizador cannot create cliente'
);

SELECT reset_auth();

SELECT * FROM finish();
