# Security Requirements Checklist: Corrigir Advisors Supabase

**Purpose**: Validar a qualidade, completude e clareza dos requisitos de segurança e critérios de triagem antes do planejamento de implementação
**Created**: 2026-07-06
**Feature**: [spec.md](../spec.md)
**Depth**: Leve (autor, pré-planejamento)
**Focus**: Segurança estrutural (RLS, grants, SECURITY DEFINER, policies) + critérios de triagem

**Note**: Este checklist testa a qualidade dos REQUISITOS — não a implementação. Itens "não" indicam lacunas ou ambiguidades no spec que devem ser resolvidas antes do `/speckit-plan`.

## Requirement Completeness

- [x] CHK001 — Os nomes técnicos dos lints sinalizados pelos advisors (`rls_enabled_no_policy`, `anon_security_definer_function_executable`, `auth_rls_initplan`, `multiple_permissive_policies`) estão explicitamente mapeados para os FRs correspondentes? [Completeness, Gap]
- [x] CHK002 — Os requisitos de acesso estão definidos por papel (`anon`, `authenticated`, `service_role`), especificando o que cada um pode ou não executar? [Completeness, Spec §FR-002]
- [x] CHK003 — Os campos obrigatórios para documentar uma exceção de conformidade (justificativa, impacto, gatilho de revisão, aprovador) estão especificados de forma alinhada com o data model? [Completeness, Spec §FR-012, Data Model §3]
- [x] CHK004 — Está definido o que dispara a reavaliação de uma exceção de conformidade e quem a executa? [Completeness, Spec §FR-012]

## Requirement Clarity

- [x] CHK005 — O "critério de dependência viva" está especificado com a lista exaustiva de superfícies a vasculhar (frontend, Edge Functions, triggers, views, outras funções)? [Clarity, Spec §FR-004, Research §D3]
- [x] CHK006 — As "guardas esperadas" para funções `SECURITY DEFINER` preservadas estão definidas — ex.: devem validar papel do chamador ou condições de negócio? [Clarity, Spec §FR-004]
- [x] CHK007 — "Padrões equivalentes mais eficientes" para reescrita de policies está definido com regras de transformação concretas — ex.: substituir `auth.uid()` direto por `(select auth.uid())`? [Clarity, Spec §FR-006]
- [x] CHK008 — A taxonomia de classificação (`risco_real`, `drift_remoto`, `concessão_residual`, `exceção_intencional`, `fora_escopo`, `resolvido`) possui critérios mutuamente exclusivos para cada rótulo? [Clarity, Spec §FR-011]

## Requirement Consistency

- [x] CHK009 — FR-002 (corrigir exposição) e FR-004 (preservar intencionais) têm ordem de precedência definida quando uma função é simultaneamente exposta e intencionalmente privilegiada? [Consistency, Spec §FR-002, §FR-004]
- [x] CHK010 — Os termos "risco real", "exceção aceita/intencional", "drift remoto" e "fora de escopo" são usados de forma consistente entre o spec, o research e o data model? [Consistency, Spec §Key Entities, Research, Data Model]

## Acceptance Criteria Quality

- [x] CHK011 — O SC-001 ("100% dos achados classificados como risco real deixam de permanecer sem correção") pode ser verificado objetivamente — o snapshot antes/depois dos advisors é o mecanismo de verificação? [Measurability, Spec §SC-001]
- [x] CHK012 — O SC-004 ("warnings reduzidos sem regressão validada") é mensurável — está definido o que constitui "regressão de comportamento autorizado" e como testá-la? [Measurability, Spec §SC-004]
- [x] CHK013 — O FR-013 ("impedir que a conclusão declare conformidade se um risco real continuar sem correção") possui um gate verificável — quem ou o que impõe esse bloqueio e em que momento? [Measurability, Spec §FR-013]

## Scenario & Edge Case Coverage

- [x] CHK014 — Estão definidos requisitos para o cenário em que uma migration é aplicada com sucesso localmente mas o estado remoto diverge (drift durante o deployment)? [Coverage, Edge Case]
- [x] CHK015 — Estão definidos requisitos para funções `SECURITY DEFINER` que têm dependência viva mas implementação insegura (ex.: sem guarda interna de autorização)? [Coverage, Gap]
- [x] CHK016 — Estão definidos requisitos para funções com múltiplos overloads onde apenas alguns estão expostos indevidamente? [Edge Case, Spec §Research D2]
- [x] CHK017 — Estão definidos requisitos para o cenário onde a consolidação de policies permissivas altera o comportamento RBAC de um papel de forma não intencional? [Edge Case, Spec §Edge Cases]

## Dependencies & Assumptions

- [x] CHK018 — A premissa de que "os achados atuais de advisors são um ponto de partida válido" está validada — há requisito de capturar um snapshot baseline antes de iniciar as correções? [Assumption, Spec §Assumptions]
- [x] CHK019 — As ferramentas MCP necessárias para validação remota (`get_advisors`, `list_migrations`, etc.) estão listadas como dependência com suas capacidades esperadas? [Dependency, Spec §Assumptions, Plan §Technical Context]

## Notes

- Itens marcados `[Gap]` indicam ausência de requisito no spec — devem gerar uma ação de clarificação ou adição ao spec.
- Itens marcados `[Clarity]` ou `[Ambiguity]` indicam que o spec menciona o tópico mas sem precisão suficiente para implementação ou teste.
- Este checklist é complementar ao `requirements.md` genérico (16/16) e foca exclusivamente nos requisitos de segurança e triagem.
- Revisado em 2026-07-06 após reforco do spec, data model, triagem governance, remote validation e runbook. Resultado: 19/19 itens atendidos.
