-- Migration: 20260703000000_security_hardening_fase2.sql
-- Fase 2 - Recriação das funções de domínio identificadas na auditoria guardrail
-- com identity guard e permissao_modulo padronizados.

CREATE OR REPLACE FUNCTION public.obter_resumo_fluxo_caixa(p_data_inicio date, p_data_fim date)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_saldo_inicial numeric(14,2) := 0;
  v_entradas numeric(14,2) := 0;
  v_saidas numeric(14,2) := 0;
  v_saldo_final_projetado numeric(14,2) := 0;
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (fluxo-caixa - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('fluxo-caixa') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('fluxo-caixa') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Fluxo de Caixa';
  END IF;

  -- Saldo Inicial: Soma de receitas - despesas anteriores à data de início
  SELECT coalesce(sum(CASE WHEN tipo = 'receita' THEN valor ELSE -valor END), 0) INTO v_saldo_inicial
  FROM public.lancamentos
  WHERE data_competencia < p_data_inicio;

  -- Entradas no período
  SELECT coalesce(sum(valor), 0) INTO v_entradas
  FROM public.lancamentos
  WHERE tipo = 'receita' AND data_competencia BETWEEN p_data_inicio AND p_data_fim;

  -- Saídas no período
  SELECT coalesce(sum(valor), 0) INTO v_saidas
  FROM public.lancamentos
  WHERE tipo = 'despesa' AND data_competencia BETWEEN p_data_inicio AND p_data_fim;

  -- Saldo Final Projetado: saldo inicial + entradas - saídas
  v_saldo_final_projetado := v_saldo_inicial + v_entradas - v_saidas;

  RETURN jsonb_build_object(
    'saldo_inicial', v_saldo_inicial,
    'entradas', v_entradas,
    'saidas', v_saidas,
    'saldo_final_projetado', v_saldo_final_projetado
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_resumo_fluxo_caixa(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_resumo_fluxo_caixa(date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_fluxo_caixa(
  p_data_inicio date,
  p_data_fim date,
  p_categoria text DEFAULT NULL,
  p_busca text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  tipo text,
  natureza text,
  descricao text,
  valor numeric(14,2),
  categoria text,
  cliente text,
  data_competencia date,
  data_vencimento date,
  status_exibicao text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (fluxo-caixa - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('fluxo-caixa') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('fluxo-caixa') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Fluxo de Caixa';
  END IF;

  RETURN QUERY
  SELECT 
    l.id,
    l.tipo,
    l.natureza,
    l.descricao,
    l.valor,
    l.categoria,
    coalesce(c.empresa, c.nome_contato, '') as cliente,
    l.data_competencia,
    l.data_vencimento,
    CASE 
      WHEN l.status = 'Pendente' AND l.data_vencimento < current_date THEN 'Vencido'
      ELSE l.status
    END as status_exibicao
  FROM public.lancamentos l
  LEFT JOIN public.clientes c ON l.cliente_id = c.id
  WHERE l.data_competencia BETWEEN p_data_inicio AND p_data_fim
    AND (p_categoria IS NULL OR p_categoria = '' OR l.categoria = p_categoria)
    AND (p_busca IS NULL OR p_busca = '' OR 
         l.descricao ILIKE '%' || p_busca || '%' OR 
         l.categoria ILIKE '%' || p_busca || '%' OR 
         c.empresa ILIKE '%' || p_busca || '%' OR 
         c.nome_contato ILIKE '%' || p_busca || '%')
  ORDER BY l.data_competencia DESC, l.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_fluxo_caixa(date, date, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_fluxo_caixa(date, date, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_fluxo_caixa_series(p_data_inicio date, p_data_fim date)
RETURNS TABLE (
  periodo text,
  receitas numeric(14,2),
  despesas numeric(14,2),
  saldo numeric(14,2)
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (fluxo-caixa - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('fluxo-caixa') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('fluxo-caixa') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Fluxo de Caixa';
  END IF;

  RETURN QUERY
  SELECT 
    to_char(l.data_competencia, 'yyyy-mm') as periodo,
    coalesce(sum(CASE WHEN l.tipo = 'receita' THEN l.valor ELSE 0 END), 0) as receitas,
    coalesce(sum(CASE WHEN l.tipo = 'despesa' THEN l.valor ELSE 0 END), 0) as despesas,
    coalesce(sum(CASE WHEN l.tipo = 'receita' THEN l.valor ELSE -l.valor END), 0) as saldo
  FROM public.lancamentos l
  WHERE l.data_competencia BETWEEN p_data_inicio AND p_data_fim
  GROUP BY 1
  ORDER BY 1 ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_fluxo_caixa_series(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_fluxo_caixa_series(date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_contas_pagar(
  p_status text DEFAULT NULL,
  p_fornecedor text DEFAULT NULL,
  p_data_inicio date DEFAULT NULL,
  p_data_fim date DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  descricao text,
  fornecedor text,
  data_vencimento date,
  categoria text,
  valor numeric(14,2),
  status_exibicao text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (contas-pagar - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('contas-pagar') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contas-pagar') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Contas a Pagar';
  END IF;

  RETURN QUERY
  SELECT 
    l.id,
    l.descricao,
    coalesce(c.empresa, c.nome_contato, '') as fornecedor,
    l.data_vencimento,
    l.categoria,
    l.valor,
    CASE 
      WHEN l.status = 'Pendente' AND l.data_vencimento < current_date THEN 'Vencido'
      ELSE l.status
    END as status_exibicao
  FROM public.lancamentos l
  LEFT JOIN public.clientes c ON l.cliente_id = c.id
  WHERE l.tipo = 'despesa' AND l.natureza = 'a_pagar'
    AND (p_data_inicio IS NULL OR l.data_vencimento >= p_data_inicio)
    AND (p_data_fim IS NULL OR l.data_vencimento <= p_data_fim)
    AND (p_fornecedor IS NULL OR p_fornecedor = '' OR 
         c.empresa ILIKE '%' || p_fornecedor || '%' OR 
         c.nome_contato ILIKE '%' || p_fornecedor || '%')
    AND (
      p_status IS NULL OR p_status = '' OR p_status = 'Todos' OR
      (p_status = 'Pago' AND l.status = 'Pago') OR
      (p_status = 'Pendente' AND l.status = 'Pendente' AND l.data_vencimento >= current_date) OR
      (p_status = 'Vencido' AND l.status = 'Pendente' AND l.data_vencimento < current_date)
    )
  ORDER BY l.data_vencimento ASC, l.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_contas_pagar(text, text, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_contas_pagar(text, text, date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_contas_receber(
  p_status text DEFAULT NULL,
  p_cliente_id uuid DEFAULT NULL,
  p_data_inicio date DEFAULT NULL,
  p_data_fim date DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  descricao text,
  cliente text,
  cliente_id uuid,
  data_competencia date,
  data_vencimento date,
  valor numeric(14,2),
  status_exibicao text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (contas-receber - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('contas-receber') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contas-receber') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Contas a Receber';
  END IF;

  RETURN QUERY
  SELECT 
    l.id,
    l.descricao,
    coalesce(c.empresa, c.nome_contato, '') as cliente,
    l.cliente_id,
    l.data_competencia,
    l.data_vencimento,
    l.valor,
    CASE 
      WHEN l.status = 'Pendente' AND l.data_vencimento < current_date THEN 'Vencido'
      ELSE l.status
    END as status_exibicao
  FROM public.lancamentos l
  LEFT JOIN public.clientes c ON l.cliente_id = c.id
  WHERE l.tipo = 'receita' AND l.natureza = 'a_receber'
    AND (p_data_inicio IS NULL OR l.data_vencimento >= p_data_inicio)
    AND (p_data_fim IS NULL OR l.data_vencimento <= p_data_fim)
    AND (p_cliente_id IS NULL OR l.cliente_id = p_cliente_id)
    AND (
      p_status IS NULL OR p_status = '' OR p_status = 'Todos' OR
      (p_status = 'Pago' AND l.status = 'Pago') OR
      (p_status = 'Pendente' AND l.status = 'Pendente' AND l.data_vencimento >= current_date) OR
      (p_status = 'Vencido' AND l.status = 'Pendente' AND l.data_vencimento < current_date)
    )
  ORDER BY l.data_vencimento ASC, l.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_contas_receber(text, uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_contas_receber(text, uuid, date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_metricas_contas(
  p_natureza text,
  p_data_inicio date DEFAULT NULL,
  p_data_fim date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_total_valor numeric(14,2) := 0.00;
  v_total_qtd integer := 0;
  v_vencidas_valor numeric(14,2) := 0.00;
  v_vencidas_qtd integer := 0;
  v_vencem_hoje_valor numeric(14,2) := 0.00;
  v_vencem_hoje_qtd integer := 0;
  v_proximos_7_dias_valor numeric(14,2) := 0.00;
  v_proximos_7_dias_qtd integer := 0;
  v_tipo text;
  v_modulo text;
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (financeiro - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Definir tipo e módulo com base na natureza
  IF p_natureza = 'a_pagar' THEN
    v_tipo := 'despesa';
    v_modulo := 'contas-pagar';
  ELSIF p_natureza = 'a_receber' THEN
    v_tipo := 'receita';
    v_modulo := 'contas-receber';
  ELSE
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Natureza inválida. Use a_pagar ou a_receber';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo(v_modulo) WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no módulo de contas';
  END IF;

  -- Métricas sobre os pendentes e vencidos no período
  -- 1. Total pendente
  SELECT coalesce(sum(valor), 0.00), count(id)
  INTO v_total_valor, v_total_qtd
  FROM public.lancamentos
  WHERE tipo = v_tipo AND natureza = p_natureza AND status = 'Pendente'
    AND (p_data_inicio IS NULL OR data_vencimento >= p_data_inicio)
    AND (p_data_fim IS NULL OR data_vencimento <= p_data_fim);

  -- 2. Vencidas (vencimento anterior a hoje)
  SELECT coalesce(sum(valor), 0.00), count(id)
  INTO v_vencidas_valor, v_vencidas_qtd
  FROM public.lancamentos
  WHERE tipo = v_tipo AND natureza = p_natureza AND status = 'Pendente'
    AND data_vencimento < current_date
    AND (p_data_inicio IS NULL OR data_vencimento >= p_data_inicio)
    AND (p_data_fim IS NULL OR data_vencimento <= p_data_fim);

  -- 3. Vencem hoje
  SELECT coalesce(sum(valor), 0.00), count(id)
  INTO v_vencem_hoje_valor, v_vencem_hoje_qtd
  FROM public.lancamentos
  WHERE tipo = v_tipo AND natureza = p_natureza AND status = 'Pendente'
    AND data_vencimento = current_date;

  -- 4. Próximos 7 dias (entre amanhã e hoje + 7)
  SELECT coalesce(sum(valor), 0.00), count(id)
  INTO v_proximos_7_dias_valor, v_proximos_7_dias_qtd
  FROM public.lancamentos
  WHERE tipo = v_tipo AND natureza = p_natureza AND status = 'Pendente'
    AND data_vencimento BETWEEN current_date + 1 AND current_date + 7;

  RETURN jsonb_build_object(
    'total_valor', v_total_valor,
    'total_qtd', v_total_qtd,
    'vencidas_valor', v_vencidas_valor,
    'vencidas_qtd', v_vencidas_qtd,
    'vencem_hoje_valor', v_vencem_hoje_valor,
    'vencem_hoje_qtd', v_vencem_hoje_qtd,
    'proximos_7_dias_valor', v_proximos_7_dias_valor,
    'proximos_7_dias_qtd', v_proximos_7_dias_qtd
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_metricas_contas(text, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_metricas_contas(text, date, date) TO authenticated;

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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (financeiro - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (financeiro - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('financeiro') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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

CREATE OR REPLACE FUNCTION public.listar_propostas(
  p_status text DEFAULT NULL,
  p_cliente_id uuid DEFAULT NULL,
  p_busca text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  cliente text,
  cliente_id uuid,
  titulo text,
  valor numeric(14,2),
  status text,
  enviada_em timestamp with time zone,
  created_at timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (propostas - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Propostas';
  END IF;

  RETURN QUERY
  SELECT 
    p.id,
    coalesce(c.empresa, c.nome_contato, '') as cliente,
    p.cliente_id,
    p.titulo,
    p.valor,
    p.status,
    p.enviada_em,
    p.created_at
  FROM public.propostas p
  LEFT JOIN public.clientes c ON p.cliente_id = c.id
  WHERE (p_cliente_id IS NULL OR p.cliente_id = p_cliente_id)
    AND (p_status IS NULL OR p_status = '' OR p_status = 'Todos' OR p.status = p_status)
    AND (p_busca IS NULL OR p_busca = '' OR 
         p.titulo ILIKE '%' || p_busca || '%' OR 
         c.empresa ILIKE '%' || p_busca || '%' OR 
         c.nome_contato ILIKE '%' || p_busca || '%')
  ORDER BY p.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_propostas(text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_propostas(text, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_proposta_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (propostas - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Propostas';
  END IF;

  SELECT jsonb_build_object(
    'id', p.id,
    'cliente_id', p.cliente_id,
    'empresa', c.empresa,
    'nome_contato', c.nome_contato,
    'email', c.email,
    'telefone', c.telefone,
    'titulo', p.titulo,
    'descricao', p.descricao,
    'valor', p.valor,
    'status', p.status,
    'enviada_em', p.enviada_em,
    'criado_por_nome', coalesce(cr.nome, 'Sistema'),
    'created_at', p.created_at,
    'documentos', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', d.id,
        'nome', d.nome,
        'arquivo_url', d.arquivo_url,
        'criado_em', d.created_at
      ) ORDER BY d.created_at DESC)
      FROM public.documentos d
      WHERE d.tipo_relacionado = 'proposta' AND d.relacionado_id = p.id
    ), '[]'::jsonb)
  ) INTO v_res
  FROM public.propostas p
  JOIN public.clientes c ON p.cliente_id = c.id
  LEFT JOIN public.perfis cr ON cr.usuario_id = p.created_by
  WHERE p.id = p_id;

  IF v_res IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Proposta não encontrada';
  END IF;

  RETURN v_res;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_proposta_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_proposta_detalhe(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_contratos(
  p_status text DEFAULT NULL,
  p_cliente_id uuid DEFAULT NULL,
  p_busca text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  cliente text,
  cliente_id uuid,
  titulo text,
  data_inicio date,
  data_fim date,
  status_exibicao text,
  valor_recorrente numeric(14,2)
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (contratos - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Contratos';
  END IF;

  RETURN QUERY
  SELECT 
    ct.id,
    coalesce(c.empresa, c.nome_contato, '') as cliente,
    ct.cliente_id,
    ct.titulo,
    ct.data_inicio,
    ct.data_fim,
    CASE 
      WHEN ct.status = 'Vigente' AND ct.data_fim < current_date THEN 'Encerrado'
      WHEN ct.status = 'Vigente' AND ct.data_fim BETWEEN current_date AND (current_date + 30) THEN 'Vencimento próximo'
      ELSE ct.status
    END as status_exibicao,
    ct.valor_recorrente
  FROM public.contratos ct
  LEFT JOIN public.clientes c ON ct.cliente_id = c.id
  WHERE (p_cliente_id IS NULL OR ct.cliente_id = p_cliente_id)
    AND (p_busca IS NULL OR p_busca = '' OR 
         ct.titulo ILIKE '%' || p_busca || '%' OR 
         c.empresa ILIKE '%' || p_busca || '%' OR 
         c.nome_contato ILIKE '%' || p_busca || '%')
    AND (
      p_status IS NULL OR p_status = '' OR p_status = 'Todos' OR
      (p_status = 'Vigente' AND ct.status = 'Vigente' AND ct.data_fim > (current_date + 30)) OR
      (p_status = 'Vencimento próximo' AND ct.status = 'Vigente' AND ct.data_fim BETWEEN current_date AND (current_date + 30)) OR
      (p_status = 'Encerrado' AND (ct.status = 'Encerrado' OR (ct.status = 'Vigente' AND ct.data_fim < current_date)))
    )
  ORDER BY ct.data_fim ASC, ct.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_contratos(text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_contratos(text, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_contrato_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (contratos - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Contratos';
  END IF;

  SELECT jsonb_build_object(
    'id', ct.id,
    'cliente_id', ct.cliente_id,
    'empresa', c.empresa,
    'nome_contato', c.nome_contato,
    'titulo', ct.titulo,
    'proposta_id', ct.proposta_id,
    'proposta_titulo', pr.titulo,
    'data_inicio', ct.data_inicio,
    'data_fim', ct.data_fim,
    'status_exibicao', (
      CASE
        WHEN ct.status = 'Vigente' AND ct.data_fim < current_date THEN 'Encerrado'
        WHEN ct.status = 'Vigente' AND ct.data_fim BETWEEN current_date AND (current_date + 30) THEN 'Vencimento próximo'
        ELSE ct.status
      END
    ),
    'valor_recorrente', ct.valor_recorrente,
    'created_by_nome', coalesce(cr.nome, 'Sistema'),
    'created_at', ct.created_at,
    'documentos', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', d.id,
        'nome', d.nome,
        'arquivo_url', d.arquivo_url,
        'criado_em', d.created_at
      ) ORDER BY d.created_at DESC)
      FROM public.documentos d
      WHERE d.tipo_relacionado = 'contrato' AND d.relacionado_id = ct.id
    ), '[]'::jsonb)
  ) INTO v_res
  FROM public.contratos ct
  JOIN public.clientes c ON ct.cliente_id = c.id
  LEFT JOIN public.propostas pr ON pr.id = ct.proposta_id
  LEFT JOIN public.perfis cr ON cr.usuario_id = ct.created_by
  WHERE ct.id = p_id;

  IF v_res IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  RETURN v_res;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_contrato_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_contrato_detalhe(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_cobrancas(
  p_status text DEFAULT NULL,
  p_cliente_id uuid DEFAULT NULL,
  p_data_inicio date DEFAULT NULL,
  p_data_fim date DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  cliente text,
  cliente_id uuid,
  contrato text,
  contrato_id uuid,
  valor numeric(14,2),
  data_vencimento date,
  status_exibicao text,
  boleto_status text,
  lembrete_status text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (cobrancas - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Cobranças';
  END IF;

  RETURN QUERY
  SELECT 
    cob.id,
    coalesce(c.empresa, c.nome_contato, '') as cliente,
    cob.cliente_id,
    coalesce(ct.titulo, '') as contrato,
    cob.contrato_id,
    cob.valor,
    cob.data_vencimento,
    CASE 
      WHEN cob.status = 'Pendente' AND cob.data_vencimento < current_date THEN 'Vencido'
      ELSE cob.status
    END as status_exibicao,
    cob.boleto_status,
    cob.lembrete_status
  FROM public.cobrancas cob
  LEFT JOIN public.clientes c ON cob.cliente_id = c.id
  LEFT JOIN public.contratos ct ON cob.contrato_id = ct.id
  WHERE (p_cliente_id IS NULL OR cob.cliente_id = p_cliente_id)
    AND (p_data_inicio IS NULL OR cob.data_vencimento >= p_data_inicio)
    AND (p_data_fim IS NULL OR cob.data_vencimento <= p_data_fim)
    AND (
      p_status IS NULL OR p_status = '' OR p_status = 'Todos' OR
      (p_status = 'Pago' AND cob.status = 'Pago') OR
      (p_status = 'Cancelado' AND cob.status = 'Cancelado') OR
      (p_status = 'Pendente' AND cob.status = 'Pendente' AND cob.data_vencimento >= current_date) OR
      (p_status = 'Vencido' AND cob.status = 'Pendente' AND cob.data_vencimento < current_date)
    )
  ORDER BY cob.data_vencimento ASC, cob.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_cobrancas(text, uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_cobrancas(text, uuid, date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_cobranca_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (cobrancas - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Cobranças';
  END IF;

  SELECT jsonb_build_object(
    'id', cob.id,
    'cliente_id', cob.cliente_id,
    'empresa', c.empresa,
    'contrato_id', cob.contrato_id,
    'contrato_titulo', ct.titulo,
    'lancamento_id', cob.lancamento_id,
    'valor', cob.valor,
    'data_vencimento', cob.data_vencimento,
    'status_exibicao', (
      CASE
        WHEN cob.status = 'Pendente' AND cob.data_vencimento < current_date THEN 'Vencido'
        ELSE cob.status
      END
    ),
    'data_pagamento', cob.data_pagamento,
    'forma_pagamento', (
      SELECT pc.forma_pagamento
      FROM public.pagamentos_cobrancas pc
      WHERE pc.cobranca_id = cob.id
      ORDER BY pc.pago_em DESC, pc.created_at DESC
      LIMIT 1
    ),
    'created_by_nome', coalesce(cr.nome, 'Sistema'),
    'created_at', cob.created_at
  ) INTO v_res
  FROM public.cobrancas cob
  JOIN public.clientes c ON cob.cliente_id = c.id
  LEFT JOIN public.contratos ct ON cob.contrato_id = ct.id
  LEFT JOIN public.perfis cr ON cr.usuario_id = cob.created_by
  WHERE cob.id = p_id;

  IF v_res IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Cobrança não encontrada';
  END IF;

  RETURN v_res;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_cobranca_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_cobranca_detalhe(uuid) TO authenticated;

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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (propostas - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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

CREATE OR REPLACE FUNCTION public.registrar_envio_proposta(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (propostas - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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

CREATE OR REPLACE FUNCTION public.encerrar_contrato(p_id uuid, p_motivo text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (contratos - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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

CREATE OR REPLACE FUNCTION public.solicitar_emissao_boleto(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (cobrancas - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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

CREATE OR REPLACE FUNCTION public.solicitar_lembrete_cobranca(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (cobrancas - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (contratos - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Contratos';
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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (equipe - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check: Apenas Administrador ou Projetos
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (equipe - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (equipe - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
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

CREATE OR REPLACE FUNCTION public.listar_exportacoes_relatorios(p_tipo text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  tipo text,
  formato text,
  status text,
  arquivo_url text,
  gerado_em timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (relatorios - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Relatórios';
  END IF;

  RETURN QUERY
  SELECT 
    er.id,
    er.tipo,
    er.formato,
    er.status,
    er.arquivo_url,
    er.gerado_em
  FROM public.exportacoes_relatorios er
  WHERE (p_tipo IS NULL OR p_tipo = '' OR er.tipo = p_tipo)
  ORDER BY er.gerado_em DESC, er.id DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_exportacoes_relatorios(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_exportacoes_relatorios(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_configuracoes_empresa()
RETURNS TABLE (
  id text,
  razao_social text,
  documento text,
  email text,
  telefone text,
  endereco text,
  idioma text,
  formato_data text,
  moeda text,
  inicio_ano_fiscal date,
  dia_vencimento_padrao integer,
  percentual_multa_atraso numeric(5,2),
  cobranca_automatica_ativa boolean,
  updated_at timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Apenas Administrador
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem ler as configurações globais da empresa';
  END IF;

  RETURN QUERY
  SELECT 
    ce.id,
    ce.razao_social,
    ce.documento,
    ce.email,
    ce.telefone,
    ce.endereco,
    ce.idioma,
    ce.formato_data,
    ce.moeda,
    ce.inicio_ano_fiscal,
    ce.dia_vencimento_padrao,
    ce.percentual_multa_atraso,
    ce.cobranca_automatica_ativa,
    ce.updated_at
  FROM public.configuracoes_empresa ce
  LIMIT 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_configuracoes_empresa() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_configuracoes_empresa() TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_usuarios_configuracoes()
RETURNS TABLE (
  usuario_id uuid,
  nome text,
  email text,
  perfil_acesso text,
  status text,
  departamento text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Apenas Administrador
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem listar usuários';
  END IF;

  RETURN QUERY
  SELECT 
    p.usuario_id,
    p.nome,
    u.email,
    p.perfil_acesso,
    p.status,
    p.departamento
  FROM public.perfis p
  JOIN public.usuarios u ON p.usuario_id = u.id
  ORDER BY p.nome ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_usuarios_configuracoes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_configuracoes() TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_minhas_configuracoes()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'perfil', jsonb_build_object(
      'id', p.id,
      'nome', p.nome,
      'avatar_url', p.avatar_url,
      'perfil_acesso', p.perfil_acesso,
      'status', p.status,
      'departamento', p.departamento
    ),
    'usuario', jsonb_build_object(
      'id', u.id,
      'email', u.email,
      'phone', u.phone
    )
  ) INTO v_res
  FROM public.perfis p
  JOIN public.usuarios u ON p.usuario_id = u.id
  WHERE p.usuario_id = auth.uid();

  RETURN v_res;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.obter_minhas_configuracoes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_minhas_configuracoes() TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_preferencias_notificacoes()
RETURNS TABLE (
  id uuid,
  perfil_id uuid,
  canal text,
  tipo text,
  ativo boolean
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    pn.id,
    pn.perfil_id,
    pn.canal,
    pn.tipo,
    pn.ativo
  FROM public.preferencias_notificacoes pn
  WHERE pn.perfil_id = (SELECT p.id FROM public.perfis p WHERE p.usuario_id = auth.uid());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_preferencias_notificacoes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_preferencias_notificacoes() TO authenticated;

CREATE OR REPLACE FUNCTION public.listar_logs_auditoria()
RETURNS TABLE (
  id uuid,
  evento text,
  usuario_nome text,
  ip_address text,
  detalhes text,
  criado_em timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  -- Apenas Administrador
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem ler os logs de auditoria';
  END IF;

  RETURN QUERY
  SELECT
    al.id,
    al.evento,
    coalesce(p.nome, al.usuario_id::text) as usuario_nome,
    al.ip_origem as ip_address,
    al.user_agent as detalhes,
    al.created_at as criado_em
  FROM public.audit_log al
  LEFT JOIN public.perfis p ON al.usuario_id = p.usuario_id
  ORDER BY al.created_at DESC, al.id DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_logs_auditoria() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_logs_auditoria() TO authenticated;

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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_escrever = true) THEN
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

-- Nota: `atualizar_usuario_perfil` NÃO é redefinida aqui. Por FR-005/tasks.md T015,
-- ela é um invariante existente (admin-only via existe_perfil_admin, search_path,
-- REVOKE/GRANT) que não deveria ganhar código novo — a definição vigente é a de
-- 20260702000002_security_hardening_fase0.sql.

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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_escrever = true) THEN
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
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (configuracoes - write)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_escrever = true) THEN
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

CREATE OR REPLACE FUNCTION public.listar_responsaveis_tarefas()
RETURNS TABLE (
  usuario_id uuid,
  nome text,
  perfil_acesso text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Identity guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Module guard (projetos - read)
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT p.usuario_id, p.nome, p.perfil_acesso
  FROM public.perfis p
  ORDER BY p.nome ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.listar_responsaveis_tarefas() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_responsaveis_tarefas() TO authenticated;

