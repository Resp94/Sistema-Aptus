CREATE OR REPLACE FUNCTION public.criar_usuario_configuracoes(payload jsonb)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_nome text := trim(coalesce(payload->>'nome', ''));
  v_email text := lower(trim(coalesce(payload->>'email', '')));
  v_senha_temporaria text := coalesce(payload->>'senha_temporaria', '');
  v_perfil_acesso text := coalesce(payload->>'perfil_acesso', 'Visualizador');
  v_departamento text := nullif(trim(coalesce(payload->>'departamento', '')), '');
  v_status text := coalesce(payload->>'status', 'Ativo');
  v_usuario_id uuid;
  v_encrypted_password text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('configuracoes.gerenciar_usuarios') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem cadastrar novos usuários';
  END IF;

  IF v_nome = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Nome é obrigatório';
  END IF;

  IF v_email = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'E-mail é obrigatório';
  END IF;

  IF position('@' IN v_email) = 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'E-mail inválido';
  END IF;

  IF length(v_senha_temporaria) < 8 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Senha temporária deve ter pelo menos 8 caracteres';
  END IF;

  IF v_perfil_acesso NOT IN ('Administrador', 'Financeiro', 'Projetos', 'Comercial', 'Técnico', 'Visualizador') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Perfil de acesso inválido';
  END IF;

  IF v_status NOT IN ('Ativo', 'Inativo') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status inválido';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = v_email) THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Já existe um usuário com este e-mail';
  END IF;

  v_encrypted_password := crypt(v_senha_temporaria, gen_salt('bf', 10));

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    is_super_admin,
    email_change,
    email_change_token_current,
    phone_change,
    phone_change_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    v_email,
    v_encrypted_password,
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('nome', v_nome, 'departamento', v_departamento, 'perfil_acesso', v_perfil_acesso),
    now(),
    now(),
    '',
    '',
    '',
    false,
    '',
    '',
    '',
    ''
  )
  RETURNING id INTO v_usuario_id;

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    v_usuario_id,
    v_usuario_id,
    jsonb_build_object('sub', v_usuario_id, 'email', v_email),
    'email',
    v_email,
    now(),
    now(),
    now()
  );

  UPDATE public.perfis
  SET
    nome = v_nome,
    perfil_acesso = v_perfil_acesso,
    status = v_status,
    departamento = v_departamento,
    updated_at = now()
  WHERE usuario_id = v_usuario_id;

  PERFORM public.registrar_evento_auditoria(
    'usuario_criado',
    '0.0.0.0',
    'Usuário criado por admin: ' || v_email || ' com perfil ' || v_perfil_acesso
  );

  IF v_status = 'Inativo' THEN
    PERFORM public.registrar_evento_auditoria(
      'conta_desativada',
      '0.0.0.0',
      'Conta criada já inativa: ' || v_email
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_usuario_configuracoes(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_usuario_configuracoes(jsonb) TO authenticated;
