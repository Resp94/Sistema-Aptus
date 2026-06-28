-- Migration: 20260628000003_modulos_landing_rpc_clientes_read.sql
-- Funções RPC para leitura de clientes e atendimentos

-- 1. Listar Clientes
CREATE OR REPLACE FUNCTION public.listar_clientes(
  p_tipo text default null,
  p_busca text default null,
  p_status text default null
)
RETURNS TABLE (
  id uuid,
  nome_contato text,
  empresa text,
  email text,
  telefone text,
  tipo text,
  status text,
  receita numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  RETURN QUERY
  SELECT 
    c.id,
    c.nome_contato,
    c.empresa,
    c.email,
    c.telefone,
    c.tipo,
    c.status,
    COALESCE(SUM(CASE WHEN l.tipo = 'receita' THEN l.valor ELSE 0 END), 0.00)::numeric AS receita
  FROM public.clientes c
  LEFT JOIN public.lancamentos l ON l.cliente_id = c.id
  WHERE (p_tipo IS NULL OR c.tipo = p_tipo)
    AND (p_status IS NULL OR c.status = p_status)
    AND (
      p_busca IS NULL OR 
      c.nome_contato ILIKE '%' || p_busca || '%' OR 
      c.empresa ILIKE '%' || p_busca || '%' OR 
      c.email ILIKE '%' || p_busca || '%'
    )
  GROUP BY c.id, c.nome_contato, c.empresa, c.email, c.telefone, c.tipo, c.status
  ORDER BY receita DESC;
END;
$$;

-- 2. Obter Estatísticas de Clientes
CREATE OR REPLACE FUNCTION public.obter_estatisticas_clientes()
RETURNS TABLE (
  total_contatos integer,
  receita_acumulada numeric,
  ativos integer,
  fornecedores integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  RETURN QUERY
  SELECT 
    COUNT(DISTINCT c.id)::integer AS total_contatos,
    COALESCE(SUM(CASE WHEN l.tipo = 'receita' THEN l.valor ELSE 0 END), 0.00)::numeric AS receita_acumulada,
    COUNT(DISTINCT CASE WHEN c.status = 'Ativo' THEN c.id END)::integer AS ativos,
    COUNT(DISTINCT CASE WHEN c.tipo = 'fornecedor' THEN c.id END)::integer AS fornecedores
  FROM public.clientes c
  LEFT JOIN public.lancamentos l ON l.cliente_id = c.id;
END;
$$;

-- 3. Obter Detalhe do Cliente
CREATE OR REPLACE FUNCTION public.obter_cliente_detalhe(p_cliente_id uuid)
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_cliente json;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
    RAISE EXCEPTION 'Cliente não encontrado';
  END IF;

  SELECT json_build_object(
    'id', c.id,
    'nome_contato', c.nome_contato,
    'empresa', c.empresa,
    'email', c.email,
    'telefone', c.telefone,
    'tipo', c.tipo,
    'status', c.status,
    'receita', COALESCE((
      SELECT SUM(valor) 
      FROM public.lancamentos 
      WHERE cliente_id = c.id AND tipo = 'receita'
    ), 0.00),
    'historico', COALESCE((
      SELECT json_agg(
        json_build_object(
          'id', a.id,
          'data', a.data,
          'descricao', a.descricao,
          'responsavel', COALESCE(p.nome, 'Sistema')
        ) ORDER BY a.data DESC, a.created_at DESC
      )
      FROM public.atendimentos a
      LEFT JOIN public.perfis p ON p.usuario_id = a.responsavel_id
      WHERE a.cliente_id = c.id
    ), '[]'::json)
  ) INTO v_cliente
  FROM public.clientes c
  WHERE c.id = p_cliente_id;

  RETURN v_cliente;
END;
$$;
