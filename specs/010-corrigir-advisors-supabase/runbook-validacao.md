# Runbook de Validacao Remota

## Objetivo

Validar remotamente o estado dos advisors no projeto `lpwnaxlczwntylcmgotm` antes e depois da aplicacao das correcoes da feature 010.

## Pre-requisitos

- MCP do Supabase conectado ao projeto de producao
- Migrations da feature preparadas e revisadas
- `triagem.md` atualizado com o baseline dos achados

## Passo 1: Baseline

1. Confirmar o projeto remoto com `get_project_url`
2. Capturar `get_advisors(type=security)`
3. Capturar `get_advisors(type=performance)`
4. Registrar em `triagem.md` qualquer variacao relevante em relacao ao baseline inicial

## Passo 2: Estado Esperado

1. Listar as migrations locais relevantes da feature
2. Confirmar quais objetos e grants elas pretendem alterar
3. Marcar os achados que deveriam ser resolvidos pela rodada
4. Confirmar quais superfícies foram vasculhadas para dependência viva: `src/services`, `src/lib`, `supabase/functions`, triggers, views e outras funções SQL relacionadas

## Passo 3: Pos-aplicacao

1. Reexecutar `get_advisors(type=security)`
2. Reexecutar `get_advisors(type=performance)`
3. Comparar objeto por objeto com o baseline
4. Se necessario, fazer inspecao remota complementar de grants, assinaturas ou dependencias

## Passo 4: Classificacao Final

Para cada achado remanescente, escolher exatamente uma classificacao:

- `resolvido`
- `drift_remoto`
- `concessao_residual`
- `excecao_intencional`
- `fora_escopo`
- `pendencia_bloqueadora`

## Regras de Precedencia

- Se uma funcao tiver dependencia viva e tambem exposicao indevida, corrigir exposicao e guardas antes de preserva-la.
- Se houver multiplos overloads, classificar e corrigir por assinatura exata, nunca por nome agregado.
- Se uma excecao for necessaria, registrar justificativa, impacto, gatilho de revisao, responsavel pela reavaliacao e aprovador.

## Definicao de Regressao

Considerar regressao qualquer um dos casos abaixo:

- um papel antes bloqueado passa a executar funcao ou fluxo nao previsto;
- um papel antes permitido perde acesso legitimo;
- uma regra de ownership, capacidade ou negocio fica mais frouxa do que antes da correcao.

## Criterios de Encerramento

- Nenhum `risco_real` no escopo fica sem correcao ou sem excecao aprovada
- `triagem.md` recebe classificacao final para todos os itens no escopo
- `.agents/project-memory/010-corrigir-advisors-supabase.md` registra a rodada
- `.sauron/wiki/knowledge/architecture.md` registra o impacto arquitetural e operacional

## Falhas que Bloqueiam a Conclusao

- MCP nao consegue confirmar o projeto remoto
- Advisors nao podem ser consultados apos a aplicacao
- Persistiu funcao exposta indevidamente sem explicacao
- Persistiu tabela com RLS sem policy coerente
- Persistiu regressao de comportamento autorizado em funcao, policy ou fluxo preservado
