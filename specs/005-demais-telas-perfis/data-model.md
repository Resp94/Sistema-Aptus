# Data Model: Demais Telas por Perfil de Acesso

Este modelo complementa a feature 004. Nao duplica entidades ja criadas quando elas podem ser fonte canonica.

## Entidades existentes reutilizadas

### `clientes`

Fonte de clientes/fornecedores para propostas, contratos, cobrancas e contrapartes financeiras.

### `projetos`, `tarefas`

Fonte operacional para Equipe, apontamentos e relatorios operacionais.

### `lancamentos`

Fonte financeira canonica para Fluxo de Caixa, Contas a Pagar e Contas a Receber.

**Uso por tela**:
- Fluxo de Caixa: todos os registros por competencia/periodo.
- Contas a Pagar: `tipo = 'despesa'` e `natureza = 'a_pagar'`.
- Contas a Receber: `tipo = 'receita'` e `natureza = 'a_receber'`.
- Status vencido: derivado em consulta quando `status = 'Pendente'` e `data_vencimento < current_date`.

**Regra de fonte unica**: `Vencido` e estado de exibicao derivado. RPCs nao devem persistir `Vencido` como fonte primaria quando a regra pode ser calculada por `status = 'Pendente'` e `data_vencimento < current_date`.

## Novas entidades

### `propostas`

Propostas comerciais enviadas a clientes.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default `gen_random_uuid()` |
| cliente_id | uuid fk `clientes(id)` | obrigatorio |
| titulo | text | obrigatorio |
| descricao | text | opcional |
| valor | numeric(14,2) | obrigatorio, `>= 0` |
| status | text | `Rascunho`, `Enviado`, `Em analise`, `Aprovado`, `Rejeitado` |
| enviada_em | timestamptz | preenchido quando status vira `Enviado` |
| created_by | uuid | `auth.uid()` |
| created_at / updated_at | timestamptz | controle |

**Transicoes**: `Rascunho -> Enviado -> Em analise -> Aprovado/Rejeitado`; `Aprovado` pode originar contrato.

### `contratos`

Contratos firmados com clientes.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| cliente_id | uuid fk `clientes(id)` | obrigatorio |
| proposta_id | uuid fk `propostas(id)` | opcional |
| titulo | text | obrigatorio |
| data_inicio | date | obrigatorio |
| data_fim | date | obrigatorio, `>= data_inicio` |
| status | text | `Vigente`, `Vencimento proximo`, `Encerrado` |
| valor_recorrente | numeric(14,2) | `>= 0` |
| created_by | uuid | `auth.uid()` |
| created_at / updated_at | timestamptz | controle |

**Status derivado**: `Vencimento proximo` pode ser calculado por RPC quando `data_fim` esta nos proximos 30 dias e status base e `Vigente`.

### `documentos`

Anexos associados a contratos, propostas ou tarefas.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| tipo_relacionado | text | `contrato`, `proposta`, `tarefa` |
| relacionado_id | uuid | id do registro relacionado |
| nome | text | obrigatorio |
| arquivo_url | text | obrigatorio apenas quando houver upload real |
| status | text | `Pendente`, `Disponivel`, `Falhou` |
| enviado_por | uuid | `auth.uid()` |
| created_at | timestamptz | controle |

### `cobrancas`

Cobrancas de clientes, vinculadas opcionalmente a contrato e lancamento.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| cliente_id | uuid fk `clientes(id)` | obrigatorio |
| contrato_id | uuid fk `contratos(id)` | opcional |
| lancamento_id | uuid fk `lancamentos(id)` | opcional, quando gerou recebivel |
| valor | numeric(14,2) | obrigatorio, `> 0` |
| data_vencimento | date | obrigatorio |
| status | text | `Pendente`, `Pago`, `Vencido`, `Cancelado` |
| data_pagamento | date | preenchido quando pago |
| boleto_status | text | `Nao configurado`, `Pendente`, `Emitido`, `Falhou` |
| lembrete_status | text | `Nao enviado`, `Pendente`, `Enviado`, `Falhou` |
| created_by | uuid | `auth.uid()` |
| created_at / updated_at | timestamptz | controle |

**Status vencido**: exibido por derivacao quando pendente e vencida, sem depender de rotina diaria.

**Ownership**: Comercial pode criar/acompanhar cobrancas, lembretes e vinculos comerciais. Financeiro controla pagamento, conciliacao com `lancamentos`, cancelamento financeiro e dados monetarios completos. Administrador pode executar ambos. Uma cobranca vinculada a `lancamento_id` nao pode gerar outro lancamento para o mesmo recebivel.

### `pagamentos_cobrancas`

Historico de pagamentos contra cobrancas.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| cobranca_id | uuid fk `cobrancas(id)` | obrigatorio |
| valor | numeric(14,2) | `> 0` |
| pago_em | date | obrigatorio |
| forma_pagamento | text | `Boleto`, `Pix`, `Transferencia`, `Cartao`, `Outro` |
| created_by | uuid | `auth.uid()` |
| created_at | timestamptz | controle |

### `membros_equipe`

Membros internos/externos da equipe.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| perfil_id | uuid fk `perfis(id)` | opcional para membro com login |
| nome | text | obrigatorio |
| funcao | text | obrigatorio |
| habilidades | text[] | default vazio |
| status | text | `Disponivel`, `Alocado`, `Ferias`, `Ausente` |
| capacidade | int | 0 a 100 |
| custo_hora | numeric(14,2) | visivel apenas para perfis autorizados |
| created_at / updated_at | timestamptz | controle |

### `alocacoes_equipe`

Alocacao de membros em projetos.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| membro_equipe_id | uuid fk `membros_equipe(id)` | obrigatorio |
| projeto_id | uuid fk `projetos(id)` | obrigatorio |
| data_inicio | date | obrigatorio |
| data_fim | date | opcional |
| percentual_alocacao | int | 1 a 100 |
| funcao_no_projeto | text | opcional |
| created_at / updated_at | timestamptz | controle |

**Relacao com `alocacoes_projeto`**: `alocacoes_projeto` e a fonte de autorizacao minima para Tecnico enxergar projetos/tarefas. `alocacoes_equipe` e fonte operacional para capacidade, percentual e historico. Se houver divergencia, leitura tecnica de projetos/tarefas segue `alocacoes_projeto`; relatorios de capacidade usam `alocacoes_equipe`.

### `apontamentos_horas`

Tempo dedicado a tarefas/projetos.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| tarefa_id | uuid fk `tarefas(id)` | opcional |
| projeto_id | uuid fk `projetos(id)` | obrigatorio quando tarefa ausente |
| membro_equipe_id | uuid fk `membros_equipe(id)` | obrigatorio |
| horas | numeric(6,2) | `> 0` |
| descricao | text | opcional |
| data | date | obrigatorio |
| created_at | timestamptz | controle |

### `agendamentos_relatorios`

Solicitacoes recorrentes de relatorios.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| tipo | text | `Financeiro`, `DRE`, `Clientes`, `Projetos`, `Personalizado` |
| formato | text | `PDF`, `CSV` |
| filtros | jsonb | filtros salvos |
| frequencia | text | `Uma vez`, `Diario`, `Semanal`, `Mensal` |
| criado_por | uuid | `auth.uid()` |
| agendado_para | timestamptz | opcional |
| status | text | `Ativo`, `Inativo`, `Executado` |
| created_at / updated_at | timestamptz | controle |

### `exportacoes_relatorios`

Historico de exportacoes reais ou pendentes.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| agendamento_id | uuid fk `agendamentos_relatorios(id)` | opcional |
| tipo | text | mesmo dominio dos relatorios |
| formato | text | `PDF`, `CSV` |
| arquivo_url | text | nulo quando nao gerado |
| status | text | `Pendente`, `Pronto`, `Falhou`, `Indisponivel` |
| criado_por | uuid | `auth.uid()` |
| gerado_em | timestamptz | opcional |

### `configuracoes_empresa`

Configuracoes globais.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | registro unico |
| razao_social | text | opcional |
| documento | text | opcional |
| email | text | opcional |
| telefone | text | opcional |
| endereco | text | opcional |
| idioma | text | default `pt-BR` |
| formato_data | text | default `dd/MM/yyyy` |
| moeda | text | default `BRL` |
| inicio_ano_fiscal | date | opcional |
| dia_vencimento_padrao | int | 1 a 31 |
| percentual_multa_atraso | numeric(5,2) | `>= 0` |
| cobranca_automatica_ativa | boolean | default false |
| updated_at | timestamptz | controle |

### `preferencias_notificacoes`

Preferencias de notificacao por perfil.

| Campo | Tipo | Regras |
|-------|------|--------|
| id | uuid pk | default |
| perfil_id | uuid fk `perfis(id)` | obrigatorio |
| canal | text | `Email`, `Sistema` |
| tipo | text | `Lembretes`, `Alertas`, `Relatorio semanal`, `Cobrancas` |
| ativo | boolean | default true |
| updated_at | timestamptz | controle |

## RLS e RBAC

- Todas as novas tabelas em `public` devem ter RLS habilitado.
- Politicas usam `TO authenticated`, nunca `auth.role()`.
- Tabelas de leitura por modulo usam helper de permissao derivado de `obter_permissoes_usuario()`.
- `Tecnico` recebe escopo limitado em `equipe` e `configuracoes`: apenas proprio perfil/membro e alocacoes relacionadas.
- `Visualizador` recebe somente leitura em relatorios permitidos.
- Escrita fica sempre nas RPCs de dominio com checagem `pode_escrever`.
- Campos restritos por perfil devem ser omitidos na consulta/RPC, nao apenas ocultados no frontend. Isso inclui custo/hora, parametros financeiros globais, dados de usuarios fora do escopo, documentos restritos e valores financeiros quando o perfil nao tiver permissao.
- Mudanca administrativa de perfil/status deve invalidar a permissao efetiva na proxima leitura de perfil/permissoes; a rota atual deve ser reavaliada no proximo guard ou refresh.

## Classificacao de dados

| Classe | Campos/entidades | Tratamento |
|---|---|---|
| PII | nome, email, telefone, documento, endereco, avatar, preferencias pessoais | Visivel apenas para perfis autorizados e para o proprio usuario quando aplicavel |
| Financeiro sensivel | valores, pagamentos, cobrancas, parametros financeiros, multa, vencimento padrao | Restrito a Administrador/Financeiro conforme modulo |
| Operacional sensivel | custo_hora, capacidade detalhada, alocacoes internas | Restrito a Administrador/Projetos; Tecnico ve apenas proprio recorte sem custo |
| Configuracao sensivel | perfis de acesso, status de usuarios, integracoes, configuracoes globais | Restrito a Administrador |

## Estados invalidos e recuperacao

- Entidade relacionada ausente/inativa: preservar exibicao do registro com indicador de vinculo indisponivel/inativo; bloquear novas acoes dependentes do vinculo.
- Escrita com falha: nao alterar estado persistido, manter formulario quando possivel e permitir retry.
- Integracao pendente: preservar status principal do registro e gravar status especifico de integracao (`Indisponivel`, `Pendente`, `Falhou`).
- Duplicidade cobranca/lancamento: rejeitar criacao duplicada ou reutilizar `lancamento_id` existente.

## Auditoria

Estender `audit_log.evento` para eventos novos:

- `proposta_excluida`
- `contrato_encerrado`
- `cobranca_cancelada`
- `membro_equipe_inativado`
- `perfil_acesso_alterado`
- `parametro_financeiro_alterado`
- `configuracao_global_alterada`

Cada RPC sensivel chama `registrar_evento_auditoria(...)` com `auth.uid()`.
