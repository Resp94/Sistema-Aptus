-- Migration: Fase 1 - Padronização retroativa das funções legadas
-- Escopo: FR-008, FR-009, FR-010, FR-011
-- Padroniza 26 funções da geração antiga com search_path fixo, guarda de identidade,
-- REVOKE/GRANT explícitos e preservação de assinatura/comportamento.

-- ============================================================
-- Helpers de permissão/perfil (3)
-- ============================================================

CREATE OR REPLACE FUNCTION public.permissao_modulo(p_modulo text)
RETURNS TABLE (pode_ler boolean, pode_escrever boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT p.pode_ler, p.pode_escrever
  FROM public.obter_permissoes_usuario() p
  WHERE p.modulo = p_modulo;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.permissao_modulo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.permissao_modulo(text) TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_permissoes_usuario()
RETURNS TABLE (
  modulo text,
  pode_ler boolean,
  pode_escrever boolean
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET row_security = off
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT perfis.perfil_acesso, perfis.status INTO v_perfil_acesso, v_status
  FROM public.perfis
  WHERE usuario_id = auth.uid();

  IF v_status <> 'Ativo' OR v_perfil_acesso IS NULL THEN
    RETURN;
  END IF;

  IF v_perfil_acesso = 'Administrador' THEN
    RETURN QUERY VALUES
      ('dashboard', true, true),
      ('clientes', true, true),
      ('propostas', true, true),
      ('contratos', true, true),
      ('cobrancas', true, true),
      ('projetos', true, true),
      ('equipe', true, true),
      ('financeiro', true, true),
      ('fluxo-caixa', true, true),
      ('contas-pagar', true, true),
      ('contas-receber', true, true),
      ('relatorios', true, true),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Financeiro' THEN
    RETURN QUERY VALUES
      ('dashboard', true, true),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', true, true),
      ('projetos', false, false),
      ('equipe', false, false),
      ('financeiro', true, true),
      ('fluxo-caixa', true, true),
      ('contas-pagar', true, true),
      ('contas-receber', true, true),
      ('relatorios', true, true),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Projetos' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', false, false),
      ('projetos', true, true),
      ('equipe', true, true),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', true, true),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Comercial' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', true, true),
      ('propostas', true, true),
      ('contratos', true, true),
      ('cobrancas', true, true),
      ('projetos', false, false),
      ('equipe', false, false),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', false, false),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Técnico' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', false, false),
      ('projetos', true, true),
      ('equipe', true, false),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', false, false),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Visualizador' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', true, false),
      ('propostas', true, false),
      ('contratos', true, false),
      ('cobrancas', true, false),
      ('projetos', true, false),
      ('equipe', true, false),
      ('financeiro', true, false),
      ('fluxo-caixa', true, false),
      ('contas-pagar', true, false),
      ('contas-receber', true, false),
      ('relatorios', true, false),
      ('configuracoes', true, false);
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_permissoes_usuario() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_permissoes_usuario() TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_perfil_usuario()
RETURNS TABLE (
  nome text,
  perfil_acesso text,
  status text,
  avatar_url text,
  departamento text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET row_security = off
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT p.nome, p.perfil_acesso, p.status, p.avatar_url, p.departamento
  FROM public.perfis p
  WHERE p.usuario_id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_perfil_usuario() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_perfil_usuario() TO authenticated;


-- ============================================================
-- Clientes e atendimentos (7)
-- ============================================================

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
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.listar_clientes(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_clientes(text, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_estatisticas_clientes()
RETURNS TABLE (
  total_contatos integer,
  receita_acumulada numeric,
  ativos integer,
  fornecedores integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.obter_estatisticas_clientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_estatisticas_clientes() TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_cliente_detalhe(p_cliente_id uuid)
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente json;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.obter_cliente_detalhe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_cliente_detalhe(uuid) TO authenticated;


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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.registrar_atendimento(uuid, text, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_atendimento(uuid, text, date) TO authenticated;


-- ============================================================
-- Projetos e tarefas (11)
-- ============================================================

CREATE OR REPLACE FUNCTION public.listar_projetos()
RETURNS TABLE (
  id uuid,
  nome text,
  cliente text,
  status text,
  progresso integer,
  orcamento numeric,
  orcamento_utilizado numeric,
  em_risco boolean,
  prazo date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT perfil_acesso INTO v_perfil FROM public.perfis WHERE usuario_id = auth.uid();

  RETURN QUERY
  SELECT
    p.id,
    p.nome,
    COALESCE(c.empresa, '') AS cliente,
    p.status,
    p.progresso,
    p.orcamento,
    p.orcamento_utilizado,
    p.em_risco,
    p.prazo
  FROM public.projetos p
  LEFT JOIN public.clientes c ON c.id = p.cliente_id
  WHERE (
    v_perfil <> 'Técnico'
    OR EXISTS (
      SELECT 1 FROM public.alocacoes_projeto ap
      WHERE ap.projeto_id = p.id AND ap.usuario_id = auth.uid()
    )
  )
  ORDER BY p.nome ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_projetos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_projetos() TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_resumo_projetos()
RETURNS TABLE (
  projetos_ativos integer,
  tarefas_abertas integer,
  orcamento_total numeric,
  orcamento_utilizado_pct integer,
  em_risco integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT perfil_acesso INTO v_perfil FROM public.perfis WHERE usuario_id = auth.uid();

  RETURN QUERY
  WITH projetos_visiveis AS (
    SELECT p.id, p.status, p.orcamento, p.orcamento_utilizado, p.em_risco
    FROM public.projetos p
    WHERE (
      v_perfil <> 'Técnico'
      OR EXISTS (
        SELECT 1 FROM public.alocacoes_projeto ap
        WHERE ap.projeto_id = p.id AND ap.usuario_id = auth.uid()
      )
    )
  ),
  metricas_proj AS (
    SELECT
      COUNT(pv.id)::integer AS total_ativos,
      COALESCE(SUM(pv.orcamento), 0.00) AS total_orc,
      COALESCE(SUM(pv.orcamento_utilizado), 0.00) AS total_utilizado,
      COUNT(CASE WHEN pv.em_risco = true THEN 1 END)::integer AS total_risco
    FROM projetos_visiveis pv
    WHERE pv.status IN ('Planejamento', 'Em andamento')
  ),
  metricas_tarefas AS (
    SELECT COUNT(t.id)::integer AS abertas
    FROM public.tarefas t
    JOIN projetos_visiveis pv ON pv.id = t.projeto_id
    WHERE t.situacao IN ('A Fazer', 'Em Andamento')
  )
  SELECT
    mp.total_ativos,
    mt.abertas,
    mp.total_orc,
    CASE
      WHEN mp.total_orc > 0 THEN ROUND((mp.total_utilizado / mp.total_orc) * 100)::integer
      ELSE 0
    END AS orc_utilizado_pct,
    mp.total_risco
  FROM metricas_proj mp, metricas_tarefas mt;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_resumo_projetos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_resumo_projetos() TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_distribuicao_clientes()
RETURNS TABLE (
  cliente text,
  percentual numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil text;
  v_total_projetos bigint;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT perfil_acesso INTO v_perfil FROM public.perfis WHERE usuario_id = auth.uid();

  SELECT COUNT(*) INTO v_total_projetos
  FROM public.projetos p
  WHERE (
    v_perfil <> 'Técnico'
    OR EXISTS (
      SELECT 1 FROM public.alocacoes_projeto ap
      WHERE ap.projeto_id = p.id AND ap.usuario_id = auth.uid()
    )
  );

  IF v_total_projetos = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(c.empresa, 'Sem Cliente') AS cliente,
    ROUND((COUNT(p.id)::numeric / v_total_projetos) * 100, 2) AS percentual
  FROM public.projetos p
  LEFT JOIN public.clientes c ON c.id = p.cliente_id
  WHERE (
    v_perfil <> 'Técnico'
    OR EXISTS (
      SELECT 1 FROM public.alocacoes_projeto ap
      WHERE ap.projeto_id = p.id AND ap.usuario_id = auth.uid()
    )
  )
  GROUP BY c.empresa
  ORDER BY percentual DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_distribuicao_clientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_distribuicao_clientes() TO authenticated;


CREATE OR REPLACE FUNCTION public.listar_tarefas_kanban()
RETURNS TABLE (
  id uuid,
  projeto_id uuid,
  projeto text,
  titulo text,
  situacao text,
  prioridade text,
  responsavel text,
  prazo date,
  instrucoes text,
  ordem integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT perfil_acesso INTO v_perfil FROM public.perfis WHERE usuario_id = auth.uid();

  RETURN QUERY
  SELECT
    t.id,
    t.projeto_id,
    p.nome AS projeto,
    t.titulo,
    t.situacao,
    t.prioridade,
    COALESCE(perf.nome, '') AS responsavel,
    t.prazo,
    t.instrucoes,
    t.ordem
  FROM public.tarefas t
  JOIN public.projetos p ON p.id = t.projeto_id
  LEFT JOIN public.perfis perf ON perf.usuario_id = t.responsavel_id
  WHERE (
    v_perfil <> 'Técnico'
    OR EXISTS (
      SELECT 1 FROM public.alocacoes_projeto ap
      WHERE ap.projeto_id = p.id AND ap.usuario_id = auth.uid()
    )
  )
  ORDER BY t.ordem ASC, t.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_tarefas_kanban() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_tarefas_kanban() TO authenticated;


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

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
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

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true) THEN
    RAISE EXCEPTION 'Sem permissão de escrita';
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
-- Dashboard (5)
-- ============================================================

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
SET search_path = public
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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT
    COALESCE(SUM(CASE WHEN tipo = 'receita' AND natureza = 'realizado' THEN valor ELSE 0.00 END), 0.00) -
    COALESCE(SUM(CASE WHEN tipo = 'despesa' AND natureza = 'realizado' THEN valor ELSE 0.00 END), 0.00)
  INTO v_saldo
  FROM public.lancamentos;

  SELECT
    COALESCE(SUM(valor), 0.00),
    COUNT(*)::integer
  INTO v_a_receber, v_cobrancas_pend
  FROM public.lancamentos
  WHERE tipo = 'receita' AND natureza = 'a_receber' AND status = 'Pendente';

  SELECT
    COALESCE(SUM(valor), 0.00),
    COUNT(*)::integer
  INTO v_a_pagar, v_faturas_ab
  FROM public.lancamentos
  WHERE tipo = 'despesa' AND natureza = 'a_pagar' AND status = 'Pendente';

  SELECT COUNT(*)::integer INTO v_cli_ativos
  FROM public.clientes
  WHERE tipo = 'cliente' AND status = 'Ativo';

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

REVOKE EXECUTE ON FUNCTION public.obter_metricas_dashboard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_metricas_dashboard() TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_fluxo_caixa_mensal(p_meses integer default 6)
RETURNS TABLE (
  mes text,
  ano integer,
  total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.obter_fluxo_caixa_mensal(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_fluxo_caixa_mensal(integer) TO authenticated;


CREATE OR REPLACE FUNCTION public.listar_ultimos_lancamentos(p_limite integer default 5)
RETURNS TABLE (
  id uuid,
  descricao text,
  valor numeric,
  tipo text,
  data date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.listar_ultimos_lancamentos(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_ultimos_lancamentos(integer) TO authenticated;


CREATE OR REPLACE FUNCTION public.listar_contas_pagar_proximas(p_dias integer default 7)
RETURNS TABLE (
  id uuid,
  descricao text,
  valor numeric,
  data_vencimento date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.listar_contas_pagar_proximas(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_contas_pagar_proximas(integer) TO authenticated;


CREATE OR REPLACE FUNCTION public.obter_composicao_receita()
RETURNS TABLE (
  categoria text,
  percentual numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_receitas numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.obter_composicao_receita() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_composicao_receita() TO authenticated;

-- Nota: `listar_responsaveis_tarefas` foi definida aqui originalmente sem o guard
-- de `permissao_modulo`. A definição vigente (com o guard completo) está em
-- 20260703000000_security_hardening_fase2.sql, que substitui esta via
-- CREATE OR REPLACE. Removida daqui para não manter duas fontes divergentes.



