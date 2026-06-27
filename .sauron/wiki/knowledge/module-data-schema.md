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
* `avatar_url` (text): Link do avatar do perfil.
* `perfil_acesso` (text, NOT NULL): RBAC ('Administrador', 'Financeiro', 'Projetos', 'Comercial', 'Técnico', 'Visualizador').
* `status` (text, NOT NULL, default 'Ativo'): Controle de ativação ('Ativo', 'Inativo').
* `departamento` (text): Setor de alocação.
* `created_at` / `updated_at` (timestamp): Controle temporal.

### `audit_log`
Tabela imutável para logs de eventos de segurança.
* `id` (uuid, PK): Identificador único do log.
* `evento` (text, NOT NULL): 'login_sucesso', 'login_falha', 'senha_alterada', 'usuario_criado', 'conta_desativada', 'conta_ativada'.
* `usuario_id` (uuid, FK -> `usuarios.id` ON DELETE SET NULL): Usuário gerador da ação.
* `ip_origem` (text, PII): IP do cliente.
* `user_agent` (text): Informações do navegador/cliente do usuário.
* `created_at` (timestamp): Data/hora da ação.

## 3. Triggers e Funções Auxiliares
* `handle_auth_user_sync()`: Executado pós-INSERT/UPDATE em `auth.users` para manter a tabela `usuarios` e criar a linha de `perfis` correspondente com valores padrão.
* `validar_perfil_update()`: Trigger executado BEFORE UPDATE em `perfis` para bloquear a alteração de `perfil_acesso` e `status` por usuários não administradores.
* `existe_perfil_admin(uid)`: Função utilizada pelas políticas RLS para verificar se o usuário solicitante é um administrador ativo (`SET row_security = off` ativa).

## 4. Data da Alteração
* 2026-06-27
