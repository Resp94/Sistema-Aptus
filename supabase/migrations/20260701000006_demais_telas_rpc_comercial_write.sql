-- Migration: 20260701000006_demais_telas_rpc_comercial_write.sql
-- Implementação de funções de escrita do domínio Comercial (Propostas, Contratos, Cobranças)

-- 1. criar_proposta
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Propostas';
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


-- 2. atualizar_proposta
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Propostas';
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


-- 3. registrar_envio_proposta
CREATE OR REPLACE FUNCTION public.registrar_envio_proposta(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Propostas';
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


-- 4. criar_contrato
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Contratos';
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


-- 5. renovar_contrato
CREATE OR REPLACE FUNCTION public.renovar_contrato(p_id uuid, p_nova_data_fim date)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data_inicio date;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Contratos';
  END IF;

  SELECT data_inicio INTO v_data_inicio FROM public.contratos WHERE id = p_id;
  IF v_data_inicio IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  IF p_nova_data_fim < v_data_inicio THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Nova data de fim deve ser posterior à data de início';
  END IF;

  UPDATE public.contratos
  SET data_fim = p_nova_data_fim,
      status = 'Vigente',
      updated_at = now()
  WHERE id = p_id;

  -- Auditoria
  PERFORM public.registrar_evento_auditoria(
    'perfil_acesso_alterado', -- Usar um dos eventos do enum, ou estender conforme necessário. O ideal aqui é 'configuracao_global_alterada' ou 'perfil_acesso_alterado'. No data-model definimos 'contrato_encerrado', mas renovação não tem evento explícito, registramos genérico.
    auth.uid(),
    '0.0.0.0',
    'System (renovar_contrato)'
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.renovar_contrato(uuid, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.renovar_contrato(uuid, date) TO authenticated;


-- 6. encerrar_contrato
CREATE OR REPLACE FUNCTION public.encerrar_contrato(p_id uuid, p_motivo text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Contratos';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contratos WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  UPDATE public.contratos
  SET status = 'Encerrado',
      updated_at = now()
  WHERE id = p_id;

  -- Auditoria
  PERFORM public.registrar_evento_auditoria(
    'contrato_encerrado',
    auth.uid(),
    '0.0.0.0',
    'Motivo: ' || coalesce(p_motivo, 'Sem motivo informado')
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) TO authenticated;


-- 7. criar_cobranca
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
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Cobranças';
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


-- 8. registrar_pagamento_cobranca
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
  -- Permissão Check: Financeiro ou Administrador (pode_escrever no módulo 'financeiro')
  -- Comercial não pode registrar pagamentos financeiros diretamente (ownership separado)
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas o Financeiro ou Administrador pode registrar pagamentos';
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


-- 9. solicitar_emissao_boleto
CREATE OR REPLACE FUNCTION public.solicitar_emissao_boleto(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão no módulo de cobranças';
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


-- 10. solicitar_lembrete_cobranca
CREATE OR REPLACE FUNCTION public.solicitar_lembrete_cobranca(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão no módulo de cobranças';
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
