-- Migration: Criação das tabelas de usuarios, perfis e logs de auditoria
-- Habilita extensões necessárias
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Tabela usuarios (espelho de auth.users no schema public)
CREATE TABLE IF NOT EXISTS public.usuarios (
  id uuid PRIMARY KEY,
  email text UNIQUE NOT NULL,
  email_confirmed_at timestamp with time zone,
  phone text,
  phone_confirmed_at timestamp with time zone,
  raw_user_meta_data jsonb,
  raw_app_meta_data jsonb,
  aud text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  last_sign_in_at timestamp with time zone
);

-- 2. Tabela perfis
CREATE TABLE IF NOT EXISTS public.perfis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL UNIQUE REFERENCES public.usuarios(id) ON DELETE CASCADE,
  nome text NOT NULL,
  avatar_url text,
  perfil_acesso text NOT NULL CHECK (perfil_acesso IN ('Administrador', 'Financeiro', 'Projetos', 'Comercial', 'Técnico', 'Visualizador')),
  status text NOT NULL DEFAULT 'Ativo' CHECK (status IN ('Ativo', 'Inativo')),
  departamento text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 3. Tabela audit_log
CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evento text NOT NULL CHECK (evento IN ('login_sucesso', 'login_falha', 'senha_alterada', 'usuario_criado', 'conta_desativada', 'conta_ativada')),
  usuario_id uuid REFERENCES public.usuarios(id) ON DELETE SET NULL,
  ip_origem text,
  user_agent text,
  created_at timestamp with time zone DEFAULT now()
);

-- Habilita Row Level Security (RLS) em todas as tabelas
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- 4. Função auxiliar de RLS para verificar se o usuário é administrador ativo
-- Usa SET row_security = off para evitar recursão infinita no RLS da tabela perfis
CREATE OR REPLACE FUNCTION public.existe_perfil_admin(uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET row_security = off
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfis
    WHERE usuario_id = uid AND perfil_acesso = 'Administrador' AND status = 'Ativo'
  );
$$;

-- 5. RLS Policies para public.usuarios
CREATE POLICY usuarios_select_self ON public.usuarios
  FOR SELECT TO authenticated USING (auth.uid() = id);

-- 6. RLS Policies para public.perfis
CREATE POLICY perfis_select_self ON public.perfis
  FOR SELECT TO authenticated USING (auth.uid() = usuario_id);

CREATE POLICY perfis_select_admin ON public.perfis
  FOR SELECT TO authenticated USING (public.existe_perfil_admin(auth.uid()));

CREATE POLICY perfis_insert_admin ON public.perfis
  FOR INSERT TO authenticated WITH CHECK (public.existe_perfil_admin(auth.uid()));

CREATE POLICY perfis_update_self ON public.perfis
  FOR UPDATE TO authenticated
  USING (auth.uid() = usuario_id)
  WITH CHECK (auth.uid() = usuario_id);

CREATE POLICY perfis_update_admin ON public.perfis
  FOR UPDATE TO authenticated
  USING (public.existe_perfil_admin(auth.uid()))
  WITH CHECK (public.existe_perfil_admin(auth.uid()));

-- 7. RLS Policies para public.audit_log
-- Audit log é somente INSERT via RPC (SECURITY DEFINER) e SELECT para administradores
CREATE POLICY audit_log_select_admin ON public.audit_log
  FOR SELECT TO authenticated USING (public.existe_perfil_admin(auth.uid()));

-- 8. Trigger para sincronização entre auth.users -> public.usuarios e public.perfis
CREATE OR REPLACE FUNCTION public.handle_auth_user_sync()
RETURNS trigger
SECURITY DEFINER
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
      coalesce(new.raw_user_meta_data->>'perfil_acesso', 'Visualizador'),
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
$$ LANGUAGE plpgsql;

-- Associa a trigger pós-criação/atualização no schema auth
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_sync();

-- 9. Trigger de validação para impedir alteração de permissão ou status por usuários comuns
CREATE OR REPLACE FUNCTION public.validar_perfil_update()
RETURNS trigger
SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  -- Permite alterações se vier de processo do sistema (sem auth.uid() definido no contexto)
  IF auth.uid() IS NULL THEN
    RETURN new;
  END IF;

  -- Se houver usuário logado, valida se ele é um administrador ativo
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    IF old.perfil_acesso <> new.perfil_acesso OR old.status <> new.status THEN
      RAISE EXCEPTION 'Apenas administradores podem alterar perfil de acesso ou status.';
    END IF;
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER before_perfil_update
  BEFORE UPDATE ON public.perfis
  FOR EACH ROW EXECUTE FUNCTION public.validar_perfil_update();

-- 10. RPC obter_perfil_usuario
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
AS $$
BEGIN
  RETURN QUERY
  SELECT p.nome, p.perfil_acesso, p.status, p.avatar_url, p.departamento
  FROM public.perfis p
  WHERE p.usuario_id = auth.uid();
END;
$$;

-- 11. RPC obter_permissoes_usuario
CREATE OR REPLACE FUNCTION public.obter_permissoes_usuario()
RETURNS TABLE (
  modulo text,
  pode_ler boolean,
  pode_escrever boolean
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET row_security = off
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
BEGIN
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
      ('dashboard', true, true),
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
      ('dashboard', true, false),
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

-- 12. RPC criar_perfil_teste
CREATE OR REPLACE FUNCTION public.criar_perfil_teste(
  p_email text,
  p_senha text,
  p_nome text,
  p_perfil_acesso text
)
RETURNS TABLE (
  usuario_id uuid,
  perfil_id uuid
)
LANGUAGE plpgsql SECURITY DEFINER
SET row_security = off
AS $$
DECLARE
  v_user_id uuid;
  v_profile_id uuid;
  v_encrypted_password text;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Apenas administradores podem criar perfis de teste';
  END IF;

  v_encrypted_password := crypt(p_senha, gen_salt('bf', 10));

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
    p_email,
    v_encrypted_password,
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('nome', p_nome),
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
  RETURNING id INTO v_user_id;

  -- Vincular identidade para permitir login por e-mail no GoTrue
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
    v_user_id,
    v_user_id,
    jsonb_build_object('sub', v_user_id, 'email', p_email),
    'email',
    p_email,
    now(),
    now(),
    now()
  );

  UPDATE public.perfis SET
    nome = p_nome,
    perfil_acesso = p_perfil_acesso,
    status = 'Ativo'
  WHERE perfis.usuario_id = v_user_id
  RETURNING id INTO v_profile_id;

  INSERT INTO public.audit_log (evento, usuario_id, ip_origem, user_agent)
  VALUES ('usuario_criado', v_user_id, '0.0.0.0', 'System (criar_perfil_teste)');

  RETURN QUERY SELECT v_user_id, v_profile_id;
END;
$$;

-- 13. RPC registrar_evento_auditoria
CREATE OR REPLACE FUNCTION public.registrar_evento_auditoria(
  p_evento text,
  p_usuario_id uuid,
  p_ip_origem text,
  p_user_agent text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO public.audit_log (
    evento,
    usuario_id,
    ip_origem,
    user_agent
  ) VALUES (
    p_evento,
    p_usuario_id,
    p_ip_origem,
    p_user_agent
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;
