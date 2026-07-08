INSERT INTO public.configuracoes_empresa (id)
VALUES ('config_unica')
ON CONFLICT (id) DO NOTHING;

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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('configuracoes') WHERE pode_ler = true) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem ler as configurações globais da empresa';
  END IF;

  INSERT INTO public.configuracoes_empresa (id)
  VALUES ('config_unica')
  ON CONFLICT (id) DO NOTHING;

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
  WHERE ce.id = 'config_unica'
  LIMIT 1;
END;
$$;
