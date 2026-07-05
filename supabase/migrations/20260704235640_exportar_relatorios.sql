-- Migration: 20260704235640_exportar_relatorios.sql
-- Feature 008 - Exportar Relatorios (Fase Foundational: T007-T017)
--
-- Fonte de verdade (nao inventar formato, seguir estes contratos):
--   specs/008-exportar-relatorios/data-model.md
--   specs/008-exportar-relatorios/contracts/rpc-exportacao-relatorios.md
--   specs/008-exportar-relatorios/contracts/storage-and-retention.md
--   specs/008-exportar-relatorios/contracts/edge-function-exportacao.md
--   specs/008-exportar-relatorios/plan.md / spec.md
--
-- Convencoes seguidas (ver supabase/migrations/20260703000002_rbac_capacidades_rpc_guards.sql
-- e supabase/migrations/20260703000001_rbac_capacidades_foundation.sql):
--   - RPCs de escrita/autorizacao: SECURITY DEFINER, SET search_path = public,
--     guarda `auth.uid() IS NULL -> Unauthorized (42501)`, checagem de
--     capacidade nomeada via public.tem_capacidade('relatorios.exportar'),
--     REVOKE EXECUTE FROM PUBLIC + GRANT EXECUTE TO authenticated explicitos.
--   - RPCs que precisam ler/gravar em varias tabelas (com RLS proprio por
--     modulo) usam `SET row_security = off`, mesmo padrao de
--     obter_permissoes_usuario/permissao_modulo/tem_capacidade.
--
-- Decisoes tomadas por ambiguidade dos contratos (documentadas tambem no
-- relatorio final da tarefa):
--   1. data_inicial/data_final sao adicionadas como colunas NULLABLE na
--      tabela (nao NOT NULL) para nao quebrar as linhas legadas
--      'Indisponivel' que nunca tiveram periodo. Toda nova linha inserida via
--      iniciar_exportacao_relatorio SEMPRE preenche as duas colunas, entao na
--      pratica sao not-null para todo o fluxo novo.
--   2. `resumo` e `detalhes` no payload de public.iniciar_exportacao_relatorio
--      sao ambos ARRAYS de objetos (`[{"label":..,"valor":..}, ...]` para
--      resumo; lista de linhas com colunas nomeadas para detalhes), pois o
--      contrato rpc-exportacao-relatorios.md mostra ambos como `[]` no
--      exemplo de retorno. Esse formato mapeia diretamente para
--      resumo.csv/detalhes.csv (contracts/storage-and-retention.md) sem a
--      Edge Function precisar de mapeamento por categoria.
--   3. `categoria_relatorio_exportavel` cobre apenas a autorizacao por
--      PERFIL x CATEGORIA. A validacao "tipo pertence ao conjunto
--      {Financeiro, DRE, Clientes, Projetos}" e feita separadamente em
--      iniciar_exportacao_relatorio/autorizar_download_exportacao_relatorio
--      retornando INVALID_CATEGORY (categoria inexistente/fora de escopo,
--      ex.: Personalizado) vs PERMISSION_DENIED (categoria valida mas nao
--      autorizada para o perfil atual).
--   4. public.lancamentos nao possui coluna projeto_id nesta base (apenas
--      cliente_id). O campo "projeto" nas linhas detalhadas de
--      Financeiro/DRE e sempre NULL — nao ha fonte de dado para vincular
--      lancamento a projeto no schema atual.
--   5. "Responsavel" de um projeto (CR-004) e derivado da primeira linha de
--      public.alocacoes_projeto (ordem de criacao) via public.perfis.nome,
--      pois projetos nao tem uma coluna own responsavel_id.
--   6. "Movimentacoes do periodo" (FR-006a) usa lancamentos.data_competencia
--      como data de referencia (data de competencia contabil).
--   7. concluir_exportacao_relatorio/falhar_exportacao_relatorio validam
--      "dono do processo" apenas por ownership (criado_por = auth.uid()),
--      pois a Edge Function (contracts/edge-function-exportacao.md) sempre
--      cria um client Supabase com o JWT do usuario para chamar as RPCs —
--      nao ha um caminho de "service role chamando em nome de outro
--      usuario" nesta arquitetura (sem fila/worker assincrono).
--   8. Observabilidade (T017) reutiliza public.audit_log (tabela de auditoria
--      ja existente no projeto), adicionando uma coluna jsonb `detalhes`
--      (a tabela original so tinha evento/usuario_id/ip_origem/user_agent,
--      sem espaco para tipo/formato/periodo/duracao/tamanho/erro) e 5 novos
--      valores de evento. Uma funcao dedicada
--      `registrar_evento_exportacao` grava esses eventos sem alterar a
--      assinatura de `registrar_evento_auditoria` (3 args) usada por outras
--      features de seguranca (login, etc).
--   9. `duracao_ms` em conclusao/falha e calculado como
--      now() - exportacoes_relatorios.criado_em, pois o contrato de RPC
--      (rpc-exportacao-relatorios.md) fixa a assinatura de
--      concluir_exportacao_relatorio/falhar_exportacao_relatorio sem um
--      parametro extra de duracao.
--  10. Visibilidade de listar_exportacoes_relatorios para
--      Visualizador/Comercial/Tecnico: retorna lista vazia (nenhum
--      historico), conforme a secao "Responsibilities" do contrato de RPC
--      ("no exportable history, unless product later defines read-only
--      audit view"), inclusive para linhas legadas 'Indisponivel'.
--  11. Correcoes de auditoria (T072, scripts/audit-rpc.mjs): (a)
--      categoria_relatorio_exportavel e validar_periodo_exportacao passam a
--      ser SECURITY DEFINER com guarda `auth.uid() IS NULL`, no mesmo padrao
--      dos demais helpers de autorizacao (permissao_modulo/tem_capacidade/
--      existe_perfil_admin) — sao classificados como HELPERS no audit script
--      (guards que nao precisam se autoguardar); (b) os 4 payload builders
--      montar_payload_relatorio_* ganham checagem explicita de
--      `tem_capacidade('relatorios.exportar')` logo apos o guard de
--      identidade: como sao SECURITY DEFINER + row_security off + GRANT
--      EXECUTE TO authenticated, sem essa checagem qualquer usuario
--      autenticado (mesmo sem a capacidade de exportar, ex.: Visualizador/
--      Comercial/Tecnico) poderia chamar a RPC diretamente e obter os dados
--      detalhados do relatorio, contornando a autorizacao feita em
--      iniciar_exportacao_relatorio. Classificados no audit script como
--      "capability-gated reads" (STABLE, mas via tem_capacidade em vez de
--      permissao_modulo, pois a regra de negocio e a capacidade nomeada
--      'relatorios.exportar', nao uma permissao de leitura do modulo
--      'relatorios'); (c) registrar_evento_exportacao e classificada como
--      HELPER (funcao de auditoria interna, mesma natureza de
--      registrar_evento_auditoria, mas sempre exige usuario autenticado —
--      por isso nao entra em AUDIT_EXCEPTIONS, que exige GRANT tambem para
--      anon); (d) concluir_exportacao_relatorio/falhar_exportacao_relatorio
--      sao classificadas como OWNERSHIP_GATED: a autorizacao delas e feita
--      por posse do registro (`criado_por = auth.uid()`, decisao #7 acima),
--      nao por capacidade nomeada — e apenas quem ja passou pela checagem de
--      tem_capacidade em iniciar_exportacao_relatorio pode ser dono de uma
--      linha 'Pendente', entao a checagem de ownership e suficiente aqui.


-- ============================================================
-- T007. Tabela public.exportacoes_relatorios: novas colunas e indices
-- ============================================================
-- Tabela ja existe (supabase/migrations/20260701000001_demais_telas_schema.sql).
-- arquivo_url permanece intocado (nullable, sem novo uso) por retrocompatibilidade.

ALTER TABLE public.exportacoes_relatorios
  ADD COLUMN IF NOT EXISTS data_inicial date,
  ADD COLUMN IF NOT EXISTS data_final date,
  ADD COLUMN IF NOT EXISTS arquivo_path text,
  ADD COLUMN IF NOT EXISTS arquivo_nome text,
  ADD COLUMN IF NOT EXISTS mime_type text,
  ADD COLUMN IF NOT EXISTS tamanho_bytes bigint,
  ADD COLUMN IF NOT EXISTS hash_sha256 text,
  ADD COLUMN IF NOT EXISTS expira_em timestamp with time zone,
  ADD COLUMN IF NOT EXISTS erro text,
  ADD COLUMN IF NOT EXISTS criado_em timestamp with time zone NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS atualizado_em timestamp with time zone NOT NULL DEFAULT now();

-- Guard-rails minimos de dados (nao quebram linhas legadas, pois toleram NULL)
ALTER TABLE public.exportacoes_relatorios DROP CONSTRAINT IF EXISTS exportacoes_relatorios_periodo_check;
ALTER TABLE public.exportacoes_relatorios ADD CONSTRAINT exportacoes_relatorios_periodo_check
  CHECK (data_inicial IS NULL OR data_final IS NULL OR data_final >= data_inicial);

ALTER TABLE public.exportacoes_relatorios DROP CONSTRAINT IF EXISTS exportacoes_relatorios_mime_type_check;
ALTER TABLE public.exportacoes_relatorios ADD CONSTRAINT exportacoes_relatorios_mime_type_check
  CHECK (mime_type IS NULL OR mime_type IN ('application/pdf', 'application/zip'));

-- Indices recomendados em data-model.md ("Indexes")
CREATE INDEX IF NOT EXISTS idx_exportacoes_relatorios_criado_por_gerado_em
  ON public.exportacoes_relatorios (criado_por, gerado_em DESC NULLS LAST, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_exportacoes_relatorios_tipo_gerado_em
  ON public.exportacoes_relatorios (tipo, gerado_em DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_exportacoes_relatorios_status
  ON public.exportacoes_relatorios (status);
CREATE INDEX IF NOT EXISTS idx_exportacoes_relatorios_expira_em
  ON public.exportacoes_relatorios (expira_em);


-- ============================================================
-- T008. Bucket privado de Storage + politicas
-- ============================================================
-- contracts/storage-and-retention.md: bucket privado, sem leitura publica,
-- objetos acessados apenas via signed URL de curta duracao gerada pela
-- Edge Function apos autorizacao por RPC.

INSERT INTO storage.buckets (id, name, public)
VALUES ('relatorios-exportados', 'relatorios-exportados', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Nao existe (e nao deve existir) nenhuma politica de SELECT/INSERT/UPDATE/DELETE
-- para o papel `anon` neste bucket: RLS de storage.objects nega por padrao
-- qualquer acesso sem uma politica permissiva correspondente, o que ja
-- cumpre "negar leitura publica/anonima".

-- Leitura autenticada apenas quando: capacidade relatorios.exportar ativa,
-- categoria ainda exportavel para o perfil atual e (Administrador OU dono do
-- registro). Serve como defesa em profundidade; o fluxo principal usa signed
-- URLs geradas pela Edge Function com service role (que ignora RLS).
DROP POLICY IF EXISTS relatorios_exportados_select_owner_or_admin ON storage.objects;
CREATE POLICY relatorios_exportados_select_owner_or_admin ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'relatorios-exportados'
    AND public.tem_capacidade('relatorios.exportar')
    AND EXISTS (
      SELECT 1
      FROM public.exportacoes_relatorios er
      WHERE er.arquivo_path = storage.objects.name
        AND (
          public.existe_perfil_admin(auth.uid())
          OR er.criado_por = auth.uid()
        )
    )
  );

-- Nenhuma politica de INSERT/UPDATE/DELETE e concedida a `authenticated` ou
-- `anon`: apenas a Edge Function (via service role, que ignora RLS) grava
-- objetos neste bucket, conforme contracts/storage-and-retention.md
-- ("Upload is performed by Edge Function after RPC authorization").


-- ============================================================
-- T009. Helper de categoria exportavel por persona
-- ============================================================
-- Fonte: contracts/rpc-exportacao-relatorios.md e data-model.md
-- ("Entity: Exportable Category Policy").

CREATE OR REPLACE FUNCTION public.categoria_relatorio_exportavel(
  p_tipo text,
  p_perfil text
)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  RETURN CASE p_perfil
    WHEN 'Administrador' THEN p_tipo IN ('Financeiro', 'DRE', 'Clientes', 'Projetos')
    WHEN 'Financeiro' THEN p_tipo IN ('Financeiro', 'DRE')
    WHEN 'Projetos' THEN p_tipo = 'Projetos'
    ELSE false
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.categoria_relatorio_exportavel(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.categoria_relatorio_exportavel(text, text) TO authenticated;


-- ============================================================
-- T010. Helper de validacao de periodo (datas inclusivas, maximo 12 meses)
-- ============================================================
-- Regra exata (data-model.md "Entity: Export Period" / spec.md):
--   data_inicial <= data_final; 2026-01-01..2026-12-31 permitido;
--   2026-01-01..2027-01-01 bloqueado.

CREATE OR REPLACE FUNCTION public.validar_periodo_exportacao(
  p_data_inicial date,
  p_data_final date
)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF p_data_inicial IS NULL OR p_data_final IS NULL THEN
    RAISE EXCEPTION 'INVALID_PERIOD' USING DETAIL = 'Data inicial e data final são obrigatórias.';
  END IF;

  IF p_data_final < p_data_inicial THEN
    RAISE EXCEPTION 'INVALID_PERIOD' USING DETAIL = 'Data final deve ser maior ou igual à data inicial.';
  END IF;

  -- Periodo maximo inclusivo de 12 meses corridos a partir da data inicial.
  IF p_data_final > ((p_data_inicial + interval '12 months') - interval '1 day')::date THEN
    RAISE EXCEPTION 'PERIOD_TOO_LONG' USING DETAIL = 'Período máximo permitido é de 12 meses.';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.validar_periodo_exportacao(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validar_periodo_exportacao(date, date) TO authenticated;


-- ============================================================
-- T011. Payload builders completos por categoria
-- ============================================================
-- Cada builder retorna jsonb no formato:
--   { "resumo": [{"label":..,"valor":..}, ...], "detalhes": [ {..linha..}, ... ], "mensagem_sem_dados": text|null }
-- SECURITY DEFINER + row_security off: builders leem lancamentos/clientes/
-- projetos/tarefas/atendimentos/apontamentos_horas/alocacoes_projeto
-- independente das politicas RLS por modulo do usuario autenticado (o
-- controle de autorizacao de QUEM pode exportar QUAL categoria ja acontece
-- antes, em iniciar_exportacao_relatorio via categoria_relatorio_exportavel).

-- 1. Financeiro (CR-001)
CREATE OR REPLACE FUNCTION public.montar_payload_relatorio_financeiro(
  p_data_inicial date,
  p_data_final date
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_receitas numeric(14,2);
  v_despesas numeric(14,2);
  v_qtd integer;
  v_detalhes jsonb;
  v_mensagem text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem permissão para exportar relatórios.';
  END IF;

  SELECT
    coalesce(sum(valor) FILTER (WHERE tipo = 'receita'), 0.00),
    coalesce(sum(valor) FILTER (WHERE tipo = 'despesa'), 0.00),
    count(*)
  INTO v_receitas, v_despesas, v_qtd
  FROM public.lancamentos
  WHERE data_competencia BETWEEN p_data_inicial AND p_data_final;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'data', l.data_competencia,
      'tipo', l.tipo,
      'natureza', l.natureza,
      'status', l.status,
      'categoria', l.categoria,
      'descricao', l.descricao,
      'cliente', c.empresa,
      'projeto', NULL,
      'valor', l.valor
    ) ORDER BY l.data_competencia, l.id
  ), '[]'::jsonb)
  INTO v_detalhes
  FROM public.lancamentos l
  LEFT JOIN public.clientes c ON c.id = l.cliente_id
  WHERE l.data_competencia BETWEEN p_data_inicial AND p_data_final;

  IF v_qtd = 0 THEN
    v_mensagem := 'Nenhum lançamento financeiro encontrado no período informado.';
  ELSE
    v_mensagem := NULL;
  END IF;

  RETURN jsonb_build_object(
    'resumo', jsonb_build_array(
      jsonb_build_object('label', 'Receitas', 'valor', v_receitas),
      jsonb_build_object('label', 'Despesas', 'valor', v_despesas),
      jsonb_build_object('label', 'Saldo', 'valor', v_receitas - v_despesas),
      jsonb_build_object('label', 'Quantidade de lançamentos', 'valor', v_qtd)
    ),
    'detalhes', v_detalhes,
    'mensagem_sem_dados', v_mensagem
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_financeiro(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_financeiro(date, date) TO authenticated;


-- 2. DRE (CR-002)
CREATE OR REPLACE FUNCTION public.montar_payload_relatorio_dre(
  p_data_inicial date,
  p_data_final date
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_faturamento numeric(14,2);
  v_custos numeric(14,2);
  v_deducoes numeric(14,2) := 0.00; -- sem fonte de deducoes distinta no schema atual (mesma convencao de gerar_previa_relatorio)
  v_resultado numeric(14,2);
  v_qtd integer;
  v_detalhes jsonb;
  v_mensagem text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem permissão para exportar relatórios.';
  END IF;

  SELECT
    coalesce(sum(valor) FILTER (WHERE tipo = 'receita'), 0.00),
    coalesce(sum(valor) FILTER (WHERE tipo = 'despesa' AND categoria = 'Operacional'), 0.00),
    coalesce(sum(CASE WHEN tipo = 'receita' THEN valor ELSE -valor END), 0.00),
    count(*)
  INTO v_faturamento, v_custos, v_resultado, v_qtd
  FROM public.lancamentos
  WHERE data_competencia BETWEEN p_data_inicial AND p_data_final;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'data', l.data_competencia,
      'grupo_dre', CASE
        WHEN l.tipo = 'receita' THEN 'Receita Bruta'
        WHEN l.tipo = 'despesa' AND l.categoria = 'Operacional' THEN 'Custos Operacionais'
        ELSE 'Outras Despesas'
      END,
      'categoria', l.categoria,
      'descricao', l.descricao,
      'valor', l.valor
    ) ORDER BY l.data_competencia, l.id
  ), '[]'::jsonb)
  INTO v_detalhes
  FROM public.lancamentos l
  WHERE l.data_competencia BETWEEN p_data_inicial AND p_data_final;

  IF v_qtd = 0 THEN
    v_mensagem := 'Nenhum lançamento encontrado no período informado para compor a DRE.';
  ELSE
    v_mensagem := NULL;
  END IF;

  RETURN jsonb_build_object(
    'resumo', jsonb_build_array(
      jsonb_build_object('label', 'Faturamento bruto', 'valor', v_faturamento),
      jsonb_build_object('label', 'Deduções', 'valor', v_deducoes),
      jsonb_build_object('label', 'Custos operacionais', 'valor', v_custos),
      jsonb_build_object('label', 'Resultado líquido', 'valor', v_resultado - v_deducoes)
    ),
    'detalhes', v_detalhes,
    'mensagem_sem_dados', v_mensagem
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_dre(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_dre(date, date) TO authenticated;


-- 3. Clientes (CR-003) - snapshot atual + metricas de atividade no periodo
CREATE OR REPLACE FUNCTION public.montar_payload_relatorio_clientes(
  p_data_inicial date,
  p_data_final date
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_total integer;
  v_ativos integer;
  v_inativos integer;
  v_novos integer;
  v_atendimentos integer;
  v_detalhes jsonb;
  v_mensagem text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem permissão para exportar relatórios.';
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'Ativo'),
    count(*) FILTER (WHERE status = 'Inativo'),
    count(*) FILTER (WHERE created_at::date BETWEEN p_data_inicial AND p_data_final)
  INTO v_total, v_ativos, v_inativos, v_novos
  FROM public.clientes;

  SELECT count(*) INTO v_atendimentos
  FROM public.atendimentos
  WHERE data BETWEEN p_data_inicial AND p_data_final;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'nome_contato', c.nome_contato,
      'empresa', c.empresa,
      'email', c.email,
      'telefone', c.telefone,
      'tipo', c.tipo,
      'status', c.status,
      'criado_em', c.created_at,
      'atualizado_em', c.updated_at,
      'atendimentos_no_periodo', coalesce(ap.qtd, 0)
    ) ORDER BY c.empresa, c.nome_contato
  ), '[]'::jsonb)
  INTO v_detalhes
  FROM public.clientes c
  LEFT JOIN (
    SELECT cliente_id, count(*) AS qtd
    FROM public.atendimentos
    WHERE data BETWEEN p_data_inicial AND p_data_final
    GROUP BY cliente_id
  ) ap ON ap.cliente_id = c.id;

  IF v_total = 0 THEN
    v_mensagem := 'Nenhum cliente cadastrado.';
  ELSE
    v_mensagem := NULL;
  END IF;

  RETURN jsonb_build_object(
    'resumo', jsonb_build_array(
      jsonb_build_object('label', 'Total de clientes', 'valor', v_total),
      jsonb_build_object('label', 'Ativos', 'valor', v_ativos),
      jsonb_build_object('label', 'Inativos', 'valor', v_inativos),
      jsonb_build_object('label', 'Novos no período', 'valor', v_novos),
      jsonb_build_object('label', 'Atendimentos no período', 'valor', v_atendimentos)
    ),
    'detalhes', v_detalhes,
    'mensagem_sem_dados', v_mensagem
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_clientes(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_clientes(date, date) TO authenticated;


-- 4. Projetos (CR-004) - snapshot atual + metricas de atividade no periodo
CREATE OR REPLACE FUNCTION public.montar_payload_relatorio_projetos(
  p_data_inicial date,
  p_data_final date
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_total integer;
  v_planejamento integer;
  v_andamento integer;
  v_concluido integer;
  v_horas numeric(12,2);
  v_tarefas_concluidas integer;
  v_detalhes jsonb;
  v_mensagem text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem permissão para exportar relatórios.';
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'Planejamento'),
    count(*) FILTER (WHERE status = 'Em andamento'),
    count(*) FILTER (WHERE status = 'Concluído')
  INTO v_total, v_planejamento, v_andamento, v_concluido
  FROM public.projetos;

  SELECT coalesce(sum(horas), 0.00) INTO v_horas
  FROM public.apontamentos_horas
  WHERE data BETWEEN p_data_inicial AND p_data_final;

  SELECT count(*) INTO v_tarefas_concluidas
  FROM public.tarefas
  WHERE situacao = 'Concluído'
    AND updated_at::date BETWEEN p_data_inicial AND p_data_final;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'nome', p.nome,
      'cliente', c.empresa,
      'status', p.status,
      'prazo', p.prazo,
      'responsavel', resp.nome,
      'progresso', p.progresso,
      'orcamento', p.orcamento,
      'orcamento_utilizado', p.orcamento_utilizado,
      'horas_apontadas_no_periodo', coalesce(ah.horas, 0),
      'tarefas_concluidas_no_periodo', coalesce(tc.qtd, 0)
    ) ORDER BY p.nome
  ), '[]'::jsonb)
  INTO v_detalhes
  FROM public.projetos p
  LEFT JOIN public.clientes c ON c.id = p.cliente_id
  LEFT JOIN LATERAL (
    SELECT pf.nome
    FROM public.alocacoes_projeto alp
    JOIN public.perfis pf ON pf.usuario_id = alp.usuario_id
    WHERE alp.projeto_id = p.id
    ORDER BY alp.created_at ASC
    LIMIT 1
  ) resp ON true
  LEFT JOIN (
    SELECT projeto_id, sum(horas) AS horas
    FROM public.apontamentos_horas
    WHERE data BETWEEN p_data_inicial AND p_data_final
    GROUP BY projeto_id
  ) ah ON ah.projeto_id = p.id
  LEFT JOIN (
    SELECT projeto_id, count(*) AS qtd
    FROM public.tarefas
    WHERE situacao = 'Concluído' AND updated_at::date BETWEEN p_data_inicial AND p_data_final
    GROUP BY projeto_id
  ) tc ON tc.projeto_id = p.id;

  IF v_total = 0 THEN
    v_mensagem := 'Nenhum projeto cadastrado.';
  ELSE
    v_mensagem := NULL;
  END IF;

  RETURN jsonb_build_object(
    'resumo', jsonb_build_array(
      jsonb_build_object('label', 'Total de projetos', 'valor', v_total),
      jsonb_build_object('label', 'Planejamento', 'valor', v_planejamento),
      jsonb_build_object('label', 'Em andamento', 'valor', v_andamento),
      jsonb_build_object('label', 'Concluído', 'valor', v_concluido),
      jsonb_build_object('label', 'Horas apontadas no período', 'valor', v_horas),
      jsonb_build_object('label', 'Tarefas concluídas no período', 'valor', v_tarefas_concluidas)
    ),
    'detalhes', v_detalhes,
    'mensagem_sem_dados', v_mensagem
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_projetos(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_projetos(date, date) TO authenticated;


-- ============================================================
-- T017 (parte 1). Extensao da auditoria existente para eventos de exportacao
-- ============================================================
-- Reaproveita public.audit_log (supabase/migrations/00000000000000_usuarios_perfis.sql)
-- em vez de criar uma tabela nova. A tabela original nao tem espaco para
-- dados estruturados (tipo/formato/periodo/duracao/tamanho/erro), entao
-- adicionamos uma coluna jsonb dedicada.

ALTER TABLE public.audit_log ADD COLUMN IF NOT EXISTS detalhes jsonb;

ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_evento_check;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_evento_check CHECK (evento IN (
  'login_sucesso', 'login_falha', 'senha_alterada', 'usuario_criado', 'conta_desativada', 'conta_ativada',
  'projeto_excluido', 'tarefa_excluida', 'cliente_inativado',
  'proposta_excluida', 'contrato_encerrado', 'cobranca_cancelada', 'membro_equipe_inativado',
  'perfil_acesso_alterado', 'parametro_financeiro_alterado', 'configuracao_global_alterada',
  'exportacao_relatorio_iniciada', 'exportacao_relatorio_concluida', 'exportacao_relatorio_falhou',
  'exportacao_download_autorizado', 'exportacao_download_negado'
));

-- Nao reaproveita a assinatura de public.registrar_evento_auditoria(text, text, text)
-- (usada por eventos de seguranca/sessao) para nao alterar seu contrato.
-- Funcao dedicada para eventos de observabilidade de exportacao
-- (data-model.md "Observability Model" / spec.md FR-028 / NFR-003).
CREATE OR REPLACE FUNCTION public.registrar_evento_exportacao(
  p_evento text,
  p_exportacao_id uuid,
  p_tipo text,
  p_formato text,
  p_data_inicial date,
  p_data_final date,
  p_status text,
  p_duracao_ms integer DEFAULT NULL,
  p_tamanho_bytes bigint DEFAULT NULL,
  p_erro text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.audit_log (evento, usuario_id, ip_origem, user_agent, detalhes)
  VALUES (
    p_evento,
    auth.uid(),
    '0.0.0.0',
    'System (relatorios-exportacao)',
    jsonb_build_object(
      'exportacao_id', p_exportacao_id,
      'tipo', p_tipo,
      'formato', p_formato,
      'data_inicial', p_data_inicial,
      'data_final', p_data_final,
      'status', p_status,
      'duracao_ms', p_duracao_ms,
      'tamanho_bytes', p_tamanho_bytes,
      'erro', p_erro
    )
  )
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text) TO authenticated;


-- ============================================================
-- T012. RPC iniciar_exportacao_relatorio
-- ============================================================

CREATE OR REPLACE FUNCTION public.iniciar_exportacao_relatorio(
  p_tipo text,
  p_formato text,
  p_data_inicial date,
  p_data_final date
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_perfil_acesso text;
  v_status_perfil text;
  v_nome_solicitante text;
  v_exportacao_id uuid;
  v_payload jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem permissão para exportar relatórios.';
  END IF;

  SELECT perfil_acesso, status, nome INTO v_perfil_acesso, v_status_perfil, v_nome_solicitante
  FROM public.perfis WHERE usuario_id = auth.uid();

  IF v_perfil_acesso IS NULL OR v_status_perfil <> 'Ativo' THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem perfil ativo.';
  END IF;

  IF p_tipo NOT IN ('Financeiro', 'DRE', 'Clientes', 'Projetos') THEN
    RAISE EXCEPTION 'INVALID_CATEGORY' USING DETAIL = 'Categoria de relatório inválida ou fora do escopo de exportação atual.';
  END IF;

  IF NOT public.categoria_relatorio_exportavel(p_tipo, v_perfil_acesso) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Perfil sem permissão para exportar esta categoria.';
  END IF;

  IF p_formato NOT IN ('PDF', 'CSV') THEN
    RAISE EXCEPTION 'INVALID_FORMAT' USING DETAIL = 'Formato de exportação inválido.';
  END IF;

  PERFORM public.validar_periodo_exportacao(p_data_inicial, p_data_final);

  INSERT INTO public.exportacoes_relatorios (
    tipo, formato, status, criado_por, data_inicial, data_final, criado_em, atualizado_em
  ) VALUES (
    p_tipo, p_formato, 'Pendente', auth.uid(), p_data_inicial, p_data_final, now(), now()
  )
  RETURNING id INTO v_exportacao_id;

  v_payload := CASE p_tipo
    WHEN 'Financeiro' THEN public.montar_payload_relatorio_financeiro(p_data_inicial, p_data_final)
    WHEN 'DRE' THEN public.montar_payload_relatorio_dre(p_data_inicial, p_data_final)
    WHEN 'Clientes' THEN public.montar_payload_relatorio_clientes(p_data_inicial, p_data_final)
    WHEN 'Projetos' THEN public.montar_payload_relatorio_projetos(p_data_inicial, p_data_final)
  END;

  PERFORM public.registrar_evento_exportacao(
    'exportacao_relatorio_iniciada', v_exportacao_id, p_tipo, p_formato,
    p_data_inicial, p_data_final, 'Pendente', NULL, NULL, NULL
  );

  RETURN jsonb_build_object(
    'exportacao_id', v_exportacao_id,
    'tipo', p_tipo,
    'formato', p_formato,
    'periodo', jsonb_build_object('data_inicial', p_data_inicial, 'data_final', p_data_final),
    'solicitante', jsonb_build_object('id', auth.uid(), 'nome', v_nome_solicitante),
    'resumo', v_payload->'resumo',
    'detalhes', v_payload->'detalhes',
    'mensagem_sem_dados', v_payload->>'mensagem_sem_dados'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.iniciar_exportacao_relatorio(text, text, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.iniciar_exportacao_relatorio(text, text, date, date) TO authenticated;


-- ============================================================
-- T013. RPCs concluir_exportacao_relatorio e falhar_exportacao_relatorio
-- ============================================================

CREATE OR REPLACE FUNCTION public.concluir_exportacao_relatorio(
  p_exportacao_id uuid,
  p_arquivo_path text,
  p_arquivo_nome text,
  p_mime_type text,
  p_tamanho_bytes bigint,
  p_hash_sha256 text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_criado_por uuid;
  v_status text;
  v_tipo text;
  v_formato text;
  v_data_inicial date;
  v_data_final date;
  v_criado_em timestamp with time zone;
  v_expira_em timestamp with time zone;
  v_duracao_ms integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT criado_por, status, tipo, formato, data_inicial, data_final, criado_em
  INTO v_criado_por, v_status, v_tipo, v_formato, v_data_inicial, v_data_final, v_criado_em
  FROM public.exportacoes_relatorios
  WHERE id = p_exportacao_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXPORT_NOT_FOUND' USING DETAIL = 'Exportação não encontrada.';
  END IF;

  -- Ownership: quem conclui deve ser o mesmo usuario dono da solicitacao
  -- (a Edge Function sempre chama esta RPC com o JWT do usuario que pediu
  -- a exportacao; nao ha caminho de service role atuando por outro usuario).
  IF v_criado_por IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF v_status <> 'Pendente' THEN
    RAISE EXCEPTION 'invalid_state' USING DETAIL = 'Exportação não está pendente de conclusão.';
  END IF;

  IF p_mime_type NOT IN ('application/pdf', 'application/zip') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Tipo de arquivo inválido.';
  END IF;

  IF p_tamanho_bytes IS NULL OR p_tamanho_bytes <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Tamanho de arquivo inválido.';
  END IF;

  v_expira_em := now() + interval '12 months';
  v_duracao_ms := GREATEST(0, extract(epoch FROM (now() - v_criado_em)) * 1000)::integer;

  UPDATE public.exportacoes_relatorios SET
    status = 'Pronto',
    arquivo_path = p_arquivo_path,
    arquivo_nome = p_arquivo_nome,
    mime_type = p_mime_type,
    tamanho_bytes = p_tamanho_bytes,
    hash_sha256 = p_hash_sha256,
    gerado_em = now(),
    expira_em = v_expira_em,
    erro = NULL,
    atualizado_em = now()
  WHERE id = p_exportacao_id;

  PERFORM public.registrar_evento_exportacao(
    'exportacao_relatorio_concluida', p_exportacao_id, v_tipo, v_formato,
    v_data_inicial, v_data_final, 'Pronto', v_duracao_ms, p_tamanho_bytes, NULL
  );

  RETURN jsonb_build_object(
    'id', p_exportacao_id,
    'status', 'Pronto',
    'gerado_em', now(),
    'expira_em', v_expira_em
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.falhar_exportacao_relatorio(
  p_exportacao_id uuid,
  p_erro text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_criado_por uuid;
  v_status text;
  v_tipo text;
  v_formato text;
  v_data_inicial date;
  v_data_final date;
  v_criado_em timestamp with time zone;
  v_erro_sanitizado text;
  v_duracao_ms integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT criado_por, status, tipo, formato, data_inicial, data_final, criado_em
  INTO v_criado_por, v_status, v_tipo, v_formato, v_data_inicial, v_data_final, v_criado_em
  FROM public.exportacoes_relatorios
  WHERE id = p_exportacao_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXPORT_NOT_FOUND' USING DETAIL = 'Exportação não encontrada.';
  END IF;

  IF v_criado_por IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF v_status <> 'Pendente' THEN
    RAISE EXCEPTION 'invalid_state' USING DETAIL = 'Exportação não está pendente de conclusão.';
  END IF;

  -- Sanitiza a mensagem de erro (evita persistir stack trace completo no historico)
  v_erro_sanitizado := left(coalesce(p_erro, 'Erro desconhecido durante a geração do relatório.'), 500);
  v_duracao_ms := GREATEST(0, extract(epoch FROM (now() - v_criado_em)) * 1000)::integer;

  UPDATE public.exportacoes_relatorios SET
    status = 'Falhou',
    erro = v_erro_sanitizado,
    atualizado_em = now()
  WHERE id = p_exportacao_id;

  PERFORM public.registrar_evento_exportacao(
    'exportacao_relatorio_falhou', p_exportacao_id, v_tipo, v_formato,
    v_data_inicial, v_data_final, 'Falhou', v_duracao_ms, NULL, v_erro_sanitizado
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.falhar_exportacao_relatorio(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.falhar_exportacao_relatorio(uuid, text) TO authenticated;


-- ============================================================
-- T014. RPC autorizar_download_exportacao_relatorio
-- ============================================================

CREATE OR REPLACE FUNCTION public.autorizar_download_exportacao_relatorio(
  p_exportacao_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_perfil_acesso text;
  v_status_perfil text;
  v_criado_por uuid;
  v_status text;
  v_tipo text;
  v_formato text;
  v_data_inicial date;
  v_data_final date;
  v_arquivo_path text;
  v_arquivo_nome text;
  v_mime_type text;
  v_expira_em timestamp with time zone;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('relatorios.exportar') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem permissão para baixar exportações de relatórios.';
  END IF;

  SELECT perfil_acesso, status INTO v_perfil_acesso, v_status_perfil
  FROM public.perfis WHERE usuario_id = auth.uid();

  IF v_perfil_acesso IS NULL OR v_status_perfil <> 'Ativo' THEN
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem perfil ativo.';
  END IF;

  SELECT criado_por, status, tipo, formato, data_inicial, data_final,
         arquivo_path, arquivo_nome, mime_type, expira_em
  INTO v_criado_por, v_status, v_tipo, v_formato, v_data_inicial, v_data_final,
       v_arquivo_path, v_arquivo_nome, v_mime_type, v_expira_em
  FROM public.exportacoes_relatorios
  WHERE id = p_exportacao_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXPORT_NOT_FOUND' USING DETAIL = 'Exportação não encontrada.';
  END IF;

  IF NOT public.categoria_relatorio_exportavel(v_tipo, v_perfil_acesso) THEN
    PERFORM public.registrar_evento_exportacao(
      'exportacao_download_negado', p_exportacao_id, v_tipo, v_formato,
      v_data_inicial, v_data_final, v_status, NULL, NULL, 'Categoria não exportável para o perfil atual.'
    );
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Perfil sem permissão para esta categoria.';
  END IF;

  -- Escopo de historico (data-model.md / rpc-exportacao-relatorios.md):
  -- Administrador ve/baixa tudo; Financeiro e Projetos apenas o proprio;
  -- demais perfis sao sempre negados.
  IF NOT (
    v_perfil_acesso = 'Administrador'
    OR (v_perfil_acesso IN ('Financeiro', 'Projetos') AND v_criado_por = auth.uid())
  ) THEN
    PERFORM public.registrar_evento_exportacao(
      'exportacao_download_negado', p_exportacao_id, v_tipo, v_formato,
      v_data_inicial, v_data_final, v_status, NULL, NULL, 'Usuário sem acesso a esta exportação.'
    );
    RAISE EXCEPTION 'PERMISSION_DENIED' USING DETAIL = 'Usuário sem acesso a esta exportação.';
  END IF;

  IF v_status <> 'Pronto' THEN
    PERFORM public.registrar_evento_exportacao(
      'exportacao_download_negado', p_exportacao_id, v_tipo, v_formato,
      v_data_inicial, v_data_final, v_status, NULL, NULL, 'Exportação não está pronta para download.'
    );
    RAISE EXCEPTION 'EXPORT_NOT_READY' USING DETAIL = 'Exportação não está pronta para download.';
  END IF;

  IF v_expira_em IS NULL OR v_expira_em < now() THEN
    PERFORM public.registrar_evento_exportacao(
      'exportacao_download_negado', p_exportacao_id, v_tipo, v_formato,
      v_data_inicial, v_data_final, v_status, NULL, NULL, 'Exportação expirada.'
    );
    RAISE EXCEPTION 'EXPORT_EXPIRED' USING DETAIL = 'Exportação expirada.';
  END IF;

  PERFORM public.registrar_evento_exportacao(
    'exportacao_download_autorizado', p_exportacao_id, v_tipo, v_formato,
    v_data_inicial, v_data_final, v_status, NULL, NULL, NULL
  );

  RETURN jsonb_build_object(
    'id', p_exportacao_id,
    'arquivo_path', v_arquivo_path,
    'arquivo_nome', v_arquivo_nome,
    'mime_type', v_mime_type,
    'expira_em', v_expira_em
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.autorizar_download_exportacao_relatorio(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.autorizar_download_exportacao_relatorio(uuid) TO authenticated;


-- ============================================================
-- T015. RPC listar_exportacoes_relatorios (contrato expandido)
-- ============================================================
-- Precisa de DROP porque a assinatura de retorno muda (Postgres nao permite
-- CREATE OR REPLACE alterar as colunas de saida de uma funcao TABLE).

DROP FUNCTION IF EXISTS public.listar_exportacoes_relatorios(text);

CREATE FUNCTION public.listar_exportacoes_relatorios(p_tipo text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  tipo text,
  formato text,
  formato_entrega text,
  status text,
  status_exibicao text,
  data_inicial date,
  data_final date,
  arquivo_nome text,
  mime_type text,
  tamanho_bytes bigint,
  criado_por uuid,
  criado_por_nome text,
  gerado_em timestamp with time zone,
  expira_em timestamp with time zone,
  pode_baixar boolean,
  erro text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_perfil_acesso text;
  v_status_perfil text;
  v_tem_capacidade boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  -- Sem leitura no modulo Relatorios (ex.: Comercial/Tecnico, que nao tem
  -- pode_ler em 'relatorios'): retorna lista vazia em vez de lancar excecao,
  -- pelo mesmo motivo/convencao de public.listar_categorias_relatorios (RPC
  -- irma de leitura/preview) e pela decisao #10 documentada no topo deste
  -- arquivo ("Visualizador/Comercial/Tecnico: retorna lista vazia, nenhum
  -- historico"). Antes desta correcao, Comercial/Tecnico recebiam uma
  -- excecao 'permission_denied' aqui (checada ANTES do corte por perfil mais
  -- abaixo, que so lida corretamente com Visualizador), inconsistente com o
  -- contrato (rpc-exportacao-relatorios.md: "Visualizador/Comercial/Tecnico:
  -- no exportable history") e com o comportamento gracioso do irmao
  -- listar_categorias_relatorios.
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true
  ) THEN
    RETURN;
  END IF;

  SELECT p.perfil_acesso, p.status INTO v_perfil_acesso, v_status_perfil
  FROM public.perfis p WHERE p.usuario_id = auth.uid();

  IF v_status_perfil IS DISTINCT FROM 'Ativo' OR v_perfil_acesso IS NULL THEN
    RETURN;
  END IF;

  -- Visualizador, Comercial e Tecnico nao possuem historico de exportacao
  -- no escopo 008 (nunca exportam nem baixam nada).
  IF v_perfil_acesso NOT IN ('Administrador', 'Financeiro', 'Projetos') THEN
    RETURN;
  END IF;

  v_tem_capacidade := public.tem_capacidade('relatorios.exportar');

  RETURN QUERY
  SELECT
    er.id,
    er.tipo,
    er.formato,
    CASE er.formato WHEN 'CSV' THEN 'ZIP_CSV' ELSE er.formato END AS formato_entrega,
    er.status,
    CASE
      WHEN er.status = 'Pronto' AND er.expira_em IS NOT NULL AND er.expira_em < now() THEN 'Expirado'
      ELSE er.status
    END AS status_exibicao,
    er.data_inicial,
    er.data_final,
    er.arquivo_nome,
    er.mime_type,
    er.tamanho_bytes,
    er.criado_por,
    coalesce(p2.nome, '') AS criado_por_nome,
    er.gerado_em,
    er.expira_em,
    (
      er.status = 'Pronto'
      AND er.expira_em IS NOT NULL AND er.expira_em >= now()
      AND v_tem_capacidade
      AND public.categoria_relatorio_exportavel(er.tipo, v_perfil_acesso)
      AND (
        v_perfil_acesso = 'Administrador'
        OR er.criado_por = auth.uid()
      )
    ) AS pode_baixar,
    er.erro
  FROM public.exportacoes_relatorios er
  LEFT JOIN public.perfis p2 ON p2.usuario_id = er.criado_por
  WHERE (p_tipo IS NULL OR p_tipo = '' OR er.tipo = p_tipo)
    AND (
      v_perfil_acesso = 'Administrador'
      OR er.criado_por = auth.uid()
    )
  ORDER BY er.criado_em DESC, er.id DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_exportacoes_relatorios(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_exportacoes_relatorios(text) TO authenticated;


-- ============================================================
-- T016. RPC legada solicitar_exportacao_relatorio (apenas compatibilidade)
-- ============================================================
-- Nenhuma mudanca de comportamento: a implementacao atual ja insere apenas
-- status 'Indisponivel' com arquivo_url nulo, sem simular sucesso. Documentamos
-- via comentario SQL que ela nao participa mais do fluxo novo (Edge Function
-- relatorios-exportacao + iniciar_exportacao_relatorio/concluir/falhar).

COMMENT ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) IS
  'DEPRECATED (feature 008): mantida apenas por compatibilidade legada. '
  'Nao participa do fluxo novo de exportacao (Edge Function relatorios-exportacao '
  '+ iniciar_exportacao_relatorio/concluir_exportacao_relatorio/falhar_exportacao_relatorio). '
  'Continua sempre inserindo status ''Indisponivel'' com arquivo_url nulo, sem simular sucesso.';
