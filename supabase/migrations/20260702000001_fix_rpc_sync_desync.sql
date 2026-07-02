-- Correção de desincronizações front<->back detectadas na auditoria de sincronia (feature 005)
--
-- 1. listar_membros_equipe / listar_preferencias_notificacoes:
--    Erro 42702 "column reference \"id\" is ambiguous". A coluna OUT `id` declarada
--    em RETURNS TABLE(id uuid, ...) colide com `id` não-qualificado nas subqueries a
--    public.perfis. Correção: qualificar todas as referências a `id`.
--
-- 2. renovar_contrato: a UI coleta um "novo valor" mas a função só atualizava a data
--    de fim. Adiciona parâmetro opcional p_novo_valor para atualizar valor_recorrente
--    quando informado (mantém compatibilidade com a chamada existente do frontend).

-- =============================================================================
-- 0. obter_metricas_equipe — alinhar chaves ao contrato TS MetricasEquipe
--    A UI lê {total_membros, membros_ativos, capacidade_total, custo_medio};
--    a versão original retornava {projetos_ativos, em_projeto_ativo, ausentes},
--    causando "R$ NaN" e capacidade vazia nos cards.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.obter_metricas_equipe()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
  v_pode_ver_custo boolean := false;
  v_total_membros integer := 0;
  v_membros_ativos integer := 0;
  v_capacidade_total integer := 0;
  v_custo_medio numeric(14,2);
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT p.perfil_acesso INTO v_perfil_acesso
  FROM public.perfis p
  WHERE p.usuario_id = auth.uid();

  SELECT me.id INTO v_membro_id
  FROM public.membros_equipe me
  WHERE me.perfil_id = (SELECT p.id FROM public.perfis p WHERE p.usuario_id = auth.uid());

  IF v_perfil_acesso IN ('Administrador', 'Projetos') THEN
    v_pode_ver_custo := true;
  END IF;

  IF v_perfil_acesso IN ('Administrador', 'Projetos', 'Visualizador') THEN
    -- Métricas da equipe completa
    SELECT
      count(*),
      count(*) FILTER (WHERE me.status <> 'Ausente'),
      coalesce(sum(me.capacidade), 0)
    INTO v_total_membros, v_membros_ativos, v_capacidade_total
    FROM public.membros_equipe me;

    IF v_pode_ver_custo THEN
      SELECT round(avg(me.custo_hora), 2) INTO v_custo_medio
      FROM public.membros_equipe me
      WHERE me.custo_hora IS NOT NULL;
    END IF;
  ELSE
    -- Métricas limitadas ao próprio membro (Técnico)
    SELECT
      count(*),
      count(*) FILTER (WHERE me.status <> 'Ausente'),
      coalesce(sum(me.capacidade), 0)
    INTO v_total_membros, v_membros_ativos, v_capacidade_total
    FROM public.membros_equipe me
    WHERE me.id = v_membro_id;
    -- Técnico não visualiza custo
    v_custo_medio := NULL;
  END IF;

  RETURN jsonb_build_object(
    'total_membros', v_total_membros,
    'membros_ativos', v_membros_ativos,
    'capacidade_total', v_capacidade_total,
    'custo_medio', v_custo_medio
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_metricas_equipe() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_metricas_equipe() TO authenticated;


-- =============================================================================
-- 1a. listar_membros_equipe (equipe_read) — id ambíguo na linha do SELECT ... INTO
--     + inclui habilidades/perfil_id no retorno (a UI usa item.habilidades).
--     Muda o shape do RETURNS TABLE, por isso exige DROP antes do CREATE.
-- =============================================================================
DROP FUNCTION IF EXISTS public.listar_membros_equipe(text, text);

CREATE OR REPLACE FUNCTION public.listar_membros_equipe(
  p_status text DEFAULT NULL,
  p_busca text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  perfil_id uuid,
  nome text,
  funcao text,
  habilidades text[],
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

  SELECT p.perfil_acesso INTO v_perfil_acesso
  FROM public.perfis p
  WHERE p.usuario_id = auth.uid();

  SELECT me.id INTO v_membro_id
  FROM public.membros_equipe me
  WHERE me.perfil_id = (SELECT p.id FROM public.perfis p WHERE p.usuario_id = auth.uid());

  IF v_perfil_acesso IN ('Administrador', 'Projetos') THEN
    v_pode_ver_custo := true;
  END IF;

  RETURN QUERY
  SELECT
    me.id,
    me.perfil_id,
    me.nome,
    me.funcao,
    me.habilidades,
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


-- =============================================================================
-- 1b. listar_preferencias_notificacoes (relatorios_config_read) — id ambíguo na subquery
-- =============================================================================
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


-- =============================================================================
-- 2. renovar_contrato — adiciona p_novo_valor (opcional) para atualizar valor_recorrente
--    Troca a assinatura (uuid, date) -> (uuid, date, numeric); requer DROP + CREATE.
-- =============================================================================
DROP FUNCTION IF EXISTS public.renovar_contrato(uuid, date);

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
  -- Permissão Check
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

  -- Auditoria
  PERFORM public.registrar_evento_auditoria(
    'perfil_acesso_alterado',
    auth.uid(),
    '0.0.0.0',
    'System (renovar_contrato)'
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) TO authenticated;


-- =============================================================================
-- 3. listar_responsaveis_tarefas — substitui o acesso direto supabase.from('perfis')
--    em ProjetosPage (violação da regra RPC-first). Popula o select de responsável
--    no formulário de tarefas.
-- =============================================================================
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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não autenticado';
  END IF;

  RETURN QUERY
  SELECT p.usuario_id, p.nome, p.perfil_acesso
  FROM public.perfis p
  ORDER BY p.nome ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_responsaveis_tarefas() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_responsaveis_tarefas() TO authenticated;


-- =============================================================================
-- 4. listar_logs_auditoria — colunas inexistentes (42703).
--    A tabela audit_log tem ip_origem/user_agent/created_at, mas a RPC lia
--    al.ip_address / al.detalhes / al.criado_em. Mapeia para as colunas reais
--    mantendo os nomes de saída esperados pelo tipo TS AuditoriaEventoItem.
-- =============================================================================
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


-- =============================================================================
-- 5. obter_alocacao_por_projeto — a UI (Visualizar membro) chama com p_membro_id
--    e espera a lista de alocações do membro (AlocacaoEquipeItem), mas a função
--    não aceitava parâmetro (PGRST202) e retornava um agregado por projeto.
--    Reescreve para receber p_membro_id e retornar a forma esperada.
-- =============================================================================
DROP FUNCTION IF EXISTS public.obter_alocacao_por_projeto();

CREATE OR REPLACE FUNCTION public.obter_alocacao_por_projeto(p_membro_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  membro_equipe_id uuid,
  membro_nome text,
  projeto_id uuid,
  projeto_nome text,
  data_inicio date,
  data_fim date,
  percentual_alocacao integer,
  funcao_no_projeto text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_membro_id uuid;
  v_target uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Equipe';
  END IF;

  SELECT pf.perfil_acesso INTO v_perfil_acesso FROM public.perfis pf WHERE pf.usuario_id = auth.uid();
  SELECT me2.id INTO v_membro_id
  FROM public.membros_equipe me2
  WHERE me2.perfil_id = (SELECT pf.id FROM public.perfis pf WHERE pf.usuario_id = auth.uid());

  -- Técnico só enxerga as próprias alocações
  IF v_perfil_acesso = 'Técnico' THEN
    v_target := v_membro_id;
  ELSE
    v_target := p_membro_id;
  END IF;

  RETURN QUERY
  SELECT
    ae.id,
    ae.membro_equipe_id,
    me.nome,
    ae.projeto_id,
    p.nome,
    ae.data_inicio,
    ae.data_fim,
    ae.percentual_alocacao,
    ae.funcao_no_projeto
  FROM public.alocacoes_equipe ae
  JOIN public.membros_equipe me ON ae.membro_equipe_id = me.id
  JOIN public.projetos p ON ae.projeto_id = p.id
  WHERE (v_target IS NULL OR ae.membro_equipe_id = v_target)
  ORDER BY ae.data_inicio DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_alocacao_por_projeto(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_alocacao_por_projeto(uuid) TO authenticated;


-- =============================================================================
-- 6. listar_apontamentos_horas — a UI envia p_projeto_id (inexistente → PGRST202)
--    e lê projeto_nome/tarefa_titulo/membro_nome; a função nomeava as colunas de
--    saída como projeto/tarefa/membro. Adiciona p_projeto_id e renomeia as colunas
--    para o contrato TS ApontamentoHorasItem.
-- =============================================================================
DROP FUNCTION IF EXISTS public.listar_apontamentos_horas(uuid, date, date);

CREATE OR REPLACE FUNCTION public.listar_apontamentos_horas(
  p_membro_id uuid DEFAULT NULL,
  p_projeto_id uuid DEFAULT NULL,
  p_data_inicio date DEFAULT NULL,
  p_data_fim date DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  membro_nome text,
  membro_equipe_id uuid,
  projeto_nome text,
  projeto_id uuid,
  tarefa_titulo text,
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
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true
    UNION
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão no módulo de Equipe/Projetos';
  END IF;

  SELECT pf.perfil_acesso INTO v_perfil_acesso FROM public.perfis pf WHERE pf.usuario_id = auth.uid();
  SELECT me2.id INTO v_membro_id
  FROM public.membros_equipe me2
  WHERE me2.perfil_id = (SELECT pf.id FROM public.perfis pf WHERE pf.usuario_id = auth.uid());

  IF v_perfil_acesso = 'Técnico' THEN
    v_target_membro_id := v_membro_id;
  ELSE
    v_target_membro_id := p_membro_id;
  END IF;

  RETURN QUERY
  SELECT
    ah.id,
    me.nome,
    ah.membro_equipe_id,
    p.nome,
    ah.projeto_id,
    t.titulo,
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
    AND (p_projeto_id IS NULL OR ah.projeto_id = p_projeto_id)
    AND (p_data_inicio IS NULL OR ah.data >= p_data_inicio)
    AND (p_data_fim IS NULL OR ah.data <= p_data_fim)
  ORDER BY ah.data DESC, ah.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_apontamentos_horas(uuid, uuid, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_apontamentos_horas(uuid, uuid, date, date) TO authenticated;


-- =============================================================================
-- 7. Detalhes comerciais (proposta/contrato/cobranca): as RPCs devolviam jsonb
--    ANINHADO (cliente:{...}, created_at nos documentos) mas os tipos TS esperam
--    a forma ACHATADA (empresa, nome_contato, criado_por_nome, documentos[].criado_em).
--    Alinha as 3 funções ao contrato TS. obter_proposta_detalhe passa a devolver
--    documentos (antes ausente, o que quebrava detalhe.documentos.length).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.obter_proposta_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
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


CREATE OR REPLACE FUNCTION public.obter_contrato_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
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


CREATE OR REPLACE FUNCTION public.obter_cobranca_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
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
