-- Migration: 20260701000007_demais_telas_rpc_equipe_read.sql
-- Implementação de funções de leitura do domínio Equipe

-- 1. obter_metricas_equipe
CREATE OR REPLACE FUNCTION public.obter_metricas_equipe()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
  v_membro_status text;
  v_total_membros integer := 0;
  v_projetos_ativos integer := 0;
  v_em_projeto_ativo integer := 0;
  v_ausentes integer := 0;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id, status INTO v_membro_id, v_membro_status FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  IF v_perfil_acesso IN ('Administrador', 'Projetos', 'Visualizador') THEN
    -- Métricas Gerais (Equipe Completa)
    SELECT count(id) INTO v_total_membros FROM public.membros_equipe;
    SELECT count(id) INTO v_projetos_ativos FROM public.projetos WHERE status = 'Em andamento';
    
    SELECT count(distinct membro_equipe_id) INTO v_em_projeto_ativo 
    FROM public.alocacoes_equipe ae
    JOIN public.projetos p ON ae.projeto_id = p.id
    WHERE p.status = 'Em andamento' AND (ae.data_fim IS NULL OR ae.data_fim >= current_date);

    SELECT count(id) INTO v_ausentes FROM public.membros_equipe WHERE status IN ('Férias', 'Ausente');
  ELSE
    -- Métricas Limitadas ao Técnico
    v_total_membros := 1;
    
    SELECT count(distinct ae.projeto_id) INTO v_projetos_ativos
    FROM public.alocacoes_equipe ae
    JOIN public.projetos p ON ae.projeto_id = p.id
    WHERE ae.membro_equipe_id = v_membro_id AND p.status = 'Em andamento';

    IF EXISTS (
      SELECT 1 FROM public.alocacoes_equipe ae
      JOIN public.projetos p ON ae.projeto_id = p.id
      WHERE ae.membro_equipe_id = v_membro_id AND p.status = 'Em andamento'
        AND (ae.data_fim IS NULL OR ae.data_fim >= current_date)
    ) THEN
      v_em_projeto_ativo := 1;
    ELSE
      v_em_projeto_ativo := 0;
    END IF;

    IF v_membro_status IN ('Férias', 'Ausente') THEN
      v_ausentes := 1;
    ELSE
      v_ausentes := 0;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'total_membros', v_total_membros,
    'projetos_ativos', v_projetos_ativos,
    'em_projeto_ativo', v_em_projeto_ativo,
    'ausentes', v_ausentes
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_metricas_equipe() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_metricas_equipe() TO authenticated;


-- 2. listar_membros_equipe
CREATE OR REPLACE FUNCTION public.listar_membros_equipe(
  p_status text DEFAULT NULL,
  p_busca text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  nome text,
  funcao text,
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
  v_pode_ver_custo boolean := false;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id INTO v_membro_id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  IF v_perfil_acesso IN ('Administrador', 'Projetos') THEN
    v_pode_ver_custo := true;
  END IF;

  RETURN QUERY
  SELECT 
    me.id,
    me.nome,
    me.funcao,
    me.status,
    coalesce((
      SELECT p.nome 
      FROM public.alocacoes_equipe ae
      JOIN public.projetos p ON ae.projeto_id = p.id
      WHERE ae.membro_equipe_id = me.id 
        AND p.status = 'Em andamento'
        AND (ae.data_fim IS NULL OR ae.data_fim >= current_date)
      LIMIT 1
    ), 'Sem projeto ativo') as projeto_atual,
    me.capacidade,
    CASE WHEN v_pode_ver_custo THEN me.custo_hora ELSE NULL END as custo_hora
  FROM public.membros_equipe me
  WHERE (
    v_perfil_acesso IN ('Administrador', 'Projetos', 'Visualizador') OR me.id = v_membro_id
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


-- 3. obter_alocacao_por_projeto
CREATE OR REPLACE FUNCTION public.obter_alocacao_por_projeto()
RETURNS TABLE (
  projeto_nome text,
  quantidade_membros bigint
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id INTO v_membro_id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  RETURN QUERY
  SELECT 
    p.nome as projeto_nome,
    count(distinct ae.membro_equipe_id) as quantidade_membros
  FROM public.alocacoes_equipe ae
  JOIN public.projetos p ON ae.projeto_id = p.id
  WHERE (
    v_perfil_acesso IN ('Administrador', 'Projetos', 'Visualizador') OR ae.membro_equipe_id = v_membro_id
  )
  GROUP BY p.nome
  ORDER BY quantidade_membros DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_alocacao_por_projeto() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_alocacao_por_projeto() TO authenticated;


-- 4. obter_capacidade_equipe
CREATE OR REPLACE FUNCTION public.obter_capacidade_equipe()
RETURNS TABLE (
  membro_nome text,
  projeto_nome text,
  percentual_alocacao integer
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id INTO v_membro_id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  RETURN QUERY
  SELECT 
    me.nome as membro_nome,
    p.nome as projeto_nome,
    ae.percentual_alocacao
  FROM public.alocacoes_equipe ae
  JOIN public.membros_equipe me ON ae.membro_equipe_id = me.id
  JOIN public.projetos p ON ae.projeto_id = p.id
  WHERE (
    v_perfil_acesso IN ('Administrador', 'Projetos', 'Visualizador') OR ae.membro_equipe_id = v_membro_id
  )
  ORDER BY me.nome ASC, ae.percentual_alocacao DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_capacidade_equipe() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_capacidade_equipe() TO authenticated;


-- 5. listar_apontamentos_horas
CREATE OR REPLACE FUNCTION public.listar_apontamentos_horas(
  p_membro_id uuid DEFAULT NULL,
  p_data_inicio date DEFAULT NULL,
  p_data_fim date DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  membro text,
  membro_equipe_id uuid,
  projeto text,
  projeto_id uuid,
  tarefa text,
  tarefa_id uuid,
  horas numeric(6,2),
  descricao text,
  data date,
  created_at timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
  v_target_membro_id uuid;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão no módulo de Equipe/Projetos';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id INTO v_membro_id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  -- Forçar técnico a ver apenas a si mesmo
  IF v_perfil_acesso = 'Técnico' THEN
    v_target_membro_id := v_membro_id;
  ELSE
    v_target_membro_id := p_membro_id;
  END IF;

  RETURN QUERY
  SELECT 
    ah.id,
    me.nome as membro,
    ah.membro_equipe_id,
    p.nome as projeto,
    ah.projeto_id,
    coalesce(t.titulo, '') as tarefa,
    ah.tarefa_id,
    ah.horas,
    ah.descricao,
    ah.data,
    ah.created_at
  FROM public.apontamentos_horas ah
  JOIN public.membros_equipe me ON ah.membro_equipe_id = me.id
  JOIN public.projetos p ON ah.projeto_id = p.id
  LEFT JOIN public.tarefas t ON ah.tarefa_id = t.id
  WHERE (v_target_membro_id IS NULL OR ah.membro_equipe_id = v_target_membro_id)
    AND (p_data_inicio IS NULL OR ah.data >= p_data_inicio)
    AND (p_data_fim IS NULL OR ah.data <= p_data_fim)
  ORDER BY ah.data DESC, ah.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_apontamentos_horas(uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_apontamentos_horas(uuid, date, date) TO authenticated;
