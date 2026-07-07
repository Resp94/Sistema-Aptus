# Data Model: Corrigir Advisors Supabase

## 1. Achado de Advisor

Representa um achado emitido pelos advisors do Supabase e rastreado pela feature.

### Campos

| Campo | Tipo conceitual | Descricao |
|-------|-----------------|-----------|
| `id` | Identificador estavel | Codigo interno usado na triagem (`SEC-001`, `PERF-001`, etc.) |
| `advisor` | Enum | `security` ou `performance` |
| `lint_name` | Texto | Nome tecnico do lint emitido pelo advisor |
| `object_schema` | Texto | Schema do objeto afetado |
| `object_name` | Texto | Nome principal do objeto afetado |
| `object_signature` | Texto opcional | Assinatura da funcao quando aplicavel |
| `severity` | Enum | `INFO`, `WARN` ou nivel equivalente retornado pela ferramenta |
| `classification` | Enum | `risco_real`, `drift_remoto`, `concessao_residual`, `excecao_intencional`, `fora_escopo`, `resolvido` |
| `planned_action` | Texto | Acao esperada pela feature |
| `evidence_source` | Texto | Origem usada na triagem: migration local, advisor remoto, leitura de codigo, metadata remota |

### Relacoes

- Um `Achado de Advisor` pode gerar zero ou uma `Excecao de Conformidade`.
- Um `Achado de Advisor` pode resultar em um ou mais itens do `Conjunto de Correcao Versionado`.
- Um `Achado de Advisor` deve aparecer em pelo menos uma `Execucao de Validacao Remota`.

## 2. Caso de Funcao Privilegiada

Representa a unidade de triagem para funcoes `SECURITY DEFINER` sinalizadas.

### Campos

| Campo | Tipo conceitual | Descricao |
|-------|-----------------|-----------|
| `function_name` | Texto | Nome da funcao |
| `signature` | Texto | Assinatura exata para grants e revokes |
| `intended_callers` | Lista | Papeis esperados (`authenticated`, service-only, interno) |
| `live_dependency` | Enum | `frontend`, `edge_function`, `db_object`, `none`, `unknown` |
| `current_remote_state` | Texto | Resultado resumido da inspecao remota de grants/assinaturas |
| `versioned_expected_state` | Texto | Resultado esperado segundo as migrations versionadas |
| `disposition` | Enum | `preservar`, `corrigir_grants`, `converter`, `remover`, `investigar` |

### Regras

- Funcoes com `live_dependency = none` nao devem permanecer publicamente executaveis por inercia.
- Funcoes com `disposition = preservar` exigem guardas de autorizacao e justificativa documentada.

## 3. Excecao de Conformidade

Representa um achado mantido intencionalmente apos triagem.

### Campos

| Campo | Tipo conceitual | Descricao |
|-------|-----------------|-----------|
| `exception_id` | Identificador | Codigo interno da excecao |
| `related_finding_id` | Referencia | Achado ao qual a excecao pertence |
| `justification` | Texto | Motivo pelo qual o comportamento e mantido |
| `impact` | Texto | Impacto residual aceito |
| `review_trigger` | Texto | Evento que exige reavaliacao futura |
| `review_owner` | Texto | Papel ou responsavel que executa a reavaliacao quando o gatilho ocorrer |
| `approved_by` | Texto | Responsavel por aprovar a excecao |

### Regras

- Nao pode existir excecao sem justificativa, impacto, gatilho de revisao, responsavel pela reavaliacao e aprovador.
- Excecao nao substitui correcao quando o achado ainda for classificado como risco real.

## 4. Conjunto de Correcao Versionado

Representa o lote auditavel de correcao entregue pelo repositório.

### Campos

| Campo | Tipo conceitual | Descricao |
|-------|-----------------|-----------|
| `migration_name` | Texto | Nome da migration |
| `scope` | Lista | Grants, policies, helper functions, tests, documentation |
| `expected_outcomes` | Lista | Achados que a migration pretende resolver |
| `rollback_note` | Texto | Observacao de recuperacao ou reexecucao segura |

### Regras

- Cada migration deve ter escopo rastreavel em relacao aos achados da triagem.
- O lote nao deve incluir tuning amplo fora do escopo declarado da feature.

## 5. Execucao de Validacao Remota

Representa uma rodada de verificacao do estado remoto apos aplicacao.

### Campos

| Campo | Tipo conceitual | Descricao |
|-------|-----------------|-----------|
| `run_id` | Identificador | Identificador da rodada |
| `target_project_ref` | Texto | Projeto validado |
| `security_snapshot` | Texto estruturado | Resumo dos achados de seguranca antes/depois |
| `performance_snapshot` | Texto estruturado | Resumo dos achados de performance antes/depois |
| `residual_findings` | Lista | Achados que permaneceram apos a rodada |
| `final_status` | Enum | `aprovado`, `bloqueado`, `parcial` |

### Regras

- Nao ha conclusao de conformidade sem pelo menos uma `Execucao de Validacao Remota` apos as migrations.
- Toda persistencia de achado deve virar classificacao final em `triagem.md`.

## 6. Regras de Classificacao

| Classificacao | Criterio de uso | Exclusoes obrigatorias |
|---------------|-----------------|------------------------|
| `risco_real` | Falha material ainda sem mitigacao aprovada | Nao pode coexistir com `excecao_intencional` ou `resolvido` |
| `drift_remoto` | Estado remoto difere do estado versionado esperado | Nao pode ser usado quando a exposicao e intencional |
| `concessao_residual` | Grant ou exposicao remanescente ainda nao legitimado como intencional | Nao pode ser usado como fechamento definitivo sem acao posterior |
| `excecao_intencional` | Comportamento preservado formalmente com justificativa e aprovacao | Nao pode existir sem impacto, gatilho e aprovador |
| `fora_escopo` | Item explicitamente excluido da feature | Nao conta como resolucao |
| `resolvido` | Item fechado pela rodada de correcao e validacao | Nao pode coexistir com qualquer outra classificacao |
