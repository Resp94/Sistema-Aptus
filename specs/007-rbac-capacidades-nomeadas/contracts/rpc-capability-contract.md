# Contract: RPCs e Capacidades

Este contrato define qual capacidade cada RPC de escrita ou acao sensivel deve validar.

## Padrao Canonico

```sql
IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
END IF;

IF NOT public.tem_capacidade('<recurso.acao>') THEN
  RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
END IF;
```

Para capacidades proprias, a RPC tambem valida ownership antes de alterar estado.

## Helpers Novos

### `tem_capacidade(p_capacidade text)`

**Entrada**: nome da capacidade.

**Retorno**: boolean.

**Contrato**:

- Retorna `false` para chamador anonimo.
- Retorna `false` para perfil inativo ou ausente.
- Retorna `true` apenas se existir linha em `public.capacidades_perfil` para o perfil ativo do usuario autenticado.
- Nao usa `user_metadata`.

### `obter_capacidades_usuario()`

**Entrada**: nenhuma.

**Retorno**: `text[]`.

**Contrato**:

- Requer usuario autenticado.
- Retorna lista ordenada de capacidades do perfil ativo.
- Retorna lista vazia para Visualizador.
- Usa `REVOKE EXECUTE FROM PUBLIC` e `GRANT EXECUTE TO authenticated`.

## Mapeamento de RPCs

### Clientes

| RPC | Capacidade |
|-----|------------|
| `criar_cliente` | `clientes.criar` |
| `atualizar_cliente` | `clientes.editar`, exceto reativacao |
| `atualizar_cliente` com status `Ativo` em cliente inativo | `clientes.reativar` |
| `inativar_cliente` | `clientes.inativar` |
| `registrar_atendimento` | `clientes.registrar_atendimento` |

### Propostas e Contratos

| RPC | Capacidade |
|-----|------------|
| `criar_proposta` | `propostas.criar` |
| `atualizar_proposta` | `propostas.editar` |
| `registrar_envio_proposta` | `propostas.enviar` |
| `criar_contrato` sem proposta vinculada | `contratos.criar` |
| `criar_contrato` gerado a partir de proposta | `propostas.gerar_contrato` |
| `renovar_contrato` | `contratos.renovar` |
| `encerrar_contrato` | `contratos.encerrar` |

### Cobrancas

| RPC | Capacidade |
|-----|------------|
| `criar_cobranca` | `cobrancas.emitir` |
| `solicitar_emissao_boleto` | `cobrancas.boleto` |
| `solicitar_lembrete_cobranca` | `cobrancas.notificar` |
| `registrar_pagamento_cobranca` | `cobrancas.baixar` |

### Projetos e Tarefas

| RPC | Capacidade |
|-----|------------|
| `criar_projeto` | `projetos.criar` |
| `atualizar_projeto` | `projetos.editar` |
| `excluir_projeto` | `projetos.excluir` |
| `criar_tarefa` | `tarefas.criar` |
| `excluir_tarefa` | `tarefas.excluir` |
| `atualizar_tarefa` | `tarefas.editar_qualquer` ou `tarefas.editar_propria` + ownership |
| `mover_tarefa` | `tarefas.mover_qualquer` ou `tarefas.mover_propria` + ownership |

### Equipe e Apontamentos

| RPC | Capacidade |
|-----|------------|
| `criar_membro_equipe` | `equipe.adicionar_membro` |
| `atualizar_membro_equipe` | `equipe.adicionar_membro` como administracao de ficha de membro |
| `alocar_membro_projeto` | `equipe.alocar` |
| `inativar_membro_equipe` | `equipe.inativar_membro` |
| `registrar_apontamento_horas` para proprio membro | `apontamentos.registrar_proprio` + ownership |
| `registrar_apontamento_horas` para qualquer membro | `apontamentos.registrar_qualquer` |

### Financeiro

| RPC | Capacidade |
|-----|------------|
| `criar_lancamento_financeiro` | `financeiro.lancar` |
| `atualizar_lancamento_financeiro` | `financeiro.editar_lancamento` |
| `registrar_pagamento_lancamento` | `financeiro.baixar_lancamento` |

### Configuracoes e Relatorios

| RPC | Capacidade |
|-----|------------|
| `atualizar_configuracoes_empresa` | `configuracoes.editar_empresa` |
| `atualizar_usuario_perfil` | `configuracoes.gerenciar_usuarios` + admin-only existente quando aplicavel |
| `atualizar_minhas_configuracoes` | `configuracoes.editar_proprio_perfil` + ownership |
| `atualizar_preferencias_notificacoes` | `configuracoes.editar_proprio_perfil` |
| `solicitar_exportacao_relatorio` | `relatorios.exportar` |
| `agendar_relatorio` | `relatorios.exportar` |

## Leituras que Continuam por Modulo

Leituras como `listar_clientes`, `listar_projetos`, `listar_tarefas_kanban`, `listar_cobrancas`, `obter_*_detalhe`, `listar_exportacoes_relatorios` e `obter_minhas_configuracoes` continuam usando `permissao_modulo` e regras de escopo/ownership existentes.

## Regras Especiais

- `listar_membros_equipe` para usuario sem leitura ampla de equipe retorna proprio membro + colegas com alocacao ativa nos mesmos projetos em andamento.
- Na leitura limitada de equipe, linhas de colegas podem retornar somente `id`, `nome`, `funcao`, `habilidades`, `status`, `capacidade` e `projeto_atual` restrito ao projeto compartilhado; `perfil_id` e `custo_hora` devem voltar nulos, e nao deve haver exposicao de permissoes, contatos sensiveis, historico de apontamentos ou alocacoes fora dos projetos compartilhados.
- `registrar_apontamento_horas` aceita `tarefa_id = null`; string sentinela `"geral"` e invalida.
- `mover_tarefa` e `atualizar_tarefa` nao podem aceitar `*_propria` se `responsavel_id` nao for o `membros_equipe.id` vinculado ao perfil do usuario autenticado.
- A presenca do botao no frontend nao substitui nenhum guard acima.
