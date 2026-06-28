# Feature Specification: Demais Telas por Perfil de Acesso

**Feature Branch**: `main` (diretorio da spec: `005-demais-telas-perfis` - o projeto resolve a feature por `.specify/feature.json`, nao por nome de branch)

**Created**: 2026-06-28

**Status**: Draft

**Input**: User description: "vamos montar as demais telas para todos os perfis de acesso"

## Contexto e Escopo

As features anteriores entregaram autenticacao, redirecionamento por persona e as landings principais de `Dashboard`, `Projetos` e `Clientes`. As demais rotas continuam apontando para a tela generica de modulo nao migrado. Esta feature especifica a conversao das telas restantes para que todos os perfis tenham seus fluxos completos de trabalho dentro do sistema, usando os arquivos em `reference/legacy-html/` como referencia visual e comportamental das telas.

**Telas em escopo:**

| Tela | Rota | Perfis com acesso |
|---|---|---|
| Fluxo de Caixa | `/fluxo-caixa` | Administrador, Financeiro |
| Contas a Pagar | `/contas-pagar` | Administrador, Financeiro |
| Contas a Receber | `/contas-receber` | Administrador, Financeiro |
| Propostas | `/propostas` | Administrador, Comercial |
| Contratos | `/contratos` | Administrador, Comercial |
| Cobrancas | `/cobrancas` | Administrador, Financeiro, Comercial |
| Equipe | `/equipe` | Administrador, Projetos, Tecnico |
| Relatorios | `/relatorios` | Administrador, Financeiro, Projetos, Visualizador |
| Configuracoes | `/configuracoes` | Administrador; Tecnico apenas dados proprios |

**Fora de escopo nesta feature:** alterar o fluxo de login, substituir as landings ja migradas, integrar provedores externos de boleto, e-mail transacional ou armazenamento documental alem do que ja estiver disponivel no produto. Quando uma acao depender de uma integracao ainda inexistente, a tela deve mostrar uma resposta honesta de "pendente de integracao", sem simular envio, emissao ou download real.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Financeiro opera o ciclo financeiro completo (Priority: P1)

Como Analista Financeiro ou Administrador, o usuario acessa Fluxo de Caixa, Contas a Pagar, Contas a Receber e Cobrancas para registrar movimentacoes, acompanhar vencimentos, controlar recebiveis e atualizar pagamentos com dados reais.

**Why this priority**: O ciclo financeiro concentra os controles mais criticos da administracao da empresa e alimenta indicadores ja exibidos no Dashboard.

**Independent Test**: Fazer login com o perfil Financeiro, navegar pelas quatro rotas financeiras, criar/editar registros permitidos, aplicar filtros e confirmar que indicadores, tabelas e estados refletem dados persistidos.

**Acceptance Scenarios**:

1. **Given** que existem lancamentos e contas financeiras, **When** o usuario acessa Fluxo de Caixa, **Then** visualiza saldo inicial, entradas, saidas, saldo projetado, grafico, previsoes e tabela com dados reais.
2. **Given** que existem contas vencidas e a vencer, **When** o usuario acessa Contas a Pagar ou Contas a Receber, **Then** visualiza cards, listas, tabela e status derivados dos registros reais.
3. **Given** que o usuario tem permissao de escrita financeira, **When** cria uma receita, despesa, conta ou registra pagamento, **Then** a alteracao e persistida e aparece na tela apos a conclusao da acao.
4. **Given** que o usuario Comercial acessa Cobrancas, **When** tenta registrar pagamento, **Then** a permissao de escrita financeira define se a acao aparece e se pode ser executada.

---

### User Story 2 - Comercial gerencia propostas, contratos e cobrancas (Priority: P1)

Como Consultor Comercial ou Administrador, o usuario cria propostas, acompanha status comerciais, converte propostas aprovadas em contratos e acompanha cobrancas vinculadas aos clientes.

**Why this priority**: Fecha o fluxo comercial iniciado pela tela de Clientes, permitindo que a carteira comercial evolua para receita contratada e cobrancas.

**Independent Test**: Fazer login com o perfil Comercial, acessar Propostas, Contratos e Cobrancas, criar registros, atualizar status e validar que somente dados comerciais permitidos aparecem.

**Acceptance Scenarios**:

1. **Given** que existem clientes cadastrados, **When** o usuario cria uma proposta, **Then** a proposta fica vinculada ao cliente, possui valor, status e historico visivel.
2. **Given** que uma proposta foi aprovada, **When** o usuario cria um contrato a partir dela, **Then** o contrato preserva o vinculo com cliente/proposta e exibe vigencia, status e valor recorrente.
3. **Given** que um contrato possui cobrancas, **When** o usuario acessa Cobrancas, **Then** visualiza status, vencimento, cliente, valor e acoes permitidas para lembretes comerciais.
4. **Given** que a acao de envio de proposta, lembrete ou boleto depende de integracao externa ausente, **When** o usuario aciona o comando, **Then** o sistema informa que a acao ficou pendente de integracao e nao apresenta falso sucesso.

---

### User Story 3 - Projetos e Tecnico acompanham equipe, capacidade e apontamentos (Priority: P2)

Como Gerente de Projetos, o usuario acompanha membros da equipe, alocacoes, disponibilidade e capacidade. Como Profissional Tecnico, o usuario visualiza apenas informacoes permitidas da equipe, suas alocacoes e seus proprios dados operacionais.

**Why this priority**: Complementa a landing de Projetos ja migrada e torna possivel gerir capacidade real da equipe.

**Independent Test**: Fazer login como Projetos e como Tecnico, comparar a tela Equipe e confirmar que o Gerente ve alocacoes completas, enquanto o Tecnico ve somente o recorte permitido.

**Acceptance Scenarios**:

1. **Given** que existem membros e alocacoes, **When** o Gerente de Projetos acessa Equipe, **Then** visualiza total de membros, projetos ativos, disponibilidade, tabela, alocacao por projeto e capacidade.
2. **Given** que um Tecnico acessa Equipe, **When** a tela carrega, **Then** visualiza apenas equipe/alocacoes relacionadas ao seu contexto permitido e nao ve custos ou dados sensiveis de outros membros.
3. **Given** que o Gerente tem permissao de escrita, **When** cadastra membro, edita status ou aloca membro em projeto, **Then** a mudanca e persistida e refletida na tela.
4. **Given** que o Tecnico atualiza seus proprios dados permitidos, **When** salva disponibilidade ou informacoes do perfil operacional, **Then** apenas seu proprio registro e alterado.

---

### User Story 4 - Administrador controla configuracoes e usuarios (Priority: P2)

Como Administrador, o usuario gerencia configuracoes gerais, parametros financeiros, notificacoes, usuarios, permissoes e preferencias visuais. Como Tecnico, o usuario acessa Configuracoes apenas para dados proprios.

**Why this priority**: Configuracoes define regras operacionais e acesso; sem ela, o sistema depende de ajustes manuais fora da interface.

**Independent Test**: Fazer login como Administrador e Tecnico, acessar Configuracoes e validar que cada perfil enxerga somente as abas e acoes permitidas.

**Acceptance Scenarios**:

1. **Given** que o Administrador acessa Configuracoes, **When** navega pelas abas, **Then** ve dados da empresa, parametros financeiros, notificacoes, usuarios, integracoes e aparencia conforme permissao.
2. **Given** que o Administrador convida ou edita um usuario, **When** salva o perfil de acesso, **Then** as permissoes do usuario sao atualizadas conforme matriz RBAC oficial.
3. **Given** que o Tecnico acessa Configuracoes, **When** a tela carrega, **Then** ve apenas seus proprios dados e preferencias autorizadas, sem acesso a usuarios, parametros financeiros ou configuracoes globais.
4. **Given** que uma alteracao afeta permissoes, **When** ela e salva, **Then** a navegacao e os guards passam a refletir o novo acesso.

---

### User Story 5 - Relatorios e Visualizador funcionam em modo leitura (Priority: P3)

Como Administrador, Financeiro, Projetos ou Visualizador, o usuario acessa Relatorios para consultar indicadores e exportacoes permitidas, sem poder alterar dados quando estiver em perfil somente leitura.

**Why this priority**: O perfil Visualizador precisa de uma experiencia util sem escrita, e os demais perfis precisam consultar resultados consolidados por dominio.

**Independent Test**: Fazer login como Visualizador, acessar Relatorios e confirmar que filtros e visualizacoes funcionam, mas nenhuma acao de escrita aparece ou e executavel.

**Acceptance Scenarios**:

1. **Given** que existem dados financeiros, comerciais e operacionais, **When** o usuario acessa Relatorios, **Then** visualiza apenas categorias permitidas pelo seu perfil.
2. **Given** que o Visualizador acessa Relatorios, **When** aplica filtros, **Then** os resultados sao atualizados sem expor comandos de criacao, edicao ou exclusao.
3. **Given** que exportacoes recentes existem, **When** o usuario abre a lista, **Then** visualiza status de exportacao real; se nao houver gerador ativo, a acao de exportar deve ficar pendente de integracao ou indisponivel com mensagem clara.

---

### User Story 6 - Navegacao nao exibe placeholders nem acessos indevidos (Priority: P3)

Como usuario autenticado de qualquer perfil, a navegacao lateral mostra apenas rotas autorizadas, e qualquer tentativa de acesso direto a uma rota sem permissao redireciona para uma tela permitida.

**Why this priority**: Fecha a experiencia por perfil e evita que rotas migradas exponham dados fora do escopo do usuario.

**Independent Test**: Executar login com todos os perfis de teste, comparar sidebar, acesso direto por URL e ausencia da tela "Modulo Nao Migrado" para rotas autorizadas em escopo.

**Acceptance Scenarios**:

1. **Given** qualquer perfil autenticado, **When** a aplicacao carrega, **Then** a sidebar mostra somente telas com permissao de leitura.
2. **Given** que o usuario acessa uma rota autorizada em escopo, **When** a pagina carrega, **Then** nunca ve a tela generica de modulo nao migrado.
3. **Given** que o usuario acessa diretamente uma rota sem permissao, **When** o guard avalia o perfil, **Then** o usuario e redirecionado para uma rota permitida antes de qualquer dado da rota bloqueada ser exibido.

### Edge Cases

- Perfil sem dados no modulo: a tela mostra estado vazio explicito por secao, nunca valores ficticios.
- Falha de carregamento: a tela mostra erro recuperavel e opcao de tentar novamente.
- Permissao de escrita ausente: comandos de criar, editar, excluir, pagar, receber, alocar, convidar, renovar ou configurar nao sao renderizados e tambem sao rejeitados pela camada de dados.
- Acao destrutiva: exige confirmacao explicita e gera registro de auditoria.
- Status vencido: deve ser derivado pela data atual quando aplicavel, evitando inconsistencia manual.
- Integracao externa ausente: nenhuma tela deve fingir envio de e-mail, emissao de boleto, upload/download ou exportacao concluida.
- Dados sensiveis: Tecnico e Visualizador nao veem valores financeiros, custo/hora, configuracoes globais ou dados de usuarios alem do permitido.
- Escrita com falha: a tela mantem os dados anteriores, preserva o formulario preenchido quando possivel, mostra mensagem recuperavel e permite nova tentativa sem duplicar registros.
- Integracao externa parcialmente solicitada: o registro de dominio permanece consistente e a pendencia fica registrada em status proprio (`Pendente de integracao`, `Indisponivel` ou equivalente), sem alterar o status principal para sucesso.
- Registro vinculado a entidade ausente/inativa: a tela exibe o registro com indicador de vinculo indisponivel/inativo e bloqueia novas acoes que dependam desse vinculo ate que ele seja corrigido ou reativado.
- Duplicidade financeira/comercial: uma cobranca vinculada a um lancamento existente nao pode gerar outro lancamento para o mesmo recebivel; o sistema deve reutilizar o vinculo ou rejeitar a duplicidade.
- Permissao alterada durante sessao ativa: apos mudanca de perfil/status, a proxima leitura de permissoes deve atualizar a sidebar e redirecionar o usuario caso a rota atual deixe de ser permitida.
- Empty states por tipo de secao: cards numericos mostram zero e rotulo "Sem dados no periodo"; tabelas/listas mostram titulo e descricao de estado vazio; graficos mostram area vazia com mensagem; previews de relatorio mostram orientacao para ajustar filtros.
- Filtros sem resultado: tabelas/listas mostram "Nenhum resultado encontrado"; graficos/cards zeram apenas o recorte filtrado; relatorios exibem preview vazio e mantem filtros editaveis.

## Regras Complementares de Readiness

### Matriz minima de seeds por perfil

| Perfil tecnico | Rotas que devem ter dados iniciais validaveis |
|---|---|
| Administrador | Todas as rotas em escopo, incluindo configuracoes globais e usuarios |
| Financeiro | `/fluxo-caixa`, `/contas-pagar`, `/contas-receber`, `/cobrancas`, `/relatorios` financeiro |
| Comercial | `/clientes`, `/propostas`, `/contratos`, `/cobrancas` |
| Projetos | `/projetos`, `/equipe`, `/relatorios` operacional |
| Tecnico | `/projetos`, `/equipe` limitada, `/configuracoes` proprias |
| Visualizador | `/relatorios` permitido e rotas de leitura ja autorizadas |

### Resultado esperado para integracoes externas ausentes

| Acao | Resultado sem integracao configurada |
|---|---|
| Enviar proposta por e-mail | Status de envio fica `Indisponivel` ou `Pendente de integracao`; proposta nao vira enviada por falso sucesso |
| Enviar lembrete de cobranca | `lembrete_status` fica `Indisponivel` ou `Pendente`; nenhuma mensagem e registrada como enviada |
| Emitir boleto | `boleto_status` fica `Nao configurado` ou `Indisponivel`; nenhuma URL falsa e criada |
| Anexar documento | Documento fica `Pendente`/`Indisponivel` quando storage/upload real nao existir; `arquivo_url` permanece nulo |
| Exportar relatorio | Exportacao fica `Indisponivel` ou `Pendente`; nenhum PDF/CSV falso e criado |

### Ownership de cobrancas

`cobrancas` e modulo compartilhado. O Comercial pode criar/acompanhar cobrancas vinculadas a clientes, contratos, lembretes e status comercial. O Financeiro controla registro de pagamento, conciliacao com `lancamentos`, cancelamento financeiro e dados monetarios completos. Administrador pode executar ambos os conjuntos. Quando um usuario tiver permissao de leitura em `cobrancas` mas nao de escrita financeira, acoes de pagamento/conciliacao nao aparecem e sao rejeitadas pela camada de dados.

### Fonte unica de status vencido

`Vencido` e sempre estado de exibicao derivado por data atual quando o registro esta pendente e `data_vencimento < current_date`. Essa regra vale para `lancamentos` financeiros, `cobrancas` e qualquer badge de UI. Rotinas e RPCs nao devem persistir `Vencido` como fonte primaria quando a situacao pode ser calculada.

### Privacidade e classificacao de dados

Dados pessoais identificaveis incluem nome, e-mail, telefone, documento, endereco, avatar e preferencias de usuario. Dados sensiveis de negocio incluem valores financeiros, custo/hora, documentos, parametros financeiros globais, perfis de acesso e status de usuarios. Tecnico e Visualizador recebem somente campos necessarios ao seu fluxo; campos restritos devem ser omitidos da resposta, nao apenas escondidos visualmente.

### Acessibilidade e responsividade

As telas migradas devem preservar a hierarquia visual dos HTML legados, mas tambem devem definir rotulos acessiveis para botoes/controles, ordem de foco previsivel, contraste suficiente, estados visiveis de foco e uso sem depender apenas de cor. As telas devem funcionar em desktop e mobile, com tabelas/kanban/cards adaptados para leitura sem sobreposicao de texto ou controles.

### Performance por familia de rota

| Familia | Meta de carregamento do conteudo principal |
|---|---|
| Financeiro | Ate 3 s para cards, grafico principal e primeira pagina de tabela |
| Comercial | Ate 3 s para metricas, tabela principal e detalhe sob demanda |
| Equipe | Ate 3 s para metricas, tabela e capacidade inicial |
| Relatorios | Ate 3 s para categorias e preview filtrado inicial |
| Configuracoes | Ate 2 s para dados proprios; ate 3 s para abas administrativas |

### Relacao entre `alocacoes_projeto` e `alocacoes_equipe`

`alocacoes_projeto` continua sendo a fonte de autorizacao minima para o Tecnico enxergar projetos e tarefas. `alocacoes_equipe` e a fonte operacional de capacidade, historico e percentual de alocacao. Quando ambas existirem para o mesmo usuario/projeto, a permissao de leitura do Tecnico exige vinculo em `alocacoes_projeto`; dados de capacidade e historico vem de `alocacoes_equipe`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE substituir `Modulo Nao Migrado` por telas funcionais para todas as rotas em escopo.
- **FR-002**: O sistema DEVE carregar indicadores, tabelas, graficos, detalhes e historicos das telas em escopo a partir de dados persistidos; nenhum valor de dominio pode permanecer codificado como mock.
- **FR-003**: O sistema DEVE aplicar a matriz RBAC por perfil tecnico: Administrador, Financeiro, Projetos, Comercial, Tecnico e Visualizador.
- **FR-003A**: O sistema DEVE usar os arquivos HTML correspondentes em `reference/legacy-html/` como fonte principal de layout, componentes, hierarquia visual e comportamento esperado de cada tela em escopo.
- **FR-004**: O sistema DEVE manter a navegacao lateral sincronizada com as permissoes reais de leitura de cada usuario.
- **FR-005**: O sistema DEVE impedir acesso direto a rotas sem permissao de leitura antes de exibir qualquer dado da rota bloqueada.
- **FR-006**: O sistema DEVE implementar Fluxo de Caixa com metricas, grafico, previsoes, tabela de movimentacoes, filtros e cadastro de receita/despesa para perfis autorizados.
- **FR-007**: O sistema DEVE implementar Contas a Pagar com metricas, vencimentos, tabela, cadastro de conta, confirmacao de pagamento e filtros por status/fornecedor.
- **FR-008**: O sistema DEVE implementar Contas a Receber com metricas, vencimentos, receita por cliente, tabela, cadastro de fatura, cobranca e registro de recebimento.
- **FR-009**: O sistema DEVE implementar Propostas com metricas, tabela, detalhe, criacao, envio/pendencia de envio e atualizacao de status.
- **FR-010**: O sistema DEVE implementar Contratos com metricas, tabela, detalhe, criacao, renovacao, acompanhamento de vigencia e anexos quando houver suporte real.
- **FR-011**: O sistema DEVE implementar Cobrancas com metricas, filtro, tabela, detalhe, registro de pagamento, lembrete e emissao/pendencia de boleto conforme integracoes disponiveis.
- **FR-012**: O sistema DEVE implementar Equipe com metricas, tabela de membros, alocacao por projeto, capacidade, cadastro/edicao/alocacao para perfis autorizados e visualizacao limitada para Tecnico.
- **FR-013**: O sistema DEVE implementar Relatorios com filtros, categorias por perfil, historico de exportacoes e estados honestos para exportacao indisponivel ou pendente.
- **FR-014**: O sistema DEVE implementar Configuracoes com abas de dados gerais, financeiro, notificacoes, usuarios, integracoes e aparencia para Administrador, e uma visao restrita de dados proprios para Tecnico.
- **FR-015**: O sistema DEVE validar entradas obrigatorias, formatos, valores monetarios, datas e vinculos antes de persistir alteracoes.
- **FR-016**: O sistema DEVE exibir estados de carregamento, vazio e erro recuperavel em todas as telas em escopo.
- **FR-017**: O sistema DEVE auditar acoes destrutivas e alteracoes sensiveis: exclusoes, inativacoes, renovacoes criticas, mudanca de perfil de acesso e alteracao de parametros financeiros globais.
- **FR-018**: O sistema DEVE manter seeds/dados iniciais reproduziveis por reset local para que cada perfil de teste tenha ao menos um fluxo validavel nas telas que pode acessar.
- **FR-019**: O sistema DEVE proteger dados sensiveis por perfil, incluindo valores financeiros, custo de equipe, parametros globais, documentos e dados de outros usuarios.
- **FR-020**: O sistema DEVE atualizar indicadores e listas apos uma acao de escrita bem-sucedida, sem exigir recarregamento manual da aplicacao.
- **FR-021**: O sistema DEVE popular seeds por perfil e por rota conforme a matriz minima de seeds por perfil definida nesta spec.
- **FR-022**: O sistema DEVE tratar cada integracao externa ausente conforme a tabela de resultado esperado, sem gravar sucesso simulado.
- **FR-023**: O sistema DEVE aplicar o ownership compartilhado de `cobrancas`, separando acoes comerciais de acoes financeiras.
- **FR-024**: O sistema DEVE derivar `Vencido` em tempo de consulta/exibicao para lancamentos, cobrancas e badges correlatos.
- **FR-025**: O sistema DEVE omitir das respostas de dados os campos restritos por perfil, nao apenas oculta-los na interface.
- **FR-026**: O sistema DEVE definir e aplicar estados vazios e resultados de filtro sem dados por tipo de secao: cards, tabelas/listas, graficos e previews.
- **FR-027**: O sistema DEVE preservar estado anterior e evitar duplicidade quando uma escrita falhar ou uma integracao ficar parcialmente pendente.
- **FR-028**: O sistema DEVE atualizar permissao/navegacao apos mudanca de perfil ou status de usuario durante uma sessao ativa.
- **FR-029**: O sistema DEVE tratar vinculos ausentes/inativos sem quebrar a tela e sem permitir novas acoes dependentes do vinculo invalido.
- **FR-030**: O sistema DEVE impedir duplicidade entre cobrancas e lancamentos quando ambos representarem o mesmo recebivel.
- **FR-031**: O sistema DEVE atender aos requisitos minimos de acessibilidade descritos nesta spec para todos os controles interativos migrados.
- **FR-032**: O sistema DEVE atender aos requisitos responsivos descritos nesta spec em desktop e mobile.
- **FR-033**: O sistema DEVE cumprir as metas de performance por familia de rota definidas nesta spec.
- **FR-034**: O sistema DEVE manter `alocacoes_projeto` como fonte de autorizacao de projetos/tarefas do Tecnico e `alocacoes_equipe` como fonte operacional de capacidade/historico.

### Key Entities *(include if feature involves data)*

- **Lancamento de Fluxo de Caixa**: Movimentacao de entrada ou saida que compoe saldo, graficos e previsoes financeiras.
- **Conta a Pagar**: Obrigacao com fornecedor, vencimento, valor, categoria, status e pagamento.
- **Conta a Receber**: Recebivel de cliente, vencimento, valor, categoria, status e data de recebimento.
- **Cobranca**: Registro cobrado do cliente, vinculado ou nao a contrato, com status, valor, vencimento e historico de lembretes/pagamentos.
- **Proposta**: Oferta comercial vinculada a cliente, com valor, status, envio e possivel origem de contrato.
- **Contrato**: Acordo firmado com cliente, vigencia, valor recorrente, status, documentos e cobrancas relacionadas.
- **Documento**: Anexo associado a contrato, proposta ou tarefa, com nome, tipo e vinculo ao registro.
- **Membro de Equipe**: Pessoa operacional com funcao, habilidades, status, capacidade e possivel vinculo com usuario do sistema.
- **Alocacao de Equipe**: Relacao entre membro, projeto, periodo e percentual de alocacao.
- **Apontamento de Horas**: Registro de tempo dedicado por membro a uma tarefa ou projeto.
- **Relatorio/Exportacao**: Consulta ou arquivo gerado a partir de filtros, categoria, formato, status e usuario solicitante.
- **Configuracao da Empresa**: Dados gerais, parametros financeiros, notificacoes e preferencias globais.
- **Perfil/Permissao**: Regras que determinam leitura e escrita por modulo para cada usuario.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das rotas em escopo deixam de renderizar a tela "Modulo Nao Migrado" para usuarios com permissao de leitura.
- **SC-002**: 0 valores ficticios/codificados permanecem visiveis nas telas em escopo; indicadores, tabelas, graficos e detalhes refletem dados persistidos.
- **SC-003**: 100% dos perfis de teste visualizam somente as telas permitidas na sidebar e sao redirecionados ao acessar rotas sem permissao.
- **SC-004**: Cada tela em escopo carrega seu conteudo principal em ate 3 segundos com o volume de dados inicial do projeto.
- **SC-005**: 100% das acoes de escrita permitidas persistem dados e permanecem consistentes apos recarregar a tela.
- **SC-006**: 100% das acoes de escrita proibidas por perfil ficam ocultas na interface e sao bloqueadas pela camada de dados.
- **SC-007**: 100% das secoes sem dados exibem estado vazio claro em vez de mock ou tela em branco.
- **SC-008**: 100% das acoes destrutivas e alteracoes sensiveis em escopo geram registro de auditoria.
- **SC-009**: Visualizador consegue consultar relatorios permitidos sem executar nenhuma acao de escrita.
- **SC-010**: Tecnico acessa Equipe e Configuracoes apenas em modo restrito, sem visualizar dados financeiros, custo de equipe ou configuracoes globais.
- **SC-011**: 100% dos perfis tecnicos possuem dados iniciais suficientes para validar pelo menos uma rota permitida em cada familia funcional que acessam.
- **SC-012**: 100% das acoes dependentes de integracao externa ausente retornam estado pendente/indisponivel documentado, sem criar artefato ou envio falso.
- **SC-013**: 100% das respostas de dados para Tecnico e Visualizador omitem campos classificados como restritos para esses perfis.
- **SC-014**: 100% das telas em escopo possuem requisito de estado vazio e filtro sem resultado por tipo de secao usado na tela.
- **SC-015**: 100% das telas em escopo podem ser usadas em desktop e mobile sem sobreposicao de texto/controles e com foco visivel em controles interativos.

## Assumptions

- Os arquivos HTML em `reference/legacy-html/` sao a referencia principal de layout, componentes, hierarquia visual e comportamento esperado para os modulos restantes.
- `docs/telas.md` e usado apenas como documentacao auxiliar para rotas, objetivos e acesso por perfil, nao como fonte principal de exemplo visual.
- As personas e perfis tecnicos descritos em `docs/personas.md` sao a fonte de verdade da matriz RBAC.
- As telas ja migradas (`Dashboard`, `Projetos`, `Clientes`) permanecem fora do rework visual desta feature, exceto por ajustes de navegacao ou integracao necessarios para cruzar dados com os novos modulos.
- As acoes que dependem de servicos externos ainda nao configurados devem ser representadas como pendentes/indisponiveis, nunca como sucesso simulado.
- Relatorios podem entregar consultas e historico de exportacoes antes de haver geracao automatica completa de arquivos, desde que a interface seja clara sobre o estado real.
- O Visualizador e um perfil auxiliar somente leitura e nao substitui as personas de negocio principais.
- A implementacao pode exigir uma nova chamada de refresh de perfil/permissoes apos alteracao administrativa de usuario; ate que essa chamada ocorra, a proxima navegacao protegida deve reavaliar o acesso.
