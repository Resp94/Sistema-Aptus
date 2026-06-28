# Contract: Relatorios e Configuracoes RPC

## Relatorios

### `listar_categorias_relatorios()`

Retorna categorias permitidas pelo perfil: financeiro, comercial, operacional, clientes, personalizado.

### `gerar_previa_relatorio(p_tipo text, p_filtros jsonb)`

Retorna dados agregados para visualizacao em tela. Nao gera arquivo.

### `listar_exportacoes_relatorios(p_tipo text)`

Retorna `id`, `tipo`, `formato`, `status`, `arquivo_url`, `gerado_em`.

### `solicitar_exportacao_relatorio(p_tipo text, p_formato text, p_filtros jsonb)`

Se gerador real nao existir, cria registro com `status = 'Indisponivel'` ou retorna indisponibilidade clara.

Nao deve criar `arquivo_url` falso. `arquivo_url` permanece nulo ate existir geracao real.

### `agendar_relatorio(payload jsonb)`

Cria agendamento quando perfil tem escrita no modulo `relatorios`.

## Configuracoes

### `obter_configuracoes_empresa()`

Administrador ve configuracoes globais. Outros perfis nao recebem dados globais.

### `atualizar_configuracoes_empresa(payload jsonb)`

Administrador apenas. Alteracoes de parametros financeiros e globais geram auditoria.

### `listar_usuarios_configuracoes()`

Administrador apenas. Retorna usuarios, perfil tecnico, status e departamento.

### `atualizar_usuario_perfil(p_usuario_id uuid, payload jsonb)`

Administrador apenas. Mudanca de perfil/status gera auditoria e atualiza permissoes derivadas.

Se o usuario afetado estiver autenticado, a nova permissao deve valer na proxima leitura de perfil/permissoes ou proxima avaliacao de rota protegida. A rota atual deve redirecionar quando deixar de ser permitida.

### `obter_minhas_configuracoes()`

Retorna dados proprios e preferencias permitidas do usuario autenticado.

### `atualizar_minhas_configuracoes(payload jsonb)`

Atualiza apenas dados proprios permitidos e preferencias pessoais.

### `listar_preferencias_notificacoes()`

Retorna preferencias do perfil autenticado.

### `atualizar_preferencias_notificacoes(payload jsonb)`

Atualiza preferencias pessoais. Administrador pode alterar configuracoes globais de notificacao quando existirem.

## Privacidade

- `listar_usuarios_configuracoes` retorna dados administrativos apenas para Administrador.
- `obter_minhas_configuracoes` retorna apenas dados do proprio usuario autenticado.
- Campos de configuracao global, perfil de acesso de terceiros e parametros financeiros nao sao retornados para Tecnico ou Visualizador.
