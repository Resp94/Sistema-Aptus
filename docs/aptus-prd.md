# Aptus

## Objetivo

Sistema interno para gestão administrativa e financeira da empresa de automação e desenvolvimento com IA, integrando controle de fluxo de caixa, clientes, propostas, contratos, cobranças, projetos e tarefas.

## Telas

### Autenticação

**Rota:** `/`

**Objetivo:** Autenticar usuário com email e senha.

**Componentes:**

- **Input Email**
- **Input Senha**
- **Botão Entrar**: Autentica o usuário e redireciona para /dashboard
- **Link Esqueci Senha**: Abre modal de recuperação de senha

### Dashboard

**Rota:** `/dashboard`

**Objetivo:** Exibir visão geral da empresa com indicadores financeiros e de projetos.

**Componentes:**

- **Card Saldo Atual**
- **Gráfico Fluxo de Caixa**
- **Tabela Últimos Lançamentos**
- **Card Projetos em Andamento**
- **Botão Novo Lançamento**: Navega para a tela de lançamento financeiro

### Financeiro

**Rota:** `/financeiro`

**Objetivo:** Gerenciar entradas e saídas financeiras, fluxo de caixa e extratos.

**Componentes:**

- **Filtro Período**
- **Tabela Lançamentos**
- **Botão Adicionar Receita**: Abre formulário de nova receita
- **Botão Adicionar Despesa**: Abre formulário de nova despesa
- **Gráfico Comparativo**
- **Botão Exportar**: Exporta dados para CSV

### Clientes

**Rota:** `/clientes`

**Objetivo:** Cadastrar e consultar clientes com histórico de atendimento.

**Componentes:**

- **Input Busca Cliente**
- **Tabela Clientes**
- **Botão Novo Cliente**: Abre formulário de cadastro de cliente
- **Botão Editar**: Abre formulário de edição do cliente selecionado
- **Área Histórico**: Exibe detalhes do cliente e atendimentos

### Propostas

**Rota:** `/propostas`

**Objetivo:** Criar e gerenciar propostas comerciais.

**Componentes:**

- **Tabela Propostas**
- **Botão Nova Proposta**: Abre formulário de criação de proposta
- **Botão Visualizar**: Abre detalhes da proposta
- **Botão Enviar**: Envia proposta por email ao cliente
- **Status Proposta**

### Contratos

**Rota:** `/contratos`

**Objetivo:** Gerenciar contratos firmados com clientes.

**Componentes:**

- **Tabela Contratos**
- **Botão Novo Contrato**: Abre formulário de criação de contrato
- **Botão Renovar**: Renova contrato selecionado
- **Status Vigência**
- **Botão Anexar Documento**: Abre seletor de arquivos

### Cobranças

**Rota:** `/cobrancas`

**Objetivo:** Controlar e gerenciar cobranças e recebimentos.

**Componentes:**

- **Tabela Cobranças**
- **Filtro Status**
- **Botão Registrar Pagamento**: Abre formulário de registro de pagamento
- **Botão Emitir Boleto**: Gera boleto para cobrança
- **Botão Enviar Lembrete**: Envia notificação ao cliente

### Projetos

**Rota:** `/projetos`

**Objetivo:** Gerenciar projetos, tarefas e prazos da equipe.

**Componentes:**

- **Tabela Projetos**
- **Botão Novo Projeto**: Abre formulário de criação de projeto
- **Kanban Tarefas**
- **Botão Adicionar Tarefa**: Abre formulário de nova tarefa
- **Gráfico Progresso**

## Personas

### Administrador

Perfil com acesso total ao sistema. Responsável pela gestão de usuários, permissões e visão estratégica da empresa. Pode visualizar todos os módulos e realizar alterações críticas.

**User Stories:**

- Como Administrador, eu quero Criar e gerenciar novos usuários no sistema para controlar acessos e permissões
- Como Administrador, eu quero Visualizar o dashboard completo com indicadores financeiros e de projetos para tomar decisões estratégicas
- Como Administrador, eu quero Exportar relatórios financeiros em CSV para auditoria e análise externa
- Como Administrador, eu quero Acessar e modificar todos os módulos (financeiro, clientes, propostas, contratos, cobranças, projetos) para garantir a integridade dos dados

### Analista Financeiro

Responsável pelo controle financeiro da empresa, incluindo lançamentos de receitas e despesas, emissão de boletos, registro de pagamentos e análise de fluxo de caixa.

**User Stories:**

- Como Analista Financeiro, eu quero Adicionar receitas e despesas no sistema para manter o fluxo de caixa atualizado
- Como Analista Financeiro, eu quero Emitir boletos e registrar pagamentos para controle de cobranças
- Como Analista Financeiro, eu quero Visualizar gráficos comparativos de períodos para analisar a evolução financeira
- Como Analista Financeiro, eu quero Exportar dados financeiros para CSV para prestação de contas

### Gerente de Projetos

Responsável por gerenciar projetos e tarefas da equipe, acompanhar prazos e progresso, e alocar recursos. Utiliza o Kanban e gráficos de progresso.

**User Stories:**

- Como Gerente de Projetos, eu quero Criar novos projetos e tarefas para organizar o trabalho da equipe
- Como Gerente de Projetos, eu quero Visualizar o Kanban de tarefas para acompanhar o status de cada atividade
- Como Gerente de Projetos, eu quero Acompanhar o gráfico de progresso dos projetos para garantir o cumprimento dos prazos
- Como Gerente de Projetos, eu quero Adicionar tarefas e atribuir responsáveis para distribuir a carga de trabalho

### Consultor Comercial

Responsável pelo relacionamento com clientes, criação de propostas e contratos, e gestão de cobranças amigáveis. Utiliza os módulos de clientes, propostas, contratos e cobranças.

**User Stories:**

- Como Consultor Comercial, eu quero Cadastrar novos clientes e visualizar histórico de atendimento para personalizar o serviço
- Como Consultor Comercial, eu quero Criar e enviar propostas comerciais para clientes para fechar negócios
- Como Consultor Comercial, eu quero Gerenciar contratos e anexar documentos para formalizar acordos
- Como Consultor Comercial, eu quero Enviar lembretes de cobrança para clientes inadimplentes para regularizar pagamentos

## Banco de Dados

### users

Usuários do sistema interno com perfis e permissões de acesso.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| name | text | - |
| email | text | - |
| role | text | - |

### clients

Clientes cadastrados no sistema com informações de contato e dados comerciais.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| name | text | - |
| email | text | - |
| phone | text | - |
| document | text | - |
| address | text | - |

### financial_transactions

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

### proposals

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

### contracts

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

### invoices

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

### projects

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

### tasks

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

### client_history

Registro de histórico de atendimentos e interações com clientes.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | uuid pk | - |
| client_id | uuid fk | - |
| user_id | uuid fk | - |
| action | text | - |
| description | text | - |

