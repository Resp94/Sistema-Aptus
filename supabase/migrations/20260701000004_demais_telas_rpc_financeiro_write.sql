-- Migration: 20260701000004_demais_telas_rpc_financeiro_write.sql
-- Implementação de funções de escrita do domínio Financeiro

-- 1. criar_lancamento_financeiro
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Financeiro';
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


-- 2. atualizar_lancamento_financeiro
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Financeiro';
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


-- 3. registrar_pagamento_lancamento
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Financeiro';
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
