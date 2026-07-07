# Triagem Inicial e Normalização dos Achados

**Projeto remoto**: `lpwnaxlczwntylcmgotm`  
**URL do projeto**: `https://lpwnaxlczwntylcmgotm.supabase.co`  
**Data do baseline**: 2026-07-07  
**Migrations remotas ativas**: 27 migrations aplicadas (última: `20260704235640_exportar_relatorios.sql`)

## 1. Tabela Principal de Achados (Advisors)

| ID | Advisor | Objeto | Lint | Classificação inicial | Ação planejada | Evidência base | Resultado final |
|----|---------|--------|------|-----------------------|----------------|----------------|-----------------|
| SEC-001 | `security` | `public.capacidades_perfil` | `rls_enabled_no_policy` | `risco_real` | Adicionar policy coerente ao desenho service-owned e revalidar advisor | Advisor remoto + `20260703000001_rbac_capacidades_foundation.sql` | resolvido |
| SEC-002 | `security` | Funções `SECURITY DEFINER` expostas a `anon` | `anon_security_definer_function_executable` | `risco_real` | Desdobrado por assinatura exata (ver Tabela 2.1) | Advisor remoto + migrations de RPCs e exportação | resolvido |
| SEC-003 | `security` | Funções `SECURITY DEFINER` expostas a `authenticated` | `authenticated_security_definer_function_executable` | `investigar` | Desdobrado por assinatura exata (ver Tabela 2.2) | Advisor remoto + busca em `src/`, `supabase/functions` e banco | excecao_intencional |
| PERF-001 | `performance` | Policies com `auth.uid()` direto | `auth_rls_initplan` | `risco_real` | Reescrever policies no escopo com `(select auth.uid())` e equivalentes seguros | Advisor remoto + `00000000000000_usuarios_perfis.sql` | resolvido |
| PERF-002 | `performance` | `public.perfis` | `multiple_permissive_policies` | `risco_real` | Consolidar `SELECT` e `UPDATE` sem regressão de acesso | Advisor remoto + `00000000000000_usuarios_perfis.sql` | resolvido |
| PERF-OUT-001 | `performance` | FKs sem índice | `unindexed_foreign_keys` | `fora_escopo` | Registrar exclusão da feature 010; avaliar em backlog próprio | Advisor remoto | Fora do escopo |
| PERF-OUT-002 | `performance` | Índices não usados | `unused_index` | `fora_escopo` | Registrar exclusão da feature 010; avaliar em backlog próprio | Advisor remoto | Fora do escopo |

---

## 2. Detalhes de SECURITY DEFINER (SEC-002 e SEC-003)

### 2.1. Tabela 2.1: Desdobramento de SEC-002 (Funções SECURITY DEFINER expostas a `anon`)

Esta tabela lista individualmente cada assinatura exata de função `SECURITY DEFINER` no escopo da feature que deve ter seus privilégios de execução públicos (`anon` e `PUBLIC`) revogados.

| ID | Assinatura Exata | Classificação | Ação Corretiva Proposta | Evidência / Destino | Resultado Final |
|----|------------------|---------------|-------------------------|---------------------|-----------------|
| SEC-002-001 | `public.criar_cliente(text, text, text, text, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-002 | `public.atualizar_cliente(uuid, text, text, text, text, text, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-003 | `public.inativar_cliente(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-004 | `public.registrar_atendimento(uuid, text, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-005 | `public.criar_proposta(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-006 | `public.atualizar_proposta(uuid, jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-007 | `public.registrar_envio_proposta(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-008 | `public.criar_contrato(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-009 | `public.renovar_contrato(uuid, date, numeric)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-010 | `public.encerrar_contrato(uuid, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-011 | `public.criar_cobranca(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-012 | `public.solicitar_emissao_boleto(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-013 | `public.solicitar_lembrete_cobranca(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-014 | `public.registrar_pagamento_cobranca(uuid, jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-015 | `public.criar_projeto(text, uuid, numeric, date, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-016 | `public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-017 | `public.excluir_projeto(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-018 | `public.criar_tarefa(uuid, text, text, uuid, date, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-019 | `public.atualizar_tarefa(uuid, text, text, uuid, date, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-020 | `public.mover_tarefa(uuid, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-021 | `public.excluir_tarefa(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-022 | `public.registrar_apontamento_horas(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-023 | `public.listar_membros_equipe(text, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260702000001_fix_rpc_sync_desync.sql` | resolvido |
| SEC-002-024 | `public.criar_membro_equipe(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-025 | `public.atualizar_membro_equipe(uuid, jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-026 | `public.alocar_membro_projeto(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-027 | `public.inativar_membro_equipe(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-028 | `public.criar_lancamento_financeiro(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-029 | `public.atualizar_lancamento_financeiro(uuid, jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-030 | `public.registrar_pagamento_lancamento(uuid, date, numeric)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-031 | `public.atualizar_configuracoes_empresa(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-032 | `public.atualizar_usuario_perfil(uuid, jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-033 | `public.atualizar_minhas_configuracoes(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-034 | `public.atualizar_preferencias_notificacoes(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-035 | `public.solicitar_exportacao_relatorio(text, text, jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-036 | `public.agendar_relatorio(jsonb)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260703000002_rbac_capacidades_rpc_guards.sql` | resolvido |
| SEC-002-037 | `public.categoria_relatorio_exportavel(text, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-038 | `public.validar_periodo_exportacao(date, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-039 | `public.montar_payload_relatorio_financeiro(date, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-040 | `public.montar_payload_relatorio_dre(date, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-041 | `public.montar_payload_relatorio_clientes(date, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-042 | `public.montar_payload_relatorio_projetos(date, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-043 | `public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-044 | `public.iniciar_exportacao_relatorio(text, text, date, date)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-045 | `public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-046 | `public.falhar_exportacao_relatorio(uuid, text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-047 | `public.autorizar_download_exportacao_relatorio(uuid)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |
| SEC-002-048 | `public.listar_exportacoes_relatorios(text)` | `risco_real` | `REVOKE EXECUTE ON FUNCTION` FROM `PUBLIC` | `20260704235640_exportar_relatorios.sql` | resolvido |

### 2.2. Tabela 2.2: Desdobramento de SEC-003 (Funções SECURITY DEFINER expostas a `authenticated`)

Esta tabela lista cada assinatura exata de função `SECURITY DEFINER` e sua classificação final em relação ao acesso pela role `authenticated` (usuários logados no cliente).
A triagem avalia a dependência viva nas superfícies: `src/services`, `supabase/functions/` e dependências no banco.

| ID | Assinatura Exata | Dependência Viva | Classificação | Racional / Ação Corretiva | Resultado Final |
|----|------------------|------------------|---------------|---------------------------|-----------------|
| SEC-003-001 | `public.criar_cliente(text, text, text, text, text)` | Frontend (`src/services/clientes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido internamente por guardas de capacidades (`clientes.criar`). | excecao_intencional |
| SEC-003-002 | `public.atualizar_cliente(uuid, text, text, text, text, text, text)` | Frontend (`src/services/clientes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidades (`clientes.editar`/`clientes.reativar`). | excecao_intencional |
| SEC-003-003 | `public.inativar_cliente(uuid)` | Frontend (`src/services/clientes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`clientes.inativar`). | excecao_intencional |
| SEC-003-004 | `public.registrar_atendimento(uuid, text, date)` | Frontend (`src/services/clientes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`clientes.registrar_atendimento`). | excecao_intencional |
| SEC-003-005 | `public.criar_proposta(jsonb)` | Frontend (`src/services/comercial.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`propostas.criar`). | excecao_intencional |
| SEC-003-006 | `public.atualizar_proposta(uuid, jsonb)` | Frontend (`src/services/comercial.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`propostas.editar`). | excecao_intencional |
| SEC-003-007 | `public.registrar_envio_proposta(uuid)` | Frontend (`src/services/comercial.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`propostas.enviar`). | excecao_intencional |
| SEC-003-008 | `public.criar_contrato(jsonb)` | Frontend (`src/services/comercial.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`contratos.criar`/`propostas.gerar_contrato`). | excecao_intencional |
| SEC-003-009 | `public.renovar_contrato(uuid, date, numeric)` | Frontend (`src/services/comercial.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`contratos.renovar`). | excecao_intencional |
| SEC-003-010 | `public.encerrar_contrato(uuid, text)` | Frontend (`src/services/comercial.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`contratos.encerrar`). | excecao_intencional |
| SEC-003-011 | `public.criar_cobranca(jsonb)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`cobrancas.emitir`). | excecao_intencional |
| SEC-003-012 | `public.solicitar_emissao_boleto(uuid)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`cobrancas.boleto`). | excecao_intencional |
| SEC-003-013 | `public.solicitar_lembrete_cobranca(uuid)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`cobrancas.notificar`). | excecao_intencional |
| SEC-003-014 | `public.registrar_pagamento_cobranca(uuid, jsonb)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`cobrancas.baixar`). | excecao_intencional |
| SEC-003-015 | `public.criar_projeto(text, uuid, numeric, date, text)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`projetos.criar`). | excecao_intencional |
| SEC-003-016 | `public.atualizar_projeto(uuid, text, uuid, text, integer, numeric, numeric, boolean, date)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`projetos.editar`). | excecao_intencional |
| SEC-003-017 | `public.excluir_projeto(uuid)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`projetos.excluir`). | excecao_intencional |
| SEC-003-018 | `public.criar_tarefa(uuid, text, text, uuid, date, text)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`tarefas.criar`). | excecao_intencional |
| SEC-003-019 | `public.atualizar_tarefa(uuid, text, text, uuid, date, text)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidades (`tarefas.editar_qualquer`/`tarefas.editar_propria`). | excecao_intencional |
| SEC-003-020 | `public.mover_tarefa(uuid, text)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidades (`tarefas.mover_qualquer`/`tarefas.mover_propria`). | excecao_intencional |
| SEC-003-021 | `public.excluir_tarefa(uuid)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`tarefas.excluir`). | excecao_intencional |
| SEC-003-022 | `public.registrar_apontamento_horas(jsonb)` | Frontend (`src/services/projetos.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidades (`apontamentos.registrar_qualquer`/`apontamentos.registrar_proprio`). | excecao_intencional |
| SEC-003-023 | `public.listar_membros_equipe(text, text)` | Frontend (`src/services/equipe.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por controle interno de visibilidade por módulo e perfil. | excecao_intencional |
| SEC-003-024 | `public.criar_membro_equipe(jsonb)` | Frontend (`src/services/equipe.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`equipe.adicionar_membro`). | excecao_intencional |
| SEC-003-025 | `public.atualizar_membro_equipe(uuid, jsonb)` | Frontend (`src/services/equipe.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`equipe.adicionar_membro`). | excecao_intencional |
| SEC-003-026 | `public.alocar_membro_projeto(jsonb)` | Frontend (`src/services/equipe.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`equipe.alocar`). | excecao_intencional |
| SEC-003-027 | `public.inativar_membro_equipe(uuid)` | Frontend (`src/services/equipe.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`equipe.inativar_membro`). | excecao_intencional |
| SEC-003-028 | `public.criar_lancamento_financeiro(jsonb)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`financeiro.lancar`). | excecao_intencional |
| SEC-003-029 | `public.atualizar_lancamento_financeiro(uuid, jsonb)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`financeiro.editar_lancamento`). | excecao_intencional |
| SEC-003-030 | `public.registrar_pagamento_lancamento(uuid, date, numeric)` | Frontend (`src/services/financeiro.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`financeiro.baixar_lancamento`). | excecao_intencional |
| SEC-003-031 | `public.atualizar_configuracoes_empresa(jsonb)` | Frontend (`src/services/configuracoes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`configuracoes.editar_empresa`). | excecao_intencional |
| SEC-003-032 | `public.atualizar_usuario_perfil(uuid, jsonb)` | Frontend (`src/services/configuracoes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`configuracoes.gerenciar_usuarios`). | excecao_intencional |
| SEC-003-033 | `public.atualizar_minhas_configuracoes(jsonb)` | Frontend (`src/services/configuracoes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`configuracoes.editar_proprio_perfil`). | excecao_intencional |
| SEC-003-034 | `public.atualizar_preferencias_notificacoes(jsonb)` | Frontend (`src/services/configuracoes.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`configuracoes.editar_proprio_perfil`). | excecao_intencional |
| SEC-003-035 | `public.solicitar_exportacao_relatorio(text, text, jsonb)` | Frontend (`src/services/relatorios.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-036 | `public.agendar_relatorio(jsonb)` | Frontend (`src/services/relatorios.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-037 | `public.categoria_relatorio_exportavel(text, text)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated` (função auxiliar de segurança). | excecao_intencional |
| SEC-003-038 | `public.validar_periodo_exportacao(date, date)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated` (função auxiliar de validação). | excecao_intencional |
| SEC-003-039 | `public.montar_payload_relatorio_financeiro(date, date)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-040 | `public.montar_payload_relatorio_dre(date, date)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-041 | `public.montar_payload_relatorio_clientes(date, date)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-042 | `public.montar_payload_relatorio_projetos(date, date)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-043 | `public.registrar_evento_exportacao(text, uuid, text, text, date, date, text, integer, bigint, text)` | Banco (`iniciar_exportacao_relatorio`) | `excecao_intencional` | Preservar acesso a `authenticated` (função de auditoria interna). | excecao_intencional |
| SEC-003-044 | `public.iniciar_exportacao_relatorio(text, text, date, date)` | Frontend (`src/services/relatorios.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`). | excecao_intencional |
| SEC-003-045 | `public.concluir_exportacao_relatorio(uuid, text, text, text, bigint, text)` | Edge Function (`supabase/functions/relatorios-exportacao/index.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por propriedade (`criado_por = auth.uid()`). | excecao_intencional |
| SEC-003-046 | `public.falhar_exportacao_relatorio(uuid, text)` | Edge Function (`supabase/functions/relatorios-exportacao/index.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por propriedade (`criado_por = auth.uid()`). | excecao_intencional |
| SEC-003-047 | `public.autorizar_download_exportacao_relatorio(uuid)` | Frontend (`src/services/relatorios.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, protegido por capacidade (`relatorios.exportar`) e ownership. | excecao_intencional |
| SEC-003-048 | `public.listar_exportacoes_relatorios(text)` | Frontend (`src/services/relatorios.service.ts`) | `excecao_intencional` | Preservar acesso a `authenticated`, filtrado por módulo e propriedade. | excecao_intencional |

## 3. Snapshots Reais de Baseline e Post-Apply

Para fins de governança e auditoria de segurança, os snapshots abaixo foram coletados no ambiente remoto de produção (`lpwnaxlczwntylcmgotm`) via ferramenta Supabase MCP.

### 3.1. Snapshot de Baseline (Remoto)
- **Security Advisors**:
  - Acusava `rls_enabled_no_policy` para a tabela `public.capacidades_perfil`.
  - Acusava `anon_security_definer_function_executable` para as 48 RPCs de escrita e exportação na namespace `public` (permitindo execução anônima pública).
  - Acusava a exceção de auditoria `registrar_evento_auditoria` como exposta.
- **Performance Advisors**:
  - Acusava `auth_rls_initplan` nas políticas RLS das tabelas centrais devido ao uso direto do predicado `auth.uid()`.
  - Acusava `multiple_permissive_policies` para a tabela `public.perfis` nos métodos `SELECT` e `UPDATE`.
  - Acusava lints de tuning geral (`unindexed_foreign_keys` e `unused_index`).

### 3.2. Snapshot de Post-Apply (Remoto)
- **Security Advisors**:
  - O warning `rls_enabled_no_policy` para `public.capacidades_perfil` foi inteiramente removido após a criação da policy explícita baseada em `service_role`.
  - Os warnings `anon_security_definer_function_executable` para as 48 RPCs sumiram completamente, após a aplicação dos comandos `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC`.
  - A exceção `registrar_evento_auditoria` foi confirmada como `excecao_intencional` e documentada na matriz.
- **Performance Advisors**:
  - Os lints `auth_rls_initplan` para as tabelas modificadas sumiram completamente da lista devido à substituição do predicado direto por `(select auth.uid())`, permitindo a otimização de subconsulta por InitPlan de única avaliação pelo Postgres.
  - O warning `multiple_permissive_policies` para `public.perfis` foi resolvido pela consolidação de policies.
  - Permaneceram ativos somente os warnings de tuning geral de chaves estrangeiras não indexadas e índices não utilizados, os quais estão marcados como fora do escopo desta feature.

---

## 4. Lints de Tuning Geral Excluídos do Escopo (FR-008 / T033)

Para esta feature (010), o escopo de atuação foi delimitado estritamente para mitigar riscos reais de segurança no banco remoto e otimizar queries e RLS no escopo das user stories. Com isso, os seguintes lints de tuning geral de banco de dados foram **explicitamente excluídos do escopo de remediação da feature**:

1. **`unindexed_foreign_keys` (Chaves estrangeiras não indexadas)**:
   - *Motivo da exclusão*: O mapeamento de índices sobre chaves estrangeiras requer uma análise ampla de caminhos de acesso e volumetria das queries do front-end do ERP. Indexar todas as FKs preventivamente pode degradar a performance de escrita e aumentar o consumo de disco sem benefício real imediato.
   - *Ação futura*: Deixado no backlog geral de Database Tuning para avaliação conforme o ERP escale em produção.
2. **`unused_index` (Índices não utilizados)**:
   - *Motivo da exclusão*: Identificar se um índice é realmente inútil exige medição de estatísticas de uso em produção (`pg_stat_user_indexes`) durante um ciclo longo de operação. A exclusão de índices sem histórico consolidado pode degradar queries analíticas esporádicas.
   - *Ação futura*: A avaliação de expurgo de índices será tratada em sprint dedicado de auditoria física de banco.

