-- Migration: RBAC por Capacidades Nomeadas - Fundacao (feature 007)
-- Escopo: T006, T016, T017, T018, T019, T020, T045
--
-- Fonte de verdade do catalogo canonico de capacidades:
--   specs/007-rbac-capacidades-nomeadas/data-model.md (secao "Catalogo inicial")
--   specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md ("Matriz Esperada")
--
-- Catalogo canonico (37 capacidades, formato recurso.acao):
--   clientes.criar
--   clientes.editar
--   clientes.inativar
--   clientes.reativar
--   clientes.registrar_atendimento
--   propostas.criar
--   propostas.editar
--   propostas.enviar
--   propostas.gerar_contrato
--   contratos.criar
--   contratos.renovar
--   contratos.encerrar
--   cobrancas.emitir
--   cobrancas.boleto
--   cobrancas.notificar
--   cobrancas.baixar
--   projetos.criar
--   projetos.editar
--   projetos.excluir
--   tarefas.criar
--   tarefas.excluir
--   tarefas.editar_qualquer
--   tarefas.mover_qualquer
--   tarefas.editar_propria
--   tarefas.mover_propria
--   equipe.adicionar_membro
--   equipe.alocar
--   equipe.inativar_membro
--   apontamentos.registrar_proprio
--   apontamentos.registrar_qualquer
--   financeiro.lancar
--   financeiro.editar_lancamento
--   financeiro.baixar_lancamento
--   configuracoes.gerenciar_usuarios
--   configuracoes.editar_empresa
--   configuracoes.editar_proprio_perfil
--   relatorios.exportar
--
-- Qualquer capacidade usada em `capacidades_perfil` ou em RPCs deve pertencer a este catalogo.
-- Alteracoes no catalogo devem ser refletidas primeiro em data-model.md e capability-matrix.md.

-- ============================================================
-- 1. Tabela public.capacidades_perfil (T016)
-- ============================================================
-- RLS habilitado sem nenhuma policy (deny-all por padrao). Acesso direto do
-- frontend via PostgREST nao e contrato publico; a leitura ocorre exclusivamente
-- via RPC SECURITY DEFINER `public.obter_capacidades_usuario()`, que usa
-- `SET row_security = off` (mesmo padrao de `public.obter_permissoes_usuario()`
-- em supabase/migrations/20260702000003_security_hardening_padronizacao.sql).

CREATE TABLE public.capacidades_perfil (
  perfil_acesso text NOT NULL,
  capacidade text NOT NULL,
  PRIMARY KEY (perfil_acesso, capacidade)
);

ALTER TABLE public.capacidades_perfil ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.capacidades_perfil FROM PUBLIC;
REVOKE ALL ON public.capacidades_perfil FROM authenticated;
GRANT ALL ON public.capacidades_perfil TO service_role;


-- ============================================================
-- 2. Helper public.tem_capacidade(p_capacidade text) (T017)
-- ============================================================
-- Contrato (contracts/rpc-capability-contract.md):
--   - Retorna false para chamador anonimo (NAO faz RAISE EXCEPTION, pois esta
--     funcao e chamada de dentro de outras RPCs que ja fizeram o guard de
--     identidade).
--   - Retorna false se perfil ausente ou status <> 'Ativo'.
--   - Retorna true apenas se existir linha em capacidades_perfil para o
--     perfil_acesso do usuario autenticado com a capacidade pedida.
--   - Nunca usa user_metadata.

CREATE OR REPLACE FUNCTION public.tem_capacidade(p_capacidade text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT perfis.perfil_acesso, perfis.status INTO v_perfil_acesso, v_status
  FROM public.perfis
  WHERE usuario_id = auth.uid();

  IF v_perfil_acesso IS NULL OR v_status <> 'Ativo' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.capacidades_perfil cp
    WHERE cp.perfil_acesso = v_perfil_acesso
      AND cp.capacidade = p_capacidade
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.tem_capacidade(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.tem_capacidade(text) TO authenticated;


-- ============================================================
-- 3. Helper public.obter_capacidades_usuario() (T018)
-- ============================================================
-- Contrato:
--   - Requer usuario autenticado (RAISE EXCEPTION 'Unauthorized' caso contrario,
--     igual ao padrao de obter_permissoes_usuario).
--   - Retorna lista ORDENADA das capacidades do perfil ativo do usuario autenticado.
--   - Retorna lista vazia para Visualizador ou perfil inativo/ausente.

CREATE OR REPLACE FUNCTION public.obter_capacidades_usuario()
RETURNS text[]
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
  v_capacidades text[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT perfis.perfil_acesso, perfis.status INTO v_perfil_acesso, v_status
  FROM public.perfis
  WHERE usuario_id = auth.uid();

  IF v_perfil_acesso IS NULL OR v_status <> 'Ativo' THEN
    RETURN ARRAY[]::text[];
  END IF;

  SELECT COALESCE(array_agg(cp.capacidade ORDER BY cp.capacidade), ARRAY[]::text[])
  INTO v_capacidades
  FROM public.capacidades_perfil cp
  WHERE cp.perfil_acesso = v_perfil_acesso;

  RETURN v_capacidades;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_capacidades_usuario() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_capacidades_usuario() TO authenticated;


-- ============================================================
-- 4. Seed da matriz de capacidades por perfil (T019)
-- ============================================================
-- Fonte: contracts/capability-matrix.md ("Matriz Esperada").
-- Visualizador propositalmente NAO recebe nenhuma linha (zero capacidades).

-- Administrador: todas as 37 capacidades do catalogo.
INSERT INTO public.capacidades_perfil (perfil_acesso, capacidade) VALUES
  ('Administrador', 'clientes.criar'),
  ('Administrador', 'clientes.editar'),
  ('Administrador', 'clientes.inativar'),
  ('Administrador', 'clientes.reativar'),
  ('Administrador', 'clientes.registrar_atendimento'),
  ('Administrador', 'propostas.criar'),
  ('Administrador', 'propostas.editar'),
  ('Administrador', 'propostas.enviar'),
  ('Administrador', 'propostas.gerar_contrato'),
  ('Administrador', 'contratos.criar'),
  ('Administrador', 'contratos.renovar'),
  ('Administrador', 'contratos.encerrar'),
  ('Administrador', 'cobrancas.emitir'),
  ('Administrador', 'cobrancas.boleto'),
  ('Administrador', 'cobrancas.notificar'),
  ('Administrador', 'cobrancas.baixar'),
  ('Administrador', 'projetos.criar'),
  ('Administrador', 'projetos.editar'),
  ('Administrador', 'projetos.excluir'),
  ('Administrador', 'tarefas.criar'),
  ('Administrador', 'tarefas.excluir'),
  ('Administrador', 'tarefas.editar_qualquer'),
  ('Administrador', 'tarefas.mover_qualquer'),
  ('Administrador', 'tarefas.editar_propria'),
  ('Administrador', 'tarefas.mover_propria'),
  ('Administrador', 'equipe.adicionar_membro'),
  ('Administrador', 'equipe.alocar'),
  ('Administrador', 'equipe.inativar_membro'),
  ('Administrador', 'apontamentos.registrar_proprio'),
  ('Administrador', 'apontamentos.registrar_qualquer'),
  ('Administrador', 'financeiro.lancar'),
  ('Administrador', 'financeiro.editar_lancamento'),
  ('Administrador', 'financeiro.baixar_lancamento'),
  ('Administrador', 'configuracoes.gerenciar_usuarios'),
  ('Administrador', 'configuracoes.editar_empresa'),
  ('Administrador', 'configuracoes.editar_proprio_perfil'),
  ('Administrador', 'relatorios.exportar');

-- Financeiro
INSERT INTO public.capacidades_perfil (perfil_acesso, capacidade) VALUES
  ('Financeiro', 'financeiro.lancar'),
  ('Financeiro', 'financeiro.editar_lancamento'),
  ('Financeiro', 'financeiro.baixar_lancamento'),
  ('Financeiro', 'cobrancas.emitir'),
  ('Financeiro', 'cobrancas.baixar'),
  ('Financeiro', 'relatorios.exportar'),
  ('Financeiro', 'configuracoes.editar_proprio_perfil');

-- Projetos
INSERT INTO public.capacidades_perfil (perfil_acesso, capacidade) VALUES
  ('Projetos', 'projetos.criar'),
  ('Projetos', 'projetos.editar'),
  ('Projetos', 'projetos.excluir'),
  ('Projetos', 'tarefas.criar'),
  ('Projetos', 'tarefas.excluir'),
  ('Projetos', 'tarefas.editar_qualquer'),
  ('Projetos', 'tarefas.mover_qualquer'),
  ('Projetos', 'equipe.adicionar_membro'),
  ('Projetos', 'equipe.alocar'),
  ('Projetos', 'equipe.inativar_membro'),
  ('Projetos', 'apontamentos.registrar_qualquer'),
  ('Projetos', 'relatorios.exportar'),
  ('Projetos', 'configuracoes.editar_proprio_perfil');

-- Comercial
INSERT INTO public.capacidades_perfil (perfil_acesso, capacidade) VALUES
  ('Comercial', 'clientes.criar'),
  ('Comercial', 'clientes.editar'),
  ('Comercial', 'clientes.inativar'),
  ('Comercial', 'clientes.reativar'),
  ('Comercial', 'clientes.registrar_atendimento'),
  ('Comercial', 'propostas.criar'),
  ('Comercial', 'propostas.editar'),
  ('Comercial', 'propostas.enviar'),
  ('Comercial', 'propostas.gerar_contrato'),
  ('Comercial', 'contratos.criar'),
  ('Comercial', 'contratos.renovar'),
  ('Comercial', 'contratos.encerrar'),
  ('Comercial', 'cobrancas.emitir'),
  ('Comercial', 'cobrancas.boleto'),
  ('Comercial', 'cobrancas.notificar'),
  ('Comercial', 'configuracoes.editar_proprio_perfil');

-- Técnico
INSERT INTO public.capacidades_perfil (perfil_acesso, capacidade) VALUES
  ('Técnico', 'tarefas.editar_propria'),
  ('Técnico', 'tarefas.mover_propria'),
  ('Técnico', 'apontamentos.registrar_proprio'),
  ('Técnico', 'configuracoes.editar_proprio_perfil');

-- Visualizador: zero capacidades (nenhuma linha inserida de proposito).


-- ============================================================
-- 5. Ajuste de leitura por modulo em obter_permissoes_usuario() (T020, T045)
-- ============================================================
-- Preserva integralmente a assinatura e a estrutura definidas por ultimo em
-- supabase/migrations/20260702000003_security_hardening_padronizacao.sql.
-- Unica mudanca funcional: Visualizador passa a ter leitura minima apenas em
-- `relatorios` e `configuracoes` (leitura das proprias configuracoes); todos os
-- demais modulos ficam (false, false) para Visualizador. Administrador,
-- Financeiro, Projetos, Comercial e Técnico permanecem inalterados (Financeiro
-- mantem dashboard (true,true); Projetos mantem dashboard (false,false)).

CREATE OR REPLACE FUNCTION public.obter_permissoes_usuario()
RETURNS TABLE (
  modulo text,
  pode_ler boolean,
  pode_escrever boolean
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET row_security = off
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT perfis.perfil_acesso, perfis.status INTO v_perfil_acesso, v_status
  FROM public.perfis
  WHERE usuario_id = auth.uid();

  IF v_status <> 'Ativo' OR v_perfil_acesso IS NULL THEN
    RETURN;
  END IF;

  IF v_perfil_acesso = 'Administrador' THEN
    RETURN QUERY VALUES
      ('dashboard', true, true),
      ('clientes', true, true),
      ('propostas', true, true),
      ('contratos', true, true),
      ('cobrancas', true, true),
      ('projetos', true, true),
      ('equipe', true, true),
      ('financeiro', true, true),
      ('fluxo-caixa', true, true),
      ('contas-pagar', true, true),
      ('contas-receber', true, true),
      ('relatorios', true, true),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Financeiro' THEN
    RETURN QUERY VALUES
      ('dashboard', true, true),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', true, true),
      ('projetos', false, false),
      ('equipe', false, false),
      ('financeiro', true, true),
      ('fluxo-caixa', true, true),
      ('contas-pagar', true, true),
      ('contas-receber', true, true),
      ('relatorios', true, true),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Projetos' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', false, false),
      ('projetos', true, true),
      ('equipe', true, true),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', true, true),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Comercial' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', true, true),
      ('propostas', true, true),
      ('contratos', true, true),
      ('cobrancas', true, true),
      ('projetos', false, false),
      ('equipe', false, false),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', false, false),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Técnico' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', false, false),
      ('projetos', true, true),
      ('equipe', true, false),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', false, false),
      ('configuracoes', true, true);

  ELSIF v_perfil_acesso = 'Visualizador' THEN
    RETURN QUERY VALUES
      ('dashboard', false, false),
      ('clientes', false, false),
      ('propostas', false, false),
      ('contratos', false, false),
      ('cobrancas', false, false),
      ('projetos', false, false),
      ('equipe', false, false),
      ('financeiro', false, false),
      ('fluxo-caixa', false, false),
      ('contas-pagar', false, false),
      ('contas-receber', false, false),
      ('relatorios', true, false),
      ('configuracoes', true, false);
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.obter_permissoes_usuario() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_permissoes_usuario() TO authenticated;
