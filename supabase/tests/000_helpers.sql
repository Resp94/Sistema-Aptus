-- Helpers para simulação de identidade em testes pgTAP

SELECT * FROM no_plan();

CREATE OR REPLACE FUNCTION set_auth(p_uuid uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_claims text;
BEGIN
  SET role = 'authenticated';
  v_claims := format('{"sub":"%s","role":"authenticated"}', p_uuid);
  EXECUTE format('SET "request.jwt.claims" = %L', v_claims);
  EXECUTE format('SET "request.jwt.claim.sub" = %L', p_uuid::text);
END;
$$;

-- Resolve o UUID pelo e-mail. Faz RESET antes da leitura de auth.users para que a
-- troca de role feita por uma chamada anterior de set_auth()/set_anon() não impeça
-- a leitura ao autenticar a próxima persona no mesmo arquivo de teste. Não usa
-- SECURITY DEFINER: o Postgres proíbe `SET ROLE`/`SET SESSION AUTHORIZATION`
-- dentro de funções SECURITY DEFINER, e essa marca também faria o helper ser
-- capturado pelo teste de catálogo (01_anon_rejeitado.sql), que varre toda função
-- SECURITY DEFINER em public.
CREATE OR REPLACE FUNCTION set_auth_by_email(p_email text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_uuid uuid;
BEGIN
  PERFORM reset_auth();
  SELECT id INTO v_uuid FROM auth.users WHERE email = p_email;
  IF v_uuid IS NULL THEN
    RAISE EXCEPTION 'Usuário de teste não encontrado: %', p_email;
  END IF;
  PERFORM set_auth(v_uuid);
END;
$$;

CREATE OR REPLACE FUNCTION set_anon()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  SET role = 'anon';
  EXECUTE 'SET "request.jwt.claims" = ''{"role":"anon"}''';
  EXECUTE 'SET "request.jwt.claim.sub" = ''''';
END;
$$;

CREATE OR REPLACE FUNCTION reset_auth()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  RESET role;
  EXECUTE 'RESET "request.jwt.claims"';
  EXECUTE 'RESET "request.jwt.claim.sub"';
END;
$$;

-- Helpers de asserts reusáveis para catálogo, grants e RLS
CREATE OR REPLACE FUNCTION assert_rls_enabled(p_schema text, p_table text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_enabled boolean;
BEGIN
  SELECT c.relrowsecurity INTO v_enabled
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = p_schema AND c.relname = p_table;

  RETURN ok(COALESCE(v_enabled, false), format('RLS deve estar habilitado em %I.%I', p_schema, p_table));
END;
$$;

CREATE OR REPLACE FUNCTION assert_has_policy(p_schema text, p_table text, p_policy text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname = p_schema AND tablename = p_table AND policyname = p_policy
  ) INTO v_exists;

  RETURN ok(v_exists, format('Tabela %I.%I deve possuir a policy %I', p_schema, p_table, p_policy));
END;
$$;

CREATE OR REPLACE FUNCTION assert_has_any_policy(p_schema text, p_table text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname = p_schema AND tablename = p_table
  ) INTO v_exists;

  RETURN ok(v_exists, format('Tabela %I.%I deve possuir ao menos uma policy cadastrada', p_schema, p_table));
END;
$$;

CREATE OR REPLACE FUNCTION assert_function_execute_grant(p_role text, p_function_signature text, p_should_have boolean)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_privilege boolean;
BEGIN
  SELECT has_function_privilege(p_role, p_function_signature, 'execute') INTO v_has_privilege;
  IF p_should_have THEN
    RETURN ok(v_has_privilege, format('Role %I deve possuir permissao de EXECUTE na funcao %s', p_role, p_function_signature));
  ELSE
    RETURN ok(NOT v_has_privilege, format('Role %I NAO deve possuir permissao de EXECUTE na funcao %s', p_role, p_function_signature));
  END IF;
END;
$$;

-- Este arquivo só define fixtures (sem SECURITY DEFINER, para não ser varrido
-- pelo teste de catálogo em 01_anon_rejeitado.sql); um assert trivial garante um
-- stream TAP válido, já que finish() falha com "No tests run" se zero testes rodarem.
SELECT ok(to_regprocedure('set_auth(uuid)') IS NOT NULL, 'helpers de identidade carregados');
SELECT ok(to_regprocedure('assert_rls_enabled(text, text)') IS NOT NULL, 'helper assert_rls_enabled carregado');
SELECT ok(to_regprocedure('assert_has_policy(text, text, text)') IS NOT NULL, 'helper assert_has_policy carregado');
SELECT ok(to_regprocedure('assert_has_any_policy(text, text)') IS NOT NULL, 'helper assert_has_any_policy carregado');
SELECT ok(to_regprocedure('assert_function_execute_grant(text, text, boolean)') IS NOT NULL, 'helper assert_function_execute_grant carregado');

SELECT * FROM finish();
