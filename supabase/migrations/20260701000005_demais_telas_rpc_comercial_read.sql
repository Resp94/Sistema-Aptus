-- Migration: 20260701000005_demais_telas_rpc_comercial_read.sql
-- Implementação de funções de leitura do domínio Comercial (Propostas, Contratos, Cobranças)

-- 1. listar_propostas
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


-- 2. obter_proposta_detalhe
CREATE OR REPLACE FUNCTION public.obter_proposta_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Propostas';
  END IF;

  SELECT jsonb_build_object(
    'id', p.id,
    'titulo', p.titulo,
    'descricao', p.descricao,
    'valor', p.valor,
    'status', p.status,
    'enviada_em', p.enviada_em,
    'created_at', p.created_at,
    'cliente', jsonb_build_object(
      'id', c.id,
      'nome_contato', c.nome_contato,
      'empresa', c.empresa,
      'email', c.email,
      'telefone', c.telefone
    ),
    'contrato', (
      SELECT jsonb_build_object('id', ct.id, 'titulo', ct.titulo)
      FROM public.contratos ct 
      WHERE ct.proposta_id = p.id 
      LIMIT 1
    )
  ) INTO v_res
  FROM public.propostas p
  JOIN public.clientes c ON p.cliente_id = c.id
  WHERE p.id = p_id;

  IF v_res IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Proposta não encontrada';
  END IF;

  RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_proposta_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_proposta_detalhe(uuid) TO authenticated;


-- 3. listar_contratos
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


-- 4. obter_contrato_detalhe
CREATE OR REPLACE FUNCTION public.obter_contrato_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Contratos';
  END IF;

  SELECT jsonb_build_object(
    'id', ct.id,
    'titulo', ct.titulo,
    'data_inicio', ct.data_inicio,
    'data_fim', ct.data_fim,
    'status', ct.status,
    'status_exibicao', (
      CASE 
        WHEN ct.status = 'Vigente' AND ct.data_fim < current_date THEN 'Encerrado'
        WHEN ct.status = 'Vigente' AND ct.data_fim BETWEEN current_date AND (current_date + 30) THEN 'Vencimento próximo'
        ELSE ct.status
      END
    ),
    'valor_recorrente', ct.valor_recorrente,
    'created_at', ct.created_at,
    'cliente', jsonb_build_object(
      'id', c.id,
      'nome_contato', c.nome_contato,
      'empresa', c.empresa,
      'email', c.email,
      'telefone', c.telefone
    ),
    'proposta', (
      SELECT jsonb_build_object('id', p.id, 'titulo', p.titulo, 'valor', p.valor)
      FROM public.propostas p
      WHERE p.id = ct.proposta_id
      LIMIT 1
    ),
    'documentos', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', d.id,
        'nome', d.nome,
        'arquivo_url', d.arquivo_url,
        'status', d.status,
        'created_at', d.created_at
      ))
      FROM public.documentos d
      WHERE d.tipo_relacionado = 'contrato' AND d.relacionado_id = ct.id
    ), '[]'::jsonb),
    'cobrancas', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', cob.id,
        'valor', cob.valor,
        'data_vencimento', cob.data_vencimento,
        'status', cob.status,
        'status_exibicao', (
          CASE 
            WHEN cob.status = 'Pendente' AND cob.data_vencimento < current_date THEN 'Vencido'
            ELSE cob.status
          END
        )
      ))
      FROM public.cobrancas cob
      WHERE cob.contrato_id = ct.id
    ), '[]'::jsonb)
  ) INTO v_res
  FROM public.contratos ct
  JOIN public.clientes c ON ct.cliente_id = c.id
  WHERE ct.id = p_id;

  IF v_res IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_contrato_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_contrato_detalhe(uuid) TO authenticated;


-- 5. listar_cobrancas
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


-- 6. obter_cobranca_detalhe
CREATE OR REPLACE FUNCTION public.obter_cobranca_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Cobranças';
  END IF;

  SELECT jsonb_build_object(
    'id', cob.id,
    'valor', cob.valor,
    'data_vencimento', cob.data_vencimento,
    'status', cob.status,
    'status_exibicao', (
      CASE 
        WHEN cob.status = 'Pendente' AND cob.data_vencimento < current_date THEN 'Vencido'
        ELSE cob.status
      END
    ),
    'data_pagamento', cob.data_pagamento,
    'boleto_status', cob.boleto_status,
    'lembrete_status', cob.lembrete_status,
    'created_at', cob.created_at,
    'cliente', jsonb_build_object(
      'id', c.id,
      'nome_contato', c.nome_contato,
      'empresa', c.empresa,
      'email', c.email,
      'telefone', c.telefone
    ),
    'contrato', (
      CASE 
        WHEN ct.id IS NOT NULL THEN jsonb_build_object('id', ct.id, 'titulo', ct.titulo)
        ELSE NULL
      END
    ),
    'lancamento', (
      CASE 
        WHEN l.id IS NOT NULL THEN jsonb_build_object('id', l.id, 'descricao', l.descricao, 'status', l.status)
        ELSE NULL
      END
    ),
    'pagamentos', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id,
        'valor', p.valor,
        'pago_em', p.pago_em,
        'forma_pagamento', p.forma_pagamento,
        'created_at', p.created_at
      ))
      FROM public.pagamentos_cobrancas p
      WHERE p.cobranca_id = cob.id
    ), '[]'::jsonb)
  ) INTO v_res
  FROM public.cobrancas cob
  JOIN public.clientes c ON cob.cliente_id = c.id
  LEFT JOIN public.contratos ct ON cob.contrato_id = ct.id
  LEFT JOIN public.lancamentos l ON cob.lancamento_id = l.id
  WHERE cob.id = p_id;

  IF v_res IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Cobrança não encontrada';
  END IF;

  RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_cobranca_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_cobranca_detalhe(uuid) TO authenticated;
