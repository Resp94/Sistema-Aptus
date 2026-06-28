# Contract: Equipe RPC

## Leitura

### `obter_metricas_equipe()`

Retorna `total_membros`, `projetos_ativos`, `em_projeto_ativo`, `ausentes`.

Escopo:
- Administrador/Projetos: equipe completa.
- Tecnico: proprio membro e alocacoes relacionadas.

### `listar_membros_equipe(p_status text, p_busca text)`

Retorna `id`, `nome`, `funcao`, `status`, `situacao`, `projeto_atual`, `capacidade`.

`custo_hora` so retorna para perfis autorizados.

### `obter_alocacao_por_projeto()`

Retorna distribuicao de membros por projeto.

### `obter_capacidade_equipe()`

Retorna capacidade por membro/projeto, respeitando escopo do perfil.

### `listar_apontamentos_horas(p_membro_id uuid, p_data_inicio date, p_data_fim date)`

Tecnico so ve os proprios apontamentos.

## Escopo Tecnico

- `alocacoes_projeto` define se o Tecnico pode ler projetos/tarefas.
- `alocacoes_equipe` define capacidade, percentual e historico operacional.
- Se um projeto existir apenas em `alocacoes_equipe`, ele nao amplia a autorizacao de projetos/tarefas do Tecnico sem registro correspondente em `alocacoes_projeto`.
- `custo_hora` e omitido da resposta para Tecnico e Visualizador.

## Escrita

### `criar_membro_equipe(payload jsonb)`

Administrador/Projetos com escrita em `equipe`.

### `atualizar_membro_equipe(p_id uuid, payload jsonb)`

Tecnico so pode atualizar campos proprios permitidos; nao pode alterar custo, perfil ou dados globais.

### `alocar_membro_projeto(payload jsonb)`

Cria/atualiza alocacao com percentual entre 1 e 100.

### `registrar_apontamento_horas(payload jsonb)`

Registra horas em tarefa/projeto. Tecnico pode registrar apenas para si.

### `inativar_membro_equipe(p_id uuid)`

Acao sensivel auditada.
