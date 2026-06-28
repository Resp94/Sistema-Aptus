-- Migration: 20260628000006_modulos_landing_rpc_projetos_write.sql
-- Funções RPC para escrita (CRUD) de projetos e tarefas

-- 1. Criar Projeto
CREATE OR REPLACE FUNCTION public.criar_projeto(
  p_nome text,
  p_cliente_id uuid,
  p_orcamento numeric,
  p_prazo date,
  p_status text default 'Planejamento'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_projeto_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF TRIM(COALESCE(p_nome, '')) = '' THEN
    RAISE EXCEPTION 'Nome do projeto não pode ser vazio';
  END IF;

  IF p_orcamento < 0 THEN
    RAISE EXCEPTION 'Orçamento não pode ser negativo';
  END IF;

  IF p_status NOT IN ('Planejamento', 'Em andamento', 'Concluído') THEN
    RAISE EXCEPTION 'Status do projeto inválido';
  END IF;

  IF p_cliente_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  INSERT INTO public.projetos (
    nome,
    cliente_id,
    status,
    progresso,
    orcamento,
    orcamento_utilizado,
    em_risco,
    prazo,
    created_by
  ) VALUES (
    p_nome,
    p_cliente_id,
    p_status,
    0,
    p_orcamento,
    0.00,
    false,
    p_prazo,
    auth.uid()
  )
  RETURNING id INTO v_projeto_id;

  RETURN v_projeto_id;
END;
$$;

-- 2. Atualizar Projeto
CREATE OR REPLACE FUNCTION public.atualizar_projeto(
  p_projeto_id uuid,
  p_nome text,
  p_cliente_id uuid,
  p_status text,
  p_progresso integer,
  p_orcamento numeric,
  p_orcamento_utilizado numeric,
  p_em_risco boolean,
  p_prazo date
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto_id) THEN
    RAISE EXCEPTION 'Projeto não encontrado';
  END IF;

  IF TRIM(COALESCE(p_nome, '')) = '' THEN
    RAISE EXCEPTION 'Nome do projeto não pode ser vazio';
  END IF;

  IF p_orcamento < 0 OR p_orcamento_utilizado < 0 THEN
    RAISE EXCEPTION 'Orçamento não pode ser negativo';
  END IF;

  IF p_progresso NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION 'Progresso deve ser entre 0 e 100';
  END IF;

  IF p_status NOT IN ('Planejamento', 'Em andamento', 'Concluído') THEN
    RAISE EXCEPTION 'Status do projeto inválido';
  END IF;

  IF p_cliente_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  UPDATE public.projetos SET
    nome = p_nome,
    cliente_id = p_cliente_id,
    status = p_status,
    progresso = p_progresso,
    orcamento = p_orcamento,
    orcamento_utilizado = p_orcamento_utilizado,
    em_risco = p_em_risco,
    prazo = p_prazo,
    updated_at = now()
  WHERE id = p_projeto_id;
END;
$$;

-- 3. Excluir Projeto
CREATE OR REPLACE FUNCTION public.excluir_projeto(p_projeto_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto_id) THEN
    RAISE EXCEPTION 'Projeto não encontrado';
  END IF;

  DELETE FROM public.projetos WHERE id = p_projeto_id;

  -- Registra log de auditoria
  PERFORM public.registrar_evento_auditoria('projeto_excluido', auth.uid(), null, null);
END;
$$;

-- 4. Criar Tarefa
CREATE OR REPLACE FUNCTION public.criar_tarefa(
  p_projeto_id uuid,
  p_titulo text,
  p_prioridade text default 'Média',
  p_responsavel_id uuid default null,
  p_prazo date default null,
  p_instrucoes text default null
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_tarefa_id uuid;
  v_ordem integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto_id) THEN
    RAISE EXCEPTION 'Projeto não encontrado';
  END IF;

  IF TRIM(COALESCE(p_titulo, '')) = '' THEN
    RAISE EXCEPTION 'Título da tarefa não pode ser vazio';
  END IF;

  IF p_prioridade NOT IN ('Alta', 'Média', 'Baixa') THEN
    RAISE EXCEPTION 'Prioridade inválida';
  END IF;

  IF p_responsavel_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_responsavel_id) THEN
    RAISE EXCEPTION 'Responsável não encontrado';
  END IF;

  -- Determinar a ordem
  SELECT COALESCE(MAX(ordem), 0) + 1 INTO v_ordem
  FROM public.tarefas
  WHERE projeto_id = p_projeto_id AND situacao = 'A Fazer';

  INSERT INTO public.tarefas (
    projeto_id,
    titulo,
    situacao,
    prioridade,
    responsavel_id,
    prazo,
    instrucoes,
    ordem
  ) VALUES (
    p_projeto_id,
    p_titulo,
    'A Fazer',
    p_prioridade,
    p_responsavel_id,
    p_prazo,
    p_instrucoes,
    v_ordem
  )
  RETURNING id INTO v_tarefa_id;

  RETURN v_tarefa_id;
END;
$$;

-- 5. Atualizar Tarefa
CREATE OR REPLACE FUNCTION public.atualizar_tarefa(
  p_tarefa_id uuid,
  p_titulo text,
  p_prioridade text,
  p_responsavel_id uuid,
  p_prazo date,
  p_instrucoes text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tarefas WHERE id = p_tarefa_id) THEN
    RAISE EXCEPTION 'Tarefa não encontrada';
  END IF;

  IF TRIM(COALESCE(p_titulo, '')) = '' THEN
    RAISE EXCEPTION 'Título da tarefa não pode ser vazio';
  END IF;

  IF p_prioridade NOT IN ('Alta', 'Média', 'Baixa') THEN
    RAISE EXCEPTION 'Prioridade inválida';
  END IF;

  IF p_responsavel_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_responsavel_id) THEN
    RAISE EXCEPTION 'Responsável não encontrado';
  END IF;

  UPDATE public.tarefas SET
    titulo = p_titulo,
    prioridade = p_prioridade,
    responsavel_id = p_responsavel_id,
    prazo = p_prazo,
    instrucoes = p_instrucoes,
    updated_at = now()
  WHERE id = p_tarefa_id;
END;
$$;

-- 6. Mover Tarefa (Persistir Kanban)
CREATE OR REPLACE FUNCTION public.mover_tarefa(
  p_tarefa_id uuid,
  p_situacao text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_projeto_id uuid;
  v_ordem integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tarefas WHERE id = p_tarefa_id) THEN
    RAISE EXCEPTION 'Tarefa não encontrada';
  END IF;

  IF p_situacao NOT IN ('A Fazer', 'Em Andamento', 'Concluído') THEN
    RAISE EXCEPTION 'Situação inválida';
  END IF;

  SELECT projeto_id INTO v_projeto_id FROM public.tarefas WHERE id = p_tarefa_id;

  -- Obter próxima ordem para a nova coluna
  SELECT COALESCE(MAX(ordem), 0) + 1 INTO v_ordem
  FROM public.tarefas
  WHERE projeto_id = v_projeto_id AND situacao = p_situacao;

  UPDATE public.tarefas SET
    situacao = p_situacao,
    ordem = v_ordem,
    updated_at = now()
  WHERE id = p_tarefa_id;
END;
$$;

-- 7. Excluir Tarefa
CREATE OR REPLACE FUNCTION public.excluir_tarefa(p_tarefa_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tarefas WHERE id = p_tarefa_id) THEN
    RAISE EXCEPTION 'Tarefa não encontrada';
  END IF;

  DELETE FROM public.tarefas WHERE id = p_tarefa_id;

  -- Registra log de auditoria
  PERFORM public.registrar_evento_auditoria('tarefa_excluida', auth.uid(), null, null);
END;
$$;
