-- Migration: 20260628000005_modulos_landing_rpc_projetos_read.sql
-- Funções RPC para leitura de projetos, tarefas e alocações

-- 1. Listar Projetos
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
SET row_security = off
AS $$
DECLARE
  v_perfil text;
BEGIN
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

-- 2. Obter Resumo de Projetos
CREATE OR REPLACE FUNCTION public.obter_resumo_projetos()
RETURNS TABLE (
  projetos_ativos integer,
  tarefas_abertas integer,
  orcamento_total numeric,
  orcamento_utilizado_pct integer,
  em_risco integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_perfil text;
BEGIN
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

-- 3. Obter Distribuição por Cliente (Gráfico de Pizza)
-- Percentual é baseado no número de projetos ativos/em andamento do cliente sobre o total visível
CREATE OR REPLACE FUNCTION public.obter_distribuicao_clientes()
RETURNS TABLE (
  cliente text,
  percentual numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_perfil text;
  v_total_projetos bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Sem permissão de leitura';
  END IF;

  SELECT perfil_acesso INTO v_perfil FROM public.perfis WHERE usuario_id = auth.uid();

  -- Total de projetos visíveis
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

-- 4. Listar Tarefas Kanban
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
SET row_security = off
AS $$
DECLARE
  v_perfil text;
BEGIN
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
