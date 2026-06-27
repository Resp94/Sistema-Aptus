# UI/Service Contract: Login Flow

## Login Screen

**Route**: `/login` (public)

**Inputs**:
- `email`: string, required, valid email format, trimmed and lowercased before submission
- `password`: string, required, minimum 8 characters (frontend validation mirrors FR-009)
- `remember`: boolean, optional (controls session persistence — see "Lembrar de mim" Contract)

**Actions**:
- Submit form → validate inputs, disable button for 3s (client-side rate limit), then call Supabase Auth `signInWithPassword({ email, password })`
- "Forgot password" link → open modal → call `resetPasswordForEmail(email)`
- Toggle password visibility

**Feedback**:
- Loading state on submit button
- Inline validation errors for empty/invalid fields
- Toast error for invalid credentials or inactive account
- Success → redirect to `/dashboard`

## Password Reset Modal

**Inputs**:
- `resetEmail`: string, required, valid email format

**Actions**:
- "Send link" → call `resetPasswordForEmail(resetEmail)`
- "Cancel" → close modal, restore focus

**Feedback**:
- Generic success message regardless of whether email exists (privacy)
- Error toast if email format is invalid

## Session Contract

After successful login, the Supabase client holds the session JWT.
The application reads the current user via `supabase.auth.getUser()` / `onAuthStateChange`.

**RPC-first access**: All profile data is fetched via PostgreSQL RPC functions, never via direct table queries.

### RPC Endpoints

| RPC Function | Purpose | Returns | Authorization |
|-------------|---------|---------|---------------|
| `obter_perfil_usuario()` | Get current authenticated user's profile | `{ nome, perfil_acesso, status, avatar_url, departamento }` or null | `WHERE usuario_id = auth.uid()` — user reads only own profile; no admin override needed for self-read |
| `obter_permissoes_usuario()` | Get current user's permission set | `{ modulo, pode_ler, pode_escrever }[]` | Reads `perfil_acesso` from own profile, maps to module permissions server-side |
| `criar_perfil_teste(email, senha, nome, perfil_acesso)` | Admin-only: create test user + profile | `{ usuario_id, perfil_id }` | Checks `existe_perfil_admin(auth.uid())` at function start; raises `EXCEPTION 'Apenas administradores podem criar perfis de teste'` on failure |

### Null Profile Contract

If `obter_perfil_usuario()` returns null (authenticated user exists in `auth.users` but has no corresponding row in `public.perfis`):
1. The frontend displays: "Perfil não encontrado. Entre em contato com o administrador."
2. The frontend forces logout via `supabase.auth.signOut()`
3. The user is redirected to `/login`

### "Lembrar de mim" Contract

When `remember` is `true`:
- Supabase Auth `signInWithPassword` is called with default session persistence (refresh token stored in browser)
- Session persists across browser restarts until logout or token expiry
- JWT access token expires in 1 hour; refresh token is rotated automatically
- When `remember` is `false`: session is browser-session only (cleared on browser close)

### Password Reset Post-Flow

After successful password reset via the reset link:
- User is redirected to `/login`
- Toast displays: "Senha redefinida com sucesso. Faça login com sua nova senha."
- No automatic login occurs — forced re-authentication required

All RPCs use `SECURITY DEFINER` — the function owner (typically a privileged role) executes the logic, so the function can access tables that are otherwise blocked to the frontend's `authenticated` role. Authorization is performed inside the function body (e.g., checking `auth.uid()` against the target record, verifying `perfil_acesso`).

**RLS as second defense layer**: Each table has granular, per-operation policies (SELECT, INSERT, UPDATE) — no `ALL` shortcuts. DELETE is never permitted on `usuarios` or `perfis`; deactivation is done via `status`. See [data-model.md](../data-model.md) for the full RLS policy matrix.
