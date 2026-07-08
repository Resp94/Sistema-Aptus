# Modelo de Dados: Autenticação e Perfis (RBAC)

## 1. Contexto e Motivação
Modelagem das tabelas do banco de dados relacional (PostgreSQL) para gerenciar o espelho dos dados do provedor de autenticação e implementar as permissões baseadas em perfis aplicacionais (RBAC) para as personas do ERP Aptus Flow.

## 2. Tabelas Criadas

### `usuarios`
Espelho dos dados fornecidos pelo Supabase Auth (GoTrue).
* `id` (uuid, PK): Vínculo direto com `auth.users.id`.
* `email` (text, único, NOT NULL): E-mail da conta (**PII**).
* `email_confirmed_at` (timestamp): Data de verificação de e-mail.
* `phone` (text, PII): Telefone da conta.
* `phone_confirmed_at` (timestamp): Confirmação do fone.
* `raw_user_meta_data` (jsonb, PII): Nome e dados públicos.
* `raw_app_meta_data` (jsonb): Metadados aplicacionais do Supabase.
* `aud` (text): Audience da sessão.
* `created_at` / `updated_at` (timestamp): Controle temporal.
* `last_sign_in_at` (timestamp): Registro do último login.

### `perfis`
Dados aplicacionais e de acessibilidade (RBAC) de cada usuário.
* `id` (uuid, PK): Identificador do perfil.
* `usuario_id` (uuid, UNIQUE, FK -> `usuarios.id`): Relacionamento 1:1 com a conta do usuário.
* `nome` (text, NOT NULL, PII): Nome exibido do usuário.
* `perfil_acesso` (text, NOT NULL): RBAC ('Administrador', 'Financeiro', 'Projetos', 'Comercial', 'Técnico', 'Visualizador').
* `status` (text, NOT NULL, default 'Ativo'): Controle de ativação ('Ativo', 'Inativo').
* `departamento` (text): Setor de alocação.
* `created_at` / `updated_at` (timestamp): Controle temporal.

### `audit_log`
Tabela imutável para logs de eventos de segurança.
* `id` (uuid, PK): Identificador único do log.
* `evento` (text, NOT NULL): 'login_sucesso', 'login_falha', 'senha_alterada', 'usuario_criado', 'conta_desativada', 'conta_ativada', 'projeto_excluido', 'tarefa_excluida', 'cliente_inativado'.
* `usuario_id` (uuid, FK -> `usuarios.id` ON DELETE SET NULL): Usuário gerador da ação.
* `ip_origem` (text, PII): IP do cliente.
* `user_agent` (text): Informações do navegador/cliente do usuário.
* `created_at` (timestamp): Data/hora da ação.

---

## 3. Módulos Adicionais (Landings por Persona)

Em 2026-06-28, o modelo de dados foi expandido com 6 tabelas para apoiar as landing pages funcionais.

### `clientes`
Contatos comerciais e parceiros de negócio.
* `id` (uuid, PK): Identificador.
* `nome_contato` (text, NOT NULL, PII): Pessoa de contato.
* `empresa` (text, NOT NULL): Razão social / nome fantasia.
* `email` (text, PII): E-mail do contato.
* `telefone` (text, PII): Telefone.
* `tipo` (text, NOT NULL): 'cliente' ou 'fornecedor'.
* `status` (text, NOT NULL, default 'Ativo'): 'Ativo' ou 'Inativo'.
* `created_by` (uuid, FK -> `usuarios.id`): Criador do registro.

### `atendimentos`
Histórico de interações comerciais de um cliente.
* `id` (uuid, PK)
* `cliente_id` (uuid, FK -> `clientes.id` ON DELETE CASCADE)
* `data` (date, NOT NULL, default current_date)
* `descricao` (text, NOT NULL)
* `responsavel_id` (uuid, FK -> `usuarios.id` ON DELETE SET NULL)

### `projetos`
Entidade operacional de projetos contratados.
* `id` (uuid, PK)
* `nome` (text, NOT NULL)
* `cliente_id` (uuid, FK -> `clientes.id` ON DELETE SET NULL)
* `status` (text, NOT NULL, default 'Planejamento'): 'Planejamento', 'Em andamento', 'Concluído'.
* `progresso` (integer, NOT NULL, default 0, CHECK 0-100)
* `orcamento` (numeric(14,2), default 0.00)
* `orcamento_utilizado` (numeric(14,2), default 0.00)
* `em_risco` (boolean, NOT NULL, default false)
* `prazo` (date)
* `created_by` (uuid, FK -> `usuarios.id`)

### `tarefas`
Quadro Kanban de tarefas dos projetos.
* `id` (uuid, PK)
* `projeto_id` (uuid, FK -> `projetos.id` ON DELETE CASCADE)
* `titulo` (text, NOT NULL)
* `situacao` (text, NOT NULL, default 'A Fazer'): 'A Fazer', 'Em Andamento', 'Concluído'.
* `prioridade` (text, NOT NULL, default 'Média'): 'Alta', 'Média', 'Baixa'.
* `responsavel_id` (uuid, FK -> `usuarios.id` ON DELETE SET NULL)
* `prazo` (date)
* `instrucoes` (text)
* `ordem` (integer, default 0)

### `alocacoes_projeto`
Relacionamento N:N definindo quais membros da equipe estão alocados a cada projeto (usado para escopo de acesso da persona Técnico).
* `id` (uuid, PK)
* `projeto_id` (uuid, FK -> `projetos.id` ON DELETE CASCADE)
* `usuario_id` (uuid, FK -> `usuarios.id` ON DELETE CASCADE)
* `papel` (text)
* *Restrição Única:* `(projeto_id, usuario_id)`.

### `lancamentos`
Movimentações financeiras que alimentam a agregação do Dashboard.
* `id` (uuid, PK)
* `tipo` (text, NOT NULL): 'receita' ou 'despesa'.
* `natureza` (text, NOT NULL): 'a_receber', 'a_pagar', 'realizado'.
* `descricao` (text, NOT NULL)
* `valor` (numeric(14,2), NOT NULL, CHECK > 0)
* `categoria` (text)
* `cliente_id` (uuid, FK -> `clientes.id` ON DELETE SET NULL)
* `data_competencia` (date, NOT NULL, default current_date)
* `data_vencimento` (date)
* `status` (text, NOT NULL, default 'Pendente'): 'Pendente' ou 'Pago' (o estado 'Vencido' é derivado dinamicamente).

### `configuracoes_empresa`
Registro singleton das configurações globais da empresa usado pela aba administrativa de Configurações.
* `id` (text, PK): valor único `config_unica`.
* `razao_social`, `documento`, `email`, `telefone`, `endereco` (text): dados cadastrais preenchidos no onboarding administrativo.
* `idioma` (text, NOT NULL, default `pt-BR`): idioma operacional inicial.
* `formato_data` (text, NOT NULL, default `dd/MM/yyyy`): padrão de exibição de datas.
* `moeda` (text, NOT NULL, default `BRL`): moeda operacional padrão.
* `inicio_ano_fiscal` (date): data opcional para fechamento fiscal.
* `dia_vencimento_padrao` (integer, NOT NULL, default `5`): dia sugerido para vencimentos.
* `percentual_multa_atraso` (numeric(5,2), NOT NULL, default `2.00`): multa padrão.
* `cobranca_automatica_ativa` (boolean, NOT NULL, default `false`): flag global de cobrança automática.

---

## 4. Triggers, Funções e Segurança

* `permissao_modulo(p_modulo)`: Função `SECURITY DEFINER` e `SET row_security = off` que atua como fonte única de RBAC, retornando `(pode_ler, pode_escrever)` para o `auth.uid()` corrente de acordo com as permissões do módulo.
* **RLS Policies**: Aplicado RLS nas 6 novas tabelas. A leitura é restrita a usuários authenticated com `pode_ler = true` no módulo correspondente; inserções, atualizações e exclusões exigem `pode_escrever = true` no módulo. Apenas `clientes` não permite exclusão física (soft delete via status 'Inativo').
* **Trilha de Auditoria**: O enum de `audit_log.evento` foi expandido para suportar `'projeto_excluido'`, `'tarefa_excluida'` e `'cliente_inativado'`. Cada RPC destrutiva chama `registrar_evento_auditoria` internamente.
* **Bootstrap de Configurações**: a RPC `public.obter_configuracoes_empresa()` agora garante a existência prévia da linha singleton `config_unica` antes do `SELECT`. Isso remove o acoplamento entre “primeira leitura” e “primeira escrita” no onboarding administrativo.
* **Cadastro Administrativo de Usuários**: a RPC `public.criar_usuario_configuracoes(payload jsonb)` cria contas diretamente em `auth.users` e `auth.identities`, sem fluxo de convite. O uso é restrito a sessão autenticada com a capacidade `configuracoes.gerenciar_usuarios` e validação explícita de perfil `Administrador`. Após a trigger de sincronização materializar `public.usuarios` e `public.perfis`, a própria RPC ajusta `nome`, `perfil_acesso`, `status` e `departamento` finais no perfil e registra auditoria de `usuario_criado`.
* **Avatar Descontinuado**: em 2026-07-08, a decisão de produto/arquitetura removeu `avatar_url` do contrato vivo de `public.perfis` e das configurações do usuário. Não haverá migração para Supabase Storage; a identificação visual do shell permanece restrita às iniciais do nome.

---

## 5. Data da Alteração
* 2026-06-28
* 2026-07-07
* 2026-07-08
