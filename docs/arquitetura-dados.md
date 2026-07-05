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

## 8. Exportação de relatórios (feature 008)

A exportação real de relatórios (PDF/CSV) segue um desenho com três camadas: RPCs Postgres para autorização e dados, Storage privado para o arquivo, e uma Edge Function que orquestra as duas. O frontend nunca fala diretamente com o Storage nem gera o arquivo no navegador.

### 8.1 Tabela `public.exportacoes_relatorios`

Tabela pré-existente, estendida pela migration `20260704235640_exportar_relatorios.sql` com: `data_inicial`/`data_final` (period solicitado), `arquivo_path`/`arquivo_nome`/`mime_type`/`tamanho_bytes`/`hash_sha256` (metadados do arquivo persistido), `expira_em` (`gerado_em + 12 meses`), `erro` (mensagem sanitizada, até 500 caracteres, quando o status é `Falhou`), e `criado_em`/`atualizado_em`.

- As novas colunas são `NULLABLE` para não quebrar as linhas legadas com status `Indisponível` (nunca tiveram período); todo registro novo criado por `iniciar_exportacao_relatorio` sempre preenche `data_inicial`/`data_final`, então na prática são obrigatórias para o fluxo novo.
- `arquivo_url` permanece na tabela apenas por retrocompatibilidade; o fluxo novo nunca lê nem grava esse campo.
- Constraints: `data_final >= data_inicial` (quando ambos não nulos) e `mime_type IN ('application/pdf', 'application/zip')` (quando não nulo).
- Índices recomendados por `data-model.md`: `(criado_por, gerado_em desc nulls last, criado_em desc)`, `(tipo, gerado_em desc nulls last)`, `(status)`, `(expira_em)`.

### 8.2 Bucket privado `relatorios-exportados`

- Criado com `public = false`. Não existe nenhuma policy de leitura/escrita para o papel `anon`.
- Única policy de `storage.objects`: `SELECT` para `authenticated` quando o usuário tem `relatorios.exportar`, a categoria do registro ainda é exportável para o perfil atual (via `categoria_relatorio_exportavel`) e o usuário é Administrador ou dono do registro (`criado_por`). Essa policy é defesa em profundidade — o fluxo principal de leitura usa signed URLs geradas pela Edge Function com service role, que ignora RLS.
- Nenhuma policy de `INSERT`/`UPDATE`/`DELETE` é concedida a `authenticated`/`anon`: apenas a Edge Function, via service role, grava objetos nesse bucket.
- Path do objeto: `<tipo-em-minúsculo>/<yyyy>/<exportacao_id>/<arquivo_nome>`, onde `<yyyy>` vem do timestamp de geração (`gerado_em`), não do período do relatório — mantém a retenção de 12 meses coerente com a data em que o objeto foi criado.
- Nome do arquivo: `relatorio-<tipo>-<data_inicial>-<data_final>-<id-curto-6-chars>.<pdf|zip>`.

### 8.3 RPCs principais

- **`categoria_relatorio_exportavel(p_tipo text, p_perfil text) RETURNS boolean`**: matriz de categoria exportável por perfil (Administrador: Financeiro/DRE/Clientes/Projetos; Financeiro: Financeiro/DRE; Projetos: Projetos; demais perfis: nenhuma). É o helper canônico derivado da mesma fonte de `listar_categorias_relatorios`, usado tanto na geração quanto no download.
- **`validar_periodo_exportacao(p_data_inicial date, p_data_final date)`**: valida datas obrigatórias, `data_final >= data_inicial` e período máximo de 12 meses corridos inclusivos (`2026-01-01`–`2026-12-31` permitido; `2026-01-01`–`2027-01-01` bloqueado).
- **`iniciar_exportacao_relatorio(p_tipo, p_formato, p_data_inicial, p_data_final) RETURNS jsonb`**: `SECURITY DEFINER`. Valida `auth.uid()`, `tem_capacidade('relatorios.exportar')`, perfil ativo, categoria dentro do escopo (`Financeiro`/`DRE`/`Clientes`/`Projetos`, senão `INVALID_CATEGORY`), categoria exportável para o perfil (senão `PERMISSION_DENIED`), formato (`PDF`/`CSV`) e período. Insere a linha com status `Pendente`, monta o payload completo (resumo + detalhes) chamando o builder da categoria (`montar_payload_relatorio_financeiro/dre/clientes/projetos`) e retorna tudo em uma única chamada.
- **`concluir_exportacao_relatorio(p_exportacao_id, p_arquivo_path, p_arquivo_nome, p_mime_type, p_tamanho_bytes, p_hash_sha256)`**: chamada pela Edge Function após o upload bem-sucedido. Valida ownership (`criado_por = auth.uid()`) e status `Pendente`, marca `Pronto`, define `expira_em = now() + 12 meses` e calcula `duracao_ms` a partir de `criado_em`.
- **`falhar_exportacao_relatorio(p_exportacao_id, p_erro)`**: marca `Falhou`, sanitiza a mensagem de erro (trunca em 500 caracteres) e nunca simula sucesso.
- **`autorizar_download_exportacao_relatorio(p_exportacao_id) RETURNS jsonb`**: valida capacidade, perfil ativo, categoria ainda exportável, escopo de acesso ao registro (Administrador vê/baixa tudo; Financeiro e Projetos apenas os próprios), status `Pronto` e não expirado. Retorna `arquivo_path`/`arquivo_nome`/`mime_type`/`expira_em` para a Edge Function assinar a URL — nunca retorna a URL em si.
- **`listar_exportacoes_relatorios(p_tipo text DEFAULT NULL) RETURNS TABLE(...)`**: read model do histórico com `status_exibicao` computado (`Expirado` quando `status = 'Pronto'` e `expira_em < now()`) e `pode_baixar` computado por status, validade, capacidade e categoria exportável atual. Visualizador, Comercial e Técnico recebem lista vazia (sem lançar exceção) por não terem histórico de exportação no escopo 008.
- A RPC legada `solicitar_exportacao_relatorio` permanece apenas por compatibilidade (comentário `DEPRECATED` na função); não participa do fluxo novo e continua sempre inserindo status `Indisponível` sem simular sucesso.

### 8.4 Fluxo de geração e download (Edge Function `relatorios-exportacao`)

A função roda em Deno, aceita `POST` com `{ action: 'gerar' | 'download', ... }` e autentica via `Authorization: Bearer <jwt do usuário>`.

- **`gerar`**: valida os campos de entrada, chama `iniciar_exportacao_relatorio` com um client Supabase criado com o JWT do usuário (não service role), renderiza o arquivo (`pdf-lib` para PDF; `fflate` para ZIP com `resumo.csv` + `detalhes.csv` quando a categoria tem os dois conjuntos), faz upload no bucket privado com um client de **service role** (criado só nesse ponto, nunca reaproveitado para chamar RPCs de negócio), chama `concluir_exportacao_relatorio` ou `falhar_exportacao_relatorio`, gera uma signed URL de 600 segundos (10 minutos) e retorna `{ exportacao, download_url, download_expires_in: 600 }`. Antes de renderizar, aplica o limite de volume operacional comum (até 5.000 linhas detalhadas ou 10 MB antes de compressão); acima disso, falha com `EXPORT_TOO_LARGE` sem gerar arquivo parcial.
- **`download`**: chama `autorizar_download_exportacao_relatorio` com o JWT do usuário e, se autorizado, usa o client de service role apenas para assinar uma nova URL de 600 segundos para o `arquivo_path` que a RPC retornou — nunca deriva o path por conta própria.
- Nenhuma URL pública ou permanente é criada ou retornada em nenhum dos dois fluxos; o service role nunca é usado para chamar as RPCs de negócio (sempre client user-scoped, preservando os checks de `auth.uid()`/ownership).
- Em caso de falha após o upload ter sido concluído mas a conclusão no banco falhar, a função tenta remover o objeto órfão do Storage (best-effort) antes de reportar a falha.

### 8.5 Retenção e expiração

- Validade de negócio: 12 meses a partir de `gerado_em`. `expira_em` é persistido no momento da conclusão.
- `Expirado` é um status de exibição **computado** em `listar_exportacoes_relatorios` (não persistido como `status`), evitando a necessidade de um cron/job para atualizar registros.
- Download de um registro `Expirado` é sempre negado por `autorizar_download_exportacao_relatorio`, com evento de auditoria `exportacao_download_negado`.
- Signed URLs (`download_expires_in`) têm vida curta de 600 segundos, independente da validade de 12 meses do registro — a cada novo pedido de download (imediato ou pelo histórico) uma nova signed URL é gerada sob demanda.

### 8.6 Observabilidade

Cada evento de exportação/download é registrado em `public.audit_log` (tabela de auditoria reaproveitada, com coluna `detalhes jsonb` adicionada para os campos estruturados) via `registrar_evento_exportacao`, com os eventos `exportacao_relatorio_iniciada`, `exportacao_relatorio_concluida`, `exportacao_relatorio_falhou`, `exportacao_download_autorizado` e `exportacao_download_negado`. Cada registro traz `exportacao_id`, usuário, tipo, formato, período, status, `duracao_ms`, `tamanho_bytes` (quando houver arquivo) e erro sanitizado (quando aplicável). A Edge Function também emite logs estruturados equivalentes (JSON por linha, via `console.log`/`console.error`) como camada adicional grepável, sem substituir os eventos gravados pela RPC.

## 9. Referências

- [contracts/guardrail-standard.md](../specs/006-rpc-security-hardening/contracts/guardrail-standard.md)
- [contracts/rpc-signatures.md](../specs/006-rpc-security-hardening/contracts/rpc-signatures.md)
- [contracts/ci-and-audit.md](../specs/006-rpc-security-hardening/contracts/ci-and-audit.md)
- [specs/007-rbac-capacidades-nomeadas/data-model.md](../specs/007-rbac-capacidades-nomeadas/data-model.md)
- [specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md](../specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md)
- [specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md](../specs/007-rbac-capacidades-nomeadas/contracts/rpc-capability-contract.md)
