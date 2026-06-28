# Módulo Clientes e Fornecedores

## 1. Contexto e Objetivo
Módulo dedicado a gerenciar o relacionamento com clientes e fornecedores do ERP Aptus Flow. Fornece uma interface para cadastros, busca ativa, estatísticas do volume de contatos e receita acumulada, e histórico de interações (atendimentos).

## 2. Visão do Frontend (React)
* **Rota:** `/clientes`
* **Permissões:** Leitura exige `pode_ler` e escrita exige `pode_escrever` no módulo `clientes`. A persona `Comercial Persona` tem acesso total; a persona `Técnico Persona` é redirecionada por falta de privilégios.
* **Componentes Principais:**
  * **Abas (Pills):** Alterna o escopo de listagem entre Clientes e Fornecedores.
  * **Barra de Busca e Status:** Input de pesquisa por nome, empresa ou email integrado a filtro por status ('Ativo', 'Inativo').
  * **Stats Bar:** Quadro de indicadores rápidos carregado da RPC `obter_estatisticas_clientes`.
  * **Tabela de Contatos:** Lista registros ordenados por receita acumulada decrescente. Clicar em uma linha exibe o painel de detalhes abaixo.
  * **Painel de Detalhes:** Painel deslizante exibindo informações do contato e sua timeline de atendimentos. Possui ações exclusivas de escrita.
  * **Modal Novo Contato:** Formulário para inserção de novos contatos.
  * **Modal Registrar Atendimento:** Permite registrar um histórico de interação no cliente selecionado.

## 3. Fluxo de Dados (RPCs)
* **Leitura:**
  * `listar_clientes(p_tipo, p_busca, p_status)`: Retorna os registros correspondentes contendo os dados de contato e a receita acumulada.
  * `obter_estatisticas_clientes()`: Retorna os consolidados de contatos, ativos, fornecedores e receita.
  * `obter_cliente_detalhe(p_cliente_id)`: Retorna o objeto completo do contato e o array JSON do histórico de interações.
* **Escrita (CRUD):**
  * `criar_cliente(...)`: Insere o registro ativo com ID do criador.
  * `atualizar_cliente(...)`: Atualiza os dados cadastrais.
  * `inativar_cliente(id)`: Executa exclusão lógica (soft delete) alterando o status para 'Inativo'. Audita o evento `cliente_inativado`.
  * `registrar_atendimento(...)`: Cadastra uma nova linha na timeline de histórico.

## 4. Auditoria e Segurança
* **RLS:** Ativado na tabela `clientes` e `atendimentos`, validando o gate de leitura/escrita via helper `permissao_modulo('clientes')`.
* **Exclusão:** Soft delete obrigatório para não violar a integridade relacional de lançamentos financeiros vinculados ao cliente.
