# Research: Promover Producao Supabase

## Decision 1: Promocao por migrations versionadas com dry-run obrigatorio

**Decision**: Usar o fluxo de migrations versionadas como caminho unico de promocao do schema, sempre com revisao previa e `dry-run` antes de aplicar.

**Rationale**: A documentacao oficial da Supabase CLI descreve `db push` como o comando de CI/CD para liberar migrations em producao e registra que `--dry-run` imprime as migrations que seriam aplicadas sem executa-las. Para producao real, isso sustenta o gate definido na spec: revisar destino, estado remoto e lista de migrations antes de qualquer mutacao.

**Alternatives considered**:
- Aplicar SQL manual no Dashboard: rejeitado por perder rastreabilidade de migrations.
- Dump completo local para remoto: rejeitado por misturar schema com dados, Auth, seeds e artefatos locais.
- Aplicar automaticamente apos dry-run: rejeitado porque producao real exige aprovacao manual explicita.

**Sources**:
- Supabase CLI reference, `supabase db push`: https://supabase.com/docs/reference/cli/supabase-db-push

## Decision 2: Seed, dump e dados locais ficam fora do escopo

**Decision**: Nao usar `--include-seed`, dumps data-only ou qualquer copia de dados locais nesta promocao.

**Rationale**: A feature e sobre promover backend validado, nao popular producao. Como ainda nao existem usuarios reais, o smoke test criara usuarios temporarios controlados, com limpeza/desativacao ao final. Isso evita transportar senhas, perfis, dados de teste ou estado local que nao representa operacao real.

**Alternatives considered**:
- Subir `supabase/seed.sql`: rejeitado porque seed e voltado ao ambiente local/dev.
- Criar usuarios reais antecipadamente: rejeitado porque o usuario confirmou que ainda nao existem usuarios reais.
- Copiar banco local inteiro: rejeitado por risco operacional e privacidade.

## Decision 3: Backup/snapshot recuperavel e pre-condicao para mutacao

**Decision**: Antes de `db push` em producao, exigir confirmacao de backup/snapshot recuperavel do projeto remoto.

**Rationale**: Migrations podem ser parcialmente irreversiveis ou depender de estado remoto. A spec exige caminho claro de parada/reversao; em producao real, isso nao pode depender apenas da intencao de escrever uma migration reversa depois do erro.

**Alternatives considered**:
- Confiar apenas no historico de migrations: rejeitado porque historico nao restaura dados removidos ou alterados indevidamente.
- Exigir backup somente se houver mudanca destrutiva no dry-run: rejeitado porque o risco tambem inclui falha operacional, permissao, ordem de migrations e estado remoto divergente.

## Decision 4: Deploy da Edge Function como checkpoint separado do schema

**Decision**: Aplicar schema e deployar `relatorios-exportacao` como checkpoints separados, ambos com verificacao.

**Rationale**: A feature 008 depende simultaneamente de RPCs, Storage privado e Edge Function. A documentacao da Supabase CLI descreve `functions deploy` como o comando para publicar uma funcao no projeto vinculado ou informado por `--project-ref`. Separar schema e funcao facilita identificar se falhas estao no banco, no bundle/deploy da funcao ou nos secrets.

**Alternatives considered**:
- Deployar funcao antes de schema: rejeitado porque a funcao depende de RPCs/bucket/policies.
- Tratar deploy da funcao como parte implicita do `db push`: rejeitado porque sao superficies diferentes.

**Sources**:
- Supabase CLI reference, `supabase functions deploy`: https://supabase.com/docs/reference/cli/supabase-functions-deploy

## Decision 5: Secrets server-side, chave publica no frontend

**Decision**: Verificar secrets da Edge Function separadamente e manter `.env.local` com apenas URL e chave publica apropriada ao cliente.

**Rationale**: A documentacao de Edge Function Secrets indica que chaves secret/service_role sao seguras em Edge Functions, mas nunca devem ser usadas no browser porque bypassam RLS. O frontend deve usar apenas chave anon/publishable com RLS e RPCs. A troca de `.env.local` so ocorre depois do smoke test remoto completo.

**Alternatives considered**:
- Colocar service role em `.env.local`: rejeitado por violacao critica de seguranca.
- Alterar `.env.local` antes do deploy da funcao: rejeitado porque tornaria o frontend local parte do diagnostico de backend incompleto.

**Sources**:
- Supabase Edge Function secrets: https://supabase.com/docs/guides/functions/secrets

## Decision 6: Smoke test remoto com usuarios temporarios

**Decision**: Criar usuarios temporarios em producao para validar ao menos um perfil autorizado e um perfil sem permissao; remover ou desativar ambos ao final.

**Rationale**: Ainda nao existem usuarios reais. Criar usuarios temporarios permite testar Auth/RPC/RLS/Edge Function com o mesmo fluxo que usuarios reais usarao, sem seed geral e sem dados locais.

**Alternatives considered**:
- Validar somente via service role/admin: rejeitado porque nao prova autorizacao user-scoped.
- Esperar usuarios reais: rejeitado porque bloqueia a validacao da promocao.
- Criar usuarios permanentes de teste: rejeitado porque deixa superficie operacional desnecessaria em producao.

## Decision 7: Falha parcial bloqueia troca de `.env.local`

**Decision**: Qualquer falha no smoke test remoto bloqueia a alteracao de `.env.local` ate correcao e novo smoke test completo.

**Rationale**: A troca de `.env.local` deve ser o ultimo checkpoint. Login e leitura funcionando nao bastam se exportacao ou bloqueio de usuario sem permissao falhar, pois a feature 008 e o objetivo imediato desta promocao dependem desses fluxos.

**Alternatives considered**:
- Permitir troca com pendencias documentadas: rejeitado por criar uma validacao local contra producao parcialmente confiavel.
- Permitir troca se login/leitura funcionarem: rejeitado porque ignora o risco principal da Edge Function.
