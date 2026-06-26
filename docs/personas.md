# Personas

## Administrador

Perfil com acesso total ao sistema. Responsável pela gestão de usuários, permissões e visão estratégica da empresa. Pode visualizar todos os módulos e realizar alterações críticas.

**User Stories:**

- Como Administrador, eu quero Criar e gerenciar novos usuários no sistema para controlar acessos e permissões
- Como Administrador, eu quero Visualizar o dashboard completo com indicadores financeiros e de projetos para tomar decisões estratégicas
- Como Administrador, eu quero Exportar relatórios financeiros e operacionais para auditoria e análise externa
- Como Administrador, eu quero Acessar e modificar todos os módulos (financeiro, clientes, propostas, contratos, cobranças, projetos, equipe, relatórios, configurações) para garantir a integridade dos dados

**Telas:** Todas as telas ativas, incluindo Configurações (gestão de usuários e permissões)

---

## Analista Financeiro

Responsável pelo controle financeiro da empresa, incluindo lançamentos de receitas e despesas, contas a pagar/receber, emissão de boletos, registro de pagamentos e análise de fluxo de caixa.

**User Stories:**

- Como Analista Financeiro, eu quero Adicionar receitas e despesas no fluxo de caixa para manter as movimentações atualizadas
- Como Analista Financeiro, eu quero Gerenciar contas a pagar e a receber para controlar obrigações e recebíveis
- Como Analista Financeiro, eu quero Emitir boletos e registrar pagamentos para controle de cobranças
- Como Analista Financeiro, eu quero Visualizar gráficos comparativos de períodos para analisar a evolução financeira
- Como Analista Financeiro, eu quero Exportar dados financeiros para CSV/PDF para prestação de contas

**Telas:** Dashboard, Fluxo de Caixa, Contas a Pagar, Contas a Receber, Cobranças, Relatórios (financeiros)

---

## Gerente de Projetos

Responsável por gerenciar projetos e tarefas da equipe, acompanhar prazos e progresso, e alocar recursos. Utiliza o Kanban e gráficos de progresso.

**User Stories:**

- Como Gerente de Projetos, eu quero Criar novos projetos e tarefas para organizar o trabalho da equipe
- Como Gerente de Projetos, eu quero Visualizar o Kanban de tarefas para acompanhar o status de cada atividade
- Como Gerente de Projetos, eu quero Acompanhar o gráfico de progresso dos projetos para garantir o cumprimento dos prazos
- Como Gerente de Projetos, eu quero Adicionar tarefas e atribuir responsáveis para distribuir a carga de trabalho
- Como Gerente de Projetos, eu quero Visualizar a alocação da equipe para planejar capacidade e disponibilidade

**Telas:** Dashboard, Projetos, Equipe, Relatórios (operacionais)

---

## Consultor Comercial

Responsável pelo relacionamento com clientes, criação de propostas e contratos, e gestão de cobranças amigáveis. Utiliza os módulos de clientes, propostas, contratos e cobranças.

**User Stories:**

- Como Consultor Comercial, eu quero Cadastrar novos clientes e visualizar histórico de atendimento para personalizar o serviço
- Como Consultor Comercial, eu quero Criar e enviar propostas comerciais para clientes para fechar negócios
- Como Consultor Comercial, eu quero Gerenciar contratos e anexar documentos para formalizar acordos
- Como Consultor Comercial, eu quero Enviar lembretes de cobrança para clientes inadimplentes para regularizar pagamentos

**Telas:** Clientes e Fornecedores, Propostas, Contratos, Cobranças

---

## Profissional Técnico

Especialista responsável pela execução técnica dos projetos, como desenvolvedores fullstack, front-end e profissionais de automação. Visualiza apenas os projetos em que está alocado, gerencia suas próprias tarefas no Kanban, acompanha a equipe e mantém seus dados pessoais atualizados. Não possui acesso ao Dashboard estratégico nem a dados financeiros ou comerciais de outros clientes.

**User Stories:**

- Como Profissional Técnico, eu quero Visualizar os projetos em que estou alocado para acompanhar minhas entregas
- Como Profissional Técnico, eu quero Ver minhas tarefas no Kanban para organizar minha rotina de trabalho
- Como Profissional Técnico, eu quero Atualizar o status das minhas tarefas para refletir o progresso real
- Como Profissional Técnico, eu quero Registrar o tempo ou esforço dedicado às tarefas para controle de produtividade
- Como Profissional Técnico, eu quero Consultar a equipe e as alocações para saber quem trabalha em cada projeto
- Como Profissional Técnico, eu quero Atualizar minhas informações de perfil e disponibilidade para manter meus dados corretos

**Telas:** Projetos, Equipe (visualização limitada), Configurações (apenas dados próprios)

---

## Perfis técnicos de acesso (RBAC)

A tela **Configurações > Usuários** define os seguintes perfis técnicos de acesso ao sistema. Eles representam o controle de permissões subjacente e podem ser mapeados às personas de negócio conforme necessário.

| Perfil técnico | Permissões gerais |
|----------------|-------------------|
| **Administrador** | Acesso total a todos os módulos, usuários e configurações. Equivalente à persona Administrador. |
| **Financeiro** | Acesso ao módulo financeiro (Fluxo de Caixa, Contas a Pagar, Contas a Receber, Cobranças) e relatórios financeiros. Equivalente à persona Analista Financeiro. |
| **Operacional** | Acesso a Projetos, Equipe e tarefas. Pode ser atribuído às personas Gerente de Projetos e Profissional Técnico, com escopo diferenciado. |
| **Visualizador** | Acesso somente leitura a dashboards e relatórios, sem permissão para criar ou editar registros. |

> **Nota:** Os perfis técnicos são o modelo de permissões planejado no sistema. As personas de negócio representam os papéis do dia a dia e podem utilizar um ou mais perfis técnicos.
