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

-- Este arquivo só define fixtures (sem SECURITY DEFINER, para não ser varrido
-- pelo teste de catálogo em 01_anon_rejeitado.sql); um assert trivial garante um
-- stream TAP válido, já que finish() falha com "No tests run" se zero testes rodarem.
SELECT ok(to_regprocedure('set_auth(uuid)') IS NOT NULL, 'helpers de identidade carregados');

SELECT * FROM finish();
