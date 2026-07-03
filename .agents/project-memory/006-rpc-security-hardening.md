# Spec 006 - RPC Security Hardening

**Data**: 2026-07-03 (atualizado na validação pós-implementação do mesmo dia)

## Correção pós-implementação (validação)

A lista abaixo originalmente incluía `atualizar_usuario_perfil(uuid, jsonb)` como uma das 34 funções recriadas na fase2. Ela foi **removida da fase2.sql**: por FR-005/tasks.md T015, essa função é admin-only via `existe_perfil_admin` e não deveria ganhar guard de módulo (`permissao_modulo`) — a definição vigente é a de `20260702000002_security_hardening_fase0.sql`, sem alteração de comportamento. `scripts/audit-rpc.mjs` foi ajustado para reconhecer esse padrão (allowlist `ADMIN_GATED`) em vez de forçar guard de módulo nela. O total de funções recriadas na fase2 passou de 34 para 32. `listar_responsaveis_tarefas` também estava duplicada (definida sem guard em `20260702000003_security_hardening_padronizacao.sql` e com guard aqui) — a versão sem guard foi removida de lá, mantendo esta como única fonte.

Também foram corrigidos bugs em `supabase/tests/*.sql` que faziam `npm run db:test` falhar (não relacionados a esta migração): ver commit/diff de 2026-07-03 para detalhes. Suíte validada em 96/96, `Result: PASS`.

## O que foi feito (registro original)

Criada a migração `supabase/migrations/20260703000000_security_hardening_fase2.sql` que recria funções RPC de domínio identificadas na auditoria `npm run audit:rpc` como não conformes com os guardrails de segurança (32 após a correção acima; ver nota no topo).

Cada função foi recriada com `CREATE OR REPLACE FUNCTION`, preservando:
- assinatura, tipo de retorno, linguagem, volatilidade e `search_path = public`;
- corpo e lógica de negócio originais;
- comentários e estilo das migrações anteriores;
- instruções `REVOKE EXECUTE ... FROM PUBLIC` e `GRANT EXECUTE ... TO authenticated` originais.

Ao início do corpo de cada função foram adicionados:
1. **Identity guard**: `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501'; END IF;`
2. **Module guard**: `IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('<modulo>') WHERE pode_ler = true / pode_escrever = true) THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501'; END IF;`

Funções recriadas (módulo e operação):

- `obter_resumo_fluxo_caixa(date, date)` — fluxo-caixa read
- `listar_fluxo_caixa(date, date, text, text)` — fluxo-caixa read
- `obter_fluxo_caixa_series(date, date)` — fluxo-caixa read
- `listar_contas_pagar(text, text, date, date)` — contas-pagar read
- `listar_contas_receber(text, uuid, date, date)` — contas-receber read
- `obter_metricas_contas(text, date, date)` — financeiro read
- `criar_lancamento_financeiro(jsonb)` — financeiro write
- `atualizar_lancamento_financeiro(uuid, jsonb)` — financeiro write
- `listar_propostas(text, uuid, text)` — propostas read
- `obter_proposta_detalhe(uuid)` — propostas read
- `listar_contratos(text, uuid, text)` — contratos read
- `obter_contrato_detalhe(uuid)` — contratos read
- `listar_cobrancas(text, uuid, date, date)` — cobrancas read
- `obter_cobranca_detalhe(uuid)` — cobrancas read
- `atualizar_proposta(uuid, jsonb)` — propostas write
- `registrar_envio_proposta(uuid)` — propostas write
- `encerrar_contrato(uuid, text)` — contratos write
- `solicitar_emissao_boleto(uuid)` — cobrancas read
- `solicitar_lembrete_cobranca(uuid)` — cobrancas read
- `renovar_contrato(uuid, date, numeric)` — contratos write
- `criar_membro_equipe(jsonb)` — equipe write
- `alocar_membro_projeto(jsonb)` — equipe write
- `inativar_membro_equipe(uuid)` — equipe write
- `listar_exportacoes_relatorios(text)` — relatorios read
- `obter_configuracoes_empresa()` — configuracoes read
- `listar_usuarios_configuracoes()` — configuracoes read
- `obter_minhas_configuracoes()` — configuracoes read
- `listar_preferencias_notificacoes()` — configuracoes read
- `listar_logs_auditoria()` — configuracoes read
- `atualizar_configuracoes_empresa(jsonb)` — configuracoes write
- `atualizar_minhas_configuracoes(jsonb)` — configuracoes write
- `atualizar_preferencias_notificacoes(jsonb)` — configuracoes write
- `listar_responsaveis_tarefas()` — projetos read

## Por que foi feito

A auditoria `npm run audit:rpc` apontou funções de domínio sem identity guard e/ou sem validação via `public.permissao_modulo`. A Fase 2 padroniza essas funções sem alterar comportamento de negócio, garantindo que toda chamada RPC exija autenticação e permissão explícita de módulo antes de executar qualquer lógica sensível.

## Regras registradas

- Toda RPC de domínio deve declarar `SECURITY DEFINER` e `SET search_path = public`.
- Toda RPC de domínio deve iniciar o corpo com identity guard (`auth.uid()` não nulo) e module guard (`public.permissao_modulo`).
- A classificação read vs write segue a finalidade da função: `list`/`obter`/`solicitar_emissao`/`solicitar_lembrete` são leitura; `criar`/`atualizar`/`registrar_envio`/`encerrar`/`inativar`/`renovar` são escrita.
- Ao recriar funções por segurança, preservar assinatura, retorno, volatilidade, lógica, comentários e grants originais.
- Não adicionar novos `REVOKE`/`GRANT` quando o arquivo original já os possui.

## Arquivos afetados

- `supabase/migrations/20260703000000_security_hardening_fase2.sql`
- `.agents/project-memory/006-rpc-security-hardening.md`
