# Release Gate Checklist: Telas de Redirecionamento por Persona

**Purpose**: Validação rigorosa da QUALIDADE DOS REQUISITOS (não da implementação) antes de liberar a feature. Cobre os domínios Redirecionamento, RBAC/Segurança, Dados/RPC e UX/Telas. Cada item testa se o requisito está completo, claro, consistente e mensurável.
**Created**: 2026-06-28
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md) · [data-model.md](../data-model.md) · [contracts/](../contracts/)

**Note**: "Unit tests for English" — itens avaliam o que está (ou não está) escrito nos requisitos, não o comportamento do sistema.

## Requirement Completeness

- [x] CHK001 - Os requisitos definem explicitamente quais telas estão dentro e fora do escopo, sem ambiguidade sobre as 10 telas adiadas? [Completeness, Spec §Contexto e Escopo]
- [x] CHK002 - Há requisito cobrindo o redirecionamento de TODOS os 6 perfis (incluindo Visualizador), não apenas dos 5 com landing explícita? [Coverage, Spec §FR-003]
- [x] CHK003 - Os requisitos especificam o conjunto mínimo de tabelas/entidades necessárias para alimentar cada uma das três landings? [Completeness, Spec §FR-005]
- [x] CHK004 - Estão documentados requisitos de estado de carregamento, vazio e erro para CADA seção das três landings? [Completeness, Spec §FR-007, §FR-008]
- [x] CHK005 - Os requisitos de escrita cobrem criar, editar E excluir para cada entidade gerenciável (cliente, projeto, tarefa)? [Completeness, Spec §FR-012]
- [x] CHK006 - Há requisito definindo o comportamento de auditoria para ações de escrita/exclusão, em linha com o `audit_log` existente? [Gap]
- [x] CHK007 - Os requisitos definem como a "receita acumulada" por cliente é obtida (derivada vs. armazenada)? [Completeness, Spec §Key Entities / data-model §clientes]
- [x] CHK008 - Há requisitos para os seeds de dados por persona, especificando que cada persona de teste enxergue dados relevantes? [Completeness, Spec §FR-009]

## Requirement Clarity

- [x] CHK009 - O critério "nenhum valor fictício/codificado permanece" é definido de forma verificável (o que conta como mock)? [Clarity, Spec §FR-004, §SC-002]
- [x] CHK010 - O termo "estado vazio explícito" é qualificado com o que deve ser exibido por seção? [Clarity, Spec §FR-007]
- [x] CHK011 - "Visualização limitada do Profissional Técnico" está definido com critério objetivo (somente projetos alocados)? [Clarity, Spec §FR-006, research §D3]
- [x] CHK012 - "Erro recuperável" está especificado com o mecanismo esperado (ex.: ação de tentar novamente)? [Clarity, Spec §FR-008, §Edge Cases]
- [x] CHK013 - Os valores válidos de cada enum (status de cliente, situação de tarefa, natureza/status de lançamento) estão enumerados sem ambiguidade? [Clarity, data-model §Validation Rules]
- [x] CHK014 - O significado de "ocultas ou desabilitadas" para ações sem permissão está definido sem deixar a escolha indefinida? [Ambiguity, Spec §US5 cenário 3]

## Requirement Consistency

- [x] CHK015 - O mapa de landing por persona é consistente entre spec, plan, data-model e quickstart (Admin/Financeiro/Visualizador→Dashboard; Projetos/Técnico→Projetos; Comercial→Clientes)? [Consistency, Spec §Contexto, quickstart §Credenciais]
- [x] CHK016 - A matriz de permissões referida nos requisitos é consistente com a já definida em `obter_permissoes_usuario` (sem nova regra conflitante)? [Consistency, research §D2]
- [x] CHK017 - A estratégia de exclusão é consistente entre entidades (soft delete em clientes vs. hard delete em projetos/tarefas) e justificada? [Consistency, research §D4, data-model §State Transitions]
- [x] CHK018 - Os nomes de módulo usados no RBAC (`clientes`, `projetos`, `dashboard`) são consistentes entre contratos, data-model e a navegação existente? [Consistency, contracts/*]
- [x] CHK019 - Os requisitos de PII (nome, e-mail, telefone de clientes) são consistentes com a política de PII já aplicada a usuários/perfis? [Consistency, Spec §Assumptions]

## Acceptance Criteria Quality & Measurability

- [x] CHK020 - Cada critério de sucesso (SC-001..SC-009) é objetivamente mensurável e independente de implementação? [Measurability, Spec §Success Criteria]
- [x] CHK021 - O alvo de desempenho "< 3 s" está vinculado a uma condição de medição clara (rede normal, volume de seed)? [Measurability, Spec §SC-003]
- [x] CHK022 - O critério "0 valores fictícios" (SC-002) é verificável por inspeção objetiva das telas? [Measurability, Spec §SC-002]
- [x] CHK023 - Cada FR possui pelo menos um cenário de aceitação ou SC correspondente que permita validá-lo? [Traceability, Spec §Requirements ↔ §Success Criteria]
- [x] CHK024 - O critério de bloqueio de escrita por perfil (SC-009) é mensurável tanto na UI quanto na camada de RPC? [Measurability, Spec §SC-009, contracts §Gate]

## Scenario Coverage (Primary / Alternate / Exception / Recovery)

- [x] CHK025 - Há requisitos para o fluxo primário de cada persona (login → landing com dados reais)? [Coverage, Spec §US1, §US2, §US3]
- [x] CHK026 - Existem requisitos para o fluxo alternato de busca/filtro sem resultados na tela de Clientes? [Coverage, Spec §US2 cenário 3, §Edge Cases]
- [x] CHK027 - Há requisitos para o fluxo de exceção de acesso não autorizado a uma landing (sem `pode_ler`)? [Coverage, Spec §FR-010, §US4 cenário 2]
- [x] CHK028 - Existem requisitos de recuperação/erro para falha ao carregar dados do banco? [Coverage, Spec §FR-008, §Edge Cases]
- [x] CHK029 - Há requisito para o caso de persistência de escrita falhar (validação/permissão/erro do banco) sem corromper o estado da tela? [Coverage, Spec §FR-014, §US5 cenário 4]
- [x] CHK030 - O comportamento da movimentação de tarefa no Kanban (persistência da mudança de coluna) está especificado como requisito? [Coverage, research §D7, contracts/projetos-rpc §mover_tarefa]

## Edge Case Coverage

- [x] CHK031 - Há requisito para persona com permissão de leitura na própria landing porém sem nenhum dado (estado totalmente vazio)? [Edge Case, Spec §Edge Cases]
- [x] CHK032 - Está definido o comportamento quando um lançamento está vencido (`data_vencimento < hoje` e `status='Pendente'`)? [Edge Case, dashboard-rpc §Notas]
- [x] CHK033 - Há requisito para o caso de cliente inativado que ainda possui lançamentos/atendimentos vinculados (integridade)? [Edge Case, research §D4, data-model §Relationships]
- [x] CHK034 - Está coberto o caso de exclusão de projeto com tarefas e alocações associadas (cascade)? [Edge Case, data-model §Relationships]
- [x] CHK035 - Há requisito para o Técnico sem nenhuma alocação de projeto (landing de Projetos vazia mas válida)? [Edge Case, Spec §US1 cenário 3, research §D3]

## RBAC & Security Requirements Quality

- [x] CHK036 - Os requisitos exigem que o RBAC seja imposto na camada de dados (RPC), não apenas na UI? [Security, Spec §FR-006, research §D2]
- [x] CHK037 - Está especificado que toda tabela nova possui RLS por operação (sem política `ALL`)? [Security, data-model §RLS]
- [x] CHK038 - Há requisito de fonte única para a matriz de permissões (evitando duplicação divergente)? [Consistency, research §D2, data-model §permissao_modulo]
- [x] CHK039 - Os requisitos de tratamento/exposição de PII de clientes estão definidos (classificação e proteção)? [Security, Spec §Assumptions, data-model §clientes]
- [x] CHK040 - O requisito de redirecionamento de acesso negado evita vazar a existência/conteúdo de dados não permitidos? [Security, Spec §FR-010]

## Data / RPC / Schema Requirements Quality

- [x] CHK041 - Cada landing tem seus dados mapeados a RPCs de leitura específicas, com payload definido? [Completeness, contracts/*]
- [x] CHK042 - As regras de validação de entrada das RPCs de escrita estão especificadas (campos obrigatórios, enums, valores válidos)? [Completeness, contracts §Validação]
- [x] CHK043 - Os requisitos definem como as métricas do Dashboard são derivadas (fórmulas de saldo, a receber/pagar, composição)? [Clarity, dashboard-rpc.md]
- [x] CHK044 - As relações e ações de cascade/set null entre entidades estão documentadas e justificadas? [Completeness, data-model §Relationships]
- [x] CHK045 - Há requisito de que RPCs retornem conjuntos vazios/zerados (não nulos quebrados) para sustentar o estado vazio? [Coverage, dashboard-rpc §Notas, Spec §SC-004]

## Routing / Redirecting Requirements Quality

- [x] CHK046 - O requisito de roteamento substitui explicitamente o placeholder "Módulo Não Migrado" apenas nas rotas em escopo, mantendo o restante? [Clarity, Spec §SC-005, plan §Project Structure]
- [x] CHK047 - Está definido o destino de fallback quando o perfil não tem acesso à sua própria landing teórica? [Edge Case, Spec §FR-010, research §D8]
- [x] CHK048 - A regra de redirecionamento pós-login é consistente com a função `rotaInicialPorPerfil` já existente (reuso, não reescrita)? [Consistency, research §D8]

## Dependencies & Assumptions

- [x] CHK049 - As suposições (reuso de auth/contexto, schema seguindo padrão existente, referência de design do legado) estão explícitas e validadas? [Assumption, Spec §Assumptions]
- [x] CHK050 - A dependência do `supabase db reset`/seeds como pré-requisito de validação está documentada? [Dependency, quickstart §Setup]

## Ambiguities & Conflicts

- [x] CHK051 - Não há conflito entre "CRUD completo" (FR-012) e a filosofia de soft delete do projeto — a exceção (clientes) está justificada? [Conflict, Spec §FR-012, research §D4]
- [x] CHK052 - O escopo "apenas landings" não conflita com a diretriz "remover dados mockados" (Dashboard incluído por causa do mock)? [Conflict, Spec §Contexto e Escopo, §US3]
- [x] CHK053 - Termos de status duplicados entre módulos (ex.: "Pendente"/"Pago"/"Vencido" em lançamentos vs. outros) não geram ambiguidade de significado? [Ambiguity, data-model §Validation Rules]

## Notes

- Marque itens concluídos com `[x]` e registre achados inline.
- Itens com `[Gap]` indicam possível requisito ausente — resolver antes de implementar.
- Use `/speckit.clarify` ou edição da spec para fechar lacunas/ambiguidades destacadas.

### Log de resolução (2026-06-28)

Avaliação executada contra spec/plan/data-model/contracts. Todos os 53 itens passam após as correções abaixo:

- **CHK006** (gap real — auditoria): adicionado **FR-015** + seção "Auditoria de ações destrutivas" no data-model (estende o enum `audit_log.evento` com `projeto_excluido`, `tarefa_excluida`, `cliente_inativado`) + **SC-011**; contratos `excluir_projeto`/`excluir_tarefa`/`inativar_cliente` padronizados para auditar.
- **CHK010** (estado vazio): **FR-007** + Edge Cases agora definem o padrão `empty-state` e mensagens-base por tipo de seção.
- **CHK030** (Kanban): adicionado **FR-016** + **SC-012** elevando a persistência do arraste a requisito.
- **CHK032** (Vencido): regra única "derivado em consulta" fixada no data-model, na entidade Lançamento e no `dashboard-rpc`.
- **CHK045** (retorno vazio): garantia de conjunto vazio (não null) adicionada aos contratos de clientes e projetos.
- **CHK023** (FR sem SC): adicionado **SC-010** cobrindo a criação do schema (`supabase db reset`).
- **CHK021** (baseline de desempenho): **SC-003** agora referencia o volume de dados dos seeds.
- **CHK040** (sem vazamento): **FR-010** explicita redirect antes de carregar dados não autorizados.
- **CHK009 / CHK014**: definição de "dado mockado" em **FR-004**; escolha por **ocultar** ações sem permissão em **FR-013**/US5 cenário 3.
- **CHK018**: mapeamento de módulo de `lancamentos` esclarecido no data-model (leitura via `dashboard`; escrita fora de escopo).
- **CHK002**: marcador corrigido de `[Gap]` para `[Coverage]` (o mapa de landing já cobre o Visualizador).
