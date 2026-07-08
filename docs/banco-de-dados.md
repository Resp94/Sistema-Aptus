# Banco de Dados

## Convenções

- `uuid` — identificador único (primary key).
- `timestamp` — data/hora com fuso UTC.
- `number` — valores monetários armazenados com precisão decimal.
- `text` — strings de tamanho variável.
- `text[]` — array de strings (PostgreSQL).
- `jsonb` — dados estruturados em JSON (PostgreSQL).
- `fk` — foreign key para outra tabela.

> **Todas as tabelas são nomeadas em pt-BR.**

---

## usuarios

Espelho dos dados do provedor de autenticação. Não contém regras de negócio do aplicativo.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | UID gerado pelo auth provider |
| email | text | Email único de autenticação |
| email_confirmed_at | timestamp | Data de confirmação do email |
| phone | text | Telefone vinculado à conta |
| phone_confirmed_at | timestamp | Data de confirmação do telefone |
| raw_user_meta_data | jsonb | Metadados públicos do usuário (ex.: nome, departamento) |
| raw_app_meta_data | jsonb | Metadados internos do app controlados pelo backend |
| aud | text | Audience do token de autenticação |
| created_at | timestamp | Data de criação da conta no auth |
| updated_at | timestamp | Última atualização no auth |
| last_sign_in_at | timestamp | Último login realizado |

## perfis

Dados aplicacionais de cada usuário autenticado.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| usuario_id | uuid fk | Referência a `usuarios.id` (1:1) |
| nome | text | Nome completo exibido no sistema |
| perfil_acesso | text | Perfil RBAC: Administrador, Financeiro, Operacional, Visualizador |
| status | text | Ativo ou Inativo |
| departamento | text | Departamento/setor |
| created_at | timestamp | - |
| updated_at | timestamp | - |

Observação atual: a feature de avatar/foto de perfil foi descontinuada em 2026-07-08. O contrato vivo de `perfis` não inclui `avatar_url`, e o shell do sistema usa apenas as iniciais do nome do usuário.

## clientes

Clientes cadastrados no sistema com informações de contato e dados comerciais.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| nome | text | Nome ou razão social |
| email | text | Email principal |
| telefone | text | Telefone |
| documento | text | CPF/CNPJ |
| endereco | text | Endereço completo |
| status | text | Ativo, Inativo ou Prospect |
| receita_acumulada | number | Receita acumulada do cliente |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## fornecedores

Fornecedores e prestadores de serviço vinculados às contas a pagar.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| nome | text | Nome ou razão social |
| email | text | Email principal |
| telefone | text | Telefone |
| documento | text | CPF/CNPJ |
| endereco | text | Endereço completo |
| categoria | text | Categoria (ex.: Software, Infraestrutura, Marketing) |
| prazo_pagamento | number | Prazo de pagamento padrão em dias |
| status | text | Ativo ou Inativo |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## historico_clientes

Registro de histórico de atendimentos e interações com clientes.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| cliente_id | uuid fk | Referência ao cliente |
| perfil_id | uuid fk | Perfil do usuário que registrou a interação |
| acao | text | Tipo de ação (ligação, email, reunião, nota) |
| descricao | text | Detalhes do atendimento |
| created_at | timestamp | Data do registro |

## propostas

Propostas comerciais enviadas a clientes com status e valores.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| cliente_id | uuid fk | Cliente destinatário |
| titulo | text | Título da proposta |
| descricao | text | Descrição/detalhamento |
| valor | number | Valor total |
| status | text | Rascunho, Enviado, Em análise, Aprovado, Rejeitado |
| enviada_em | timestamp | Data de envio |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## contratos

Contratos firmados com clientes, com vigência e documentos anexados.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| cliente_id | uuid fk | Cliente contratante |
| proposta_id | uuid fk | Proposta de origem (opcional) |
| titulo | text | Título ou número do contrato |
| data_inicio | timestamp | Início da vigência |
| data_fim | timestamp | Fim da vigência |
| status | text | Vigente, Vencimento próximo, Encerrado |
| valor_recorrente | number | Valor recorrente mensal |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## documentos

Documentos anexados a contratos, propostas ou outros registros.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| tipo_relacionado | text | Entidade relacionada: contrato, proposta, tarefa |
| relacionado_id | uuid fk | ID do registro relacionado |
| nome | text | Nome do arquivo |
| arquivo_url | text | URL de armazenamento do documento |
| enviado_por | uuid fk | Perfil do usuário que fez o upload |
| created_at | timestamp | - |

## cobrancas

Cobranças geradas a partir de contratos, com status de pagamento e emissão de boletos.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| contrato_id | uuid fk | Contrato de origem (opcional) |
| cliente_id | uuid fk | Cliente cobrado |
| valor | number | Valor da cobrança |
| data_vencimento | timestamp | Data de vencimento |
| status | text | Pendente, Pago, Vencido |
| data_pagamento | timestamp | Data do pagamento |
| boleto_url | text | URL do boleto gerado |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## pagamentos_cobrancas

Pagamentos registrados contra cobranças, permitindo múltiplos pagamentos parciais.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| cobranca_id | uuid fk | Cobrança quitada |
| valor | number | Valor pago |
| pago_em | timestamp | Data do pagamento |
| forma_pagamento | text | Boleto, Pix, Transferência, Cartão |
| created_at | timestamp | - |

## projetos

Projetos gerenciados pela equipe, com prazos e responsáveis.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| cliente_id | uuid fk | Cliente do projeto |
| nome | text | Nome do projeto |
| descricao | text | Descrição |
| data_inicio | timestamp | Início |
| data_fim | timestamp | Prazo de entrega |
| status | text | Planejado, Em andamento, Concluído, Cancelado, Em risco |
| orcamento | number | Orçamento total |
| percentual_progresso | number | Percentual de progresso |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## tarefas

Tarefas vinculadas a projetos, com status e responsável para acompanhamento no Kanban.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| projeto_id | uuid fk | Projeto da tarefa |
| titulo | text | Título |
| descricao | text | Descrição |
| status | text | A Fazer, Em Andamento, Concluído |
| responsavel_id | uuid fk | Membro da equipe responsável |
| data_limite | timestamp | Prazo |
| horas_estimadas | number | Horas estimadas |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## apontamentos_horas

Registro de tempo dedicado às tarefas pelos profissionais técnicos.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| tarefa_id | uuid fk | Tarefa executada |
| membro_equipe_id | uuid fk | Profissional que executou |
| horas | number | Quantidade de horas |
| descricao | text | Observação sobre o trabalho |
| data | timestamp | Data do apontamento |
| created_at | timestamp | - |

## categorias

Categorias financeiras reutilizáveis para contas a pagar, receber e fluxo de caixa.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| nome | text | Nome da categoria |
| tipo | text | Receita, Despesa ou Ambos |
| descricao | text | Descrição opcional |
| created_at | timestamp | - |

## lancamentos_fluxo_caixa

Movimentações financeiras gerais de entradas e saídas do fluxo de caixa.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| tipo | text | Entrada ou Saída |
| descricao | text | Descrição |
| valor | number | Valor |
| data | timestamp | Data da movimentação |
| categoria_id | uuid fk | Categoria financeira |
| cliente_id | uuid fk | Cliente relacionado (opcional) |
| fornecedor_id | uuid fk | Fornecedor relacionado (opcional) |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## contas_pagar

Obrigações financeiras com fornecedores, vencimentos e pagamentos.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| fornecedor_id | uuid fk | Fornecedor credor |
| descricao | text | Descrição da despesa |
| valor | number | Valor |
| data_vencimento | timestamp | Data de vencimento |
| data_pagamento | timestamp | Data do pagamento |
| status | text | Pendente, Pago, Vencido |
| categoria_id | uuid fk | Categoria |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## contas_receber

Faturas e recebíveis de clientes, integrado ou independente das cobranças.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| cliente_id | uuid fk | Cliente devedor |
| cobranca_id | uuid fk | Cobrança vinculada (opcional) |
| descricao | text | Descrição |
| valor | number | Valor |
| data_vencimento | timestamp | Data de vencimento |
| data_pagamento | timestamp | Data do pagamento |
| status | text | Pendente, Pago, Vencido, Hoje |
| categoria_id | uuid fk | Categoria |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## membros_equipe

Membros da equipe técnica, com função, disponibilidade e alocação atual.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| perfil_id | uuid fk | Perfil do usuário no sistema (opcional) |
| nome | text | Nome do membro |
| funcao | text | Função técnica: Dev Fullstack, Front-end, Automação, Designer, etc. |
| habilidades | text[] | Lista de habilidades |
| status | text | Disponível, Alocado, Férias, Ausente |
| projeto_atual_id | uuid fk | Projeto atual (opcional) |
| capacidade | number | Capacidade percentual disponível (0-100) |
| custo_hora | number | Custo hora (opcional) |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## alocacoes_equipe

Histórico e controle de alocação dos membros da equipe nos projetos.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| membro_equipe_id | uuid fk | Membro alocado |
| projeto_id | uuid fk | Projeto |
| data_inicio | timestamp | Início da alocação |
| data_fim | timestamp | Fim previsto |
| percentual_alocacao | number | Percentual de alocação (0-100) |
| funcao_no_projeto | text | Função no projeto |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## agendamentos_relatorios

Agendamentos de relatórios periódicos criados pelos usuários.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| tipo | text | Tipo do relatório (Financeiro, DRE, Clientes, Fluxo de Caixa, Contas, Personalizado) |
| formato | text | PDF ou CSV |
| filtros | jsonb | Filtros salvos (período, categoria, cliente) |
| frequencia | text | Uma vez, Diário, Semanal, Mensal |
| criado_por | uuid fk | Perfil do usuário criador |
| agendado_para | timestamp | Data/hora do agendamento |
| status | text | Ativo, Inativo, Executado |
| created_at | timestamp | - |
| updated_at | timestamp | - |

## exportacoes_relatorios

Exportações já geradas e disponíveis para download.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| agendamento_id | uuid fk | Agendamento de origem (opcional) |
| tipo | text | Tipo do relatório |
| formato | text | PDF ou CSV |
| arquivo_url | text | URL do arquivo gerado |
| criado_por | uuid fk | Perfil do usuário que gerou |
| gerado_em | timestamp | Data de geração |
| status | text | Pronto, Processando, Falhou |

## configuracoes_empresa

Configurações gerais da empresa mantidas na tela Configurações.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| razao_social | text | Nome da empresa |
| documento | text | CNPJ |
| email | text | Email institucional |
| telefone | text | Telefone |
| endereco | text | Endereço |
| idioma | text | Idioma padrão |
| formato_data | text | Formato de data |
| moeda | text | Moeda |
| inicio_ano_fiscal | timestamp | Início do ano fiscal |
| dia_vencimento_padrao | number | Dia de vencimento padrão |
| percentual_multa_atraso | number | Percentual de multa por atraso |
| cobranca_automatica_ativa | boolean | Cobrança automática ativa |
| updated_at | timestamp | - |

## preferencias_notificacoes

Preferências de notificações por usuário.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| perfil_id | uuid fk | Perfil do usuário |
| canal | text | Email ou Sistema |
| tipo | text | Lembretes, Alertas, Relatório semanal, Cobranças |
| ativo | boolean | Ativo ou inativo |
| updated_at | timestamp | - |

---

## Relacionamentos principais

- `perfis.usuario_id → usuarios.id` (1:1)
- `historico_clientes.cliente_id → clientes.id`
- `historico_clientes.perfil_id → perfis.id`
- `propostas.cliente_id → clientes.id`
- `contratos.cliente_id → clientes.id`
- `contratos.proposta_id → propostas.id`
- `documentos.relacionado_id` (polimórfico) → `contratos`, `propostas` ou `tarefas`
- `cobrancas.contrato_id → contratos.id`
- `cobrancas.cliente_id → clientes.id`
- `pagamentos_cobrancas.cobranca_id → cobrancas.id`
- `projetos.cliente_id → clientes.id`
- `tarefas.projeto_id → projetos.id`
- `tarefas.responsavel_id → membros_equipe.id`
- `apontamentos_horas.tarefa_id → tarefas.id`
- `apontamentos_horas.membro_equipe_id → membros_equipe.id`
- `lancamentos_fluxo_caixa.categoria_id → categorias.id`
- `lancamentos_fluxo_caixa.cliente_id → clientes.id`
- `lancamentos_fluxo_caixa.fornecedor_id → fornecedores.id`
- `contas_pagar.fornecedor_id → fornecedores.id`
- `contas_pagar.categoria_id → categorias.id`
- `contas_receber.cliente_id → clientes.id`
- `contas_receber.cobranca_id → cobrancas.id`
- `contas_receber.categoria_id → categorias.id`
- `membros_equipe.perfil_id → perfis.id`
- `membros_equipe.projeto_atual_id → projetos.id`
- `alocacoes_equipe.membro_equipe_id → membros_equipe.id`
- `alocacoes_equipe.projeto_id → projetos.id`
- `agendamentos_relatorios.criado_por → perfis.id`
- `exportacoes_relatorios.agendamento_id → agendamentos_relatorios.id`
- `exportacoes_relatorios.criado_por → perfis.id`
- `preferencias_notificacoes.perfil_id → perfis.id`

---

## Notas de refatoração

- A tabela `lancamentos_financeiros` (antiga `financial_transactions`) foi substituída por `lancamentos_fluxo_caixa`, `contas_pagar` e `contas_receber`.
- A tabela `documentos` substitui o campo `document_url` de `contratos`, permitindo múltiplos anexos por contrato/proposta/tarefa.
- `membros_equipe` pode estar vinculada a `perfis` (quando o membro tem login) ou ser independente para colaboradores externos.
- `usuarios` é espelho do auth provider; dados de perfil e permissões ficam em `perfis`.
