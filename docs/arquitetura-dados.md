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

## 7. Referências

- [contracts/guardrail-standard.md](../specs/006-rpc-security-hardening/contracts/guardrail-standard.md)
- [contracts/rpc-signatures.md](../specs/006-rpc-security-hardening/contracts/rpc-signatures.md)
- [contracts/ci-and-audit.md](../specs/006-rpc-security-hardening/contracts/ci-and-audit.md)
