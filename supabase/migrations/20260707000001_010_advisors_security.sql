-- Migration: 20260707000001_010_advisors_security.sql
-- Feature: 010-corrigir-advisors-supabase
-- Propósito: Tratar os achados de segurança do Supabase Advisors (SEC-001, SEC-002, SEC-003)
--            incluindo a policy para public.capacidades_perfil e a revogação de grants públicos indevidos.

-- ============================================================================
-- 1. SEC-001: Policy explícita para a tabela service-owned public.capacidades_perfil
-- ============================================================================
ALTER TABLE public.capacidades_perfil ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_full_access" ON public.capacidades_perfil;
CREATE POLICY "service_role_full_access" ON public.capacidades_perfil
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 2. SEC-002 / SEC-003: Revogação de privilégios para PUBLIC/anon e concessão a authenticated
-- ============================================================================

-- 2.1 Clientes
REVOKE EXECUTE ON FUNCTION public.criar_cliente(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_cliente(text, text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_cliente(uuid, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_cliente(uuid, text, text, text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.inativar_cliente(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inativar_cliente(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.registrar_atendimento(uuid, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_atendimento(uuid, text, date) TO authenticated;

-- 2.2 Comercial
REVOKE EXECUTE ON FUNCTION public.criar_proposta(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_proposta(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_proposta(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_proposta(uuid, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.registrar_envio_proposta(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_envio_proposta(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.criar_contrato(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_contrato(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renovar_contrato(uuid, date, numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encerrar_contrato(uuid, text) TO authenticated;

-- 2.3 Financeiro / Cobranças
REVOKE EXECUTE ON FUNCTION public.criar_cobranca(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_cobranca(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.solicitar_emissao_boleto(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.solicitar_emissao_boleto(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.solicitar_lembrete_cobranca(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.solicitar_lembrete_cobranca(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.registrar_pagamento_cobranca(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_pagamento_cobranca(uuid, jsonb) TO authenticated;

-- 2.4 Projetos / Tarefas
REVOKE EXECUTE ON FUNCTION public.criar_projeto(text, uuid, numeric, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_projeto(text, uuid, numeric, date, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.excluir_projeto(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.excluir_projeto(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.criar_tarefa(uuid, text, text, uuid, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_tarefa(uuid, text, text, uuid, date, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_tarefa(uuid, text, text, uuid, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_tarefa(uuid, text, text, uuid, date, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mover_tarefa(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mover_tarefa(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.excluir_tarefa(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.excluir_tarefa(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.registrar_apontamento_horas(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_apontamento_horas(jsonb) TO authenticated;

-- 2.5 Equipe
REVOKE EXECUTE ON FUNCTION public.listar_membros_equipe(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_membros_equipe(text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.criar_membro_equipe(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_membro_equipe(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_membro_equipe(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_membro_equipe(uuid, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.alocar_membro_projeto(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.alocar_membro_projeto(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) TO authenticated;

-- 2.6 Financeiro
REVOKE EXECUTE ON FUNCTION public.criar_lancamento_financeiro(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_lancamento_financeiro(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_lancamento_financeiro(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_lancamento_financeiro(uuid, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.registrar_pagamento_lancamento(uuid, date, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_pagamento_lancamento(uuid, date, numeric) TO authenticated;

-- 2.7 Configurações
REVOKE EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_configuracoes_empresa(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_usuario_perfil(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_usuario_perfil(uuid, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_minhas_configuracoes(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_minhas_configuracoes(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.atualizar_preferencias_notificacoes(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_preferencias_notificacoes(jsonb) TO authenticated;

-- 2.8 Relatórios e Exportação
REVOKE EXECUTE ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.solicitar_exportacao_relatorio(text, text, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.agendar_relatorio(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agendar_relatorio(jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.categoria_relatorio_exportavel(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.categoria_relatorio_exportavel(text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.validar_periodo_exportacao(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validar_periodo_exportacao(date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_financeiro(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_financeiro(date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_dre(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_dre(date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_clientes(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_clientes(date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.montar_payload_relatorio_projetos(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.montar_payload_relatorio_projetos(date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.iniciar_exportacao_relatorio(text, text, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.iniciar_exportacao_relatorio(text, text, date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.falhar_exportacao_relatorio(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.falhar_exportacao_relatorio(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.autorizar_download_exportacao_relatorio(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.autorizar_download_exportacao_relatorio(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.listar_exportacoes_relatorios(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_exportacoes_relatorios(text) TO authenticated;
