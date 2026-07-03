# Security & Requirements-Quality Gate Checklist: Hardening de Segurança das RPCs

**Purpose**: Gate formal de release — valida a **qualidade dos requisitos** (completude, clareza, consistência, mensurabilidade, cobertura) da spec e do plano antes de gerar tasks e implementar. Não testa implementação; testa se os requisitos estão bem escritos.
**Created**: 2026-07-02
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)
**Foco**: Segurança (guardrails/RBAC/auditoria) · Testabilidade e gates (pgTAP/CI) · Preservação de contrato (Fase 1) · Diretrizes arquiteturais (Fase 4)
**Público/Timing**: Autor/revisor, antes de codar

**Legenda de status**: `[x]` = requisito bem escrito / coberto · `[ ]` = lacuna ou ambiguidade residual (ver nota). Verificação executada em 2026-07-02.

## Requirement Completeness (Segurança)

- [x] CHK001 - Os requisitos definem o modelo de ameaça do chamador anônimo para cada classe de função (domínio, helper de permissão, auditoria, trigger)? [Completeness, Spec §Contexto] — OK: US1/US2/US3 + Edge Cases cobrem; classificação por classe em data-model.md.
- [x] CHK002 - Está especificado o que acontece com os registros existentes de `audit_log` cujo autor foi previamente fornecido pelo cliente (integridade histórica)? [Gap] — RESOLVIDO: §Assumptions agora registra a decisão — dados históricos aceitos como estão; autoria confiável vale a partir da função corrigida.
- [x] CHK003 - Há requisito definindo o comportamento de idempotência/reexecução das migrations corretivas (Fase 0 e Fase 1)? [Gap] — RESOLVIDO: research.md item 11 documenta `CREATE OR REPLACE` + `DROP IF EXISTS` (reexecutáveis).
- [x] CHK004 - Há requisito de rollback/tratamento para falha parcial da migration de padronização das 26 funções? [Gap, Recovery Flow] — RESOLVIDO: research.md item 11 registra que DDL Postgres é transacional (reverte atomicamente) + fases em migrations separadas.
- [x] CHK005 - Está especificado o modo de falha do seed efêmero (se a criação/descarte da função de teste falhar no reset local)? [Gap, Spec §FR-002] — RESOLVIDO: research.md item 11 exige que o `DROP` final da função efêmera rode sempre, mesmo após erro.
- [x] CHK006 - Os requisitos declaram explicitamente a fonte de verdade de autorização (tabela de perfis, nunca `user_metadata`)? [Completeness, Spec §Assumptions] — OK: §Assumptions bullet 2 + FR-004 + US3.

## Requirement Clarity & Measurability (Segurança)

- [x] CHK007 - O "erro de não-autorizado explícito" (FR-010) está definido com um contrato objetivo e testável (texto e código de erro canônicos)? [Ambiguity, Spec §FR-010] — OK: contrato canônico (`Unauthorized`/ERRCODE `42501`) em contracts/guardrail-standard.md. Recomendado citar o código na spec para rastreabilidade.
- [x] CHK008 - A lista fixa de eventos de pré-autenticação está enumerada de forma fechada, ou o "no mínimo a falha de login" (FR-003a) deixa a lista aberta e ambígua? [Ambiguity, Spec §FR-003a] — RESOLVIDO: FR-003a agora define lista fechada e explicitamente mantida (atualmente exatamente `login_falha`), ampliável só por alteração da função.
- [x] CHK009 - O critério de "grava sempre a identidade da sessão como autor" é mensurável/verificável de forma inequívoca? [Measurability, Spec §FR-003] — OK: autor == `auth.uid()`; testável (US2 cenário 3 + SC-004).
- [x] CHK010 - "Todo novo usuário nasce Visualizador sem exceção" (FR-004) está definido sem brechas de interpretação (convite, criação por admin, importação)? [Clarity, Spec §FR-004] — RESOLVIDO: FR-004 agora explicita que governa o caminho de auto-cadastro e que perfil diferente só vem da promoção administrativa (FR-005) após a criação.

## Requirement Consistency & Conflicts

- [x] CHK011 - Os nomes de perfis em FR-015 conferem com os perfis reais? [Conflict, Spec §FR-015] — RESOLVIDO: FR-015 e Key Entities usam `Projetos` (não "Gestor").
- [x] CHK012 - A contagem de funções em SC-003 é consistente após remoção/recriação? [Conflict, Spec §SC-003] — RESOLVIDO: SC-003 refere o conjunto remanescente (80 após a remoção).
- [x] CHK013 - A tensão FR-011 (zero mudança) × FR-010 (erro explícito ao anônimo) está reconciliada? [Conflict, Spec §FR-011] — RESOLVIDO: FR-011 escopa "chamadores legítimos" e admite o erro ao anônimo.
- [x] CHK014 - O conjunto das "26 funções antigas" (§Contexto) é consistente com FR-008 e com a exclusão de `existe_perfil_admin`/`registrar_evento_auditoria`? [Consistency, Spec §FR-008] — RESOLVIDO: (a) §Contexto agora separa o grupo crítico da Fase 0 do conjunto de 26 (23 domínio + 3 helpers) da Fase 1; (b) `validar_perfil_update` entrou no escopo da Fase 0 via FR-007a (fixar `search_path`), fechando o furo em SC-003.
- [x] CHK015 - FR-003 e FR-003a estão redigidos sem se contradizerem após a clarificação? [Consistency, Spec §Clarifications] — OK: são complementares (autenticado × whitelist anônima).

## Acceptance Criteria Quality (Success Criteria)

- [x] CHK016 - Todos os critérios SC-001..SC-008 são mensuráveis e independentes de implementação? [Acceptance Criteria] — OK: mensuráveis; SC-004 é absoluto mas testável via US2.
- [x] CHK017 - SC-001 quantifica a exceção da auditoria de forma objetiva e verificável? [Measurability, Spec §SC-001] — OK: "exatamente 1 exceção catalogada".
- [x] CHK018 - SC-008 é reconciliável com FR-003b (3 pontos na Fase 0)? [Consistency, Spec §SC-008] — RESOLVIDO: SC-008 explicita que os 3 pontos são Fase 0 e não contam.
- [x] CHK019 - Existe critério mensurável para "auditoria não falsificável" além do qualitativo (SC-004)? [Measurability, Spec §SC-004] — OK: FR-003b torna impossível por construção (parâmetro removido) + cenários de US2.

## Testabilidade & Gates (pgTAP / CI) — Qualidade dos Requisitos

- [x] CHK020 - O escopo de "toda função SECURITY DEFINER" do teste (FR-016) define exclusões (triggers, auditoria)? [Gap, Spec §FR-016] — OK: exceção da auditoria na spec; exclusão de triggers definida em research.md (item 3). Recomendado mencionar a exclusão de triggers na spec.
- [x] CHK021 - O critério do script de auditoria (FR-012) enumera o "conjunto completo de guardrails"? [Measurability, Spec §FR-012] — OK: FR-012 enumera os 5 guardrails inline.
- [x] CHK022 - A matriz por perfil (FR-015) especifica quais módulos são leitura/escrita por perfil, ou apenas lista os perfis? [Completeness, Spec §FR-015] — RESOLVIDO: FR-015 agora cita `obter_permissoes_usuario` como fonte única de verdade da matriz, contra a qual os testes comparam.
- [x] CHK023 - A ordem e o bloqueio de cada etapa do CI (FR-017) estão inequívocos? [Clarity, Spec §FR-017] — OK: FR-017 "em sequência" + "bloquear se qualquer etapa falhar"; contracts/ci-and-audit.md detalha a ordem.
- [x] CHK024 - Os requisitos distinguem `db lint` de `db advisors`? [Clarity, Spec §FR-017] — OK: FR-017 + §Assumptions bullet 4 distinguem qualidade de schema × avisos de segurança nativos.
- [x] CHK025 - Há requisito sobre pré-condições do CI (disponibilidade de `advisors`) e fallback? [Gap] — OK: research.md item 9 (CLI ≥ 2.81.3 + fallback `get_advisors` via MCP).
- [x] CHK026 - A allowlist do check `supabase.from()` (FR-013) está fechada e justificada? [Clarity, Spec §FR-013] — OK: FR-013 + contracts especificam `health-check.ts`.
- [x] CHK027 - O check anti-`user_metadata` (FR-014) distingue uso legítimo (nome/departamento) de proibido (autorização) de forma testável? [Ambiguity, Spec §FR-014] — RESOLVIDO: contracts/ci-and-audit.md agora define allowlist explícita de ocorrências legítimas; qualquer ocorrência nova reprova o CI e exige revisão consciente (default seguro, sem heurística frágil).

## Preservação de Contrato (Fase 1) — Qualidade dos Requisitos

- [x] CHK028 - "Sem alterar assinatura/comportamento" (FR-011) tem critério objetivo de verificação? [Measurability, Spec §FR-011] — OK: SC-008 (0 pontos de chamada) + Independent Test da US4.
- [x] CHK029 - Os requisitos especificam que a guarda `auth.uid()` não altera o resultado para chamadores legítimos? [Clarity, Spec §FR-010] — OK: FR-011 agora afirma isso explicitamente.
- [x] CHK030 - Está documentado que helpers chamados dentro de outras `SECURITY DEFINER`/RLS continuam operando após a guarda? [Coverage, Gap] — OK: research.md item 7 ("Cuidado": `auth.uid()` resolve o chamador original dentro de `SECURITY DEFINER`).

## Diretrizes Arquiteturais (Fase 4) — Qualidade dos Requisitos

- [x] CHK031 - A condição para a agregadora É permitida está definida de forma mensurável? [Ambiguity, Spec §FR-019] — OK (intencional): FR-019 exige "latência medida" como gate de "medir antes de agregar"; limiar decidido caso a caso, por design.
- [x] CHK032 - As armadilhas de RLS (UPDATE exige `USING`+`WITH CHECK`; UPDATE exige SELECT) estão como requisitos acionáveis? [Clarity, Spec §FR-020] — OK: FR-020 + Edge Cases (linha 132); detalhado em docs/arquitetura-dados.md.
- [x] CHK033 - "Views, frontend nunca as chama" (FR-020) tem mecanismo de verificação? [Coverage, Gap, Spec §FR-020] — OK (parcial): acesso a view no frontend seria via `supabase.from()`, já barrado por `check-no-from.mjs`. Diretriz + enforcement indireto.

## Dependencies, Assumptions & Scope Boundaries

- [x] CHK034 - A suposição "cadastro público pode estar habilitado" está validada, ou permanece não verificada? [Assumption, Spec §Assumptions] — OK: documentada como suposição; a correção (nunca confiar em metadata) é válida independentemente de o cadastro público estar ligado.
- [x] CHK035 - A dependência de FR-005 na RPC de promoção existente está validada (existe + protegida)? [Assumption/Dependency, Spec §FR-005] — OK: `atualizar_usuario_perfil` existe, é admin-only (`existe_perfil_admin`), com `search_path` e `REVOKE`/`GRANT`, e valida contra os 6 perfis reais.
- [x] CHK036 - As fronteiras de "Out of Scope" estão sem sobreposição ambígua com o escopo incluído? [Clarity, Spec §Out of Scope] — OK: agregadora, UI, novas funcionalidades e reescrita de call sites (exceto auditoria) claramente delimitadas.

## Notes

- Check items off as completed: `[x]`
- **Status final: 36/36 itens aprovados.** Todos os achados da verificação de 2026-07-02 foram endereçados na spec e/ou nos artefatos do plano.
- **Achado de maior impacto (CHK014)**: o trigger `validar_perfil_update` estava fora do escopo e é `SECURITY DEFINER` sem `search_path` — teria reprovado SC-003. Incluído na Fase 0 via FR-007a.
- **Decisão registrada (CHK002)**: registros históricos de `audit_log` aceitos como estão; autoria confiável passa a valer a partir da função corrigida (§Assumptions).
- **Polimentos aplicados**: CHK008 (lista fechada de eventos pré-auth), CHK010 (escopo do gatilho de cadastro), CHK022 (fonte única da matriz de permissões), CHK027 (allowlist em vez de heurística), CHK003/004/005 (segurança de migrations/seed em research.md item 11).
- Traceability: cada item referencia uma seção da spec ou um marcador ([Gap]/[Ambiguity]/[Conflict]/[Assumption]).
