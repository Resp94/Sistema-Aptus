-- FR-003/003a/003b: auditoria com whitelist anônima e autor forçado

SELECT * FROM no_plan();

-- Anônimo registra login_falha (whitelist) com autor nulo
SELECT set_anon();

SELECT lives_ok(
  $$SELECT public.registrar_evento_auditoria('login_falha', '127.0.0.1', 'test-agent')$$,
  'anon can record login_falha'
);

-- Leitura de public.audit_log exige privilégio elevado (RPC-first: nem anon nem
-- authenticated têm SELECT direto na tabela), por isso resetamos o role antes de
-- verificar o resultado gravado pela RPC.
SELECT reset_auth();

SELECT ok(
  (SELECT usuario_id IS NULL FROM public.audit_log WHERE evento = 'login_falha' ORDER BY created_at DESC LIMIT 1),
  'login_falha recorded with NULL author'
);

-- Anônimo fora da whitelist é rejeitado
SELECT set_anon();

SELECT throws_ok(
  $$SELECT public.registrar_evento_auditoria('login_sucesso', '127.0.0.1', 'test-agent')$$,
  '42501',
  'Unauthorized',
  'anon cannot record login_sucesso'
);

-- Autenticado grava com auth.uid() — não pode forjar autor
SELECT reset_auth();
SELECT set_auth_by_email('admin@aptusflow.local');

SELECT lives_ok(
  $$SELECT public.registrar_evento_auditoria('login_sucesso', '127.0.0.1', 'test-agent')$$,
  'authenticated can record login_sucesso'
);

SELECT reset_auth();

SELECT ok(
  (SELECT usuario_id = (SELECT id FROM auth.users WHERE email = 'admin@aptusflow.local')
   FROM public.audit_log WHERE evento = 'login_sucesso' ORDER BY created_at DESC LIMIT 1),
  'authenticated event author is auth.uid()'
);

-- Garante privilégio de execução legítimo para anon e PUBLIC na função de auditoria (T012)
SELECT assert_function_execute_grant('anon', 'public.registrar_evento_auditoria(text, text, text)', true);
SELECT assert_function_execute_grant('public', 'public.registrar_evento_auditoria(text, text, text)', true);

SELECT reset_auth();

SELECT * FROM finish();
