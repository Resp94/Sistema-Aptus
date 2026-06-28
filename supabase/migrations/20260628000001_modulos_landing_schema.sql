-- Migration: 20260628000001_modulos_landing_schema.sql
-- Criação das tabelas para Clientes, Atendimentos, Projetos, Tarefas, Alocações e Lançamentos

-- 1. Clientes
CREATE TABLE IF NOT EXISTS public.clientes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_contato text NOT NULL,
  empresa text NOT NULL,
  email text,
  telefone text,
  tipo text NOT NULL CHECK (tipo IN ('cliente', 'fornecedor')),
  status text NOT NULL DEFAULT 'Ativo' CHECK (status IN ('Ativo', 'Inativo')),
  created_by uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 2. Atendimentos
CREATE TABLE IF NOT EXISTS public.atendimentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  data date NOT NULL DEFAULT current_date,
  descricao text NOT NULL,
  responsavel_id uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- 3. Projetos
CREATE TABLE IF NOT EXISTS public.projetos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  cliente_id uuid REFERENCES public.clientes(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'Planejamento' CHECK (status IN ('Planejamento', 'Em andamento', 'Concluído')),
  progresso integer NOT NULL DEFAULT 0 CHECK (progresso BETWEEN 0 AND 100),
  orcamento numeric(14,2) DEFAULT 0.00 CHECK (orcamento >= 0),
  orcamento_utilizado numeric(14,2) DEFAULT 0.00 CHECK (orcamento_utilizado >= 0),
  em_risco boolean NOT NULL DEFAULT false,
  prazo date,
  created_by uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 4. Tarefas
CREATE TABLE IF NOT EXISTS public.tarefas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  titulo text NOT NULL,
  situacao text NOT NULL DEFAULT 'A Fazer' CHECK (situacao IN ('A Fazer', 'Em Andamento', 'Concluído')),
  prioridade text NOT NULL DEFAULT 'Média' CHECK (prioridade IN ('Alta', 'Média', 'Baixa')),
  responsavel_id uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  prazo date,
  instrucoes text,
  ordem integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 5. Alocações de Projeto (N:N)
CREATE TABLE IF NOT EXISTS public.alocacoes_projeto (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id uuid NOT NULL REFERENCES public.projetos(id) ON DELETE CASCADE,
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  papel text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT alocacoes_projeto_projeto_id_usuario_id_key UNIQUE (projeto_id, usuario_id)
);

-- 6. Lançamentos Financeiros
CREATE TABLE IF NOT EXISTS public.lancamentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo text NOT NULL CHECK (tipo IN ('receita', 'despesa')),
  natureza text NOT NULL CHECK (natureza IN ('a_receber', 'a_pagar', 'realizado')),
  descricao text NOT NULL,
  valor numeric(14,2) NOT NULL CHECK (valor > 0),
  categoria text,
  cliente_id uuid REFERENCES public.clientes(id) ON DELETE SET NULL,
  data_competencia date NOT NULL DEFAULT current_date,
  data_vencimento date,
  status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Vencido')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Índices para otimização de FKs e buscas comuns
CREATE INDEX IF NOT EXISTS idx_clientes_tipo ON public.clientes(tipo);
CREATE INDEX IF NOT EXISTS idx_clientes_status ON public.clientes(status);
CREATE INDEX IF NOT EXISTS idx_atendimentos_cliente ON public.atendimentos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_projetos_cliente ON public.projetos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_projetos_status ON public.projetos(status);
CREATE INDEX IF NOT EXISTS idx_tarefas_projeto ON public.tarefas(projeto_id);
CREATE INDEX IF NOT EXISTS idx_tarefas_situacao ON public.tarefas(situacao);
CREATE INDEX IF NOT EXISTS idx_alocacoes_projeto_usuario ON public.alocacoes_projeto(usuario_id);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tipo_natureza ON public.lancamentos(tipo, natureza);
CREATE INDEX IF NOT EXISTS idx_lancamentos_cliente ON public.lancamentos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_lancamentos_data_vencimento ON public.lancamentos(data_vencimento);
