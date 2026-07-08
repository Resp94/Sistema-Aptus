# Feature Specification: Padrao Enterprise Relatorios

**Feature Branch**: `011-padrao-enterprise-relatorios`

**Created**: 2026-07-08

**Status**: Draft

**Input**: User description: "Nao deve haver preview e o relatorio precisa seguir um padrao enterprise, mantendo a exportacao fora de producao por enquanto em fase de deliberacao."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Baixar relatorio executivo sem preview (Priority: P1)

Como usuario operacional ou gestor, quero baixar o relatorio executivo diretamente no meu dispositivo para que eu possa compartilhar ou arquivar o documento sem troca de contexto no navegador.

**Why this priority**: O comportamento atual compromete a confianca na exportacao e torna o fluxo inconsistente para um artefato que precisa parecer oficial.

**Independent Test**: Pode ser testado de forma isolada ao solicitar um PDF de qualquer categoria e verificar que o navegador inicia o download sem abrir o conteudo em preview e sem substituir a tela de relatorios.

**Acceptance Scenarios**:

1. **Given** que o usuario solicita um relatorio em PDF, **When** a exportacao fica pronta e ele escolhe baixar o arquivo, **Then** o sistema inicia o download direto do documento sem abrir preview no navegador.
2. **Given** que o usuario esta na pagina de relatorios, **When** ele baixa um PDF a partir do historico de exportacoes, **Then** a pagina permanece utilizavel e o arquivo e entregue como download.

---

### User Story 2 - Receber documento apresentavel para negocio (Priority: P2)

Como gestor, quero que o PDF exportado tenha linguagem, hierarquia visual e estrutura adequadas para uso com diretoria, clientes ou auditoria, para que o documento pareca oficial e autoexplicativo.

**Why this priority**: O principal valor do formato PDF nesta funcionalidade e a apresentacao executiva. Se o documento expoe termos tecnicos ou serializacao bruta, ele falha no objetivo central.

**Independent Test**: Pode ser testado de forma isolada ao gerar um PDF de uma categoria suportada e validar que o documento usa rotulos de negocio, valores legiveis e secoes coerentes sem chaves tecnicas aparentes.

**Acceptance Scenarios**:

1. **Given** que um relatorio PDF foi gerado com dados, **When** o usuario abre o arquivo baixado, **Then** ele encontra titulo, periodo, resumo executivo e detalhes apresentados em linguagem de negocio.
2. **Given** que o resumo do relatorio possui indicadores estruturados, **When** o PDF e montado, **Then** os indicadores aparecem como rotulos e valores finais, sem expor chaves tecnicas como `label` ou `valor`.

---

### User Story 3 - Entender claramente o papel de cada formato (Priority: P3)

Como usuario da area administrativa, quero distinguir o formato executivo do formato operacional para que eu escolha o arquivo correto sem ambiguidade sobre o que sera entregue.

**Why this priority**: A expectativa de padrao enterprise exige que o produto diferencie claramente um documento executivo de um extrato tecnico de dados.

**Independent Test**: Pode ser testado de forma isolada ao revisar a experiencia de exportacao e historico, confirmando que o PDF e tratado como documento executivo e que formatos tabulares nao sao apresentados como equivalentes a um relatorio enterprise.

**Acceptance Scenarios**:

1. **Given** que o usuario escolhe entre formatos de exportacao, **When** ele visualiza as opcoes disponiveis, **Then** o produto comunica o PDF como formato executivo e os formatos tabulares como exportacoes operacionais.
2. **Given** que existe um item de historico com formato tabular, **When** o usuario revisa esse item, **Then** ele nao encontra nomenclatura que induza a pensar que recebera um documento executivo em padrao enterprise.

---

### Edge Cases

- Como o sistema se comporta quando o relatorio nao possui dados no periodo selecionado? O PDF e CSV exibem a mensagem: "Nao ha dados disponiveis para o periodo selecionado. Selecione um intervalo diferente ou entre em contato com o administrador." O CSV usa header `Observacao` (nao `mensagem`) com essa mesma mensagem na celula.
- Como o sistema se comporta quando o usuario baixa um item historico cuja validade expirou? Itens expirados permanecem visiveis no historico com badge "Expirado" e botao de download desabilitado com tooltip informando a data de expiracao no formato DD/MM/AAAA: "Este relatorio expirou em DD/MM/AAAA. Gere um novo para o mesmo periodo."
- Como o sistema se comporta quando o documento possui labels com acentos, moeda e datas em PT-BR? Fonte Noto Sans embedada garante acentuacao completa. Fallback: se o embed falhar, usar StandardFonts.Helvetica com remocao de acentos e log de warning.
- Como o sistema se comporta quando um mesmo relatorio e baixado repetidamente por usuarios diferentes? Cada usuario gera seu proprio artefato (nova entrada no historico). Nao ha reuso de artefato entre usuarios — isso garante rastreabilidade individual.
- Como o sistema se comporta quando um usuario sem permissao `relatorios.exportar` tenta exportar? O botao "Exportar Relatorio" aparece desabilitado com tooltip "Voce nao tem permissao para exportar". A pre-visualizacao e o historico permanecem acessiveis (leitura).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST entregar relatorios PDF por download direto, sem abrir preview no navegador durante o fluxo normal de exportacao ou download pelo historico.
- **FR-002**: O sistema MUST manter a pagina de relatorios utilizavel apos o inicio de um download de PDF, sem substituir o contexto principal do usuario.
- **FR-003**: O sistema MUST apresentar o PDF como o formato executivo oficial dos relatorios exportados.
- **FR-004**: O sistema MUST renderizar titulos, metadados e secoes do PDF em PT-BR com acentuacao, datas e nomenclatura legiveis para usuarios de negocio.
- **FR-005**: O sistema MUST apresentar o resumo executivo com rotulos de negocio e valores finais, sem expor nomes de campos internos, chaves tecnicas ou serializacao bruta. A traducao de chaves internas para rotulos de negocio sera feita via mapa estatico por categoria na edge function (renderers.ts), conforme contrato [rotulos-negocio.md](./contracts/rotulos-negocio.md). Regra especial para `resumo`: usar o VALOR de `label` como rotulo de exibicao e o VALOR de `valor` como dado formatado — nunca expor as chaves `label` ou `valor` como texto.
- **FR-006**: O sistema MUST organizar o conteudo do PDF em secoes consistentes, no minimo contemplando identificacao do relatorio, periodo, resumo executivo e detalhes do periodo. A hierarquia visual deve seguir criterios mensuraveis: titulo 18pt Bold, subtitulos 14pt Bold, corpo 11pt Regular, margens 50pt, espacamento 16pt — aplicados identicamente a todas as categorias.
- **FR-007**: O sistema MUST fornecer uma mensagem de estado vazio apropriada quando nao houver dados para compor o relatorio, sem exibir artefatos tecnicos ou headers genericos. Mensagem padrao: "Nao ha dados disponiveis para o periodo selecionado. Selecione um intervalo diferente ou entre em contato com o administrador." Para CSV, o header de empty state deve ser `Observacao` (nao `mensagem`).
- **FR-008**: O sistema MUST aplicar um padrao visual consistente entre as categorias Financeiro, DRE, Clientes e Projetos, preservando a identidade do documento executivo mesmo quando o conteudo variar.
- **FR-009**: O sistema MUST diferenciar claramente documentos executivos de exportacoes tabulares, evitando apresentar formatos tabulares como se fossem equivalentes ao padrao enterprise.
- **FR-010**: O sistema MUST usar nomes de arquivo e rotulos de historico coerentes com o tipo de artefato entregue. Convencao: `relatorio-{categoria-slug}-{data_inicial}-{data_final}.pdf` para PDF executivo; `exportacao-{categoria-slug}-{data_inicial}-{data_final}.zip` para CSV operacional. No historico, badge "PDF" (azul) ou "CSV" (cinza) ao lado do nome.

### Key Entities *(include if feature involves data)*

- **Solicitacao de exportacao**: Pedido iniciado pelo usuario para gerar um artefato de relatorio com categoria, periodo e formato selecionados.
- **Artefato executivo**: Documento final em PDF voltado a leitura de negocio, com titulo, metadados, resumo executivo e detalhes.
- **Exportacao tabular**: Arquivo operacional voltado a manipulacao de dados, distinto do documento executivo.
- **Item de historico de exportacao**: Registro consultavel de uma exportacao ja gerada, incluindo categoria, periodo, formato, status e validade.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% dos testes de aceite do formato PDF, o download inicia sem abrir preview no navegador e a pagina permanece utilizavel (sem bloqueio de UI, sem navegacao forcada, toast desaparece em 3s). O download deve iniciar em ate 5 segundos apos o clique para volumes operacionais comuns (ate 500 linhas de detalhes).
- **SC-002**: Em 100% dos PDFs validados para Financeiro, DRE, Clientes e Projetos, nao ha exposicao de chaves tecnicas, nomes de campos internos ou serializacao bruta. Todos os rotulos conferem com o mapa definido em [rotulos-negocio.md](./contracts/rotulos-negocio.md).
- **SC-003**: Pelo menos 90% dos usuarios de teste identificam corretamente, sem orientacao adicional, qual formato representa o documento executivo e qual formato representa a exportacao operacional.
- **SC-004**: Em 100% dos cenarios sem dados, o documento apresenta mensagem de estado vazio compreensivel e apropriada ao contexto de negocio.

## Clarifications

### Session 2026-07-08

- Q: As correcoes de encoding, acentuacao e nomenclatura aplicam-se apenas ao PDF ou tambem ao CSV/ZIP? → A: Ambos os formatos (PDF + CSV) recebem correcoes de encoding, acentuacao e nomenclatura; apenas o PDF recebe o layout enterprise completo.
- Q: Qual estrategia de fonte para suportar acentuacao PT-BR no PDF (pdf-lib)? → A: Embeddar fonte TrueType Noto Sans (subset PT-BR) no bundle da edge function (~150-250KB adicionais).
- Q: Como traduzir chaves tecnicas internas (ex: label, valor) para rotulos de negocio no PDF? → A: Mapa estatico de traducao por categoria na edge function (renderers.ts) com dicionario chave_interna → rotulo_negocio.
- Q: Como o sistema deve se comportar quando o usuario tenta baixar um item do historico cuja validade expirou? → A: Exibir o item com badge/indicador "Expirado" e desabilitar o botao de download com tooltip explicativo.
- Q: Como a feature em fase de deliberacao deve ser exposta ao usuario final? → A: Feature visivel e funcional para todos os perfis, mas com indicador visual "Experimental"/"Beta" na UI de exportacao.

## Assumptions

- O PDF continuara sendo o formato oficial de apresentacao executiva desta funcionalidade.
- A renderizacao do PDF utilizara fonte TrueType Noto Sans (subset PT-BR) embedada no bundle da edge function para garantir suporte completo a acentuacao e caracteres latinos estendidos. Fallback: se o embed falhar, usar StandardFonts.Helvetica com remocao de acentos e log de warning.
- Exportacoes tabulares permanecem disponiveis para uso operacional, mas nao fazem parte do padrao enterprise de apresentacao — porem recebem correcoes de encoding (BOM UTF-8), acentuacao e headers legiveis neste escopo, usando os mesmos mapas de traducao do PDF conforme [rotulos-negocio.md](./contracts/rotulos-negocio.md).
- A feature permanece em fase de deliberacao e padronizacao, sem compromisso de entrada imediata em producao. Durante esta fase, a UI de exportacao exibe indicador visual "Experimental" / "Beta" visivel para todos os perfis APENAS na pagina de relatorios e no modal de exportacao — NAO no PDF gerado nem nos itens do historico.
- As categorias atuais de relatorio permanecem Financeiro, DRE, Clientes e Projetos durante este escopo.
- Acessibilidade do PDF (PDF/UA, contraste, texto alternativo) sera tratada em feature futura — nao faz parte deste escopo.
