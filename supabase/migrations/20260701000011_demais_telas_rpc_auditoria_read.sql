-- Migration: 20260701000011_demais_telas_rpc_auditoria_read.sql
-- Implementação da RPC de leitura para logs de auditoria (audit_log)

CREATE OR REPLACE FUNCTION public.listar_logs_auditoria()
RETURNS TABLE (
  id uuid,
  evento text,
  usuario_nome text,
  ip_address text,
  detalhes text,
  criado_em timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
BEGIN
  -- Apenas Administrador
  IF NOT public.existe_perfil_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Apenas administradores podem ler os logs de auditoria';
  END IF;

  RETURN QUERY
  SELECT 
    al.id,
    al.evento,
    coalesce(p.nome, al.usuario_id::text) as usuario_nome,
    al.ip_address,
    al.detalhes,
    al.criado_em
  FROM public.audit_log al
  LEFT JOIN public.perfis p ON al.usuario_id = p.usuario_id
  ORDER BY al.criado_em DESC, al.id DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.listar_logs_auditoria() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listar_logs_auditoria() TO authenticated;
