-- SQL de semente para banco de dados local do Supabase
-- Cria os usuários e perfis de teste baseados nas personas do projeto

DO $$
DECLARE
  v_senha text;
BEGIN
  -- Obtém a senha de teste configurada via ambiente no config.toml (se estiver configurada)
  v_senha := current_setting('app.settings.seed_user_password', true);
  
  -- Fallback seguro para o ambiente local para garantir resiliência
  IF v_senha IS NULL OR v_senha = '' THEN
    v_senha := 'SenhaDeTesteSegura123!';
    RAISE WARNING 'SEED_USER_PASSWORD não pôde ser lida do ambiente. Usando senha de fallback padrão.';
  END IF;

  -- Remove registros anteriores das personas se existirem (para idempotência)
  DELETE FROM auth.users WHERE email IN (
    'admin@aptusflow.local',
    'financeiro@aptusflow.local',
    'projetos@aptusflow.local',
    'comercial@aptusflow.local',
    'tecnico@aptusflow.local'
  );

  -- Cria os usuários de teste chamando a RPC criar_perfil_teste
  PERFORM public.criar_perfil_teste('admin@aptusflow.local', v_senha, 'Administrador Persona', 'Administrador');
  PERFORM public.criar_perfil_teste('financeiro@aptusflow.local', v_senha, 'Financeiro Persona', 'Financeiro');
  PERFORM public.criar_perfil_teste('projetos@aptusflow.local', v_senha, 'Projetos Persona', 'Projetos');
  PERFORM public.criar_perfil_teste('comercial@aptusflow.local', v_senha, 'Comercial Persona', 'Comercial');
  PERFORM public.criar_perfil_teste('tecnico@aptusflow.local', v_senha, 'Técnico Persona', 'Técnico');
  
  RAISE NOTICE 'Seed executado com sucesso: 5 personas de teste configuradas.';
END $$;
