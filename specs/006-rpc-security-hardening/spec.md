# Feature Specification: Hardening de Segurança das RPCs e Padronização Retroativa do Banco

**Feature Branch**: `006-rpc-security-hardening`

**Created**: 2026-07-02

**Status**: Draft

**Input**: User description: "Hardening de segurança das RPCs e padronização retroativa do banco (Supabase/Postgres)."

## Contexto e Motivação

Uma auditoria conduzida em 2026-07-02 sobre as 20 migrations do banco (81 funções: 79 RPCs + 2 triggers) revelou duas gerações de código com padrões de segurança divergentes:

- **Geração nova** (migrations `20260701*` / `20260702*`: financeiro, comercial, equipe, relatórios, configurações): já segue o padrão completo de guardrails — função com privilégio elevado, escopo de busca de schema fixo, checagem de permissão de módulo no corpo, revogação de execução do público geral e concessão explícita apenas a usuários autenticados.
- **Geração antiga** (batch `20260628*`: clientes, projetos, tarefas, dashboard; e o arquivo base de usuários/perfis): 26 funções fora do padrão — sem escopo de busca fixo, sem revogação de execução e sem concessão explícita.

A auditoria confirmou que o sistema **já é orientado a RPC** (78 chamadas de RPC nos serviços contra 1 única consulta direta a tabela, esta legítima), portanto o valor desta feature está em **fechar brechas de segurança e uniformizar o padrão**, não em refatorar a arquitetura de leitura.

Duas das 26 funções antigas têm falhas **exploráveis** (uma delas por chamador anônimo), tratadas como prioridade máxima.

Esta avaliação também **rejeitou formalmente** uma proposta anterior de migrar para "1 RPC agregadora por página": ela não fecha nenhuma brecha de segurança e traz custo e risco altos. A decisão fica registrada como diretriz arquitetural (ver User Story 5).

## Clarifications

### Session 2026-07-02

- Q: Como a função de auditoria deve tratar eventos legítimos de pré-autenticação (ex.: falha de login, que é registrada sem sessão)? → A: Permitir chamador anônimo **apenas** para uma lista fixa de eventos de segurança pré-autenticação (ex.: `login_falha`), sempre com autor nulo; para chamador autenticado, forçar o autor como a identidade da sessão e ignorar qualquer autor recebido por parâmetro; rejeitar eventos fora da lista quando o chamador for anônimo.
- Q: O que fazer com o parâmetro de autor (`p_usuario_id`) da função de auditoria, agora irrelevante? → A: Remover o parâmetro da assinatura e ajustar os 3 pontos de chamada no cliente (falha de login, sucesso de login, senha alterada), tornando a falsificação de autor impossível por construção.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Eliminar a criação anônima de administradores (Priority: P1)

Existe uma função de conveniência para criar perfis de teste que roda com privilégio elevado e está exposta ao público geral. Sua guarda de autorização só barra usuários autenticados sem perfil de administrador; um **chamador anônimo passa direto** e consegue criar um usuário Administrador com senha arbitrária diretamente na tabela de autenticação. Esta é a vulnerabilidade mais grave do sistema.

**Why this priority**: É uma escalação de privilégio total e não autenticada — o pior tipo de falha possível. Precisa ser fechada antes de qualquer outra coisa. A decisão do responsável é **remover a função de produção**.

**Independent Test**: Após a correção, verificar que a função não existe no ambiente de produção e que uma tentativa de chamá-la (anônima ou autenticada) falha; e que o processo de preparação do banco local (reset/seed) continua criando os usuários de teste normalmente.

**Acceptance Scenarios**:

1. **Given** um chamador anônimo, **When** ele tenta invocar a função de criação de perfil de teste em produção, **Then** a chamada falha porque a função não existe.
2. **Given** o ambiente de desenvolvimento local, **When** o banco é resetado e populado, **Then** os usuários de teste dos 6 perfis são criados com sucesso sem depender de nenhuma função exposta em produção.

---

### User Story 2 - Impedir falsificação da trilha de auditoria (Priority: P1)

A função que registra eventos de auditoria roda com privilégio elevado, está exposta ao público geral e não faz nenhuma verificação de identidade. Além de permitir que um anônimo insira eventos arbitrários, ela aceita o identificador do autor como parâmetro, o que permite **atribuir um evento a qualquer outro usuário** — corrompendo a confiabilidade da trilha de auditoria. A correção deve preservar o registro de eventos legítimos de pré-autenticação (notadamente a falha de login, que por natureza ocorre sem sessão) sem reabrir a brecha de falsificação.

**Why this priority**: Uma trilha de auditoria falsificável é pior que nenhuma trilha, pois cria falsa confiança. Corrigir é pré-requisito para qualquer uso da auditoria como evidência.

**Independent Test**: Verificar que um chamador anônimo só consegue registrar eventos de uma lista fixa de segurança pré-autenticação (com autor nulo) e é rejeitado para qualquer outro evento; que um chamador autenticado só consegue registrar eventos atribuídos a si mesmo (o autor gravado é sempre a identidade da sessão, nunca um parâmetro); e que os pontos de chamada no cliente continuam funcionando.

**Acceptance Scenarios**:

1. **Given** um chamador anônimo, **When** ele registra um evento da lista fixa de pré-autenticação (ex.: falha de login), **Then** o evento é gravado com autor nulo.
2. **Given** um chamador anônimo, **When** ele tenta registrar um evento fora da lista de pré-autenticação, **Then** a operação é rejeitada.
3. **Given** um usuário autenticado, **When** ele registra um evento e tenta atribuí-lo a outro usuário, **Then** o evento é gravado com a identidade do próprio autor, ignorando o identificador fornecido.

---

### User Story 3 - Impedir escalação de privilégio no cadastro (Priority: P1)

O gatilho de sincronização que cria o perfil de um novo usuário lê o nível de acesso a partir de metadados editáveis pelo próprio usuário no momento do cadastro. Se o cadastro público estiver habilitado, um usuário pode se autoconceder o perfil de Administrador ao se registrar.

**Why this priority**: É uma escalação de privilégio no ponto de entrada do sistema. A regra oficial da plataforma é nunca derivar autorização de metadados editáveis pelo usuário.

**Independent Test**: Simular um cadastro em que os metadados do usuário declaram um nível de acesso privilegiado e verificar que o perfil resultante é sempre o de menor privilégio (Visualizador). Verificar que dados não-sensíveis (nome, departamento) continuam sendo aproveitados do cadastro.

**Acceptance Scenarios**:

1. **Given** um cadastro cujos metadados declaram nível de acesso "Administrador", **When** o perfil é criado, **Then** o nível de acesso atribuído é "Visualizador".
2. **Given** um usuário já cadastrado, **When** um administrador o promove pela função administrativa apropriada, **Then** a promoção é aplicada — este é o único caminho válido de elevação de perfil.
3. **Given** um cadastro com nome e departamento informados, **When** o perfil é criado, **Then** nome e departamento são preservados (não são dados de autorização).

---

### User Story 4 - Padronizar as 26 funções legadas sem quebrar o cliente (Priority: P2)

As 26 funções da geração antiga precisam ser alinhadas ao padrão de guardrails da geração nova, **sem alterar assinatura nem comportamento observável** — ou seja, sem exigir nenhuma mudança no código cliente. Além dos itens exploráveis já tratados, isto inclui as funções de clientes, projetos, tarefas, dashboard e as funções base de permissão/perfil.

**Why this priority**: Fecha a dívida de padrão que originou as falhas exploráveis e elimina o risco latente de escopo de busca de schema não fixado em funções com privilégio elevado. É amplo, porém de baixo risco, por não mudar contrato.

**Independent Test**: Para cada uma das 26 funções, verificar que passou a ter escopo de busca fixo, revogação de execução do público geral, concessão explícita a autenticados e uma guarda explícita de identidade; e que as telas correspondentes (clientes, projetos, dashboard) continuam funcionando sem alteração no cliente.

**Acceptance Scenarios**:

1. **Given** qualquer uma das 26 funções legadas, **When** inspecionada, **Then** ela apresenta escopo de busca fixo, execução revogada do público geral, execução concedida a autenticados e guarda de identidade explícita.
2. **Given** um chamador anônimo, **When** invoca qualquer função legada, **Then** recebe erro de não-autorizado explícito (e não um resultado vazio silencioso).
3. **Given** as telas de clientes, projetos e dashboard, **When** usadas por um perfil com permissão, **Then** funcionam identicamente ao comportamento anterior à padronização.

---

### User Story 5 - Travar o padrão contra regressões futuras (Priority: P2)

Uma nova função fora do padrão não deve conseguir entrar no sistema sem ser detectada. É necessário automação que verifique o padrão de guardrails, proíba consultas diretas a tabelas na camada de serviço (salvo a exceção legítima), proíba o uso de metadados editáveis pelo usuário em decisões de autorização, e uma suíte de testes de banco que valide o comportamento por perfil de acesso.

**Why this priority**: Sem trava automática, a divergência entre gerações se repete. É o que sustenta o ganho de segurança ao longo do tempo. Depende das correções P1/P2 estarem aplicadas para passar em verde.

**Independent Test**: Introduzir deliberadamente uma função sem os guardrails e verificar que a verificação automática falha; introduzir uma consulta direta a tabela num serviço de domínio e verificar que é bloqueada; rodar a suíte de testes de banco e confirmar cobertura dos 6 perfis.

**Acceptance Scenarios**:

1. **Given** uma função com privilégio elevado sem guarda de identidade, **When** a verificação automática de guardrails roda, **Then** ela falha e aponta a função.
2. **Given** uma consulta direta a tabela adicionada a um serviço de domínio, **When** a verificação automática roda, **Then** ela falha (exceto para o arquivo de verificação de saúde, que está na lista de exceções).
3. **Given** a suíte de testes de banco, **When** executada, **Then** cobre: anônimo recebe não-autorizado em toda função com privilégio elevado (guiado pelo catálogo do banco, não por lista manual); usuário sem permissão de módulo recebe proibido; escrita sem permissão de escrita falha; matriz de comportamento para os 6 perfis; e regressão do cadastro que tenta autoconceder Administrador.

---

### User Story 6 - Registrar as diretrizes arquiteturais (Priority: P3)

As decisões de arquitetura tomadas nesta avaliação precisam ficar documentadas para orientar trabalho futuro e evitar retomar propostas já descartadas.

**Why this priority**: É documentação, não código executável. Importante para consistência futura, mas não bloqueia segurança.

**Independent Test**: Verificar que o documento de diretrizes existe e cobre: RPCs granulares como regra; agregadora por página descartada do caminho crítico e permitida só por latência medida; views apenas como modelos de leitura internos não expostos ao frontend; e RLS por operação como defesa em profundidade com suas armadilhas conhecidas.

**Acceptance Scenarios**:

1. **Given** um desenvolvedor futuro considerando agregar RPCs por página, **When** consulta as diretrizes, **Then** encontra a decisão registrada, a justificativa e a única condição sob a qual a agregação é permitida.

---

### Edge Cases

- **Reset do banco local**: remover a função de criação de perfil de teste não pode quebrar o fluxo de preparação local. A definição deve viver apenas no processo de seed (criada, usada e descartada ali), nunca persistida em produção.
- **Pontos de chamada da auditoria no cliente**: se a assinatura da função de registro de auditoria mudar (remoção do parâmetro de autor), todos os pontos de chamada precisam ser localizados e ajustados; caso contrário, o registro de eventos quebra silenciosamente.
- **Guarda explícita vs. bloqueio indireto**: hoje o bloqueio de anônimo nas funções legadas é um efeito colateral de a checagem de permissão retornar vazio. Ao introduzir a guarda explícita de identidade, é preciso garantir que nenhum fluxo legítimo dependa do comportamento silencioso anterior.
- **Funções futuras esquecidas**: o teste de "anônimo recebe não-autorizado" deve ser guiado pelo catálogo do banco, para que uma função nova criada sem guarda seja automaticamente coberta e reprovada.
- **Armadilha de política de atualização**: uma política de atualização de linha sem verificação de escrita permitiria reatribuir a posse de um registro a outro usuário; e uma atualização sem política de leitura correspondente falha silenciosamente sem alterar linhas.

## Requirements *(mandatory)*

### Functional Requirements

**Correções críticas (Fase 0)**

- **FR-001**: O sistema MUST remover a função de criação de perfil de teste do banco de produção, de modo que ela não exista em nenhum ambiente publicado.
- **FR-002**: O processo de preparação do banco local MUST continuar criando os usuários de teste dos 6 perfis sem depender de qualquer função exposta em produção (definição efêmera restrita ao seed).
- **FR-003**: A função de registro de eventos de auditoria MUST, para chamador autenticado, gravar sempre a identidade da sessão como autor do evento, ignorando qualquer identificador de autor recebido por parâmetro.
- **FR-003a**: A função de registro de eventos de auditoria MUST permitir chamador anônimo apenas para uma lista fixa de eventos de segurança pré-autenticação (no mínimo a falha de login), gravando-os com autor nulo, e MUST rejeitar qualquer outro evento quando o chamador for anônimo.
- **FR-003b**: A função de registro de eventos de auditoria MUST remover o parâmetro de identificador de autor da sua assinatura, e os pontos de chamada no cliente (falha de login, sucesso de login e senha alterada) MUST ser ajustados para não mais informar o autor.
- **FR-004**: O gatilho de sincronização de usuários MUST atribuir o perfil de menor privilégio (Visualizador) a todo novo usuário, sem exceção, ignorando qualquer nível de acesso presente em metadados editáveis pelo usuário.
- **FR-005**: A elevação de perfil de um usuário MUST ocorrer exclusivamente pela função administrativa dedicada, disponível apenas a administradores.
- **FR-006**: O gatilho de sincronização MAY preservar dados não-sensíveis do cadastro (nome, departamento), por não constituírem autorização.
- **FR-007**: A função de verificação de existência de administrador MUST ter sua execução revogada do público geral e concedida apenas a usuários autenticados.

**Padronização retroativa (Fase 1)**

- **FR-008**: Todas as 26 funções da geração antiga MUST passar a ter escopo de busca de schema fixado.
- **FR-009**: Todas as 26 funções MUST ter a execução revogada do público geral e concedida explicitamente apenas a usuários autenticados.
- **FR-010**: Todas as 26 funções MUST conter uma guarda explícita que rejeita chamadores sem identidade autenticada com um erro de não-autorizado.
- **FR-011**: A padronização MUST NOT alterar a assinatura nem o comportamento observável de nenhuma das funções, de modo a não exigir qualquer mudança no código cliente.

**Verificação automatizada e testes (Fases 2 e 3)**

- **FR-012**: O sistema MUST prover uma verificação automática que reprova qualquer função com privilégio elevado que não apresente o conjunto completo de guardrails (privilégio elevado declarado, escopo de busca fixo, checagem de permissão quando aplicável, execução revogada do público geral, execução concedida a autenticados).
- **FR-013**: O sistema MUST prover uma verificação automática que reprova consultas diretas a tabelas na camada de serviço de domínio, com uma lista de exceções explícita (verificação de saúde).
- **FR-014**: O sistema MUST prover uma verificação automática que reprova o uso de metadados editáveis pelo usuário em lógica de autorização, tanto no banco quanto no cliente.
- **FR-015**: O sistema MUST prover uma suíte de testes de banco que valide, por perfil de acesso (Administrador, Gestor, Financeiro, Comercial, Técnico, Visualizador): rejeição de anônimo em toda função com privilégio elevado; rejeição por falta de permissão de módulo; falha de escrita sem permissão de escrita; e a regressão de autoconcessão de perfil no cadastro.
- **FR-016**: O teste de rejeição de anônimo MUST ser guiado pelo catálogo do banco (enumerando as funções existentes) e não por uma lista mantida manualmente, aplicando uma lista de exceções explícita e mínima para as funções legitimamente chamáveis por anônimo (a função de auditoria, restrita à sua lista fixa de eventos de pré-autenticação).
- **FR-017**: O pipeline de integração contínua MUST executar, em sequência, a compilação do projeto, os testes automatizados, a verificação de qualidade do schema, os avisos de segurança nativos da plataforma e os scripts de auditoria, e MUST bloquear a integração se qualquer etapa falhar.

**Diretrizes arquiteturais (Fase 4)**

- **FR-018**: O sistema MUST registrar, em documento de diretrizes, que RPCs granulares são a regra para leitura e escrita, e que a agregação de múltiplas leituras em uma RPC por página está descartada do caminho crítico.
- **FR-019**: O documento MUST estabelecer que a agregação por página só é permitida pontualmente quando justificada por latência medida.
- **FR-020**: O documento MUST estabelecer que views servem apenas como modelos de leitura internos não expostos ao frontend e que a RLS por operação é mantida como defesa em profundidade, registrando as armadilhas conhecidas de políticas de atualização.

### Key Entities *(include if feature involves data)*

- **Função de banco com privilégio elevado (RPC)**: unidade de acesso a dados invocada pelo cliente. Atributos de segurança relevantes: nível de privilégio, escopo de busca de schema, presença de checagem de permissão, e concessões de execução.
- **Perfil de acesso**: nível de autorização de um usuário (Administrador, Gestor, Financeiro, Comercial, Técnico, Visualizador). Deriva de fonte confiável, nunca de metadados editáveis pelo usuário.
- **Evento de auditoria**: registro de uma ação relevante, com autor (sempre a identidade da sessão), tipo de evento e origem.
- **Permissão de módulo**: par de capacidades (ler / escrever) que um perfil possui sobre uma área funcional do sistema.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nenhuma função com privilégio elevado é executável por um chamador anônimo sem rejeição explícita de não-autorizado, salvo a única exceção documentada da função de auditoria restrita à sua lista fixa de eventos de pré-autenticação (exatamente 1 exceção catalogada).
- **SC-002**: A função de criação de perfil de teste não existe em nenhum ambiente de produção.
- **SC-003**: 100% das 81 funções do banco passam no script de auditoria de guardrails.
- **SC-004**: É impossível gravar um evento de auditoria atribuído a um usuário diferente do autor autenticado da sessão.
- **SC-005**: Um cadastro que tenta autoconceder qualquer perfil diferente de Visualizador resulta, em 100% dos casos, no perfil Visualizador.
- **SC-006**: A suíte de testes de banco passa em verde cobrindo os 6 perfis de acesso.
- **SC-007**: A introdução deliberada de uma função fora do padrão, ou de uma consulta direta a tabela num serviço de domínio, é reprovada pela integração contínua antes da integração.
- **SC-008**: A padronização das 26 funções legadas não exige nenhuma alteração no código cliente (0 pontos de chamada modificados por conta da Fase 1).

## Assumptions

- O cadastro público de usuários pode estar habilitado; portanto, a escalação via metadados é tratada como ameaça real e não apenas teórica.
- A fonte confiável de autorização é a tabela de perfis do sistema, consultada pela cadeia de funções de permissão já existente — não os metadados do provedor de autenticação.
- A remoção da função de criação de perfil de teste é a decisão final do responsável (confirmada), preferida sobre apenas adicionar guardas.
- A plataforma oferece um mecanismo nativo de avisos de segurança do schema, distinto da verificação de qualidade/lint, e ambos serão usados na integração contínua.
- A camada de serviço de domínio é o local onde consultas diretas a tabela devem ser proibidas; o arquivo de verificação de saúde é a única exceção legítima atual.
- Os testes de banco usam o mecanismo de testes de schema da própria plataforma, executáveis localmente e na integração contínua.
- A padronização das 26 funções preserva assinaturas; qualquer necessidade de mudança de assinatura (como na função de auditoria) é tratada explicitamente como parte das correções críticas, com ajuste dos pontos de chamada.

## Out of Scope

- Refatoração da arquitetura de leitura para RPCs agregadoras por página (avaliada e descartada; permanece apenas como possibilidade pontual guiada por latência medida).
- Mudanças de interface de usuário.
- Novas funcionalidades de negócio.
- Reescrita dos pontos de chamada do cliente, exceto o(s) ajuste(s) estritamente decorrente(s) da mudança de assinatura da função de auditoria.
