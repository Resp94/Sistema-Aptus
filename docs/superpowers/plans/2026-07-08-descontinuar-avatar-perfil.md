# Descontinuar Avatar de Perfil Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remover a feature morta de avatar/foto de perfil do frontend, contratos de tipos e backend Supabase, eliminando `avatar_url` da UI e das RPCs.

**Architecture:** A remoção será feita em quatro frentes pequenas e auditáveis: testes de regressão primeiro, limpeza do frontend e contratos TypeScript, migration SQL para retirar `avatar_url` do schema e das RPCs, e atualização da memória do projeto em `.agents` e `.sauron`. A UI continuará usando iniciais do nome no shell, sem qualquer fallback de imagem.

**Tech Stack:** Vite, React, TypeScript, Vitest, Supabase SQL migrations, documentação local em `.agents` e `.sauron`

---

### Task 1: Remover avatar do frontend e dos contratos TS

**Files:**
- Modify: `src/pages/ConfiguracoesPage.tsx`
- Modify: `src/services/configuracoes.service.ts`
- Modify: `src/types/auth.ts`
- Modify: `src/pages/ConfiguracoesPage.test.tsx`
- Modify: `src/pages/RelatoriosPage.test.tsx`

- [ ] **Step 1: Escrever/ajustar testes para o contrato sem avatar**

Cobrir pelo menos:
- `ConfiguracoesPage` nao deve renderizar campo `Avatar URL`
- mocks de `useAuth` e `obterMinhasConfiguracoes` nao devem mais depender de `avatar_url`
- tipos de perfil usados pelos testes devem refletir o novo contrato

- [ ] **Step 2: Rodar os testes direcionados e confirmar falha vermelha**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx src/pages/RelatoriosPage.test.tsx`

Expected:
- Falha por referencias restantes a `avatar_url` ou pelo campo ainda existir na UI

- [ ] **Step 3: Implementar a remocao minima no frontend**

Aplicar:
- remover `formAvatar`, leitura inicial e envio de `avatar_url` em `ConfiguracoesPage`
- remover `avatar_url` do payload de `atualizarMinhasConfiguracoes`
- remover `avatar_url` de `PerfilUsuario`
- ajustar consumidores de `PerfilUsuario` e mocks de teste

- [ ] **Step 4: Rodar novamente os testes direcionados**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx src/pages/RelatoriosPage.test.tsx`

Expected:
- PASS

- [ ] **Step 5: Registrar os arquivos alterados para integracao**

Listar explicitamente os caminhos modificados no retorno do worker.

### Task 2: Remover avatar do schema e das RPCs Supabase

**Files:**
- Create: `supabase/migrations/<timestamp>_drop_avatar_perfil.sql`
- Optionally modify if test coverage exists nearby: `supabase/tests/*`

- [ ] **Step 1: Identificar o contrato atual a ser removido**

Remover:
- coluna `public.perfis.avatar_url`
- retorno `avatar_url` de `public.obter_perfil_usuario()`
- retorno `avatar_url` de `public.obter_minhas_configuracoes()`
- escrita de `avatar_url` em `public.atualizar_minhas_configuracoes(payload jsonb)`

- [ ] **Step 2: Criar uma migration nova via CLI do Supabase**

Run: `supabase migration new drop_avatar_perfil`

Expected:
- Novo arquivo criado em `supabase/migrations/`

- [ ] **Step 3: Implementar a migration minima**

Incluir no SQL:
- `ALTER TABLE public.perfis DROP COLUMN IF EXISTS avatar_url;`
- recriar as funcoes afetadas com a assinatura/shape sem `avatar_url`
- preservar guards de autenticacao, capacidade e `search_path`

- [ ] **Step 4: Validar estaticamente referencias restantes**

Run: `rg -n "avatar_url" src supabase docs .agents .sauron`

Expected:
- nenhuma referencia de codigo vivo; apenas historico/documentacao antiga, se ainda nao atualizada pela Task 3

- [ ] **Step 5: Registrar os arquivos alterados para integracao**

Listar explicitamente os caminhos modificados no retorno do worker.

### Task 3: Atualizar documentacao funcional e memoria obrigatoria

**Files:**
- Modify: `docs/banco-de-dados.md`
- Modify: `.agents/project-memory/005-demais-telas-perfis.md`
- Modify: `.sauron/wiki/knowledge/module-data-schema.md`
- Optionally modify if houver contexto adicional: `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`
- Optionally modify: `.sauron/wiki/summary.json` somente se criar nova pagina

- [ ] **Step 1: Registrar a decisao de descontinuacao**

Documentar:
- avatar era campo morto e nao renderizado
- decisao aprovada: remover a feature, nao migrar para storage
- impacto no schema, UI e contratos

- [ ] **Step 2: Atualizar estado atual da documentacao**

Aplicar:
- remover `avatar_url` das tabelas/contratos atuais
- registrar que o shell usa apenas iniciais do nome
- registrar a migration que retira o campo

- [ ] **Step 3: Verificar necessidade de atualizar indices**

Run: `rg -n "avatar_url|foto de perfil|Avatar URL" docs .agents .sauron`

Expected:
- nenhuma referencia ativa contradizendo o estado atual

- [ ] **Step 4: Registrar os arquivos alterados para integracao**

Listar explicitamente os caminhos modificados no retorno do worker.

### Task 4: Integracao e verificacao final

**Files:**
- Review only: repo diff completo

- [ ] **Step 1: Revisar conflitos entre as tasks**

Confirmar que nao ha choque de ownership entre frontend, migration e docs.

- [ ] **Step 2: Rodar verificacoes finais**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx src/pages/RelatoriosPage.test.tsx`

Run: `npm run build`

Expected:
- testes direcionados verdes
- build verde

- [ ] **Step 3: Fazer uma busca final por residuos**

Run: `rg -n "avatar_url|Avatar URL" src supabase docs .agents .sauron`

Expected:
- sem referencias em codigo ativo

- [ ] **Step 4: Preparar resumo final com evidencias**

Reportar:
- migrations criadas
- arquivos alterados
- comandos rodados e resultado
