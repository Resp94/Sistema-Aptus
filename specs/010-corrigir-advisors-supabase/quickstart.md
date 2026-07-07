# Quickstart: Corrigir Advisors Supabase

## Objetivo

Validar a feature 010 de ponta a ponta sem depender de conhecimento tacito fora do repositório.

## Pre-requisitos

- Repositório com `specs/010-corrigir-advisors-supabase/` presente
- MCP do Supabase conectado ao projeto `lpwnaxlczwntylcmgotm`
- Ambiente local capaz de rodar testes do projeto

## Fluxo de Validacao

### 1. Ler o baseline

1. Abrir `triagem.md`
2. Revisar `research.md`
3. Confirmar o escopo em `contracts/security-remediation.md` e `contracts/performance-remediation.md`

### 2. Validar o repositório localmente (Gates Estáticos)

1. Confirmar que as migrations novas da feature existem em `supabase/migrations/`
2. Executar validações de código e build:
   - `npm run test` (testes unitários e de integração do frontend)
   - `npm run build` (compilação livre de erros de tipagem)
   - `npm run audit` (auditoria estática de conformidade RLS/RPC)
3. Executar testes locais de banco de dados (se aplicável):
   - `npm run db:test` (cobertura pgTAP completa)
   > [!NOTE]
   > Caso a engine local do Docker Desktop não esteja instalada ou ativa no host do usuário, os testes locais de banco (`npm run db:test`) devem ser pulados (bypass operacional documentado). A validação remota via MCP Supabase passa a ser o gate principal de conformidade de infraestrutura.
4. Esperado:
   - Compilação estrita com sucesso, auditoria sem novos lints de segurança/RPC e frontend íntegro.

### 3. Validar o baseline remoto

1. Conectar via MCP do Supabase ao projeto `lpwnaxlczwntylcmgotm`.
2. Seguir `runbook-validacao.md` até o fim do Passo 1.
3. Esperado:
   - Conexão e projeto remoto confirmados.
   - Snapshot inicial registrado comprovando as violações do linter em `capacidades_perfil` (sem policy) e RPCs expostas.

### 4. Aplicar e revalidar remotamente (Gate Dinâmico)

1. Promover as migrations locais para o banco remoto de produção `lpwnaxlczwntylcmgotm`.
2. Executar o Passo 3 e Passo 4 do `runbook-validacao.md`.
3. Esperado:
   - O linter remoto do Supabase Advisors não deve apontar mais nenhum erro de segurança ou performance ligado a `capacidades_perfil`, RPCs expostas ou RLS ineficientes no escopo.

### 5. Fechar a rodada (Gate de Governança)

1. Atualizar `triagem.md` registrando os snapshots de baseline/post-apply e classificações finais.
2. Atualizar `.agents/project-memory/010-corrigir-advisors-supabase.md`.
3. Atualizar `.sauron/wiki/knowledge/architecture.md`.
4. Esperado:
   - Todo achado de segurança/performance no escopo está documentado como resolvido ou justificado como exceção intencional.

---

## 6. Exclusão Explícita de Tuning Geral do Escopo (FR-008 / T033)

Para evitar desvio de foco e assegurar a entrega estruturada do MVP de conformidade:
- Lints de **Database Tuning Geral** (tais como `unindexed_foreign_keys` - chaves estrangeiras sem índices - e `unused_index` - índices não utilizados) foram **explicitamente excluídos do escopo de remediação desta feature**.
- Estas otimizações físicas de banco devem ser encaminhadas ao backlog de infraestrutura/performance em sprints subsequentes.

