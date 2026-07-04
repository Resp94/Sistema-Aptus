# Feature Specification: Exportar Relatorios

**Feature Branch**: `008-exportar-relatorios`

**Created**: 2026-07-04

**Status**: Draft

**Input**: User description: "Incluir na pagina Relatorios a exportacao imediata de relatorios completos em PDF e CSV, por categoria selecionada, com data inicial e data final, historico com download posterior, validade de 12 meses e respeito as personas/capacidades de exportacao."

## Clarifications

### Session 2026-07-04

- Q: Quem pode ver e baixar exportacoes anteriores no historico? → A: Administrador ve e baixa todas; Financeiro e Projetos veem e baixam somente as proprias exportacoes.
- Q: Qual conteudo minimo define um relatorio completo exportado? → A: Resumo executivo e linhas detalhadas da categoria.
- Q: Qual e o periodo maximo permitido por exportacao? → A: Periodo maximo de 12 meses por exportacao.
- Q: Como o periodo deve afetar cada categoria de relatorio? → A: Financeiro/DRE usam movimentacoes do periodo; Clientes/Projetos usam snapshot atual com metricas de atividade no periodo.
- Q: Como o formato CSV deve representar resumo e detalhes? → A: ZIP com CSV de resumo e CSV de detalhes quando a categoria tiver ambos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Exportar relatorio completo imediatamente (Priority: P1)

Como usuario autorizado a exportar relatorios, quero selecionar uma categoria, informar data inicial e data final, escolher PDF ou CSV e receber o arquivo pronto para download imediato.

**Why this priority**: Esta e a entrega principal da funcionalidade. Sem download imediato, a tela continua no estado atual de solicitacao pendente/indisponivel e nao resolve a necessidade operacional.

**Independent Test**: Pode ser testada por um usuario com permissao de exportacao abrindo Relatorios, escolhendo uma categoria permitida, informando periodo valido, selecionando PDF ou CSV e concluindo com arquivo baixavel.

**Acceptance Scenarios**:

1. **Given** um Administrador em Relatorios com categoria selecionada, **When** informa um periodo valido, escolhe PDF e confirma a exportacao, **Then** o sistema gera um PDF completo da categoria selecionada e disponibiliza download imediato.
2. **Given** um usuario Financeiro em Relatorios com categoria financeira permitida, **When** informa data inicial e data final validas, escolhe CSV e confirma, **Then** o sistema gera um CSV completo apenas daquela categoria e periodo.
3. **Given** um usuario Projetos em Relatorios com categoria Projetos selecionada, **When** exporta o relatorio, **Then** o arquivo inclui dados completos da categoria Projetos respeitando o periodo informado.

---

### User Story 2 - Baixar exportacoes anteriores (Priority: P2)

Como usuario autorizado, quero ver o historico de exportacoes e baixar novamente arquivos anteriores enquanto ainda estiverem validos.

**Why this priority**: O historico transforma a exportacao em artefato operacional reutilizavel, evita regerar arquivos sem necessidade e preserva rastreabilidade.

**Independent Test**: Pode ser testada gerando uma exportacao e, em seguida, baixando o mesmo arquivo pelo historico sem refazer a geracao.

**Acceptance Scenarios**:

1. **Given** uma exportacao concluida ha menos de 12 meses, **When** o usuario autorizado aciona Download no historico, **Then** o sistema disponibiliza novamente o arquivo gerado.
2. **Given** uma exportacao expirada, **When** o usuario visualiza o historico, **Then** o registro aparece como expirado e o download nao fica disponivel.
3. **Given** uma exportacao em falha, **When** o usuario visualiza o historico, **Then** o status indica falha e nao oferece link de arquivo inexistente.
4. **Given** um Administrador, **When** acessa o historico de exportacoes, **Then** consegue ver e baixar exportacoes validas de todos os usuarios.
5. **Given** um usuario Financeiro ou Projetos, **When** acessa o historico de exportacoes, **Then** consegue ver e baixar apenas exportacoes proprias ainda validas.

---

### User Story 3 - Respeitar personas e leitura sem exportacao (Priority: P3)

Como usuario com acesso limitado, quero que a tela diferencie leitura de relatorios e extracao de arquivos, para que somente personas autorizadas exportem.

**Why this priority**: A exportacao e uma acao sensivel porque materializa dados empresariais em arquivos. A UX e a autorizacao precisam seguir a matriz de capacidades definida para as personas.

**Independent Test**: Pode ser testada entrando com cada persona e verificando acesso a Relatorios, visibilidade do botao de exportacao e bloqueio real quando a persona nao tem permissao.

**Acceptance Scenarios**:

1. **Given** um Visualizador com acesso de leitura a Relatorios, **When** abre a tela, **Then** consegue consultar dados permitidos, mas nao consegue exportar PDF ou CSV.
2. **Given** um Comercial ou Tecnico sem capacidade de exportar relatorios, **When** tenta acessar exportacao por qualquer caminho, **Then** o sistema bloqueia a acao e nao gera arquivo.
3. **Given** um Administrador, Financeiro ou Projetos com capacidade de exportacao, **When** abre uma categoria permitida para seu perfil, **Then** consegue exportar somente categorias autorizadas para esse perfil.

### Edge Cases

- Data inicial posterior a data final deve impedir a exportacao e explicar o erro antes de gerar qualquer arquivo.
- Periodo maior que 12 meses deve impedir a exportacao e orientar o usuario a reduzir o intervalo.
- Periodo sem dados deve gerar arquivo valido com cabecalho, periodo, categoria e mensagem de ausencia de registros.
- Clientes e Projetos devem continuar exibindo a situacao atual dos registros no snapshot, mesmo quando a atividade do periodo for zero.
- Categoria nao permitida para a persona deve ser bloqueada, mesmo que o usuario tente reutilizar uma URL, chamada ou registro antigo.
- Arquivo expirado deve permanecer rastreavel no historico, mas sem download.
- Falha durante a geracao deve registrar status de falha e nao apresentar sucesso simulado.
- Exportacoes duplicadas para mesma categoria, periodo e formato podem existir como eventos separados, pois representam solicitacoes feitas em momentos diferentes.
- Nomes de arquivos devem ser claros para o usuario e indicar categoria, periodo e formato.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST permitir que usuarios autorizados exportem relatorios completos da categoria selecionada em PDF.
- **FR-002**: O sistema MUST permitir que usuarios autorizados exportem relatorios completos da categoria selecionada em CSV.
- **FR-002a**: Quando a exportacao CSV tiver resumo executivo e linhas detalhadas, o sistema MUST entregar um pacote baixavel contendo um CSV de resumo e um CSV de detalhes.
- **FR-003**: O sistema MUST exigir data inicial e data final para toda exportacao manual.
- **FR-004**: O sistema MUST iniciar o modal de exportacao com data inicial no primeiro dia do mes atual e data final na data atual.
- **FR-005**: O sistema MUST validar que a data inicial seja menor ou igual a data final antes de concluir a exportacao.
- **FR-005a**: O sistema MUST limitar cada exportacao a um periodo maximo de 12 meses.
- **FR-006**: O sistema MUST aplicar o periodo informado aos dados exportados, nao apenas ao nome do arquivo ou ao historico.
- **FR-006a**: Para Financeiro e DRE, o periodo informado MUST filtrar as movimentacoes consideradas no relatorio.
- **FR-006b**: Para Clientes e Projetos, o relatorio MUST combinar snapshot atual dos registros com metricas de atividade do periodo informado.
- **FR-007**: O sistema MUST exportar apenas a categoria selecionada pelo usuario, nao um consolidado com todas as categorias.
- **FR-008**: O sistema MUST gerar relatorios completos, com dados detalhados suficientes para analise operacional, e nao apenas a pre-visualizacao resumida exibida na tela.
- **FR-008a**: Todo relatorio exportado MUST conter um resumo executivo e linhas detalhadas da categoria selecionada.
- **FR-008b**: O PDF MUST priorizar leitura humana com resumo executivo antes dos detalhes; o CSV MUST preservar resumo e detalhes em arquivos tabulares separados quando ambos existirem.
- **FR-009**: O sistema MUST registrar cada exportacao no historico com categoria, formato, periodo, status, usuario solicitante, data de geracao e data de expiracao.
- **FR-010**: O sistema MUST permitir download imediato quando a exportacao for concluida com sucesso.
- **FR-011**: O sistema MUST permitir baixar novamente exportacoes anteriores enquanto elas estiverem dentro da validade.
- **FR-012**: O sistema MUST considerar exportacoes validas por 12 meses a partir da data de geracao.
- **FR-013**: O sistema MUST exibir exportacoes vencidas como expiradas e bloquear novo download do arquivo expirado.
- **FR-014**: O sistema MUST registrar falhas de exportacao sem apresentar arquivo ou sucesso simulado.
- **FR-015**: O sistema MUST manter Visualizador como perfil de leitura sem capacidade de exportar PDF ou CSV.
- **FR-016**: O sistema MUST permitir exportacao para Administrador, Financeiro e Projetos somente quando a persona possuir capacidade de exportar relatorios.
- **FR-017**: O sistema MUST impedir exportacao por Comercial, Tecnico ou qualquer perfil sem capacidade de exportar relatorios.
- **FR-018**: O sistema MUST respeitar a categoria de relatorio permitida para cada persona ao gerar e ao baixar arquivos.
- **FR-019**: O sistema MUST bloquear download historico quando o usuario nao tiver permissao atual para acessar aquela exportacao.
- **FR-019a**: O sistema MUST permitir que Administrador veja e baixe exportacoes validas de todos os usuarios.
- **FR-019b**: O sistema MUST limitar Financeiro e Projetos a ver e baixar somente exportacoes proprias.
- **FR-020**: O sistema MUST apresentar mensagem clara quando uma exportacao falhar, expirar, nao tiver dados no periodo ou for bloqueada por permissao.
- **FR-021**: O sistema MUST evitar expor links publicos permanentes para arquivos de relatorio.
- **FR-022**: O sistema MUST manter o historico de exportacoes ordenado pelas solicitacoes mais recentes primeiro.
- **FR-023**: O sistema MUST diferenciar visualmente no historico os estados Pronto, Falhou e Expirado.
- **FR-024**: O sistema MUST preservar a separacao entre visualizar relatorios e exportar arquivos, para que leitura de Relatorios nao implique direito de extracao.

### Key Entities *(include if feature involves data)*

- **Exportacao de Relatorio**: Registro de uma solicitacao de arquivo gerado. Inclui categoria, formato, periodo, status, usuario solicitante, data de geracao, data de expiracao e referencia ao arquivo.
- **Arquivo de Relatorio**: Artefato baixavel em PDF ou CSV criado a partir de uma exportacao concluida. Possui validade de 12 meses.
- **Filtro de Periodo**: Data inicial e data final usadas para limitar os dados do relatorio exportado.
- **Categoria de Relatorio**: Grupo de dados selecionado pelo usuario para exportacao, como Financeiro, DRE, Clientes ou Projetos, respeitando o escopo permitido da persona.
- **Persona Autorizada**: Perfil que pode exportar relatorios conforme sua capacidade atual; Administrador, Financeiro e Projetos sao os perfis previstos para exportacao, enquanto Visualizador permanece somente leitura.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das exportacoes bem-sucedidas disponibilizam download imediato ao usuario em ate 10 segundos para volumes operacionais comuns.
- **SC-002**: 100% dos registros de historico de exportacao exibem categoria, formato, periodo, status e data de geracao.
- **SC-003**: 100% das exportacoes prontas com menos de 12 meses permitem novo download por usuario ainda autorizado.
- **SC-004**: 0 exportacoes expiradas oferecem download de arquivo vencido.
- **SC-005**: 0 usuarios sem capacidade de exportar relatorios conseguem gerar ou baixar arquivos por qualquer fluxo de UI.
- **SC-006**: Usuarios autorizados conseguem concluir uma exportacao PDF ou CSV em ate 4 interacoes principais: abrir modal, confirmar periodo/formato, gerar e baixar.
- **SC-007**: 100% dos cenarios sem dados geram resultado compreensivel, sem erro tecnico e sem arquivo vazio sem contexto.
- **SC-008**: Durante validacao por persona, Administrador, Financeiro e Projetos conseguem exportar categorias permitidas; Visualizador apenas le; Comercial e Tecnico nao exportam.
- **SC-009**: Durante validacao de historico, Administrador acessa exportacoes validas de todos os usuarios, enquanto Financeiro e Projetos acessam somente as proprias.
- **SC-010**: 100% dos arquivos gerados contem resumo executivo identificavel e linhas detalhadas, exceto quando o periodo nao tem registros, caso em que o arquivo informa explicitamente a ausencia de dados.
- **SC-011**: 100% das tentativas com periodo superior a 12 meses sao bloqueadas antes da geracao do arquivo.
- **SC-012**: 100% das exportacoes CSV com resumo e detalhes entregam ambos os conjuntos de dados em arquivos tabulares separados no mesmo download.

## Assumptions

- A matriz de capacidades nomeadas da feature 007 permanece a fonte de verdade para decidir quem pode exportar.
- Visualizador continua tendo leitura restrita de Relatorios e Configuracoes proprias, mas nenhuma capacidade de exportacao.
- O historico anterior de exportacoes indisponiveis pode coexistir com os novos registros prontos, falhos ou expirados.
- A exportacao inicial cobre categorias existentes na tela Relatorios; novas categorias futuras devem aderir ao mesmo contrato de periodo, historico e permissao.
- A validade de 12 meses conta a partir da data/hora em que o arquivo foi gerado.
- Arquivos expirados podem permanecer registrados para auditoria, mas nao ficam disponiveis para download.
- O formato CSV e orientado a planilhas; o formato PDF e orientado a leitura e compartilhamento humano.
