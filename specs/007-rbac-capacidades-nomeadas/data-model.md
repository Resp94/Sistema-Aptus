# Data Model: RBAC por Capacidades Nomeadas

## Entidade: Capacidade Nomeada

Representa uma permissao atomica de acao no formato `recurso.acao`.

**Campos**

| Campo | Tipo | Obrigatorio | Regra |
|-------|------|-------------|-------|
| `capacidade` | text | Sim | Deve seguir `^[a-z0-9_-]+\\.[a-z0-9_-]+$` por convencao/teste. |
| `recurso` | derivado | Sim | Parte antes do ponto. Ex.: `tarefas`. |
| `acao` | derivado | Sim | Parte depois do ponto. Ex.: `mover_propria`. |

**Catalogo inicial**

```text
clientes.criar
clientes.editar
clientes.inativar
clientes.reativar
clientes.registrar_atendimento
propostas.criar
propostas.editar
propostas.enviar
propostas.gerar_contrato
contratos.criar
contratos.renovar
contratos.encerrar
cobrancas.emitir
cobrancas.boleto
cobrancas.notificar
cobrancas.baixar
projetos.criar
projetos.editar
projetos.excluir
tarefas.criar
tarefas.excluir
tarefas.editar_qualquer
tarefas.mover_qualquer
tarefas.editar_propria
tarefas.mover_propria
equipe.adicionar_membro
equipe.alocar
equipe.inativar_membro
apontamentos.registrar_proprio
apontamentos.registrar_qualquer
financeiro.lancar
financeiro.editar_lancamento
financeiro.baixar_lancamento
configuracoes.gerenciar_usuarios
configuracoes.editar_empresa
configuracoes.editar_proprio_perfil
relatorios.exportar
```

## Entidade: Matriz de Capacidades por Perfil

Tabela canonica: `public.capacidades_perfil`.

**Campos**

| Campo | Tipo | Obrigatorio | Regra |
|-------|------|-------------|-------|
| `perfil_acesso` | text | Sim | Deve corresponder a um perfil tecnico valido: `Administrador`, `Financeiro`, `Projetos`, `Comercial`, `Técnico`, `Visualizador`. |
| `capacidade` | text | Sim | Deve existir no catalogo inicial. |

**Chave primaria**

`(perfil_acesso, capacidade)`

**Relacionamentos**

- `perfil_acesso` se relaciona logicamente com `public.perfis.perfil_acesso`.
- `capacidade` e validada por seed/teste contra o catalogo esperado.

**RLS e grants**

- RLS habilitado.
- Acesso direto do frontend nao e contrato publico.
- Leitura pelo frontend ocorre por `public.obter_capacidades_usuario()`.
- Escrita inicial ocorre via migration/seed; UI administrativa futura fica fora do escopo.

## Matriz Inicial por Perfil

### Administrador

Recebe todas as capacidades catalogadas.

### Financeiro

```text
financeiro.lancar
financeiro.editar_lancamento
financeiro.baixar_lancamento
cobrancas.emitir
cobrancas.baixar
relatorios.exportar
configuracoes.editar_proprio_perfil
```

### Projetos

```text
projetos.criar
projetos.editar
projetos.excluir
tarefas.criar
tarefas.excluir
tarefas.editar_qualquer
tarefas.mover_qualquer
equipe.adicionar_membro
equipe.alocar
equipe.inativar_membro
apontamentos.registrar_qualquer
relatorios.exportar
configuracoes.editar_proprio_perfil
```

### Comercial

```text
clientes.criar
clientes.editar
clientes.inativar
clientes.reativar
clientes.registrar_atendimento
propostas.criar
propostas.editar
propostas.enviar
propostas.gerar_contrato
contratos.criar
contratos.renovar
contratos.encerrar
cobrancas.emitir
cobrancas.boleto
cobrancas.notificar
configuracoes.editar_proprio_perfil
```

### Técnico

```text
tarefas.editar_propria
tarefas.mover_propria
apontamentos.registrar_proprio
configuracoes.editar_proprio_perfil
```

### Visualizador

Zero capacidades. Mantem apenas leitura minima por modulo em `relatorios` e `configuracoes` proprias.

## Entidade: Permissao de Modulo

Continua retornada por `obter_permissoes_usuario()` e usada em `RequirePermissao`, menu e leitura.

**Mudancas esperadas**

- `pode_escrever` deixa de ser fonte canonica de acoes no frontend.
- `Visualizador`: leitura minima em `relatorios` e `configuracoes`; sem escrita.
- `Projetos`: sem Dashboard oficial, salvo decisao posterior.
- `Financeiro`: Dashboard oficial.

## Entidade: Capacidade da Sessao

Lista de textos retornada por `obter_capacidades_usuario()` e armazenada no contexto de auth.

**Campos no frontend**

| Campo | Tipo | Regra |
|-------|------|-------|
| `capacidades` | string[] | Lista vazia quando nao autenticado ou quando o perfil nao possui capacidades. |

**Invariantes**

- `capacidades` nunca autoriza sozinha no backend.
- Helper `pode(capacidades, capacidade)` retorna `false` para lista ausente, capacidade ausente ou texto invalido.
- Mudanca de sessao/perfil recarrega capacidades junto com perfil e permissoes.

## Entidade: Operacao Protegida

Qualquer RPC de escrita ou acao sensivel com efeito de negocio.

**Exemplos**

- Escrita direta: criar/atualizar/excluir projeto, tarefa, cliente, contrato, lancamento.
- Efeito de negocio: boleto, notificacao, exportacao, envio de proposta, gerar contrato, baixa.

**Regra de validacao**

1. Deve exigir `auth.uid()` autenticado.
2. Deve validar `tem_capacidade('<recurso.acao>')`.
3. Se a capacidade for `*_propria`/`*_proprio`, deve validar ownership.
4. Deve manter `REVOKE EXECUTE FROM PUBLIC` e `GRANT EXECUTE TO authenticated`.

## Entidade: Ownership

Relacionamento usado para limitar capacidades proprias.

| Dominio | Ownership |
|---------|-----------|
| Tarefas | `tarefas.responsavel_id = membros_equipe.id` do membro vinculado ao perfil do usuario autenticado (`perfis.usuario_id = auth.uid()`) |
| Apontamentos | `membros_equipe.perfil_id` pertence ao perfil do usuario autenticado |
| Configuracoes proprias | Registro alvo corresponde ao usuario autenticado |

## Escopo de Leitura: Equipe Limitada do Tecnico

`listar_membros_equipe` deve tratar Tecnico como leitura limitada, nao como leitura ampla de equipe.

**Inclusao de linhas**

- Sempre incluir o proprio membro vinculado ao perfil do usuario autenticado.
- Incluir colegas somente quando o Tecnico e o colega tiverem alocacoes ativas no mesmo projeto em andamento.
- Alocacao ativa significa `alocacoes_equipe.data_fim IS NULL OR alocacoes_equipe.data_fim >= current_date`.
- Projeto ativo significa projeto em andamento.

**Campos permitidos para colegas**

- `id`
- `nome`
- `funcao`
- `habilidades`
- `status`
- `capacidade`
- `projeto_atual`, limitado ao projeto ativo compartilhado com o Tecnico

**Campos e dados limitados para colegas**

- `perfil_id` deve ser nulo ou omitido.
- `custo_hora` deve ser nulo.
- Permissoes, dados de autenticacao, contatos sensiveis, historico de apontamentos e alocacoes fora dos projetos compartilhados nao podem ser expostos por essa leitura limitada.

## State Transitions

### Cliente

```text
Ativo --clientes.inativar--> Inativo
Inativo --clientes.reativar--> Ativo
```

### Tarefa

```text
A Fazer --tarefas.mover_*--> Em andamento
Em andamento --tarefas.mover_*--> Concluido
```

`*_propria` exige responsavel autenticado; `*_qualquer` permite responsavel diferente.

### Apontamento de horas

```text
payload.tarefa_id = uuid  -> apontamento vinculado a tarefa
payload.tarefa_id = null  -> atividade geral do projeto
```

String sentinela como `"geral"` e invalida no contrato de dados.

### Visualizador

```text
Signup -> Visualizador -> promocao administrativa -> Perfil operacional
```

Visualizador nao e persona operacional; e estado tecnico minimo ate promocao.
