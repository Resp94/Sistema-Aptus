# Feature Specification: RBAC por Capacidades Nomeadas

**Feature Branch**: `007-rbac-capacidades-nomeadas`

**Created**: 2026-07-03

**Status**: Draft

**Input**: User description: "Fundacao com capacidades nomeadas em tabela, helper tem_capacidade, RPC obter_capacidades_usuario, migracao das RPCs de escrita para capacidades, ajuste de leitura de equipe para Tecnico, soft delete do perfil Visualizador como persona ativa, frontend usando helper pode(), correcoes funcionais de apontamento/detalhes/clientes, travas de auditoria/testes e documentacao de personas/arquitetura."

## Contexto e Motivacao

A validacao fim-a-fim das personas em 2026-07-03 confirmou que o bloqueio de rotas esta funcionando, mas tambem revelou um desalinhamento estrutural entre a matriz atual de permissao por modulo e as historias reais de usuario. O par `pode_ler`/`pode_escrever` por modulo e suficiente para navegacao e leitura ampla, mas nao distingue acoes diferentes dentro do mesmo dominio.

Os exemplos mais claros estao no perfil Tecnico:

- precisa atualizar e mover as proprias tarefas, mas nao criar ou excluir projetos;
- precisa apontar as proprias horas, mas nao gerenciar equipe;
- precisa consultar colegas alocados nos mesmos projetos, mas nao ver a equipe inteira nem apenas a si mesmo.

Tambem ha uma divergencia de produto no perfil Visualizador: hoje ele funciona como leitura ampla de quase todos os modulos, enquanto a regra desejada e que deixe de ser uma persona ativa e permaneca apenas como perfil tecnico minimo para usuarios recem-cadastrados ate promocao administrativa.

A solucao desta feature e introduzir capacidades nomeadas como fonte canonica de autorizacao de acoes, persistidas de forma auditavel em `public.capacidades_perfil`, consultadas no banco por `tem_capacidade(p_capacidade text)` e expostas ao frontend por `obter_capacidades_usuario()`. A permissao por modulo continua existindo para navegacao e leitura de rotas, mas a escrita e as acoes sensiveis passam a ser decididas por capacidades explicitas. A regra central passa a ser: **o frontend usa capacidades para experiencia de usuario; as RPCs usam as mesmas capacidades para autorizacao real**.

## Clarifications

### Session 2026-07-03

- Q: Quais operacoes precisam validar capacidades nomeadas: apenas escritas diretas ou toda acao com efeito de negocio? → A: Toda acao sensivel com efeito de negocio deve validar capacidade nomeada, incluindo escrita direta, boleto, notificacao, exportacao, baixa, envio e geracao.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Autorizar acoes por capacidade nomeada (Priority: P1)

Como administrador do sistema, eu quero que cada perfil tenha uma lista explicita de capacidades de acao para que o frontend e o backend apliquem a mesma regra de autorizacao, sem depender de escrita ampla por modulo.

**Why this priority**: Esta e a fundacao que corrige a causa raiz dos bugs de RBAC. Sem ela, as correcoes continuam sendo excecoes por perfil e por tela, mantendo o risco de regressao.

**Independent Test**: Validar que cada perfil recebe exatamente as capacidades esperadas e que uma acao sem capacidade e bloqueada mesmo quando a rota de leitura do modulo esta acessivel.

**Acceptance Scenarios**:

1. **Given** um usuario Tecnico autenticado, **When** o sistema consulta suas capacidades, **Then** ele recebe apenas capacidades de tarefas proprias, apontamento proprio e edicao do proprio perfil.
2. **Given** um usuario Comercial autenticado, **When** o sistema consulta suas capacidades, **Then** ele recebe capacidades de clientes, propostas, contratos e cobrancas comerciais, mas nao recebe capacidade de baixar cobranca.
3. **Given** um usuario sem capacidade para uma acao, **When** ele tenta executar a acao diretamente pelo canal de dados, **Then** a operacao e rejeitada independentemente de o botao estar oculto no frontend.

---

### User Story 2 - Corrigir o trabalho diario do Tecnico (Priority: P1)

Como Profissional Tecnico, eu quero ver os projetos e colegas relevantes ao meu trabalho, mover minhas proprias tarefas e registrar minhas proprias horas, sem receber permissoes gerenciais sobre projetos ou equipe.

**Why this priority**: Esta historia mata os tres bugs reais encontrados para Tecnico: excesso de escrita em projetos, ausencia de apontamento de horas e leitura de equipe limitada demais.

**Independent Test**: Entrar como Tecnico, confirmar que acoes gerenciais nao aparecem nem funcionam por chamada direta, que tarefas proprias podem ser atualizadas, que apontamento proprio e gravado e que a equipe visivel inclui colegas alocados nos mesmos projetos.

**Acceptance Scenarios**:

1. **Given** um Tecnico alocado em um projeto, **When** acessa Projetos, **Then** ele nao ve acoes de criar ou excluir projeto.
2. **Given** uma tarefa atribuida ao Tecnico, **When** ele move ou edita essa propria tarefa, **Then** a alteracao e aceita.
3. **Given** uma tarefa de outro responsavel, **When** o Tecnico tenta move-la ou edita-la diretamente, **Then** a operacao e rejeitada.
4. **Given** um Tecnico em Equipe, **When** consulta membros, **Then** ele ve a si mesmo e colegas alocados nos mesmos projetos, com visualizacao limitada.
5. **Given** um Tecnico registrando horas, **When** tenta apontar horas para outro membro, **Then** o registro e atribuido ao proprio Tecnico ou rejeitado de forma explicita, conforme a regra da operacao.

---

### User Story 3 - Remover Visualizador como persona operacional (Priority: P1)

Como administrador, eu quero que usuarios recem-cadastrados fiquem em um perfil tecnico minimo ate promocao manual, para reduzir risco de exposicao por leitura ampla indevida.

**Why this priority**: A validacao mostrou que Visualizador hoje tem leitura ampla demais e contradiz a documentacao desejada. Manter esse perfil como persona ativa perpetua ambiguidade de seguranca.

**Independent Test**: Validar que o perfil Visualizador permanece como valor tecnico de menor privilegio para cadastro inicial, mas nao aparece como persona ativa nos seeds, documentos, seletores administrativos de perfil operacional ou testes de persona.

**Acceptance Scenarios**:

1. **Given** um novo usuario criado por fluxo de cadastro, **When** seu perfil inicial e definido, **Then** ele recebe Visualizador como estado minimo anti-escalacao.
2. **Given** um administrador gerenciando usuarios, **When** escolhe um perfil operacional para promover um usuario, **Then** as opcoes ativas sao Administrador, Financeiro, Projetos, Comercial e Tecnico.
3. **Given** a suite de personas, **When** os testes fim-a-fim rodam, **Then** ela valida cinco personas operacionais e nao trata Visualizador como jornada ativa de negocio.

---

### User Story 4 - Alinhar os controles do frontend as capacidades (Priority: P2)

Como usuario autorizado, eu quero ver somente as acoes que fazem sentido para meu perfil e executar essas acoes com feedback consistente, para que a interface reflita exatamente a autorizacao do sistema.

**Why this priority**: O frontend nao e a fonte de seguranca, mas precisa consumir a mesma fonte de autorizacao para evitar botoes indevidos, botoes ausentes e experiencias quebradas.

**Independent Test**: Simular capacidades por perfil no cliente e confirmar que botoes de criar, excluir, apontar, baixar, boleto, notificar, inativar e reativar aparecem ou somem conforme a matriz canonica.

**Acceptance Scenarios**:

1. **Given** um usuario com capacidade de apontamento proprio, **When** abre a tela Equipe, **Then** a acao de apontar horas aparece para o proprio fluxo permitido.
2. **Given** um usuario sem capacidade de excluir projeto, **When** abre Projetos, **Then** a acao de excluir projeto nao e renderizada.
3. **Given** um usuario Comercial, **When** abre Cobrancas, **Then** ve acoes comerciais permitidas como boleto e notificacao, mas nao ve baixa financeira.
4. **Given** um usuario com capacidade de reativar cliente, **When** visualiza um cliente inativo, **Then** a interface oferece a acao de reativacao.

---

### User Story 5 - Corrigir fluxos funcionais afetados pela validacao (Priority: P2)

Como usuario das telas de Equipe, Propostas, Contratos e Clientes, eu quero que controles existentes concluam sua acao ou possam ser fechados/revertidos pela interface, para nao depender de ajuste manual no banco.

**Why this priority**: Estes bugs nao sao a causa estrutural de RBAC, mas afetam diretamente o uso diario e foram confirmados no E2E.

**Independent Test**: Executar cada fluxo afetado: apontamento sem tarefa, abertura e fechamento de detalhes de proposta/contrato, inativacao e reativacao de cliente.

**Acceptance Scenarios**:

1. **Given** um usuario autorizado registrando horas, **When** escolhe "atividade geral sem tarefa", **Then** o apontamento e salvo sem erro de identificador invalido.
2. **Given** um usuario visualizando detalhe de proposta, **When** clica em fechar ou pressiona Esc, **Then** o painel de detalhe e fechado.
3. **Given** um usuario visualizando detalhe de contrato, **When** clica em fechar ou pressiona Esc, **Then** o painel de detalhe e fechado.
4. **Given** um cliente inativo e um usuario autorizado, **When** aciona reativacao, **Then** o cliente volta ao estado ativo pela propria interface.

---

### User Story 6 - Impedir regressao por testes e auditoria (Priority: P2)

Como mantenedor, eu quero que guardrails e testes automatizados detectem qualquer escrita sem capacidade nomeada ou qualquer desvio de RPC-first, para que futuras mudancas nao reintroduzam autorizacao divergente.

**Why this priority**: A feature so fica sustentavel se a nova regra virar contrato automatizado. Sem isso, o sistema pode voltar a usar permissao ampla por modulo em novas RPCs ou botoes.

**Independent Test**: Introduzir deliberadamente uma escrita sem capacidade nomeada ou uma consulta direta de dominio e confirmar que os testes/auditorias falham antes de integracao.

**Acceptance Scenarios**:

1. **Given** uma RPC de escrita nova sem guarda por capacidade nomeada, **When** a auditoria de RPCs roda, **Then** ela falha apontando a funcao.
2. **Given** uma consulta direta a tabela em servico de dominio, **When** a auditoria RPC-first roda, **Then** ela falha, preservando apenas excecoes explicitamente catalogadas.
3. **Given** um Tecnico tentando mover tarefa alheia, **When** os testes de autorizacao rodam, **Then** a tentativa e rejeitada.
4. **Given** um Tecnico tentando forjar apontamento para outro membro, **When** os testes de autorizacao rodam, **Then** o sistema nao grava apontamento indevido para o outro membro.

---

### User Story 7 - Documentar a nova regra de autorizacao (Priority: P3)

Como desenvolvedor futuro, eu quero encontrar a matriz de capacidades e a regra de consumo por frontend/backend documentadas, para evoluir o RBAC sem reabrir decisoes ja tomadas.

**Why this priority**: E documentacao de governanca. Nao bloqueia o MVP funcional, mas e obrigatoria para manter a decisao rastreavel.

**Independent Test**: Verificar que a documentacao de personas e arquitetura registra cinco personas operacionais, o papel tecnico do Visualizador e a regra central de capacidades compartilhadas por frontend e RPCs.

**Acceptance Scenarios**:

1. **Given** um desenvolvedor avaliando uma nova acao sensivel, **When** consulta a documentacao de arquitetura, **Then** encontra a exigencia de capacidade nomeada validada no backend e consumida pelo frontend.
2. **Given** um analista revisando personas, **When** consulta a documentacao, **Then** encontra cinco personas operacionais e Visualizador descrito apenas como perfil tecnico minimo de signup.

### Edge Cases

- **Capacidade inexistente ou escrita incorreta**: uma capacidade nao cadastrada para o perfil deve ser tratada como negada, nunca como permitida por fallback.
- **Perfil sem linha de capacidade**: um perfil autenticado sem capacidades deve conseguir apenas o que sua permissao de leitura minima permitir e nenhuma escrita sensivel.
- **Usuario com sessao antiga apos mudanca de perfil**: a proxima consulta de capacidades deve refletir a matriz atual do banco; a interface nao pode depender apenas de cache permanente.
- **Acoes proprias vs qualquer registro**: capacidades com sufixo `propria` ou `proprio` exigem verificacao de ownership no corpo da operacao; nao basta conceder a capacidade.
- **Apontamento sem tarefa**: "sem tarefa" deve ser representado como ausencia de tarefa, nao como identificador textual.
- **Visualizador em dados legados**: se existirem usuarios com esse perfil, eles devem permanecer autenticaveis com privilegio minimo ate promocao administrativa, sem serem tratados como persona ativa.
- **Rotas de leitura autorizadas sem acoes**: uma tela pode ser acessivel para consulta mesmo quando todas as acoes de escrita estao ocultas e bloqueadas.

## Requirements *(mandatory)*

### Functional Requirements

**Fundacao de capacidades**

- **FR-001**: O sistema MUST manter a matriz auditavel de capacidades em `public.capacidades_perfil`, relacionando `perfil_acesso` e `capacidade` no formato `recurso.acao`.
- **FR-002**: O sistema MUST impedir duplicidade de capacidade para o mesmo perfil por meio da unicidade do par `perfil_acesso` + `capacidade`.
- **FR-003**: O sistema MUST oferecer a verificacao canonica `tem_capacidade(p_capacidade text)` para uso por operacoes protegidas.
- **FR-004**: O sistema MUST oferecer ao frontend a lista de capacidades do usuario autenticado por meio de `obter_capacidades_usuario()`, retornando uma lista simples de textos.
- **FR-005**: A permissao por modulo MUST continuar disponivel para leitura, rota e navegacao, mas o frontend MUST deixar de usar `pode_escrever` como fonte principal de exibicao de acoes sensiveis.
- **FR-006**: Capacidades ausentes MUST ser interpretadas como negadas.

**Catalogo e matriz por perfil**

- **FR-007**: O catalogo de capacidades MUST cobrir os recursos: clientes, propostas, contratos, cobrancas, projetos, tarefas, equipe, apontamentos, financeiro, configuracoes e relatorios.
- **FR-008**: O perfil Administrador MUST possuir todas as capacidades catalogadas.
- **FR-009**: O perfil Financeiro MUST possuir capacidades de financeiro, baixa/emissao de cobrancas, exportacao de relatorios e edicao do proprio perfil.
- **FR-010**: O perfil Projetos MUST possuir capacidades de projetos, tarefas gerenciais, equipe, apontamentos de qualquer membro, exportacao de relatorios e edicao do proprio perfil.
- **FR-011**: O perfil Comercial MUST possuir capacidades de clientes, propostas, contratos, cobrancas comerciais sem baixa financeira e edicao do proprio perfil.
- **FR-012**: O perfil Tecnico MUST possuir somente capacidades de editar/mover tarefas proprias, registrar apontamento proprio e editar o proprio perfil.
- **FR-013**: O perfil Visualizador MUST possuir zero capacidades de escrita e permanecer apenas como perfil tecnico minimo para usuarios ainda nao promovidos.
- **FR-013a**: O perfil Visualizador MUST manter leitura minima apenas para relatorios e configuracoes proprias, sem acesso a demais rotas de negocio.

**Catalogo detalhado de capacidades**

- **FR-014**: Clientes MUST suportar capacidades para criar, editar, inativar, reativar e registrar atendimento.
- **FR-015**: Propostas MUST suportar capacidades para criar, editar, enviar e gerar contrato.
- **FR-016**: Contratos MUST suportar capacidades para criar, renovar e encerrar.
- **FR-017**: Cobrancas MUST suportar capacidades para emitir, gerar/solicitar boleto, notificar e baixar.
- **FR-018**: Projetos MUST suportar capacidades para criar, editar e excluir.
- **FR-019**: Tarefas MUST suportar capacidades para criar, excluir, editar qualquer tarefa, mover qualquer tarefa, editar tarefa propria e mover tarefa propria.
- **FR-020**: Equipe MUST suportar capacidades para adicionar membro, alocar membro e inativar membro.
- **FR-021**: Apontamentos MUST suportar capacidades para registrar apontamento proprio e registrar apontamento de qualquer membro.
- **FR-022**: Financeiro MUST suportar capacidades para lancar, editar lancamento e baixar lancamento.
- **FR-023**: Configuracoes MUST suportar capacidades para gerenciar usuarios, editar dados da empresa e editar o proprio perfil.
- **FR-024**: Relatorios MUST suportar capacidade para exportar.

**Autorizacao de RPCs e ownership**

- **FR-025**: Todas as RPCs de escrita existentes e futuras, e toda acao sensivel com efeito de negocio, MUST validar uma capacidade nomeada antes de executar.
- **FR-026**: Operacoes com capacidade `propria` ou `proprio` MUST validar ownership do registro alvo no corpo da operacao.
- **FR-027**: Acoes gerenciais sobre projetos MUST exigir capacidades de projetos e nao podem ser liberadas por capacidades de tarefa propria.
- **FR-028**: Acoes gerenciais sobre equipe MUST exigir capacidades de equipe e nao podem ser liberadas por capacidade de apontamento proprio.
- **FR-029**: Registrar apontamento proprio MUST impedir que um usuario grave horas para outro membro.
- **FR-030**: Registrar apontamento de qualquer membro MUST ficar restrito aos perfis com capacidade operacional correspondente.
- **FR-031**: Mover ou editar tarefa propria MUST rejeitar tarefa que nao esteja atribuida ao usuario autenticado.
- **FR-032**: Mover ou editar qualquer tarefa MUST ficar restrito a perfis com capacidade gerencial de tarefas.

**Leitura de equipe e Visualizador**

- **FR-033**: A leitura de membros para Tecnico MUST retornar o proprio Tecnico e colegas com alocacao ativa nos mesmos projetos ativos, considerando alocacao ativa quando `data_fim` for nula ou maior/igual a data atual e projeto ativo quando o projeto estiver em andamento.
- **FR-034**: A leitura de membros para Tecnico MUST preservar visualizacao limitada: para colegas, pode expor somente `id`, `nome`, `funcao`, `habilidades`, `status`, `capacidade` e `projeto_atual` restrito ao projeto ativo compartilhado; MUST ocultar ou retornar nulo para `perfil_id`, `custo_hora`, permissoes, contatos sensiveis, historico de apontamentos e alocacoes fora dos projetos compartilhados.
- **FR-035**: Visualizador MUST sair dos seeds de personas operacionais, da documentacao de personas ativas, dos seletores administrativos de perfil operacional e dos testes E2E de persona ativa.
- **FR-036**: Visualizador MUST continuar existindo como valor tecnico valido para o estado inicial de menor privilegio no cadastro, com leitura minima em relatorios e configuracoes proprias.

**Frontend e UX de acoes**

- **FR-037**: O frontend MUST manter capacidades no contexto de autenticacao da sessao.
- **FR-038**: O frontend MUST oferecer helper unico para verificar se uma capacidade esta presente.
- **FR-039**: Todo botao ou controle de acao sensivel MUST ser exibido com base em capacidade nomeada, nao em escrita ampla por modulo.
- **FR-040**: A tela de Equipe MUST permitir apontamento sem tarefa usando ausencia de tarefa como valor valido.
- **FR-041**: As telas de Propostas e Contratos MUST permitir fechar o painel de detalhe por controle visivel e por tecla Esc.
- **FR-042**: A tela de Clientes MUST oferecer reativacao de cliente inativo para usuarios com capacidade apropriada, reutilizando uma operacao autorizada de atualizacao de cliente.

**Travas automatizadas**

- **FR-043**: A auditoria de RPCs (`audit-rpc`) MUST aceitar `tem_capacidade` como guarda valida para escrita e para acoes sensiveis com efeito de negocio.
- **FR-044**: A auditoria de RPCs (`audit-rpc`) MUST reprovar operacoes de escrita e acoes sensiveis com efeito de negocio sem capacidade nomeada.
- **FR-045**: A suite de testes de banco MUST incluir um conjunto dedicado de testes de capacidades por perfil.
- **FR-046**: A suite de testes de banco MUST validar ownership de Tecnico em tarefas proprias e apontamentos proprios.
- **FR-047**: A suite de testes de banco MUST validar que Tecnico enxerga colegas alocados nos mesmos projetos.
- **FR-048**: A suite de testes RBAC por perfil MUST ser ajustada para cinco personas operacionais, mantendo Visualizador apenas como caso tecnico de menor privilegio.
- **FR-049**: Os testes unitarios do frontend MUST cobrir o helper de capacidade e a normalizacao de payload de apontamento sem tarefa.
- **FR-050**: O E2E de personas MUST passar com cinco personas operacionais: Administrador, Financeiro, Projetos, Comercial e Tecnico.

**Documentacao**

- **FR-051**: A documentacao de personas MUST registrar cinco personas operacionais e remover Visualizador como persona ativa.
- **FR-052**: A documentacao de arquitetura de dados MUST registrar a regra central: frontend usa capacidade para UX; RPC usa capacidade para autorizacao; ambos consomem a mesma fonte canonica.
- **FR-053**: A documentacao MUST registrar que Dashboard oficial fica com Administrador e Financeiro, salvo decisao posterior explicita.

### Key Entities *(include if feature involves data)*

- **Capacidade nomeada**: permissao atomica de acao no formato `recurso.acao`, como `tarefas.mover_propria` ou `cobrancas.baixar`.
- **Matriz de capacidades por perfil**: relacao auditavel entre perfil de acesso e capacidades concedidas, identificada pelo par unico `perfil_acesso` + `capacidade`.
- **Perfil de acesso**: classificacao do usuario usada para navegacao, leitura e concessao de capacidades. Perfis operacionais: Administrador, Financeiro, Projetos, Comercial e Tecnico. Perfil tecnico minimo: Visualizador.
- **Operacao protegida**: qualquer acao que altera estado ou dispara efeito de negocio sensivel, incluindo boleto, notificacao, exportacao, baixa, envio e geracao.
- **Ownership**: relacao que prova que um registro pertence ao usuario autenticado ou esta atribuido a ele, necessaria para capacidades proprias.
- **Capacidades da sessao**: lista de capacidades do usuario autenticado consumida pela interface para exibir ou ocultar controles.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das RPCs de escrita protegidas e acoes sensiveis com efeito de negocio validam capacidade nomeada antes de executar.
- **SC-002**: 0 botoes de acao sensivel no frontend dependem exclusivamente de `pode_escrever` por modulo apos a migracao.
- **SC-003**: Tecnico nao consegue criar/excluir projeto, mover tarefa alheia nem apontar horas para outro membro em chamadas diretas.
- **SC-004**: Tecnico consegue mover/editar tarefa propria e registrar apontamento proprio com sucesso.
- **SC-005**: Tecnico ve a si mesmo e ao menos os colegas alocados nos mesmos projetos em cenarios de seed que tenham colegas compartilhados.
- **SC-006**: Visualizador nao aparece como persona operacional em seeds, documentacao, seletor administrativo operacional ou E2E de personas, mas permanece como perfil tecnico minimo de signup com leitura restrita a relatorios e configuracoes proprias.
- **SC-007**: Apontamento sem tarefa conclui sem erro de identificador invalido em 100% dos cenarios testados.
- **SC-008**: Paineis de detalhe de Propostas e Contratos podem ser fechados por controle visivel e por Esc.
- **SC-009**: Cliente inativo pode ser reativado pela interface por usuario autorizado.
- **SC-010**: A auditoria de RPCs falha ao introduzir deliberadamente uma escrita ou acao sensivel com efeito de negocio sem capacidade nomeada.
- **SC-011**: A suite automatizada cobre matriz de capacidades, ownership, leitura de equipe do Tecnico, helper de capacidade, normalizacao de apontamento e E2E das cinco personas.
- **SC-012**: A validacao final por persona nao encontra divergencias entre acoes visiveis no frontend e autorizacao real do backend.

## Assumptions

- As capacidades nomeadas sao a nova fonte canonica para autorizacao de acoes; permissoes por modulo continuam para leitura, navegacao e compatibilidade gradual.
- O perfil Visualizador continua necessario como defesa contra auto-escalacao no cadastro, mas nao representa uma jornada operacional de negocio.
- A migracao de escrita para capacidades pode ser gradual no frontend, mas toda operacao sensivel alterada nesta feature deve terminar protegida por capacidade no backend.
- A matriz inicial de capacidades sera versionada e auditavel; uma futura tela administrativa podera editar essa matriz, mas essa UI esta fora do escopo atual.
- Regras de ownership pertencem ao backend; o frontend pode ocultar controles, mas nunca e considerado fonte de autorizacao.
- A documentacao de Dashboard passa a considerar Administrador e Financeiro como perfis oficiais com acesso ao Dashboard, enquanto Projetos fica sem Dashboard salvo decisao futura explicita.

## Out of Scope

- Criar uma interface administrativa para editar capacidades por perfil.
- Substituir a navegacao por modulo; `obter_permissoes_usuario` permanece para leitura/rotas.
- Refatorar leituras para RPCs agregadoras por pagina.
- Criar novas personas de negocio.
- Alterar integracoes externas de boleto, notificacao ou exportacao alem dos gates de capacidade ja descritos.
