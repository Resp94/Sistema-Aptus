-- Migration: 20260628000002_modulos_landing_security.sql
-- Habilitação de RLS, criação da função auxiliar permissao_modulo, políticas de segurança e extensão do enum de auditoria

-- 1. Função auxiliar de permissão (Fonte única de RBAC para RLS e RPCs)
CREATE OR REPLACE FUNCTION public.permissao_modulo(p_modulo text)
RETURNS TABLE (pode_ler boolean, pode_escrever boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET row_security = off
AS $$
BEGIN
  RETURN QUERY
  SELECT p.pode_ler, p.pode_escrever
  FROM public.obter_permissoes_usuario() p
  WHERE p.modulo = p_modulo;
END;
$$;

-- 2. Habilitação de RLS nas 6 tabelas
ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.atendimentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projetos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tarefas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alocacoes_projeto ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lancamentos ENABLE ROW LEVEL SECURITY;

-- 3. Políticas para Clientes
CREATE POLICY clientes_select ON public.clientes
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_ler = true));

CREATE POLICY clientes_insert ON public.clientes
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true));

CREATE POLICY clientes_update ON public.clientes
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true));

-- 4. Políticas para Atendimentos
CREATE POLICY atendimentos_select ON public.atendimentos
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_ler = true));

CREATE POLICY atendimentos_insert ON public.atendimentos
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true));

CREATE POLICY atendimentos_update ON public.atendimentos
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true));

CREATE POLICY atendimentos_delete ON public.atendimentos
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('clientes') WHERE pode_escrever = true));

-- 5. Políticas para Projetos
CREATE POLICY projetos_select ON public.projetos
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true));

CREATE POLICY projetos_insert ON public.projetos
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

CREATE POLICY projetos_update ON public.projetos
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

CREATE POLICY projetos_delete ON public.projetos
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

-- 6. Políticas para Tarefas
CREATE POLICY tarefas_select ON public.tarefas
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true));

CREATE POLICY tarefas_insert ON public.tarefas
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

CREATE POLICY tarefas_update ON public.tarefas
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

CREATE POLICY tarefas_delete ON public.tarefas
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

-- 7. Políticas para Alocações de Projeto
CREATE POLICY alocacoes_select ON public.alocacoes_projeto
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_ler = true));

CREATE POLICY alocacoes_insert ON public.alocacoes_projeto
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

CREATE POLICY alocacoes_update ON public.alocacoes_projeto
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

CREATE POLICY alocacoes_delete ON public.alocacoes_projeto
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true));

-- 8. Políticas para Lançamentos
CREATE POLICY lancamentos_select ON public.lancamentos
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_ler = true));

CREATE POLICY lancamentos_insert ON public.lancamentos
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_escrever = true));

CREATE POLICY lancamentos_update ON public.lancamentos
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_escrever = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_escrever = true));

CREATE POLICY lancamentos_delete ON public.lancamentos
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.permissao_modulo('dashboard') WHERE pode_escrever = true));

-- 9. Extensão do CHECK da coluna audit_log.evento para suportar exclusões e inativação
ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_evento_check;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_evento_check CHECK (
  evento IN (
    'login_sucesso', 'login_falha', 'senha_alterada', 'usuario_criado',
    'conta_desativada', 'conta_ativada',
    'projeto_excluido', 'tarefa_excluida', 'cliente_inativado'
  )
);
