-- Migration: 20260701000009_demais_telas_rpc_relatorios_config_read.sql
-- Implementação de funções de leitura do domínio Relatórios e Configurações

-- 1. listar_categorias_relatorios
CREATE OR REPLACE FUNCTION public.listar_categorias_relatorios()
RETURNS TABLE (categoria text)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true
  ) THEN
    RETURN;
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();

  IF v_perfil_acesso = 'Administrador' OR v_perfil_acesso = 'Visualizador' THEN
    RETURN QUERY VALUES 
      ('Financeiro'), ('DRE'), ('Clientes'), ('Projetos'), ('Personalizado');
  ELSIF v_perfil_acesso = 'Financeiro' THEN
    RETURN QUERY VALUES 
      ('Financeiro'), ('DRE');
  ELSIF v_perfil_acesso = 'Comercial' THEN
    RETURN QUERY VALUES 
      ('Clientes');
  ELSIF v_perfil_acesso = 'Projetos' THEN
    RETURN QUERY VALUES 
      ('Projetos');
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_categorias_relatorios() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_categorias_relatorios() TO authenticated;


-- 2. gerar_previa_relatorio
CREATE OR REPLACE FUNCTION public.gerar_previa_relatorio(p_tipo text, p_filtros jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de leitura no Relatórios';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();

  -- Impedir acesso a relatórios financeiros para perfis não autorizados
  IF p_tipo IN ('Financeiro', 'DRE') AND v_perfil_acesso NOT IN ('Administrador', 'Financeiro', 'Visualizador') THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão para visualizar relatórios financeiros';
  END IF;

  -- Impedir acesso a relatórios de projetos para perfis não autorizados
  IF p_tipo = 'Projetos' AND v_perfil_acesso NOT IN ('Administrador', 'Projetos', 'Visualizador') THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão para visualizar relatórios de projetos';
  END IF;

  -- Geração de dados de preview dinâmicos (sem persistir arquivo)
  IF p_tipo = 'Financeiro' THEN
    RETURN (
      SELECT jsonb_build_object(
        'receitas_totais', coalesce(sum(CASE WHEN tipo = 'receita' THEN valor ELSE 0 END), 0.00),
        'despesas_totais', coalesce(sum(CASE WHEN tipo = 'despesa' THEN valor ELSE 0 END), 0.00),
        'saldo_acumulado', coalesce(sum(CASE WHEN tipo = 'receita' THEN valor ELSE -valor END), 0.00),
        'lancamentos_count', count(id)
      )
      FROM public.lancamentos
    );
  ELSIF p_tipo = 'DRE' THEN
    RETURN (
      SELECT jsonb_build_object(
        'faturamento_bruto', coalesce(sum(valor) filter (where tipo = 'receita'), 0.00),
        'deducoes', 0.00,
        'custos_operacionais', coalesce(sum(valor) filter (where tipo = 'despesa' and categoria = 'Operacional'), 0.00),
        'resultado_liquido', coalesce(sum(CASE WHEN tipo = 'receita' THEN valor ELSE -valor END), 0.00)
      )
      FROM public.lancamentos
    );
  ELSIF p_tipo = 'Clientes' THEN
    RETURN (
      SELECT jsonb_build_object(
        'total_clientes', count(id),
        'ativos', count(id) filter (where status = 'Ativo'),
        'inativos', count(id) filter (where status = 'Inativo')
      )
      FROM public.clientes
    );
  ELSIF p_tipo = 'Projetos' THEN
    RETURN (
      SELECT jsonb_build_object(
        'total_projetos', count(id),
        'concluidos', count(id) filter (where status = 'Concluído'),
        'em_andamento', count(id) filter (where status = 'Em andamento'),
        'planejamento', count(id) filter (where status = 'Planejamento')
      )
      FROM public.projetos
    );
  ELSE
    RETURN jsonb_build_object('message', 'Prévia de relatório indisponível para este formato.');
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.gerar_previa_relatorio(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.gerar_previa_relatorio(text, jsonb) TO authenticated;


-- 3. listar_exportacoes_relatorios
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


-- 4. obter_configuracoes_empresa
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


-- 5. listar_usuarios_configuracoes
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


-- 6. obter_minhas_configuracoes
CREATE OR REPLACE FUNCTION public.obter_minhas_configuracoes()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
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


-- 7. listar_preferencias_notificacoes
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
  WHERE pn.perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_preferencias_notificacoes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_preferencias_notificacoes() TO authenticated;
