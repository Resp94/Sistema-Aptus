-- Migration: RBAC por Capacidades Nomeadas - Guardas de RPC (feature 007)
-- Escopo: T032, T033, T034, T035, T036, T063, T067, T074, T075, T076, T077,
--         T078, T079, T080.
--
-- Recria (CREATE OR REPLACE, mesma assinatura/retorno) as RPCs de escrita e de
-- efeito de negocio listadas em
-- specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md,
-- substituindo o guard de modulo (`permissao_modulo(...).pode_escrever`) pelo
-- padrao canonico de capacidade nomeada:
--
--   IF auth.uid() IS NULL THEN
--     RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
--   END IF;
--
--   IF NOT public.tem_capacidade('<recurso.acao>') THEN
--     RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
--   END IF;
--
-- Para capacidades `*_propria`/`*_proprio` a RPC tambem valida ownership do
-- registro alvo (ver data-model.md "Entidade: Ownership"). Leituras (ex.:
-- listar_membros_equipe) continuam usando `permissao_modulo`.
--
-- Toda funcao mantem SECURITY DEFINER, SET search_path = public e
-- REVOKE/GRANT explicitos (T080).


-- ============================================================
-- 1. Clientes (T074)
-- ============================================================

CREATE OR REPLACE FUNCTION public.criar_cliente(
  p_nome_contato text,
  p_empresa text,
  p_email text,
  p_telefone text,
  p_tipo text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('clientes.criar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
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

REVOKE EXECUTE ON FUNCTION public.criar_cliente(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_cliente(text, text, text, text, text) TO authenticated;


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
SET search_path = public
AS $$
DECLARE
  v_status_atual text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT status INTO v_status_atual FROM public.clientes WHERE id = p_cliente_id;

  -- Regra especial (contracts/rpc-capability-contract.md): reativação
  -- (Inativo -> Ativo) exige clientes.reativar; qualquer outra edição
  -- (incluindo inativar por este RPC) exige clientes.editar.
  IF p_status = 'Ativo' AND v_status_atual = 'Inativo' THEN
    IF NOT public.tem_capacidade('clientes.reativar') THEN
      RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NOT public.tem_capacidade('clientes.editar') THEN
      RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
    END IF;
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

REVOKE EXECUTE ON FUNCTION public.atualizar_cliente(uuid, text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_cliente(uuid, text, text, text, text, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.inativar_cliente(p_cliente_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('clientes.inativar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  UPDATE public.clientes SET
    status = 'Inativo',
    updated_at = now()
  WHERE id = p_cliente_id;

  PERFORM public.registrar_evento_auditoria('cliente_inativado', null, null);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inativar_cliente(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.inativar_cliente(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.registrar_atendimento(
  p_cliente_id uuid,
  p_descricao text,
  p_data date default current_date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_atendimento_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('clientes.registrar_atendimento') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
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

REVOKE EXECUTE ON FUNCTION public.registrar_atendimento(uuid, text, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_atendimento(uuid, text, date) TO authenticated;


-- ============================================================
-- 2. Propostas e Contratos (T075)
-- ============================================================

CREATE OR REPLACE FUNCTION public.criar_proposta(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_cliente_id uuid;
  v_titulo text;
  v_descricao text;
  v_valor numeric(14,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('propostas.criar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_cliente_id := (payload->>'cliente_id')::uuid;
  v_titulo := payload->>'titulo';
  v_descricao := payload->>'descricao';
  v_valor := (payload->>'valor')::numeric;

  -- Validações
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Cliente é obrigatório';
  END IF;
  IF v_titulo IS NULL OR trim(v_titulo) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Título é obrigatório';
  END IF;
  IF v_valor IS NULL OR v_valor < 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor inválido';
  END IF;

  INSERT INTO public.propostas (
    cliente_id,
    titulo,
    descricao,
    valor,
    status,
    created_by
  ) VALUES (
    v_cliente_id,
    v_titulo,
    v_descricao,
    v_valor,
    'Rascunho',
    auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_proposta(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_proposta(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.atualizar_proposta(p_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_titulo text;
  v_descricao text;
  v_valor numeric(14,2);
  v_status text;
  v_old_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('propostas.editar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT status INTO v_old_status FROM public.propostas WHERE id = p_id;
  IF v_old_status IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Proposta não encontrada';
  END IF;

  v_titulo := payload->>'titulo';
  v_descricao := payload->>'descricao';
  v_valor := (payload->>'valor')::numeric;
  v_status := payload->>'status';

  -- Validações
  IF v_valor IS NOT NULL AND v_valor < 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor inválido';
  END IF;
  IF v_status IS NOT NULL AND v_status NOT IN ('Rascunho', 'Enviado', 'Em análise', 'Aprovado', 'Rejeitado') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status inválido';
  END IF;

  UPDATE public.propostas
  SET
    titulo = coalesce(v_titulo, titulo),
    descricao = coalesce(v_descricao, descricao),
    valor = coalesce(v_valor, valor),
    status = coalesce(v_status, status),
    enviada_em = CASE
      WHEN v_status = 'Enviado' AND v_old_status <> 'Enviado' THEN now()
      ELSE enviada_em
    END,
    updated_at = now()
  WHERE id = p_id;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_proposta(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_proposta(uuid, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.registrar_envio_proposta(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('propostas.enviar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.propostas WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Proposta não encontrada';
  END IF;

  -- Grava como Pendente de Integração nos logs/documentos e não altera status da proposta
  -- Retorna erro/mensagem clara simulando ausência de integração de e-mail
  RETURN jsonb_build_object(
    'status', 'Falhou',
    'erro', 'Pendente de integração',
    'mensagem', 'Integração de e-mail não configurada no sistema. O envio real da proposta não pôde ser concluído.'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_envio_proposta(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_envio_proposta(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.criar_contrato(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_cliente_id uuid;
  v_proposta_id uuid;
  v_titulo text;
  v_data_inicio date;
  v_data_fim date;
  v_valor_recorrente numeric(14,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Regra especial: contrato gerado a partir de proposta usa
  -- propostas.gerar_contrato; sem proposta vinculada usa contratos.criar.
  IF (payload->>'proposta_id') IS NOT NULL THEN
    IF NOT public.tem_capacidade('propostas.gerar_contrato') THEN
      RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NOT public.tem_capacidade('contratos.criar') THEN
      RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
    END IF;
  END IF;

  v_cliente_id := (payload->>'cliente_id')::uuid;
  v_proposta_id := (payload->>'proposta_id')::uuid;
  v_titulo := payload->>'titulo';
  v_data_inicio := (payload->>'data_inicio')::date;
  v_data_fim := (payload->>'data_fim')::date;
  v_valor_recorrente := coalesce((payload->>'valor_recorrente')::numeric, 0.00);

  -- Validações
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Cliente é obrigatório';
  END IF;
  IF v_titulo IS NULL OR trim(v_titulo) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Título é obrigatório';
  END IF;
  IF v_data_inicio IS NULL OR v_data_fim IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Vigência do contrato é obrigatória';
  END IF;
  IF v_data_fim < v_data_inicio THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Data de fim deve ser posterior ou igual à data de início';
  END IF;
  IF v_valor_recorrente < 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor recorrente inválido';
  END IF;

  INSERT INTO public.contratos (
    cliente_id,
    proposta_id,
    titulo,
    data_inicio,
    data_fim,
    status,
    valor_recorrente,
    created_by
  ) VALUES (
    v_cliente_id,
    v_proposta_id,
    v_titulo,
    v_data_inicio,
    v_data_fim,
    'Vigente',
    v_valor_recorrente,
    auth.uid()
  )
  RETURNING id INTO v_id;

  -- Se foi originado de proposta, marca a proposta como Aprovada
  IF v_proposta_id IS NOT NULL THEN
    UPDATE public.propostas SET status = 'Aprovado' WHERE id = v_proposta_id;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_contrato(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_contrato(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.renovar_contrato(
  p_id uuid,
  p_nova_data_fim date,
  p_novo_valor numeric DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data_inicio date;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('contratos.renovar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT c.data_inicio INTO v_data_inicio FROM public.contratos c WHERE c.id = p_id;
  IF v_data_inicio IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  IF p_nova_data_fim < v_data_inicio THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Nova data de fim deve ser posterior à data de início';
  END IF;

  IF p_novo_valor IS NOT NULL AND p_novo_valor <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Novo valor deve ser maior que zero';
  END IF;

  UPDATE public.contratos
  SET data_fim = p_nova_data_fim,
      valor_recorrente = coalesce(p_novo_valor, valor_recorrente),
      status = 'Vigente',
      updated_at = now()
  WHERE id = p_id;

  PERFORM public.registrar_evento_auditoria(
    'configuracao_global_alterada',
    '0.0.0.0',
    'System (renovar_contrato)'
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) TO authenticated;


CREATE OR REPLACE FUNCTION public.encerrar_contrato(p_id uuid, p_motivo text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('contratos.encerrar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contratos WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  UPDATE public.contratos
  SET status = 'Encerrado',
      updated_at = now()
  WHERE id = p_id;

  PERFORM public.registrar_evento_auditoria(
    'contrato_encerrado',
    '0.0.0.0',
    'Motivo: ' || coalesce(p_motivo, 'Sem motivo informado')
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) TO authenticated;


-- ============================================================
-- 3. Cobranças (T076)
-- ============================================================

CREATE OR REPLACE FUNCTION public.criar_cobranca(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_cliente_id uuid;
  v_contrato_id uuid;
  v_valor numeric(14,2);
  v_data_vencimento date;
  v_lancamento_id uuid;
  v_contrato_titulo text;
  v_cria_lancamento boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('cobrancas.emitir') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_cliente_id := (payload->>'cliente_id')::uuid;
  v_contrato_id := (payload->>'contrato_id')::uuid;
  v_valor := (payload->>'valor')::numeric;
  v_data_vencimento := (payload->>'data_vencimento')::date;
  v_cria_lancamento := coalesce((payload->>'cria_lancamento')::boolean, true);

  -- Validações
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Cliente é obrigatório';
  END IF;
  IF v_valor IS NULL OR v_valor <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor deve ser maior que zero';
  END IF;
  IF v_data_vencimento IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Data de vencimento é obrigatória';
  END IF;

  -- Regra de Duplicidade: Verificar se já existe cobrança com mesmos parâmetros no banco
  SELECT id INTO v_id
  FROM public.cobrancas
  WHERE cliente_id = v_cliente_id
    AND coalesce(contrato_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_contrato_id, '00000000-0000-0000-0000-000000000000'::uuid)
    AND valor = v_valor
    AND data_vencimento = v_data_vencimento
    AND status <> 'Cancelado'
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    -- Retorna o ID da cobrança existente para evitar duplicidade
    RETURN v_id;
  END IF;

  -- Criar Lançamento Financeiro a receber associado se solicitado
  IF v_cria_lancamento THEN
    IF v_contrato_id IS NOT NULL THEN
      SELECT titulo INTO v_contrato_titulo FROM public.contratos WHERE id = v_contrato_id;
    END IF;

    INSERT INTO public.lancamentos (
      tipo,
      natureza,
      descricao,
      valor,
      categoria,
      cliente_id,
      data_competencia,
      data_vencimento,
      status
    ) VALUES (
      'receita',
      'a_receber',
      coalesce('Cobrança contratual: ' || v_contrato_titulo, 'Fatura de serviços'),
      v_valor,
      'Contratos',
      v_cliente_id,
      current_date,
      v_data_vencimento,
      'Pendente'
    )
    RETURNING id INTO v_lancamento_id;
  END IF;

  -- Criar a cobrança
  INSERT INTO public.cobrancas (
    cliente_id,
    contrato_id,
    lancamento_id,
    valor,
    data_vencimento,
    status,
    created_by
  ) VALUES (
    v_cliente_id,
    v_contrato_id,
    v_lancamento_id,
    v_valor,
    v_data_vencimento,
    'Pendente',
    auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_cobranca(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_cobranca(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.solicitar_emissao_boleto(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('cobrancas.boleto') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cobrancas WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Cobrança não encontrada';
  END IF;

  -- Atualiza status do boleto
  UPDATE public.cobrancas
  SET boleto_status = 'Não configurado',
      updated_at = now()
  WHERE id = p_id;

  RETURN jsonb_build_object(
    'status', 'Não configurado',
    'mensagem', 'Emissão de boleto indisponível. O gateway de pagamentos não está configurado.'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.solicitar_emissao_boleto(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.solicitar_emissao_boleto(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.solicitar_lembrete_cobranca(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('cobrancas.notificar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cobrancas WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Cobrança não encontrada';
  END IF;

  -- Atualiza status do lembrete
  UPDATE public.cobrancas
  SET lembrete_status = 'Falhou', -- 'Falhou' ou 'Não enviado' conforme ausência de integração real
      updated_at = now()
  WHERE id = p_id;

  RETURN jsonb_build_object(
    'status', 'Falhou',
    'mensagem', 'Serviço de lembrete por e-mail/SMS indisponível no momento.'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.solicitar_lembrete_cobranca(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.solicitar_lembrete_cobranca(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.registrar_pagamento_cobranca(p_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_valor numeric(14,2);
  v_pago_em date;
  v_forma_pagamento text;
  v_lancamento_id uuid;
  v_cobranca_status text;
  v_cobranca_valor numeric(14,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('cobrancas.baixar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT status, valor, lancamento_id INTO v_cobranca_status, v_cobranca_valor, v_lancamento_id
  FROM public.cobrancas
  WHERE id = p_id;

  IF v_cobranca_status IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Cobrança não encontrada';
  END IF;

  IF v_cobranca_status = 'Pago' THEN
    RETURN true;
  END IF;

  v_valor := coalesce((payload->>'valor')::numeric, v_cobranca_valor);
  v_pago_em := coalesce((payload->>'pago_em')::date, current_date);
  v_forma_pagamento := coalesce(payload->>'forma_pagamento', 'Pix');

  -- Registrar pagamento na cobrança
  UPDATE public.cobrancas
  SET status = 'Pago',
      data_pagamento = v_pago_em,
      updated_at = now()
  WHERE id = p_id;

  -- Registrar no histórico
  INSERT INTO public.pagamentos_cobrancas (
    cobranca_id,
    valor,
    pago_em,
    forma_pagamento,
    created_by
  ) VALUES (
    p_id,
    v_valor,
    v_pago_em,
    v_forma_pagamento,
    auth.uid()
  );

  -- Sincronizar lançamento se houver
  IF v_lancamento_id IS NOT NULL THEN
    UPDATE public.lancamentos
    SET status = 'Pago',
        data_competencia = v_pago_em,
        updated_at = now()
    WHERE id = v_lancamento_id;
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_pagamento_cobranca(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_pagamento_cobranca(uuid, jsonb) TO authenticated;


-- ============================================================
-- 4. Projetos e Tarefas (T032, T033, T034)
-- ============================================================

CREATE OR REPLACE FUNCTION public.criar_projeto(
  p_nome text,
  p_cliente_id uuid,
  p_orcamento numeric,
  p_prazo date,
  p_status text default 'Planejamento'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('projetos.criar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
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

REVOKE EXECUTE ON FUNCTION public.criar_projeto(text, uuid, numeric, date, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_projeto(text, uuid, numeric, date, text) TO authenticated;


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
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('projetos.editar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
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

REVOKE EXECUTE ON FUNCTION public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date) TO authenticated;


CREATE OR REPLACE FUNCTION public.excluir_projeto(p_projeto_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('projetos.excluir') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto_id) THEN
    RAISE EXCEPTION 'Projeto não encontrado';
  END IF;

  DELETE FROM public.projetos WHERE id = p_projeto_id;

  PERFORM public.registrar_evento_auditoria('projeto_excluido', null, null);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.excluir_projeto(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.excluir_projeto(uuid) TO authenticated;


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
SET search_path = public
AS $$
DECLARE
  v_tarefa_id uuid;
  v_ordem integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('tarefas.criar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
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

REVOKE EXECUTE ON FUNCTION public.criar_tarefa(uuid, text, text, uuid, date, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_tarefa(uuid, text, text, uuid, date, text) TO authenticated;


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
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Ownership (data-model.md "Entidade: Ownership"): tarefas.responsavel_id
  -- referencia diretamente public.usuarios(id) = auth.uid() do usuário
  -- autenticado. tarefas.editar_qualquer libera qualquer responsável;
  -- tarefas.editar_propria exige responsavel_id = auth.uid().
  IF NOT (
    public.tem_capacidade('tarefas.editar_qualquer')
    OR (
      public.tem_capacidade('tarefas.editar_propria')
      AND EXISTS (
        SELECT 1 FROM public.tarefas
        WHERE id = p_tarefa_id AND responsavel_id = auth.uid()
      )
    )
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
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

REVOKE EXECUTE ON FUNCTION public.atualizar_tarefa(uuid, text, text, uuid, date, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_tarefa(uuid, text, text, uuid, date, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.mover_tarefa(
  p_tarefa_id uuid,
  p_situacao text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_projeto_id uuid;
  v_ordem integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT (
    public.tem_capacidade('tarefas.mover_qualquer')
    OR (
      public.tem_capacidade('tarefas.mover_propria')
      AND EXISTS (
        SELECT 1 FROM public.tarefas
        WHERE id = p_tarefa_id AND responsavel_id = auth.uid()
      )
    )
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tarefas WHERE id = p_tarefa_id) THEN
    RAISE EXCEPTION 'Tarefa não encontrada';
  END IF;

  IF p_situacao NOT IN ('A Fazer', 'Em Andamento', 'Concluído') THEN
    RAISE EXCEPTION 'Situação inválida';
  END IF;

  SELECT projeto_id INTO v_projeto_id FROM public.tarefas WHERE id = p_tarefa_id;

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

REVOKE EXECUTE ON FUNCTION public.mover_tarefa(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mover_tarefa(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.excluir_tarefa(p_tarefa_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('tarefas.excluir') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tarefas WHERE id = p_tarefa_id) THEN
    RAISE EXCEPTION 'Tarefa não encontrada';
  END IF;

  DELETE FROM public.tarefas WHERE id = p_tarefa_id;

  PERFORM public.registrar_evento_auditoria('tarefa_excluida', null, null);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.excluir_tarefa(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.excluir_tarefa(uuid) TO authenticated;


-- ============================================================
-- 5. Equipe e Apontamentos (T035, T036, T077)
-- ============================================================

CREATE OR REPLACE FUNCTION public.registrar_apontamento_horas(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_tarefa_id uuid;
  v_projeto_id uuid;
  v_membro_equipe_id uuid;
  v_horas numeric(6,2);
  v_descricao text;
  v_data date;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Nota (T061/T063): o cast abaixo falha naturalmente com 22P02 para a
  -- string sentinela "geral" (não é um uuid válido) — nenhum tratamento
  -- especial é adicionado para essa string, conforme contrato de dados.
  v_tarefa_id := (payload->>'tarefa_id')::uuid;
  v_projeto_id := (payload->>'projeto_id')::uuid;
  v_membro_equipe_id := (payload->>'membro_equipe_id')::uuid;
  v_horas := (payload->>'horas')::numeric;
  v_descricao := payload->>'descricao';
  v_data := coalesce((payload->>'data')::date, current_date);

  -- Ownership (data-model.md "Entidade: Ownership"): apontamentos.registrar_proprio
  -- exige que o membro_equipe_id do payload esteja vinculado (via perfil_id)
  -- ao perfil do usuário autenticado. Sem redirecionamento silencioso: se
  -- nenhuma capacidade se aplica, a chamada é rejeitada (T035).
  IF NOT (
    public.tem_capacidade('apontamentos.registrar_qualquer')
    OR (
      public.tem_capacidade('apontamentos.registrar_proprio')
      AND EXISTS (
        SELECT 1
        FROM public.membros_equipe me
        JOIN public.perfis p ON p.id = me.perfil_id
        WHERE me.id = v_membro_equipe_id AND p.usuario_id = auth.uid()
      )
    )
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Se tarefa_id for fornecido, resolve o projeto_id automaticamente caso seja nulo
  IF v_tarefa_id IS NOT NULL AND v_projeto_id IS NULL THEN
    SELECT projeto_id INTO v_projeto_id FROM public.tarefas WHERE id = v_tarefa_id;
  END IF;

  -- Validações
  IF v_projeto_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Projeto é obrigatório';
  END IF;
  IF v_membro_equipe_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Membro é obrigatório';
  END IF;
  IF v_horas IS NULL OR v_horas <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Horas devem ser maior que zero';
  END IF;

  INSERT INTO public.apontamentos_horas (
    tarefa_id,
    projeto_id,
    membro_equipe_id,
    horas,
    descricao,
    data
  ) VALUES (
    v_tarefa_id,
    v_projeto_id,
    v_membro_equipe_id,
    v_horas,
    v_descricao,
    v_data
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_apontamento_horas(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_apontamento_horas(jsonb) TO authenticated;


-- listar_membros_equipe permanece uma leitura por módulo (permissao_modulo),
-- não por capacidade nomeada. Ajuste de escopo (T036, data-model.md "Escopo
-- de Leitura: Equipe Limitada do Tecnico"): quem não tem leitura ampla de
-- equipe (hoje, na prática, só o Técnico) vê o próprio membro mais colegas
-- com alocação ativa compartilhada em projeto em andamento; perfil_id e
-- custo_hora só aparecem no próprio registro ou para quem tem leitura ampla
-- (Administrador/Projetos); projeto_atual do colega fica restrito ao
-- projeto efetivamente compartilhado.
CREATE OR REPLACE FUNCTION public.listar_membros_equipe(
  p_status text DEFAULT NULL,
  p_busca text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  perfil_id uuid,
  nome text,
  funcao text,
  habilidades text[],
  status text,
  projeto_atual text,
  capacidade integer,
  custo_hora numeric(14,2)
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
  v_pode_ver_dados_amplos boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT p.perfil_acesso INTO v_perfil_acesso
  FROM public.perfis p
  WHERE p.usuario_id = auth.uid();

  SELECT me.id INTO v_membro_id
  FROM public.membros_equipe me
  WHERE me.perfil_id = (SELECT p.id FROM public.perfis p WHERE p.usuario_id = auth.uid());

  IF v_perfil_acesso IN ('Administrador', 'Projetos') THEN
    v_pode_ver_dados_amplos := true;
  END IF;

  RETURN QUERY
  SELECT
    me.id,
    CASE WHEN me.id = v_membro_id OR v_pode_ver_dados_amplos THEN me.perfil_id ELSE NULL END AS perfil_id,
    me.nome,
    me.funcao,
    me.habilidades,
    me.status,
    CASE
      WHEN me.id = v_membro_id OR v_pode_ver_dados_amplos THEN
        coalesce((
          SELECT p.nome
          FROM public.alocacoes_equipe ae
          JOIN public.projetos p ON ae.projeto_id = p.id
          WHERE ae.membro_equipe_id = me.id
            AND p.status = 'Em andamento'
            AND (ae.data_fim IS NULL OR ae.data_fim >= current_date)
          LIMIT 1
        ), 'Sem projeto ativo')
      ELSE
        coalesce((
          SELECT p.nome
          FROM public.alocacoes_equipe ae_colega
          JOIN public.alocacoes_equipe ae_eu ON ae_colega.projeto_id = ae_eu.projeto_id
          JOIN public.projetos p ON p.id = ae_colega.projeto_id
          WHERE ae_colega.membro_equipe_id = me.id
            AND ae_eu.membro_equipe_id = v_membro_id
            AND p.status = 'Em andamento'
            AND (ae_colega.data_fim IS NULL OR ae_colega.data_fim >= current_date)
            AND (ae_eu.data_fim IS NULL OR ae_eu.data_fim >= current_date)
          LIMIT 1
        ), 'Sem projeto ativo')
    END AS projeto_atual,
    me.capacidade,
    CASE WHEN me.id = v_membro_id OR v_pode_ver_dados_amplos THEN me.custo_hora ELSE NULL END AS custo_hora
  FROM public.membros_equipe me
  WHERE (
    v_perfil_acesso IN ('Administrador', 'Projetos', 'Visualizador')
    OR me.id = v_membro_id
    OR EXISTS (
      SELECT 1
      FROM public.alocacoes_equipe ae_colega
      JOIN public.alocacoes_equipe ae_eu ON ae_colega.projeto_id = ae_eu.projeto_id
      JOIN public.projetos proj ON proj.id = ae_colega.projeto_id
      WHERE ae_colega.membro_equipe_id = me.id
        AND ae_eu.membro_equipe_id = v_membro_id
        AND proj.status = 'Em andamento'
        AND (ae_colega.data_fim IS NULL OR ae_colega.data_fim >= current_date)
        AND (ae_eu.data_fim IS NULL OR ae_eu.data_fim >= current_date)
    )
  )
    AND (p_status IS NULL OR p_status = '' OR p_status = 'Todos' OR me.status = p_status)
    AND (p_busca IS NULL OR p_busca = '' OR
         me.nome ILIKE '%' || p_busca || '%' OR
         me.funcao ILIKE '%' || p_busca || '%')
  ORDER BY me.nome ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_membros_equipe(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_membros_equipe(text, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.criar_membro_equipe(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_nome text;
  v_funcao text;
  v_habilidades text[];
  v_status text;
  v_capacidade integer;
  v_custo_hora numeric(14,2);
  v_perfil_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('equipe.adicionar_membro') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_nome := payload->>'nome';
  v_funcao := payload->>'funcao';
  v_habilidades := coalesce(array_fill(null::text, array[0]), (
    SELECT array_agg(x) FROM jsonb_array_elements_text(payload->'habilidades') x
  ), '{}'::text[]);
  v_status := coalesce(payload->>'status', 'Disponível');
  v_capacidade := coalesce((payload->>'capacidade')::integer, 100);
  v_custo_hora := coalesce((payload->>'custo_hora')::numeric, 0.00);
  v_perfil_id := (payload->>'perfil_id')::uuid;

  -- Validações
  IF v_nome IS NULL OR trim(v_nome) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Nome é obrigatório';
  END IF;
  IF v_funcao IS NULL OR trim(v_funcao) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Função é obrigatória';
  END IF;
  IF v_status NOT IN ('Disponível', 'Alocado', 'Férias', 'Ausente') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status de membro inválido';
  END IF;
  IF v_capacidade NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Capacidade deve ser entre 0 e 100';
  END IF;
  IF v_custo_hora < 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Custo por hora inválido';
  END IF;

  INSERT INTO public.membros_equipe (
    nome,
    funcao,
    habilidades,
    status,
    capacidade,
    custo_hora,
    perfil_id
  ) VALUES (
    v_nome,
    v_funcao,
    v_habilidades,
    v_status,
    v_capacidade,
    v_custo_hora,
    v_perfil_id
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_membro_equipe(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_membro_equipe(jsonb) TO authenticated;


-- atualizar_membro_equipe (T077): remove a antiga branch de nome de perfil
-- ("IF v_perfil_acesso = 'Técnico' THEN ..." permitia o Técnico editar o
-- próprio registro). O contrato desta feature só lista equipe.adicionar_membro
-- para este RPC, sem variante "própria" — ownership por relacionamento, não
-- por nome de perfil (research.md).
CREATE OR REPLACE FUNCTION public.atualizar_membro_equipe(p_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nome text;
  v_funcao text;
  v_habilidades text[];
  v_status text;
  v_capacidade integer;
  v_custo_hora numeric(14,2);
  v_perfil_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('equipe.adicionar_membro') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_nome := payload->>'nome';
  v_funcao := payload->>'funcao';
  v_habilidades := (SELECT array_agg(x) FROM jsonb_array_elements_text(payload->'habilidades') x);
  v_status := payload->>'status';
  v_capacidade := (payload->>'capacidade')::integer;
  v_custo_hora := (payload->>'custo_hora')::numeric;
  v_perfil_id := (payload->>'perfil_id')::uuid;

  UPDATE public.membros_equipe
  SET
    nome = coalesce(v_nome, nome),
    funcao = coalesce(v_funcao, funcao),
    habilidades = coalesce(v_habilidades, habilidades),
    status = coalesce(v_status, status),
    capacidade = coalesce(v_capacidade, capacidade),
    custo_hora = coalesce(v_custo_hora, custo_hora),
    perfil_id = coalesce(v_perfil_id, perfil_id),
    updated_at = now()
  WHERE id = p_id;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_membro_equipe(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_membro_equipe(uuid, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.alocar_membro_projeto(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_membro_equipe_id uuid;
  v_projeto_id uuid;
  v_data_inicio date;
  v_data_fim date;
  v_percentual_alocacao integer;
  v_funcao_no_projeto text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('equipe.alocar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_membro_equipe_id := (payload->>'membro_equipe_id')::uuid;
  v_projeto_id := (payload->>'projeto_id')::uuid;
  v_data_inicio := (payload->>'data_inicio')::date;
  v_data_fim := (payload->>'data_fim')::date;
  v_percentual_alocacao := (payload->>'percentual_alocacao')::integer;
  v_funcao_no_projeto := payload->>'funcao_no_projeto';

  -- Validações
  IF v_membro_equipe_id IS NULL OR v_projeto_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Membro e projeto são obrigatórios';
  END IF;
  IF v_data_inicio IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Data de início é obrigatória';
  END IF;
  IF v_percentual_alocacao NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Percentual de alocação deve ser entre 1 e 100';
  END IF;

  -- Verifica se já existe alocação ativa para evitar duplicidade
  SELECT id INTO v_id
  FROM public.alocacoes_equipe
  WHERE membro_equipe_id = v_membro_equipe_id AND projeto_id = v_projeto_id
    AND (data_fim IS NULL OR data_fim >= v_data_inicio)
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    -- Atualiza alocação existente
    UPDATE public.alocacoes_equipe
    SET percentual_alocacao = v_percentual_alocacao,
        data_fim = v_data_fim,
        funcao_no_projeto = coalesce(v_funcao_no_projeto, funcao_no_projeto),
        updated_at = now()
    WHERE id = v_id;
  ELSE
    -- Insere nova alocação
    INSERT INTO public.alocacoes_equipe (
      membro_equipe_id,
      projeto_id,
      data_inicio,
      data_fim,
      percentual_alocacao,
      funcao_no_projeto
    ) VALUES (
      v_membro_equipe_id,
      v_projeto_id,
      v_data_inicio,
      v_data_fim,
      v_percentual_alocacao,
      v_funcao_no_projeto
    )
    RETURNING id INTO v_id;
  END IF;

  -- Também cria um registro em public.alocacoes_projeto se não existir (para garantir a autorização técnica mínima)
  -- Obtém o usuario_id do perfil do membro de equipe
  DECLARE
    v_usuario_id uuid;
  BEGIN
    SELECT usuario_id INTO v_usuario_id FROM public.perfis WHERE id = (SELECT perfil_id FROM public.membros_equipe WHERE id = v_membro_equipe_id);
    IF v_usuario_id IS NOT NULL THEN
      INSERT INTO public.alocacoes_projeto (projeto_id, usuario_id, papel)
      VALUES (v_projeto_id, v_usuario_id, v_funcao_no_projeto)
      ON CONFLICT (projeto_id, usuario_id) DO NOTHING;
    END IF;
  END;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.alocar_membro_projeto(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.alocar_membro_projeto(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.inativar_membro_equipe(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('equipe.inativar_membro') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT perfil_id INTO v_perfil_id FROM public.membros_equipe WHERE id = p_id;
  IF v_perfil_id IS NULL AND NOT EXISTS (SELECT 1 FROM public.membros_equipe WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Membro de equipe não encontrado';
  END IF;

  UPDATE public.membros_equipe
  SET status = 'Ausente',
      capacidade = 0,
      updated_at = now()
  WHERE id = p_id;

  IF v_perfil_id IS NOT NULL THEN
    UPDATE public.perfis
    SET status = 'Inativo',
        updated_at = now()
    WHERE id = v_perfil_id;
  END IF;

  PERFORM public.registrar_evento_auditoria(
    'membro_equipe_inativado',
    '0.0.0.0',
    'Membro ID: ' || p_id::text
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) TO authenticated;


-- ============================================================
-- 6. Financeiro (T078)
-- ============================================================

CREATE OR REPLACE FUNCTION public.criar_lancamento_financeiro(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_tipo text;
  v_natureza text;
  v_descricao text;
  v_valor numeric(14,2);
  v_categoria text;
  v_cliente_id uuid;
  v_data_competencia date;
  v_data_vencimento date;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('financeiro.lancar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Parsing do payload
  v_tipo := payload->>'tipo';
  v_natureza := payload->>'natureza';
  v_descricao := payload->>'descricao';
  v_valor := (payload->>'valor')::numeric;
  v_categoria := payload->>'categoria';
  v_cliente_id := (payload->>'cliente_id')::uuid;
  v_data_competencia := coalesce((payload->>'data_competencia')::date, current_date);
  v_data_vencimento := (payload->>'data_vencimento')::date;

  -- Validações
  IF v_tipo IS NULL OR v_tipo NOT IN ('receita', 'despesa') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Tipo inválido. Deve ser receita ou despesa';
  END IF;

  IF v_natureza IS NULL OR v_natureza NOT IN ('realizado', 'a_pagar', 'a_receber') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Natureza inválida. Deve ser realizado, a_pagar ou a_receber';
  END IF;

  IF v_valor IS NULL OR v_valor <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor deve ser maior que zero';
  END IF;

  IF v_descricao IS NULL OR trim(v_descricao) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Descrição é obrigatória';
  END IF;

  -- Se for realizado, status é Pago, senão é Pendente
  IF v_natureza = 'realizado' THEN
    v_status := 'Pago';
  ELSE
    v_status := 'Pendente';
  END IF;

  -- Inserção do lançamento
  INSERT INTO public.lancamentos (
    tipo,
    natureza,
    descricao,
    valor,
    categoria,
    cliente_id,
    data_competencia,
    data_vencimento,
    status
  ) VALUES (
    v_tipo,
    v_natureza,
    v_descricao,
    v_valor,
    v_categoria,
    v_cliente_id,
    v_data_competencia,
    v_data_vencimento,
    v_status
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_lancamento_financeiro(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_lancamento_financeiro(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.atualizar_lancamento_financeiro(p_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tipo text;
  v_natureza text;
  v_descricao text;
  v_valor numeric(14,2);
  v_categoria text;
  v_cliente_id uuid;
  v_data_competencia date;
  v_data_vencimento date;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('financeiro.editar_lancamento') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Check existence
  IF NOT EXISTS (SELECT 1 FROM public.lancamentos WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Lançamento não encontrado';
  END IF;

  -- Parsing do payload
  v_tipo := payload->>'tipo';
  v_natureza := payload->>'natureza';
  v_descricao := payload->>'descricao';
  v_valor := (payload->>'valor')::numeric;
  v_categoria := payload->>'categoria';
  v_cliente_id := (payload->>'cliente_id')::uuid;
  v_data_competencia := (payload->>'data_competencia')::date;
  v_data_vencimento := (payload->>'data_vencimento')::date;
  v_status := payload->>'status';

  -- Validações (apenas se fornecidos no payload)
  IF v_tipo IS NOT NULL AND v_tipo NOT IN ('receita', 'despesa') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Tipo inválido';
  END IF;

  IF v_natureza IS NOT NULL AND v_natureza NOT IN ('realizado', 'a_pagar', 'a_receber') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Natureza inválida';
  END IF;

  IF v_valor IS NOT NULL AND v_valor <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor deve ser maior que zero';
  END IF;

  IF v_status IS NOT NULL AND v_status NOT IN ('Pendente', 'Pago', 'Vencido') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status inválido';
  END IF;

  -- Atualização do lançamento
  UPDATE public.lancamentos
  SET
    tipo = coalesce(v_tipo, tipo),
    natureza = coalesce(v_natureza, natureza),
    descricao = coalesce(v_descricao, descricao),
    valor = coalesce(v_valor, valor),
    categoria = coalesce(v_categoria, categoria),
    cliente_id = coalesce(v_cliente_id, cliente_id),
    data_competencia = coalesce(v_data_competencia, data_competencia),
    data_vencimento = coalesce(v_data_vencimento, data_vencimento),
    status = coalesce(v_status, status),
    updated_at = now()
  WHERE id = p_id;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_lancamento_financeiro(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_lancamento_financeiro(uuid, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.registrar_pagamento_lancamento(
  p_id uuid,
  p_data_pagamento date,
  p_valor numeric
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lanc_valor numeric(14,2);
  v_status text;
  v_cobranca_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('financeiro.baixar_lancamento') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Obter valor e status atual do lançamento
  SELECT valor, status INTO v_lanc_valor, v_status
  FROM public.lancamentos
  WHERE id = p_id;

  IF v_lanc_valor IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Lançamento não encontrado';
  END IF;

  -- Se já estiver pago, retorna true sem erro
  IF v_status = 'Pago' THEN
    RETURN true;
  END IF;

  -- Validação de valor (opcionalmente pode ser parcial, mas contrato diz "cobre o saldo previsto")
  IF p_valor < v_lanc_valor THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Valor pago é menor que o valor previsto do lançamento';
  END IF;

  -- Registrar pagamento no lançamento
  UPDATE public.lancamentos
  SET status = 'Pago',
      data_competencia = coalesce(p_data_pagamento, current_date),
      updated_at = now()
  WHERE id = p_id;

  -- Sincronizar com cobrança se houver alguma vinculada
  SELECT id INTO v_cobranca_id
  FROM public.cobrancas
  WHERE lancamento_id = p_id AND status <> 'Pago';

  IF v_cobranca_id IS NOT NULL THEN
    UPDATE public.cobrancas
    SET status = 'Pago',
        data_pagamento = coalesce(p_data_pagamento, current_date),
        updated_at = now()
    WHERE id = v_cobranca_id;

    -- Registrar no histórico de pagamentos da cobrança
    INSERT INTO public.pagamentos_cobrancas (
      cobranca_id,
      valor,
      pago_em,
      forma_pagamento,
      created_by
    ) VALUES (
      v_cobranca_id,
      p_valor,
      coalesce(p_data_pagamento, current_date),
      'Pix', -- Padrão assumido quando dá baixa direta pelo financeiro
      auth.uid()
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_pagamento_lancamento(uuid, date, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_pagamento_lancamento(uuid, date, numeric) TO authenticated;


-- ============================================================
-- 7. Configurações e Relatórios (T079)
-- ============================================================

CREATE OR REPLACE FUNCTION public.atualizar_configuracoes_empresa(payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_razao_social text;
  v_documento text;
  v_email text;
  v_telefone text;
  v_endereco text;
  v_idioma text;
  v_formato_data text;
  v_moeda text;
  v_inicio_ano_fiscal date;
  v_dia_vencimento_padrao integer;
  v_percentual_multa_atraso numeric(5,2);
  v_cobranca_automatica_ativa boolean;
  v_old_multa numeric(5,2);
  v_old_vencimento integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('configuracoes.editar_empresa') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem atualizar as configurações da empresa';
  END IF;

  INSERT INTO public.configuracoes_empresa (id) VALUES ('config_unica') ON CONFLICT (id) DO NOTHING;

  SELECT percentual_multa_atraso, dia_vencimento_padrao
  INTO v_old_multa, v_old_vencimento
  FROM public.configuracoes_empresa
  WHERE id = 'config_unica';

  v_razao_social := payload->>'razao_social';
  v_documento := payload->>'documento';
  v_email := payload->>'email';
  v_telefone := payload->>'telefone';
  v_endereco := payload->>'endereco';
  v_idioma := payload->>'idioma';
  v_formato_data := payload->>'formato_data';
  v_moeda := payload->>'moeda';
  v_inicio_ano_fiscal := (payload->>'inicio_ano_fiscal')::date;
  v_dia_vencimento_padrao := (payload->>'dia_vencimento_padrao')::integer;
  v_percentual_multa_atraso := (payload->>'percentual_multa_atraso')::numeric;
  v_cobranca_automatica_ativa := (payload->>'cobranca_automatica_ativa')::boolean;

  IF v_dia_vencimento_padrao IS NOT NULL AND v_dia_vencimento_padrao NOT BETWEEN 1 AND 31 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Dia de vencimento padrão deve ser entre 1 e 31';
  END IF;
  IF v_percentual_multa_atraso IS NOT NULL AND v_percentual_multa_atraso < 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Percentual de multa por atraso inválido';
  END IF;

  UPDATE public.configuracoes_empresa
  SET
    razao_social = coalesce(v_razao_social, razao_social),
    documento = coalesce(v_documento, documento),
    email = coalesce(v_email, email),
    telefone = coalesce(v_telefone, telefone),
    endereco = coalesce(v_endereco, endereco),
    idioma = coalesce(v_idioma, idioma),
    formato_data = coalesce(v_formato_data, formato_data),
    moeda = coalesce(v_moeda, moeda),
    inicio_ano_fiscal = coalesce(v_inicio_ano_fiscal, inicio_ano_fiscal),
    dia_vencimento_padrao = coalesce(v_dia_vencimento_padrao, dia_vencimento_padrao),
    percentual_multa_atraso = coalesce(v_percentual_multa_atraso, percentual_multa_atraso),
    cobranca_automatica_ativa = coalesce(v_cobranca_automatica_ativa, cobranca_automatica_ativa),
    updated_at = now()
  WHERE id = 'config_unica';

  IF (v_percentual_multa_atraso IS NOT NULL AND v_percentual_multa_atraso <> v_old_multa) OR
     (v_dia_vencimento_padrao IS NOT NULL AND v_dia_vencimento_padrao <> v_old_vencimento) THEN
    PERFORM public.registrar_evento_auditoria(
      'parametro_financeiro_alterado',
      '0.0.0.0',
      'Configurações financeiras atualizadas'
    );
  ELSE
    PERFORM public.registrar_evento_auditoria(
      'configuracao_global_alterada',
      '0.0.0.0',
      'Configurações gerais atualizadas'
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) TO authenticated;


-- atualizar_usuario_perfil (T079): permanece admin-only (ADMIN_GATED em
-- scripts/audit-rpc.mjs), mas ganha a checagem de capacidade nomeada em
-- adição ao guard existente de existe_perfil_admin (não o substitui).
CREATE OR REPLACE FUNCTION public.atualizar_usuario_perfil(p_usuario_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
  v_departamento text;
  v_old_perfil text;
  v_old_status text;
  v_old_departamento text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('configuracoes.gerenciar_usuarios') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem gerenciar perfis de terceiros';
  END IF;

  SELECT perfil_acesso, status, departamento INTO v_old_perfil, v_old_status, v_old_departamento
  FROM public.perfis
  WHERE usuario_id = p_usuario_id;

  IF v_old_perfil IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Perfil de usuário não encontrado';
  END IF;

  v_perfil_acesso := payload->>'perfil_acesso';
  v_status := payload->>'status';
  v_departamento := payload->>'departamento';

  IF v_perfil_acesso IS NOT NULL AND v_perfil_acesso NOT IN ('Administrador', 'Financeiro', 'Projetos', 'Comercial', 'Técnico', 'Visualizador') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Perfil de acesso inválido';
  END IF;
  IF v_status IS NOT NULL AND v_status NOT IN ('Ativo', 'Inativo') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status inválido';
  END IF;

  UPDATE public.perfis
  SET
    perfil_acesso = coalesce(v_perfil_acesso, perfil_acesso),
    status = coalesce(v_status, status),
    departamento = coalesce(v_departamento, departamento),
    updated_at = now()
  WHERE usuario_id = p_usuario_id;

  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
    'perfil_acesso', coalesce(v_perfil_acesso, v_old_perfil),
    'departamento', coalesce(v_departamento, v_old_departamento)
  )
  WHERE id = p_usuario_id;

  IF v_perfil_acesso IS NOT NULL AND v_perfil_acesso <> v_old_perfil THEN
    PERFORM public.registrar_evento_auditoria(
      'perfil_acesso_alterado',
      '0.0.0.0',
      'Alterado perfil de ' || p_usuario_id::text || ' de ' || v_old_perfil || ' para ' || v_perfil_acesso
    );
  END IF;

  IF v_status IS NOT NULL AND v_status <> v_old_status THEN
    DECLARE
      v_evento text := 'conta_ativada';
    BEGIN
      IF v_status = 'Inativo' THEN
        v_evento := 'conta_desativada';
      END IF;

      PERFORM public.registrar_evento_auditoria(
        v_evento,
        '0.0.0.0',
        'Alterado status de ' || p_usuario_id::text || ' para ' || v_status
      );
    END;
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_usuario_perfil(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_usuario_perfil(uuid, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.atualizar_minhas_configuracoes(payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nome text;
  v_avatar_url text;
  v_departamento text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- configuracoes.editar_proprio_perfil + ownership: a atualização já opera
  -- exclusivamente sobre o registro do próprio usuário autenticado via
  -- `WHERE usuario_id = auth.uid()` abaixo, sem parâmetro de id externo.
  IF NOT public.tem_capacidade('configuracoes.editar_proprio_perfil') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_nome := payload->>'nome';
  v_avatar_url := payload->>'avatar_url';
  v_departamento := payload->>'departamento';

  UPDATE public.perfis
  SET
    nome = coalesce(v_nome, nome),
    avatar_url = coalesce(v_avatar_url, avatar_url),
    departamento = coalesce(v_departamento, departamento),
    updated_at = now()
  WHERE usuario_id = auth.uid();

  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
    'nome', coalesce(v_nome, raw_user_meta_data->>'nome'),
    'departamento', coalesce(v_departamento, raw_user_meta_data->>'departamento')
  )
  WHERE id = auth.uid();

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_minhas_configuracoes(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_minhas_configuracoes(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.atualizar_preferencias_notificacoes(payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_id uuid;
  v_item jsonb;
  v_canal text;
  v_tipo text;
  v_ativo boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('configuracoes.editar_proprio_perfil') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT id INTO v_perfil_id FROM public.perfis WHERE usuario_id = auth.uid();
  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Perfil não encontrado';
  END IF;

  -- Se payload for uma lista de preferências, atualiza/insere cada uma
  IF jsonb_typeof(payload) = 'array' THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(payload) LOOP
      v_canal := v_item->>'canal';
      v_tipo := v_item->>'tipo';
      v_ativo := coalesce((v_item->>'ativo')::boolean, true);

      IF v_canal IN ('Email', 'Sistema') AND v_tipo IN ('Lembretes', 'Alertas', 'Relatorio semanal', 'Cobrancas') THEN
        INSERT INTO public.preferencias_notificacoes (perfil_id, canal, tipo, ativo, updated_at)
        VALUES (v_perfil_id, v_canal, v_tipo, v_ativo, now())
        ON CONFLICT (perfil_id, canal, tipo)
        DO UPDATE SET ativo = EXCLUDED.ativo, updated_at = now();
      END IF;
    END LOOP;
  ELSE
    -- Se for um objeto único
    v_canal := payload->>'canal';
    v_tipo := payload->>'tipo';
    v_ativo := coalesce((payload->>'ativo')::boolean, true);

    IF v_canal IN ('Email', 'Sistema') AND v_tipo IN ('Lembretes', 'Alertas', 'Relatorio semanal', 'Cobrancas') THEN
      INSERT INTO public.preferencias_notificacoes (perfil_id, canal, tipo, ativo, updated_at)
      VALUES (v_perfil_id, v_canal, v_tipo, v_ativo, now())
      ON CONFLICT (perfil_id, canal, tipo)
      DO UPDATE SET ativo = EXCLUDED.ativo, updated_at = now();
    ELSE
      RAISE EXCEPTION 'validation_error' USING DETAIL = 'Parâmetros de notificação inválidos';
    END IF;
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_preferencias_notificacoes(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_preferencias_notificacoes(jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.solicitar_exportacao_relatorio(
  p_tipo text,
  p_formato text,
  p_filtros jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Insere o registro de exportação com status 'Indisponível' (sem simular sucesso falso)
  INSERT INTO public.exportacoes_relatorios (
    tipo,
    formato,
    status,
    arquivo_url,
    criado_por,
    gerado_em
  ) VALUES (
    p_tipo,
    p_formato,
    'Indisponível',
    NULL, -- arquivo_url nulo pois não há gerador de PDF/CSV configurado no backend
    auth.uid(),
    now()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.agendar_relatorio(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_tipo text;
  v_formato text;
  v_filtros jsonb;
  v_frequencia text;
  v_agendado_para timestamp with time zone;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_tipo := payload->>'tipo';
  v_formato := payload->>'formato';
  v_filtros := coalesce(payload->'filtros', '{}'::jsonb);
  v_frequencia := payload->>'frequencia';
  v_agendado_para := (payload->>'agendado_para')::timestamp with time zone;

  -- Validações
  IF v_tipo NOT IN ('Financeiro', 'DRE', 'Clientes', 'Projetos', 'Personalizado') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Tipo de relatório inválido';
  END IF;
  IF v_formato NOT IN ('PDF', 'CSV') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Formato inválido';
  END IF;
  IF v_frequencia NOT IN ('Uma vez', 'Diário', 'Semanal', 'Mensal') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Frequência inválida';
  END IF;

  INSERT INTO public.agendamentos_relatorios (
    tipo,
    formato,
    filtros,
    frequencia,
    criado_por,
    agendado_para,
    status
  ) VALUES (
    v_tipo,
    v_formato,
    v_filtros,
    v_frequencia,
    auth.uid(),
    v_agendado_para,
    'Ativo'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.agendar_relatorio(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agendar_relatorio(jsonb) TO authenticated;
