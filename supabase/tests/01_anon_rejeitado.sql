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

-- Asserts estáticos de privilégio de execução para 'anon'
SELECT assert_function_execute_grant(
  'anon',
  format('%I.%I(%s)', n.nspname, p.proname, oidvectortypes(p.proargtypes)),
  false
)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND p.prorettype <> 'pg_catalog.trigger'::regtype
  AND p.proname <> 'registrar_evento_auditoria';

-- Asserts estáticos de privilégio de execução para 'PUBLIC'
SELECT assert_function_execute_grant(
  'public',
  format('%I.%I(%s)', n.nspname, p.proname, oidvectortypes(p.proargtypes)),
  false
)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND p.prorettype <> 'pg_catalog.trigger'::regtype
  AND p.proname <> 'registrar_evento_auditoria';

-- Asserts estáticos explícitos por assinatura exata (T011)

-- Clientes
SELECT assert_function_execute_grant('anon', 'public.criar_cliente(text, text, text, text, text)', false);
SELECT assert_function_execute_grant('public', 'public.criar_cliente(text, text, text, text, text)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_cliente(uuid, text, text, text, text, text, text)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_cliente(uuid, text, text, text, text, text, text)', false);
SELECT assert_function_execute_grant('anon', 'public.inativar_cliente(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.inativar_cliente(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.registrar_atendimento(uuid, text, date)', false);
SELECT assert_function_execute_grant('public', 'public.registrar_atendimento(uuid, text, date)', false);

-- Comercial
SELECT assert_function_execute_grant('anon', 'public.criar_proposta(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.criar_proposta(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_proposta(uuid, jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_proposta(uuid, jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.registrar_envio_proposta(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.registrar_envio_proposta(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.criar_contrato(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.criar_contrato(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.renovar_contrato(uuid, date, numeric)', false);
SELECT assert_function_execute_grant('public', 'public.renovar_contrato(uuid, date, numeric)', false);
SELECT assert_function_execute_grant('anon', 'public.encerrar_contrato(uuid, text)', false);
SELECT assert_function_execute_grant('public', 'public.encerrar_contrato(uuid, text)', false);

-- Financeiro / Cobranças
SELECT assert_function_execute_grant('anon', 'public.criar_cobranca(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.criar_cobranca(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.solicitar_emissao_boleto(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.solicitar_emissao_boleto(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.solicitar_lembrete_cobranca(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.solicitar_lembrete_cobranca(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.registrar_pagamento_cobranca(uuid, jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.registrar_pagamento_cobranca(uuid, jsonb)', false);

-- Projetos / Tarefas
SELECT assert_function_execute_grant('anon', 'public.criar_projeto(text, uuid, numeric, date, text)', false);
SELECT assert_function_execute_grant('public', 'public.criar_projeto(text, uuid, numeric, date, text)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date)', false);
SELECT assert_function_execute_grant('anon', 'public.excluir_projeto(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.excluir_projeto(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.criar_tarefa(uuid, text, text, uuid, date, text)', false);
SELECT assert_function_execute_grant('public', 'public.criar_tarefa(uuid, text, text, uuid, date, text)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_tarefa(uuid, text, text, uuid, date, text)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_tarefa(uuid, text, text, uuid, date, text)', false);
SELECT assert_function_execute_grant('anon', 'public.mover_tarefa(uuid, text)', false);
SELECT assert_function_execute_grant('public', 'public.mover_tarefa(uuid, text)', false);
SELECT assert_function_execute_grant('anon', 'public.excluir_tarefa(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.excluir_tarefa(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.registrar_apontamento_horas(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.registrar_apontamento_horas(jsonb)', false);

-- Equipe
SELECT assert_function_execute_grant('anon', 'public.listar_membros_equipe(text, text)', false);
SELECT assert_function_execute_grant('public', 'public.listar_membros_equipe(text, text)', false);
SELECT assert_function_execute_grant('anon', 'public.criar_membro_equipe(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.criar_membro_equipe(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_membro_equipe(uuid, jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_membro_equipe(uuid, jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.alocar_membro_projeto(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.alocar_membro_projeto(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.inativar_membro_equipe(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.inativar_membro_equipe(uuid)', false);

-- Financeiro
SELECT assert_function_execute_grant('anon', 'public.criar_lancamento_financeiro(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.criar_lancamento_financeiro(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_lancamento_financeiro(uuid, jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_lancamento_financeiro(uuid, jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.registrar_pagamento_lancamento(uuid, date, numeric)', false);
SELECT assert_function_execute_grant('public', 'public.registrar_pagamento_lancamento(uuid, date, numeric)', false);

-- Configurações
SELECT assert_function_execute_grant('anon', 'public.atualizar_configuracoes_empresa(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_configuracoes_empresa(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_usuario_perfil(uuid, jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_usuario_perfil(uuid, jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_minhas_configuracoes(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_minhas_configuracoes(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.atualizar_preferencias_notificacoes(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.atualizar_preferencias_notificacoes(jsonb)', false);

-- Relatórios e Exportação
SELECT assert_function_execute_grant('anon', 'public.solicitar_exportacao_relatorio(text, text, jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.solicitar_exportacao_relatorio(text, text, jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.agendar_relatorio(jsonb)', false);
SELECT assert_function_execute_grant('public', 'public.agendar_relatorio(jsonb)', false);
SELECT assert_function_execute_grant('anon', 'public.categoria_relatorio_exportavel(text, text)', false);
SELECT assert_function_execute_grant('public', 'public.categoria_relatorio_exportavel(text, text)', false);
SELECT assert_function_execute_grant('anon', 'public.validar_periodo_exportacao(date, date)', false);
SELECT assert_function_execute_grant('public', 'public.validar_periodo_exportacao(date, date)', false);
SELECT assert_function_execute_grant('anon', 'public.montar_payload_relatorio_financeiro(date, date)', false);
SELECT assert_function_execute_grant('public', 'public.montar_payload_relatorio_financeiro(date, date)', false);
SELECT assert_function_execute_grant('anon', 'public.montar_payload_relatorio_dre(date, date)', false);
SELECT assert_function_execute_grant('public', 'public.montar_payload_relatorio_dre(date, date)', false);
SELECT assert_function_execute_grant('anon', 'public.montar_payload_relatorio_clientes(date, date)', false);
SELECT assert_function_execute_grant('public', 'public.montar_payload_relatorio_clientes(date, date)', false);
SELECT assert_function_execute_grant('anon', 'public.montar_payload_relatorio_projetos(date, date)', false);
SELECT assert_function_execute_grant('public', 'public.montar_payload_relatorio_projetos(date, date)', false);
SELECT assert_function_execute_grant('anon', 'public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text)', false);
SELECT assert_function_execute_grant('public', 'public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text)', false);
SELECT assert_function_execute_grant('anon', 'public.iniciar_exportacao_relatorio(text, text, date, date)', false);
SELECT assert_function_execute_grant('public', 'public.iniciar_exportacao_relatorio(text, text, date, date)', false);
SELECT assert_function_execute_grant('anon', 'public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text)', false);
SELECT assert_function_execute_grant('public', 'public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text)', false);
SELECT assert_function_execute_grant('anon', 'public.falhar_exportacao_relatorio(uuid, text)', false);
SELECT assert_function_execute_grant('public', 'public.falhar_exportacao_relatorio(uuid, text)', false);
SELECT assert_function_execute_grant('anon', 'public.autorizar_download_exportacao_relatorio(uuid)', false);
SELECT assert_function_execute_grant('public', 'public.autorizar_download_exportacao_relatorio(uuid)', false);
SELECT assert_function_execute_grant('anon', 'public.listar_exportacoes_relatorios(text)', false);
SELECT assert_function_execute_grant('public', 'public.listar_exportacoes_relatorios(text)', false);

SELECT reset_auth();

SELECT * FROM finish();
