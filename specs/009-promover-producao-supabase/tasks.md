# Tarefas: Promover Producao Supabase

**Entrada**: Artefatos de desenho em `specs/009-promover-producao-supabase/`

**Pre-requisitos**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/`

**Testes**: Esta feature e um workflow operacional de promocao. As tarefas de teste sao obrigatorias porque a spec define validacao local, revisao de dry-run, smoke test remoto e validacao local contra producao como gates de conclusao.

**Organizacao**: As tarefas estao agrupadas por user story para que cada incremento operacional tenha um ponto independente de parada e validacao. Tarefas que podem mutar producao sao intencionalmente sequenciais e bloqueadas por gates explicitos.

## Formato: `[ID] [P?] [Story] Descricao`

- **[P]**: Pode rodar em paralelo porque toca arquivos diferentes ou produz evidencia independente.
- **[Story]**: Label da user story em `spec.md` (`US1`, `US2`, `US3`).
- Toda tarefa indica o arquivo onde a evidencia, configuracao ou documentacao deve ser atualizada.

## Fase 1: Setup (Preparacao Operacional Compartilhada)

**Objetivo**: Preparar evidencias locais, confirmar escopo e deixar o registro de promocao pronto antes de qualquer comando de producao.

- [ ] T001 Confirmar os artefatos ativos da feature e registrar o caminho resolvido do plano em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T002 Confirmar que `requirements.md` e `plan-quality.md` estao 100% marcados e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T003 [P] Inventariar os arquivos locais de migration em `supabase/migrations/` e registrar o escopo esperado de promocao de schema em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T004 [P] Inventariar os arquivos da Edge Function em `supabase/functions/relatorios-exportacao/` e registrar o escopo esperado de promocao da funcao em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T005 [P] Capturar o destino atual de `.env.local`, criar copia local segura para rollback em `C:\tmp\sistema-aptus-009-env-local.backup` sem registrar valores secretos em docs/chat, e registrar apenas a identidade nao secreta do ambiente em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T006 Confirmar o destino de producao `lpwnaxlczwntylcmgotm` e a API URL `https://lpwnaxlczwntylcmgotm.supabase.co` em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T007 Criar o esqueleto do registro de execucao com os campos de `contracts/documentation-and-recovery.md` em `.agents/project-memory/009-promover-producao-supabase.md`.

---

## Fase 2: Fundacional (Pre-requisitos Bloqueantes)

**Objetivo**: Completar todos os gates locais e pre-mutacao. Nenhuma tarefa de user story pode iniciar antes da conclusao desta fase.

- [ ] T008 Executar `supabase --version` e `supabase --help`, depois registrar a versao do CLI e a disponibilidade dos comandos em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T009 Executar `npm run db:test` e registrar o resultado de saida em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T010 Executar `npm run test` e registrar o resultado de saida em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T011 Executar `npm run build` e registrar o resultado de saida em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T012 Executar `npm run audit` e registrar o resultado de saida em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T013 Confirmar que a evidencia de backup/snapshot contem tipo, timestamp, origem da confirmacao, responsavel pela aprovacao e declaracao de recuperabilidade em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T014 Parar o workflow se qualquer validacao local ou evidencia de backup/snapshot estiver ausente e documentar o checkpoint bloqueado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T015 Espelhar o resumo de evidencias pre-mutacao em `.sauron/wiki/knowledge/architecture.md`.

**Checkpoint**: Validacao local e evidencia de backup completas. A inspecao de producao pode comecar; mutacao em producao continua bloqueada.

---

## Fase 3: User Story 1 - Promover backend validado para producao com revisao previa (Prioridade: P1)

**Objetivo**: Apresentar destino, estado remoto de migrations e mudancas pendentes de schema antes de qualquer mutacao em producao, aplicando schema somente apos aprovacao explicita.

**Teste independente**: O responsavel consegue ver destino, evidencia de backup, estado de migrations, saida do dry-run e decisao de aprovacao pos-dry-run antes de qualquer mutacao de schema.

### Testes Operacionais da User Story 1

- [ ] T016 [US1] Executar `supabase link --project-ref lpwnaxlczwntylcmgotm` e registrar a confirmacao do destino em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T017 [US1] Executar `supabase migration list` e registrar o estado local/remoto de migrations em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T018 [US1] Comparar o historico remoto de migrations com `supabase/migrations/` e documentar qualquer migration apenas remota, ausente, reordenada ou conflitante em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T019 [US1] Parar o workflow se o destino divergir, o historico de migrations conflitar, houver drift remoto ou falha de autenticacao/permissao/rede impedir revisao confiavel; documentar o motivo da parada em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T020 [US1] Executar `supabase db push --dry-run` e registrar o resumo completo revisado do dry-run em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T021 [US1] Revisar a saida do dry-run em busca de seed, dump, operacoes data-local ou objetos fora de schema, regras de acesso, Storage privado, RPCs e `relatorios-exportacao`, depois registrar a decisao em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T022 [US1] Parar apos o dry-run e capturar aprovacao ou rejeicao manual explicita em `.agents/project-memory/009-promover-producao-supabase.md`.

### Implementacao da User Story 1

- [ ] T023 [US1] Se e somente se T022 registrar aprovacao, executar `supabase db push` sem flags de seed e registrar o resumo das migrations aplicadas em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T024 [US1] Se a aplicacao de schema falhar, parar o workflow e registrar o ultimo checkpoint bem-sucedido e a proxima acao de recuperacao em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T025 [US1] Espelhar o resultado da US1, incluindo checkpoint de aprovacao e resultado da aplicacao de schema, em `.sauron/wiki/knowledge/architecture.md`.

**Checkpoint**: Promocao de schema aplicada e documentada, ou parada com acao de recuperacao documentada.

---

## Fase 4: User Story 2 - Validar exportacao remota antes de trocar configuracao local (Prioridade: P2)

**Objetivo**: Publicar e validar `relatorios-exportacao` em producao, depois provar exportacao autorizada, bloqueio nao autorizado, privacidade do arquivo e limpeza de usuarios temporarios.

**Teste independente**: Um usuario temporario autorizado consegue gerar/baixar uma exportacao permitida, um usuario temporario nao autorizado e bloqueado, o acesso ao arquivo nao depende de URL publica permanente e todos os usuarios temporarios sao removidos ou desativados.

### Testes Operacionais da User Story 2

- [ ] T026 [US2] Deployar `relatorios-exportacao` com `supabase functions deploy relatorios-exportacao --project-ref lpwnaxlczwntylcmgotm` e registrar o resultado do deploy em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T027 [US2] Verificar por evidencia aceitavel que a funcao publicada mantem verificacao JWT habilitada (`verify_jwt` nao desabilitado em config/deploy/Dashboard ou evidencia equivalente) e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T028 [US2] Executar `supabase secrets list --project-ref lpwnaxlczwntylcmgotm` sem copiar valores e registrar apenas presenca/ausencia dos secrets obrigatorios em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T029 [US2] Parar o workflow se o deploy da funcao ou a verificacao dos secrets obrigatorios falhar e registrar o checkpoint bloqueado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T030 [US2] Criar ou preparar um usuario temporario de producao autorizado com capacidade `relatorios.exportar` (ex.: Administrador, Financeiro ou Projetos conforme categoria validada) e registrar seu identificador nao secreto, persona/capacidade e finalidade em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T031 [US2] Criar ou preparar um usuario temporario de producao sem capacidade `relatorios.exportar` (ex.: Visualizador, Comercial ou Tecnico) e registrar seu identificador nao secreto, persona/capacidade ausente e finalidade em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T032 [US2] Validar ST-001, exportacao autorizada contra producao, medir a duracao do fluxo e confirmar limite de ate 10 segundos para volume comum, registrando resultado e duracao em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T033 [US2] Validar ST-002, bloqueio de exportacao/download nao autorizado contra producao, e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T034 [US2] Validar ST-003, acesso privado ao arquivo sem URL publica permanente, e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T035 [US2] Remover ou desativar todos os usuarios temporarios de smoke test e registrar o resultado da limpeza em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T036 [US2] Parar o workflow se qualquer cenario de smoke ou limpeza falhar e registrar a acao de recuperacao em `.agents/project-memory/009-promover-producao-supabase.md`.

### Implementacao da User Story 2

- [ ] T037 [US2] Marcar o smoke test remoto como aprovado somente se ST-001, ST-002, ST-003 e limpeza passarem em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T038 [US2] Espelhar resultados de Edge Function, secrets, smoke test e limpeza em `.sauron/wiki/knowledge/architecture.md`.

**Checkpoint**: Fluxo remoto de exportacao aprovado e usuarios temporarios limpos, ou `.env.local` permanece bloqueado com acao de recuperacao documentada.

---

## Fase 5: User Story 3 - Apontar configuracao local para producao apos validacao (Prioridade: P3)

**Objetivo**: Trocar `.env.local` para producao somente apos aprovacao do smoke remoto, depois validar a aplicacao local contra producao sem expor segredos privilegiados.

**Teste independente**: A aplicacao local autentica contra producao, a rota inicial autorizada carrega, a exportacao autorizada funciona e nenhuma chave privilegiada aparece em variaveis consumidas pelo frontend.

### Testes Operacionais da User Story 3

- [ ] T039 [US3] Confirmar aprovacao do smoke da US2 e limpeza de usuarios temporarios antes de tocar em `.env.local`, depois registrar o resultado do gate em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T040 [US3] Confirmar a origem da chave publica/anon de producao sem copiar valores privilegiados para docs e registrar a origem em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T041 [US3] Atualizar `.env.local` com `VITE_SUPABASE_URL=https://lpwnaxlczwntylcmgotm.supabase.co`, chave publica anon de producao e `VITE_APP_ENV=production`.
- [ ] T042 [US3] Inspecionar `.env.local` em busca de valores proibidos (`service_role`, secret key, senha de banco, personal access token, project management token, secret privado de Edge Function) e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T043 [US3] Executar `npm run dev` e validar autenticacao local contra producao, depois registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T044 [US3] Validar a tela inicial autorizada contra producao e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T045 [US3] Validar exportacao autorizada de relatorio a partir da aplicacao local contra producao e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T046 [US3] Validar que o comportamento de exportacao nao autorizada continua bloqueado contra producao e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.

### Implementacao da User Story 3

- [ ] T047 [US3] Se qualquer validacao local falhar, restaurar `.env.local` a partir de `C:\tmp\sistema-aptus-009-env-local.backup`, sem registrar valores secretos em docs/chat, e documentar o rollback em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T048 [US3] Se toda a validacao local passar, registrar o resultado da troca de `.env.local` em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T049 [US3] Espelhar troca de `.env.local`, validacao local e qualquer rollback em `.sauron/wiki/knowledge/architecture.md`.

**Checkpoint**: Configuracao local aponta para producao e esta validada, ou foi revertida e a feature permanece incompleta.

---

## Fase 6: Polish e Preocupacoes Transversais

**Objetivo**: Fechar rastreabilidade, postura de recuperacao e higiene do repositorio.

- [ ] T050 Reconciliar todos os campos obrigatorios de `contracts/documentation-and-recovery.md` em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T051 Reconciliar todas as atualizacoes obrigatorias de arquitetura/historico em `.sauron/wiki/knowledge/architecture.md`.
- [ ] T052 Verificar que `specs/009-promover-producao-supabase/checklists/requirements.md` continua totalmente marcado e registrar a contagem final em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T053 Verificar que `specs/009-promover-producao-supabase/checklists/plan-quality.md` continua totalmente marcado e registrar a contagem final em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T054 Revisar `git diff` de `.agents/project-memory/009-promover-producao-supabase.md` e `.sauron/wiki/knowledge/architecture.md`, inspecionar `.env.local` diretamente por padroes proibidos e registrar que nenhum segredo foi exposto.
- [ ] T055 Executar os comandos finais de verificacao exigidos pelo ultimo checkpoint bem-sucedido e registrar o resultado em `.agents/project-memory/009-promover-producao-supabase.md`.
- [ ] T056 Documentar qualquer acao pendente, rollback ou checkpoint bloqueado restante em `.agents/project-memory/009-promover-producao-supabase.md`.

---

## Dependencias e Ordem de Execucao

### Dependencias por Fase

- **Setup (Fase 1)**: Sem dependencias; pode iniciar imediatamente.
- **Fundacional (Fase 2)**: Depende da conclusao do Setup e bloqueia todas as user stories.
- **US1 (Fase 3)**: Depende da conclusao da fase Fundacional. Mutacao em producao fica bloqueada ate T022 registrar aprovacao manual explicita.
- **US2 (Fase 4)**: Depende de sucesso na aplicacao de schema da US1.
- **US3 (Fase 5)**: Depende de aprovacao do smoke da US2 e limpeza dos usuarios temporarios.
- **Polish (Fase 6)**: Depende do checkpoint alcancado; se o workflow parar antes do fim, a fase registra o estado bloqueado e a acao de recuperacao.

### Dependencias por User Story

- **User Story 1 (P1)**: MVP. Estabelece destino de producao, dry-run, aprovacao e promocao de schema.
- **User Story 2 (P2)**: Requer promocao de schema da US1 porque a Edge Function depende de RPCs, Storage e regras de acesso.
- **User Story 3 (P3)**: Requer aprovacao do smoke remoto da US2 antes de `.env.local` apontar para producao.

### Ordem dos Gates

1. Validacao local e evidencia de backup.
2. Revisao de destino e estado de migrations.
3. Revisao de dry-run.
4. Aprovacao manual apos dry-run.
5. Aplicacao de schema.
6. Deploy da Edge Function e verificacao de secrets.
7. Smoke test remoto e limpeza de usuarios temporarios.
8. Troca de `.env.local`.
9. Validacao da aplicacao local contra producao.
10. Documentacao final.

---

## Oportunidades de Paralelismo

- T003, T004 e T005 podem rodar em paralelo durante o setup porque inspecionam artefatos locais diferentes.
- A reconciliacao documental em T050 e T051 pode ser preparada em paralelo depois que o resultado operacional for conhecido, mas ambas devem refletir o mesmo checkpoint final.
- A maioria das tarefas voltadas a producao e intencionalmente sequencial porque cada gate depende da evidencia anterior.

## Exemplo Paralelo: Setup

```text
Tarefa: "T003 Inventariar arquivos locais de migration em supabase/migrations/"
Tarefa: "T004 Inventariar arquivos da Edge Function em supabase/functions/relatorios-exportacao/"
Tarefa: "T005 Capturar o destino atual de .env.local e criar backup local seguro sem registrar valores secretos"
```

---

## Estrategia de Implementacao

### MVP Primeiro (Somente User Story 1)

1. Concluir Fase 1 e Fase 2.
2. Concluir US1 ate a revisao de dry-run.
3. Parar em T022 para aprovacao manual explicita.
4. Aplicar schema somente se T022 registrar aprovacao.
5. Documentar sucesso de schema ou estado bloqueado/recuperacao.

### Entrega Incremental

1. US1: promover schema com gates de revisao, backup e aprovacao manual.
2. US2: deployar e validar `relatorios-exportacao` com usuarios temporarios.
3. US3: trocar `.env.local` somente apos aprovacao do smoke remoto.
4. Polish: reconciliar documentacao e verificacoes finais.

### Regras de Seguranca

- Nao executar `supabase db push` antes de T022 registrar aprovacao manual explicita.
- Nao incluir seed, dump ou promocao de dados locais em nenhuma tarefa.
- Nao expor service role, secret key, senha de banco ou management token em `.env.local`, docs ou chat.
- Nao marcar a feature como completa enquanto usuarios temporarios de smoke test permanecerem ativos sem intencao.
- Nao atualizar `.env.local` ate que o smoke test remoto e a limpeza da US2 tenham passado.
