# Quickstart: Validacao do Padrao Enterprise de Relatorios

## Prerequisites

### 1. Requisitos de Ambiente e Permissões (RBAC)
- **Capacidades do Usuário**:
  - Para testar o fluxo completo de exportação: O usuário ativo deve possuir a capacidade nomeada `relatorios.exportar`.
  - Para testar a restrição de permissão (Edge Case): É necessário um usuário secundário ativo ou alteração temporária do perfil para remover a capacidade `relatorios.exportar`.
- **Baseline de Banco de Dados**:
  - Funções RPC da Feature 008 criadas e estáveis (`public.montar_payload_relatorio_financeiro`, `public.montar_payload_relatorio_dre`, `public.montar_payload_relatorio_clientes`, `public.montar_payload_relatorio_projetos`).
  - Estrutura da tabela de histórico de exportação criada com suporte a metadados de expiração e tipo de formato.

### 2. Infraestrutura e Dependências Locais
- **Supabase Local**: Instância local do Supabase ativa ou mocks adequados configurados para simular a resposta da Edge Function `relatorios-exportacao`.
- **Dependências Frontend**: `npm install` executado para garantir a presença de bibliotecas de teste (Vitest, React Testing Library).
- **Assets de Fonte**: Arquivos de fonte NotoSans (`NotoSans-Regular.ttf` e `NotoSans-Bold.ttf`) adicionados no diretório `supabase/functions/relatorios-exportacao/assets/` para que a Edge Function possa carregá-los durante a geração do PDF executivo.

---

## Validation Commands

```bash
# Executa todos os testes unitários e de integração locais (Vitest)
npm run test

# Executa especificamente os testes da funcionalidade de relatórios
npx vitest src/lib/download.test.ts src/services/relatorios.service.test.ts src/pages/RelatoriosPage.test.tsx

# Executa testes locais de renderização e rotas do Deno nas Edge Functions (se Deno estiver configurado localmente)
deno test supabase/functions/relatorios-exportacao/

# Validação do build de produção do frontend
npm run build
```

---

## Detailed Browser Verification Steps

### Scenario 1: Download Imediato de PDF sem Preview
1. Faça login com um usuário que tenha a capacidade `relatorios.exportar`.
2. Acesse a página de Relatórios em `/relatorios`.
3. Certifique-se de que o badge ou indicador visual **"Experimental" / "Beta"** está visível na página de relatórios e no modal de exportação.
4. Clique no botão de exportação e selecione a categoria desejada (ex: **Financeiro**).
5. Escolha o formato **PDF (Documento Executivo)** e clique para confirmar.
6. **Passos de verificação no navegador**:
   - O botão do modal deve entrar em estado de loading e ficar desabilitado temporariamente.
   - O navegador deve iniciar o download do arquivo PDF diretamente.
   - **Verificação crítica**: O navegador **NÃO** deve abrir uma nova aba de visualização (preview padrão do navegador) e **NÃO** deve navegar ou atualizar a rota atual (o usuário permanece em `/relatorios`).
   - Um toast de sucesso deve aparecer, durar cerca de 3 segundos e sumir automaticamente.
   - A página de relatórios permanece 100% interativa durante e após o download.

### Scenario 2: Validação Visual do PDF Executivo
1. Abra o arquivo PDF baixado (o nome deve seguir o padrão: `relatorio-financeiro-{data_inicio}-{data_fim}.pdf`).
2. **Passos de verificação visual (Leitura)**:
   - **Layout e Seções**: O documento deve possuir exatamente 5 seções bem delimitadas e em ordem lógica:
     1. Identificação do Relatório (Título em 18pt Bold)
     2. Metadados do período (Datas de início e fim, data de geração, solicitante e validade em PT-BR)
     3. Resumo Executivo (Indicadores e métricas)
     4. Detalhes do Período (Tabelas ou listagens estruturadas)
   - **Acentuação e Fontes**: Todos os textos acentuados e caracteres em português (ex: "Relatório", "Transações", "Média") devem ser renderizados corretamente através da fonte *Noto Sans* embutida.
   - **Nomenclatura de Negócio**: Não deve haver vazamento de chaves técnicas no layout. Por exemplo:
     - Onde havia a chave bruta `nome_contato` no payload, deve exibir "Nome do Contato".
     - Na seção de Resumo, as chaves estruturadas `label` e `valor` **NÃO** devem aparecer na saída. Apenas os valores correspondentes de negócio devem ser impressos como "Rótulo: Valor".
   - **Caso Sem Dados**: Se não houver dados no período selecionado, a seção de Detalhes (seção 4) deve exibir a seguinte mensagem exata:
     > "Não há dados disponíveis para o período selecionado. Selecione um intervalo diferente ou entre em contato com o administrador."
     > E as demais seções (Identificação, Metadados e Resumo) devem se manter intactas.

### Scenario 3: Exportação Tabular Operacional (CSV)
1. No modal de exportação em `/relatorios`, escolha a opção **CSV (Exportação Operacional)**.
2. Confirme e verifique se o arquivo é baixado como um arquivo compactado `.zip` contendo o arquivo `.csv`, com a convenção de nome `exportacao-{categoria-slug}-{data_inicio}-{data_fim}.zip`.
3. Abra o arquivo CSV usando um editor de planilhas (Excel ou similar).
4. **Passos de verificação**:
   - **Encoding**: O arquivo deve estar encodado em UTF-8 com BOM para que caracteres especiais e acentos em português apareçam corretamente por padrão.
   - **Cabeçalhos**: As colunas devem apresentar os rótulos amigáveis traduzidos (ex: "Data da Transação" em vez de `data_transacao`).
   - **Caso Sem Dados**: O arquivo CSV deve conter apenas uma coluna com o cabeçalho `Observacao` e o valor da célula deve ser a mensagem exata: "Não há dados disponíveis para o período selecionado. Selecione um intervalo diferente ou entre em contato com o administrador."

### Scenario 4: Histórico de Itens Expirados
1. Na página `/relatorios`, localize a tabela de histórico de exportações anteriores.
2. Identifique um item cuja validade já expirou (data atual posterior à data de validade do item).
3. **Passos de verificação na UI**:
   - O item deve exibir um indicador ou badge visual com o estado **"Expirado"** em cinza.
   - O botão de download associado a este item deve estar desabilitado para clique.
   - Ao passar o mouse sobre o botão ou badge desabilitado, um tooltip deve ser exibido com o texto exato:
     > "Este relatório expirou em DD/MM/AAAA. Gere um novo para o mesmo período." (Substituindo DD/MM/AAAA pela data de expiração real).

### Scenario 5: Restrição de Permissão (Sem relatorios.exportar)
1. Faça login com um usuário que **NÃO** tenha a capacidade `relatorios.exportar`.
2. Acesse a rota de Relatórios `/relatorios`.
3. **Passos de verificação na UI**:
   - O botão principal de "Exportar Relatório" deve estar visivelmente desabilitado (estilo cinza/desbotado).
   - Ao passar o cursor do mouse sobre o botão desabilitado, um tooltip deve ser exibido com a mensagem exata:
     > "Você não tem permissão para exportar"
   - O usuário ainda pode visualizar os gráficos e tabelas da página (apenas leitura) e baixar relatórios válidos do histórico que já haviam sido gerados, se aplicável.

## Expected Outcomes

- Downloads de PDF são acionados diretamente como `attachment` sem renderização ou preview em abas do navegador.
- Todos os arquivos PDF gerados mantêm consistência tipográfica, layout executivo e tradução total de rótulos (zero vazamento de chaves de API/banco).
- Formato CSV possui BOM UTF-8 e nomenclatura de headers consistentes com o mapa de negócio.
- O histórico reflete corretamente a expiração dos links e restringe downloads antigos expirados.
- Controle de acesso impede a exportação por usuários não autorizados através de tooltip e botões desabilitados.

---

## Validation Log — 2026-07-09

### Ambiente validado

- Projeto Supabase de produção: `lpwnaxlczwntylcmgotm`.
- Edge Function: `relatorios-exportacao`.
- Versão publicada e validada: `5`.
- Navegador validado via Chrome DevTools MCP usando sessão real autenticada como `Jonathas` / `Administrador`.
- Rota validada: `http://127.0.0.1:5173/relatorios`.

### Comandos executados

```bash
npm test -- src/lib/download.test.ts src/services/relatorios.service.test.ts src/pages/RelatoriosPage.test.tsx
npm run build
supabase functions deploy relatorios-exportacao --project-ref lpwnaxlczwntylcmgotm --use-api
```

Resultados:

- Testes focados de frontend: **23/23 passando**.
- Build de produção: **passou** (`tsc -b && vite build`), com aviso não bloqueante de chunk Vite acima de 500 kB.
- Edge Function em produção: **versão 5 ativa** confirmada via Supabase MCP (`list_edge_functions`).
- Chamada real da Edge Function: **POST 200** confirmada via Supabase MCP (`get_logs`) no deployment `..._5`.

### Resultado do browser/manual

- Modal exibe **Documento Executivo (.pdf)** e **Exportação Operacional (.zip)**.
- Histórico exibe registros PDF prontos para o período `01/07/2026 - 09/07/2026`.
- PDF final baixado e aberto no Chrome:
  - arquivo: `C:\Users\respl\Downloads\relatorio-financeiro-2026-07-01-2026-07-09 (2).pdf`;
  - título: `Relatório Financeiro`;
  - datas em PT-BR: `01/07/2026 a 09/07/2026`;
  - resumo sem vazamento de chaves internas `label` / `valor`;
  - valores monetários como `R$ 0,00`;
  - mensagem de empty state completa, acentuada e quebrada em múltiplas linhas sem cortar na margem.

### Limitação conhecida de validação local

O binário `deno` não ficou acessível no shell desta sessão (`CreateProcessAsUserW failed: 5` / comando não executável), então os testes Deno locais da Edge Function não foram executados aqui. A validação da Edge Function foi feita por deploy real, geração real via UI, inspeção visual do PDF e confirmação de logs MCP na versão 5.
