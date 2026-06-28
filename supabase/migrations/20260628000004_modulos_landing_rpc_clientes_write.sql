-- Migration: 20260628000004_modulos_landing_rpc_clientes_write.sql
-- Funções RPC para escrita (CRUD) de clientes e atendimentos

-- 1. Criar Cliente
CREATE OR REPLACE FUNCTION public.criar_cliente(
  p_nome_contato text,
  p_empresa text,
  p_email text,
  p_telefone text,
  p_tipo text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_cliente_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF TRIM(COALESCE(p_nome_contato, '')) = '' THEN
    RAISE EXCEPTION 'Nome de contato não pode ser vazio';
  END IF;

  IF TRIM(COALESCE(p_empresa, '')) = '' THEN
    RAISE EXCEPTION 'Empresa não pode ser vazia';
  END IF;

  IF p_tipo NOT IN ('cliente', 'fornecedor') THEN
    RAISE EXCEPTION 'Tipo de contato inválido';
  END IF;

  INSERT INTO public.clientes (
    nome_contato,
    empresa,
    email,
    telefone,
    tipo,
    status,
    created_by
  ) VALUES (
    p_nome_contato,
    p_empresa,
    p_email,
    p_telefone,
    p_tipo,
    'Ativo',
    auth.uid()
  )
  RETURNING id INTO v_cliente_id;

  RETURN v_cliente_id;
END;
$$;

-- 2. Atualizar Cliente
CREATE OR REPLACE FUNCTION public.atualizar_cliente(
  p_cliente_id uuid,
  p_nome_contato text,
  p_empresa text,
  p_email text,
  p_telefone text,
  p_tipo text,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  IF TRIM(COALESCE(p_nome_contato, '')) = '' THEN
    RAISE EXCEPTION 'Nome de contato não pode ser vazio';
  END IF;

  IF TRIM(COALESCE(p_empresa, '')) = '' THEN
    RAISE EXCEPTION 'Empresa não pode ser vazia';
  END IF;

  IF p_tipo NOT IN ('cliente', 'fornecedor') THEN
    RAISE EXCEPTION 'Tipo de contato inválido';
  END IF;

  IF p_status NOT IN ('Ativo', 'Inativo') THEN
    RAISE EXCEPTION 'Status inválido';
  END IF;

  UPDATE public.clientes SET
    nome_contato = p_nome_contato,
    empresa = p_empresa,
    email = p_email,
    telefone = p_telefone,
    tipo = p_tipo,
    status = p_status,
    updated_at = now()
  WHERE id = p_cliente_id;
END;
$$;

-- 3. Inativar Cliente (Soft Delete)
CREATE OR REPLACE FUNCTION public.inativar_cliente(p_cliente_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  UPDATE public.clientes SET
    status = 'Inativo',
    updated_at = now()
  WHERE id = p_cliente_id;

  -- Registra log de auditoria
  PERFORM public.registrar_evento_auditoria('cliente_inativado', auth.uid(), null, null);
END;
$$;

-- 4. Registrar Atendimento
CREATE OR REPLACE FUNCTION public.registrar_atendimento(
  p_cliente_id uuid,
  p_descricao text,
  p_data date default current_date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_atendimento_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  IF TRIM(COALESCE(p_descricao, '')) = '' THEN
    RAISE EXCEPTION 'Descrição do atendimento não pode ser vazia';
  END IF;

  INSERT INTO public.atendimentos (
    cliente_id,
    data,
    descricao,
    responsavel_id
  ) VALUES (
    p_cliente_id,
    p_data,
    p_descricao,
    auth.uid()
  )
  RETURNING id INTO v_atendimento_id;

  RETURN v_atendimento_id;
END;
$$;
