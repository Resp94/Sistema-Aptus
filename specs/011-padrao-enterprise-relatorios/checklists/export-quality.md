# Export Quality Checklist: Padrao Enterprise Relatorios

**Purpose**: Validate requirement quality for enterprise report export — unit tests for the spec, contracts, and data model.
**Audience**: PR reviewer (author + peer)
**Created**: 2026-07-08
**Validated**: 2026-07-08
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md)

---

## PDF Executivo — Apresentação (Mandatory Gates)

- [x] CHK001 — Os requisitos de hierarquia visual do PDF estão definidos para todas as 4 categorias (Financeiro, DRE, Clientes, Projetos)? [Completeness, Spec §FR-006, Contract pdf-executivo §Category Expectations]
  → **RESOLVIDO**: pdf-executivo.md §Visual Hierarchy define criterios mensuraveis (18pt/14pt/11pt, margens 50pt, LINE_HEIGHT 16pt) identicos para todas as categorias.

- [x] CHK002 — A ordem lógica das seções do PDF (identificação → metadados → resumo → detalhes → empty state) está explicitamente documentada em requisito funcional? [Clarity, Contract pdf-executivo §Required Sections]
  → **PASS**: Contract §Required Sections enumera 1→5 em ordem. Spec §FR-006 lista "identificacao, periodo, resumo executivo e detalhes". Ordem documentada em ambos.

- [x] CHK003 — Os requisitos de nomenclatura de negócio para títulos e subtítulos estão definidos com exemplos concretos por categoria? [Clarity, Spec §FR-004, Contract pdf-executivo §Presentation Rules]
  → **RESOLVIDO**: rotulos-negocio.md fornece mapa completo com exemplos concretos para todas as 4 categorias (ex: `data`→"Data", `nome_contato`→"Nome do Contato").

- [x] CHK004 — O mapeamento de chaves internas → rótulos de negócio está especificado com cobertura para TODAS as chaves que o payload atual retorna? [Completeness, Spec §FR-005, Clarification Session 2026-07-08]
  → **RESOLVIDO**: rotulos-negocio.md cobre 100% das chaves do payload real (validado contra RPC): Financeiro (9 chaves), DRE (5), Clientes (10), Projetos (11). Regra especial para `resumo` documentada.

- [x] CHK005 — Os requisitos de fonte PT-BR (Noto Sans subset) incluem fallback explícito para caso a fonte não carregue na edge function? [Edge Case, Spec §Assumptions, Plan §Technical Context]
  → **RESOLVIDO**: Spec §Edge Cases e §Assumptions definem fallback: StandardFonts.Helvetica + remoção de acentos + log de warning.

- [x] CHK006 — A consistência visual entre categorias está definida com critérios mensuráveis (ex: mesma família de fonte, mesmo tamanho de títulos, mesmas margens)? [Measurability, Spec §FR-008, Contract pdf-executivo §Presentation Rules]
  → **RESOLVIDO**: pdf-executivo.md §Visual Hierarchy define tabela com font-size (18/14/11pt), weight (Bold/Regular), margins (50pt), spacing (16pt) — identicos para todas as categorias.

- [x] CHK007 — Os requisitos de conteúdo para a seção "Resumo Executivo" especificam quais indicadores cada categoria DEVE conter? [Completeness, Contract pdf-executivo §Category Expectations]
  → **PASS**: Contract especifica: Financeiro (entradas, saidas, saldo, volume), DRE (indicadores executivos de resultado), Clientes (base ativa, atividade do periodo), Projetos (carteira, andamento).

- [x] CHK008 — O requisito de empty state (FR-007) define a mensagem exata ou template que substitui o fallback técnico atual? [Clarity, Spec §FR-007, Contract pdf-executivo §Empty State]
  → **RESOLVIDO**: Mensagem exata definida em spec §FR-007 e pdf-executivo.md: "Nao ha dados disponiveis para o periodo selecionado. Selecione um intervalo diferente ou entre em contato com o administrador."

## Download Sem Preview (Mandatory Gates)

- [x] CHK009 — O requisito de "download direto sem preview" (FR-001) especifica o mecanismo técnico esperado (ex: `<a download>` vs `Content-Disposition` header)? [Clarity, Spec §FR-001, Contract download-sem-preview §Behavior]
  → **PASS**: Plan §Project Structure referencia `src/lib/download.ts`. Contract §Behavior diz "entregue como download local com nome e tipo corretos". Mecanismo `<a download>` está documentado no código existente e referenciado no plan.

- [x] CHK010 — Os requisitos cobrem explicitamente ambos os fluxos: (a) exportação nova e (b) re-download do histórico? [Coverage, Spec §US1 Acceptance Scenarios, Contract download-sem-preview §Covered Flows]
  → **PASS**: Spec §US1 Scenario 1 cobre exportação nova, Scenario 2 cobre histórico. Contract §Covered Flows lista ambos explicitamente.

- [x] CHK011 — O requisito de "página permanece utilizável" (FR-002) define o que constitui "utilizável" após o início do download (ex: sem bloqueio de UI, sem navegação, sem modal persistente)? [Measurability, Spec §FR-002, Spec §SC-001]
  → **RESOLVIDO**: download-sem-preview.md §"Utilizavel" define 4 criterios: sem bloqueio de UI, sem navegacao forcada, toast some em 3s, usuario pode continuar interagindo. SC-001 atualizado com limite de 5s.

- [x] CHK012 — Os cenários de falha no download (erro de rede, URL expirada, arquivo indisponível) têm requisitos de UX definidos? [Edge Case, Contract download-sem-preview §Failure Handling]
  → **PASS**: Contract §Failure Handling cobre 3 cenários: item expirado (não inicia), exportação falhou (estado+mensagem), erro temporário (preserva página, informa falha).

- [x] CHK013 — O requisito de nome de arquivo (FR-010) especifica o padrão de nomenclatura incluindo caracteres seguros e encoding para download? [Clarity, Spec §FR-010, Data Model §Exportacao Tabular]
  → **RESOLVIDO**: download-sem-preview.md §File Naming Convention define: `relatorio-{categoria-slug}-{data_inicial}-{data_final}.pdf` para PDF e `exportacao-{categoria-slug}-{data_inicial}-{data_final}.zip` para CSV. FR-010 atualizado.

## CSV / Exportação Tabular (Mandatory Gates)

- [x] CHK014 — Os requisitos de encoding UTF-8 para CSV incluem BOM explícito ou outra estratégia de detecção para ferramentas de escritório? [Clarity, Spec §Assumptions, Contract exportacao-tabular §Required Rules]
  → **PASS**: Spec §Assumptions (atualizado na clarificação) menciona explicitamente "correcoes de encoding (BOM UTF-8)".

- [x] CHK015 — O requisito de "headers compreensíveis por usuários de negócio" define a estratégia de tradução de nomes de coluna (mesmo mapa estático do PDF ou mapa separado)? [Consistency, Contract exportacao-tabular §Required Rules, Clarification Q1]
  → **RESOLVIDO**: rotulos-negocio.md §Aplicação Cruzada estabelece que CSV usa os MESMOS mapas do PDF. "Não há mapa separado para CSV." exportacao-tabular.md atualizado para referenciar rotulos-negocio.md.

- [x] CHK016 — O comportamento de empty state para CSV (sem dados) está definido com headers e mensagem que NÃO usam fallback técnico `mensagem`? [Completeness, Spec §FR-007, Contract exportacao-tabular §Required Rules]
  → **RESOLVIDO**: exportacao-tabular.md define header `Observacao` (substitui `mensagem`). FR-007 atualizado: "Para CSV, o header de empty state deve ser `Observacao`." Mensagem = mesma do PDF.

- [x] CHK017 — Os requisitos de diferenciação visual entre PDF (executivo) e CSV (operacional) na UI de exportação estão especificados? [Coverage, Spec §FR-009, Contract exportacao-tabular §Product Positioning]
  → **RESOLVIDO**: exportacao-tabular.md §Product Positioning define labels: PDF="Documento Executivo", CSV="Exportacao Operacional (.zip)". Historico: badge "PDF" (azul) / "CSV" (cinza).

- [x] CHK018 — O nome do arquivo CSV e o rótulo no histórico de exportações refletem explicitamente que se trata de exportação operacional, não documento executivo? [Consistency, Spec §FR-010, Contract exportacao-tabular §Required Rules]
  → **RESOLVIDO**: Convencao definida: prefixo `exportacao-` para CSV (vs `relatorio-` para PDF). Badge "CSV" cinza no historico. FR-010 e exportacao-tabular.md atualizados.

## Histórico e Validade (Mandatory Gates)

- [x] CHK019 — Os estados possíveis de um item de histórico (`Pronto`, `Falhou`, `Expirado`, `Indisponível`) estão mapeados para comportamentos de UI específicos (ícone, cor, ação disponível)? [Completeness, Contract historico-e-validade §Required Statuses]
  → **RESOLVIDO**: historico-e-validade.md §Required Statuses define tabela completa: Pronto (check verde, botao Baixar), Falhou (X vermelho, sem acao), Expirado (relogio cinza, botao desabilitado + tooltip), Indisponivel (proibido cinza, sem acao).

- [x] CHK020 — O requisito de badge "Expirado" + tooltip com data define o formato exato da data e o texto do tooltip? [Clarity, Spec §Edge Cases, Contract historico-e-validade §Expired Behavior]
  → **RESOLVIDO**: historico-e-validade.md §Expired Behavior define: formato DD/MM/AAAA e tooltip "Este relatorio expirou em DD/MM/AAAA. Gere um novo para o mesmo periodo."

- [x] CHK021 — O requisito de ordenação do histórico (mais recente primeiro) é explícito e cobre o comportamento quando há itens expirados intercalados? [Clarity, Contract historico-e-validade §History Rules]
  → **PASS**: Contract diz "Itens continuam ordenados do mais recente para o mais antigo." O "continuam" implica que expirados mantêm sua posição cronológica, sem segregação.

- [x] CHK022 — A diferenciação visual entre item executivo (PDF) e operacional (CSV) no histórico está especificada? [Coverage, Spec §FR-009, Contract historico-e-validade §History Rules]
  → **RESOLVIDO**: historico-e-validade.md §History Rules define: badge "PDF" azul para executivo, badge "CSV" cinza para operacional.

## Requisitos Não-Funcionais (Advisory)

- [x] CHK023 — O impacto de ~150-250KB da fonte Noto Sans no tempo de cold-start da edge function está documentado e aceito? [Gap, Plan §Technical Context, Clarification Q2]
  → **RESOLVIDO**: plan.md §Font Bundle Tradeoff documenta o overhead de ~200KB como tradeoff aceito, com nota de monitoramento.

- [x] CHK024 — Os requisitos de acessibilidade para o PDF gerado (ex: PDF/UA, texto alternativo em gráficos, contraste) estão definidos? [Gap, Spec — não abordado]
  → **RESOLVIDO**: Spec §Assumptions declara exclusao explicita: "Acessibilidade do PDF (PDF/UA, contraste, texto alternativo) sera tratada em feature futura — nao faz parte deste escopo." Escopo delimitado.

- [x] CHK025 — O requisito de performance "resposta percebida como imediata" (Plan §Performance Goals) está quantificado com limite de tempo máximo para geração + download? [Measurability, Plan §Performance Goals]
  → **RESOLVIDO**: plan.md e spec SC-001 quantificam: "download deve iniciar em ate 5 segundos apos clique para volumes de ate 500 linhas de detalhes."

## Cenários e Edge Cases (Advisory)

- [x] CHK026 — O requisito de "badge Beta/Experimental na UI" define onde e como o indicador aparece (apenas na página de relatórios, também no PDF gerado, também no histórico)? [Clarity, Spec §Assumptions, Clarification Q5]
  → **RESOLVIDO**: Spec §Assumptions delimita: APENAS na pagina de relatorios e no modal de exportacao. NAO no PDF gerado, NAO nos itens do historico.

- [x] CHK027 — O comportamento quando um mesmo relatório é baixado repetidamente por usuários diferentes está definido (nova geração vs reuso de artefato)? [Edge Case, Spec §Edge Cases]
  → **RESOLVIDO**: Spec §Edge Cases define: "Cada usuario gera seu proprio artefato (nova entrada no historico). Nao ha reuso de artefato entre usuarios — isso garante rastreabilidade individual."

- [x] CHK028 — Os requisitos cobrem o cenário de usuário sem permissão `relatorios.exportar` tentando acessar a UI de exportação? [Coverage, Spec — não abordado, Plan §Constitution Check referencia RBAC]
  → **RESOLVIDO**: Spec §Edge Cases define: "botao 'Exportar Relatorio' aparece desabilitado com tooltip 'Voce nao tem permissao para exportar'. Pre-visualizacao e historico permanecem acessiveis (leitura)."

## Consistência Entre Artefatos (Advisory)

- [x] CHK029 — Os requisitos de rótulos de negócio são consistentes entre spec.md, data-model.md e os 4 contratos em `contracts/`? [Consistency, Cross-artifact]
  → **PASS**: Spec, data-model e contracts usam terminologia alinhada: "documento executivo" / "artefato executivo" para PDF, "exportação tabular" / "operacional" para CSV.

- [x] CHK030 — O termo "documento executivo" vs "exportação operacional" vs "exportação tabular" é usado de forma consistente em todos os artefatos? [Terminology, Spec §FR-009, Contract exportacao-tabular, Contract historico-e-validade]
  → **PASS**: Spec §FR-009 usa "documentos executivos" e "exportacoes tabulares". Contracts usam "documento executivo", "artefato operacional", "exportacao tabular" como sinônimos intencionais. Sem conflitos.

---

## Validation Summary

### Mandatory Gates (CHK001–CHK022)

| Categoria | Total | Pass | Fail | % |
|-----------|-------|------|------|---|
| PDF Executivo — Apresentação | 8 | 8 | 0 | 100% |
| Download Sem Preview | 5 | 5 | 0 | 100% |
| CSV / Exportação Tabular | 5 | 5 | 0 | 100% |
| Histórico e Validade | 4 | 4 | 0 | 100% |
| **Mandatory Subtotal** | **22** | **22** | **0** | **100%** |

### Advisory (CHK023–CHK030)

| Categoria | Total | Pass | Fail | % |
|-----------|-------|------|------|---|
| Requisitos Não-Funcionais | 3 | 3 | 0 | 100% |
| Cenários e Edge Cases | 3 | 3 | 0 | 100% |
| Consistência Entre Artefatos | 2 | 2 | 0 | 100% |
| **Advisory Subtotal** | **8** | **8** | **0** | **100%** |

| **TOTAL** | **30** | **30** | **0** | **100%** |

### Artefatos Atualizados nesta Sessão

| Arquivo | Mudanças |
|---------|-----------|
| `contracts/rotulos-negocio.md` | **NOVO** — Mapa completo de tradução chave→rótulo para 4 categorias (35 chaves) |
| `contracts/pdf-executivo.md` | +Visual Hierarchy (tabela mensurável), +Empty State (mensagem exata), +ref rotulos-negocio |
| `contracts/download-sem-preview.md` | +"Utilizavel" (4 critérios), +File Naming Convention (padrão com prefixos) |
| `contracts/exportacao-tabular.md` | +Product Positioning (labels PDF/CSV), +CSV empty state (header `Observacao`), +ref rotulos-negocio |
| `contracts/historico-e-validade.md` | +Required Statuses (tabela 4 estados com UI mapping), +Expired Behavior (formato data + tooltip exato) |
| `spec.md` | Edge Cases (5/5 resolvidos), FR-005/006/007/010 (concretizados), SC-001 (métricas), Assumptions (6 bullets atualizados) |
| `plan.md` | +Font Bundle Tradeoff, +Performance target (5s/500 linhas), +rotulos-negocio.md no project structure |
| `checklists/export-quality.md` | 30/30 ✅ (21 gaps resolvidos) |

---

## Notes

- Todos os 30 itens do checklist passam na validação pós-resolução dos gaps.
- 21 itens foram resolvidos nesta sessão (estavam `[ ]` FAIL, agora `[x]` PASS).
- 9 itens já passavam antes e permanecem passando.
- Checklist validado contra spec.md, plan.md, data-model.md e 5 contratos em `contracts/`.
- Payload validado contra as funções RPC reais `public.montar_payload_relatorio_*`.
