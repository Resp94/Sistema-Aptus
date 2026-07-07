# Runbook de Validação Remota e Governança de Advisors

## Objetivo

Validar remotamente o estado dos advisors no projeto `lpwnaxlczwntylcmgotm` antes e depois da aplicação das correções da feature 010.

## Pré-requisitos

- MCP do Supabase conectado ao projeto remoto de produção (`lpwnaxlczwntylcmgotm`).
- Configuração do MCP no workspace local (`.agents/mcp_config.json`) ativa.
- Acesso à ferramenta MCP Supabase (`get_project_url`, `get_advisors`, `list_migrations`).

---

## Passo 1: Baseline e Verificação do Projeto Remoto

1. Confirmar a referência do projeto remoto executando a ferramenta MCP `get_project_url` e verificando se ela retorna o endpoint `https://lpwnaxlczwntylcmgotm.supabase.co`.
2. Listar as migrations ativas em produção com a ferramenta MCP `list_migrations` para garantir que o banco remoto não possui conflitos pendentes.
3. Obter os warnings de segurança iniciais executando a ferramenta MCP `get_advisors` com o parâmetro `type="security"`.
4. Obter os warnings de performance iniciais executando a ferramenta MCP `get_advisors` com o parâmetro `type="performance"`.
5. Registrar no arquivo `triagem.md` (Seção 3.1) o snapshot dos achados obtidos no baseline.

## Passo 2: Estado Esperado e Análise de Impacto

1. Mapear os arquivos SQL locais de migração (`supabase/migrations/20260707000001_010_advisors_security.sql` e `20260707000002_010_advisors_performance.sql`).
2. Certificar que as RPCs afetadas foram devidamente triadas por dependência viva nas superfícies locais (`src/services`, `src/lib`, `supabase/functions/relatorios-exportacao/index.ts`).
3. Definir na matriz de `triagem.md` o estado esperado de cada item no escopo.

## Passo 3: Pós-aplicação (Revalidação via MCP)

1. Após a aplicação das migrations locais em produção, reexecutar o MCP `get_advisors(type="security")`.
2. Reexecutar o MCP `get_advisors(type="performance")`.
3. Validar se os achados de segurança no escopo (SEC-001 e SEC-002) sumiram completamente da lista ativa.
4. Validar se os achados de performance no escopo (PERF-001 e PERF-002) sumiram da lista.
5. Registrar o snapshot final na Seção 3.2 do `triagem.md`.

## Passo 4: Classificação Final dos Achados Remanescentes

Para cada achado remanescente retornado pelo linter, aplicar a seguinte taxonomia em `triagem.md`:
- `resolvido`: O lint sumiu da lista oficial após a aplicação da migration.
- `excecao_intencional`: O lint persiste (ou é gerado), mas é justificado por necessidade operacional legítima de negócio.
- `fora_escopo`: Lints que não pertencem ao grupo de segurança/RLS/RPC da feature 010 (ex: tuning de índices/FKs).

---

## Governança de Exceções (FR-019 / T032)

Qualquer achado classificado como `excecao_intencional` (tais como o privilégio de execução anônima de `registrar_evento_auditoria` ou acessos `authenticated` a RPCs) deve ser revisado periodicamente.

### 1. Gatilhos de Reavaliação de Exceções
A reavaliação das exceções intencionais cadastradas será disparada automaticamente sob qualquer um dos seguintes cenários:
- **Alteração de Assinatura**: Modificação na assinatura de qualquer RPC sob exceção.
- **Mudança de Grants ou Policies**: Execução de scripts que alterem privilégios (`GRANT`/`REVOKE`) ou políticas RLS nos objetos sob exceção.
- **Novos Lints de Segurança**: Geração de novos warnings de segurança pelos Advisors correlacionados a estas entidades.
- **Depreciação de Dependência Viva**: Quando o frontend ou Edge Functions deixarem de invocar a RPC/objeto mapeado sob exceção (eliminando o motivo de sua concessão).

### 2. Papel Responsável pela Reavaliação
O papel designado como **Lead Database Engineer / Security Custodian** é o responsável formal por executar a revisão, atualizar as justificativas em `triagem.md` e revalidar o estado remoto em caso de disparo dos gatilhos.

---

## Definição de Regressão

Será considerado regressão funcional ou de segurança qualquer ocorrência onde:
- Um papel (`anon`, `authenticated`) antes bloqueado passe a executar fluxos privilegiados ou ter acesso a dados indevidos.
- Um fluxo de negócio legítimo (ex: login, exportação, apontamentos) seja quebrado devido à revogação excessiva de privilégios.
- Uma regra de ownership, RLS ou capacidade nomeada seja afrouxada.

## Critérios de Encerramento

- Todos os lints do escopo classificados com `resolvido`, `excecao_intencional` ou `fora_escopo` na matriz.
- Nenhuma regressão detectada nas rodadas locais ou remotas.
- Memória do projeto e wiki de arquitetura sincronizados.

## Falhas que Bloqueiam a Conclusão

- Falha de conexão ou autenticação do MCP com o projeto remoto.
- Permanência de lints de segurança ou RLS ativos no escopo que não foram resolvidos nem catalogados como exceção.
- Quebra de testes funcionais no frontend ou banco.
