-- FR-016: anônimo é rejeitado em toda SECURITY DEFINER não-trigger
-- exceto a função de auditoria (whitelist de eventos pré-auth).

SELECT * FROM no_plan();

SELECT set_anon();

-- Nota: verificamos apenas o SQLSTATE (42501), não o texto da mensagem.
-- Funções que concedem GRANT só a `authenticated` (a maioria) são barradas pelo
-- Postgres na camada de permissão antes mesmo do corpo rodar, com a mensagem nativa
-- "permission denied for function X" — só `registrar_evento_auditoria` (GRANT a
-- `anon`) chega a executar o `RAISE EXCEPTION 'Unauthorized'` customizado. Ambos os
-- casos usam o código 42501, que é o contrato objetivo definido em
-- contracts/guardrail-standard.md.
-- 2 argumentos: pgTAP checa só o SQLSTATE (o 2º argumento bate o padrão de
-- errcode de 5 caracteres). Passar uma "description" como 3º argumento faria
-- pgTAP interpretá-la como a mensagem de erro ESPERADA (comparação exata), o que
-- quebraria para toda função sem GRANT a anon (ver nota acima).
SELECT throws_ok(
  format(
    'SELECT %I(%s)',
    p.proname,
    coalesce(
      (SELECT string_agg(format('NULL::%s', format_type(t, NULL)), ', ')
       FROM unnest(p.proargtypes) t),
      ''
    )
  ),
  '42501'
)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND p.prorettype <> 'pg_catalog.trigger'::regtype
  AND p.proname <> 'registrar_evento_auditoria';

SELECT reset_auth();

SELECT * FROM finish();
