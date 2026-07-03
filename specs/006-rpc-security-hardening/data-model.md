# Phase 1 Data Model: Entidades de Segurança

Esta feature não cria tabelas de negócio novas. O "modelo" aqui são as entidades de **segurança** que a feature governa e as transições de estado relevantes. Referências: [spec.md](./spec.md), [research.md](./research.md).

## Entidade: Função de banco com privilégio elevado (RPC)

Representa cada função `SECURITY DEFINER` no schema `public` exposta como endpoint de dados.

| Atributo | Descrição | Regra |
|----------|-----------|-------|
| `nome` | Identificador da função | Único por assinatura |
| `security_definer` | Roda com privilégio do criador | MUST ser `true` para RPCs de dados |
| `search_path` | Escopo de resolução de nomes | MUST ser fixado (`SET search_path = public`) |
| `checa_permissao` | Verifica `permissao_modulo()` no corpo | MUST para funções de domínio; N/A para helpers de permissão/perfil e auditoria |
| `guarda_identidade` | Rejeita anônimo explicitamente | MUST (`auth.uid() IS NULL → Unauthorized`), salvo exceção da auditoria |
| `execute_revogado_public` | `REVOKE EXECUTE FROM PUBLIC` | MUST |
| `execute_concedido` | `GRANT EXECUTE TO authenticated` (e `anon` só na auditoria) | MUST |

**Classificação para auditoria/testes**:
- **Domínio** (23 do batch legado + geração nova): guarda + `permissao_modulo` + grants.
- **Helper de permissão/perfil** (`permissao_modulo`, `obter_permissoes_usuario`, `obter_perfil_usuario`): guarda + grants; não checam módulo (são a base do RBAC).
- **Auditoria** (`registrar_evento_auditoria`): exceção catalogada — `anon` permitido para whitelist.
- **Trigger** (`handle_auth_user_sync`, `validar_perfil_update`): não invocáveis diretamente; excluídas do teste guiado por catálogo; ainda MUST ter `search_path` fixo.

## Entidade: Evento de auditoria

Registro imutável de uma ação relevante em `public.audit_log`.

| Atributo | Descrição | Regra pós-feature |
|----------|-----------|-------------------|
| `evento` | Tipo do evento (ex.: `login_falha`, `login_sucesso`, `senha_alterada`, `usuario_criado`) | Livre, mas o conjunto pré-auth é fixo |
| `usuario_id` | Autor do evento | `auth.uid()` quando autenticado; `NULL` quando evento pré-auth anônimo; **nunca** um parâmetro do cliente |
| `ip_origem` | Origem declarada | Mantido como parâmetro (informativo) |
| `user_agent` | Agente declarado | Mantido como parâmetro (informativo) |

**Lista fixa de eventos pré-autenticação (whitelist anônima)**: `['login_falha']`. Extensível apenas por alteração explícita da função (não por parâmetro).

**Invariante de segurança**: não existe caminho em que um chamador escolha `usuario_id` diferente da própria sessão. (SC-004)

## Entidade: Perfil de acesso

Nível de autorização de um usuário, em `public.perfis`.

| Atributo | Valores | Regra |
|----------|---------|-------|
| `perfil_acesso` | `Administrador`, `Financeiro`, `Projetos`, `Comercial`, `Técnico`, `Visualizador` | Fonte confiável = tabela `perfis`, nunca `user_metadata` |
| `status` | `Ativo`, ... | Permissões só valem se `Ativo` |

**Transição no cadastro (corrigida)**:

```text
signup (auth.users INSERT)
  -> trigger handle_auth_user_sync
     -> perfis.perfil_acesso := 'Visualizador'   (SEMPRE; ignora raw_user_meta_data->>'perfil_acesso')
     -> perfis.nome/departamento := raw_user_meta_data (dados do usuário; OK)
```

**Transição de promoção (único caminho de elevação)**:

```text
Administrador -> RPC atualizar_usuario_perfil(alvo, novo_perfil)
  -> valida existe_perfil_admin(auth.uid())
  -> perfis.perfil_acesso := novo_perfil
```

## Entidade: Permissão de módulo

Par `(pode_ler, pode_escrever)` por módulo, derivado do `perfil_acesso` em `obter_permissoes_usuario()`.

| Módulo (exemplos) | Consumido por |
|-------------------|---------------|
| `clientes`, `projetos`, `financeiro`, `contas-pagar`, `contas-receber`, `fluxo-caixa`, `propostas`, `contratos`, `cobrancas`, `equipe`, `relatorios`, `configuracoes`, `dashboard` | RPCs de domínio (via `permissao_modulo(modulo)`) e políticas RLS |

**Regra de teste (matriz RBAC, FR-015)**: para cada um dos 6 perfis, o par `(pode_ler, pode_escrever)` retornado por `obter_permissoes_usuario()` deve bater com a definição de `00000000000000_usuarios_perfis.sql`, e uma escrita sem `pode_escrever` deve falhar.
