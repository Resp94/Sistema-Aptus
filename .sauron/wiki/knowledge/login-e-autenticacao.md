# Login e Autenticação

## 1. Contexto e Motivação
Implementação da primeira página em React (`Login.tsx`) a partir do design legado (`login.html`), integrando-a ao provedor de autenticação nativo do Supabase (GoTrue) para controle de acesso seguro e identificação de personas de negócio na Aptus Flow.

## 2. Como Funciona
O fluxo é totalmente baseado na arquitetura **RPC-first**:
1. **Login**: O usuário informa e-mail e senha. O frontend valida a complexidade da senha (mínimo de 8 caracteres, uma maiúscula, uma minúscula, um número e um caractere especial) e, após desabilitar o clique por 3 segundos (rate limit local), chama `signInWithPassword`.
2. **Obtenção do Perfil**: Uma vez autenticado no `auth.users`, o cliente chama a RPC `obter_perfil_usuario()` para recuperar os dados aplicacionais (nome, perfil_acesso, status, departamento).
3. **Mapeamento de Perfis (RBAC)**: O roteadorSPA simples no React direciona o usuário para as telas legadas de acordo com seu perfil de acesso:
   - `Administrador` / `Financeiro` -> `/dashboard.html`
   - `Projetos` / `Técnico` -> `/projetos.html`
   - `Comercial` -> `/clientes.html`
4. **Recuperação de Senha**: No modal da tela de login, o usuário solicita recuperação. Um e-mail com link de redefinição é gerado via GoTrue (capturado pelo Inbucket no local dev). O link redireciona para a rota com hash de recovery, que é capturada pelo `ResetPassword.tsx` para alteração segura e posterior reautenticação forçada.
5. **Auditoria**: Logins de sucesso e falha, além de mudanças de senha e criação de usuários, são gravados na tabela `audit_log` via RPC `registrar_evento_auditoria()`.

## 3. Segurança e RLS
* **Isolamento de Tabelas**: RLS habilitado em todas as tabelas (`usuarios`, `perfis`, `audit_log`).
* **Trigger Sincronizada**: Qualquer alteração no schema `auth.users` é replicada em tempo real para `public.usuarios` e `public.perfis` via trigger pós-INSERT/UPDATE.
* **Bypass de Recursão**: As funções auxiliares e triggers utilizam `SET row_security = off` para evitar loops de recursão no RLS.

## 4. Arquivos Afetados
* `src/pages/Login.tsx` (Componente de Login React)
* `src/pages/ResetPassword.tsx` (Tela de alteração de senha)
* `src/components/ui/Toast.tsx` (Componente de feedback visual)
* `src/services/auth.service.ts` (Serviço de integração)
* `src/types/auth.ts` (Tipos TypeScript de RBAC)
* `src/App.tsx` (Roteamento SPA)
* `supabase/migrations/00000000000000_usuarios_perfis.sql` (Migration do banco)
* `supabase/seed.sql` (Seed das personas)
* `supabase/config.toml` (Configuração do Supabase)

## 5. Data da Alteração
* 2026-06-27
