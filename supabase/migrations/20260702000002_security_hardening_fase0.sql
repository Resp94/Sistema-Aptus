-- Migration: Fase 0 - Correções críticas de segurança
-- Escopo: FR-001, FR-003/003a/003b, FR-004/005/006, FR-007, FR-007a
--   * Remover criar_perfil_teste de produção
--   * Recriar registrar_evento_auditoria com autor forçado pela sessão
--   * Corrigir handle_auth_user_sync para sempre atribuir Visualizador
--   * Fixar search_path em validar_perfil_update
--   * Endurecer existe_perfil_admin

-- FR-001: remover função de criação anônima de administradores de produção
DROP FUNCTION IF EXISTS public.criar_perfil_teste(text, text, text, text);

-- Remover assinatura antiga de auditoria (4 args) para garantir catálogo limpo
DROP FUNCTION IF EXISTS public.registrar_evento_auditoria(text, uuid, text, text);

-- FR-003/003a/003b: recriar auditoria com autor forçado pela sessão e whitelist anônima fechada
CREATE OR REPLACE FUNCTION public.registrar_evento_auditoria(
  p_evento text,
  p_ip_origem text,
  p_user_agent text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  IF auth.uid() IS NOT NULL THEN
    INSERT INTO public.audit_log (evento, usuario_id, ip_origem, user_agent)
    VALUES (p_evento, auth.uid(), p_ip_origem, p_user_agent)
    RETURNING id INTO v_log_id;
  ELSIF p_evento = ANY (ARRAY['login_falha']) THEN
    INSERT INTO public.audit_log (evento, usuario_id, ip_origem, user_agent)
    VALUES (p_evento, NULL, p_ip_origem, p_user_agent)
    RETURNING id INTO v_log_id;
  ELSE
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  RETURN v_log_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_evento_auditoria(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_evento_auditoria(text, text, text) TO anon, authenticated;

-- Ajustar call sites SQL não cobertos pela Fase 1 (funções fora das 26 legadas)
-- que chamam registrar_evento_auditoria com a assinatura antiga (4 args).
-- 1. renovar_contrato (assinatura atual: uuid, date, numeric)
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

  PERFORM public.registrar_evento_auditoria(
    'configuracao_global_alterada',
    '0.0.0.0',
    'System (renovar_contrato)'
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) TO authenticated;

-- 2. encerrar_contrato
CREATE OR REPLACE FUNCTION public.encerrar_contrato(p_id uuid, p_motivo text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Contratos';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contratos WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Contrato não encontrado';
  END IF;

  UPDATE public.contratos
  SET status = 'Encerrado',
      updated_at = now()
  WHERE id = p_id;

  PERFORM public.registrar_evento_auditoria(
    'contrato_encerrado',
    '0.0.0.0',
    'Motivo: ' || coalesce(p_motivo, 'Sem motivo informado')
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) TO authenticated;

-- 3. inativar_membro_equipe
CREATE OR REPLACE FUNCTION public.inativar_membro_equipe(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
  END IF;

  SELECT perfil_id INTO v_perfil_id FROM public.membros_equipe WHERE id = p_id;
  IF v_perfil_id IS NULL AND NOT EXISTS (SELECT 1 FROM public.membros_equipe WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Membro de equipe não encontrado';
  END IF;

  UPDATE public.membros_equipe
  SET status = 'Ausente',
      capacidade = 0,
      updated_at = now()
  WHERE id = p_id;

  IF v_perfil_id IS NOT NULL THEN
    UPDATE public.perfis
    SET status = 'Inativo',
        updated_at = now()
    WHERE id = v_perfil_id;
  END IF;

  PERFORM public.registrar_evento_auditoria(
    'membro_equipe_inativado',
    '0.0.0.0',
    'Membro ID: ' || p_id::text
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) TO authenticated;

-- 4. atualizar_configuracoes_empresa
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
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem atualizar as configurações da empresa';
  END IF;

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

  IF (v_percentual_multa_atraso IS NOT NULL AND v_percentual_multa_atraso <> v_old_multa) OR
     (v_dia_vencimento_padrao IS NOT NULL AND v_dia_vencimento_padrao <> v_old_vencimento) THEN
    PERFORM public.registrar_evento_auditoria(
      'parametro_financeiro_alterado',
      '0.0.0.0',
      'Configurações financeiras atualizadas'
    );
  ELSE
    PERFORM public.registrar_evento_auditoria(
      'configuracao_global_alterada',
      '0.0.0.0',
      'Configurações gerais atualizadas'
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) TO authenticated;

-- 5. atualizar_usuario_perfil
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
  v_old_departamento text;
BEGIN
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem gerenciar perfis de terceiros';
  END IF;

  SELECT perfil_acesso, status, departamento INTO v_old_perfil, v_old_status, v_old_departamento
  FROM public.perfis
  WHERE usuario_id = p_usuario_id;

  IF v_old_perfil IS NULL THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Perfil de usuário não encontrado';
  END IF;

  v_perfil_acesso := payload->>'perfil_acesso';
  v_status := payload->>'status';
  v_departamento := payload->>'departamento';

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

  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
    'perfil_acesso', coalesce(v_perfil_acesso, v_old_perfil),
    'departamento', coalesce(v_departamento, v_old_departamento)
  )
  WHERE id = p_usuario_id;

  IF v_perfil_acesso IS NOT NULL AND v_perfil_acesso <> v_old_perfil THEN
    PERFORM public.registrar_evento_auditoria(
      'perfil_acesso_alterado',
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

-- FR-004/006: corrigir trigger de sincronização para sempre atribuir Visualizador
CREATE OR REPLACE FUNCTION public.handle_auth_user_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.usuarios (
      id,
      email,
      email_confirmed_at,
      phone,
      phone_confirmed_at,
      raw_user_meta_data,
      raw_app_meta_data,
      aud,
      created_at,
      updated_at,
      last_sign_in_at
    ) VALUES (
      new.id,
      new.email,
      new.email_confirmed_at,
      new.phone,
      new.phone_confirmed_at,
      new.raw_user_meta_data,
      new.raw_app_meta_data,
      new.aud,
      new.created_at,
      new.updated_at,
      new.last_sign_in_at
    );

    INSERT INTO public.perfis (
      usuario_id,
      nome,
      perfil_acesso,
      status,
      departamento
    ) VALUES (
      new.id,
      coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
      'Visualizador',
      'Ativo',
      new.raw_user_meta_data->>'departamento'
    )
    ON CONFLICT (usuario_id) DO NOTHING;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.usuarios SET
      email = new.email,
      email_confirmed_at = new.email_confirmed_at,
      phone = new.phone,
      phone_confirmed_at = new.phone_confirmed_at,
      raw_user_meta_data = new.raw_user_meta_data,
      raw_app_meta_data = new.raw_app_meta_data,
      aud = new.aud,
      updated_at = new.updated_at,
      last_sign_in_at = new.last_sign_in_at
    WHERE id = new.id;

    IF new.raw_user_meta_data->>'nome' IS NOT NULL THEN
      UPDATE public.perfis SET
        nome = new.raw_user_meta_data->>'nome'
      WHERE usuario_id = new.id;
    END IF;
  END IF;
  RETURN new;
END;
$$;

-- FR-007a: fixar search_path no trigger de validação de perfil (mantém guarda de contexto de sistema)
CREATE OR REPLACE FUNCTION public.validar_perfil_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET row_security = off
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN new;
  END IF;

  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    IF old.perfil_acesso <> new.perfil_acesso OR old.status <> new.status THEN
      RAISE EXCEPTION 'Apenas administradores podem alterar perfil de acesso ou status.';
    END IF;
  END IF;
  RETURN new;
END;
$$;

-- FR-007: endurecer existe_perfil_admin
CREATE OR REPLACE FUNCTION public.existe_perfil_admin(uid uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.perfis
    WHERE usuario_id = uid AND perfil_acesso = 'Administrador' AND status = 'Ativo'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.existe_perfil_admin(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.existe_perfil_admin(uuid) TO authenticated;
