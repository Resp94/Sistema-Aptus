-- Migration: 20260701000002_demais_telas_security.sql
-- Habilitação de RLS e políticas de segurança para novas tabelas

-- 1. Habilitação de RLS
ALTER TABLE public.propostas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contratos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cobrancas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagamentos_cobrancas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membros_equipe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alocacoes_equipe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apontamentos_horas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agendamentos_relatorios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exportacoes_relatorios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_empresa ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferencias_notificacoes ENABLE ROW LEVEL SECURITY;

-- 2. Revogar privilégios públicos padrão e conceder explicitamente
DO $$
DECLARE
  t text;
  tabelas text[] := ARRAY[
    'propostas', 'contratos', 'documentos', 'cobrancas', 'pagamentos_cobrancas',
    'membros_equipe', 'alocacoes_equipe', 'apontamentos_horas',
    'agendamentos_relatorios', 'exportacoes_relatorios', 'configuracoes_empresa',
    'preferencias_notificacoes'
  ];
BEGIN
  FOREACH t IN ARRAY tabelas LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM public;', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated;', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role;', t);
  END LOOP;
END;
$$;

-- 3. Políticas para Propostas (Comercial / Administrador / Visualizador)
CREATE POLICY propostas_select ON public.propostas
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true)
  );

CREATE POLICY propostas_insert ON public.propostas
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true)
  );

CREATE POLICY propostas_update ON public.propostas
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true)
  );

CREATE POLICY propostas_delete ON public.propostas
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true)
  );

-- 4. Políticas para Contratos (Comercial / Administrador / Visualizador)
CREATE POLICY contratos_select ON public.contratos
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true)
  );

CREATE POLICY contratos_insert ON public.contratos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true)
  );

CREATE POLICY contratos_update ON public.contratos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true)
  );

CREATE POLICY contratos_delete ON public.contratos
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true)
  );

-- 5. Políticas para Documentos
CREATE POLICY documentos_select ON public.documentos
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_ler = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_ler = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true)
  );

CREATE POLICY documentos_insert ON public.documentos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true)
  );

CREATE POLICY documentos_update ON public.documentos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('contratos') WHERE pode_escrever = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('propostas') WHERE pode_escrever = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true)
  );

-- 6. Políticas para Cobranças (Comercial / Financeiro / Administrador / Visualizador)
CREATE POLICY cobrancas_select ON public.cobrancas
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true)
  );

CREATE POLICY cobrancas_insert ON public.cobrancas
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true)
  );

CREATE POLICY cobrancas_update ON public.cobrancas
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true)
  );

-- 7. Políticas para Pagamentos Cobranças
CREATE POLICY pagamentos_cobrancas_select ON public.pagamentos_cobrancas
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_ler = true)
  );

CREATE POLICY pagamentos_cobrancas_insert ON public.pagamentos_cobrancas
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('cobrancas') WHERE pode_escrever = true)
  );

-- 8. Políticas para Membros da Equipe
-- Projetos/Admin/Visualizador veem tudo. Técnico vê apenas a si mesmo.
CREATE POLICY membros_equipe_select ON public.membros_equipe
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true) AND (
      public.existe_perfil_admin(auth.uid()) OR
      EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = auth.uid() AND perfil_acesso IN ('Projetos', 'Visualizador')) OR
      perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid())
    )
  );

CREATE POLICY membros_equipe_insert ON public.membros_equipe
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true)
  );

CREATE POLICY membros_equipe_update ON public.membros_equipe
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) OR
    (perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true) OR
    (
      -- Técnico só pode atualizar si mesmo e sem alterar campos protegidos (tratado na trigger ou na RPC)
      perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid())
    )
  );

-- 9. Políticas para Alocações Equipe
CREATE POLICY alocacoes_equipe_select ON public.alocacoes_equipe
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true) AND (
      public.existe_perfil_admin(auth.uid()) OR
      EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = auth.uid() AND perfil_acesso IN ('Projetos', 'Visualizador')) OR
      membro_equipe_id = (SELECT id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()))
    )
  );

CREATE POLICY alocacoes_equipe_insert ON public.alocacoes_equipe
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true)
  );

CREATE POLICY alocacoes_equipe_update ON public.alocacoes_equipe
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true)
  );

CREATE POLICY alocacoes_equipe_delete ON public.alocacoes_equipe
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true)
  );

-- 10. Políticas para Apontamentos de Horas
CREATE POLICY apontamentos_horas_select ON public.apontamentos_horas
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true) OR
    EXISTS (SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true) AND (
      public.existe_perfil_admin(auth.uid()) OR
      EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = auth.uid() AND perfil_acesso IN ('Projetos', 'Visualizador')) OR
      membro_equipe_id = (SELECT id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()))
    )
  );

CREATE POLICY apontamentos_horas_insert ON public.apontamentos_horas
  FOR INSERT TO authenticated
  WITH CHECK (
    public.existe_perfil_admin(auth.uid()) OR
    EXISTS (SELECT 1 FROM public.perfis WHERE usuario_id = auth.uid() AND perfil_acesso IN ('Projetos', 'Técnico'))
  );

-- 11. Políticas para Agendamentos e Exportações de Relatórios
CREATE POLICY agendamentos_relatorios_select ON public.agendamentos_relatorios
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true)
  );

CREATE POLICY agendamentos_relatorios_insert ON public.agendamentos_relatorios
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_escrever = true)
  );

CREATE POLICY agendamentos_relatorios_update ON public.agendamentos_relatorios
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_escrever = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_escrever = true)
  );

CREATE POLICY exportacoes_relatorios_select ON public.exportacoes_relatorios
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_ler = true)
  );

CREATE POLICY exportacoes_relatorios_insert ON public.exportacoes_relatorios
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.permissao_modulo('relatorios') WHERE pode_escrever = true)
  );

-- 12. Políticas para Configurações Empresa (Apenas Administrador)
CREATE POLICY configuracoes_empresa_select ON public.configuracoes_empresa
  FOR SELECT TO authenticated
  USING (
    public.existe_perfil_admin(auth.uid())
  );

CREATE POLICY configuracoes_empresa_update ON public.configuracoes_empresa
  FOR UPDATE TO authenticated
  USING (
    public.existe_perfil_admin(auth.uid())
  )
  WITH CHECK (
    public.existe_perfil_admin(auth.uid())
  );

-- 13. Políticas para Preferências de Notificações
CREATE POLICY preferencias_notificacoes_select ON public.preferencias_notificacoes
  FOR SELECT TO authenticated
  USING (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()) OR
    public.existe_perfil_admin(auth.uid())
  );

CREATE POLICY preferencias_notificacoes_insert ON public.preferencias_notificacoes
  FOR INSERT TO authenticated
  WITH CHECK (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()) OR
    public.existe_perfil_admin(auth.uid())
  );

CREATE POLICY preferencias_notificacoes_update ON public.preferencias_notificacoes
  FOR UPDATE TO authenticated
  USING (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()) OR
    public.existe_perfil_admin(auth.uid())
  )
  WITH CHECK (
    perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid()) OR
    public.existe_perfil_admin(auth.uid())
  );
