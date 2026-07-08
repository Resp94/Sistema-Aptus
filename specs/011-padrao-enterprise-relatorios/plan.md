# Implementation Plan: Padrao Enterprise Relatorios

**Branch**: `011-padrao-enterprise-relatorios` | **Date**: 2026-07-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-padrao-enterprise-relatorios/spec.md`

## Summary

Elevar a exportacao de relatorios para um padrao enterprise sem abrir escopo de produto alem do necessario: o PDF passa a ser o documento executivo oficial, com download direto sem preview, linguagem PT-BR correta, hierarquia visual coerente e apresentacao sem vazamento de chaves tecnicas; os formatos tabulares permanecem operacionais, mas recebem correcoes de encoding, nomenclatura e comportamento de historico. A implementacao reaproveita a arquitetura ja existente da feature 008, concentrando mudancas em `RelatoriosPage`, `relatorios.service.ts`, na Edge Function `relatorios-exportacao`, nos renderers de PDF/CSV e nos contratos do historico.

## Technical Context

**Language/Version**: TypeScript no frontend Vite/React, TypeScript/Deno na Supabase Edge Function, SQL PostgreSQL no Supabase para schema/RPCs/RLS ja existentes.

**Primary Dependencies**: React 19, Vite, `@supabase/supabase-js`, Supabase Edge Functions, `pdf-lib`, `fflate`, Storage privado Supabase.

**Storage**: PostgreSQL para metadados de exportacao em `public.exportacoes_relatorios`; Supabase Storage privado no bucket `relatorios-exportados`; arquivos PDF e ZIP/CSV continuam privados e assinados sob demanda.

**Testing**: Vitest para frontend/services, testes da Edge Function, pgTAP para contratos e historico quando necessario, `npm run build`, validacao manual no navegador para download sem preview e leitura visual do PDF.

**Target Platform**: Aplicacao web Vite/React com backend Supabase cloud/local, acessada em navegadores desktop e mobile.

**Project Type**: Web application com frontend React e backend Supabase RPC-first + serverless edge rendering.

**Performance Goals**: Download de PDF e CSV iniciado sem troca de contexto e com resposta percebida como imediata para volumes operacionais comuns ja aceitos pela feature 008; renderizacao do PDF permanece dentro do envelope atual de exportacao. Meta quantificada: download deve iniciar em ate 5 segundos apos clique para volumes de ate 500 linhas de detalhes.

**Font Bundle Tradeoff**: O embed da fonte Noto Sans (subset PT-BR, ~200KB) adiciona overhead ao bundle da edge function. Tradeoff aceito para garantir renderizacao com acentuacao PT-BR completa. O impacto no cold-start sera monitorado; se exceder limites aceitaveis, a estrategia de subset pode ser refinada.

**Constraints**: Nao introduzir preview de PDF no fluxo normal; nao rebaixar seguranca de bucket privado; preservar historico e validade ja definidos; manter `Personalizado` fora do escopo; diferenciar explicitamente documento executivo de exportacao tabular.

**Scale/Scope**: Quatro categorias de relatorio (`Financeiro`, `DRE`, `Clientes`, `Projetos`), um fluxo de exportacao imediata e um fluxo de re-download via historico, com impacto concentrado em uma pagina frontend, um service, uma edge function e contratos existentes da feature 008.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Spec-driven delivery**: PASS. A feature possui spec ativa, checklist e delimitacao clara de escopo.
- **RPC-first / backend authorization**: PASS. O plano mantem autorizacao e historico no backend; o frontend apenas inicia geracao/download e controla UX.
- **RBAC by named capabilities**: PASS. Nenhuma ampliacao de permissao; o comportamento enterprise se apoia no contrato atual de `relatorios.exportar`.
- **No mock success**: PASS. O plano exige artefato real para PDF e CSV, com download verdadeiro e estados de historico coerentes.
- **Auditability/documentation**: PASS. O plano cria pesquisa, modelo, contratos, quickstart e memoria local da decisao.
- **Supabase security**: PASS. Nenhuma abertura de Storage publico, nenhuma exposicao de service role e nenhuma URL permanente.

**Re-check after Phase 1 design**: PASS. Os artefatos de pesquisa, contratos e validacao mantem o fluxo autenticado, o bucket privado e a diferenciacao entre documento executivo e exportacao operacional.

## Project Structure

### Documentation (this feature)

```text
specs/011-padrao-enterprise-relatorios/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── pdf-executivo.md
│   ├── download-sem-preview.md
│   ├── exportacao-tabular.md
│   ├── historico-e-validade.md
│   └── rotulos-negocio.md
└── tasks.md
```

### Source Code (repository root)

```text
src/
├── lib/
│   └── download.ts
├── pages/
│   └── RelatoriosPage.tsx
├── services/
│   └── relatorios.service.ts
└── types/
    └── relatorios.ts

supabase/
├── functions/
│   └── relatorios-exportacao/
│       ├── index.ts
│       ├── payload.ts
│       └── renderers.ts
├── migrations/
└── tests/
```

**Structure Decision**: Reaproveitar a arquitetura da feature 008. O frontend passa a controlar download sem preview e nomenclatura/estado da UX; a Edge Function passa a controlar layout executivo do PDF, fontes, mapeamento de rotulos e serializacao tabular revisada; o schema atual e reutilizado sem abrir um novo subsistema.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Embutir fonte TrueType no renderer PDF | Necessario para suportar PT-BR completo e manter aparencia consistente no documento executivo | Permanecer com fontes padrao do `pdf-lib` nao resolve o padrao visual e conflita com a spec atual da feature |
| Download por bytes/blob no navegador | Necessario para impedir preview nativo de PDF sem abrir bucket publico | Navegar diretamente para a signed URL deixa o browser decidir entre preview e download |

## Phase 0 Output

Pesquisa registrada em [research.md](./research.md), cobrindo estrategia de download sem preview, forma de padronizacao do PDF executivo, correcoes para exportacao tabular, comportamento de historico expirado e delimitacao do que muda ou nao na feature 008.

## Phase 1 Output

- Modelo operacional: [data-model.md](./data-model.md)
- Contrato do PDF executivo: [contracts/pdf-executivo.md](./contracts/pdf-executivo.md)
- Contrato de download sem preview: [contracts/download-sem-preview.md](./contracts/download-sem-preview.md)
- Contrato da exportacao tabular: [contracts/exportacao-tabular.md](./contracts/exportacao-tabular.md)
- Contrato de historico e validade: [contracts/historico-e-validade.md](./contracts/historico-e-validade.md)
- Guia de validacao: [quickstart.md](./quickstart.md)

## Phase 2 Direction

`/speckit-tasks` deve gerar tarefas executaveis e ordenadas para:

1. Ajustar o fluxo frontend de download para impedir preview de PDF em exportacao imediata e historico.
2. Atualizar `relatorios.service.ts` e `src/lib/download.ts` para diferenciar download executivo de navegacao por URL assinada.
3. Reestruturar os renderers da Edge Function para um template executivo por categoria, com fonte embutida, rotulos de negocio e empty state apropriado.
4. Corrigir a serializacao tabular com BOM UTF-8, headers legiveis e sem nomenclatura enganosa de `Excel/XLSX`.
5. Revisar a UX do historico para status `Expirado`, `Pronto`, `Falhou` e rotulos por formato.
6. Cobrir os fluxos com testes de service/UI, testes do renderer e validacao manual em navegador.
7. Atualizar memoria obrigatoria em `.agents` e `.sauron` e validar build/testes antes da implementacao ser dada como pronta.
