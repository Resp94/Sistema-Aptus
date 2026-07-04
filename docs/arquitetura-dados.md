# Diretrizes de Arquitetura de Dados

Este documento registra as decisões arquiteturais do projeto `sistema-aptus` em relação à camada de acesso a dados, RPCs, views e Row Level Security (RLS). Ele orienta escolhas futuras e evita a retomada de propostas já avaliadas e descartadas.

## 1. RPCs granulares como regra

O frontend acessa o banco **exclusivamente via RPCs** (funções PostgreSQL expostas pelo Supabase). Cada operação de leitura ou escrita é representada por uma função com responsabilidade clara e limitada.

- **Regra**: uma RPC por operação de domínio (ex.: `criar_cliente`, `listar_projetos`, `obter_metricas_dashboard`).
- **Padrão obrigatório** para toda RPC de dados:
  - `SECURITY DEFINER`;
  - `SET search_path = public`;
  - guarda explícita de identidade (`auth.uid() IS NULL → Unauthorized`);
  - checagem de permissão de módulo (`permissao_modulo(...)`) quando aplicável;
  - `REVOKE EXECUTE ... FROM PUBLIC`;
  - `GRANT EXECUTE ... TO authenticated`.
- O frontend **nunca** usa `supabase.from(...)` para lógica de domínio. A única exceção catalogada é `src/services/health-check.ts`, que faz uma chamada de verificação de saúde à API REST.

## 2. Agregadora por página descartada do caminho crítico

A proposta de substituir múltiplas RPCs granulares por "uma RPC agregadora por página" foi avaliada e **formalmente descartada** como estratégia padrão.

- **Justificativa**: a agregadora não fecha nenhuma brecha de segurança e introduz alto risco de quebra de contrato, acoplamento página-a-página e dificuldade de reuso. O custo supera o benefício quando não há evidência de latência.
- **Regra**: mantém-se RPCs granulares. A agregadora só pode ser introduzida **pontualmente** e **mediante medição de latência real** que justifique a mudança.
- **Condição mínima para agregação**:
  1. Identificar, com dados de produção ou carga representativa, que múltiplas chamadas granulares causam latência perceptível ao usuário;
  2. Demonstrar que a agregadora reduz a latência medida;
  3. Garantir que a agregadora não mude o contrato de segurança (continua usando permissões por módulo, guarda de identidade, `search_path` fixo e `REVOKE`/`GRANT`).

## 3. Views como read models internos

Views podem ser usadas no banco como **modelos de leitura internos**, nunca chamadas diretamente pelo frontend.

- **Uso permitido**: simplificar consultas complexas dentro de RPCs ou relatórios, desde que a view seja criada com `security_invoker = true`.
- **Uso proibido**: expor views como endpoints diretos para o frontend (`supabase.from('minha_view')`).
- A função `check-no-from.mjs` no CI reprova qualquer `supabase.from(...)` em `src/services/**`, exceto `health-check.ts`.

## 4. RLS como defesa em profundidade

Row Level Security (RLS) é mantido como camada adicional de defesa, mesmo quando as RPCs já aplicam permissões.

### Regras obrigatórias para políticas de `UPDATE`

1. **Sempre definir `USING` e `WITH CHECK`**:
   - `USING` controla quais linhas podem ser vistas pela atualização;
   - `WITH CHECK` controla quais valores resultantes são permitidos.
   - Omitir `WITH CHECK` permite transformar uma linha em algo que o usuário não teria permissão de criar.

2. **Sempre garantir uma política de `SELECT` correspondente**:
   - Um `UPDATE` em PostgreSQL precisa localizar a linha antes de atualizá-la.
   - Se não houver política de `SELECT` que permita ver a linha, o `UPDATE` falha silenciosamente sem alterar linhas, mascarando erros de autorização.

### Exemplo canônico de política segura

```sql
CREATE POLICY tabela_select ON public.tabela
  FOR SELECT TO authenticated
  USING (public.permissao_modulo('modulo') AND condicao_de_negocio);

CREATE POLICY tabela_update ON public.tabela
  FOR UPDATE TO authenticated
  USING (public.permissao_modulo('modulo') AND condicao_de_negocio)
  WITH CHECK (public.permissao_modulo('modulo') AND condicao_de_negocio);
```

## 5. Autorização nunca derivada de user_metadata

A autorização do sistema deriva exclusivamente da tabela `public.perfis` e das funções de permissão (`obter_permissoes_usuario`, `permissao_modulo`, `existe_perfil_admin`).

- **`raw_user_meta_data` e `user_metadata` são dados do usuário**, não fonte de autorização.
- Campos como `nome` e `departamento` podem ser lidos/escritos em `raw_user_meta_data` para sincronização, mas nunca usados para decidir permissões.
- A função `check-no-user-metadata.mjs` no CI reprova novas ocorrências de `raw_user_meta_data`/`user_metadata` fora da allowlist explícita.

## 6. Migrations hand-authored

Todas as migrations são escritas manualmente e versionadas em `supabase/migrations/`.

- Não usar `supabase db pull` para gerar migrations de schema.
- Funções são recriadas com `CREATE OR REPLACE` e ajustes de `REVOKE`/`GRANT` quando necessário.
- Correções críticas e padronizações retroativas devem ficar em migrations separadas por fase de risco.

## 7. RBAC por capacidades nomeadas para ações sensíveis

A permissão por módulo (`permissao_modulo`/`obter_permissoes_usuario`) continua sendo a fonte canônica de **leitura, rota e menu**. Ela não muda com esta seção. O que muda é a autorização de **ações** dentro de um módulo já acessível.

### 7.1 Tabela `public.capacidades_perfil`

- Representa uma capacidade nomeada no formato `recurso.acao` (ex.: `clientes.criar`, `cobrancas.boleto`, `tarefas.mover_propria`).
- Chave primária composta: `(perfil_acesso, capacidade)`.
- `perfil_acesso` corresponde a um valor válido de `public.perfis.perfil_acesso` (`Administrador`, `Financeiro`, `Projetos`, `Comercial`, `Técnico`, `Visualizador`).
- Um perfil sem linha na tabela não possui aquela capacidade; `Visualizador` não possui nenhuma linha (zero capacidades).
- RLS habilitado. **Não é contrato direto do frontend**: não há `supabase.from('capacidades_perfil')` nem policy de `SELECT` ampla para `authenticated`. A leitura pelo frontend ocorre exclusivamente pela RPC `obter_capacidades_usuario()`.
- A matriz inicial é populada por migration/seed versionado; uma UI administrativa para editar linhas é possível no futuro, mas está fora do escopo atual.

### 7.2 Helpers `tem_capacidade` e `obter_capacidades_usuario`

- **`public.tem_capacidade(p_capacidade text) RETURNS boolean`**: usado **dentro do corpo das RPCs de escrita/efeito** para autorizar a ação antes de qualquer mutação. Retorna `false` para chamador anônimo ou perfil inativo/ausente, e `true` somente se existir linha em `capacidades_perfil` para o perfil ativo do usuário autenticado. Nunca deriva de `user_metadata` (ver seção 5).
- **`public.obter_capacidades_usuario() RETURNS text[]`**: usada pelo **frontend** para carregar a lista de capacidades do usuário junto ao perfil/permissões na inicialização da sessão, alimentando a UX (mostrar/esconder controles). Requer usuário autenticado, retorna lista vazia para `Visualizador` ou usuário sem capacidades.
- Ambas seguem os guardrails padrão: `SECURITY DEFINER`, `SET search_path = public`, `REVOKE EXECUTE FROM PUBLIC`, `GRANT EXECUTE TO authenticated`.

### 7.3 Regra central de autorização

- `permissao_modulo` / `obter_permissoes_usuario()` respondem "o usuário pode ver/navegar neste módulo?" — continuam controlando rota, menu e leituras (`listar_*`, `obter_*_detalhe`).
- `tem_capacidade` / capacidades nomeadas respondem "o usuário pode executar esta ação específica?" — são a fonte de autorização para **ações sensíveis**: toda escrita (criar/atualizar/excluir) e todo efeito de negócio (emitir boleto, notificar, exportar, enviar proposta, gerar contrato, baixar cobrança/lançamento).
- Capacidades no formato `*_propria`/`*_proprio` exigem checagem adicional de **ownership** por relacionamento (ex.: `tarefas.responsavel_id` = `membros_equipe.id` vinculado ao `perfis.usuario_id = auth.uid()`), nunca por hardcode de nome de perfil.
- Padrão canônico no corpo da RPC:

  ```sql
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT public.tem_capacidade('<recurso.acao>') THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;
  ```

- Detalhe completo do mapeamento RPC → capacidade em [`specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md`](../specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md) e da matriz por perfil em [`specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md`](../specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md).

### 7.4 Regra de consumo frontend/backend

- O frontend consome `capacidades` (lista de `obter_capacidades_usuario()`) **somente para UX**, via helper `pode(capacidades, 'recurso.acao')` — para decidir se mostra ou esconde um botão/ação na tela.
- A autorização **real** de qualquer ação sensível acontece sempre na RPC, via `tem_capacidade`, nunca no frontend.
- A presença (ou ausência) de um botão no frontend **nunca substitui** o guard de `tem_capacidade` no backend. Uma chamada direta à RPC sem o botão correspondente deve ser bloqueada do mesmo jeito.

## 8. Referências

- [contracts/guardrail-standard.md](../specs/006-rpc-security-hardening/contracts/guardrail-standard.md)
- [contracts/rpc-signatures.md](../specs/006-rpc-security-hardening/contracts/rpc-signatures.md)
- [contracts/ci-and-audit.md](../specs/006-rpc-security-hardening/contracts/ci-and-audit.md)
- [specs/007-rbac-capacidades-nomeadas/data-model.md](../specs/007-rbac-capacidades-nomeadas/data-model.md)
- [specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md](../specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md)
- [specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md](../specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md)
