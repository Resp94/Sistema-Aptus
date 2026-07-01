-- Migration: 20260701000010_demais_telas_rpc_config_write.sql
-- Implementação de funções de escrita do domínio Relatórios e Configurações

-- 1. solicitar_exportacao_relatorio
CREATE OR REPLACE FUNCTION public.solicitar_exportacao_relatorio(
  p_tipo text,
  p_formato text,
  p_filtros jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão para solicitar exportações';
  END IF;

  -- Insere o registro de exportação com status 'Indisponível' (sem simular sucesso falso)
  INSERT INTO public.exportacoes_relatorios (
    tipo,
    formato,
    status,
    arquivo_url,
    criado_por,
    gerado_em
  ) VALUES (
    p_tipo,
    p_formato,
    'Indisponível',
    NULL, -- arquivo_url nulo pois não há gerador de PDF/CSV configurado no backend
    auth.uid(),
    now()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) TO authenticated;


-- 2. agendar_relatorio
CREATE OR REPLACE FUNCTION public.agendar_relatorio(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_tipo text;
  v_formato text;
  v_filtros jsonb;
  v_frequencia text;
  v_agendado_para timestamp with time zone;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão para agendar relatórios';
  END IF;

  v_tipo := payload->>'tipo';
  v_formato := payload->>'formato';
  v_filtros := coalesce(payload->'filtros', '{}'::jsonb);
  v_frequencia := payload->>'frequencia';
  v_agendado_para := (payload->>'agendado_para')::timestamp with time zone;

  -- Validações
  IF v_tipo NOT IN ('Financeiro', 'DRE', 'Clientes', 'Projetos', 'Personalizado') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Tipo de relatório inválido';
  END IF;
  IF v_formato NOT IN ('PDF', 'CSV') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Formato inválido';
  END IF;
  IF v_frequencia NOT IN ('Uma vez', 'Diário', 'Semanal', 'Mensal') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Frequência inválida';
  END IF;

  INSERT INTO public.agendamentos_relatorios (
    tipo,
    formato,
    filtros,
    frequencia,
    criado_por,
    agendado_para,
    status
  ) VALUES (
    v_tipo,
    v_formato,
    v_filtros,
    v_frequencia,
    auth.uid(),
    v_agendado_para,
    'Ativo'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.agendar_relatorio(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agendar_relatorio(jsonb) TO authenticated;


-- 3. atualizar_configuracoes_empresa
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
  -- Apenas Administrador
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem atualizar as configurações da empresa';
  END IF;

  -- Garante que o registro único exista
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

  -- Validações
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

  -- Auditoria de parâmetros financeiros
  IF (v_percentual_multa_atraso IS NOT NULL AND v_percentual_multa_atraso <> v_old_multa) OR
     (v_dia_vencimento_padrao IS NOT NULL AND v_dia_vencimento_padrao <> v_old_vencimento) THEN
    PERFORM public.registrar_evento_auditoria(
      'parametro_financeiro_alterado',
      auth.uid(),
      '0.0.0.0',
      'Configurações financeiras atualizadas'
    );
  ELSE
    PERFORM public.registrar_evento_auditoria(
      'configuracao_global_alterada',
      auth.uid(),
      '0.0.0.0',
      'Configurações gerais atualizadas'
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) TO authenticated;


-- 4. atualizar_usuario_perfil
CREATE OR REPLACE FUNCTION public.atualizar_usuario_perfil(p_usuario_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
  v_departamento text;
  v_old_perfil text;
  v_old_status text;
BEGIN
  -- Apenas Administrador
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem gerenciar perfis de terceiros';
  END IF;

  SELECT perfil_acesso, status INTO v_old_perfil, v_old_status
  FROM public.perfis
  WHERE usuario_id = p_usuario_id;

  IF v_old_perfil IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Perfil de usuário não encontrado';
  END IF;

  v_perfil_acesso := payload->>'perfil_acesso';
  v_status := payload->>'status';
  v_departamento := payload->>'departamento';

  -- Validações
  IF v_perfil_acesso IS NOT NULL AND v_perfil_acesso NOT IN ('Administrador', 'Financeiro', 'Projetos', 'Comercial', 'Técnico', 'Visualizador') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Perfil de acesso inválido';
  END IF;
  IF v_status IS NOT NULL AND v_status NOT IN ('Ativo', 'Inativo') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status inválido';
  END IF;

  UPDATE public.perfis
  SET
    perfil_acesso = coalesce(v_perfil_acesso, perfil_acesso),
    status = coalesce(v_status, status),
    departamento = coalesce(v_departamento, departamento),
    updated_at = now()
  WHERE usuario_id = p_usuario_id;

  -- Sincronizar com a tabela auth.users se necessário (opcional no GoTrue, mas recomendável atualizar raw_user_meta_data)
  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
    'perfil_acesso', coalesce(v_perfil_acesso, v_old_perfil),
    'departamento', coalesce(v_departamento, departamento)
  )
  WHERE id = p_usuario_id;

  -- Auditoria
  IF v_perfil_acesso IS NOT NULL AND v_perfil_acesso <> v_old_perfil THEN
    PERFORM public.registrar_evento_auditoria(
      'perfil_acesso_alterado',
      auth.uid(),
      '0.0.0.0',
      'Alterado perfil de ' || p_usuario_id::text || ' de ' || v_old_perfil || ' para ' || v_perfil_acesso
    );
  END IF;

  IF v_status IS NOT NULL AND v_status <> v_old_status THEN
    DECLARE
      v_evento text := 'conta_ativada';
    BEGIN
      IF v_status = 'Inativo' THEN
        v_evento := 'conta_desativada';
      END IF;
      
      PERFORM public.registrar_evento_auditoria(
        v_evento,
        auth.uid(),
        '0.0.0.0',
        'Alterado status de ' || p_usuario_id::text || ' para ' || v_status
      );
    END;
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_usuario_perfil(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_usuario_perfil(uuid, jsonb) TO authenticated;


-- 5. atualizar_minhas_configuracoes
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

  -- Atualizar raw_user_meta_data em auth.users
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


-- 6. atualizar_preferencias_notificacoes
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
