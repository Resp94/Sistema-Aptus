# Contract: `.env.local` Production Switch

## Purpose

Definir quando e como a configuracao local do frontend pode passar a apontar para producao.

## Preconditions

- Migrations aplicadas com sucesso.
- Edge Function publicada.
- Secrets server-side verificados.
- Smoke test remoto completo aprovado.
- Usuarios temporarios removidos ou desativados.
- Resultado operacional documentado.

## Allowed Values

```text
VITE_SUPABASE_URL=https://lpwnaxlczwntylcmgotm.supabase.co
VITE_SUPABASE_ANON_KEY=<production public/anon key>
VITE_APP_ENV=production
```

`SEED_USER_PASSWORD` deve ser removido, esvaziado ou mantido apenas se explicitamente necessario para fluxos locais nao-producao. Ele nao deve ser usado para criar usuarios reais de producao.

## Forbidden Values

`.env.local` MUST NOT contain:
- `service_role`
- secret key
- database password
- personal access token
- project management token
- Edge Function private secret

## Validation

After switching:
- App local must authenticate against production.
- Initial authorized route must load.
- Report export flow must still work for an authorized production/session context.
- No privileged key may appear in frontend-consumed environment variables.

## Rollback

If local validation fails:
- Restore previous `.env.local` values.
- Document failure and rollback.
- Do not mark feature complete.
