# Spec 009 - Promover Producao Supabase

**Data**: 2026-07-06

## O que foi especificado

Criada a feature Spec Kit `009-promover-producao-supabase` para planejar a promocao controlada do backend local validado para o projeto Supabase de producao `lpwnaxlczwntylcmgotm`.

## Decisoes registradas

- O projeto `lpwnaxlczwntylcmgotm` e producao real.
- A promocao inclui schema versionado, regras de acesso, Storage privado, RPCs e Edge Function `relatorios-exportacao`.
- Seed, dump e dados locais ficam fora do escopo.
- O processo para apos `db push --dry-run` e exige aprovacao manual explicita antes de aplicar schema.
- Mudancas de schema exigem confirmacao previa de backup ou snapshot recuperavel.
- Smoke test remoto usa usuarios temporarios, pois ainda nao existem usuarios reais.
- Usuarios temporarios devem ser removidos ou desativados apos a validacao.
- `.env.local` so aponta para producao depois de smoke test remoto completo aprovado.
- Qualquer falha no smoke test bloqueia a troca de `.env.local` ate correcao e nova validacao.
- Chaves privilegiadas nunca entram em `.env.local`.

## Artefatos criados

- `specs/009-promover-producao-supabase/spec.md`
- `specs/009-promover-producao-supabase/checklists/requirements.md`
- `specs/009-promover-producao-supabase/plan.md`
- `specs/009-promover-producao-supabase/research.md`
- `specs/009-promover-producao-supabase/data-model.md`
- `specs/009-promover-producao-supabase/quickstart.md`
- `specs/009-promover-producao-supabase/contracts/promotion-gates.md`
- `specs/009-promover-producao-supabase/contracts/smoke-test.md`
- `specs/009-promover-producao-supabase/contracts/env-local-switch.md`
- `specs/009-promover-producao-supabase/contracts/documentation-and-recovery.md`

## Planejamento tecnico

Executado `/speckit-plan` para transformar a spec em plano operacional. O plano divide a promocao em checkpoints: verificacao local, confirmacao de destino, backup/snapshot, revisao de migration history, dry-run, aprovacao manual, aplicacao sem seed, deploy da Edge Function, verificacao de secrets, smoke test remoto, limpeza de usuarios temporarios, troca de `.env.local` e documentacao final.

## Proxima etapa

Executar `/speckit-tasks` para gerar tarefas operacionais ordenadas. Nenhum comando de producao deve ser executado antes das tarefas explicitarem gates, aprovacoes e pontos de parada.

## Checklist de qualidade do plano

Executado `/speckit-checklist` sobre `specs/009-promover-producao-supabase/plan.md` e criado `specs/009-promover-producao-supabase/checklists/plan-quality.md`.

O checklist possui 45 itens de revisao de qualidade dos requisitos e do plano, cobrindo completude, clareza, consistencia, criterios de aceite, cobertura de cenarios, seguranca/privacidade, dependencias, premissas, rastreabilidade e prontidao para tarefas. O foco e validar se os artefatos escritos estao prontos para gerar tarefas operacionais, nao testar a execucao em producao.

## Verificacao dos checklists

Em 2026-07-06, os checklists da feature 009 foram verificados contra `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md` e contratos.

- `requirements.md`: 18/18 itens atendidos.
- `plan-quality.md`: 42/45 itens atendidos.
- Itens abertos em `plan-quality.md`: CHK008, CHK010 e CHK015.

Os itens abertos exigem detalhar a evidencia minima de backup/snapshot recuperavel, definir criterios concretos para parar diante de drift ou historico remoto conflitante, e alinhar a transicao de estado do `Lote de Promocao` com todos os gates do contrato `promotion-gates.md`.

## Fechamento dos gaps do checklist

Em 2026-07-06, por deliberacao do responsavel, foi adotada a abordagem estrita para fechar CHK008, CHK010 e CHK015 antes de gerar tarefas.

- CHK008: fechado ao exigir evidencia minima de backup/snapshot recuperavel com tipo, timestamp, origem da confirmacao, responsavel e declaracao de recuperabilidade.
- CHK010: fechado ao definir stop conditions para target divergente, migration remota ausente localmente, migration local com status/ordem remota conflitante, dry-run com objeto fora do escopo, seed/dump/dado local e falhas de autenticacao/permissao/rede que impeçam revisar o estado remoto.
- CHK015: fechado ao alinhar `Lote de Promocao` com a sequencia completa de gates: destino, backup, historico remoto, dry-run, aprovacao manual, schema, Edge Function, secrets, smoke test e `.env.local`.

Resultado final: `plan-quality.md` ficou com 45/45 itens atendidos. Nenhum comando de Supabase Cloud, mutacao de producao ou alteracao de `.env.local` foi executado nesta deliberacao.
