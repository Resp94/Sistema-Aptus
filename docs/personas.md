# Personas

> **Cinco personas operacionais.** O sistema tem exatamente cinco personas operacionais, cada uma espelhada por um perfil técnico de acesso: Administrador, Analista Financeiro (perfil `Financeiro`), Gerente de Projetos (perfil `Projetos`), Consultor Comercial (perfil `Comercial`) e Profissional Técnico (perfil `Técnico`). **Visualizador não é uma persona operacional.** É o perfil técnico mínimo atribuído automaticamente no signup (estado inicial), sem nenhuma capacidade nomeada de ação e com leitura restrita a Relatórios e às próprias Configurações, até que um Administrador promova o usuário a um dos cinco perfis operacionais. Ver detalhes na seção [Perfis técnicos de acesso (RBAC)](#perfis-técnicos-de-acesso-rbac) ao final deste documento.
>
> **Acesso ao Dashboard.** O Dashboard é tela de acesso oficial (leitura) apenas para Administrador e Financeiro. Projetos, Comercial, Técnico e Visualizador não têm Dashboard oficial.

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

**Telas:** Projetos, Equipe, Relatórios (operacionais). Sem Dashboard oficial: o Dashboard estratégico é acesso exclusivo de Administrador e Financeiro.

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

A tela **Configurações > Usuários** define os seguintes perfis técnicos de acesso ao sistema. Os cinco primeiros são perfis **operacionais** e cada um espelha diretamente uma persona de negócio, garantindo que as permissões reflitam o papel real do usuário. **Visualizador não é um perfil operacional**: é o estado técnico mínimo de signup (ver nota abaixo).

Desde a introdução do RBAC por capacidades nomeadas (feature `007-rbac-capacidades-nomeadas`), estas permissões gerais continuam valendo como leitura/rota/navegação (`obter_permissoes_usuario`/`permissao_modulo`), mas ações sensíveis (escrita e efeitos de negócio como emitir boleto, notificar, exportar, enviar proposta, gerar contrato) são autorizadas por capacidades nomeadas (`recurso.acao`) específicas de cada perfil — ver `docs/arquitetura-dados.md` e `specs/007-rbac-capacidades-nomeadas/contracts/capability-matrix.md` para a matriz completa.

| Perfil técnico | Persona | Permissões gerais |
|----------------|---------|-------------------|
| **Administrador** | Administrador | Acesso total a todos os módulos, usuários e configurações do sistema. Todas as capacidades nomeadas do catálogo. Dashboard oficial. |
| **Financeiro** | Analista Financeiro | Acesso ao módulo financeiro (Fluxo de Caixa, Contas a Pagar, Contas a Receber, Cobranças), Dashboard e relatórios financeiros. Dashboard oficial. |
| **Projetos** | Gerente de Projetos | Acesso a Projetos (Kanban, tarefas, progresso), Equipe (alocações, capacidade) e relatórios operacionais. **Sem Dashboard oficial** (não consta na matriz de capacidades/leitura oficial do perfil). |
| **Comercial** | Consultor Comercial | Acesso a Clientes, Propostas, Contratos, Cobranças (emissão e lembretes) e histórico de atendimento. Sem Dashboard oficial. |
| **Técnico** | Profissional Técnico | Acesso somente aos projetos em que está alocado, suas tarefas próprias no Kanban (capacidades `tarefas.editar_propria`/`tarefas.mover_propria`), apontamento próprio de horas, equipe (visualização limitada aos colegas dos mesmos projetos) e própria ficha em Configurações. Sem acesso a Dashboard, financeiro ou dados comerciais de terceiros. |
| **Visualizador** | — (não é persona operacional) | Perfil técnico mínimo de signup. Zero capacidades nomeadas de ação. Leitura restrita a Relatórios e às próprias Configurações. Não pode criar, editar, exportar nem disparar nenhum efeito de negócio. |

> **Nota sobre o Visualizador:** o perfil **Visualizador** não representa uma persona de negócio nem é um "modo restrito" atribuível a outras personas. É o valor padrão atribuído a toda conta recém-criada (signup), funcionando como estado anti-escalação até que um Administrador promova o usuário a um dos cinco perfis operacionais (Administrador, Financeiro, Projetos, Comercial ou Técnico). Enquanto estiver como Visualizador, o usuário tem zero capacidades nomeadas e leitura limitada a Relatórios e às suas próprias Configurações — nenhum outro módulo, dashboard ou dado de terceiros é acessível.
