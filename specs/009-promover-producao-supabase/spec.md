# Feature Specification: Promover Producao Supabase

**Feature Branch**: `009-promover-producao-supabase`

**Created**: 2026-07-06

**Status**: Draft

**Input**: User description: "Deliberar e planejar a promocao do banco local validado para o projeto Supabase de producao lpwnaxlczwntylcmgotm, verificar Edge Functions em producao e, apos a subida validada, ajustar a configuracao local da aplicacao para apontar ao banco de producao."

## Clarifications

### Session 2026-07-06

- Q: O projeto `lpwnaxlczwntylcmgotm` e homologacao ou producao real? -> A: Producao real.
- Q: A promocao deve copiar dados locais ou apenas o schema validado? -> A: Promover o que foi validado e funcionando, preservando o escopo seguro: schema versionado, regras de seguranca, Storage, RPCs e Edge Functions; nao promover dados locais nem seed sem aprovacao explicita.
- Q: Quando a configuracao local deve apontar para producao? -> A: Somente apos a promocao do backend e a verificacao remota das Edge Functions.
- Q: Quais usuarios devem ser usados no smoke test remoto? -> A: Criar usuarios temporarios de validacao em producao e remove-los ou desativa-los apos o smoke test, pois ainda nao existem usuarios reais.
- Q: Qual gate deve existir entre a revisao previa e a aplicacao em producao? -> A: Parar apos o dry-run e aplicar em producao somente com aprovacao manual explicita.
- Q: Quando o arquivo `.env.local` deve ser atualizado para producao? -> A: Atualizar `.env.local` somente apos smoke test remoto aprovado.
- Q: Como tratar falha no smoke test remoto? -> A: Falha no smoke test bloqueia a troca de `.env.local` e exige correcao seguida de novo smoke test aprovado.
- Q: Qual salvaguarda deve existir antes de aplicar mudancas em producao? -> A: Exigir confirmacao de backup ou snapshot recuperavel antes do `db push`.
- Q: Qual evidencia minima fecha a confirmacao de backup/snapshot recuperavel? -> A: Registrar tipo de backup/snapshot, timestamp, origem da confirmacao, responsavel pela aprovacao e declaracao de recuperabilidade antes de qualquer `db push`.
- Q: Quais condicoes devem parar o fluxo por drift ou historico conflitante? -> A: Parar se houver target diferente, migration remota ausente localmente, migration local ja marcada de modo conflitante no remoto, dry-run com seed/dump/dado local, objeto fora do escopo aprovado, ou erro de autenticacao, permissao ou rede que impeça entender o estado remoto.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Promover backend validado para producao com revisao previa (Priority: P1)

Como responsavel pelo sistema, quero revisar exatamente o que sera aplicado em producao antes de qualquer mutacao, para reduzir risco de alteracoes inesperadas no ambiente real da empresa.

**Why this priority**: O destino e producao real. A promocao sem revisao previa pode comprometer acesso, autorizacao, dados operacionais ou disponibilidade.

**Independent Test**: Pode ser testada apresentando o estado remoto atual, a lista de mudancas pendentes e uma decisao explicita de continuar ou parar antes da primeira mutacao em producao.

**Acceptance Scenarios**:

1. **Given** o ambiente de producao informado, **When** a revisao previa e executada, **Then** o responsavel ve o destino, o estado de migracoes e as mudancas pendentes antes de aprovar a aplicacao.
2. **Given** a revisao previa com mudancas inesperadas, **When** o responsavel avalia o resultado, **Then** a promocao para e nenhuma mutacao e aplicada em producao.
3. **Given** a revisao previa com apenas mudancas esperadas, **When** o responsavel aprova manualmente continuar apos o dry-run, **Then** a promocao pode avancar para aplicacao controlada.

---

### User Story 2 - Validar exportacao remota antes de trocar configuracao local (Priority: P2)

Como responsavel pelo sistema, quero verificar em producao a capacidade de exportacao de relatorios antes de apontar a aplicacao local para o ambiente real, para evitar diagnosticar frontend contra um backend incompleto.

**Why this priority**: A feature 008 depende de schema, permissoes, armazenamento privado e funcao server-side. A configuracao local so deve mudar depois que esse conjunto estiver operacional em producao.

**Independent Test**: Pode ser testada criando usuarios temporarios de validacao em producao, usando um usuario autorizado para gerar ou baixar uma exportacao permitida, confirmando que outro usuario sem permissao continua bloqueado e removendo ou desativando esses usuarios ao final.

**Acceptance Scenarios**:

1. **Given** o backend promovido para producao, **When** um usuario autorizado executa o fluxo de exportacao remota, **Then** o sistema gera ou disponibiliza o arquivo conforme as regras da feature 008.
2. **Given** um usuario sem capacidade de exportacao, **When** tenta acionar o fluxo remoto, **Then** o sistema bloqueia a acao sem gerar arquivo.
3. **Given** falha na verificacao remota da exportacao, **When** a falha e registrada, **Then** a configuracao local permanece apontando para o ambiente anterior ate a causa ser resolvida.

---

### User Story 3 - Apontar configuracao local para producao apos validacao (Priority: P3)

Como desenvolvedor do projeto, quero atualizar a configuracao local da aplicacao para usar o ambiente de producao somente depois do backend validado, para testar a aplicacao real sem expor segredos privilegiados.

**Why this priority**: A troca de configuracao local e util para validacao final, mas deve acontecer depois da promocao e nunca deve incluir chaves privilegiadas.

**Independent Test**: Pode ser testada abrindo a aplicacao local apos a troca de configuracao e validando login, leitura inicial e fluxo de exportacao contra producao com credenciais permitidas.

**Acceptance Scenarios**:

1. **Given** smoke test remoto aprovado, **When** a configuracao local e atualizada, **Then** ela aponta para o ambiente de producao e usa apenas credenciais publicas apropriadas ao cliente.
2. **Given** a configuracao local atualizada, **When** a aplicacao e aberta localmente, **Then** login, leitura inicial e exportacao autorizada funcionam contra producao.
3. **Given** uma chave privilegiada disponivel para operacoes server-side, **When** a configuracao local do frontend e revisada, **Then** essa chave nao aparece em variaveis consumidas pelo navegador.

### Edge Cases

- O ambiente remoto ja possui migracoes aplicadas parcialmente e a lista local nao bate com a historia remota, incluindo migration remota ausente localmente ou migration local marcada de modo conflitante no remoto.
- A revisao previa mostra aplicacao de seed, dados locais ou objetos fora do escopo aprovado.
- A revisao previa nao consegue comprovar o destino por target diferente, erro de autenticacao, erro de permissao ou falha de rede.
- O dry-run mostra apenas mudancas esperadas, mas a aprovacao manual explicita ainda nao foi dada.
- A revisao previa esta aprovada, mas ainda nao ha confirmacao de backup ou snapshot recuperavel do ambiente de producao.
- A promocao do schema conclui, mas a funcao remota de exportacao nao fica disponivel.
- O armazenamento privado existe, mas as regras de acesso impedem download autorizado ou permitem acesso indevido.
- O usuario de smoke test nao existe ou nao possui a persona/capacidade necessaria em producao.
- Usuarios temporarios de smoke test sao criados, mas nao conseguem ser removidos ou desativados apos a validacao.
- A chave publica de producao esta incorreta ou pertence a outro projeto.
- A configuracao local e alterada antes da verificacao remota e precisa ser revertida.
- O smoke test remoto ainda nao foi aprovado, mas ha pressao para testar o frontend local contra producao.
- O smoke test remoto passa parcialmente, como login e leitura funcionando, mas exportacao ou bloqueio de usuario sem permissao falhando.
- A promocao e interrompida no meio por erro de credencial, rede ou permissao.
- Um teste de usuario sem permissao passa indevidamente e revela falha de autorizacao.
- A documentacao obrigatoria de mutacao em producao nao e atualizada apos a execucao.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O processo MUST tratar `lpwnaxlczwntylcmgotm` como ambiente de producao real e exigir confirmacao explicita do destino antes de qualquer mutacao.
- **FR-002**: O processo MUST apresentar o estado remoto de migracoes e a lista de mudancas pendentes antes da aplicacao em producao.
- **FR-003**: O processo MUST parar antes de mutar producao se a revisao previa mostrar mudancas inesperadas, conflito de historico, drift remoto, target diferente, falha que impeça entender o estado remoto ou aplicacao de dados fora do escopo.
- **FR-004**: A promocao MUST incluir apenas artefatos versionados e validados do backend: schema, regras de acesso, funcoes de negocio, armazenamento privado e funcoes server-side necessarias.
- **FR-005**: A promocao MUST NOT copiar dados locais, seed de desenvolvimento ou dump completo para producao sem aprovacao explicita separada.
- **FR-006**: A promocao MUST preservar as regras de autorizacao, privacidade de arquivos, ausencia de links publicos permanentes e separacao entre chaves publicas e privilegiadas.
- **FR-007**: O processo MUST verificar que a capacidade remota de exportacao de relatorios esta disponivel para usuario autorizado antes de alterar a configuracao local da aplicacao.
- **FR-008**: O processo MUST verificar que usuario sem capacidade de exportacao continua bloqueado em producao.
- **FR-009**: A configuracao local da aplicacao MUST ser atualizada para producao somente apos a promocao e smoke test remoto aprovados.
- **FR-010**: A configuracao local da aplicacao MUST conter apenas endpoint publico de producao, chave publica apropriada ao cliente e marcador de ambiente; nenhuma chave privilegiada pode ser exposta ao cliente.
- **FR-011**: O processo MUST registrar em documentacao de projeto a data, destino, escopo, resultado das verificacoes e qualquer decisao operacional relevante.
- **FR-012**: O processo MUST manter um caminho claro de parada ou reversao de configuracao local caso a verificacao remota falhe.
- **FR-013**: O processo MUST separar decisao, revisao previa, mutacao de producao, verificacao remota e troca de configuracao local como checkpoints distintos.
- **FR-014**: O smoke test remoto MUST usar usuarios temporarios de validacao criados em producao quando nao existirem usuarios reais aprovados.
- **FR-015**: Usuarios temporarios de validacao MUST ser removidos ou desativados apos o smoke test, e essa limpeza MUST ser registrada junto ao resultado operacional.
- **FR-016**: O processo MUST parar apos a revisao previa/dry-run e exigir aprovacao manual explicita antes de aplicar qualquer mudanca em producao.
- **FR-017**: O arquivo `.env.local` MUST permanecer apontando para o ambiente anterior ate que o smoke test remoto de producao esteja aprovado.
- **FR-018**: Qualquer falha no smoke test remoto MUST bloquear a troca de `.env.local` ate que a causa seja corrigida e um novo smoke test completo seja aprovado.
- **FR-019**: O processo MUST exigir confirmacao de backup ou snapshot recuperavel do ambiente de producao antes de aplicar mudancas de schema, registrando tipo de backup/snapshot, timestamp, origem da confirmacao, responsavel pela aprovacao e declaracao de recuperabilidade.

### Key Entities *(include if feature involves data)*

- **Ambiente de Producao**: Projeto remoto real que recebera o backend validado e servira a aplicacao em uso operacional.
- **Lote de Promocao**: Conjunto de mudancas versionadas aprovadas para producao em uma janela controlada.
- **Revisao Previa**: Evidencia apresentada antes da mutacao, contendo destino, estado remoto e mudancas pendentes.
- **Smoke Test Remoto**: Validacao minima em producao para confirmar exportacao autorizada, bloqueio nao autorizado e disponibilidade de arquivos.
- **Configuracao Local da Aplicacao**: Arquivo local de variaveis usado pelo frontend durante desenvolvimento ou validacao manual.
- **Registro Operacional**: Documentacao obrigatoria da mutacao, incluindo escopo, resultado e pendencias.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das mutacoes de producao sao precedidas por revisao previa do destino, estado remoto e mudancas pendentes.
- **SC-002**: 0 dados locais, seeds de desenvolvimento ou dumps completos sao promovidos para producao durante esta feature.
- **SC-003**: 100% das mudancas aplicadas em producao pertencem ao conjunto versionado e validado previamente no projeto.
- **SC-004**: Ao menos 1 fluxo remoto de exportacao autorizado e validado com sucesso antes da troca de configuracao local.
- **SC-005**: Ao menos 1 tentativa remota sem permissao e bloqueada com sucesso antes da troca de configuracao local.
- **SC-006**: 0 chaves privilegiadas aparecem na configuracao local consumida pelo frontend.
- **SC-007**: A aplicacao local consegue autenticar e abrir a experiencia inicial contra producao apos a troca de configuracao.
- **SC-008**: A documentacao obrigatoria em `.agents` e `.sauron` registra a mutacao em ate a mesma sessao de trabalho em que ela ocorrer.
- **SC-009**: Qualquer falha em promocao, funcao remota ou smoke test impede automaticamente a troca de configuracao local ate ser resolvida.
- **SC-010**: 100% dos usuarios temporarios criados para smoke test sao removidos ou desativados antes do encerramento da validacao operacional.
- **SC-011**: 0 mudancas sao aplicadas em producao antes de aprovacao manual explicita apos a revisao previa/dry-run.
- **SC-012**: 0 alteracoes em `.env.local` para producao ocorrem antes do smoke test remoto aprovado.
- **SC-013**: 100% das falhas de smoke test impedem a troca de `.env.local` ate uma nova validacao remota completa ser aprovada.
- **SC-014**: 0 mudancas de schema sao aplicadas em producao antes da confirmacao documentada de backup ou snapshot recuperavel com tipo, timestamp, origem, responsavel e declaracao de recuperabilidade.

## Assumptions

- A feature 008 de exportacao de relatorios ja foi validada localmente pelos testes definidos em sua propria especificacao.
- O projeto remoto `lpwnaxlczwntylcmgotm` e o destino correto de producao.
- A promocao inicial nao deve semear usuarios, perfis ou dados de teste em producao.
- A verificacao remota usara usuarios temporarios criados especificamente para smoke test, com ao menos um perfil autorizado e um perfil sem permissao de exportacao.
- A configuracao local da aplicacao pode ser alterada depois da verificacao, mas arquivos com segredos privilegiados continuam fora do frontend.
- A documentacao em `.agents` e `.sauron` e obrigatoria para toda mutacao de estado, conforme instrucao do repositorio.
