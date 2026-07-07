# Feature Specification: Corrigir Advisors Supabase

**Feature Branch**: `010-corrigir-advisors-supabase`

**Created**: 2026-07-06

**Status**: Draft

**Input**: User description: "Gerar uma feature dedicada para corrigir os achados do Supabase Advisors, cobrindo riscos reais de seguranca e warnings de performance ligados a RLS/RPC, com validacao remota apos aplicacao."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fechar exposicoes indevidas detectadas pelos advisors (Priority: P1)

Como responsavel pelo sistema, quero corrigir exposicoes indevidas e lacunas de protecao apontadas pelos advisors do Supabase, para reduzir risco de acesso nao autorizado em producao.

**Why this priority**: Os achados de seguranca em funcoes privilegiadas e tabelas protegidas afetam diretamente a superficie de ataque do ambiente real.

**Independent Test**: Pode ser testada revisando os artefatos versionados, aplicando-os em ambiente controlado e confirmando que os advisors nao continuam reportando exposicoes indevidas ou tabelas protegidas sem politica.

**Acceptance Scenarios**:

1. **Given** uma tabela exposta com RLS habilitado e sem politica valida, **When** a correcao e aplicada, **Then** a tabela passa a ter politica coerente com seu modelo de acesso ou deixa de permanecer exposta fora do uso previsto.
2. **Given** uma funcao privilegiada que nao deveria estar disponivel para acesso publico, **When** a correcao e aplicada, **Then** sua execucao deixa de ficar aberta a papeis nao autorizados.
3. **Given** uma funcao privilegiada que precisa continuar existindo por desenho, **When** a feature e concluida, **Then** o acesso permitido, as guardas esperadas e a justificativa operacional ficam explicitamente documentados.

---

### User Story 2 - Reduzir warnings de performance que afetam RLS e RPC (Priority: P2)

Como responsavel pelo backend, quero corrigir warnings de performance ligados a policies e avaliacoes repetidas de identidade, para diminuir custo de consulta e evitar degradacao desnecessaria em fluxos protegidos por RLS e RPC.

**Why this priority**: Esses avisos nao sao o risco principal, mas afetam diretamente as camadas de autorizacao e leitura protegida que fazem parte do comportamento central do sistema.

**Independent Test**: Pode ser testada comparando os advisors antes e depois da aplicacao e verificando que os warnings ligados a `auth` em policies e combinacoes permissivas relevantes foram removidos ou reduzidos com justificativa registrada.

**Acceptance Scenarios**:

1. **Given** policies que reavaliam identidade por linha sem necessidade, **When** a correcao e aplicada, **Then** os advisors deixam de sinalizar esse padrao nos objetos ajustados.
2. **Given** conjuntos de policies sobre o mesmo recurso que geram warnings relevantes de execucao, **When** a feature e concluida, **Then** essas policies ficam consolidadas ou justificadas sem ambiguidade operacional.
3. **Given** um warning de performance sem impacto material no escopo de RLS ou RPC desta feature, **When** a triagem e concluida, **Then** ele permanece fora do escopo e essa exclusao fica registrada.

---

### User Story 3 - Validar o estado remoto apos a correcao (Priority: P3)

Como responsavel pela operacao, quero um runbook para validar os advisors no projeto remoto apos a aplicacao, para diferenciar correcao efetiva de drift, grant residual ou falso positivo operacional.

**Why this priority**: O estado remoto atual pode nao refletir fielmente a intencao do SQL versionado, entao a validacao pos-aplicacao precisa fazer parte do fluxo de conformidade.

**Independent Test**: Pode ser testada executando o runbook apos a aplicacao, registrando o estado dos advisors e classificando cada achado remanescente como resolvido, excecao intencional ou drift a investigar.

**Acceptance Scenarios**:

1. **Given** as correcoes versionadas aplicadas, **When** o runbook de validacao remota e executado, **Then** ele registra o resultado dos advisors antes e depois da mudanca.
2. **Given** um achado que persiste apos a aplicacao, **When** o runbook e seguido, **Then** o resultado identifica se a causa provavel e drift remoto, concessao residual ou excecao intencional.
3. **Given** uma excecao intencional aprovada, **When** a validacao termina, **Then** a excecao fica documentada com criterio claro para reavaliacao futura.

### Edge Cases

- O advisor continua acusando funcao `SECURITY DEFINER` mesmo apos restricao correta de grants, exigindo classificacao como possivel falso positivo ou estado remoto residual.
- Uma migration aplica com sucesso, mas o estado remoto continua divergente por overload antigo, grant residual ou assinatura nao coberta pela correcao versionada.
- Uma tabela protegida por RLS nao pode receber policy ampla sem violar o modelo de acesso, exigindo alternativa que preserve o comportamento esperado.
- Uma funcao `SECURITY DEFINER` possui dependencia viva, mas sua implementacao atual nao valida identidade, papel, capacidade, ownership ou outra guarda de negocio obrigatoria.
- A consolidacao de policies reduz warnings de performance, mas muda a legibilidade ou a auditabilidade do modelo de autorizacao.
- A consolidacao de policies permissivas altera de forma nao intencional o comportamento RBAC de um papel previamente valido.
- O estado remoto diverge do SQL versionado, fazendo com que a validacao pos-aplicacao mostre grants diferentes do que o repositório descreve.
- A correcao de um warning de performance em policy altera o comportamento de leitura ou escrita de um papel valido.
- Uma funcao possui multiplos overloads e apenas parte deles esta exposta indevidamente, exigindo correcao por assinatura exata.
- Um achado remanescente nao representa risco real, mas tambem nao pode ser descartado sem criterio de excecao documentado.
- O conjunto de correcao melhora os advisors, mas revela outra dependencia de conformidade em RPC ou RLS que precisa ser explicitamente fora de escopo desta feature.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O processo MUST tratar os achados de advisors ligados a seguranca como prioridade sobre tuning geral.
- **FR-002**: A feature MUST corrigir exposicoes indevidas de funcoes privilegiadas acessiveis por papeis nao previstos.
- **FR-003**: A feature MUST corrigir tabelas com RLS habilitado e sem politica coerente com o modelo de acesso aprovado.
- **FR-004**: A feature MUST preservar funcoes privilegiadas que forem referenciadas por código da aplicação ou outro objeto do banco (critério de dependência viva), desde que sua justificativa operacional e suas guardas esperadas fiquem documentadas. Funções sem dependência viva detectável devem ser corrigidas ou removidas.
- **FR-005**: A feature MUST corrigir warnings de performance que impactem diretamente policies de RLS ou fluxos de RPC no escopo desta feature.
- **FR-006**: A feature MUST revisar policies que avaliam identidade de forma repetitiva e substitui-las por padroes equivalentes mais eficientes quando isso nao alterar o comportamento esperado.
- **FR-007**: A feature MUST revisar warnings de policies permissivas sobre os mesmos papeis e acoes quando eles afetarem recursos centrais do modelo de autorizacao.
- **FR-008**: A feature MUST excluir explicitamente do escopo ajustes gerais de indice, chave estrangeira ou tuning nao relacionados a RLS ou RPC.
- **FR-009**: A feature MUST produzir artefatos versionados de correção como arquivos `.sql` individuais em `supabase/migrations/` para que o estado esperado do backend possa ser reproduzido de forma auditável e determinística.
- **FR-010**: A feature MUST incluir um runbook de validação remota pós-aplicação em `runbook-validacao.md` no diretório da feature, com passos para comparar o estado dos advisors antes e depois das mudanças.
- **FR-011**: O `runbook-validacao.md` MUST orientar a classificar achados remanescentes como resolvidos, drift remoto, concessão residual ou exceção intencional.
- **FR-012**: A feature MUST registrar criterios de excecao para qualquer achado mantido intencionalmente apos a triagem.
- **FR-013**: A feature MUST impedir que a conclusao declare conformidade se um risco real de seguranca continuar sem correcao ou sem excecao aprovada.
- **FR-014**: A feature MUST manter separadas a correcao estrutural do backend e a promocao operacional ampla tratada em outras features.
- **FR-015**: A feature MUST registrar a decisao operacional e os resultados da validacao remota na documentacao obrigatoria do projeto na mesma sessao de trabalho em que a mudanca for concluida.
- **FR-016**: A feature MUST mapear explicitamente os lints `rls_enabled_no_policy`, `anon_security_definer_function_executable`, `authenticated_security_definer_function_executable`, `auth_rls_initplan` e `multiple_permissive_policies` para os requisitos e criterios de triagem correspondentes.
- **FR-017**: O estado-alvo por papel MUST ser explicito: `anon` nao pode executar RPCs de negocio privilegiadas no escopo; `authenticated` so pode executar assinaturas explicitamente concedidas e validadas por dependencia viva e guardas internas; `service_role` pode manter acesso a objetos service-owned e rotinas internas que nao devem ficar expostas aos papeis de cliente.
- **FR-018**: Toda excecao de conformidade MUST registrar, no minimo, justificativa, impacto residual, gatilho de revisao e aprovador nomeado, em formato alinhado ao modelo de dados e a triagem da feature.
- **FR-019**: A reavaliacao de uma excecao MUST ser disparada por qualquer mudanca de grant, policy, assinatura de funcao, dependencia viva, regra de RBAC/Auth ou novo achado de advisor relacionado, e MUST ser executada pelo responsavel pela rodada de validacao remota ou pelo autor da mudanca subsequente.
- **FR-020**: O criterio de dependencia viva MUST vasculhar, no minimo, `src/services`, `src/lib`, `supabase/functions`, triggers, views e outras funcoes SQL relacionadas ao objeto analisado.
- **FR-021**: Toda funcao `SECURITY DEFINER` preservada MUST ter guardas internas explicitas de identidade e de acesso esperado, incluindo validacao de usuario autenticado quando aplicavel, verificacao de papel/capacidade/ownership/regra de negocio e grant por assinatura exata ao conjunto minimo de papeis permitido.
- **FR-022**: A reescrita de policies para performance MUST aplicar regras de transformacao concretas: chamadas diretas de contexto de autenticacao em predicates de policy devem ser substituidas por avaliacao equivalente de escopo por consulta, incluindo o padrao `(select auth.uid())` para os casos atuais de `auth.uid()` direto.
- **FR-023**: A taxonomia de triagem MUST ser mutuamente exclusiva: `risco_real` para falha material ainda sem mitigacao; `drift_remoto` para diferenca observavel entre remoto e estado versionado esperado; `concessao_residual` para grant ou exposicao remanescente ainda nao classificado como intencional; `excecao_intencional` para comportamento preservado com aprovacao formal; `fora_escopo` para item explicitamente excluido da feature; `resolvido` para caso fechado pela rodada corrente.
- **FR-024**: Quando uma funcao for simultaneamente privilegiada, necessaria e exposta a papel nao previsto, a precedencia MUST ser corrigir exposicao e guardas primeiro; a preservacao do comportamento legitimo so pode ocorrer apos revogar o acesso indevido e revalidar os chamadores esperados.
- **FR-025**: A feature MUST capturar um snapshot baseline remoto antes de iniciar as correcoes, incluindo `get_project_url`, `get_advisors(type=security)`, `get_advisors(type=performance)` e `list_migrations`, e usar esse baseline como referencia objetiva para medir resolucao, drift e regressao.
- **FR-026**: A feature MUST tratar como regressao de comportamento autorizado qualquer ampliacao de acesso antes bloqueado, bloqueio de acesso antes permitido, ou alteracao indevida de ownership/regra de negocio em fluxos que dependem das funcoes ou policies preservadas.

### Advisor Mapping

- `rls_enabled_no_policy` -> FR-003, FR-016, FR-017, FR-025
- `anon_security_definer_function_executable` -> FR-002, FR-017, FR-021, FR-024, FR-025
- `authenticated_security_definer_function_executable` -> FR-004, FR-017, FR-020, FR-021, FR-024, FR-025
- `auth_rls_initplan` -> FR-005, FR-006, FR-022, FR-026
- `multiple_permissive_policies` -> FR-005, FR-007, FR-022, FR-026

### Role Matrix

- **`anon`**: nao pode executar RPCs privilegiadas de negocio no escopo da feature; qualquer exposicao remanescente a `anon` e tratada como risco real ou concessao residual ate classificacao final.
- **`authenticated`**: so pode executar assinaturas explicitamente concedidas, com dependencia viva confirmada e guardas internas coerentes com papel, capacidade, ownership ou regra de negocio.
- **`service_role`**: pode manter acesso a objetos service-owned e rotinas internas necessarias ao backend, desde que esses acessos nao sejam usados para justificar exposicao desnecessaria a `anon` ou `authenticated`.

### Validation Rules

- O baseline remoto capturado por `FR-025` e o mecanismo objetivo de verificacao para `SC-001`, `SC-003`, `SC-004` e `SC-005`.
- O gate de `FR-013` e satisfeito apenas quando a rodada final de validacao remota marcar todos os itens no escopo como `resolvido`, `excecao_intencional`, `drift_remoto` ou `fora_escopo`, sem nenhum `risco_real` restante.
- A validacao de nao-regressao exigida por `FR-026` deve provar que:
  - nenhum papel anteriormente bloqueado ganhou acesso indevido;
  - nenhum papel anteriormente permitido perdeu acesso legitimo;
  - nenhuma regra de ownership, capacidade ou negocio foi afrouxada por consolidacao de policies ou ajuste de grants.

### Key Entities *(include if feature involves data)*

- **Achado de Advisor**: Registro de aviso ou alerta emitido pela análise do Supabase e triado pela feature como risco real, exceção aceita, drift remoto ou item fora de escopo. Rastreado em tabela Markdown versionada em `specs/010-corrigir-advisors-supabase/triagem.md`.
- **Excecao de Conformidade**: Justificativa formal para manter um comportamento intencionalmente diferente do esperado por um advisor, com motivo, impacto e criterio de revisao.
- **Conjunto de Correção Versionado**: Lote auditável de mudanças de backend entregue como migrations `.sql` individuais em `supabase/migrations/`, destinado a alinhar grants, policies, guardas e validações com a postura aprovada.
- **Runbook de Validação Remota**: Arquivo `runbook-validacao.md` versionado no diretório da feature, contendo procedimento operacional que orienta a confirmar o estado dos advisors após aplicação e a registrar o resultado final.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos achados classificados como risco real de seguranca no escopo da feature deixam de permanecer sem correcao ou sem excecao aprovada, medidos contra o snapshot baseline e o snapshot pos-aplicacao registrados pela feature.
- **SC-002**: 100% das tabelas no escopo com RLS habilitado possuem politica coerente com o modelo de acesso esperado ao final da feature.
- **SC-003**: 100% das funcoes privilegiadas no escopo possuem classificacao explicita como acesso corrigido ou excecao intencional documentada.
- **SC-004**: Os warnings de performance ligados a RLS ou RPC no escopo da feature sao reduzidos sem regressao validada de comportamento autorizado, onde regressao significa ampliar acesso indevido, bloquear acesso legitimo ou alterar ownership/regra de negocio em fluxos preservados.
- **SC-005**: 100% dos achados remanescentes apos a validacao remota recebem classificacao final registrada como `resolvido`, `drift_remoto`, `concessao_residual`, `excecao_intencional`, `fora_escopo` ou `pendencia_bloqueadora`, sem categoria ambigua ou sobreposta.
- **SC-006**: O `runbook-validacao.md` permite repetir a validação remota completa em uma única sessão de trabalho usando o MCP do Supabase conectado ao ambiente de produção, sem depender de conhecimento tácito fora do repositório.
- **SC-007**: 0 itens fora do escopo declarado da feature sao tratados como concluidos por engano dentro desta entrega.

## Clarifications

### Session 2026-07-06

- Q: Como os achados dos advisors, sua classificação de triagem e estado de resolução devem ser rastreados de forma concreta? → A: Tabela de rastreamento em Markdown no diretório da feature (`specs/010-corrigir-advisors-supabase/`), versionada junto com o spec.
- Q: Qual o formato dos artefatos versionados de correção? → A: Arquivos `.sql` individuais em `supabase/migrations/`, seguindo o padrão existente do projeto.
- Q: Qual o formato e local do runbook de validação remota? → A: Arquivo Markdown `runbook-validacao.md` no diretório da feature, versionado junto com o spec.
- Q: Como a conexão e autenticação com o projeto remoto serão feitas para validação? → A: MCP do Supabase já conectado ao ambiente de produção.
- Q: Qual o critério para determinar se uma função privilegiada é intencional e deve ser preservada vs. corrigida? → A: Preservar se for referenciada por código da aplicação ou outro objeto do banco (critério de dependência viva).

## Assumptions

- Os achados atuais de advisors no projeto remoto sao um ponto de partida valido para a feature, mas podem incluir drift ou diferencas de grants em relacao ao SQL versionado.
- Funcoes privilegiadas podem continuar existindo no sistema desde que seu acesso permitido seja intencional, restrito e auditavelmente justificado.
- Ajustes amplos de indices, chaves estrangeiras sem indice e indices nao usados permanecem fora desta feature, salvo se uma dependencia direta com RLS ou RPC surgir durante a triagem.
- A validacao remota sera executada exclusivamente via MCP do Supabase contra o mesmo projeto de producao ja tratado pela feature de promocao; nenhuma operacao remota usara Supabase CLI ou linha de comando local para acessar o banco, garantindo que o runbook seja reproduzivel apenas com o ambiente MCP ja conectado. Esta feature nao substitui o workflow completo de promocao operacional.
- A documentacao em `.agents` e `.sauron` continuara obrigatoria quando a execucao operacional da correcao ocorrer.
