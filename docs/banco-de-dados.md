# Banco de Dados

## users

Usuários do sistema interno com perfis e permissões de acesso.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| name | text | - |
| email | text | - |
| role | text | - |

## clients

Clientes cadastrados no sistema com informações de contato e dados comerciais.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| name | text | - |
| email | text | - |
| phone | text | - |
| document | text | - |
| address | text | - |

## financial_transactions

Lançamentos financeiros de receitas e despesas do fluxo de caixa.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| type | text | - |
| description | text | - |
| amount | number | - |
| date | timestamp | - |
| category | text | - |
| client_id | uuid fk | - |

## proposals

Propostas comerciais enviadas a clientes com status e valores.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| client_id | uuid fk | - |
| title | text | - |
| description | text | - |
| amount | number | - |
| status | text | - |
| sent_at | timestamp | - |

## contracts

Contratos firmados com clientes, com vigência e documentos anexados.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| client_id | uuid fk | - |
| proposal_id | uuid fk | - |
| start_date | timestamp | - |
| end_date | timestamp | - |
| status | text | - |
| document_url | text | - |

## invoices

Cobranças geradas a partir de contratos, com status de pagamento e emissão de boletos.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| contract_id | uuid fk | - |
| client_id | uuid fk | - |
| amount | number | - |
| due_date | timestamp | - |
| status | text | - |
| payment_date | timestamp | - |
| boleto_url | text | - |

## projects

Projetos gerenciados pela equipe, com prazos e responsáveis.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| client_id | uuid fk | - |
| name | text | - |
| description | text | - |
| start_date | timestamp | - |
| end_date | timestamp | - |
| status | text | - |

## tasks

Tarefas vinculadas a projetos, com status e responsável para acompanhamento no Kanban.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| project_id | uuid fk | - |
| title | text | - |
| description | text | - |
| status | text | - |
| assigned_to | uuid fk | - |
| due_date | timestamp | - |

## client_history

Registro de histórico de atendimentos e interações com clientes.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| client_id | uuid fk | - |
| user_id | uuid fk | - |
| action | text | - |
| description | text | - |
