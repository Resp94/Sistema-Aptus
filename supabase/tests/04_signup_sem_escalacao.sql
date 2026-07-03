-- FR-004/006: cadastro com metadata privilegiada resulta em Visualizador

SELECT * FROM no_plan();

SELECT reset_auth();

-- Idempotência: remove resíduo de execução anterior antes de inserir (evita
-- "duplicate key" em auth.users/public.usuarios ao rodar `npm run db:test` mais
-- de uma vez sem `db reset`). public.usuarios não tem cascade de auth.users.
DELETE FROM public.perfis WHERE usuario_id IN (SELECT id FROM public.usuarios WHERE email = 'teste_escalacao@aptusflow.local');
DELETE FROM public.usuarios WHERE email = 'teste_escalacao@aptusflow.local';
DELETE FROM auth.users WHERE email = 'teste_escalacao@aptusflow.local';

-- Insere usuário com metadata declarando Administrador
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
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'teste_escalacao@aptusflow.local',
  crypt('SenhaSegura123!', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"nome": "Teste Escalacao", "perfil_acesso": "Administrador", "departamento": "TI"}'::jsonb,
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
);

SELECT ok(
  (SELECT perfil_acesso FROM public.perfis WHERE usuario_id = (SELECT id FROM auth.users WHERE email = 'teste_escalacao@aptusflow.local')) = 'Visualizador',
  'signup with Administrador metadata results in Visualizador profile'
);

SELECT ok(
  (SELECT nome FROM public.perfis WHERE usuario_id = (SELECT id FROM auth.users WHERE email = 'teste_escalacao@aptusflow.local')) = 'Teste Escalacao',
  'signup preserves nome from metadata'
);

SELECT ok(
  (SELECT departamento FROM public.perfis WHERE usuario_id = (SELECT id FROM auth.users WHERE email = 'teste_escalacao@aptusflow.local')) = 'TI',
  'signup preserves departamento from metadata'
);

SELECT * FROM finish();
