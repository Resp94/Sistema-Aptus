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

- **Campos obrigatórios em branco**: O frontend bloqueia o submit e exibe erro inline em cada campo vazio.
- **E-mail não confirmado**: O GoTrue rejeita o login com erro específico; o frontend exibe "Confirme seu e-mail antes de fazer login. Verifique sua caixa de entrada."
- **Conta inativa**: Login bloqueado com mensagem "Conta desativada. Entre em contato com o administrador."
- **Senha incorreta vs e-mail inexistente**: A mesma mensagem genérica é exibida para ambos os casos: "E-mail ou senha inválidos."
- **Link/token de redefinição expirado**: O GoTrue rejeita com erro; o frontend redireciona para a tela de login com "Link expirado. Solicite uma nova redefinição de senha."
- **Supabase Auth indisponível**: O frontend exibe toast "Serviço de autenticação temporariamente indisponível. Tente novamente em instantes." e mantém o formulário habilitado para retry.
- **Usuário autenticado sem perfil (RPC retorna null)**: O frontend redireciona para uma tela de erro com "Perfil não encontrado. Entre em contato com o administrador." e força logout.
- **E-mail de redefinição não entregue (bounce/falha SMTP)**: O GoTrue registra a falha; o sistema não notifica o usuário proativamente, mas o link de redefinição simplesmente não chega — o usuário pode solicitar novo envio.
- **Logins concorrentes**: Permitidos. Cada dispositivo/sessão recebe seu próprio refresh token. Não há invalidação cruzada entre dispositivos.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE apresentar uma página de login com campos de e-mail, senha, opção "lembrar de mim", botão de acesso e link para recuperação de senha, mantendo a identidade visual e o layout de referência.
- **FR-002**: O sistema DEVE validar as credenciais informadas e iniciar uma sessão autenticada quando forem corretas.
- **FR-003**: O sistema DEVE redirecionar o usuário, após login bem-sucedido, para a tela inicial apropriada ao seu perfil de acesso.
- **FR-004**: O sistema DEVE manter a tabela `usuarios` espelhando os dados do provedor de autenticação, conforme modelo de dados do projeto.
- **FR-005**: O sistema DEVE manter a tabela `perfis` vinculada aos usuários, armazenando nome, avatar, perfil de acesso, status e demais dados aplicacionais.
- **FR-006**: O sistema DEVE criar usuários de teste para todas as personas definidas (Administrador, Analista Financeiro, Gerente de Projetos, Consultor Comercial e Profissional Técnico), vinculando cada um ao perfil técnico correspondente.
- **FR-007**: O sistema DEVE permitir que o usuário solicite a recuperação de senha através do e-mail cadastrado.
- **FR-008**: O sistema DEVE exibir mensagens de erro para falhas de validação, credenciais incorretas ou contas inativas, sem revelar se o e-mail existe ou não (resposta genérica: "E-mail ou senha inválidos"), em consistência com a política de privacidade do fluxo de recuperação de senha.
- **FR-009**: O sistema DEVE exigir senhas com no mínimo 8 caracteres, incluindo ao menos uma letra maiúscula, uma minúscula, um dígito e um caractere especial. Senhas comuns (ex.: "12345678", "password") devem ser rejeitadas.
- **FR-010**: O sistema DEVE contar com proteção contra força bruta delegada ao GoTrue (Supabase Auth), que impõe rate limiting nativo de 5 tentativas por minuto por IP e bloqueio temporário após tentativas repetidas. O frontend DEVE adicionalmente desabilitar o botão de submit por 3 segundos após cada tentativa.
- **FR-011**: O sistema DEVE gerenciar sessões autenticadas com JWT de acesso (expiração: 1 hora) e refresh token com rotação automática gerenciada pelo Supabase Auth. Ao fazer logout, ambos os tokens devem ser invalidados.
- **FR-012**: O sistema DEVE registrar em tabela de auditoria (`audit_log`) eventos de segurança: tentativa de login (sucesso/falha), alteração de senha, criação de usuário por admin, ativação/desativação de conta.
- **FR-013**: O sistema DEVE exigir confirmação de e-mail antes de permitir o primeiro login. A flag `email_confirmed_at` em `usuarios` controla esse gate. Em ambiente de desenvolvimento, o Inbucket captura os e-mails de confirmação.
- **FR-014**: O sistema DEVE, após redefinição de senha bem-sucedida, redirecionar o usuário para a página de login com a mensagem "Senha redefinida com sucesso. Faça login com sua nova senha.", forçando reautenticação (sem login automático).

### Key Entities *(include if feature involves data)*

- **Usuário**: Representa a conta de autenticação. Atributos principais: identificador único, e-mail, confirmação de e-mail, telefone, metadados, datas de criação/atualização e último login.
- **Perfil**: Representa os dados aplicacionais do usuário autenticado. Atributos principais: identificador, vínculo com usuário, nome, avatar, perfil de acesso (RBAC), status, departamento e datas de controle.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos usuários de teste das personas conseguem fazer login com sucesso na primeira tentativa, após a execução bem-sucedida de `supabase db reset` (provisionamento dos seeds como pré-requisito).
- **SC-002**: O fluxo de login completo, do carregamento da página ao redirecionamento, é concluído em menos de 5 segundos em condições normais de rede.
- **SC-003**: 100% das tentativas de login com credenciais inválidas exibem exclusivamente a mensagem "E-mail ou senha inválidos" — sem distinção entre e-mail não cadastrado e senha incorreta.
- **SC-004**: A recuperação de senha pode ser solicitada diretamente na página de login e retorna confirmação visual em menos de 3 segundos.
- **SC-005**: Nenhuma resposta de erro do sistema revela se um determinado e-mail está ou não cadastrado na base (proteção contra enumeração de usuários).
- **SC-006**: Senhas que não atendem à política de complexidade (FR-009) são rejeitadas com mensagem específica listando os critérios faltantes.
- **SC-007**: Tokens de redefinição de senha expiram em 1 hora (padrão GoTrue) e não podem ser reutilizados após o primeiro uso.
- **SC-008**: Eventos de segurança (login sucesso/falha, alteração de senha, criação/desativação de usuário) são registrados em `audit_log` com timestamp, usuário afetado e IP de origem.

## Assumptions

- O sistema utiliza o Supabase Auth (GoTrue) como provedor de autenticação, que gerencia nativamente: hash de senhas (bcrypt), rate limiting, JWT, refresh token rotation e envio de e-mails transacionais.
- Toda comunicação com endpoints de autenticação é feita exclusivamente via HTTPS (imposto pelo Supabase e pela Cloudflare Pages).
- As senhas dos usuários de teste são injetadas via variáveis de ambiente (`SEED_USER_PASSWORD`) no `seed.sql`, nunca hardcoded no repositório.
- O envio de e-mails de recuperação/confirmação depende do servidor SMTP configurado no Supabase (produção) ou do Inbucket (desenvolvimento local).
- O serviço de e-mail utilizado em produção DEVE suportar TLS e autenticação SMTP.
- O arquivo `login.html` é a referência de design e comportamento para a nova página de login React.
- Cada persona de negócio é mapeada para um único perfil técnico conforme `personas.md`: Administrador → Administrador, Analista Financeiro → Financeiro, Gerente de Projetos → Projetos, Consultor Comercial → Comercial, Profissional Técnico → Técnico.
- Dados nas tabelas `usuarios` e `perfis` são classificados como **PII** (Personally Identifiable Information): `email`, `phone`, `nome`. Os demais campos são dados operacionais internos.
