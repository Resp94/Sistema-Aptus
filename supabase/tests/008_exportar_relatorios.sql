-- Feature 008 (Exportar Relatorios): seeds/helpers reutilizaveis de persona,
-- helpers de fixture para linhas de exportacoes_relatorios em cada status, e
-- testes reais de privacidade do bucket de Storage relatorios-exportados.
--
-- Escopo desta rodada (T023 em specs/008-exportar-relatorios/tasks.md):
--   1. Helpers reutilizaveis de persona para as 6 personas relevantes desta
--      feature (Administrador, Financeiro, Projetos, Visualizador, Comercial,
--      Tecnico), reaproveitando os helpers de identidade ja existentes em
--      supabase/tests/000_helpers.sql (set_auth_by_email/set_anon/reset_auth) e
--      as personas ja seedadas por supabase/seed.sql. Visualizador nao e
--      seedado por padrao (mesma situacao documentada em
--      supabase/tests/05_capacidades.sql, secao 5), entao ganha aqui um
--      fixture local dedicado a esta feature.
--   2. Helpers para simular linhas de public.exportacoes_relatorios em cada
--      status (Pendente, Pronto, Falhou, Indisponivel) e um atalho para
--      "Expirado" (Pronto com expira_em no passado, ja que Expirado e um
--      status_exibicao COMPUTADO, nao persistido — ver data-model.md,
--      secao "Status Lifecycle"). Estes helpers existem apenas para uso das
--      fases seguintes (T024-T026, T044-T046, T059-T060); esta rodada NAO
--      escreve os testes de comportamento das RPCs de exportacao.
--   3. Testes reais (nao adiaveis) de que o bucket relatorios-exportados e
--      privado e que leituras amplas de storage.objects/storage.buckets sao
--      negadas para anon, para um authenticated sem relacao com o objeto e
--      ate para o proprio dono do objeto — por contrato
--      (specs/008-exportar-relatorios/contracts/storage-and-retention.md)
--      todo acesso de download deve passar por signed URL de curta duracao
--      emitida pela Edge Function apos autorizacao via RPC, nunca por leitura
--      direta de tabela pelo cliente.
--
-- IMPORTANTE (TDD): a migration supabase/migrations/*_exportar_relatorios.sql
-- que cria o bucket relatorios-exportados e as novas colunas de
-- exportacoes_relatorios (data_inicial, data_final, arquivo_path,
-- arquivo_nome, mime_type, tamanho_bytes, hash_sha256, expira_em, erro,
-- criado_em, atualizado_em — ver data-model.md) esta sendo construida em
-- paralelo (T007-T017). Verificado neste banco antes de escrever este arquivo
-- (\d storage.buckets / \d public.exportacoes_relatorios): o bucket ainda NAO
-- existe e as colunas novas ainda NAO existem. Por isso:
--   - Secao 1 (helpers de persona) funciona hoje, sem depender da migration.
--   - Secao 2 (helpers de fixture de exportacoes_relatorios) e criada e tem
--     apenas sua PRESENCA no catalogo verificada aqui; invoca-las hoje
--     falharia com "column does not exist" ate a migration em paralelo
--     adicionar as colunas — isso e esperado e sera exercido pelos testes de
--     comportamento das fases seguintes, nao por este arquivo.
--   - Secao 3 (privacidade do bucket) e testada de verdade agora: os dois
--     primeiros testes (existencia do bucket + public = false) DEVEM falhar
--     ate a migration criar o bucket (comportamento correto de TDD); os
--     testes de leitura negada (anon / authenticated alheio / authenticated
--     dono) continuam validos independentemente da migration, pois
--     storage.objects e storage.buckets ja vem com ROW LEVEL SECURITY
--     habilitado e NENHUMA policy por padrao nesta instalacao local do
--     Supabase (confirmado via \d storage.objects / \d storage.buckets) — ou
--     seja, hoje nenhuma role client-side consegue ler linha alguma dessas
--     tabelas, e este arquivo passa a vigiar que a migration em paralelo nao
--     introduza, por engano, uma policy permissiva demais para este bucket.

SELECT * FROM no_plan();


-- ============================================================
-- 1. Helpers de persona para a feature 008
-- ============================================================
-- Fonte da matriz: specs/008-exportar-relatorios/contracts/audit-and-tests.md
-- ("Persona Matrix") e data-model.md ("Entity: Exportable Category Policy").
--
-- Personas operacionais ja seedadas por supabase/seed.sql / criar_perfil_teste
-- (confirmado em auth.users neste banco): admin@aptusflow.local,
-- financeiro@aptusflow.local, projetos@aptusflow.local,
-- comercial@aptusflow.local, tecnico@aptusflow.local.
--
-- Nenhuma funcao abaixo usa SECURITY DEFINER: supabase/tests/01_anon_rejeitado.sql
-- varre dinamicamente toda funcao SECURITY DEFINER em public e espera que uma
-- chamada anonima com argumentos NULL retorne 42501; helpers de fixture nao
-- fazem esse tipo de checagem de autorizacao (nao sao RPCs de aplicacao) e por
-- isso devem ficar fora dessa varredura, exatamente como set_auth/set_anon/
-- reset_auth em 000_helpers.sql. Por serem SECURITY INVOKER, so tem efeito
-- pratico quando chamadas enquanto a sessao ainda esta no role padrao
-- (postgres), isto e, logo apos reset_auth() — igual ao padrao ja usado para
-- fixtures diretas em supabase/tests/05_capacidades.sql.

SELECT reset_auth();

-- 1.1 Mapa persona -> email de teste, para uso genérico em loops/matrizes das
-- fases seguintes sem duplicar a lista de e-mails em cada arquivo novo.
CREATE OR REPLACE FUNCTION public.email_persona_teste_relatorios(p_perfil_acesso text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_perfil_acesso
    WHEN 'Administrador' THEN 'admin@aptusflow.local'
    WHEN 'Financeiro'    THEN 'financeiro@aptusflow.local'
    WHEN 'Projetos'      THEN 'projetos@aptusflow.local'
    WHEN 'Comercial'     THEN 'comercial@aptusflow.local'
    WHEN 'Tecnico'       THEN 'tecnico@aptusflow.local'
    WHEN 'Visualizador'  THEN 'visualizador_teste_008@aptusflow.local'
    ELSE NULL
  END;
$$;

SELECT is(public.email_persona_teste_relatorios('Administrador'), 'admin@aptusflow.local', 'email_persona_teste_relatorios: Administrador');
SELECT is(public.email_persona_teste_relatorios('Financeiro'), 'financeiro@aptusflow.local', 'email_persona_teste_relatorios: Financeiro');
SELECT is(public.email_persona_teste_relatorios('Projetos'), 'projetos@aptusflow.local', 'email_persona_teste_relatorios: Projetos');
SELECT is(public.email_persona_teste_relatorios('Comercial'), 'comercial@aptusflow.local', 'email_persona_teste_relatorios: Comercial');
SELECT is(public.email_persona_teste_relatorios('Tecnico'), 'tecnico@aptusflow.local', 'email_persona_teste_relatorios: Tecnico');
SELECT is(public.email_persona_teste_relatorios('Visualizador'), 'visualizador_teste_008@aptusflow.local', 'email_persona_teste_relatorios: Visualizador');

-- 1.2 Fixture local idempotente do usuario Visualizador de teste desta
-- feature. Replica o INSERT em auth.users usado por criar_perfil_teste em
-- supabase/seed.sql / pela fixture de 05_capacidades.sql secao 5; o trigger
-- public.handle_auth_user_sync() cria automaticamente a linha correspondente
-- em public.perfis com perfil_acesso = 'Visualizador' e status = 'Ativo'
-- (comportamento padrao de novo cadastro). Usa e-mail proprio
-- (visualizador_teste_008@aptusflow.local) para nao acoplar este arquivo ao
-- ciclo de vida do fixture de 05_capacidades.sql.
CREATE OR REPLACE FUNCTION public.fixture_persona_visualizador_008()
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'visualizador_teste_008@aptusflow.local';
  IF v_user_id IS NOT NULL THEN
    RETURN v_user_id;
  END IF;

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
    'visualizador_teste_008@aptusflow.local',
    crypt('SenhaDeTesteSegura123!', gen_salt('bf', 10)),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('nome', 'Visualizador Teste 008'),
    now(),
    now(),
    '', '', '', false, '', '', '', ''
  )
  RETURNING id INTO v_user_id;

  RETURN v_user_id;
END;
$$;

SELECT ok(
  public.fixture_persona_visualizador_008() IS NOT NULL,
  'fixture_persona_visualizador_008 cria (ou reaproveita) o usuario de teste Visualizador desta feature'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.perfis p
    JOIN auth.users u ON u.id = p.usuario_id
    WHERE u.email = 'visualizador_teste_008@aptusflow.local'
      AND p.perfil_acesso = 'Visualizador'
      AND p.status = 'Ativo'
  ),
  'persona Visualizador de teste (008) tem perfil Visualizador/Ativo via trigger padrao de cadastro'
);

-- Idempotencia: chamar de novo nao deve criar um segundo usuario.
SELECT is(
  (SELECT count(*)::int FROM auth.users WHERE email = 'visualizador_teste_008@aptusflow.local'),
  1,
  'fixture_persona_visualizador_008 e idempotente (uma unica linha em auth.users apos chamadas repetidas)'
);


-- ============================================================
-- 2. Helpers de fixture para public.exportacoes_relatorios por status
-- ============================================================
-- Uso previsto pelas fases seguintes (T024-T026, T044-T046, T059-T060):
--   SELECT reset_auth(); -- garante execucao como role padrao (bypassa RLS)
--   SELECT public.fixture_exportacao_pendente('financeiro@aptusflow.local', 'Financeiro');
--   SELECT public.fixture_exportacao_pronta('financeiro@aptusflow.local', 'Financeiro');
--   SELECT public.fixture_exportacao_falhou('projetos@aptusflow.local', 'Projetos', 'Falha simulada X');
--   SELECT public.fixture_exportacao_expirada('projetos@aptusflow.local', 'Projetos');
--   SELECT public.fixture_exportacao_indisponivel('admin@aptusflow.local', 'Clientes');
--
-- Nenhuma funcao usa SECURITY DEFINER (mesmo racional da secao 1). Devem ser
-- chamadas com a sessao no role padrao (logo apos reset_auth()), nao apos
-- set_auth_by_email(...)/set_anon(), pois RLS de public.exportacoes_relatorios
-- restringe INSERT a quem tem permissao_modulo('relatorios').pode_escrever, o
-- que nao vale para todas as personas que estas fixtures precisam simular
-- (ex.: gerar uma exportacao "de outro usuario" para testes de escopo/ownership
-- em US2/US3).
--
-- NOTA (TDD): public.exportacoes_relatorios ainda NAO tem as colunas
-- data_inicial, data_final, arquivo_path, arquivo_nome, mime_type,
-- tamanho_bytes, erro, criado_em, atualizado_em usadas abaixo (verificado
-- neste banco antes de escrever este arquivo). PL/pgSQL so valida os
-- comandos SQL do corpo da funcao na primeira execucao, entao a definicao
-- abaixo e criada com sucesso mesmo antes da migration em paralelo adicionar
-- essas colunas; CHAMAR qualquer uma destas funcoes hoje falha com
-- "column ... does not exist" ate essa migration ser aplicada. Esta rodada
-- (T023) verifica apenas que os helpers estao registrados no catalogo —
-- exercita-los de fato e responsabilidade dos testes de comportamento das
-- fases seguintes.

CREATE OR REPLACE FUNCTION public.fixture_exportacao_relatorio(
  p_persona_email text,
  p_tipo text,
  p_status text,
  p_formato text DEFAULT 'PDF',
  p_data_inicial date DEFAULT date_trunc('month', current_date)::date,
  p_data_final date DEFAULT current_date,
  p_expira_em timestamptz DEFAULT NULL,
  p_erro text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid := gen_random_uuid();
  v_user_id uuid;
  v_arquivo_nome text;
  v_arquivo_path text;
  v_mime_type text;
  v_gerado_em timestamptz;
  v_expira_em timestamptz;
  v_tamanho_bytes bigint;
BEGIN
  IF p_status NOT IN ('Pendente', 'Pronto', 'Falhou', 'Indisponível') THEN
    RAISE EXCEPTION 'fixture_exportacao_relatorio: status invalido (%). Use Pendente, Pronto, Falhou ou Indisponível; para simular "Expirado" use fixture_exportacao_expirada (Pronto + expira_em no passado, ja que Expirado e status_exibicao computado, nao persistido).', p_status;
  END IF;

  SELECT id INTO v_user_id FROM auth.users WHERE email = p_persona_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'fixture_exportacao_relatorio: persona de teste nao encontrada (%)', p_persona_email;
  END IF;

  IF p_status = 'Pronto' THEN
    v_arquivo_nome := format(
      'relatorio-%s-%s-%s-%s.%s',
      lower(p_tipo), p_data_inicial, p_data_final, left(replace(v_id::text, '-', ''), 6),
      CASE WHEN p_formato = 'PDF' THEN 'pdf' ELSE 'zip' END
    );
    v_arquivo_path := format('%s/%s/%s/%s', lower(p_tipo), extract(year from p_data_final)::int, v_id, v_arquivo_nome);
    v_mime_type := CASE WHEN p_formato = 'PDF' THEN 'application/pdf' ELSE 'application/zip' END;
    v_gerado_em := now();
    v_expira_em := coalesce(p_expira_em, now() + interval '12 months');
    v_tamanho_bytes := 128000;
  END IF;

  INSERT INTO public.exportacoes_relatorios (
    id, tipo, formato, status, data_inicial, data_final,
    arquivo_path, arquivo_nome, mime_type, tamanho_bytes,
    criado_por, gerado_em, expira_em, erro, criado_em, atualizado_em
  ) VALUES (
    v_id, p_tipo, p_formato, p_status, p_data_inicial, p_data_final,
    v_arquivo_path, v_arquivo_nome, v_mime_type, v_tamanho_bytes,
    v_user_id, v_gerado_em, v_expira_em,
    CASE WHEN p_status = 'Falhou' THEN coalesce(p_erro, 'Falha simulada em fixture de teste (008)') ELSE NULL END,
    now(), now()
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fixture_exportacao_pendente(
  p_persona_email text,
  p_tipo text,
  p_formato text DEFAULT 'PDF'
)
RETURNS uuid
LANGUAGE sql
AS $$
  SELECT public.fixture_exportacao_relatorio(
    p_persona_email => p_persona_email,
    p_tipo => p_tipo,
    p_status => 'Pendente',
    p_formato => p_formato
  );
$$;

CREATE OR REPLACE FUNCTION public.fixture_exportacao_pronta(
  p_persona_email text,
  p_tipo text,
  p_formato text DEFAULT 'PDF'
)
RETURNS uuid
LANGUAGE sql
AS $$
  SELECT public.fixture_exportacao_relatorio(
    p_persona_email => p_persona_email,
    p_tipo => p_tipo,
    p_status => 'Pronto',
    p_formato => p_formato
  );
$$;

CREATE OR REPLACE FUNCTION public.fixture_exportacao_falhou(
  p_persona_email text,
  p_tipo text,
  p_erro text DEFAULT NULL,
  p_formato text DEFAULT 'PDF'
)
RETURNS uuid
LANGUAGE sql
AS $$
  SELECT public.fixture_exportacao_relatorio(
    p_persona_email => p_persona_email,
    p_tipo => p_tipo,
    p_status => 'Falhou',
    p_formato => p_formato,
    p_erro => p_erro
  );
$$;

CREATE OR REPLACE FUNCTION public.fixture_exportacao_expirada(
  p_persona_email text,
  p_tipo text,
  p_formato text DEFAULT 'PDF'
)
RETURNS uuid
LANGUAGE sql
AS $$
  SELECT public.fixture_exportacao_relatorio(
    p_persona_email => p_persona_email,
    p_tipo => p_tipo,
    p_status => 'Pronto',
    p_formato => p_formato,
    p_expira_em => now() - interval '1 day'
  );
$$;

CREATE OR REPLACE FUNCTION public.fixture_exportacao_indisponivel(
  p_persona_email text,
  p_tipo text,
  p_formato text DEFAULT 'PDF'
)
RETURNS uuid
LANGUAGE sql
AS $$
  SELECT public.fixture_exportacao_relatorio(
    p_persona_email => p_persona_email,
    p_tipo => p_tipo,
    p_status => 'Indisponível',
    p_formato => p_formato
  );
$$;

-- Verifica apenas que os helpers estao registrados no catalogo (ver NOTA
-- acima sobre por que nao sao invocados nesta rodada).
SELECT ok(to_regprocedure('public.fixture_exportacao_relatorio(text, text, text, text, date, date, timestamptz, text)') IS NOT NULL, 'helper fixture_exportacao_relatorio registrado');
SELECT ok(to_regprocedure('public.fixture_exportacao_pendente(text, text, text)') IS NOT NULL, 'helper fixture_exportacao_pendente registrado');
SELECT ok(to_regprocedure('public.fixture_exportacao_pronta(text, text, text)') IS NOT NULL, 'helper fixture_exportacao_pronta registrado');
SELECT ok(to_regprocedure('public.fixture_exportacao_falhou(text, text, text, text)') IS NOT NULL, 'helper fixture_exportacao_falhou registrado');
SELECT ok(to_regprocedure('public.fixture_exportacao_expirada(text, text, text)') IS NOT NULL, 'helper fixture_exportacao_expirada registrado');
SELECT ok(to_regprocedure('public.fixture_exportacao_indisponivel(text, text, text)') IS NOT NULL, 'helper fixture_exportacao_indisponivel registrado');


-- ============================================================
-- 3. Storage: bucket relatorios-exportados deve ser privado
-- ============================================================
-- Contrato: specs/008-exportar-relatorios/contracts/storage-and-retention.md
--   - "Private bucket." / "No public access."
--   - "Objects are accessed only through short-lived signed URLs generated by
--      relatorios-exportacao."
--   - "Bucket policies must deny public object reads."
--   - "Browser clients should not list or read objects directly."
--   - "...should not expose broad authenticated access."

-- --- 3.1 O bucket precisa existir e ser privado -----------------------------
-- Estes dois testes DEVEM falhar ate a migration em paralelo
-- (supabase/migrations/*_exportar_relatorios.sql, T008) criar o bucket —
-- comportamento correto de um teste escrito antes da implementacao.

SELECT reset_auth();

SELECT ok(
  EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'relatorios-exportados'),
  'bucket relatorios-exportados existe em storage.buckets'
);

SELECT ok(
  NOT coalesce((SELECT public FROM storage.buckets WHERE id = 'relatorios-exportados'), true),
  'bucket relatorios-exportados nao e publico (storage.buckets.public = false)'
);

-- --- 3.2 Fixture: objeto simulado dentro do bucket privado ------------------
-- Insere diretamente como role padrao (bypassa RLS, mesma tecnica das
-- fixtures diretas de tarefas/projetos em 05_capacidades.sql). Nao depende do
-- Storage API/Edge Function reais terem rodado. O INSERT ... SELECT ... WHERE
-- EXISTS evita violar a FK objects_bucketId_fkey enquanto o bucket ainda nao
-- existe (0 linhas inseridas em vez de erro, para nao abortar o restante do
-- arquivo). Idempotencia via ON CONFLICT (nao DELETE): storage.objects tem um
-- trigger storage.protect_delete() que bloqueia DELETE direto na tabela
-- ("Direct deletion from storage tables is not allowed. Use the Storage API
-- instead."), entao repetir este arquivo sem `supabase db reset` deve
-- atualizar a linha existente em vez de apaga-la.

INSERT INTO storage.objects (bucket_id, name, owner, metadata)
SELECT
  'relatorios-exportados',
  'financeiro/2026/00000000-0000-0000-0000-000000000008/fixture-008-privacidade.pdf',
  (SELECT id FROM auth.users WHERE email = 'financeiro@aptusflow.local'),
  '{"mimetype":"application/pdf"}'::jsonb
WHERE EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'relatorios-exportados')
ON CONFLICT (bucket_id, name) DO UPDATE
  SET owner = excluded.owner,
      metadata = excluded.metadata;

SELECT is(
  (SELECT count(*)::int FROM storage.objects
   WHERE bucket_id = 'relatorios-exportados'
     AND name = 'financeiro/2026/00000000-0000-0000-0000-000000000008/fixture-008-privacidade.pdf'),
  1,
  'setup: objeto fixture inserido em storage.objects para o bucket privado via role padrao (se este assert falhar, o bucket ainda nao existe e os testes de leitura negada abaixo ficam inconclusivos)'
);

-- --- 3.3 Leitura ampla e negada para anon, authenticated alheio e o dono ----
-- Em nenhum caso um cliente deve enxergar o objeto via SELECT direto em
-- storage.objects: o unico caminho de acesso previsto pelo contrato e uma
-- signed URL de curta duracao emitida pela Edge Function relatorios-exportacao
-- apos autorizacao via autorizar_download_exportacao_relatorio. Hoje
-- (verificado neste banco) storage.objects e storage.buckets tem ROW LEVEL
-- SECURITY habilitado e NENHUMA policy — ou seja, qualquer policy futura
-- adicionada pela migration em paralelo que exponha leitura ampla para
-- anon/authenticated quebraria estes testes.

SELECT set_anon();

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'relatorios-exportados'),
  0,
  'anon nao enxerga nenhum objeto do bucket relatorios-exportados via SELECT direto em storage.objects'
);

SELECT reset_auth();
SELECT set_auth_by_email('comercial@aptusflow.local');

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'relatorios-exportados'),
  0,
  'authenticated sem relacao com o objeto (Comercial) nao enxerga objetos do bucket relatorios-exportados via SELECT direto em storage.objects'
);

SELECT reset_auth();
SELECT set_auth_by_email('financeiro@aptusflow.local');

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'relatorios-exportados'),
  0,
  'authenticated dono do objeto (Financeiro) tambem nao enxerga objetos do bucket relatorios-exportados via SELECT direto em storage.objects (acesso deve ocorrer so via signed URL emitida pela Edge Function)'
);

SELECT reset_auth();


-- ============================================================
-- 4. iniciar_exportacao_relatorio: autenticacao, capacidade e matriz de
--    categoria por persona (T024)
-- ============================================================
-- Convencoes de asserção de erro (ver comentário no topo de
-- supabase/tests/05_capacidades.sql): throws_ok(sql, sqlstate) de 2
-- argumentos checa apenas o SQLSTATE, documentado por um comentário SQL logo
-- acima/abaixo da chamada; throws_ok(sql, sqlstate, errmsg) de 3 argumentos
-- (nesta instalação de pgTAP) exige que errmsg bata com o texto EXATO da
-- exceção, usado aqui só quando é necessário distinguir duas exceções que
-- carregam o mesmo SQLSTATE 'P0001' (ex.: PERMISSION_DENIED x
-- INVALID_CATEGORY). Todas as RAISE EXCEPTION de negócio em
-- iniciar_exportacao_relatorio usam SQLSTATE default 'P0001', exceto o guard
-- de autenticação ('Unauthorized' com ERRCODE 42501).
--
-- Periodo fixo (2026-01-01..2026-01-31) usado nesta seção: qualquer período
-- válido serve para os testes de autenticação/capacidade/categoria, que não
-- dependem de dados existentes — apenas do sucesso/falha da autorização.

-- --- 4.1 Chamador anônimo é rejeitado (42501) -------------------------------
SELECT set_anon();

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  '42501'
); -- anon é rejeitado por iniciar_exportacao_relatorio (Unauthorized)

SELECT reset_auth();

-- --- 4.2 Matriz de categoria exportável por persona (data-model.md
--         "Entity: Exportable Category Policy") ---------------------------
-- Cobre simultaneamente o requisito de "capacidade" (Visualizador/Comercial/
-- Tecnico não têm relatorios.exportar e por isso são rejeitados nas 4
-- categorias) e o requisito de "matriz de categoria por persona".

-- Administrador: todas as 4 categorias.
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Administrador'));

SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Administrador pode iniciar_exportacao_relatorio para Financeiro'
);
SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Administrador pode iniciar_exportacao_relatorio para DRE'
);
SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Administrador pode iniciar_exportacao_relatorio para Clientes'
);
SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Administrador pode iniciar_exportacao_relatorio para Projetos'
);

SELECT reset_auth();

-- Financeiro: só Financeiro e DRE.
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Financeiro pode iniciar_exportacao_relatorio para Financeiro'
);
SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Financeiro pode iniciar_exportacao_relatorio para DRE'
);
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Financeiro não pode iniciar_exportacao_relatorio para Clientes (PERMISSION_DENIED)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Financeiro não pode iniciar_exportacao_relatorio para Projetos (PERMISSION_DENIED)

SELECT reset_auth();

-- Projetos: só Projetos.
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Projetos'));

SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'Projetos pode iniciar_exportacao_relatorio para Projetos'
);
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Projetos não pode iniciar_exportacao_relatorio para Financeiro (PERMISSION_DENIED)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Projetos não pode iniciar_exportacao_relatorio para DRE (PERMISSION_DENIED)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Projetos não pode iniciar_exportacao_relatorio para Clientes (PERMISSION_DENIED)

SELECT reset_auth();

-- Visualizador, Comercial e Tecnico: nenhuma categoria (sem capacidade
-- relatorios.exportar — 05_capacidades.sql confirma que nenhum dos três tem
-- essa capacidade na matriz canônica).
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Visualizador'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Visualizador não pode iniciar_exportacao_relatorio para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Visualizador não pode iniciar_exportacao_relatorio para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Visualizador não pode iniciar_exportacao_relatorio para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Visualizador não pode iniciar_exportacao_relatorio para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Comercial'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Comercial não pode iniciar_exportacao_relatorio para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Comercial não pode iniciar_exportacao_relatorio para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Comercial não pode iniciar_exportacao_relatorio para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Comercial não pode iniciar_exportacao_relatorio para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Tecnico'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Tecnico não pode iniciar_exportacao_relatorio para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Tecnico não pode iniciar_exportacao_relatorio para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Tecnico não pode iniciar_exportacao_relatorio para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001'
); -- Tecnico não pode iniciar_exportacao_relatorio para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();

-- --- 4.3 Personalizado é bloqueado explicitamente (INVALID_CATEGORY) -------
-- Mesmo o Administrador (que teria capacidade e, em tese, acesso a qualquer
-- categoria) é rejeitado, pois 'Personalizado' está fora do conjunto
-- {Financeiro, DRE, Clientes, Projetos} aceito por esta feature (data-model.md
-- "Entity: Exportable Category Policy": "Personalizado não é exportável no
-- escopo 008"). O uso do errmsg exato (3º argumento) aqui distingue
-- deliberadamente esta rejeição estrutural (INVALID_CATEGORY) da rejeição de
-- permissão por perfil (PERMISSION_DENIED) testada acima.
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Administrador'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Personalizado', 'PDF', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001',
  'INVALID_CATEGORY'
); -- Personalizado é bloqueado estruturalmente mesmo para Administrador

SELECT reset_auth();


-- ============================================================
-- 5. Validação de período (T025)
-- ============================================================
-- Regra exata (data-model.md "Entity: Export Period"): data_inicial <=
-- data_final; período de um dia é permitido; máximo inclusivo de 12 meses
-- corridos (2026-01-01..2026-12-31 permitido; 2026-01-01..2027-01-01
-- bloqueado). Testado tanto diretamente no helper validador quanto de ponta a
-- ponta via iniciar_exportacao_relatorio (que a invoca internamente).

-- --- 5.1 Direto em public.validar_periodo_exportacao -----------------------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Administrador'));

SELECT throws_ok(
  $$SELECT public.validar_periodo_exportacao('2026-02-01'::date, '2026-01-01'::date)$$,
  'P0001',
  'INVALID_PERIOD'
); -- data final antes da inicial é bloqueada (INVALID_PERIOD)

SELECT lives_ok(
  $$SELECT public.validar_periodo_exportacao('2026-06-15'::date, '2026-06-15'::date)$$,
  'período de um único dia (data_inicial = data_final) é permitido'
);

SELECT lives_ok(
  $$SELECT public.validar_periodo_exportacao('2026-01-01'::date, '2026-12-31'::date)$$,
  'período de até 12 meses corridos inclusivos (2026-01-01 a 2026-12-31) é permitido'
);

SELECT throws_ok(
  $$SELECT public.validar_periodo_exportacao('2026-01-01'::date, '2027-01-01'::date)$$,
  'P0001',
  'PERIOD_TOO_LONG'
); -- período de 2026-01-01 a 2027-01-01 excede 12 meses e é bloqueado (PERIOD_TOO_LONG)

SELECT reset_auth();

-- --- 5.2 De ponta a ponta via iniciar_exportacao_relatorio ------------------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-02-01'::date, '2026-01-01'::date)$$,
  'P0001',
  'INVALID_PERIOD'
); -- iniciar_exportacao_relatorio propaga INVALID_PERIOD da validação de período

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2027-01-01'::date)$$,
  'P0001',
  'PERIOD_TOO_LONG'
); -- iniciar_exportacao_relatorio propaga PERIOD_TOO_LONG da validação de período

SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-01-01'::date, '2026-12-31'::date)$$,
  'iniciar_exportacao_relatorio aceita o período máximo permitido de 12 meses corridos (2026-01-01 a 2026-12-31)'
);

SELECT lives_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'PDF', '2026-06-15'::date, '2026-06-15'::date)$$,
  'iniciar_exportacao_relatorio aceita período de um único dia (data_inicial = data_final)'
);

SELECT reset_auth();


-- ============================================================
-- 6. Formato do payload completo por categoria (T026)
-- ============================================================
-- Fonte: data-model.md "Entity: Report Payload" (estrutura comum) e
-- "Category Payload Requirements" (resumo/detalhes por categoria). Em vez de
-- assumir contagens fixas do seed (que podem ser alteradas por fixtures de
-- outros arquivos pgTAP executados antes deste, ex.: criar_lancamento_financeiro
-- em 05_capacidades.sql), cada bloco calcula a contagem real esperada via
-- consulta direta (role padrão, bypassa RLS) imediatamente antes de chamar a
-- RPC, e depois valida que o payload retornado é consistente com essa
-- contagem — o alvo é o FORMATO do payload, não um dataset específico.
--
-- O payload jsonb é serializado como texto em uma GUC de sessão
-- (set_config/current_setting), a mesma técnica já usada em 05_capacidades.sql
-- para atravessar trocas de role entre chamadas.

-- --- 6.1 Financeiro (CR-001) -------------------------------------------------
SELECT reset_auth();
SELECT set_config(
  'test.qtd_lanc_periodo',
  (SELECT count(*)::text FROM public.lancamentos WHERE data_competencia BETWEEN (current_date - 30) AND (current_date + 5)),
  false
);

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT set_config(
  'test.payload_financeiro',
  (public.iniciar_exportacao_relatorio('Financeiro', 'PDF', (current_date - 30)::date, (current_date + 5)::date))::text,
  false
);

SELECT reset_auth();

SELECT ok(
  (current_setting('test.payload_financeiro')::jsonb) ?& ARRAY['exportacao_id', 'tipo', 'formato', 'periodo', 'solicitante', 'resumo', 'detalhes', 'mensagem_sem_dados'],
  'Financeiro: payload contém todas as chaves de nível superior do contrato (rpc-exportacao-relatorios.md)'
);

SELECT is(
  current_setting('test.payload_financeiro')::jsonb ->> 'tipo',
  'Financeiro',
  'Financeiro: payload.tipo reflete a categoria solicitada'
);

SELECT is(
  current_setting('test.payload_financeiro')::jsonb -> 'periodo' ->> 'data_inicial',
  (current_date - 30)::text,
  'Financeiro: payload.periodo.data_inicial reflete o período solicitado'
);

SELECT is(
  current_setting('test.payload_financeiro')::jsonb -> 'periodo' ->> 'data_final',
  (current_date + 5)::text,
  'Financeiro: payload.periodo.data_final reflete o período solicitado'
);

SELECT ok(
  (current_setting('test.payload_financeiro')::jsonb -> 'solicitante') ?& ARRAY['id', 'nome'],
  'Financeiro: payload.solicitante contém id e nome'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_financeiro')::jsonb -> 'resumo'),
  'array',
  'Financeiro: payload.resumo é um array (resumo executivo)'
);

SELECT set_eq(
  format($$SELECT (jsonb_array_elements(%L::jsonb -> 'resumo'))->>'label'$$, current_setting('test.payload_financeiro')),
  $$VALUES ('Receitas'), ('Despesas'), ('Saldo'), ('Quantidade de lançamentos')$$,
  'Financeiro: resumo tem exatamente os 4 labels definidos em CR-001'
);

SELECT ok(
  coalesce((
    SELECT bool_and(elem ?& ARRAY['label', 'valor'])
    FROM jsonb_array_elements(current_setting('test.payload_financeiro')::jsonb -> 'resumo') elem
  ), false),
  'Financeiro: todo item de resumo tem as chaves label e valor'
);

SELECT is(
  (
    SELECT (elem ->> 'valor')::numeric
    FROM jsonb_array_elements(current_setting('test.payload_financeiro')::jsonb -> 'resumo') elem
    WHERE elem ->> 'label' = 'Quantidade de lançamentos'
  ),
  current_setting('test.qtd_lanc_periodo')::numeric,
  'Financeiro: resumo "Quantidade de lançamentos" bate com a contagem real de lançamentos no período'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_financeiro')::jsonb -> 'detalhes'),
  'array',
  'Financeiro: payload.detalhes é um array (linhas detalhadas)'
);

SELECT is(
  jsonb_array_length(current_setting('test.payload_financeiro')::jsonb -> 'detalhes'),
  current_setting('test.qtd_lanc_periodo')::int,
  'Financeiro: quantidade de linhas em detalhes bate com a contagem real de lançamentos no período'
);

SELECT ok(
  coalesce((
    SELECT bool_and(elem ?& ARRAY['data', 'tipo', 'natureza', 'status', 'categoria', 'descricao', 'cliente', 'projeto', 'valor'])
    FROM jsonb_array_elements(current_setting('test.payload_financeiro')::jsonb -> 'detalhes') elem
  ), true),
  'Financeiro: toda linha de detalhes tem as colunas esperadas (CR-001)'
);

SELECT is(
  (current_setting('test.payload_financeiro')::jsonb ->> 'mensagem_sem_dados') IS NULL,
  current_setting('test.qtd_lanc_periodo')::int > 0,
  'Financeiro: mensagem_sem_dados é nulo quando há lançamentos no período e preenchido quando não há'
);

-- --- 6.2 DRE (CR-002) --------------------------------------------------------
SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT set_config(
  'test.payload_dre',
  (public.iniciar_exportacao_relatorio('DRE', 'PDF', (current_date - 30)::date, (current_date + 5)::date))::text,
  false
);

SELECT reset_auth();

SELECT ok(
  (current_setting('test.payload_dre')::jsonb) ?& ARRAY['exportacao_id', 'tipo', 'formato', 'periodo', 'solicitante', 'resumo', 'detalhes', 'mensagem_sem_dados'],
  'DRE: payload contém todas as chaves de nível superior do contrato'
);

SELECT is(
  current_setting('test.payload_dre')::jsonb ->> 'tipo',
  'DRE',
  'DRE: payload.tipo reflete a categoria solicitada'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_dre')::jsonb -> 'resumo'),
  'array',
  'DRE: payload.resumo é um array (resumo executivo)'
);

SELECT set_eq(
  format($$SELECT (jsonb_array_elements(%L::jsonb -> 'resumo'))->>'label'$$, current_setting('test.payload_dre')),
  $$VALUES ('Faturamento bruto'), ('Deduções'), ('Custos operacionais'), ('Resultado líquido')$$,
  'DRE: resumo tem exatamente os 4 labels definidos em CR-002'
);

SELECT ok(
  coalesce((
    SELECT bool_and(elem ?& ARRAY['label', 'valor'])
    FROM jsonb_array_elements(current_setting('test.payload_dre')::jsonb -> 'resumo') elem
  ), false),
  'DRE: todo item de resumo tem as chaves label e valor'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_dre')::jsonb -> 'detalhes'),
  'array',
  'DRE: payload.detalhes é um array (linhas detalhadas)'
);

SELECT is(
  jsonb_array_length(current_setting('test.payload_dre')::jsonb -> 'detalhes'),
  current_setting('test.qtd_lanc_periodo')::int,
  'DRE: quantidade de linhas em detalhes bate com a contagem real de lançamentos no período (mesmo universo do Financeiro)'
);

SELECT ok(
  coalesce((
    SELECT bool_and(elem ?& ARRAY['data', 'grupo_dre', 'categoria', 'descricao', 'valor'])
    FROM jsonb_array_elements(current_setting('test.payload_dre')::jsonb -> 'detalhes') elem
  ), true),
  'DRE: toda linha de detalhes tem as colunas esperadas (CR-002)'
);

-- --- 6.3 Clientes (CR-003) ---------------------------------------------------
SELECT reset_auth();
SELECT set_config('test.qtd_clientes', (SELECT count(*)::text FROM public.clientes), false);

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Administrador'));

SELECT set_config(
  'test.payload_clientes',
  (public.iniciar_exportacao_relatorio('Clientes', 'PDF', (current_date - 30)::date, (current_date + 5)::date))::text,
  false
);

SELECT reset_auth();

SELECT ok(
  (current_setting('test.payload_clientes')::jsonb) ?& ARRAY['exportacao_id', 'tipo', 'formato', 'periodo', 'solicitante', 'resumo', 'detalhes', 'mensagem_sem_dados'],
  'Clientes: payload contém todas as chaves de nível superior do contrato'
);

SELECT is(
  current_setting('test.payload_clientes')::jsonb ->> 'tipo',
  'Clientes',
  'Clientes: payload.tipo reflete a categoria solicitada'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_clientes')::jsonb -> 'resumo'),
  'array',
  'Clientes: payload.resumo é um array (resumo executivo)'
);

SELECT set_eq(
  format($$SELECT (jsonb_array_elements(%L::jsonb -> 'resumo'))->>'label'$$, current_setting('test.payload_clientes')),
  $$VALUES ('Total de clientes'), ('Ativos'), ('Inativos'), ('Novos no período'), ('Atendimentos no período')$$,
  'Clientes: resumo tem exatamente os 5 labels definidos em CR-003'
);

SELECT is(
  (
    SELECT (elem ->> 'valor')::numeric
    FROM jsonb_array_elements(current_setting('test.payload_clientes')::jsonb -> 'resumo') elem
    WHERE elem ->> 'label' = 'Total de clientes'
  ),
  current_setting('test.qtd_clientes')::numeric,
  'Clientes: resumo "Total de clientes" bate com a contagem real de clientes cadastrados'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_clientes')::jsonb -> 'detalhes'),
  'array',
  'Clientes: payload.detalhes é um array (snapshot por cliente)'
);

SELECT is(
  jsonb_array_length(current_setting('test.payload_clientes')::jsonb -> 'detalhes'),
  current_setting('test.qtd_clientes')::int,
  'Clientes: quantidade de linhas em detalhes bate com a contagem real de clientes (snapshot atual, não filtrado por período)'
);

SELECT ok(
  coalesce((
    SELECT bool_and(elem ?& ARRAY['id', 'nome_contato', 'empresa', 'email', 'telefone', 'tipo', 'status', 'criado_em', 'atualizado_em', 'atendimentos_no_periodo'])
    FROM jsonb_array_elements(current_setting('test.payload_clientes')::jsonb -> 'detalhes') elem
  ), true),
  'Clientes: toda linha de detalhes tem as colunas esperadas (CR-003)'
);

-- --- 6.4 Projetos (CR-004) ---------------------------------------------------
SELECT reset_auth();
SELECT set_config('test.qtd_projetos', (SELECT count(*)::text FROM public.projetos), false);

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Projetos'));

SELECT set_config(
  'test.payload_projetos',
  (public.iniciar_exportacao_relatorio('Projetos', 'PDF', (current_date - 30)::date, (current_date + 5)::date))::text,
  false
);

SELECT reset_auth();

SELECT ok(
  (current_setting('test.payload_projetos')::jsonb) ?& ARRAY['exportacao_id', 'tipo', 'formato', 'periodo', 'solicitante', 'resumo', 'detalhes', 'mensagem_sem_dados'],
  'Projetos: payload contém todas as chaves de nível superior do contrato'
);

SELECT is(
  current_setting('test.payload_projetos')::jsonb ->> 'tipo',
  'Projetos',
  'Projetos: payload.tipo reflete a categoria solicitada'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_projetos')::jsonb -> 'resumo'),
  'array',
  'Projetos: payload.resumo é um array (resumo executivo)'
);

SELECT set_eq(
  format($$SELECT (jsonb_array_elements(%L::jsonb -> 'resumo'))->>'label'$$, current_setting('test.payload_projetos')),
  $$VALUES ('Total de projetos'), ('Planejamento'), ('Em andamento'), ('Concluído'), ('Horas apontadas no período'), ('Tarefas concluídas no período')$$,
  'Projetos: resumo tem exatamente os 6 labels definidos em CR-004'
);

SELECT is(
  (
    SELECT (elem ->> 'valor')::numeric
    FROM jsonb_array_elements(current_setting('test.payload_projetos')::jsonb -> 'resumo') elem
    WHERE elem ->> 'label' = 'Total de projetos'
  ),
  current_setting('test.qtd_projetos')::numeric,
  'Projetos: resumo "Total de projetos" bate com a contagem real de projetos cadastrados'
);

SELECT is(
  jsonb_typeof(current_setting('test.payload_projetos')::jsonb -> 'detalhes'),
  'array',
  'Projetos: payload.detalhes é um array (snapshot por projeto)'
);

SELECT is(
  jsonb_array_length(current_setting('test.payload_projetos')::jsonb -> 'detalhes'),
  current_setting('test.qtd_projetos')::int,
  'Projetos: quantidade de linhas em detalhes bate com a contagem real de projetos (snapshot atual, não filtrado por período)'
);

SELECT ok(
  coalesce((
    SELECT bool_and(elem ?& ARRAY['id', 'nome', 'cliente', 'status', 'prazo', 'responsavel', 'progresso', 'orcamento', 'orcamento_utilizado', 'horas_apontadas_no_periodo', 'tarefas_concluidas_no_periodo'])
    FROM jsonb_array_elements(current_setting('test.payload_projetos')::jsonb -> 'detalhes') elem
  ), true),
  'Projetos: toda linha de detalhes tem as colunas esperadas (CR-004)'
);

SELECT reset_auth();


-- ============================================================
-- 7. Escopo de historico/download por persona (T044)
-- ============================================================
-- Fonte: contracts/rpc-exportacao-relatorios.md ("Enforce history visibility" /
-- listar_exportacoes_relatorios "Scope results by persona") e data-model.md
-- ("RLS and Access Rules"): Administrador ve/baixa qualquer exportacao;
-- Financeiro e Projetos veem/baixam apenas as proprias.
--
-- Para isolar "escopo por ownership" de "escopo por categoria" (regras
-- distintas, ja cobertas separadamente na secao 4 / Fase US3), cada persona
-- não-admin ganha aqui DUAS fixtures na MESMA categoria em que tem permissão
-- (Financeiro -> tipo Financeiro; Projetos -> tipo Projetos): uma própria e
-- outra pertencente ao Administrador. Assim, se a listagem/download vazar a
-- exportação alheia, o motivo não pode ser "categoria não permitida".

SELECT reset_auth();

SELECT set_config('test.t044_admin_clientes', public.fixture_exportacao_pronta('admin@aptusflow.local', 'Clientes')::text, false);
SELECT set_config('test.t044_financeiro_propria', public.fixture_exportacao_pronta('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t044_admin_financeiro', public.fixture_exportacao_pronta('admin@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t044_projetos_propria', public.fixture_exportacao_pronta('projetos@aptusflow.local', 'Projetos')::text, false);
SELECT set_config('test.t044_admin_projetos', public.fixture_exportacao_pronta('admin@aptusflow.local', 'Projetos')::text, false);

-- --- 7.1 Administrador enxerga e baixa as 5 exportações (proprias e alheias) --
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Administrador'));

SELECT ok(
  (SELECT count(*)::int FROM public.listar_exportacoes_relatorios()
   WHERE id::text IN (
     current_setting('test.t044_admin_clientes'),
     current_setting('test.t044_financeiro_propria'),
     current_setting('test.t044_admin_financeiro'),
     current_setting('test.t044_projetos_propria'),
     current_setting('test.t044_admin_projetos')
   )) = 5,
  'listar_exportacoes_relatorios: Administrador enxerga as 5 exportações de teste (próprias e de outros usuários)'
);

SELECT lives_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_financeiro_propria')),
  'autorizar_download_exportacao_relatorio: Administrador baixa exportação pertencente ao Financeiro'
);
SELECT lives_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_projetos_propria')),
  'autorizar_download_exportacao_relatorio: Administrador baixa exportação pertencente ao Projetos'
);
SELECT lives_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_admin_clientes')),
  'autorizar_download_exportacao_relatorio: Administrador baixa a própria exportação (Clientes)'
);

SELECT reset_auth();

-- --- 7.2 Financeiro enxerga/baixa apenas a própria exportação Financeiro ----
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.listar_exportacoes_relatorios()
    WHERE id::text = current_setting('test.t044_financeiro_propria')
  ),
  'listar_exportacoes_relatorios: Financeiro enxerga a própria exportação'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.listar_exportacoes_relatorios()
    WHERE id::text = current_setting('test.t044_admin_financeiro')
  ),
  'listar_exportacoes_relatorios: Financeiro NÃO enxerga exportação de mesma categoria pertencente ao Administrador'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.listar_exportacoes_relatorios()
    WHERE id::text = current_setting('test.t044_admin_clientes')
  ),
  'listar_exportacoes_relatorios: Financeiro NÃO enxerga exportação de Clientes pertencente ao Administrador'
);

SELECT lives_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_financeiro_propria')),
  'autorizar_download_exportacao_relatorio: Financeiro baixa a própria exportação (Financeiro)'
);

-- Mesma categoria (Financeiro), mas pertence ao Administrador: deve ser
-- negado por ESCOPO DE OWNERSHIP (não por categoria, já que Financeiro tem
-- categoria_relatorio_exportavel('Financeiro','Financeiro') = true).
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_admin_financeiro')),
  'P0001',
  'PERMISSION_DENIED'
); -- Financeiro não pode baixar exportação Financeiro pertencente ao Administrador (fora de escopo por ownership)

SELECT reset_auth();

-- --- 7.3 Projetos enxerga/baixa apenas a própria exportação Projetos -------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Projetos'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.listar_exportacoes_relatorios()
    WHERE id::text = current_setting('test.t044_projetos_propria')
  ),
  'listar_exportacoes_relatorios: Projetos enxerga a própria exportação'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.listar_exportacoes_relatorios()
    WHERE id::text = current_setting('test.t044_admin_projetos')
  ),
  'listar_exportacoes_relatorios: Projetos NÃO enxerga exportação de mesma categoria pertencente ao Administrador'
);

SELECT lives_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_projetos_propria')),
  'autorizar_download_exportacao_relatorio: Projetos baixa a própria exportação (Projetos)'
);

-- Mesma categoria (Projetos), mas pertence ao Administrador: deve ser negado
-- por ESCOPO DE OWNERSHIP.
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t044_admin_projetos')),
  'P0001',
  'PERMISSION_DENIED'
); -- Projetos não pode baixar exportação Projetos pertencente ao Administrador (fora de escopo por ownership)

SELECT reset_auth();


-- ============================================================
-- 8. Negação de download por estado (T045)
-- ============================================================
-- Fonte: contracts/rpc-exportacao-relatorios.md
-- ("autorizar_download_exportacao_relatorio" Responsibilities: "Ensure
-- status = 'Pronto'", "Ensure expira_em >= now()") e data-model.md ("Status
-- Lifecycle": download deve ser bloqueado se status_exibicao != 'Pronto').
--
-- Cada fixture usa dono + categoria já autorizados para a persona que tenta o
-- download (Financeiro/Financeiro e Projetos/Projetos), isolando a negação
-- por ESTADO da negação por categoria/ownership (já cobertas nas seções 4 e
-- 7). Usa errmsg exato (3º arg de throws_ok) para confirmar qual motivo de
-- negação está sendo de fato levantado.

SELECT reset_auth();

SELECT set_config('test.t045_pendente', public.fixture_exportacao_pendente('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t045_falhou', public.fixture_exportacao_falhou('financeiro@aptusflow.local', 'Financeiro', 'Falha simulada T045')::text, false);
SELECT set_config('test.t045_expirada', public.fixture_exportacao_expirada('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t045_indisponivel', public.fixture_exportacao_indisponivel('projetos@aptusflow.local', 'Projetos')::text, false);

-- --- 8.1 Pendente: negado (dono + categoria corretos) -----------------------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t045_pendente')),
  'P0001',
  'EXPORT_NOT_READY'
); -- exportação Pendente não pode ser baixada (EXPORT_NOT_READY)

-- --- 8.2 Falhou: negado (dono + categoria corretos) -------------------------
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t045_falhou')),
  'P0001',
  'EXPORT_NOT_READY'
); -- exportação Falhou não pode ser baixada (EXPORT_NOT_READY)

-- --- 8.3 Expirada: negada com motivo distinto (dono + categoria corretos) --
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t045_expirada')),
  'P0001',
  'EXPORT_EXPIRED'
); -- exportação expirada não pode ser baixada (EXPORT_EXPIRED, não EXPORT_NOT_READY)

SELECT reset_auth();

-- --- 8.4 Legado Indisponível: negado (dono + categoria corretos p/ Projetos) -
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Projetos'));

SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t045_indisponivel')),
  'P0001',
  'EXPORT_NOT_READY'
); -- exportação legada Indisponível não pode ser baixada (EXPORT_NOT_READY)

SELECT reset_auth();

-- --- 8.5 As mesmas 4 exportações continuam visíveis no histórico do dono,
--         mas sem permitir download (pode_baixar = false) -------------------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT ok(
  coalesce((
    SELECT bool_and(NOT pode_baixar)
    FROM public.listar_exportacoes_relatorios()
    WHERE id::text IN (
      current_setting('test.t045_pendente'),
      current_setting('test.t045_falhou'),
      current_setting('test.t045_expirada')
    )
  ), false),
  'listar_exportacoes_relatorios: Pendente/Falhou/Expirada aparecem no histórico do Financeiro com pode_baixar = false'
);

SELECT is(
  (SELECT count(*)::int FROM public.listar_exportacoes_relatorios()
   WHERE id::text IN (
     current_setting('test.t045_pendente'),
     current_setting('test.t045_falhou'),
     current_setting('test.t045_expirada')
   )),
  3,
  'listar_exportacoes_relatorios: as 3 exportações Pendente/Falhou/Expirada continuam listadas (não somem do histórico)'
);

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Projetos'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.listar_exportacoes_relatorios()
    WHERE id::text = current_setting('test.t045_indisponivel')
      AND pode_baixar = false
  ),
  'listar_exportacoes_relatorios: exportação legada Indisponível continua listada para o Projetos com pode_baixar = false'
);

SELECT reset_auth();


-- ============================================================
-- 9. Ordenação e cálculo de status_exibicao/pode_baixar (T046)
-- ============================================================
-- Fonte: contracts/rpc-exportacao-relatorios.md ("Return newest records
-- first") e data-model.md ("Derived Read Model": status_exibicao incluindo
-- 'Expirado' computado; pode_baixar "computado por status, validade e
-- permissao atual").

SELECT reset_auth();

-- --- 9.1 Ordenação mais-recente-primeiro ------------------------------------
-- Cria 3 exportações do Financeiro em sequência (criado_em cresce a cada
-- INSERT) e confirma que a listagem retorna a mais recente primeiro.
SELECT set_config('test.t046_ord_1', public.fixture_exportacao_pronta('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT pg_sleep(0.01);
SELECT set_config('test.t046_ord_2', public.fixture_exportacao_pronta('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT pg_sleep(0.01);
SELECT set_config('test.t046_ord_3', public.fixture_exportacao_pronta('financeiro@aptusflow.local', 'Financeiro')::text, false);

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT is(
  (
    SELECT array_agg(id::text ORDER BY ordinality)
    FROM (
      SELECT id, row_number() OVER () AS ordinality
      FROM public.listar_exportacoes_relatorios()
      WHERE id::text IN (
        current_setting('test.t046_ord_1'),
        current_setting('test.t046_ord_2'),
        current_setting('test.t046_ord_3')
      )
    ) sub
  ),
  ARRAY[
    current_setting('test.t046_ord_3'),
    current_setting('test.t046_ord_2'),
    current_setting('test.t046_ord_1')
  ],
  'listar_exportacoes_relatorios: as 3 exportações de teste aparecem em ordem mais-recente-primeiro'
);

SELECT reset_auth();

-- --- 9.2 status_exibicao computa 'Expirado' para Pronto vencido, mas mantém
--         status='Pronto' persistido intacto -------------------------------
SELECT set_config('test.t046_expirada', public.fixture_exportacao_expirada('financeiro@aptusflow.local', 'Financeiro')::text, false);

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT results_eq(
  format($$SELECT status, status_exibicao FROM public.listar_exportacoes_relatorios() WHERE id = %L::uuid$$, current_setting('test.t046_expirada')),
  $$VALUES ('Pronto'::text, 'Expirado'::text)$$,
  'listar_exportacoes_relatorios: exportação Pronto com expira_em vencido mantém status=Pronto mas status_exibicao=Expirado'
);

SELECT is(
  (SELECT pode_baixar FROM public.listar_exportacoes_relatorios() WHERE id = current_setting('test.t046_expirada')::uuid),
  false,
  'listar_exportacoes_relatorios: exportação Expirada tem pode_baixar = false'
);

SELECT reset_auth();

-- --- 9.3 pode_baixar = true apenas para Pronto ainda válido, dentro do
--         escopo/categoria do usuário atual ---------------------------------
SELECT set_config('test.t046_pronta', public.fixture_exportacao_pronta('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t046_pendente', public.fixture_exportacao_pendente('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t046_falhou', public.fixture_exportacao_falhou('financeiro@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t046_indisponivel', public.fixture_exportacao_indisponivel('financeiro@aptusflow.local', 'Financeiro')::text, false);

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT results_eq(
  format(
    $$SELECT status_exibicao, pode_baixar FROM public.listar_exportacoes_relatorios() WHERE id = %L::uuid$$,
    current_setting('test.t046_pronta')
  ),
  $$VALUES ('Pronto'::text, true)$$,
  'listar_exportacoes_relatorios: exportação Pronto e válida tem status_exibicao=Pronto e pode_baixar=true'
);

SELECT results_eq(
  format(
    $$SELECT status_exibicao, pode_baixar FROM public.listar_exportacoes_relatorios() WHERE id = %L::uuid$$,
    current_setting('test.t046_pendente')
  ),
  $$VALUES ('Pendente'::text, false)$$,
  'listar_exportacoes_relatorios: exportação Pendente tem status_exibicao=Pendente e pode_baixar=false'
);

SELECT results_eq(
  format(
    $$SELECT status_exibicao, pode_baixar FROM public.listar_exportacoes_relatorios() WHERE id = %L::uuid$$,
    current_setting('test.t046_falhou')
  ),
  $$VALUES ('Falhou'::text, false)$$,
  'listar_exportacoes_relatorios: exportação Falhou tem status_exibicao=Falhou e pode_baixar=false'
);

SELECT results_eq(
  format(
    $$SELECT status_exibicao, pode_baixar FROM public.listar_exportacoes_relatorios() WHERE id = %L::uuid$$,
    current_setting('test.t046_indisponivel')
  ),
  $$VALUES ('Indisponível'::text, false)$$,
  'listar_exportacoes_relatorios: exportação legada Indisponível tem status_exibicao=Indisponível e pode_baixar=false'
);

SELECT reset_auth();


-- ============================================================
-- 10. US3 - Visualizador, Comercial e Tecnico: geração e download
--     negados para qualquer categoria (T059)
-- ============================================================
-- Fonte: spec.md User Story 3 ("Respeitar personas e leitura sem
-- exportação"), Acceptance Scenario 2 ("Comercial ou Tecnico sem
-- capacidade de exportar relatorios... bloqueia a ação e não gera
-- arquivo") e FR-015/FR-017 (Visualizador só lê; Comercial/Tecnico nunca
-- exportam). A negação de GERAÇÃO para estas 3 personas em formato PDF já
-- está coberta em detalhe na seção 4.2 (T024, todas as 4 categorias); esta
-- seção (T059) reexercita a mesma matriz de persona x categoria em
-- formato CSV (cobertura incremental de formato, não uma repetição literal
-- da asserção PDF já existente) e acrescenta a verificação de DOWNLOAD
-- (autorizar_download_exportacao_relatorio), que nenhuma seção anterior
-- testou para estas 3 personas — a seção 7 cobriu apenas escopo de
-- ownership para Administrador/Financeiro/Projetos.

-- --- 10.1 Geração (CSV) negada para as 4 categorias -------------------------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Visualizador'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode iniciar_exportacao_relatorio (CSV) para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode iniciar_exportacao_relatorio (CSV) para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode iniciar_exportacao_relatorio (CSV) para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode iniciar_exportacao_relatorio (CSV) para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Comercial'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode iniciar_exportacao_relatorio (CSV) para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode iniciar_exportacao_relatorio (CSV) para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode iniciar_exportacao_relatorio (CSV) para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode iniciar_exportacao_relatorio (CSV) para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Tecnico'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode iniciar_exportacao_relatorio (CSV) para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode iniciar_exportacao_relatorio (CSV) para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode iniciar_exportacao_relatorio (CSV) para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode iniciar_exportacao_relatorio (CSV) para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();

-- --- 10.2 Fixtures Pronto por categoria (dono: Administrador), usadas
--          apenas para testar a NEGAÇÃO de download por falta de
--          capacidade — o dono é irrelevante aqui porque
--          autorizar_download_exportacao_relatorio checa
--          tem_capacidade('relatorios.exportar') antes de checar categoria
--          ou ownership (mesma ordem de guard-rails de
--          iniciar_exportacao_relatorio), então Visualizador/Comercial/
--          Tecnico devem ser barrados independentemente de quem gerou o
--          arquivo ou de qual categoria é.
SELECT set_config('test.t059_admin_financeiro', public.fixture_exportacao_pronta('admin@aptusflow.local', 'Financeiro')::text, false);
SELECT set_config('test.t059_admin_dre', public.fixture_exportacao_pronta('admin@aptusflow.local', 'DRE')::text, false);
SELECT set_config('test.t059_admin_clientes', public.fixture_exportacao_pronta('admin@aptusflow.local', 'Clientes')::text, false);
SELECT set_config('test.t059_admin_projetos', public.fixture_exportacao_pronta('admin@aptusflow.local', 'Projetos')::text, false);

-- --- 10.3 Download negado para as 4 categorias (Visualizador) --------------
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Visualizador'));

SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_financeiro')),
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode autorizar_download_exportacao_relatorio para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_dre')),
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode autorizar_download_exportacao_relatorio para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_clientes')),
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode autorizar_download_exportacao_relatorio para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_projetos')),
  'P0001', 'PERMISSION_DENIED'
); -- Visualizador não pode autorizar_download_exportacao_relatorio para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Comercial'));

SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_financeiro')),
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode autorizar_download_exportacao_relatorio para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_dre')),
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode autorizar_download_exportacao_relatorio para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_clientes')),
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode autorizar_download_exportacao_relatorio para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_projetos')),
  'P0001', 'PERMISSION_DENIED'
); -- Comercial não pode autorizar_download_exportacao_relatorio para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Tecnico'));

SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_financeiro')),
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode autorizar_download_exportacao_relatorio para Financeiro (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_dre')),
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode autorizar_download_exportacao_relatorio para DRE (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_clientes')),
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode autorizar_download_exportacao_relatorio para Clientes (sem capacidade relatorios.exportar)
SELECT throws_ok(
  format('SELECT public.autorizar_download_exportacao_relatorio(%L::uuid)', current_setting('test.t059_admin_projetos')),
  'P0001', 'PERMISSION_DENIED'
); -- Tecnico não pode autorizar_download_exportacao_relatorio para Projetos (sem capacidade relatorios.exportar)

SELECT reset_auth();


-- ============================================================
-- 11. US3 - Financeiro negado em Projetos/Clientes; Projetos negado em
--     Financeiro/DRE/Clientes, via iniciar_exportacao_relatorio (T060)
-- ============================================================
-- Fonte: contracts/rpc-exportacao-relatorios.md ("Exportable Category
-- Policy") e Closed Checklist Decisions do plan.md ("Financeiro exporta
-- Financeiro e DRE; Projetos exporta Projetos"), refletido em
-- public.categoria_relatorio_exportavel (T009). A mesma matriz já é
-- validada em formato PDF na seção 4.2 (T024); esta seção (T060) cobre a
-- mesma matriz em formato CSV — cobertura incremental de formato em vez de
-- repetir literalmente as asserções PDF já existentes — sempre via
-- iniciar_exportacao_relatorio, como pedido explicitamente pela tarefa
-- T060.

SELECT set_auth_by_email(public.email_persona_teste_relatorios('Financeiro'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Projetos', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Financeiro não pode iniciar_exportacao_relatorio (CSV) para Projetos
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Financeiro não pode iniciar_exportacao_relatorio (CSV) para Clientes

SELECT reset_auth();
SELECT set_auth_by_email(public.email_persona_teste_relatorios('Projetos'));

SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Financeiro', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Projetos não pode iniciar_exportacao_relatorio (CSV) para Financeiro
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('DRE', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Projetos não pode iniciar_exportacao_relatorio (CSV) para DRE
SELECT throws_ok(
  $$SELECT public.iniciar_exportacao_relatorio('Clientes', 'CSV', '2026-01-01'::date, '2026-01-31'::date)$$,
  'P0001', 'PERMISSION_DENIED'
); -- Projetos não pode iniciar_exportacao_relatorio (CSV) para Clientes

SELECT reset_auth();

SELECT * FROM finish();
