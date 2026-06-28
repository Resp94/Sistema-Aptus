# Research: Demais Telas por Perfil de Acesso

## D1 - Fonte principal de layout e comportamento

**Decision**: Usar `reference/legacy-html/` como fonte principal para layout, hierarquia visual, componentes e comportamento esperado de cada tela.

**Rationale**: O usuario corrigiu explicitamente que os exemplos estao nos HTML legados, nao em `docs/telas.md`. Os HTML contem a composicao visual real, enquanto `docs/telas.md` resume rotas, objetivos e permissoes.

**Alternatives considered**:
- Usar `docs/telas.md` como fonte principal: rejeitado por ser resumo textual e nao o exemplo visual.
- Recriar layout livremente em React: rejeitado por aumentar divergencia visual.

## D2 - Fonte financeira canonica

**Decision**: Reaproveitar a tabela `lancamentos` da feature 004 como fonte canonica para Fluxo de Caixa, Contas a Pagar e Contas a Receber.

**Rationale**: A tabela existente ja possui `tipo`, `natureza`, `valor`, `data_competencia`, `data_vencimento`, `status`, `cliente_id` e `categoria`, cobrindo as projecoes financeiras requeridas. Criar `lancamentos_fluxo_caixa`, `contas_pagar` e `contas_receber` como tabelas separadas agora duplicaria fonte de verdade e criaria risco de divergencia.

**Alternatives considered**:
- Criar tabelas separadas para cada tela financeira: rejeitado por duplicacao e sincronizacao desnecessaria.
- Manter tudo apenas no frontend: rejeitado porque a spec exige dados reais persistidos.

## D3 - Cobrancas como entidade propria

**Decision**: Criar `cobrancas` como entidade propria vinculavel a cliente, contrato e lancamento financeiro.

**Rationale**: Cobrancas possui ciclo proprio: lembrete, boleto pendente/indisponivel, registro de pagamento, status e possivel origem em contrato. Ela se relaciona com financeiro, mas nao deve ser apenas uma linha generica de `lancamentos`.

**Alternatives considered**:
- Modelar cobranca apenas como `lancamentos.natureza = 'a_receber'`: rejeitado porque perde historico comercial e estado de boleto/lembretes.

## D4 - Comercial separado de Clientes

**Decision**: Criar `propostas`, `contratos` e `documentos` vinculados a `clientes`.

**Rationale**: Clientes ja existe e deve permanecer fonte da carteira. Propostas e contratos representam etapas comerciais posteriores, com status, valores, vigencia e anexos.

**Alternatives considered**:
- Armazenar propostas/contratos como historico de atendimento: rejeitado porque sao entidades com ciclo e metricas proprias.

## D5 - Equipe e alocacao

**Decision**: Criar `membros_equipe`, `alocacoes_equipe` e `apontamentos_horas`, vinculando membros a `perfis` quando houver login.

**Rationale**: A feature 004 possui `alocacoes_projeto` para limitar projetos do Tecnico, mas a tela Equipe precisa capacidade, disponibilidade, funcao, habilidades, alocacao percentual e apontamentos.

**Alternatives considered**:
- Usar apenas `alocacoes_projeto`: rejeitado por nao representar capacidade, status de membro e historico de alocacao.

## D6 - Relatorios sem gerador ficticio

**Decision**: Relatorios devem exibir consultas reais e historico de exportacoes reais; quando geracao de arquivo nao estiver implementada, o comando fica indisponivel ou pendente de integracao.

**Rationale**: A spec proibe sucesso simulado. A tela pode entregar valor com filtros, agregacoes e status de exportacao sem fingir PDF/CSV pronto.

**Alternatives considered**:
- Gerar arquivos mockados: rejeitado por violar a regra de zero mock.
- Omitir Relatorios: rejeitado porque e rota em escopo e perfil Visualizador depende dela.

## D7 - Seguranca RPC-first no Supabase

**Decision**: Todas as novas funcoes RPC devem validar `auth.uid()`, checar RBAC por modulo, fixar `search_path`, revogar `EXECUTE` de `PUBLIC` e conceder apenas ao papel necessario (`authenticated`).

**Rationale**: O changelog do Supabase de 2026-04-28 informa que novas tabelas podem nao ser expostas automaticamente a Data/GraphQL API. O projeto nao depende de Data API direta, mas as funcoes RPC continuam sendo a superficie publica do frontend e precisam de grants explicitos e autorizacao interna. A skill Supabase tambem alerta que `SECURITY DEFINER` em `public` e sensivel.

**Alternatives considered**:
- Confiar so em RLS: rejeitado porque o padrao do projeto e RPC-first com RBAC nas funcoes.
- Usar queries diretas `supabase.from()`: rejeitado por violar arquitetura existente.

## D8 - Auditoria

**Decision**: Auditar acoes destrutivas e alteracoes sensiveis: exclusoes/inativacoes, mudanca de perfil, parametros financeiros globais e renovacoes criticas.

**Rationale**: A spec exige auditoria para acoes destrutivas e sensiveis. A feature 004 ja estabeleceu `audit_log` para eventos irreversiveis.

**Alternatives considered**:
- Auditar toda criacao/edicao: rejeitado para evitar excesso de ruido nesta fase.

## D9 - Ordem de entrega

**Decision**: Planejar entregas por dominio: financeiro e comercial primeiro, equipe/configuracoes depois, relatorios e fechamento de navegacao por ultimo.

**Rationale**: Financeiro e comercial sao P1 na spec e alimentam indicadores usados por multiplos perfis. Equipe complementa Projetos, Configuracoes controla RBAC, Relatorios fecha leitura/Visualizador.

**Alternatives considered**:
- Implementar tela por tela sem camada de dados comum: rejeitado porque duplicaria services/RPCs.
- Implementar todos os bancos antes de qualquer UI: rejeitado porque atrasa validacao incremental por perfil.

## D10 - Ownership de cobrancas

**Decision**: `cobrancas` e modulo compartilhado: Comercial controla origem, relacionamento, lembretes e acompanhamento; Financeiro controla pagamento, conciliacao, cancelamento financeiro e dados monetarios completos; Administrador cobre ambos.

**Rationale**: A tela e acessada por Financeiro e Comercial, mas as acoes tem riscos diferentes. Registrar pagamento altera saldos e precisa permissao financeira. Lembretes e acompanhamento pertencem ao fluxo comercial.

**Alternatives considered**:
- Tratar `cobrancas` como modulo exclusivamente financeiro: rejeitado porque Comercial precisa acompanhar clientes inadimplentes.
- Tratar como modulo exclusivamente comercial: rejeitado porque pagamento/conciliacao impacta financeiro.

## D11 - Estados derivados e fonte unica de vencido

**Decision**: `Vencido` e sempre estado de exibicao derivado por data atual em registros pendentes.

**Rationale**: Persistir `Vencido` como fonte primaria exige rotina de atualizacao e pode gerar divergencia. A mesma regra deve valer para `lancamentos`, `cobrancas` e badges de UI.

**Alternatives considered**:
- Persistir `Vencido` em cada tabela: rejeitado por risco de inconsistencia temporal.

## D12 - Alocacoes de autorizacao versus alocacoes operacionais

**Decision**: `alocacoes_projeto` permanece fonte de autorizacao do Tecnico para projetos/tarefas; `alocacoes_equipe` e fonte operacional para capacidade e historico.

**Rationale**: A feature 004 ja usa `alocacoes_projeto` para restringir Tecnico. Substituir isso na feature 005 poderia quebrar a seguranca ja entregue. `alocacoes_equipe` complementa a gestao de equipe, nao substitui a autorizacao.

**Alternatives considered**:
- Usar apenas `alocacoes_equipe`: rejeitado por misturar permissao com capacidade operacional.

## D13 - Requisitos transversais de UI

**Decision**: Responsividade e acessibilidade minima entram como requisitos da feature, mesmo usando HTML legado como referencia visual.

**Rationale**: A migracao para React nao deve carregar limitacoes dos prototipos quando elas impedirem uso em mobile, foco por teclado, leitura de estado ou contraste.

**Alternatives considered**:
- Excluir acessibilidade/responsividade desta fase: rejeitado porque o checklist apontou gap e a feature inclui 9 rotas de uso recorrente.
