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

### 2. Validar o repositório antes da aplicacao

1. Confirmar que as migrations novas da feature existem em `supabase/migrations/`
2. Executar:
   - `npm run db:test`
   - `npm run test`
   - `npm run build`
   - `npm run audit`
3. Esperado:
   - Nenhum teste quebra por regressao de grants, RLS ou RPC

### 3. Validar o baseline remoto

1. Seguir `runbook-validacao.md` ate o fim do Passo 1
2. Esperado:
   - Projeto remoto confirmado como `lpwnaxlczwntylcmgotm`
   - Snapshot inicial de `security` e `performance` registrado

### 4. Aplicar e revalidar

1. Aplicar as migrations da feature no fluxo operacional apropriado
2. Reexecutar o `runbook-validacao.md` a partir do Passo 3
3. Esperado:
   - Achados de seguranca e performance no escopo reduzidos ou reclassificados de forma explicita

### 5. Fechar a rodada

1. Atualizar `triagem.md` com resultado final
2. Atualizar `.agents/project-memory/010-corrigir-advisors-supabase.md`
3. Atualizar `.sauron/wiki/knowledge/architecture.md`
4. Esperado:
   - Nenhum risco real no escopo fica sem resolucao documentada
