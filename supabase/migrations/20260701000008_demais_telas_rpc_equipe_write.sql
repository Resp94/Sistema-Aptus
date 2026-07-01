-- Migration: 20260701000008_demais_telas_rpc_equipe_write.sql
-- Implementação de funções de escrita do domínio Equipe

-- 1. criar_membro_equipe
CREATE OR REPLACE FUNCTION public.criar_membro_equipe(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_nome text;
  v_funcao text;
  v_habilidades text[];
  v_status text;
  v_capacidade integer;
  v_custo_hora numeric(14,2);
  v_perfil_id uuid;
BEGIN
  -- Permissão Check: Apenas Administrador ou Projetos
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
  END IF;

  v_nome := payload->>'nome';
  v_funcao := payload->>'funcao';
  v_habilidades := coalesce(array_fill(null::text, array[0]), (
    SELECT array_agg(x) FROM jsonb_array_elements_text(payload->'habilidades') x
  ), '{}'::text[]);
  v_status := coalesce(payload->>'status', 'Disponível');
  v_capacidade := coalesce((payload->>'capacidade')::integer, 100);
  v_custo_hora := coalesce((payload->>'custo_hora')::numeric, 0.00);
  v_perfil_id := (payload->>'perfil_id')::uuid;

  -- Validações
  IF v_nome IS NULL OR trim(v_nome) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Nome é obrigatório';
  END IF;
  IF v_funcao IS NULL OR trim(v_funcao) = '' THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Função é obrigatória';
  END IF;
  IF v_status NOT IN ('Disponível', 'Alocado', 'Férias', 'Ausente') THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Status de membro inválido';
  END IF;
  IF v_capacidade NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Capacidade deve ser entre 0 e 100';
  END IF;
  IF v_custo_hora < 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Custo por hora inválido';
  END IF;

  INSERT INTO public.membros_equipe (
    nome,
    funcao,
    habilidades,
    status,
    capacidade,
    custo_hora,
    perfil_id
  ) VALUES (
    v_nome,
    v_funcao,
    v_habilidades,
    v_status,
    v_capacidade,
    v_custo_hora,
    v_perfil_id
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_membro_equipe(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_membro_equipe(jsonb) TO authenticated;


-- 2. atualizar_membro_equipe
CREATE OR REPLACE FUNCTION public.atualizar_membro_equipe(p_id uuid, payload jsonb)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_acesso text;
  v_my_membro_id uuid;
  v_nome text;
  v_funcao text;
  v_habilidades text[];
  v_status text;
  v_capacidade integer;
  v_custo_hora numeric(14,2);
  v_perfil_id uuid;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_ler = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão no módulo Equipe';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id INTO v_my_membro_id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  v_nome := payload->>'nome';
  v_funcao := payload->>'funcao';
  v_habilidades := (SELECT array_agg(x) FROM jsonb_array_elements_text(payload->'habilidades') x);
  v_status := payload->>'status';
  v_capacidade := (payload->>'capacidade')::integer;
  v_custo_hora := (payload->>'custo_hora')::numeric;
  v_perfil_id := (payload->>'perfil_id')::uuid;

  -- Restrição do Técnico: Só atualiza seus próprios dados (nome, habilidades)
  IF v_perfil_acesso = 'Técnico' THEN
    IF p_id <> v_my_membro_id THEN
      RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Técnico não pode editar dados de outro membro';
    END IF;

    UPDATE public.membros_equipe
    SET
      nome = coalesce(v_nome, nome),
      habilidades = coalesce(v_habilidades, habilidades),
      updated_at = now()
    WHERE id = p_id;
  ELSE
    -- Administrador ou Projetos: Atualiza tudo
    -- Validar se tem permissão de escrita
    IF NOT EXISTS (
      SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
    ) THEN
      RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não possui permissão de escrita';
    END IF;

    UPDATE public.membros_equipe
    SET
      nome = coalesce(v_nome, nome),
      funcao = coalesce(v_funcao, funcao),
      habilidades = coalesce(v_habilidades, habilidades),
      status = coalesce(v_status, status),
      capacidade = coalesce(v_capacidade, capacidade),
      custo_hora = coalesce(v_custo_hora, custo_hora),
      perfil_id = coalesce(v_perfil_id, perfil_id),
      updated_at = now()
    WHERE id = p_id;
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.atualizar_membro_equipe(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_membro_equipe(uuid, jsonb) TO authenticated;


-- 3. alocar_membro_projeto
CREATE OR REPLACE FUNCTION public.alocar_membro_projeto(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_membro_equipe_id uuid;
  v_projeto_id uuid;
  v_data_inicio date;
  v_data_fim date;
  v_percentual_alocacao integer;
  v_funcao_no_projeto text;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
  END IF;

  v_membro_equipe_id := (payload->>'membro_equipe_id')::uuid;
  v_projeto_id := (payload->>'projeto_id')::uuid;
  v_data_inicio := (payload->>'data_inicio')::date;
  v_data_fim := (payload->>'data_fim')::date;
  v_percentual_alocacao := (payload->>'percentual_alocacao')::integer;
  v_funcao_no_projeto := payload->>'funcao_no_projeto';

  -- Validações
  IF v_membro_equipe_id IS NULL OR v_projeto_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Membro e projeto são obrigatórios';
  END IF;
  IF v_data_inicio IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Data de início é obrigatória';
  END IF;
  IF v_percentual_alocacao NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Percentual de alocação deve ser entre 1 e 100';
  END IF;

  -- Verifica se já existe alocação ativa para evitar duplicidade
  SELECT id INTO v_id
  FROM public.alocacoes_equipe
  WHERE membro_equipe_id = v_membro_equipe_id AND projeto_id = v_projeto_id
    AND (data_fim IS NULL OR data_fim >= v_data_inicio)
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    -- Atualiza alocação existente
    UPDATE public.alocacoes_equipe
    SET percentual_alocacao = v_percentual_alocacao,
        data_fim = v_data_fim,
        funcao_no_projeto = coalesce(v_funcao_no_projeto, funcao_no_projeto),
        updated_at = now()
    WHERE id = v_id;
  ELSE
    -- Insere nova alocação
    INSERT INTO public.alocacoes_equipe (
      membro_equipe_id,
      projeto_id,
      data_inicio,
      data_fim,
      percentual_alocacao,
      funcao_no_projeto
    ) VALUES (
      v_membro_equipe_id,
      v_projeto_id,
      v_data_inicio,
      v_data_fim,
      v_percentual_alocacao,
      v_funcao_no_projeto
    )
    RETURNING id INTO v_id;
  END IF;

  -- Também cria um registro em public.alocacoes_projeto se não existir (para garantir a autorização técnica mínima)
  -- Obtém o usuario_id do perfil do membro de equipe
  DECLARE
    v_usuario_id uuid;
  BEGIN
    SELECT usuario_id INTO v_usuario_id FROM public.perfis WHERE id = (SELECT perfil_id FROM public.membros_equipe WHERE id = v_membro_equipe_id);
    IF v_usuario_id IS NOT NULL THEN
      INSERT INTO public.alocacoes_projeto (projeto_id, usuario_id, papel)
      VALUES (v_projeto_id, v_usuario_id, v_funcao_no_projeto)
      ON CONFLICT (projeto_id, usuario_id) DO NOTHING;
    END IF;
  END;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.alocar_membro_projeto(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.alocar_membro_projeto(jsonb) TO authenticated;


-- 4. registrar_apontamento_horas
CREATE OR REPLACE FUNCTION public.registrar_apontamento_horas(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_tarefa_id uuid;
  v_projeto_id uuid;
  v_membro_equipe_id uuid;
  v_horas numeric(6,2);
  v_descricao text;
  v_data date;
  v_perfil_acesso text;
  v_my_membro_id uuid;
BEGIN
  -- Permissão Check
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('projetos') WHERE pode_escrever = true
    UNION
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão no módulo Equipe/Projetos';
  END IF;

  SELECT perfil_acesso INTO v_perfil_acesso FROM public.perfis WHERE usuario_id = auth.uid();
  SELECT id INTO v_my_membro_id FROM public.membros_equipe WHERE perfil_id = (SELECT id FROM public.perfis WHERE usuario_id = auth.uid());

  v_tarefa_id := (payload->>'tarefa_id')::uuid;
  v_projeto_id := (payload->>'projeto_id')::uuid;
  v_membro_equipe_id := (payload->>'membro_equipe_id')::uuid;
  v_horas := (payload->>'horas')::numeric;
  v_descricao := payload->>'descricao';
  v_data := coalesce((payload->>'data')::date, current_date);

  -- Validação do Técnico: Só aponta horas para si mesmo
  IF v_perfil_acesso = 'Técnico' THEN
    v_membro_equipe_id := v_my_membro_id;
  END IF;

  -- Se tarefa_id for fornecido, resolve o projeto_id automaticamente caso seja nulo
  IF v_tarefa_id IS NOT NULL AND v_projeto_id IS NULL THEN
    SELECT projeto_id INTO v_projeto_id FROM public.tarefas WHERE id = v_tarefa_id;
  END IF;

  -- Validações
  IF v_projeto_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Projeto é obrigatório';
  END IF;
  IF v_membro_equipe_id IS NULL THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Membro é obrigatório';
  END IF;
  IF v_horas IS NULL OR v_horas <= 0 THEN
    RAISE EXCEPTION 'validation_error' USING DETAIL = 'Horas devem ser maior que zero';
  END IF;

  INSERT INTO public.apontamentos_horas (
    tarefa_id,
    projeto_id,
    membro_equipe_id,
    horas,
    descricao,
    data
  ) VALUES (
    v_tarefa_id,
    v_projeto_id,
    v_membro_equipe_id,
    v_horas,
    v_descricao,
    v_data
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_apontamento_horas(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_apontamento_horas(jsonb) TO authenticated;


-- 5. inativar_membro_equipe
CREATE OR REPLACE FUNCTION public.inativar_membro_equipe(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil_id uuid;
BEGIN
  -- Permissão Check: Apenas Administrador ou Projetos
  IF NOT EXISTS (
    SELECT 1 FROM public.permissao_modulo('equipe') WHERE pode_escrever = true
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING DETAIL = 'Usuário não tem permissão de escrita no Equipe';
  END IF;

  SELECT perfil_id INTO v_perfil_id FROM public.membros_equipe WHERE id = p_id;
  IF v_perfil_id IS NULL AND NOT EXISTS (SELECT 1 FROM public.membros_equipe WHERE id = p_id) THEN
    RAISE EXCEPTION 'not_found' USING DETAIL = 'Membro de equipe não encontrado';
  END IF;

  -- 1. Inativar o membro (Ausente)
  UPDATE public.membros_equipe
  SET status = 'Ausente',
      capacidade = 0,
      updated_at = now()
  WHERE id = p_id;

  -- 2. Inativar o perfil correspondente na tabela perfis (se houver login)
  IF v_perfil_id IS NOT NULL THEN
    UPDATE public.perfis
    SET status = 'Inativo',
        updated_at = now()
    WHERE id = v_perfil_id;
  END IF;

  -- 3. Registrar auditoria
  PERFORM public.registrar_evento_auditoria(
    'membro_equipe_inativado',
    auth.uid(),
    '0.0.0.0',
    'Membro ID: ' || p_id::text
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.inativar_membro_equipe(uuid) TO authenticated;
