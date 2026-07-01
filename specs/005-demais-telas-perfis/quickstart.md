# Quickstart: Validacao da Feature 005

## Pre-requisitos

1. Docker Desktop ativo.
2. Supabase CLI acessivel via `npx supabase`.
3. `.env.local` com `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` e variaveis ja usadas pelas features anteriores.

## Baseline e Preparacao (Resultados)

- **T001 (npm test)**: Executado com 34 testes no total (33 passando, 1 falha em `src/lib/usuario.test.ts > rotaInicialPorPerfil > Visualizador (default) vai para /dashboard` onde retornou `/clientes`).
- **T002 (npm run build)**: Executado com sucesso. O compilador TypeScript (`tsc`) e o empacotador (`vite build`) geraram com sucesso os ativos de distribuição estática na pasta `dist/` (assets de js de 510 kB e css de 39 kB).
- **T003 (npx supabase status)**: Local Supabase está ativo e saudável. As portas locais mapeadas são: API no 54321, DB no 54322, Studio no 54323, Inbucket/Mailpit no 54324.
- **T004 (Review Financeiro HTML)**:
  - `fluxo-caixa.html`: Cartões de resumo (`fc-summary`), gráfico de colunas duplas (`chart-dual`) receita/despesa, barras de progresso de previsão de 30 dias e tabela de movimentações com busca local.
  - `contas-pagar.html`: Cartões de métricas (`cp-summary`), próximos vencimentos com destaque para atrasados, despesas por categoria em formato de barra de progresso, tabela principal de contas a pagar com botão de pagar (abre modal de confirmação).
  - `contas-receber.html`: Resumo financeiro (`cr-summary`), próximos recebimentos com sinalizadores de vencido/pendente, resumo por cliente e tabela principal de faturas com modal para emissão e cobrança.
- **T005 (Review Comercial HTML)**:
  - `propostas.html`: Cartões de resumo (`proposal-summary`), filtro por busca e status, tabela de propostas e painel de detalhes inferior expansível (`proposal-detail-panel`), além do modal de criação de proposta.
  - `contratos.html`: Métricas de contratos ativos e novos, filtro avançado, tabela de contratos com ações de renovação/rescisão e modal de upload/renovação de documentos.
  - `cobrancas.html`: Resumos de cobranças, painel principal de envio de lembretes manuais e automáticos, tabela com busca, modal para emissão de boleto simulado.
- **T006 (Review Operacional/Config HTML)**:
  - `equipe.html`: Visão de alocações e capacidade (`allocation-grid`), tabela de membros da equipe com detalhes de custo/hora, modal de atribuição de tarefas e novos membros.
  - `relatorios.html`: Filtros por categoria/perfil, visualizador de preview dinâmico de relatórios, histórico de exportações com botões de download e agendamento recorrente.
  - `configuracoes.html`: Abas de controle (Perfil, Empresa, Integrações, Usuários/RBAC, Preferências), campos de formulário e modal de edição rápida de usuário.


```powershell
npm install
npm run supabase:reset
npm test
npm run build
npm run dev
```

## Cenarios de validacao

### C1 - Rotas substituem placeholder

Para cada rota em [contracts/ui-routes.md](./contracts/ui-routes.md), acessar com um perfil autorizado.

Resultado esperado:
- A rota nao renderiza `ModuloNaoMigrado`.
- Layout segue o HTML correspondente em `reference/legacy-html/`.
- Estados de carregamento, vazio e erro existem.

### C2 - Financeiro

Login como perfil Financeiro.

Validar:
- `/fluxo-caixa` mostra metricas, grafico e tabela reais.
- `/contas-pagar` lista despesas `a_pagar` e permite registrar pagamento quando autorizado.
- `/contas-receber` lista receitas `a_receber`.
- Status vencido e derivado por data, nao por mock.

### C3 - Comercial

Login como perfil Comercial.

Validar:
- `/propostas` cria e atualiza proposta real.
- `/contratos` cria contrato vinculado a cliente/proposta.
- `/cobrancas` mostra cobrancas reais e nao simula boleto/lembrete quando integracao estiver ausente.

### C4 - Equipe e Tecnico

Login como Projetos e depois como Tecnico.

Validar:
- Projetos ve equipe completa, capacidade e alocacoes.
- Tecnico ve apenas escopo permitido.
- Tecnico nao ve custo/hora nem configuracoes globais.

### C5 - Configuracoes

Login como Administrador.

Validar:
- Abas globais carregam dados reais.
- Alteracao de perfil atualiza permissoes e navegacao.
- Alteracao sensivel gera auditoria.

Login como Tecnico.

Validar:
- Configuracoes mostra apenas dados proprios/preferencias permitidas.

### C6 - Relatorios e Visualizador

Login como Visualizador.

Validar:
- `/relatorios` exibe apenas categorias permitidas.
- Nenhuma acao de escrita aparece.
- Exportacao indisponivel/pendente nao retorna sucesso falso.

### C7 - RBAC e acesso direto

Para cada perfil, tentar acessar uma rota fora da permissao.

Resultado esperado:
- Guard redireciona para rota permitida.
- Nenhum dado da rota bloqueada e carregado ou exibido.

### C8 - Ausencia de mock

Buscar no codigo das paginas em escopo por listas/valores fixos de dominio.

Resultado esperado:
- Valores exibidos nas tabelas, cards e graficos vem de RPCs ou de estados vazios.
- Textos estruturais de UI podem ser fixos; dados de dominio nao.

### C9 - Seeds por perfil e rota

Para cada perfil tecnico, validar que existe ao menos um registro real para as rotas indicadas na matriz da spec.

Resultado esperado:
- Administrador cobre todas as rotas em escopo.
- Financeiro possui dados em fluxo, contas, cobrancas e relatorios financeiros.
- Comercial possui propostas, contratos e cobrancas vinculadas a clientes.
- Projetos possui equipe/alocacoes.
- Tecnico possui projetos/equipe/configuracoes proprias limitadas.
- Visualizador possui relatorios permitidos em leitura.

### C10 - Integracoes ausentes e recovery

Executar acoes sem integracao configurada: enviar proposta, emitir boleto, enviar lembrete, anexar documento e solicitar exportacao.

Resultado esperado:
- Cada acao retorna estado documentado (`Indisponivel`, `Pendente de integracao` ou equivalente).
- Nenhum envio, boleto, arquivo ou URL falso e criado.
- Falhas de escrita preservam dados anteriores e permitem nova tentativa sem duplicidade.

### C11 - Shared ownership de cobrancas

Validar cobrancas com Comercial, Financeiro e Administrador.

Resultado esperado:
- Comercial ve/acompanhha cobrancas e lembretes, mas nao executa pagamento/conciliacao financeira sem permissao.
- Financeiro registra pagamento/conciliacao e controla efeitos em `lancamentos`.
- Administrador cobre ambos os conjuntos.

### C12 - Acessibilidade, responsividade e estados por secao

Em desktop e mobile, revisar todas as rotas em escopo.

Resultado esperado:
- Controles tem foco visivel e nome acessivel.
- Layout nao sobrepoe textos/controles.
- Cards, tabelas/listas, graficos e previews tem estados vazios e filtros sem resultado proprios.
- `Vencido` aparece de forma consistente como estado derivado.

## Gates finais

```powershell
npm test
npm run build
npm run supabase:reset
```

Todos devem passar antes de considerar a feature pronta para entrega.
