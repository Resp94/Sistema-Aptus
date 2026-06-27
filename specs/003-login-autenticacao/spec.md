# Feature Specification: Login e Autenticação

**Feature Branch**: `003-login-autenticacao`

**Created**: 2026-06-27

**Status**: Draft

**Input**: User description: "vamos começar a implementação da primeira page e table, use o arquivo login.html para gerarmos a page - e vamos criar users tester com as personas em personas.md - gerar a table usuarios que esta em banco-de-dados.md - testar o login com todas as personas, aprovando o login"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Login com e-mail e senha (Priority: P1)

Um usuário cadastrado acessa a página de login, informa e-mail e senha válidos e entra no sistema, sendo direcionado para a tela inicial correspondente ao seu perfil de acesso.

**Why this priority**: É o fluxo principal de entrada no sistema. Sem ele, nenhuma outra funcionalidade pode ser acessada de forma segura.

**Independent Test**: Pode ser testado isoladamente acessando a página de login, digitando credenciais válidas de qualquer persona e verificando o redirecionamento.

**Acceptance Scenarios**:

1. **Given** que o usuário possui uma conta ativa com perfil vinculado, **When** ele informa e-mail e senha corretos e confirma o login, **Then** o sistema inicia a sessão autenticada e o redireciona para a tela inicial adequada ao seu perfil.
2. **Given** que o usuário informa credenciais inválidas, **When** ele tenta fazer login, **Then** o sistema exibe uma mensagem clara de erro e não libera o acesso.

---

### User Story 2 - Recuperação de senha (Priority: P2)

Um usuário que esqueceu a senha solicita, a partir da página de login, o envio de um link ou instrução de redefinição para o e-mail cadastrado.

**Why this priority**: Reduz dependência de suporte humano e garante que usuários legítimos possam recuperar o acesso de forma autônoma.

**Independent Test**: Pode ser testado isoladamente clicando em "Esqueci a senha", informando um e-mail válido e verificando se a solicitação é aceita.

**Acceptance Scenarios**:

1. **Given** que o usuário está na página de login, **When** ele solicita a recuperação de senha e informa um e-mail cadastrado, **Then** o sistema confirma o envio da instrução de redefinição.
2. **Given** que o usuário informa um e-mail não cadastrado na recuperação, **When** ele solicita o envio, **Then** o sistema responde de forma a não revelar a existência da conta, protegendo a privacidade.

---

### User Story 3 - Usuários de teste para cada persona (Priority: P3)

O sistema disponibiliza contas de teste pré-cadastradas para cada persona de negócio, permitindo validar o login e o direcionamento por perfil durante desenvolvimento e homologação.

**Why this priority**: Acelera os testes de aceitação e garante que cada perfil de acesso possa ser verificado antes da entrega.

**Independent Test**: Pode ser testado isoladamente executando o login com as credenciais de cada usuário de teste e confirmando que a autenticação é aprovada.

**Acceptance Scenarios**:

1. **Given** que as contas de teste foram criadas com base nas personas definidas, **When** cada persona realiza login com suas credenciais, **Then** o sistema autentica com sucesso e associa a sessão ao perfil técnico correspondente.
2. **Given** que uma persona de teste está inativa, **When** ela tenta fazer login, **Then** o sistema bloqueia o acesso e informa o motivo.

### Edge Cases

- O que acontece quando o usuário deixa campos obrigatórios em branco?
- Como o sistema lida com e-mail não confirmado ou conta inativa?
- Como é exibido o erro quando a senha está incorreta, mas o e-mail existe?
- O que ocorre se o link/token de redefinição de senha estiver expirado?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE apresentar uma página de login com campos de e-mail, senha, opção "lembrar de mim", botão de acesso e link para recuperação de senha, mantendo a identidade visual e o layout de referência.
- **FR-002**: O sistema DEVE validar as credenciais informadas e iniciar uma sessão autenticada quando forem corretas.
- **FR-003**: O sistema DEVE redirecionar o usuário, após login bem-sucedido, para a tela inicial apropriada ao seu perfil de acesso.
- **FR-004**: O sistema DEVE manter a tabela `usuarios` espelhando os dados do provedor de autenticação, conforme modelo de dados do projeto.
- **FR-005**: O sistema DEVE manter a tabela `perfis` vinculada aos usuários, armazenando nome, avatar, perfil de acesso, status e demais dados aplicacionais.
- **FR-006**: O sistema DEVE criar usuários de teste para todas as personas definidas (Administrador, Analista Financeiro, Gerente de Projetos, Consultor Comercial e Profissional Técnico), vinculando cada um ao perfil técnico correspondente.
- **FR-007**: O sistema DEVE permitir que o usuário solicite a recuperação de senha através do e-mail cadastrado.
- **FR-008**: O sistema DEVE exibir mensagens de erro claras e acessíveis para falhas de validação, credenciais incorretas ou contas inativas, sem expor detalhes internos de segurança.

### Key Entities *(include if feature involves data)*

- **Usuário**: Representa a conta de autenticação. Atributos principais: identificador único, e-mail, confirmação de e-mail, telefone, metadados, datas de criação/atualização e último login.
- **Perfil**: Representa os dados aplicacionais do usuário autenticado. Atributos principais: identificador, vínculo com usuário, nome, avatar, perfil de acesso (RBAC), status, departamento e datas de controle.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos usuários de teste das personas conseguem fazer login com sucesso na primeira tentativa.
- **SC-002**: O fluxo de login completo, do carregamento da página ao redirecionamento, é concluído em menos de 5 segundos em condições normais de rede.
- **SC-003**: 100% das tentativas de login com credenciais inválidas exibem uma mensagem de erro compreensível ao usuário.
- **SC-004**: A recuperação de senha pode ser solicitada diretamente na página de login e retorna confirmação visual em menos de 3 segundos.

## Assumptions

- O sistema utilizará o provedor de autenticação e o banco de dados já adotados no projeto.
- As senhas dos usuários de teste serão definidas durante o processo de criação dos dados de teste.
- O envio de e-mails de recuperação de senha depende de um serviço de e-mail configurado no ambiente.
- O arquivo `login.html` é a referência de design e comportamento para a nova página de login.
- Cada persona de negócio será mapeada para um único perfil técnico de acesso (Administrador, Financeiro, Operacional ou Visualizador).
