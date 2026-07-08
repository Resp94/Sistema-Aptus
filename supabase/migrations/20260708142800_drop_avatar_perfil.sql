ALTER TABLE public.perfis
DROP COLUMN IF EXISTS avatar_url;

CREATE OR REPLACE FUNCTION public.obter_perfil_usuario()
RETURNS TABLE (
  nome text,
  perfil_acesso text,
  status text,
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
  SELECT p.nome, p.perfil_acesso, p.status, p.departamento
  FROM public.perfis p
  WHERE p.usuario_id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_perfil_usuario() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_perfil_usuario() TO authenticated;

CREATE OR REPLACE FUNCTION public.obter_minhas_configuracoes()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'perfil', jsonb_build_object(
      'id', p.id,
      'nome', p.nome,
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

REVOKE EXECUTE ON FUNCTION public.obter_minhas_configuracoes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.obter_minhas_configuracoes() TO authenticated;

CREATE OR REPLACE FUNCTION public.atualizar_minhas_configuracoes(payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nome text;
  v_departamento text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('configuracoes.editar_proprio_perfil') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  v_nome := payload->>'nome';
  v_departamento := payload->>'departamento';

  UPDATE public.perfis
  SET
    nome = coalesce(v_nome, nome),
    departamento = coalesce(v_departamento, departamento),
    updated_at = now()
  WHERE usuario_id = auth.uid();

  UPDATE auth.users
  SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
    'nome', coalesce(v_nome, raw_user_meta_data->>'nome'),
    'departamento', coalesce(v_departamento, raw_user_meta_data->>'departamento')
  )
  WHERE id = auth.uid();

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_minhas_configuracoes(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_minhas_configuracoes(jsonb) TO authenticated;
