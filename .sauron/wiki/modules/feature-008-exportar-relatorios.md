# Feature 008 / 011 — Exportação de Relatórios e Padrão Enterprise

## Contexto Geral

A funcionalidade de exportação de relatórios da Aptus foi concebida sob a **Feature 008** para resolver a necessidade de extrair relatórios completos (PDF e CSV) diretamente da interface do sistema.

Posteriormente, a **Feature 011** estendeu o escopo para elevar o PDF gerado ao patamar de documento executivo ("Padrão Enterprise"), ajustando a formatação e os templates por categoria, e alterando o fluxo de download local do frontend para ocorrer direto em disco (anexo), sem interrupções de navegação ou previews no browser.

---

## Detalhes da Arquitetura

O subsistema de exportação de relatórios é fundado em três componentes:

1. **Camada de Banco de Dados**:
   - Tabela `exportacoes_relatorios` que gerencia o ciclo de vida dos arquivos (`Agendado`, `Processando`, `Pronto`, `Falhou`).
   - Retenção automática implícita: Arquivos expiram em 12 meses. O status `Expirado` é computado dinamicamente na consulta do histórico (`expira_em < now()`), bloqueando downloads de forma segura.
   - Helpers no Postgres para validação de períodos limite (máximo de 12 meses por exportação) e elegibilidade de categorias com base nas capacidades de permissão RBAC do usuário.

2. **Supabase Edge Function (`relatorios-exportacao`)**:
   - Centraliza a orquestração de geração e controle de links.
   - Utiliza a biblioteca `pdf-lib` combinada com as fontes `NotoSans-Regular` e `NotoSans-Bold` embutidas em seus assets locais para compor as grades executivas em formato PDF.
   - Utiliza `fflate` para compactar saídas tabulares multi-arquivo em arquivos `.zip` contendo os planilhas `.csv` codificadas com UTF-8 BOM.
   - Retorna Signed URLs com vida útil restrita de 600 segundos (10 minutos) que apontam para o bucket privado `relatorios-exportados`.

3. **Interface do Usuário (Frontend React)**:
   - Um modal de exportação integrado na página `/relatorios` permite a seleção de categorias válidas para o perfil do usuário, intervalo de datas (padrão do início do mês atual até hoje) e formato de saída.
   - Histórico de exportações com badges de formatos: **Documento Executivo (PDF)** com destaque em azul e **Exportação Operacional (CSV)** com destaque em cinza.
   - Tratamento de controle de acesso desabilitando o botão de geração se o usuário carece da capacidade `relatorios.exportar`.

---

## Fluxo e Regras de Negócio Estabelecidas na Feature 011

### Download Direct-to-Disk (Sem Preview)
O download de qualquer relatório (seja imediato ou a partir do histórico) ocorre através de requisição `fetch` assíncrona da URL assinada. O payload é recebido na memória do navegador como um `Blob` binário, transferido para um Object URL e descarregado instantaneamente. Após a conclusão do salvamento, a Object URL é imediatamente revogada para liberação de memória.

### Regras de Negócio e Rótulos PT-BR
Nenhum termo técnico derivado do banco de dados (ex: chaves como `label`, `valor`, `atendimentos_no_periodo`) é vazado nas exportações em PDF:
- **DRE / Financeiro**: Renderização com totais e subtotais formatados em Reais (R$).
- **Clientes / Projetos**: Contêm resumos macro estruturados e tabelas secundárias com títulos amigáveis ("Horas Apontadas no Período", "Progresso", etc.).
- **Mensagem de Dados Vazios**: Caso não haja movimentações para o filtro selecionado, o PDF exibe na área de detalhes a mensagem executiva padrão:
  > "Não há dados disponíveis para o período selecionado. Selecione um intervalo diferente ou entre em contato com o administrador."

---

## Arquivos e Artefatos Relevantes
- **Mapeamento de Banco de Dados**: `supabase/migrations/20260704235640_exportar_relatorios.sql`
- **Lógica do Renderizador**: `supabase/functions/relatorios-exportacao/renderers.ts`
- **Componente Visual**: `src/pages/RelatoriosPage.tsx`
- **Notas de Memória do Projeto**:
  - `.agents/project-memory/008-exportar-relatorios.md`
  - `.agents/project-memory/011-padrao-enterprise-relatorios.md`

---

## Estado da Funcionalidade
**Implementada, publicada e validada**. Em 2026-07-09, a Edge Function `relatorios-exportacao` foi publicada no projeto Supabase `lpwnaxlczwntylcmgotm` até a versão `5`. A validação de produção confirmou chamada real `POST 200` via Supabase MCP e geração de PDF executivo via Chrome DevTools MCP no usuário `Jonathas` / `Administrador`.

O arquivo final validado foi `relatorio-financeiro-2026-07-01-2026-07-09 (2).pdf`, com título `Relatório Financeiro`, datas PT-BR, valores `R$`, ausência de `label`/`valor` e empty state completo com quebra de linha sem corte lateral. A suíte focada de frontend passou com 23/23 testes e `npm run build` concluiu com sucesso.
