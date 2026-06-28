# Research: Telas de Redirecionamento por Persona (Landing Pages)

Decisões técnicas para converter as landings de Projetos e Clientes e religar o Dashboard a dados reais, mantendo a arquitetura RPC-first do projeto. Não há `NEEDS CLARIFICATION` remanescente da spec (escopo de escrita confirmado como CRUD completo).

---

## D1 — Acesso a dados: RPC-first para leitura e escrita

- **Decisão**: Todo acesso a dados (SELECT, INSERT, UPDATE, DELETE) é feito por funções PostgreSQL `SECURITY DEFINER` chamadas via `supabase.rpc()`. O frontend nunca usa `supabase.from('tabela')`.
- **Rationale**: É o padrão já estabelecido na feature 003 (`obter_perfil_usuario`, `obter_permissoes_usuario`, etc.). Centraliza a lógica de autorização (RBAC) e de agregação no banco, simplifica o frontend e mantém as tabelas protegidas por RLS como segunda camada.
- **Alternativas consideradas**:
  - *PostgREST direto (`.from().select()`) com RLS*: rejeitado por divergir do padrão do projeto e espalhar regras de agregação/RBAC pelo frontend.
  - *Edge Functions*: rejeitado — desnecessário para CRUD relacional; RPC no Postgres é suficiente e mais simples.

## D2 — Autorização RBAC dentro das RPCs

- **Decisão**: Criar um helper `public.permissao_modulo(p_modulo text)` que retorna `(pode_ler boolean, pode_escrever boolean)` para o `auth.uid()` atual, derivado do `perfil_acesso` (mesma matriz de `obter_permissoes_usuario`). Toda RPC de leitura valida `pode_ler`; toda RPC de escrita valida `pode_escrever` e lança exceção quando negado.
- **Rationale**: Fonte única de verdade para permissões, reaproveitando a matriz já existente. Garante que a autorização seja imposta no banco, não apenas escondendo botões no frontend (SC-009).
- **Alternativas consideradas**:
  - *Repetir a matriz em cada RPC*: rejeitado por duplicação e risco de divergência.
  - *Depender só do RLS*: rejeitado — RLS protege a tabela, mas a regra de negócio "Comercial não escreve em projetos" fica mais clara e testável como gate explícito na RPC.

## D3 — Visibilidade do Profissional Técnico (escopo por alocação)

- **Decisão**: Criar a tabela `alocacoes_projeto` (usuário × projeto). A RPC `listar_projetos()` retorna todos os projetos para Administrador/Projetos e **apenas os projetos alocados** para o perfil `Técnico`. A RPC `listar_tarefas_kanban()` segue a mesma regra.
- **Rationale**: Atende FR-006 e SC-006 ("Técnico vê apenas projetos em que está alocado") sem criar telas adicionais.
- **Alternativas consideradas**:
  - *Coluna `responsavel_id` no projeto*: rejeitado — um projeto pode ter vários membros; alocação N:N é mais fiel ao domínio.

## D4 — Exclusão: hard delete guardado vs. soft delete

- **Decisão**: Para **clientes**, seguir o padrão do projeto e usar **soft delete** (`status = 'Inativo'`) como ação padrão de "excluir/inativar", preservando histórico financeiro vinculado. Para **projetos** e **tarefas**, permitir **hard delete** via RPC (`excluir_projeto`, `excluir_tarefa`) guardado por `pode_escrever` + auditoria, pois são registros operacionais sem exigência de rastreabilidade permanente. `ON DELETE CASCADE` remove tarefas/alocações ao excluir um projeto.
- **Rationale**: Concilia "CRUD completo" pedido pelo usuário com a filosofia de não apagar dados sensíveis/financeiros já adotada (perfis/usuários nunca são deletados). Cliente inativo some das listas ativas mas mantém integridade referencial dos lançamentos.
- **Alternativas consideradas**:
  - *Hard delete em tudo*: rejeitado — quebraria integridade de lançamentos/atendimentos e o princípio de rastreabilidade do projeto.
  - *Soft delete em tudo*: rejeitado — adiciona complexidade desnecessária para tarefas/projetos descartáveis.

## D5 — Métricas e séries do Dashboard derivadas no banco

- **Decisão**: Os indicadores do Dashboard são **calculados por RPCs de agregação** sobre `lancamentos` e `clientes` (ex.: `obter_metricas_dashboard`, `obter_fluxo_caixa_mensal`, `listar_ultimos_lancamentos`, `listar_contas_pagar_proximas`, `obter_composicao_receita`). Nenhum valor fixo permanece no componente.
- **Rationale**: Atende FR-004/FR-011 e SC-002 ("0 valores fictícios"). Agregação no SQL é eficiente e mantém o frontend declarativo.
- **Alternativas consideradas**:
  - *Buscar linhas cruas e agregar no frontend*: rejeitado — mais tráfego, lógica duplicada e divergência do RPC-first.
  - *Views materializadas*: rejeitado para o volume atual; agregação on-the-fly é suficiente (< 3 s).

## D6 — Estados de carregamento, vazio e erro

- **Decisão**: Cada página implementa três estados explícitos: **carregando** (skeleton/placeholder), **vazio** (mensagem dedicada por seção, ex.: "Nenhum projeto encontrado") e **erro recuperável** (mensagem + ação "tentar novamente"). Padrão de hook local `useEffect` + `useState` por página, encapsulando a chamada ao service.
- **Rationale**: Atende FR-007/FR-008, SC-004 e os edge cases. Mantém consistência com `ProtectedRoute` (que já tem estado "Carregando…").
- **Alternativas consideradas**:
  - *React Query / SWR*: rejeitado para esta feature — adiciona dependência nova; o volume de telas é pequeno e o padrão manual já é usado no projeto. Pode ser reavaliado em feature futura.

## D7 — Kanban de tarefas (drag-and-drop)

- **Decisão**: Implementar o Kanban com as três colunas (A Fazer / Em Andamento / Concluído) reusando o markup/estilo de `projetos.html`. O arraste usa a **HTML5 Drag and Drop API nativa** (sem biblioteca). Soltar um card em outra coluna chama `mover_tarefa(p_tarefa_id, p_situacao)`.
- **Rationale**: A referência legada já usa `draggable="true"`; a API nativa evita dependências e é suficiente. A persistência da mudança de coluna é uma operação de escrita simples.
- **Alternativas consideradas**:
  - *dnd-kit / react-beautiful-dnd*: rejeitado nesta feature por adicionar dependência; pode ser adotado depois se a UX exigir reordenação avançada.

## D8 — Redirecionamento por perfil e proteção de rota

- **Decisão**: Reusar `rotaInicialPorPerfil` (já existente) para o redirecionamento pós-login e adicionar guarda de leitura por módulo: ao acessar uma landing sem `pode_ler`, redirecionar para a rota inicial do próprio perfil. Trocar `ModuloNaoMigrado` por `ProjetosPage`/`ClientesPage` nas rotas `/projetos` e `/clientes` em `App.tsx`.
- **Rationale**: Atende FR-003/FR-010 e SC-001/SC-007 sem reescrever o fluxo de login.
- **Alternativas consideradas**:
  - *Guardas de permissão por rota genéricas*: desejável no futuro, mas fora do escopo mínimo; uma checagem leve por landing basta agora.

## D9 — Seeds de dados por persona

- **Decisão**: Estender `supabase/seed.sql` para popular `clientes`, `atendimentos`, `projetos`, `tarefas`, `alocacoes_projeto` e `lancamentos` com dados coerentes às personas de teste já criadas (ex.: alocar a persona `Técnico` a um subconjunto de projetos; vincular lançamentos a clientes para alimentar o Dashboard). Reusar os nomes do mock legado (Inovatec, DataFlow, etc.) para familiaridade visual.
- **Rationale**: Atende FR-009 e SC-001 — cada persona de teste vê dados relevantes ao seu perfil em sua landing após `supabase db reset`.
- **Alternativas consideradas**:
  - *Sem seeds (telas vazias)*: rejeitado — dificultaria a validação de aceitação e a demonstração por persona.

## D10 — Testes

- **Decisão**: Testes unitários (Vitest) para os helpers puros novos (`lib/permissoes.ts`, transformações de dados nos services que não dependem de rede). A validação ponta-a-ponta dos fluxos por persona é feita manualmente via `quickstart.md` após `supabase db reset` (mesmo padrão da 003, que não testa RPC em CI).
- **Rationale**: Mantém o nível de teste consistente com o projeto; lógica pura é coberta por unidade, integração de banco é validada pelo quickstart.
- **Alternativas consideradas**:
  - *Testes de integração automatizados contra Supabase local*: desejável, mas fora do escopo atual de CI do projeto.

## D11 — Migrações modulares (em vez de um único arquivo)

- **Decisão**: Dividir o schema em **7 migrações** ordenadas por timestamp, separadas por camada e por domínio + operação: (1) `schema` (tabelas/CHECKs/FKs/índices), (2) `security` (RLS + `permissao_modulo` + extensão do enum `audit_log.evento`), (3) `rpc_clientes_read`, (4) `rpc_clientes_write`, (5) `rpc_projetos_read`, (6) `rpc_projetos_write`, (7) `rpc_dashboard_read` (Dashboard é somente leitura). A ordem lexical garante que `security` (que cria o helper e estende o enum usados pelas RPCs) seja aplicada antes das migrações de RPC.
- **Rationale**: Um único arquivo concentraria 6 tabelas + RLS + ~23 funções, ficando grande e difícil de revisar/diff. A divisão por domínio **e por operação (leitura/escrita)** isola mudanças ao máximo (ajustar uma RPC de escrita de clientes não toca o arquivo de leitura nem o de projetos), torna os diffs pequenos e focados, e permite que as 5 migrações de RPC sejam desenvolvidas/revisadas em paralelo. Mantém-se o fluxo `supabase db reset` inalterado (o CLI aplica todas as migrações em ordem).
- **Alternativas consideradas**:
  - *Migração única `modulos_landing.sql`*: rejeitada por tamanho e acoplamento — dificulta revisão e gera conflitos de merge quando várias frentes editam o mesmo arquivo.
  - *Split por camada+domínio sem separar leitura/escrita (5 arquivos)*: viável, mas a separação leitura/escrita isola ainda mais as mudanças (RPCs de escrita evoluem mais que as de leitura) e mantém cada arquivo enxuto — adotado o split mais granular.
  - *Uma migração por tabela ou por função*: rejeitada por granularidade excessiva; a divisão por camada + domínio + operação equilibra coesão e tamanho.
