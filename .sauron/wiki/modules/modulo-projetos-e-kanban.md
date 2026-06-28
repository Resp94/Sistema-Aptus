# Módulo Projetos e Kanban

## 1. Contexto e Objetivo
Gerenciamento operacional dos projetos da empresa e acompanhamento de tarefas das equipes de desenvolvimento e infraestrutura através de um quadro visual Kanban.

## 2. Visão do Frontend (React)
* **Rota:** `/projetos`
* **Permissões:** Acesso concedido a `Administrador`, `Projetos` e `Técnico`. A escrita (criar/excluir projetos e tarefas) é restrita a usuários com `pode_escrever('projetos')`.
* **Componentes Principais:**
  * **Cards de Métricas:** Ativos, tarefas abertas, orçamento total e projetos em risco (RPC `obter_resumo_projetos`).
  * **Lista de Progresso:** Exibe a barra de progresso individual de cada projeto ativo. Projetos em risco recebem destaque em cor vermelha.
  * **Gráfico de Pizza:** Distribuição de projetos ativos por cliente, desenhado programaticamente por gradiente cônico em CSS.
  * **Quadro Kanban:** Três colunas de situação ('A Fazer', 'Em Andamento', 'Concluído'). Suporta arrastar e soltar (HTML5 Drag and Drop) com persistência automática no banco.
  * **Modal Novo Projeto:** Formulário para cadastro.
  * **Modal Nova Tarefa:** Cria tarefas associadas a projetos com prioridade e responsável.
  * **Modal de Instruções:** Edição e leitura de diretivas da tarefa.

## 3. Fluxo de Dados (RPCs)
* **Leitura:**
  * `listar_projetos()`: Retorna os projetos operacionais. Se o perfil logado for `Técnico`, restringe aos projetos em que ele está alocado.
  * `obter_resumo_projetos()`: Consolida os cards de métricas no escopo do perfil.
  * `obter_distribuicao_clientes()`: Retorna a participação percentual de projetos por cliente.
  * `listar_tarefas_kanban()`: Retorna a lista ordenada de tarefas dos projetos visíveis.
* **Escrita (CRUD):**
  * `criar_projeto(...)`: Cadastra o projeto com progresso 0.
  * `atualizar_projeto(...)`: Atualiza os dados de cronograma e orçamento.
  * `excluir_projeto(id)`: Remove fisicamente (hard delete) o projeto, disparando cascade em tarefas e alocações. Audita o evento `projeto_excluido`.
  * `criar_tarefa(...)` / `atualizar_tarefa(...)`: Gerenciamento de tarefas.
  * `mover_tarefa(id, situacao)`: Altera a coluna da tarefa no Kanban, persistindo no banco.
  * `excluir_tarefa(id)`: Remove a tarefa e registra auditoria de `tarefa_excluida`.

## 4. Segurança por Alocação
* A persona `Técnico` possui restrição de escopo de dados: ela só enxerga projetos em que possui vínculo cadastrado na tabela `alocacoes_projeto`. O filtro é aplicado na camada de dados (RPCs de leitura), impedindo vazamento de dados de outros projetos.
