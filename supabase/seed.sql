-- SQL de semente para banco de dados local do Supabase
-- Cria os usuários e perfis de teste baseados nas personas do projeto e estende com dados dos módulos de landing.

DO $$
DECLARE
  v_senha text;
  v_admin_id uuid;
  v_financeiro_id uuid;
  v_projetos_id uuid;
  v_comercial_id uuid;
  v_tecnico_id uuid;

  v_cliente_inovatec_id uuid;
  v_cliente_dataflow_id uuid;
  v_cliente_prime_id uuid;
  v_forn_techsupplies_id uuid;

  v_proj_infra_id uuid;
  v_proj_portal_id uuid;
  v_proj_migracao_id uuid;
  v_proj_suporte_id uuid;
BEGIN
  -- Obtém a senha de teste configurada via ambiente no config.toml (se estiver configurada)
  v_senha := current_setting('app.settings.seed_user_password', true);
  
  -- Fallback seguro para o ambiente local para garantir resiliência
  IF v_senha IS NULL OR v_senha = '' THEN
    v_senha := 'SenhaDeTesteSegura123!';
    RAISE WARNING 'SEED_USER_PASSWORD não pôde ser lida do ambiente. Usando senha de fallback padrão.';
  END IF;

  -- Remove registros anteriores das personas se existirem (para idempotência)
  DELETE FROM auth.users WHERE email IN (
    'admin@aptusflow.local',
    'financeiro@aptusflow.local',
    'projetos@aptusflow.local',
    'comercial@aptusflow.local',
    'tecnico@aptusflow.local'
  );

  -- Limpar as tabelas operacionais antes de inserir os novos seeds
  TRUNCATE TABLE public.lancamentos CASCADE;
  TRUNCATE TABLE public.alocacoes_projeto CASCADE;
  TRUNCATE TABLE public.tarefas CASCADE;
  TRUNCATE TABLE public.projetos CASCADE;
  TRUNCATE TABLE public.atendimentos CASCADE;
  TRUNCATE TABLE public.clientes CASCADE;

  -- Cria os usuários de teste chamando a RPC criar_perfil_teste
  SELECT usuario_id INTO v_admin_id FROM public.criar_perfil_teste('admin@aptusflow.local', v_senha, 'Administrador Persona', 'Administrador');
  SELECT usuario_id INTO v_financeiro_id FROM public.criar_perfil_teste('financeiro@aptusflow.local', v_senha, 'Financeiro Persona', 'Financeiro');
  SELECT usuario_id INTO v_projetos_id FROM public.criar_perfil_teste('projetos@aptusflow.local', v_senha, 'Projetos Persona', 'Projetos');
  SELECT usuario_id INTO v_comercial_id FROM public.criar_perfil_teste('comercial@aptusflow.local', v_senha, 'Comercial Persona', 'Comercial');
  SELECT usuario_id INTO v_tecnico_id FROM public.criar_perfil_teste('tecnico@aptusflow.local', v_senha, 'Técnico Persona', 'Técnico');

  -------------------------------------------------------------
  -- 1. SEEDS DE CLIENTES E FORNECEDORES
  -------------------------------------------------------------
  INSERT INTO public.clientes (nome_contato, empresa, email, telefone, tipo, status, created_by)
  VALUES ('Lucas Andrade', 'Inovatec', 'lucas@inovatec.com', '(11) 99999-0001', 'cliente', 'Ativo', v_comercial_id)
  RETURNING id INTO v_cliente_inovatec_id;

  INSERT INTO public.clientes (nome_contato, empresa, email, telefone, tipo, status, created_by)
  VALUES ('Mariana Costa', 'DataFlow', 'mariana@dataflow.com', '(21) 98888-0002', 'cliente', 'Ativo', v_comercial_id)
  RETURNING id INTO v_cliente_dataflow_id;

  INSERT INTO public.clientes (nome_contato, empresa, email, telefone, tipo, status, created_by)
  VALUES ('Roberto Silva', 'Prime Solutions', 'roberto@primesolutions.com', '(31) 97777-0003', 'cliente', 'Ativo', v_comercial_id)
  RETURNING id INTO v_cliente_prime_id;

  INSERT INTO public.clientes (nome_contato, empresa, email, telefone, tipo, status, created_by)
  VALUES ('Suporte Vendas', 'TechSupplies', 'vendas@techsupplies.com', '(11) 3333-0004', 'fornecedor', 'Ativo', v_admin_id)
  RETURNING id INTO v_forn_techsupplies_id;

  -------------------------------------------------------------
  -- 2. SEEDS DE ATENDIMENTOS (HISTÓRICO)
  -------------------------------------------------------------
  INSERT INTO public.atendimentos (cliente_id, data, descricao, responsavel_id)
  VALUES (v_cliente_inovatec_id, current_date - 8, 'Apresentação comercial e demonstração da proposta de infraestrutura.', v_comercial_id);

  INSERT INTO public.atendimentos (cliente_id, data, descricao, responsavel_id)
  VALUES (v_cliente_inovatec_id, current_date - 5, 'Reunião de alinhamento técnico e coleta de insumos para início do projeto.', v_comercial_id);

  INSERT INTO public.atendimentos (cliente_id, data, descricao, responsavel_id)
  VALUES (v_cliente_dataflow_id, current_date - 12, 'Primeiro contato comercial via e-mail e agendamento da demo.', v_comercial_id);

  INSERT INTO public.atendimentos (cliente_id, data, descricao, responsavel_id)
  VALUES (v_cliente_dataflow_id, current_date - 2, 'Validação dos requisitos do portal corporativo com o time de design.', v_comercial_id);

  -------------------------------------------------------------
  -- 3. SEEDS DE PROJETOS
  -------------------------------------------------------------
  -- Projeto A (Infraestrutura)
  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Reestruturação de Infraestrutura', v_cliente_inovatec_id, 'Em andamento', 65, 50000.00, 32000.00, false, current_date + 30, v_projetos_id)
  RETURNING id INTO v_proj_infra_id;

  -- Projeto B (Portal DataFlow)
  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Portal Corporativo', v_cliente_dataflow_id, 'Planejamento', 15, 25000.00, 0.00, false, current_date + 60, v_projetos_id)
  RETURNING id INTO v_proj_portal_id;

  -- Projeto C (Migração Prime)
  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Migração de Sistemas', v_cliente_prime_id, 'Em andamento', 40, 80000.00, 60000.00, true, current_date + 15, v_projetos_id)
  RETURNING id INTO v_proj_migracao_id;

  -- Projeto D (Suporte Legado Inovatec - Concluído)
  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Suporte Legado', v_cliente_inovatec_id, 'Concluído', 100, 12000.00, 12000.00, false, current_date - 10, v_projetos_id)
  RETURNING id INTO v_proj_suporte_id;

  -------------------------------------------------------------
  -- 4. SEEDS DE ALOCAÇÕES DE PROJETO (Técnico alocado apenas em A e B)
  -------------------------------------------------------------
  INSERT INTO public.alocacoes_projeto (projeto_id, usuario_id, papel)
  VALUES (v_proj_infra_id, v_tecnico_id, 'DevOps');

  INSERT INTO public.alocacoes_projeto (projeto_id, usuario_id, papel)
  VALUES (v_proj_portal_id, v_tecnico_id, 'Frontend Developer');

  -------------------------------------------------------------
  -- 5. SEEDS DE TAREFAS
  -------------------------------------------------------------
  -- Projeto A (Infra)
  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_infra_id, 'Migração dos Bancos de Dados', 'A Fazer', 'Alta', v_tecnico_id, current_date + 10, 'Migrar PostgreSQL legado para RDS AWS.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_infra_id, 'Configuração do Kubernetes', 'Em Andamento', 'Alta', v_tecnico_id, current_date + 5, 'Configurar clusters EKS e deployments iniciais.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_infra_id, 'Setup do Ambiente de Testes', 'Concluído', 'Média', v_tecnico_id, current_date - 2, 'Provisionar infra de staging.', 1);

  -- Projeto B (Portal)
  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_portal_id, 'Criação do Protótipo de Design', 'A Fazer', 'Média', v_tecnico_id, current_date + 20, 'Desenhar wireframes e fluxo de navegação no Figma.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_portal_id, 'Desenho da Arquitetura SPA', 'Concluído', 'Alta', v_tecnico_id, current_date - 1, 'Definir estrutura do projeto React + Router + Tailwind.', 1);

  -- Projeto C (Migração Prime - Técnico não alocado)
  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_migracao_id, 'Auditoria de Segurança nos Servidores', 'Em Andamento', 'Alta', v_projetos_id, current_date + 3, 'Análise de vulnerabilidades.', 1);

  -------------------------------------------------------------
  -- 6. SEEDS DE LANÇAMENTOS FINANCEIROS
  -------------------------------------------------------------
  -- Receita Realizada (Projeto D)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'realizado', 'Parcela Única - Suporte Legado', 12000.00, 'Suporte', v_cliente_inovatec_id, current_date - 30, current_date - 25, 'Pago');

  -- Receita Realizada (Projeto A)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'realizado', 'Entrada - Reestruturação de Infra', 16000.00, 'Projetos', v_cliente_inovatec_id, current_date - 15, current_date - 12, 'Pago');

  -- Receita a Receber (Pendente - Projeto A)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'a_receber', 'Segunda Parcela - Reestruturação de Infra', 18000.00, 'Projetos', v_cliente_inovatec_id, current_date, current_date + 15, 'Pendente');

  -- Receita Realizada (Consultoria Prime)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'realizado', 'Consultoria Técnica Estratégica', 30000.00, 'Consultoria', v_cliente_prime_id, current_date - 45, current_date - 40, 'Pago');

  -- Despesa Realizada (AWS infra fornecida pela TechSupplies)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'realizado', 'Consumo AWS Staging & Production', 5000.00, 'Infraestrutura', v_forn_techsupplies_id, current_date - 10, current_date - 8, 'Pago');

  -- Despesa a Pagar (Pendente - TechSupplies, nos próximos 7 dias!)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'a_pagar', 'Licenças Adicionais JetBrains', 1200.00, 'Licenciamento', v_forn_techsupplies_id, current_date, current_date + 5, 'Pendente');

  -- Despesa a Pagar (Pendente - Vencida! vencimento ontem, status Pendente)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'a_pagar', 'Mensalidade Servidores Backup Cloud', 2000.00, 'Infraestrutura', v_forn_techsupplies_id, current_date - 5, current_date - 1, 'Pendente');

  -- Despesa Realizada (Marketing)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'realizado', 'Campanha de Marketing LinkedIn Ads', 3500.00, 'Marketing', null, current_date - 20, current_date - 18, 'Pago');

  RAISE NOTICE 'Seed executado com sucesso: 5 personas e dados dos módulos de landing cadastrados.';
END $$;
