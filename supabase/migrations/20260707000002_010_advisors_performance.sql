-- Migration: 20260707000002_010_advisors_performance.sql
-- Feature: 010-corrigir-advisors-supabase
-- Propósito: Tratar os warnings de performance do Supabase Advisors (PERF-001, PERF-002)
--            incluindo reescrita de policies com (select auth.uid()) e consolidação em public.perfis.

-- =========================================================================
-- 1. Tabela public.perfis (Consolidação e Otimização)
-- =========================================================================
DROP POLICY IF EXISTS perfis_select_self ON public.perfis;
DROP POLICY IF EXISTS perfis_select_admin ON public.perfis;
CREATE POLICY perfis_select ON public.perfis
  FOR SELECT TO authenticated
  USING (
    (select auth.uid()) = usuario_id OR public.existe_perfil_admin((select auth.uid()))
  );

DROP POLICY IF EXISTS perfis_update_self ON public.perfis;
DROP POLICY IF EXISTS perfis_update_admin ON public.perfis;
CREATE POLICY perfis_update ON public.perfis
  FOR UPDATE TO authenticated
  USING (
    (select auth.uid()) = usuario_id OR public.existe_perfil_admin((select auth.uid()))
  )
  WITH CHECK (
    (select auth.uid()) = usuario_id OR public.existe_perfil_admin((select auth.uid()))
  );

DROP POLICY IF EXISTS perfis_insert_admin ON public.perfis;
CREATE POLICY perfis_insert_admin ON public.perfis
  FOR INSERT TO authenticated
  WITH CHECK (
    public.existe_perfil_admin((select auth.uid()))
  );

-- =========================================================================
-- 2. Tabela public.usuarios (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS usuarios_select_self ON public.usuarios;
CREATE POLICY usuarios_select_self ON public.usuarios
  FOR SELECT TO authenticated
  USING (
    (select auth.uid()) = id
  );

-- =========================================================================
-- 3. Tabela public.audit_log (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS audit_log_select_admin ON public.audit_log;
CREATE POLICY audit_log_select_admin ON public.audit_log
  FOR SELECT TO authenticated
  USING (
    public.existe_perfil_admin((select auth.uid()))
  );

-- =========================================================================
-- 4. Tabela public.membros_equipe (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS membros_equipe_select ON public.membros_equipe;
CREATE POLICY membros_equipe_select ON public.membros_equipe
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true) AND (
      public.existe_perfil_admin((select auth.uid())) OR
      EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = (select auth.uid()) AND perfil_acesso IN ('Projetos', 'Visualizador')) OR
      perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid()))
    )
  );

DROP POLICY IF EXISTS membros_equipe_update ON public.membros_equipe;
CREATE POLICY membros_equipe_update ON public.membros_equipe
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) OR
    (perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) OR
    (
      perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid()))
    )
  );

-- =========================================================================
-- 5. Tabela public.alocacoes_equipe (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS alocacoes_equipe_select ON public.alocacoes_equipe;
CREATE POLICY alocacoes_equipe_select ON public.alocacoes_equipe
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true) AND (
      public.existe_perfil_admin((select auth.uid())) OR
      EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = (select auth.uid()) AND perfil_acesso IN ('Projetos', 'Visualizador')) OR
      membro_equipe_id = (SELECT id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())))
    )
  );

-- =========================================================================
-- 6. Tabela public.apontamentos_horas (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS apontamentos_horas_select ON public.apontamentos_horas;
CREATE POLICY apontamentos_horas_select ON public.apontamentos_horas
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true) AND (
      public.existe_perfil_admin((select auth.uid())) OR
      EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = (select auth.uid()) AND perfil_acesso IN ('Projetos', 'Visualizador')) OR
      membro_equipe_id = (SELECT id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())))
    )
  );

DROP POLICY IF EXISTS apontamentos_horas_insert ON public.apontamentos_horas;
CREATE POLICY apontamentos_horas_insert ON public.apontamentos_horas
  FOR INSERT TO authenticated
  WITH CHECK (
    public.existe_perfil_admin((select auth.uid())) OR
    EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = (select auth.uid()) AND perfil_acesso IN ('Projetos', 'Técnico'))
  );

-- =========================================================================
-- 7. Tabela public.configuracoes_empresa (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS configuracoes_empresa_select ON public.configuracoes_empresa;
CREATE POLICY configuracoes_empresa_select ON public.configuracoes_empresa
  FOR SELECT TO authenticated
  USING (
    public.existe_perfil_admin((select auth.uid()))
  );

DROP POLICY IF EXISTS configuracoes_empresa_update ON public.configuracoes_empresa;
CREATE POLICY configuracoes_empresa_update ON public.configuracoes_empresa
  FOR UPDATE TO authenticated
  USING (
    public.existe_perfil_admin((select auth.uid()))
  )
  WITH CHECK (
    public.existe_perfil_admin((select auth.uid()))
  );

-- =========================================================================
-- 8. Tabela public.preferencias_notificacoes (Otimização)
-- =========================================================================
DROP POLICY IF EXISTS preferencias_notificacoes_select ON public.preferencias_notificacoes;
CREATE POLICY preferencias_notificacoes_select ON public.preferencias_notificacoes
  FOR SELECT TO authenticated
  USING (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())) OR
    public.existe_perfil_admin((select auth.uid()))
  );

DROP POLICY IF EXISTS preferencias_notificacoes_insert ON public.preferencias_notificacoes;
CREATE POLICY preferencias_notificacoes_insert ON public.preferencias_notificacoes
  FOR INSERT TO authenticated
  WITH CHECK (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())) OR
    public.existe_perfil_admin((select auth.uid()))
  );

DROP POLICY IF EXISTS preferencias_notificacoes_update ON public.preferencias_notificacoes;
CREATE POLICY preferencias_notificacoes_update ON public.preferencias_notificacoes
  FOR UPDATE TO authenticated
  USING (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())) OR
    public.existe_perfil_admin((select auth.uid()))
  )
  WITH CHECK (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = (select auth.uid())) OR
    public.existe_perfil_admin((select auth.uid()))
  );
