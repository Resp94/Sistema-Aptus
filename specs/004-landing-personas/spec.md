# Feature Specification: Telas de Redirecionamento por Persona (Landing Pages)

**Feature Branch**: `main` (diretório da spec: `004-landing-personas` — o projeto trabalha em `main` e resolve a feature por `.specify/feature.json`, não por nome de branch)

**Created**: 2026-06-28

**Status**: Draft

**Input**: User description: "vamos converter as demais telas de redirecionamento de acordo com cada perfil das personas. - atualmente as unicas pages convertidas foram /login e /dashboard. - exclua dados mockados, vamos trabalhar com dados reais vindo do banco - conversão das demais telas .html em reference para as demais personas"

## Contexto e Escopo

Após o login, cada persona é direcionada para uma **tela inicial (landing)** correspondente ao seu perfil de acesso. Hoje apenas a landing do Dashboard existe de fato, e mesmo ela exibe **dados fictícios (mockados)**. As demais personas caem em uma tela placeholder ("Módulo Não Migrado").

Esta feature converte as **telas iniciais de redirecionamento por persona** que ainda faltam — **Projetos** (`/projetos`) e **Clientes/Fornecedores** (`/clientes`) — a partir das referências em `reference/legacy-html/`, e **substitui todos os dados mockados** dessas telas (incluindo o Dashboard já existente) por **dados reais persistidos no banco**. Para isso, o escopo inclui **criar o schema de dados** (tabelas, segurança em nível de linha e dados de carga inicial) que alimenta essas três landings.

**Mapa de landing por persona:**

| Persona (perfil técnico) | Tela inicial | Estado atual |
|---|---|---|
| Administrador, Analista Financeiro (Financeiro), Visualizador | Dashboard (`/dashboard`) | Convertida, porém **mockada** |
| Gerente de Projetos (Projetos), Profissional Técnico (Técnico) | Projetos (`/projetos`) | **Placeholder** |
| Consultor Comercial (Comercial) | Clientes/Fornecedores (`/clientes`) | **Placeholder** |

**Fora de escopo nesta feature:** as demais telas internas que não são landing de nenhuma persona (Fluxo de Caixa, Contas a Pagar, Contas a Receber, Propostas, Contratos, Cobranças, Equipe, Relatórios, Configurações). Elas continuam exibindo o placeholder de módulo não migrado e serão tratadas em features futuras.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Gerente de Projetos / Técnico chega à tela de Projetos com dados reais (Priority: P1)

Ao fazer login, um Gerente de Projetos ou Profissional Técnico é redirecionado automaticamente para a tela de Projetos, que exibe seus projetos, tarefas e indicadores reais carregados do banco de dados — sem qualquer valor fictício.

**Why this priority**: É a landing de duas das personas e a principal entrega que falta para que esses perfis tenham uma experiência funcional após o login. Sem ela, esses usuários caem em uma tela placeholder.

**Independent Test**: Pode ser testado isoladamente fazendo login com a persona Gerente de Projetos (ou Técnico), confirmando o redirecionamento para `/projetos` e verificando que os indicadores, a lista de projetos e o quadro de tarefas refletem registros existentes no banco.

**Acceptance Scenarios**:

1. **Given** que existem projetos e tarefas cadastrados no banco, **When** o Gerente de Projetos faz login, **Then** o sistema o redireciona para a tela de Projetos exibindo os indicadores (projetos ativos, tarefas abertas, orçamento total, projetos em risco), o progresso dos projetos e o quadro de tarefas com dados reais.
2. **Given** que o Profissional Técnico está alocado em um subconjunto de projetos, **When** ele acessa a tela de Projetos, **Then** o sistema exibe apenas os projetos e tarefas a que ele tem direito de visualizar, conforme suas permissões.
3. **Given** que não há projetos cadastrados para o usuário, **When** ele acessa a tela de Projetos, **Then** o sistema exibe um estado vazio claro (ex.: "Nenhum projeto encontrado") em vez de dados fictícios.

---

### User Story 2 - Consultor Comercial chega à tela de Clientes com dados reais (Priority: P1)

Ao fazer login, um Consultor Comercial é redirecionado automaticamente para a tela de Clientes/Fornecedores, que exibe a carteira real de clientes e fornecedores, indicadores e histórico de atendimento carregados do banco.

**Why this priority**: É a landing da persona Comercial e equivale, para esse perfil, ao que o Dashboard representa para o Administrador. Sem ela, o Comercial cai em placeholder.

**Independent Test**: Pode ser testado isoladamente fazendo login com a persona Consultor Comercial, confirmando o redirecionamento para `/clientes` e verificando que a lista de contatos, os indicadores e o painel de detalhes refletem registros reais do banco.

**Acceptance Scenarios**:

1. **Given** que existem clientes e fornecedores cadastrados, **When** o Consultor Comercial faz login, **Then** o sistema o redireciona para a tela de Clientes exibindo as abas Clientes/Fornecedores, os indicadores (contatos, receita acumulada, ativos, fornecedores) e a tabela de contatos com dados reais.
2. **Given** que um contato possui histórico de atendimento registrado, **When** o usuário seleciona esse contato, **Then** o painel de detalhes exibe os dados de contato, a receita e o histórico de atendimento reais daquele cliente.
3. **Given** que a busca/filtro é aplicada, **When** o usuário digita um termo ou seleciona um status, **Then** a tabela é filtrada com base nos dados reais retornados pelo banco.

---

### User Story 3 - Dashboard deixa de usar dados mockados (Priority: P2)

A tela de Dashboard, já existente, passa a exibir indicadores, gráficos e listas alimentados por dados reais do banco em vez dos valores fixos atualmente codificados na tela.

**Why this priority**: O Dashboard é a landing de Administrador, Financeiro e Visualizador e já está convertido visualmente; o que falta é eliminar o mock. Tem prioridade logo abaixo das landings inexistentes porque a tela já é navegável, ainda que com dados falsos.

**Independent Test**: Pode ser testado isoladamente fazendo login com a persona Administrador e comparando os valores exibidos no Dashboard (saldo, contas a receber/pagar, clientes ativos, fluxo de caixa, últimos lançamentos) com os registros existentes no banco.

**Acceptance Scenarios**:

1. **Given** que existem lançamentos financeiros e clientes no banco, **When** o Administrador acessa o Dashboard, **Then** os cards de métricas, o gráfico de fluxo de caixa, a lista de últimos lançamentos, a lista de contas a pagar dos próximos 7 dias e a composição de receita refletem os dados reais — nenhum valor fixo permanece na tela.
2. **Given** que o banco está sem dados em alguma seção, **When** o usuário acessa o Dashboard, **Then** a seção correspondente exibe um estado vazio ou zerado coerente, sem números fictícios.

---

### User Story 4 - Redirecionamento correto e consistente por perfil (Priority: P2)

Cada persona, ao concluir o login, é levada à sua landing correta; ao tentar acessar uma rota sem permissão, o sistema a trata de forma previsível.

**Why this priority**: Garante que a conversão das telas se traduza em uma experiência de redirecionamento coerente entre todos os perfis, fechando o ciclo de "telas de redirecionamento de acordo com cada perfil".

**Independent Test**: Pode ser testado isoladamente executando login com cada persona e confirmando que a rota inicial corresponde ao mapa de landing por persona.

**Acceptance Scenarios**:

1. **Given** uma persona autenticada, **When** o login é concluído, **Then** o sistema a redireciona para a landing definida para o seu perfil (Administrador/Financeiro/Visualizador → Dashboard; Projetos/Técnico → Projetos; Comercial → Clientes).
2. **Given** que um usuário tenta acessar diretamente uma landing à qual seu perfil não tem permissão de leitura, **When** a rota é carregada, **Then** o sistema impede o acesso e o conduz a uma rota permitida (ex.: sua própria landing).

### User Story 5 - Gerenciar registros (criar, editar, excluir) com persistência real (Priority: P2)

Nas landings em escopo, usuários com permissão de escrita podem criar, editar e excluir registros (projetos, tarefas, clientes/fornecedores), com as alterações persistidas no banco e refletidas imediatamente na tela.

**Why this priority**: Torna as landings operacionais de fato, não apenas painéis de leitura. Depende da camada de dados real (P1) já existir, por isso vem logo abaixo.

**Independent Test**: Pode ser testado isoladamente criando um novo registro em cada landing, recarregando a tela e confirmando que o registro persistiu; e tentando a mesma ação com um perfil sem permissão de escrita para confirmar o bloqueio.

**Acceptance Scenarios**:

1. **Given** um usuário com permissão de escrita no módulo, **When** ele cria um novo registro (projeto, tarefa ou contato) e confirma, **Then** o sistema persiste o dado no banco e o exibe na tela sem necessidade de recarga manual.
2. **Given** um registro existente, **When** o usuário o edita ou exclui, **Then** a alteração é persistida e refletida na tela.
3. **Given** um usuário sem permissão de escrita no módulo (ex.: Visualizador), **When** ele acessa a landing, **Then** as ações de criar/editar/excluir ficam **ocultas** (não renderizadas) e, ainda que invocadas diretamente, são rejeitadas pela camada de dados.
4. **Given** uma entrada inválida ou falha de persistência, **When** o usuário confirma a ação, **Then** o sistema exibe uma mensagem de erro clara e não corrompe o estado da tela.

### Edge Cases

- **Persona sem dados na landing**: cada seção exibe um estado vazio explícito, seguindo o padrão visual `empty-state` da referência legada (ícone + título curto + descrição orientando a ação), nunca dados fictícios. Mensagens-base por tipo de seção: lista/tabela → "Nenhum registro encontrado"; busca/filtro → "Nenhum resultado encontrado"; gráfico/indicador → valor zerado com rótulo "Sem dados no período".
- **Usuário sem permissão de leitura no módulo da própria landing**: o sistema o redireciona para uma rota permitida **antes** de carregar qualquer dado do módulo, evitando tela em branco, erro ou exposição de dados não autorizados.
- **Falha ao carregar dados do banco**: a tela exibe um estado de erro recuperável (ex.: mensagem com opção de tentar novamente), mantendo a navegação utilizável.
- **Carregamento em andamento**: a tela apresenta um estado de carregamento (skeleton/spinner) enquanto os dados reais são buscados, evitando "flash" de conteúdo vazio.
- **Técnico visualizando Projetos/Equipe**: vê somente os projetos em que está alocado e a visualização limitada da equipe, conforme suas permissões.
- **Filtro/busca sem resultados**: a tabela exibe "nenhum resultado encontrado" em vez de manter dados anteriores.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE converter a tela de Projetos (`/projetos`) a partir de `reference/legacy-html/projetos.html`, preservando a identidade visual e a estrutura de componentes (indicadores, progresso dos projetos, distribuição por cliente, quadro de tarefas Kanban e modais de novo projeto/nova tarefa).
- **FR-002**: O sistema DEVE converter a tela de Clientes/Fornecedores (`/clientes`) a partir de `reference/legacy-html/clientes.html`, preservando a identidade visual e a estrutura de componentes (abas Clientes/Fornecedores, busca e filtro de status, indicadores, tabela de contatos, painel de detalhes e modal de novo contato).
- **FR-003**: O sistema DEVE redirecionar cada persona, após o login, para a landing correspondente ao seu perfil de acesso, conforme o mapa de landing por persona.
- **FR-004**: O sistema DEVE substituir todos os dados mockados das telas em escopo (Dashboard, Projetos, Clientes) por dados reais lidos do banco de dados; nenhum valor fictício codificado deve permanecer nessas telas. Para efeito deste requisito, **dado mockado** = qualquer valor de domínio (número, texto, item de lista, série de gráfico) fixado no código do componente/markup e não proveniente de uma chamada de leitura ao banco. Inclui-se aqui a remoção de elementos de UI alimentados por dados fictícios que não possuam fonte real nesta feature (ex.: o modal de notificações fictício do Dashboard), que devem ser removidos ou religados a dados reais.
- **FR-005**: O sistema DEVE criar o schema de dados (tabelas, regras de segurança em nível de linha e dados de carga inicial) necessário para alimentar as três landings em escopo, abrangendo no mínimo: clientes/fornecedores, projetos, tarefas e lançamentos/contas financeiras.
- **FR-006**: O sistema DEVE aplicar as permissões por perfil (RBAC) já definidas, exibindo em cada landing apenas os dados que o perfil do usuário tem direito de ler, e respeitando a visualização limitada do Profissional Técnico.
- **FR-007**: O sistema DEVE exibir um estado vazio explícito em cada seção das landings quando não houver dados correspondentes no banco, sem recorrer a valores fictícios, seguindo o padrão `empty-state` (ícone + título + descrição) e as mensagens-base definidas em Edge Cases.
- **FR-008**: O sistema DEVE exibir um estado de carregamento enquanto os dados reais são buscados e um estado de erro recuperável quando a busca falhar.
- **FR-009**: O sistema DEVE manter os dados de carga inicial (seeds) coerentes com as personas de teste existentes, de modo que cada persona de teste visualize dados reais relevantes ao seu perfil em sua landing.
- **FR-010**: O sistema DEVE impedir que um usuário acesse uma landing para a qual seu perfil não tem permissão de leitura, redirecionando-o para uma rota permitida **antes** de qualquer carregamento de dados do módulo, de modo que nenhum dado não autorizado seja buscado ou exibido.
- **FR-011**: Os indicadores, gráficos e listas das landings DEVEM ser calculados/derivados a partir dos dados reais persistidos (ex.: contagens, somatórios, percentuais), refletindo o estado atual do banco.
- **FR-012**: As ações de criação, edição e exclusão apresentadas nas telas em escopo (ex.: novo/editar projeto, nova/editar tarefa, novo/editar contato) DEVEM persistir os dados reais no banco, refletindo as alterações imediatamente na tela sem simular persistência fictícia.
- **FR-013**: O sistema DEVE aplicar as permissões de escrita por perfil (RBAC) nas ações de criar/editar/excluir, **ocultando** (não renderizando) essas ações para perfis sem direito de escrita no módulo correspondente (ex.: Visualizador, ou Técnico em módulos restritos). A ocultação na interface é uma conveniência de UX; a imposição autoritativa ocorre na camada de dados (FR-006).
- **FR-014**: O sistema DEVE validar os dados de entrada das ações de escrita e exibir mensagens de erro claras quando a operação falhar (validação, permissão ou erro do banco), mantendo a tela utilizável.
- **FR-015**: O sistema DEVE registrar na trilha de auditoria (`audit_log`) as ações **destrutivas** dos módulos em escopo — exclusão de projeto, exclusão de tarefa e inativação de cliente —, com tipo de evento, usuário responsável e data/hora. Ações de criação e edição não destrutivas não são auditadas, mantendo a trilha focada em eventos de segurança e ações irreversíveis (consistente com o uso atual de `audit_log`).
- **FR-016**: O sistema DEVE persistir a mudança de coluna de uma tarefa no quadro Kanban (A Fazer / Em Andamento / Concluído) quando o usuário a movimenta, refletindo a nova situação após recarregar a tela.

### Key Entities *(include if feature involves data)*

- **Cliente/Fornecedor**: Contato comercial da empresa. Atributos principais: identificador, nome/razão social, tipo (cliente ou fornecedor), dados de contato (e-mail, telefone), status (ativo/inativo), receita acumulada associada e datas de controle. Relaciona-se com projetos e com o histórico de atendimento.
- **Atendimento/Interação**: Registro do histórico de relacionamento com um cliente. Atributos principais: identificador, vínculo com o cliente, data, descrição/resumo e responsável.
- **Projeto**: Trabalho gerenciado pela equipe. Atributos principais: identificador, nome, cliente associado, status, progresso (%), orçamento, indicador de risco e datas. Relaciona-se com clientes, tarefas e membros alocados.
- **Tarefa**: Unidade de trabalho de um projeto exibida no Kanban. Atributos principais: identificador, vínculo com projeto, título, situação (A Fazer / Em Andamento / Concluído), responsável e prazo.
- **Lançamento/Conta Financeira**: Movimentação financeira que alimenta os indicadores do Dashboard. Atributos principais: identificador, tipo (receita/despesa), natureza (a pagar/a receber/realizado), descrição, valor, data de competência/vencimento, status e contraparte (cliente/fornecedor). Sustenta saldo, contas a pagar/receber, fluxo de caixa, últimos lançamentos e composição de receita. O status **Vencido** é **derivado em tempo de consulta** (lançamento `Pendente` cuja data de vencimento é anterior à data atual), não armazenado, garantindo consistência sem rotina de atualização.
- **Alocação de Equipe** *(suporte à visualização do Técnico)*: Vínculo entre um membro/usuário e um projeto. Atributos principais: identificador, usuário, projeto e papel. Define quais projetos o Profissional Técnico pode visualizar.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das personas de teste são redirecionadas, após o login, para a landing correta do seu perfil (Dashboard, Projetos ou Clientes).
- **SC-002**: 0 valores fictícios/codificados permanecem visíveis nas telas em escopo — todos os indicadores, gráficos e listas refletem dados do banco.
- **SC-003**: Cada landing em escopo carrega e exibe seus dados reais em menos de 3 segundos em condições normais de rede, medido sobre o volume de dados de referência provisionado pelos seeds (ordem de dezenas de registros por entidade).
- **SC-004**: Quando não há dados, 100% das seções das landings exibem um estado vazio explícito, sem números ou itens fictícios.
- **SC-005**: As três landings em escopo (Dashboard, Projetos, Clientes) deixam de exibir a tela "Módulo Não Migrado" para as personas correspondentes.
- **SC-006**: Cada persona visualiza exclusivamente os dados permitidos pelo seu perfil; o Profissional Técnico vê apenas projetos em que está alocado.
- **SC-007**: 100% das tentativas de acesso a uma landing sem permissão de leitura resultam em redirecionamento para uma rota permitida, sem tela em branco ou erro não tratado.
- **SC-008**: Registros criados, editados ou excluídos nas landings persistem no banco e permanecem consistentes após recarregar a tela (verificável em 100% das ações de escrita testadas).
- **SC-009**: 100% das ações de escrita executadas por perfis sem permissão são bloqueadas — ocultas na interface e rejeitadas pela camada de dados —, e nenhuma alteração é persistida nesses casos.
- **SC-010**: A reconstrução do banco (`supabase db reset`) cria as 6 tabelas novas e todas as funções de acesso (leitura e escrita) sem erros de integridade, com os seeds por persona aplicados.
- **SC-011**: 100% das ações destrutivas em escopo (exclusão de projeto/tarefa, inativação de cliente) geram um registro correspondente em `audit_log` com usuário e data/hora.
- **SC-012**: Mover uma tarefa entre colunas do Kanban persiste a nova situação, verificável após recarregar a tela em 100% dos casos testados.

## Assumptions

- O redirecionamento por perfil já implementado (Administrador/Financeiro/Visualizador → Dashboard; Projetos/Técnico → Projetos; Comercial → Clientes) é a regra de negócio correta e deve ser mantido.
- As personas e os perfis técnicos de acesso (RBAC) definidos em `docs/personas.md` e nas regras de permissão já existentes no banco são a fonte de verdade para o que cada landing exibe.
- Os arquivos `reference/legacy-html/projetos.html` e `reference/legacy-html/clientes.html` são a referência de design e comportamento para as novas telas React.
- A infraestrutura de autenticação, contexto de usuário e proteção de rotas já existente é reutilizada; esta feature não altera o fluxo de login em si.
- A criação do schema de dados desta feature segue o mesmo padrão de migrações, segurança em nível de linha e seeds já adotado para usuários/perfis.
- O Dashboard, embora já convertido, está em escopo apenas para troca de dados mockados por dados reais — não há rework visual previsto além do necessário para refletir os dados do banco.
- As demais telas internas (fora das três landings) permanecem como "Módulo Não Migrado" e não fazem parte desta entrega.
- Dados de clientes/contatos (nome, e-mail, telefone) são classificados como PII e devem seguir as mesmas regras de proteção já aplicadas a usuários/perfis.
