-- SQL de semente para banco de dados local do Supabase
-- Cria os usuários e perfis de teste baseados nas personas do projeto e estende com dados dos módulos de landing e demais telas.

DO $$
DECLARE
  v_senha text;
  v_admin_id uuid;
  v_financeiro_id uuid;
  v_projetos_id uuid;
  v_comercial_id uuid;
  v_tecnico_id uuid;
  v_visualizador_id uuid;

  v_cliente_inovatec_id uuid;
  v_cliente_dataflow_id uuid;
  v_cliente_prime_id uuid;
  v_forn_techsupplies_id uuid;

  v_proj_infra_id uuid;
  v_proj_portal_id uuid;
  v_proj_migracao_id uuid;
  v_proj_suporte_id uuid;

  -- Variáveis para Propostas
  v_prop_analise_id uuid;
  v_prop_enviado_id uuid;
  v_prop_aprovado_id uuid;
  v_prop_rascunho_id uuid;

  -- Variáveis para Contratos
  v_contrato_vigente_id uuid;
  v_contrato_proximo_id uuid;
  v_contrato_encerrado_id uuid;

  -- Variáveis para Cobranças
  v_cobranca_pendente_id uuid;
  v_cobranca_pago_id uuid;
  v_cobranca_vencido_id uuid;

  -- Variáveis para Membros Equipe
  v_membro_tecnico_id uuid;
  v_membro_projetos_id uuid;
  v_membro_comercial_id uuid;
  v_membro_financeiro_id uuid;
  v_membro_admin_id uuid;
BEGIN
  -- Obtém a senha de teste
  v_senha := 'SenhaDeTesteSegura123!';

  -- Remove registros anteriores das personas se existirem (para idempotência)
  DELETE FROM auth.users WHERE email IN (
    'admin@aptusflow.local',
    'financeiro@aptusflow.local',
    'projetos@aptusflow.local',
    'comercial@aptusflow.local',
    'tecnico@aptusflow.local',
    'visualizador@aptusflow.local'
  );

  -- Limpar as tabelas operacionais na ordem correta
  TRUNCATE TABLE public.preferencias_notificacoes CASCADE;
  TRUNCATE TABLE public.configuracoes_empresa CASCADE;
  TRUNCATE TABLE public.exportacoes_relatorios CASCADE;
  TRUNCATE TABLE public.agendamentos_relatorios CASCADE;
  TRUNCATE TABLE public.apontamentos_horas CASCADE;
  TRUNCATE TABLE public.alocacoes_equipe CASCADE;
  TRUNCATE TABLE public.membros_equipe CASCADE;
  TRUNCATE TABLE public.pagamentos_cobrancas CASCADE;
  TRUNCATE TABLE public.cobrancas CASCADE;
  TRUNCATE TABLE public.documentos CASCADE;
  TRUNCATE TABLE public.contratos CASCADE;
  TRUNCATE TABLE public.propostas CASCADE;
  TRUNCATE TABLE public.lancamentos CASCADE;
  TRUNCATE TABLE public.alocacoes_projeto CASCADE;
  TRUNCATE TABLE public.tarefas CASCADE;
  TRUNCATE TABLE public.projetos CASCADE;
  TRUNCATE TABLE public.atendimentos CASCADE;
  TRUNCATE TABLE public.clientes CASCADE;

  -- Cria os usuários de teste
  SELECT usuario_id INTO v_admin_id FROM public.criar_perfil_teste('admin@aptusflow.local', v_senha, 'Administrador Persona', 'Administrador');
  SELECT usuario_id INTO v_financeiro_id FROM public.criar_perfil_teste('financeiro@aptusflow.local', v_senha, 'Financeiro Persona', 'Financeiro');
  SELECT usuario_id INTO v_projetos_id FROM public.criar_perfil_teste('projetos@aptusflow.local', v_senha, 'Projetos Persona', 'Projetos');
  SELECT usuario_id INTO v_comercial_id FROM public.criar_perfil_teste('comercial@aptusflow.local', v_senha, 'Comercial Persona', 'Comercial');
  SELECT usuario_id INTO v_tecnico_id FROM public.criar_perfil_teste('tecnico@aptusflow.local', v_senha, 'Técnico Persona', 'Técnico');
  SELECT usuario_id INTO v_visualizador_id FROM public.criar_perfil_teste('visualizador@aptusflow.local', v_senha, 'Visualizador Persona', 'Visualizador');

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
  -- 2. SEEDS DE ATENDIMENTOS
  -------------------------------------------------------------
  INSERT INTO public.atendimentos (cliente_id, data, descricao, responsavel_id)
  VALUES (v_cliente_inovatec_id, current_date - 8, 'Apresentação comercial e demonstração da proposta de infraestrutura.', v_comercial_id);

  INSERT INTO public.atendimentos (cliente_id, data, descricao, responsavel_id)
  VALUES (v_cliente_dataflow_id, current_date - 12, 'Primeiro contato comercial via e-mail e agendamento da demo.', v_comercial_id);

  -------------------------------------------------------------
  -- 3. SEEDS DE PROJETOS
  -------------------------------------------------------------
  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Reestruturação de Infraestrutura', v_cliente_inovatec_id, 'Em andamento', 65, 50000.00, 32000.00, false, current_date + 30, v_projetos_id)
  RETURNING id INTO v_proj_infra_id;

  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Portal Corporativo', v_cliente_dataflow_id, 'Planejamento', 15, 25000.00, 0.00, false, current_date + 60, v_projetos_id)
  RETURNING id INTO v_proj_portal_id;

  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Migração de Sistemas', v_cliente_prime_id, 'Em andamento', 40, 80000.00, 60000.00, true, current_date + 15, v_projetos_id)
  RETURNING id INTO v_proj_migracao_id;

  INSERT INTO public.projetos (nome, cliente_id, status, progresso, orcamento, orcamento_utilizado, em_risco, prazo, created_by)
  VALUES ('Suporte Legado', v_cliente_inovatec_id, 'Concluído', 100, 12000.00, 12000.00, false, current_date - 10, v_projetos_id)
  RETURNING id INTO v_proj_suporte_id;

  -------------------------------------------------------------
  -- 4. SEEDS DE ALOCAÇÕES DE PROJETO (Autorização Técnica mínima)
  -------------------------------------------------------------
  INSERT INTO public.alocacoes_projeto (projeto_id, usuario_id, papel)
  VALUES (v_proj_infra_id, v_tecnico_id, 'DevOps');

  INSERT INTO public.alocacoes_projeto (projeto_id, usuario_id, papel)
  VALUES (v_proj_portal_id, v_tecnico_id, 'Frontend Developer');

  -------------------------------------------------------------
  -- 5. SEEDS DE TAREFAS
  -------------------------------------------------------------
  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_infra_id, 'Migração dos Bancos de Dados', 'A Fazer', 'Alta', v_tecnico_id, current_date + 10, 'Migrar PostgreSQL legado para RDS AWS.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_infra_id, 'Configuração do Kubernetes', 'Em Andamento', 'Alta', v_tecnico_id, current_date + 5, 'Configurar clusters EKS e deployments iniciais.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_infra_id, 'Setup do Ambiente de Testes', 'Concluído', 'Média', v_tecnico_id, current_date - 2, 'Provisionar infra de staging.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_portal_id, 'Criação do Protótipo de Design', 'A Fazer', 'Média', v_tecnico_id, current_date + 20, 'Desenhar wireframes e fluxo de navegação no Figma.', 1);

  INSERT INTO public.tarefas (projeto_id, titulo, situacao, prioridade, responsavel_id, prazo, instrucoes, ordem)
  VALUES (v_proj_portal_id, 'Desenho da Arquitetura SPA', 'Concluído', 'Alta', v_tecnico_id, current_date - 1, 'Definir estrutura do projeto React + Router + Tailwind.', 1);

  -------------------------------------------------------------
  -- 6. SEEDS DE LANÇAMENTOS FINANCEIROS (Reutilizados pela feature 005)
  -------------------------------------------------------------
  -- Receita Realizada (Pago)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'realizado', 'Parcela Única - Suporte Legado', 12000.00, 'Suporte', v_cliente_inovatec_id, current_date - 30, current_date - 25, 'Pago');

  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'realizado', 'Entrada - Reestruturação de Infra', 16000.00, 'Projetos', v_cliente_inovatec_id, current_date - 15, current_date - 12, 'Pago');

  -- Receita a Receber (Pendente)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('receita', 'a_receber', 'Segunda Parcela - Reestruturação de Infra', 18000.00, 'Projetos', v_cliente_inovatec_id, current_date, current_date + 15, 'Pendente');

  -- Despesa Realizada (Pago)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'realizado', 'Consumo AWS Staging & Production', 5000.00, 'Infraestrutura', v_forn_techsupplies_id, current_date - 10, current_date - 8, 'Pago');

  -- Despesa a Pagar (Pendente)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'a_pagar', 'Licenças Adicionais JetBrains', 1200.00, 'Licenciamento', v_forn_techsupplies_id, current_date, current_date + 5, 'Pendente');

  -- Despesa a Pagar (Vencida)
  INSERT INTO public.lancamentos (tipo, natureza, descricao, valor, categoria, cliente_id, data_competencia, data_vencimento, status)
  VALUES ('despesa', 'a_pagar', 'Mensalidade Servidores Backup Cloud', 2000.00, 'Infraestrutura', v_forn_techsupplies_id, current_date - 5, current_date - 1, 'Pendente');

  -------------------------------------------------------------
  -- 7. SEEDS DE PROPOSTAS
  -------------------------------------------------------------
  INSERT INTO public.propostas (cliente_id, titulo, descricao, valor, status, enviada_em, created_by)
  VALUES (v_cliente_inovatec_id, 'Plataforma IA: módulo analytics', 'Módulo completo de analytics com painéis de dados.', 72000.00, 'Em análise', current_date - 5, v_comercial_id)
  RETURNING id INTO v_prop_analise_id;

  INSERT INTO public.propostas (cliente_id, titulo, descricao, valor, status, enviada_em, created_by)
  VALUES (v_cliente_dataflow_id, 'Suporte Premium 24h', 'Suporte técnico de alta disponibilidade com SLA de 2h.', 36000.00, 'Enviado', current_date - 2, v_comercial_id)
  RETURNING id INTO v_prop_enviado_id;

  INSERT INTO public.propostas (cliente_id, titulo, descricao, valor, status, enviada_em, created_by)
  VALUES (v_cliente_prime_id, 'Automação de Processos', 'Automação de fluxos e integrações API.', 45000.00, 'Aprovado', current_date - 10, v_comercial_id)
  RETURNING id INTO v_prop_aprovado_id;

  INSERT INTO public.propostas (cliente_id, titulo, descricao, valor, status, enviada_em, created_by)
  VALUES (v_cliente_inovatec_id, 'Chatbot Omnichannel', 'Chatbot de inteligência artificial com integração a canais.', 58000.00, 'Rascunho', NULL, v_comercial_id)
  RETURNING id INTO v_prop_rascunho_id;

  -------------------------------------------------------------
  -- 8. SEEDS DE CONTRATOS
  -------------------------------------------------------------
  INSERT INTO public.contratos (cliente_id, proposta_id, titulo, data_inicio, data_fim, status, valor_recorrente, created_by)
  VALUES (v_cliente_prime_id, v_prop_aprovado_id, 'Prestação de Serviços - Automação', current_date - 10, current_date + 355, 'Vigente', 5000.00, v_comercial_id)
  RETURNING id INTO v_contrato_vigente_id;

  INSERT INTO public.contratos (cliente_id, proposta_id, titulo, data_inicio, data_fim, status, valor_recorrente, created_by)
  VALUES (v_cliente_inovatec_id, NULL, 'Contrato Temporário - DevOps', current_date - 15, current_date + 10, 'Vigente', 8000.00, v_comercial_id)
  RETURNING id INTO v_contrato_proximo_id;

  INSERT INTO public.contratos (cliente_id, proposta_id, titulo, data_inicio, data_fim, status, valor_recorrente, created_by)
  VALUES (v_cliente_dataflow_id, NULL, 'Suporte Mensal Legado', current_date - 365, current_date - 5, 'Encerrado', 3000.00, v_comercial_id)
  RETURNING id INTO v_contrato_encerrado_id;

  -------------------------------------------------------------
  -- 9. SEEDS DE DOCUMENTOS
  -------------------------------------------------------------
  INSERT INTO public.documentos (tipo_relacionado, relacionado_id, nome, arquivo_url, status, enviado_por)
  VALUES ('contrato', v_contrato_vigente_id, 'contrato_firmado.pdf', 'https://supabase.local/storage/v1/object/documentos/contrato_firmado.pdf', 'Disponível', v_comercial_id);

  INSERT INTO public.documentos (tipo_relacionado, relacionado_id, nome, arquivo_url, status, enviado_por)
  VALUES ('proposta', v_prop_analise_id, 'proposta_comercial_v2.pdf', 'https://supabase.local/storage/v1/object/documentos/proposta_comercial.pdf', 'Disponível', v_comercial_id);

  -------------------------------------------------------------
  -- 10. SEEDS DE COBRANÇAS (E PAGAMENTOS COBRANÇAS)
  -------------------------------------------------------------
  -- Cobrança Pendente
  INSERT INTO public.cobrancas (cliente_id, contrato_id, lancamento_id, valor, data_vencimento, status, created_by)
  VALUES (v_cliente_prime_id, v_contrato_vigente_id, NULL, 5000.00, current_date + 10, 'Pendente', v_comercial_id)
  RETURNING id INTO v_cobranca_pendente_id;

  -- Cobrança Paga
  INSERT INTO public.cobrancas (cliente_id, contrato_id, lancamento_id, valor, data_vencimento, status, data_pagamento, created_by)
  VALUES (v_cliente_prime_id, v_contrato_vigente_id, NULL, 5000.00, current_date - 20, 'Pago', current_date - 19, v_comercial_id)
  RETURNING id INTO v_cobranca_pago_id;

  INSERT INTO public.pagamentos_cobrancas (cobranca_id, valor, pago_em, forma_pagamento, created_by)
  VALUES (v_cobranca_pago_id, 5000.00, current_date - 19, 'Pix', v_financeiro_id);

  -- Cobrança Vencida
  INSERT INTO public.cobrancas (cliente_id, contrato_id, lancamento_id, valor, data_vencimento, status, created_by)
  VALUES (v_cliente_dataflow_id, v_contrato_encerrado_id, NULL, 3000.00, current_date - 5, 'Pendente', v_comercial_id)
  RETURNING id INTO v_cobranca_vencido_id;

  -------------------------------------------------------------
  -- 11. SEEDS DE MEMBROS DA EQUIPE
  -------------------------------------------------------------
  -- Vincula personas de login aos membros da equipe
  INSERT INTO public.membros_equipe (perfil_id, nome, funcao, habilidades, status, capacidade, custo_hora)
  VALUES (
    (SELECT id FROM public.perfis WHERE usuario_id = v_tecnico_id),
    'Técnico Persona', 'Desenvolvedor Pleno', ARRAY['React', 'PostgreSQL', 'TypeScript'], 'Disponível', 80, 75.00
  ) RETURNING id INTO v_membro_tecnico_id;

  INSERT INTO public.membros_equipe (perfil_id, nome, funcao, habilidades, status, capacidade, custo_hora)
  VALUES (
    (SELECT id FROM public.perfis WHERE usuario_id = v_projetos_id),
    'Projetos Persona', 'Gerente de Projetos', ARRAY['Metodologias Ágeis', 'Scrum', 'Figma'], 'Disponível', 100, 110.00
  ) RETURNING id INTO v_membro_projetos_id;

  INSERT INTO public.membros_equipe (perfil_id, nome, funcao, habilidades, status, capacidade, custo_hora)
  VALUES (
    (SELECT id FROM public.perfis WHERE usuario_id = v_comercial_id),
    'Comercial Persona', 'Analista de Negócios', ARRAY['Vendas', 'Negociação'], 'Disponível', 100, 90.00
  ) RETURNING id INTO v_membro_comercial_id;

  INSERT INTO public.membros_equipe (perfil_id, nome, funcao, habilidades, status, capacidade, custo_hora)
  VALUES (
    (SELECT id FROM public.perfis WHERE usuario_id = v_financeiro_id),
    'Financeiro Persona', 'Controller', ARRAY['Excel', 'Contabilidade'], 'Disponível', 100, 95.00
  ) RETURNING id INTO v_membro_financeiro_id;

  INSERT INTO public.membros_equipe (perfil_id, nome, funcao, habilidades, status, capacidade, custo_hora)
  VALUES (
    (SELECT id FROM public.perfis WHERE usuario_id = v_admin_id),
    'Administrador Persona', 'Diretor Executivo', ARRAY['Gestão', 'Estratégia'], 'Disponível', 100, 150.00
  ) RETURNING id INTO v_membro_admin_id;

  -- Membro sem login associado (avulso)
  INSERT INTO public.membros_equipe (perfil_id, nome, funcao, habilidades, status, capacidade, custo_hora)
  VALUES (NULL, 'Carlos Dev', 'DevOps Senior', ARRAY['Kubernetes', 'AWS', 'Docker'], 'Alocado', 100, 120.00);

  -------------------------------------------------------------
  -- 12. SEEDS DE ALOCAÇÕES EQUIPE
  -------------------------------------------------------------
  -- Técnico alocado em Infra e Portal
  INSERT INTO public.alocacoes_equipe (membro_equipe_id, projeto_id, data_inicio, data_fim, percentual_alocacao, funcao_no_projeto)
  VALUES (v_membro_tecnico_id, v_proj_infra_id, current_date - 15, current_date + 30, 40, 'DevOps');

  INSERT INTO public.alocacoes_equipe (membro_equipe_id, projeto_id, data_inicio, data_fim, percentual_alocacao, funcao_no_projeto)
  VALUES (v_membro_tecnico_id, v_proj_portal_id, current_date - 5, current_date + 60, 40, 'Frontend Developer');

  -------------------------------------------------------------
  -- 13. SEEDS DE APONTAMENTOS DE HORAS
  -------------------------------------------------------------
  INSERT INTO public.apontamentos_horas (tarefa_id, projeto_id, membro_equipe_id, horas, descricao, data)
  VALUES (
    (SELECT id FROM public.tarefas WHERE titulo = 'Setup do Ambiente de Testes' LIMIT 1),
    v_proj_infra_id,
    v_membro_tecnico_id,
    4.50,
    'Configuração do servidor de staging e validação de deploy.',
    current_date - 2
  );

  INSERT INTO public.apontamentos_horas (tarefa_id, projeto_id, membro_equipe_id, horas, descricao, data)
  VALUES (
    (SELECT id FROM public.tarefas WHERE titulo = 'Desenho da Arquitetura SPA' LIMIT 1),
    v_proj_portal_id,
    v_membro_tecnico_id,
    6.00,
    'Modelagem inicial dos componentes React e rotas protegidas.',
    current_date - 1
  );

  -------------------------------------------------------------
  -- 14. SEEDS DE CONFIGURAÇÕES EMPRESA
  -------------------------------------------------------------
  INSERT INTO public.configuracoes_empresa (
    id, razao_social, documento, email, telefone, endereco, idioma, formato_data, moeda, dia_vencimento_padrao, percentual_multa_atraso, cobranca_automatica_ativa
  ) VALUES (
    'config_unica',
    'Aptus Flow Soluções de TI Ltda',
    '12.345.678/0001-99',
    'financeiro@aptusflow.com',
    '(11) 5555-1234',
    'Av Paulista, 1000 - São Paulo/SP',
    'pt-BR',
    'dd/MM/yyyy',
    'BRL',
    5,
    2.00,
    true
  ) ON CONFLICT (id) DO NOTHING;

  -------------------------------------------------------------
  -- 15. SEEDS DE PREFERÊNCIAS DE NOTIFICAÇÕES
  -------------------------------------------------------------
  INSERT INTO public.preferencias_notificacoes (perfil_id, canal, tipo, ativo)
  VALUES 
    ((SELECT id FROM public.perfis WHERE usuario_id = v_tecnico_id), 'Email', 'Lembretes', true),
    ((SELECT id FROM public.perfis WHERE usuario_id = v_tecnico_id), 'Sistema', 'Alertas', true),
    ((SELECT id FROM public.perfis WHERE usuario_id = v_tecnico_id), 'Email', 'Relatorio semanal', false),
    ((SELECT id FROM public.perfis WHERE usuario_id = v_tecnico_id), 'Sistema', 'Cobrancas', false),
    ((SELECT id FROM public.perfis WHERE usuario_id = v_financeiro_id), 'Email', 'Cobrancas', true),
    ((SELECT id FROM public.perfis WHERE usuario_id = v_financeiro_id), 'Sistema', 'Alertas', true);

  RAISE NOTICE 'Seed executado com sucesso: 6 personas e dados completos cadastrados.';
END $$;
