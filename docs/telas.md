# Telas

## Autenticação

**Rota:** `/`

**Objetivo:** Autenticar usuário com email e senha.

**Componentes:**

- **Input Email**
- **Input Senha**
- **Botão Entrar**: Autentica o usuário e redireciona para /dashboard
- **Link Esqueci Senha**: Abre modal de recuperação de senha

## Dashboard

**Rota:** `/dashboard`

**Objetivo:** Exibir visão geral da empresa com indicadores financeiros e de projetos.

**Componentes:**

- **Card Saldo Atual**
- **Gráfico Fluxo de Caixa**
- **Tabela Últimos Lançamentos**
- **Card Projetos em Andamento**
- **Botão Novo Lançamento**: Navega para a tela de lançamento financeiro

## Financeiro

**Rota:** `/financeiro`

**Objetivo:** Gerenciar entradas e saídas financeiras, fluxo de caixa e extratos.

**Componentes:**

- **Filtro Período**
- **Tabela Lançamentos**
- **Botão Adicionar Receita**: Abre formulário de nova receita
- **Botão Adicionar Despesa**: Abre formulário de nova despesa
- **Gráfico Comparativo**
- **Botão Exportar**: Exporta dados para CSV

## Clientes

**Rota:** `/clientes`

**Objetivo:** Cadastrar e consultar clientes com histórico de atendimento.

**Componentes:**

- **Input Busca Cliente**
- **Tabela Clientes**
- **Botão Novo Cliente**: Abre formulário de cadastro de cliente
- **Botão Editar**: Abre formulário de edição do cliente selecionado
- **Área Histórico**: Exibe detalhes do cliente e atendimentos

## Propostas

**Rota:** `/propostas`

**Objetivo:** Criar e gerenciar propostas comerciais.

**Componentes:**

- **Tabela Propostas**
- **Botão Nova Proposta**: Abre formulário de criação de proposta
- **Botão Visualizar**: Abre detalhes da proposta
- **Botão Enviar**: Envia proposta por email ao cliente
- **Status Proposta**

## Contratos

**Rota:** `/contratos`

**Objetivo:** Gerenciar contratos firmados com clientes.

**Componentes:**

- **Tabela Contratos**
- **Botão Novo Contrato**: Abre formulário de criação de contrato
- **Botão Renovar**: Renova contrato selecionado
- **Status Vigência**
- **Botão Anexar Documento**: Abre seletor de arquivos

## Cobranças

**Rota:** `/cobrancas`

**Objetivo:** Controlar e gerenciar cobranças e recebimentos.

**Componentes:**

- **Tabela Cobranças**
- **Filtro Status**
- **Botão Registrar Pagamento**: Abre formulário de registro de pagamento
- **Botão Emitir Boleto**: Gera boleto para cobrança
- **Botão Enviar Lembrete**: Envia notificação ao cliente

## Projetos

**Rota:** `/projetos`

**Objetivo:** Gerenciar projetos, tarefas e prazos da equipe.

**Componentes:**

- **Tabela Projetos**
- **Botão Novo Projeto**: Abre formulário de criação de projeto
- **Kanban Tarefas**
- **Botão Adicionar Tarefa**: Abre formulário de nova tarefa
- **Gráfico Progresso**
