# Feature 011 — Padrão Enterprise Relatórios

## Objetivo

Evoluir a exportação de relatórios da Feature 008 para um padrão enterprise, focando na experiência de consumo executivo dos relatórios em PDF, no download local síncrono e na separação clara entre artefatos de negócio e técnicos.

---

## Decisões Aprovadas e Implementadas

- **Download Direto Sem Preview**: A visualização padrão integrada no navegador (preview) de PDFs foi eliminada no fluxo de download. Os arquivos são transferidos diretamente como anexos binários via fetch de URLs assinadas e salvamento local imediato na máquina do usuário.
- **Formatação de Negócio (PT-BR)**: Todos os cabeçalhos e valores nos PDFs gerados foram adaptados ao formato brasileiro (ex: R$ 1.500,00, 100,50h, 09/07/2026). Nomes de chaves técnicas internas (como `label` ou `valor`) foram completamente omitidos.
- **Templates Executivos Dedicados**: A Edge Function agora renderiza layouts distintos para cada categoria:
  - **Financeiro / DRE**: Focados em DFC (Demonstrativo de Fluxo de Caixa) e DRE (Demonstrativo de Resultados do Exercício) estruturados com totais consolidados de Receitas, Despesas e Saldo/Resultado Líquido.
  - **Clientes**: Focado em dados cadastrais consolidados com métricas de atendimentos no período.
  - **Projetos**: Traz o progresso de tarefas concluídas, orçamento consumido e horas de atividades acumuladas.
- **Segurança de Acesso e RBAC**: O frontend desabilita e exibe tooltips informativos para o botão "Exportar Relatório" se o perfil ativo do usuário não contiver a capacidade `relatorios.exportar` no banco de dados.
- **Empacotamento Operacional (CSV/ZIP)**: Exportações em formato CSV continuam disponíveis para análise tabular. Quando o relatório possui múltiplos subconjuntos de dados (resumos e detalhes), eles são empacotados em um arquivo `.zip` contendo os respectivos arquivos CSV com codificação UTF-8 BOM para preservação de caracteres acentuados.
- **Publicação de Edge Function em Produção**: Em 2026-07-09, `relatorios-exportacao` foi publicada no projeto Supabase `lpwnaxlczwntylcmgotm` até a versão `5`, incluindo o módulo `font-assets.ts` para empacotar as fontes Noto Sans no grafo de deploy da Edge Function.

---

## Detalhes Técnicos da Implementação

### 1. Fluxo de Download Direct-to-Disk (US1)
No frontend, a gravação de arquivos é efetuada no arquivo [download.ts](file:///C:/Users/respl/OneDrive/Aptus%20Flow/sistema-aptus/src/lib/download.ts) através do seguinte fluxo:
1. Obtenção do Signed URL com expiração de 600 segundos gerada pelo Storage privado da Supabase.
2. Chamada assíncrona `fetch` à URL assinada com cabeçalhos CORS corretos.
3. Conversão da resposta HTTP para um objeto binário do tipo `Blob`.
4. Criação temporária de Object URL (`URL.createObjectURL(blob)`).
5. Criação dinâmica de um link HTML `<a>` com propriedade `download` preenchida com a nomenclatura normalizada do arquivo.
6. Simulação do clique (`link.click()`) e subsequente remoção do elemento e invalidação do Object URL (`URL.revokeObjectURL`).

### 2. Layouts Executivos Category-Aware (US2)
No arquivo [renderers.ts](file:///C:/Users/respl/OneDrive/Aptus%20Flow/sistema-aptus/supabase/functions/relatorios-exportacao/renderers.ts), a biblioteca `pdf-lib` desenha o relatório através de quatro seções principais:
1. **Cabeçalho de Identificação**: título executivo do relatório, por exemplo `Relatório Financeiro`.
2. **Metadados do Relatório**: Categoria, período do filtro, nome do solicitante e timestamp de exportação.
3. **Resumo Executivo**: Caixa destacada contendo os totais agregados e indicadores-chave em texto corrido com fonte `NotoSans-Bold`.
4. **Dados Detalhados**: Grade tabular estruturada com rótulos de negócio definidos em `LABEL_MAP`. Caso não existam dados, exibe-se a mensagem padronizada no espaço de detalhes:
   > "Não há dados disponíveis para o período selecionado. Selecione um intervalo diferente ou entre em contato com o administrador."

O renderer quebra linhas longas com base na largura real da fonte (`widthOfTextAtSize`) para impedir corte lateral de mensagens e linhas extensas.

### 3. Nomenclatura e Separação de Formatos (US3)
- O PDF é rotulado como **Documento Executivo** (Badge Azul no Histórico) e seu arquivo segue a máscara `relatorio-[categoria-slug]-[data_inicial]-[data_final].pdf`.
- O CSV/ZIP é rotulado como **Exportação Operacional** (Badge Cinza no Histórico) e seu arquivo segue a máscara `exportacao-[categoria-slug]-[data_inicial]-[data_final].zip` (ou `.csv`).
- A indicação de recurso `Experimental` ou `Beta` foi removida da folha de PDF gerada, aparecendo agora unicamente no modal de seleção del frontend.

---

## Arquivos Relacionados
- `src/lib/download.ts`
- `src/pages/RelatoriosPage.tsx`
- `src/pages/RelatoriosPage.css`
- `supabase/functions/relatorios-exportacao/renderers.ts`
- `supabase/functions/relatorios-exportacao/index.ts`

---

## Estado de Validação
**Implementada, publicada e validada em produção**. Evidências de 2026-07-09:

- `npm test -- src/lib/download.test.ts src/services/relatorios.service.test.ts src/pages/RelatoriosPage.test.tsx`: 23/23 testes passando.
- `npm run build`: sucesso, com aviso não bloqueante de chunk Vite acima de 500 kB.
- Supabase MCP confirmou `relatorios-exportacao` ativa na versão `5`.
- Supabase MCP confirmou chamada real `POST 200` no deployment da versão `5`.
- Chrome DevTools MCP validou o fluxo real `/relatorios` com usuário `Jonathas` / `Administrador`.
- PDF final validado visualmente: `relatorio-financeiro-2026-07-01-2026-07-09 (2).pdf`, com título correto, acentuação, valores monetários, ausência de `label`/`valor` e empty state completo sem corte lateral.

Observação: `deno test` local não foi executado nesta sessão porque o binário Deno não estava acessível pelo shell.
