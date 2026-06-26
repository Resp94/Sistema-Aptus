# Telas

Este documento descreve as telas ativas do Aptus Flow. Telas legadas (`index.html` e `financeiro.html`) não são documentadas aqui.

## Componentes recorrentes

A maioria das telas compartilha a estrutura base:

- **Sidebar fixa** com navegação agrupada em "Principal" e "Gestão"
- **Header superior** com título da tela, busca global e ações rápidas
- **Cards de métricas** exibindo indicadores principais
- **Tabelas `ds-table`** com ordenação, busca e ações por linha
- **Modais** para criação, edição e confirmação de ações
- **Gráficos** de barras, linha e pizza
- **Badges de status** padronizados por módulo
- **Botões de exportação** (CSV/PDF)
- **Filtros** por período, status e categoria

---

## Login

**Rota:** `/login`

**Objetivo:** Autenticar usuário com email e senha.
**Acesso:** Pública

**Componentes:**

- **Input Email**
- **Input Senha**
- **Checkbox Lembrar de mim**
- **Botão Entrar**: Autentica o usuário e redireciona para `/dashboard`
- **Link Esqueci Senha**: Abre modal de recuperação de senha

---

## Dashboard

**Rota:** `/dashboard`

**Objetivo:** Exibir visão geral da empresa com indicadores financeiros e de projetos.
**Acesso:** Administrador, Analista Financeiro, Gerente de Projetos

**Componentes:**

- **Cards de métricas clicáveis**: Saldo em conta, Contas a receber, Contas a pagar, Clientes ativos
- **Gráfico Fluxo de Caixa** (barras: receitas × despesas)
- **Lista Últimos Lançamentos**
- **Lista Contas a pagar: próximos 7 dias**
- **Card Composição de receita** (gráfico de pizza)
- **Card Notificações** com modal de alertas

**Ações principais:**

- Navegar para Fluxo de Caixa, Contas a Pagar, Contas a Receber ou Clientes a partir dos cards

---

## Fluxo de Caixa

**Rota:** `/fluxo-caixa`

**Objetivo:** Controlar movimentações financeiras de entradas, saídas e projeções.
**Acesso:** Administrador, Analista Financeiro

**Componentes:**

- **Cards de métricas**: Saldo Inicial, Entradas, Saídas, Saldo Final Projetado
- **Gráfico dual** receitas × despesas
- **Card Previsão: próximos 30 dias**
- **Tabela Movimentações** com busca
- **Modal Novo Lançamento**

**Ações principais:**

- Adicionar receita/despesa
- Filtrar por período e categoria
- Exportar dados

---

## Contas a Pagar

**Rota:** `/contas-pagar`

**Objetivo:** Gerenciar obrigações, vencimentos e fornecedores.
**Acesso:** Administrador, Analista Financeiro

**Componentes:**

- **Cards de métricas**: Contas pendentes, Vencidas, Vencem hoje, Próximos 7 dias
- **Lista Próximos vencimentos**
- **Lista Por categoria**
- **Tabela Todas as contas**
- **Modais**: Nova conta a pagar, Confirmar pagamento

**Status:** Pendente, Pago, Vencido

**Ações principais:**

- Cadastrar nova conta a pagar
- Registrar pagamento
- Filtrar por status e fornecedor

---

## Contas a Receber

**Rota:** `/contas-receber`

**Objetivo:** Controlar faturas emitidas, recebimentos e cobranças.
**Acesso:** Administrador, Analista Financeiro

**Componentes:**

- **Cards de métricas**: Contas a receber, Vencidas, Vencem hoje, Próximos 7 dias
- **Lista Próximos recebimentos**
- **Lista Receita por Cliente**
- **Tabela Todas as contas a receber**
- **Modais**: Nova fatura, Enviar cobrança

**Status:** Pendente, Pago, Vencido, Hoje

**Ações principais:**

- Cadastrar nova fatura
- Enviar cobrança por email
- Registrar recebimento

---

## Clientes e Fornecedores

**Rota:** `/clientes`

**Objetivo:** Cadastrar e consultar clientes e fornecedores com histórico.
**Acesso:** Administrador, Consultor Comercial

**Componentes:**

- **Abas Clientes / Fornecedores**
- **Barra de busca** + filtro de status
- **Stats bar**: contatos, receita acumulada, ativos, fornecedores
- **Tabela de contatos**
- **Painel de detalhes** (avatar, contato, receita, histórico de atendimento)
- **Modal Novo contato**

**Ações principais:**

- Cadastrar/editar cliente ou fornecedor
- Visualizar histórico de atendimentos
- Registrar nova interação

---

## Propostas

**Rota:** `/propostas`

**Objetivo:** Criar e gerenciar propostas comerciais.
**Acesso:** Administrador, Consultor Comercial

**Componentes:**

- **Cards de métricas**: Propostas este mês, Taxa de aprovação, Pipeline total
- **Tabela Propostas**
- **Painel de detalhes**
- **Modal Criar proposta**

**Status:** Rascunho, Enviado, Em análise, Aprovado, Rejeitado

**Ações principais:**

- Criar proposta
- Visualizar detalhes
- Enviar proposta por email
- Atualizar status

---

## Contratos

**Rota:** `/contratos`

**Objetivo:** Gerenciar contratos firmados com clientes.
**Acesso:** Administrador, Consultor Comercial

**Componentes:**

- **Cards de métricas**: Contratos vigentes, Vencimento próximo, Receita recorrente mensal, Encerrados
- **Tabela Contratos**
- **Painel de detalhes**
- **Modal Criar contrato**

**Status:** Vigente, Vencimento próximo, Encerrado

**Ações principais:**

- Criar contrato
- Renovar contrato
- Anexar documentos
- Acompanhar vigência

---

## Cobranças

**Rota:** `/cobrancas`

**Objetivo:** Controlar e gerenciar cobranças e recebimentos.
**Acesso:** Administrador, Analista Financeiro, Consultor Comercial

**Componentes:**

- **Cards de métricas**: Recebido este mês, Próximos 7 dias, Contas vencidas, Inadimplência
- **Filtro Status**
- **Tabela Cobranças**
- **Painel de detalhes da fatura**
- **Modal Registrar pagamento**

**Status:** Pago, Pendente, Vencido

**Ações principais:**

- Registrar pagamento
- Emitir boleto
- Enviar lembrete ao cliente

---

## Projetos

**Rota:** `/projetos`

**Objetivo:** Gerenciar projetos, tarefas e prazos da equipe.
**Acesso:** Administrador, Gerente de Projetos, Profissional Técnico (apenas projetos alocados)

**Componentes:**

- **Cards de métricas**: Projetos ativos, Tarefas abertas, Orçamento total, Em risco
- **Progresso dos projetos**
- **Distribuição por cliente** (gráfico de pizza)
- **Kanban Tarefas** com colunas A Fazer, Em Andamento, Concluído
- **Cards de tarefa arrastáveis**
- **Modais**: Novo projeto, Adicionar tarefa

**Ações principais:**

- Criar projeto
- Adicionar/organizar tarefas no Kanban
- Atribuir responsáveis
- Acompanhar progresso

---

## Equipe

**Rota:** `/equipe`

**Objetivo:** Acompanhar membros da equipe, alocações, capacidade e disponibilidade.
**Acesso:** Administrador, Gerente de Projetos, Profissional Técnico (visualização limitada)

**Componentes:**

- **Cards de métricas**: Total de membros, Projetos ativos, Em projeto ativo, Ausentes
- **Tabela de equipe** (avatar, função, status, situação, projeto atual)
- **Alocação por projeto**
- **Visão de capacidade**
- **Modais**: Novo membro, Editar membro, Alocar membro

**Status dos membros:** Disponível, Alocado, Férias, Ausente

**Ações principais:**

- Cadastrar membro
- Alocar em projeto
- Atualizar status e disponibilidade

---

## Relatórios

**Rota:** `/relatorios`

**Objetivo:** Gerar e exportar relatórios financeiros e operacionais.
**Acesso:** Administrador, Analista Financeiro, Gerente de Projetos

**Componentes:**

- **Filtros** de período e categoria
- **Botões Exportar PDF / Exportar CSV**
- **Cards de relatórios**: Financeiro, DRE, Análise de clientes, Fluxo de caixa detalhado, Contas a pagar/receber, Personalizado
- **Gráfico receitas × despesas**
- **Lista Exportações recentes**
- **Modal Agendar relatório**

**Ações principais:**

- Gerar relatório
- Exportar em PDF/CSV
- Agendar relatório periódico

---

## Configurações

**Rota:** `/configuracoes`

**Objetivo:** Configurar preferências do sistema, usuários e integrações.
**Acesso:** Administrador (geral), Profissional Técnico (apenas dados próprios)

**Componentes (abas verticais):**

- **Geral**: dados da empresa, idioma, formato de data, moeda
- **Financeiro**: dia de fechamento, ano fiscal, vencimento padrão, multa, cobrança automática
- **Notificações**: lembretes, alertas por email, notificações no sistema, relatório semanal
- **Usuários**: tabela com perfis (Administrador, Financeiro, Operacional, Visualizador) e status Ativo/Inativo
- **Integrações**: API pública, webhook, exportação automática
- **Aparência**: tema claro/escuro

**Modais**: Convidar usuário, Editar usuário

**Ações principais:**

- Configurar dados da empresa
- Gerenciar usuários e permissões
- Ajustar notificações e tema
