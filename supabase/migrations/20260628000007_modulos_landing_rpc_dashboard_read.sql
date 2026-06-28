-- Migration: 20260628000007_modulos_landing_rpc_dashboard_read.sql
-- Funções RPC para agregação e relatórios do Dashboard

-- 1. Obter Métricas do Dashboard
CREATE OR REPLACE FUNCTION public.obter_metricas_dashboard()
RETURNS TABLE (
  saldo_em_conta numeric,
  contas_receber numeric,
  cobrancas_pendentes integer,
  contas_pagar numeric,
  faturas_abertas integer,
  clientes_ativos integer,
  clientes_novos_mes integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_saldo numeric;
  v_a_receber numeric;
  v_cobrancas_pend integer;
  v_a_pagar numeric;
  v_faturas_ab integer;
  v_cli_ativos integer;
  v_cli_novos integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  -- Saldo em conta: Receitas Realizadas - Despesas Realizadas
  SELECT 
    COALESCE(SUM(CASE WHEN tipo = 'receita' AND natureza = 'realizado' THEN valor ELSE 0.00 END), 0.00) -
    COALESCE(SUM(CASE WHEN tipo = 'despesa' AND natureza = 'realizado' THEN valor ELSE 0.00 END), 0.00)
  INTO v_saldo
  FROM public.lancamentos;

  -- Contas a receber (Pendente)
  SELECT 
    COALESCE(SUM(valor), 0.00),
    COUNT(*)::integer
  INTO v_a_receber, v_cobrancas_pend
  FROM public.lancamentos
  WHERE tipo = 'receita' AND natureza = 'a_receber' AND status = 'Pendente';

  -- Contas a pagar (Pendente)
  SELECT 
    COALESCE(SUM(valor), 0.00),
    COUNT(*)::integer
  INTO v_a_pagar, v_faturas_ab
  FROM public.lancamentos
  WHERE tipo = 'despesa' AND natureza = 'a_pagar' AND status = 'Pendente';

  -- Clientes ativos
  SELECT COUNT(*)::integer INTO v_cli_ativos
  FROM public.clientes
  WHERE tipo = 'cliente' AND status = 'Ativo';

  -- Clientes novos no mês
  SELECT COUNT(*)::integer INTO v_cli_novos
  FROM public.clientes
  WHERE tipo = 'cliente' 
    AND status = 'Ativo' 
    AND date_trunc('month', created_at) = date_trunc('month', now());

  RETURN QUERY SELECT 
    v_saldo,
    v_a_receber,
    v_cobrancas_pend,
    v_a_pagar,
    v_faturas_ab,
    v_cli_ativos,
    v_cli_novos;
END;
$$;

-- 2. Obter Fluxo de Caixa Mensal (últimos N meses)
CREATE OR REPLACE FUNCTION public.obter_fluxo_caixa_mensal(p_meses integer default 6)
RETURNS TABLE (
  mes text,
  ano integer,
  total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  RETURN QUERY
  WITH meses_series AS (
    SELECT 
      to_char(g, 'TMMon') AS mes_str,
      extract(month from g)::integer AS mes_num,
      extract(year from g)::integer AS ano_num,
      g AS data_ref
    FROM generate_series(
      date_trunc('month', now()) - (p_meses - 1) * interval '1 month',
      date_trunc('month', now()),
      interval '1 month'
    ) g
  )
  SELECT 
    ms.mes_str AS mes,
    ms.ano_num AS ano,
    COALESCE(
      (
        SELECT SUM(CASE WHEN l.tipo = 'receita' THEN l.valor ELSE -l.valor END)
        FROM public.lancamentos l
        WHERE date_trunc('month', l.data_competencia) = date_trunc('month', ms.data_ref)
          AND l.natureza = 'realizado'
      ), 0.00
    )::numeric AS total
  FROM meses_series ms
  ORDER BY ms.data_ref ASC;
END;
$$;

-- 3. Listar Últimos Lançamentos
CREATE OR REPLACE FUNCTION public.listar_ultimos_lancamentos(p_limite integer default 5)
RETURNS TABLE (
  id uuid,
  descricao text,
  valor numeric,
  tipo text,
  data date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  RETURN QUERY
  SELECT 
    l.id,
    l.descricao,
    l.valor,
    l.tipo,
    l.data_competencia AS data
  FROM public.lancamentos l
  ORDER BY l.data_competencia DESC, l.created_at DESC
  LIMIT p_limite;
END;
$$;

-- 4. Listar Contas a Pagar Próximas (próximos N dias)
CREATE OR REPLACE FUNCTION public.listar_contas_pagar_proximas(p_dias integer default 7)
RETURNS TABLE (
  id uuid,
  descricao text,
  valor numeric,
  data_vencimento date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  RETURN QUERY
  SELECT 
    l.id,
    l.descricao,
    l.valor,
    l.data_vencimento
  FROM public.lancamentos l
  WHERE l.natureza = 'a_pagar'
    AND l.status = 'Pendente'
    AND l.data_vencimento BETWEEN current_date AND (current_date + p_dias)
  ORDER BY l.data_vencimento ASC;
END;
$$;

-- 5. Obter Composição de Receitas
CREATE OR REPLACE FUNCTION public.obter_composicao_receita()
RETURNS TABLE (
  categoria text,
  percentual numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_total_receitas numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT COALESCE(SUM(valor), 0.00) INTO v_total_receitas
  FROM public.lancamentos
  WHERE tipo = 'receita';

  IF v_total_receitas = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    COALESCE(l.categoria, 'Outros') AS categoria,
    ROUND((SUM(l.valor) / v_total_receitas) * 100, 2) AS percentual
  FROM public.lancamentos l
  WHERE l.tipo = 'receita'
  GROUP BY l.categoria
  ORDER BY percentual DESC;
END;
$$;
