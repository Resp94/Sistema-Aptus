-- Migration: 20260701000003_demais_telas_rpc_financeiro_read.sql
-- Implementação de funções de leitura do domínio Financeiro (Fluxo de Caixa, Contas a Pagar/Receber)

-- 1. obter_resumo_fluxo_caixa
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

-- Revogar execução pública e conceder a autenticados
REVOKE EXECUTE ON FUNCTION public.obter_resumo_fluxo_caixa(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_resumo_fluxo_caixa(date, date) TO authenticated;


-- 2. listar_fluxo_caixa
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


-- 3. obter_fluxo_caixa_series
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


-- 4. listar_contas_pagar
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


-- 5. listar_contas_receber
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


-- 6. obter_metricas_contas
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
