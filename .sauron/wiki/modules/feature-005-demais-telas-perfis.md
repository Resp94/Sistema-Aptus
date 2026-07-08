# Feature 005 — Demais Telas por Perfil de Acesso

Esta página documenta a migração e implementação das 9 rotas de negócios que anteriormente utilizavam o componente placeholder `ModuloNaoMigrado`. Todas as telas foram desenvolvidas em React, utilizando acesso a dados exclusivo por RPCs do Supabase (RPC-first), RLS/RBAC granulares e sem simulações de falsos sucessos em integrações.

---

## 1. O que foi feito
Substituição completa de todos os placeholders de módulos do sistema Aptus Flow por telas React funcionais integradas diretamente ao Supabase local via RPCs específicas:
1. **Fluxo de Caixa** (`/fluxo-caixa`)
2. **Contas a Pagar** (`/contas-pagar`)
3. **Contas a Receber** (`/contas-receber`)
4. **Cobranças** (`/cobrancas`)
5. **Propostas Comerciais** (`/propostas`)
6. **Contratos** (`/contratos`)
7. **Equipe** (`/equipe`)
8. **Relatórios** (`/relatorios`)
9. **Configurações** (`/configuracoes`)

---

## 2. Modelo de Dados e Segurança (RBAC/RLS)
Todas as novas tabelas possuem políticas de segurança RLS baseadas no helper `public.permissao_modulo(modulo)` e no perfil do usuário conectado:
- As RPCs de leitura/escrita utilizam o parâmetro `SECURITY DEFINER` e possuem caminhos limpos (`SET search_path = public`).
- Apenas administradores podem ler e atualizar as configurações da empresa e logs de auditoria.
- Profissionais técnicos possuem acesso limitado: na equipe, não visualizam custos (`custo_hora` retorna `NULL` da RPC) e só conseguem apontar horas para suas próprias tarefas e a si mesmos.

---

## 3. Sincronização Lançamento <-> Cobrança
- **Registrar pagamento do lançamento**: Dá baixa na cobrança associada e registra histórico de pagamento.
- **Registrar pagamento da cobrança**: Atualiza o status do lançamento financeiro correspondente para `Pago`.

---

## 4. Integrações Pendentes (Sem Falso Sucesso)
Para ações que demandam serviços externos reais de terceiros (envio de e-mail, gateway de pagamentos), o sistema retorna status de indisponibilidade explícita, mostrando em tela o componente `IntegrationPendingState` ou avisos correspondentes:
- **Envio de Proposta**: Retorna `Não configurado`.
- **Emissão de Boleto**: Retorna `Não configurado`.
- **Lembrete de Cobrança**: Retorna `Não enviado`.
- **Exportação de Relatórios**: Cria registro com status `Indisponível` e `arquivo_url` nulo.

---

## 5. Arquivos Afetados
### Banco de Dados (Migrações)
- `supabase/migrations/20260701000001_demais_telas_schema.sql` (DDL de tabelas)
- `supabase/migrations/20260701000002_demais_telas_security.sql` (Políticas de RLS)
- `supabase/migrations/20260701000003_demais_telas_rpc_financeiro_read.sql`
- `supabase/migrations/20260701000004_demais_telas_rpc_financeiro_write.sql`
- `supabase/migrations/20260701000005_demais_telas_rpc_comercial_read.sql`
- `supabase/migrations/20260701000006_demais_telas_rpc_comercial_write.sql`
- `supabase/migrations/20260701000007_demais_telas_rpc_equipe_read.sql`
- `supabase/migrations/20260701000008_demais_telas_rpc_equipe_write.sql`
- `supabase/migrations/20260701000009_demais_telas_rpc_relatorios_config_read.sql`
- `supabase/migrations/20260701000010_demais_telas_rpc_config_write.sql`
- `supabase/migrations/20260701000011_demais_telas_rpc_auditoria_read.sql`
- `supabase/seed.sql` (Dados sementes atualizados para cobrir todos os fluxos)

### Frontend (React & TypeScript)
- `src/App.tsx` (Mapeamento de novas rotas)
- `src/main.tsx` (Importação dos estilos comuns)
- `src/types/common.ts`, `financeiro.ts`, `comercial.ts`, `equipe.ts`, `relatorios.ts`, `configuracoes.ts` (Modelagem de tipos)
- `src/components/ui/States.tsx` e `states.css` (Componentes comuns de feedback)
- `src/services/financeiro.service.ts`, `comercial.service.ts`, `equipe.service.ts`, `relatorios.service.ts`, `configuracoes.service.ts`
- `src/pages/FluxoCaixaPage.tsx` / `.css`
- `src/pages/ContasPagarPage.tsx` / `.css`
- `src/pages/ContasReceberPage.tsx` / `.css`
- `src/pages/CobrancasPage.tsx` / `.css`
- `src/pages/PropostasPage.tsx` / `.css`
- `src/pages/ContratosPage.tsx` / `.css`
- `src/pages/EquipePage.tsx` / `.css`
- `src/pages/RelatoriosPage.tsx` / `.css`
- `src/pages/ConfiguracoesPage.tsx` / `.css`
- `src/lib/usuario.ts` (Redirecionamento inicial do Visualizador corrigido para `/dashboard`)

---

## 6. Histórico de Testes e Build
- **Build do Vite**: Compilação sem nenhum aviso ou falha (`tsc -b && vite build` concluído com sucesso).
- **Testes Unitários (Vitest)**: Todos os 42 testes passando com sucesso, incluindo os novos testes do service financeiro e permissões de rotas.
- **Reset do Banco**: Executado com sucesso via Docker local sementes atualizados.

---

## 7. Correção de Primeiro Acesso em Configurações
- **Problema**: no primeiro acesso de um administrador à aba `Dados da Empresa`, a RPC `obter_configuracoes_empresa()` podia retornar nenhuma linha porque `public.configuracoes_empresa` ainda não havia sido semeada. O frontend então assumia retorno válido e acabava propagando um estado incompatível com a renderização da tela.
- **Decisão**: o bootstrap da linha única `config_unica` passou a acontecer já na leitura, não apenas na escrita.
- **Justificativa**: a tela de configurações precisa abrir utilizável no primeiro acesso, com defaults coerentes, sem depender de um primeiro salvamento para criar a linha base.
- **Defesa adicional no frontend**: `configuracoesService.obterConfiguracoesEmpresa()` agora normaliza retornos `null`, `undefined` ou arrays vazios para uma estrutura inicial segura, preservando defaults do domínio (`pt-BR`, `dd/MM/yyyy`, `BRL`, dia 5, multa 2, cobrança automática desativada).
- **Arquivos afetados**:
  - `supabase/migrations/20260708020859_bootstrap_configuracoes_empresa_read.sql`
  - `src/services/configuracoes.service.ts`
  - `src/services/configuracoes.service.test.ts`

---

## 8. Cadastro Direto de Usuários em Configurações
- **Problema**: a aba `Contas e Acessos` permitia apenas listar contas existentes e ajustar perfil/status. Não existia fluxo real para um administrador criar um novo usuário no primeiro acesso operacional da empresa.
- **Decisão**: o cadastro de usuário passou a ser direto na própria tela de configurações, sem link de convite. O administrador informa `nome`, `e-mail`, `senha temporária`, `perfil de acesso`, `status` e `departamento`.
- **Implementação**:
  - O frontend ganhou modal de cadastro e integração com `configuracoesService.criarUsuarioConfiguracoes(...)`.
  - O backend ganhou a RPC `public.criar_usuario_configuracoes(payload jsonb)`, protegida por `configuracoes.gerenciar_usuarios` e validação adicional de perfil administrador.
  - A RPC cria a conta em `auth.users`, registra a identidade em `auth.identities`, aproveita a trigger de sincronização já existente para materializar `public.usuarios` e `public.perfis`, e então ajusta perfil/status/departamento finais.
- **Regras de negócio**:
  - Não usar convite por e-mail para esse fluxo administrativo.
  - Apenas administradores com a capacidade `configuracoes.gerenciar_usuarios` podem cadastrar novas contas.
  - A senha temporária deve ter pelo menos 8 caracteres.
  - O e-mail deve ser único e o perfil informado deve pertencer ao conjunto RBAC oficial do sistema.
  - Contas podem ser criadas já como `Inativo`, bloqueando login até ativação posterior.
- **Arquivos afetados**:
  - `supabase/migrations/20260708025456_create_usuario_configuracoes.sql`
  - `src/pages/ConfiguracoesPage.tsx`
  - `src/pages/ConfiguracoesPage.css`
  - `src/services/configuracoes.service.ts`
- `src/services/configuracoes.service.test.ts`
- `src/pages/ConfiguracoesPage.test.tsx`
- `src/types/configuracoes.ts`

---

## 9. Descontinuação do Avatar/Foto de Perfil
- **Problema**: a documentação e parte do contrato funcional de `Configurações` ainda carregavam a noção de avatar/foto de perfil via `avatar_url`, embora a interface ativa não dependesse dessa feature como experiência de produto consolidada.
- **Decisão**: a feature foi descontinuada. Não haverá migração para Supabase Storage, upload de imagem nem manutenção de um contrato vivo para avatar.
- **Estado atual aprovado**:
  - o shell continua mostrando apenas as iniciais do nome do usuário;
  - `Configurações` deixa de tratar avatar/foto de perfil como dado ativo;
  - a documentação atual de schema e telas não deve listar `avatar_url` como campo vigente.
- **Justificativa**: manter um contrato morto criava drift entre backend, frontend e memória arquitetural, além de sugerir um roadmap de mídia que não foi aprovado.
- **Impacto documentado**:
  - remoção de `avatar_url` da documentação corrente de `perfis`;
  - alinhamento da narrativa funcional da tela `Configurações`;
  - preservação do histórico da decisão em `.agents` e `.sauron`.
- **Arquivos afetados**:
  - `.agents/project-memory/005-demais-telas-perfis.md`
  - `.sauron/wiki/knowledge/architecture.md`
  - `.sauron/wiki/knowledge/module-data-schema.md`
  - `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`
  - `docs/banco-de-dados.md`
  - `docs/telas.md`
