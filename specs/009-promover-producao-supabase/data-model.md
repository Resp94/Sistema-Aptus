# Data Model: Promover Producao Supabase

Esta feature nao introduz novas tabelas de negocio. O modelo abaixo descreve entidades operacionais do processo de promocao e validacao.

## Ambiente de Producao

**Representa**: Projeto Supabase real que recebera schema e Edge Function.

**Atributos**:
- `project_ref`: `lpwnaxlczwntylcmgotm`
- `api_url`: `https://lpwnaxlczwntylcmgotm.supabase.co`
- `classification`: `producao real`
- `backup_status`: `pendente`, `confirmado`, `falhou`
- `backup_evidence`: tipo de backup/snapshot, timestamp, origem da confirmacao, responsavel e declaracao de recuperabilidade
- `migration_state`: lista remota de migrations conhecidas antes da aplicacao

**Validations**:
- `project_ref` deve ser confirmado antes de qualquer mutacao.
- `backup_status` deve ser `confirmado` antes de aplicar schema.
- `backup_evidence` deve estar completa antes de aplicar schema; confirmacao generica sem tipo, timestamp, origem, responsavel e recuperabilidade nao fecha o gate.
- O ambiente nao pode receber seed/dump local nesta feature.

## Lote de Promocao

**Representa**: Conjunto de artefatos versionados que sera promovido.

**Atributos**:
- `scope`: migrations versionadas, regras de acesso, Storage privado, RPCs, Edge Function `relatorios-exportacao`
- `excluded_scope`: seed, dumps, dados locais, usuarios permanentes de teste
- `destination_gate`: `pendente`, `confirmado`, `falhou`
- `backup_gate`: `pendente`, `confirmado`, `falhou`
- `migration_state_gate`: `pendente`, `revisado`, `falhou`
- `dry_run_output`: lista de migrations que seriam aplicadas
- `dry_run_gate`: `pendente`, `revisado`, `falhou`
- `manual_approval`: `pendente`, `aprovado`, `rejeitado`
- `apply_status`: `nao_iniciado`, `aplicado`, `falhou`
- `function_deploy_status`: `nao_iniciado`, `publicado`, `falhou`
- `secrets_status`: `pendente`, `confirmado`, `falhou`
- `smoke_status`: `nao_iniciado`, `aprovado`, `bloqueado`
- `env_switch_status`: `nao_iniciado`, `validado`, `revertido`, `bloqueado`

**State transitions**:
```text
nao_iniciado
-> destino_confirmado
-> backup_confirmado
-> historico_remoto_revisado
-> dry_run_revisado
-> aprovado_manualmente
-> schema_aplicado
-> funcao_publicada
-> secrets_confirmados
-> smoke_test_aprovado
-> env_local_validado
```

**Blocking states**:
- `dry_run_com_mudanca_inesperada`
- `destino_divergente`
- `backup_nao_confirmado`
- `historico_remoto_conflitante`
- `drift_remoto`
- `estado_remoto_inconclusivo`
- `aprovacao_manual_pendente`
- `aplicacao_falhou`
- `deploy_funcao_falhou`
- `secrets_nao_confirmados`
- `smoke_test_bloqueado`
- `env_local_bloqueado`

## Edge Function Remota

**Representa**: Funcao `relatorios-exportacao` publicada em producao.

**Atributos**:
- `name`: `relatorios-exportacao`
- `actions`: `gerar`, `download`
- `jwt_required`: true
- `secret_status`: `pendente`, `confirmado`, `falhou`
- `deploy_status`: `nao_publicada`, `publicada`, `falhou`

**Validations**:
- Deploy so deve ser validado apos schema aplicado.
- Secrets privilegiados devem existir apenas no ambiente server-side.
- A funcao deve manter verificacao JWT habilitada.

## Usuario Temporario de Smoke Test

**Representa**: Usuario criado em producao somente para validacao operacional.

**Atributos**:
- `purpose`: `smoke-test`
- `persona`: perfil autorizado ou perfil sem permissao
- `created_for_feature`: `009-promover-producao-supabase`
- `cleanup_status`: `pendente`, `removido`, `desativado`, `falhou`

**Validations**:
- Deve existir ao menos um usuario autorizado e um usuario sem permissao.
- Todos devem ser removidos ou desativados antes do encerramento da validacao.
- A limpeza deve ser registrada em `.agents` e `.sauron`.

## Smoke Test Remoto

**Representa**: Validacao minima da producao apos schema e Edge Function.

**Atributos**:
- `authorized_export_result`: `passou`, `falhou`, `nao_executado`
- `unauthorized_block_result`: `passou`, `falhou`, `nao_executado`
- `file_access_result`: `passou`, `falhou`, `nao_executado`
- `cleanup_result`: `passou`, `falhou`, `nao_executado`
- `overall_status`: `aprovado`, `bloqueado`

**Validation rules**:
- `overall_status` so pode ser `aprovado` se todos os resultados obrigatorios forem `passou`.
- Qualquer falha bloqueia a troca de `.env.local`.

## Configuracao Local da Aplicacao

**Representa**: `.env.local` consumido pelo frontend local.

**Atributos**:
- `VITE_SUPABASE_URL`: URL publica do projeto alvo
- `VITE_SUPABASE_ANON_KEY`: chave publica apropriada ao cliente
- `VITE_APP_ENV`: marcador do ambiente

**Validations**:
- Nao pode conter service role, secret key ou senha de banco.
- So pode apontar para producao depois de smoke test remoto aprovado.
- Deve ser reversivel para o ambiente anterior se validacao local falhar.

## Registro Operacional

**Representa**: Documentacao obrigatoria do processo.

**Atributos**:
- `date`: data da execucao
- `target`: projeto de producao
- `scope`: artefatos promovidos
- `gates`: backup, dry-run, aprovacao manual, deploy, smoke test, cleanup
- `results`: sucesso/falha por checkpoint
- `pending_items`: pendencias ou bloqueios

**Validations**:
- Deve ser atualizado na mesma sessao da mutacao.
- Deve existir em `.agents` e `.sauron`.
