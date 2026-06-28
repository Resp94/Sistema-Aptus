# Quickstart: Validacao da Feature 005

## Pre-requisitos

1. Docker Desktop ativo.
2. Supabase CLI acessivel via `npx supabase`.
3. `.env.local` com `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` e variaveis ja usadas pelas features anteriores.

## Setup local

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
