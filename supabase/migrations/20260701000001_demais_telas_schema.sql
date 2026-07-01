-- Migration: 20260701000001_demais_telas_schema.sql
-- Atualiza a constraint de eventos em public.audit_log para conter todos os eventos anteriores e novos
ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_evento_check;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_evento_check CHECK (evento IN (
  'login_sucesso', 'login_falha', 'senha_alterada', 'usuario_criado', 'conta_desativada', 'conta_ativada',
  'projeto_excluido', 'tarefa_excluida', 'cliente_inativado',
  'proposta_excluida', 'contrato_encerrado', 'cobranca_cancelada', 'membro_equipe_inativado',
  'perfil_acesso_alterado', 'parametro_financeiro_alterado', 'configuracao_global_alterada'
));

-- 1. Propostas
CREATE TABLE IF NOT EXISTS public.propostas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  titulo text NOT NULL,
  descricao text,
  valor numeric(14,2) NOT NULL CHECK (valor >= 0),
  status text NOT NULL DEFAULT 'Rascunho' CHECK (status IN ('Rascunho', 'Enviado', 'Em análise', 'Aprovado', 'Rejeitado')),
  enviada_em timestamp with time zone,
  created_by uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 2. Contratos
CREATE TABLE IF NOT EXISTS public.contratos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  proposta_id uuid REFERENCES public.propostas(id) ON DELETE SET NULL,
  titulo text NOT NULL,
  data_inicio date NOT NULL,
  data_fim date NOT NULL,
  status text NOT NULL DEFAULT 'Vigente' CHECK (status IN ('Vigente', 'Vencimento próximo', 'Encerrado')),
  valor_recorrente numeric(14,2) NOT NULL DEFAULT 0.00 CHECK (valor_recorrente >= 0),
  created_by uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT contratos_datas_check CHECK (data_fim >= data_inicio)
);

-- 3. Documentos (anexos)
CREATE TABLE IF NOT EXISTS public.documentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_relacionado text NOT NULL CHECK (tipo_relacionado IN ('contrato', 'proposta', 'tarefa')),
  relacionado_id uuid NOT NULL,
  nome text NOT NULL,
  arquivo_url text,
  status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Disponível', 'Falhou')),
  enviado_por uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- 4. Cobranças
CREATE TABLE IF NOT EXISTS public.cobrancas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  contrato_id uuid REFERENCES public.contratos(id) ON DELETE SET NULL,
  lancamento_id uuid REFERENCES public.lancamentos(id) ON DELETE SET NULL,
  valor numeric(14,2) NOT NULL CHECK (valor > 0),
  data_vencimento date NOT NULL,
  status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Vencido', 'Cancelado')),
  data_pagamento date,
  boleto_status text NOT NULL DEFAULT 'Não configurado' CHECK (boleto_status IN ('Não configurado', 'Pendente', 'Emitido', 'Falhou')),
  lembrete_status text NOT NULL DEFAULT 'Não enviado' CHECK (lembrete_status IN ('Não enviado', 'Pendente', 'Enviado', 'Falhou')),
  created_by uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 5. Pagamentos Cobranças (Histórico)
CREATE TABLE IF NOT EXISTS public.pagamentos_cobrancas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cobranca_id uuid NOT NULL REFERENCES public.cobrancas(id) ON DELETE CASCADE,
  valor numeric(14,2) NOT NULL CHECK (valor > 0),
  pago_em date NOT NULL,
  forma_pagamento text NOT NULL CHECK (forma_pagamento IN ('Boleto', 'Pix', 'Transferência', 'Cartão', 'Outro')),
  created_by uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- 6. Membros da Equipe
CREATE TABLE IF NOT EXISTS public.membros_equipe (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id uuid UNIQUE REFERENCES public.perfis(id) ON DELETE SET NULL,
  nome text NOT NULL,
  funcao text NOT NULL,
  habilidades text[] DEFAULT '{}'::text[],
  status text NOT NULL DEFAULT 'Disponível' CHECK (status IN ('Disponível', 'Alocado', 'Férias', 'Ausente')),
  capacidade integer NOT NULL DEFAULT 100 CHECK (capacidade BETWEEN 0 AND 100),
  custo_hora numeric(14,2) NOT NULL DEFAULT 0.00 CHECK (custo_hora >= 0),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 7. Alocações Equipe (Capacidade/Histórico)
CREATE TABLE IF NOT EXISTS public.alocacoes_equipe (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membro_equipe_id uuid NOT NULL REFERENCES public.membros_equipe(id) ON DELETE CASCADE,
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  data_inicio date NOT NULL,
  data_fim date,
  percentual_alocacao integer NOT NULL CHECK (percentual_alocacao BETWEEN 1 AND 100),
  funcao_no_projeto text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 8. Apontamentos de Horas
CREATE TABLE IF NOT EXISTS public.apontamentos_horas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tarefa_id uuid REFERENCES public.tarefas(id) ON DELETE SET NULL,
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  membro_equipe_id uuid NOT NULL REFERENCES public.membros_equipe(id) ON DELETE CASCADE,
  horas numeric(6,2) NOT NULL CHECK (horas > 0),
  descricao text,
  data date NOT NULL DEFAULT current_date,
  created_at timestamp with time zone DEFAULT now()
);

-- 9. Agendamentos de Relatórios
CREATE TABLE IF NOT EXISTS public.agendamentos_relatorios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo text NOT NULL CHECK (tipo IN ('Financeiro', 'DRE', 'Clientes', 'Projetos', 'Personalizado')),
  formato text NOT NULL CHECK (formato IN ('PDF', 'CSV')),
  filtros jsonb DEFAULT '{}'::jsonb,
  frequencia text NOT NULL CHECK (frequencia IN ('Uma vez', 'Diário', 'Semanal', 'Mensal')),
  criado_por uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  agendado_para timestamp with time zone,
  status text NOT NULL DEFAULT 'Ativo' CHECK (status IN ('Ativo', 'Inativo', 'Executado')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 10. Exportações de Relatórios
CREATE TABLE IF NOT EXISTS public.exportacoes_relatorios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agendamento_id uuid REFERENCES public.agendamentos_relatorios(id) ON DELETE SET NULL,
  tipo text NOT NULL CHECK (tipo IN ('Financeiro', 'DRE', 'Clientes', 'Projetos', 'Personalizado')),
  formato text NOT NULL CHECK (formato IN ('PDF', 'CSV')),
  arquivo_url text,
  status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pronto', 'Falhou', 'Indisponível')),
  criado_por uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  gerado_em timestamp with time zone
);

-- 11. Configurações da Empresa
CREATE TABLE IF NOT EXISTS public.configuracoes_empresa (
  id text PRIMARY KEY DEFAULT 'config_unica' CHECK (id = 'config_unica'),
  razao_social text,
  documento text,
  email text,
  telefone text,
  endereco text,
  idioma text NOT NULL DEFAULT 'pt-BR',
  formato_data text NOT NULL DEFAULT 'dd/MM/yyyy',
  moeda text NOT NULL DEFAULT 'BRL',
  inicio_ano_fiscal date,
  dia_vencimento_padrao integer NOT NULL DEFAULT 5 CHECK (dia_vencimento_padrao BETWEEN 1 AND 31),
  percentual_multa_atraso numeric(5,2) NOT NULL DEFAULT 2.00 CHECK (percentual_multa_atraso >= 0),
  cobranca_automatica_ativa boolean NOT NULL DEFAULT false,
  updated_at timestamp with time zone DEFAULT now()
);

-- 12. Preferências de Notificações
CREATE TABLE IF NOT EXISTS public.preferencias_notificacoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id uuid NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
  canal text NOT NULL CHECK (canal IN ('Email', 'Sistema')),
  tipo text NOT NULL CHECK (tipo IN ('Lembretes', 'Alertas', 'Relatorio semanal', 'Cobrancas')),
  ativo boolean NOT NULL DEFAULT true,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT preferencias_notificacoes_perfil_canal_tipo_key UNIQUE (perfil_id, canal, tipo)
);

-- Índices adicionais para as novas FKs e buscas frequentes
CREATE INDEX IF NOT EXISTS idx_propostas_cliente ON public.propostas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_contratos_cliente ON public.contratos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_contratos_proposta ON public.contratos(proposta_id);
CREATE INDEX IF NOT EXISTS idx_cobrancas_cliente ON public.cobrancas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_cobrancas_contrato ON public.cobrancas(contrato_id);
CREATE INDEX IF NOT EXISTS idx_cobrancas_lancamento ON public.cobrancas(lancamento_id);
CREATE INDEX IF NOT EXISTS idx_pagamentos_cobrancas_cobranca ON public.pagamentos_cobrancas(cobranca_id);
CREATE INDEX IF NOT EXISTS idx_alocacoes_equipe_membro ON public.alocacoes_equipe(membro_equipe_id);
CREATE INDEX IF NOT EXISTS idx_alocacoes_equipe_projeto ON public.alocacoes_equipe(projeto_id);
CREATE INDEX IF NOT EXISTS idx_apontamentos_horas_membro ON public.apontamentos_horas(membro_equipe_id);
CREATE INDEX IF NOT EXISTS idx_apontamentos_horas_projeto ON public.apontamentos_horas(projeto_id);
CREATE INDEX IF NOT EXISTS idx_apontamentos_horas_tarefa ON public.apontamentos_horas(tarefa_id);
CREATE INDEX IF NOT EXISTS idx_exportacoes_relatorios_agendamento ON public.exportacoes_relatorios(agendamento_id);
CREATE INDEX IF NOT EXISTS idx_preferencias_notificacoes_perfil ON public.preferencias_notificacoes(perfil_id);
