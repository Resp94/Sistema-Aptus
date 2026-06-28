# Contract: UI Routes

Cada rota abaixo substitui `ModuloNaoMigrado`, usa `AppShell`, respeita `RequirePermissao` e deriva layout de `reference/legacy-html/`.

| Rota | Pagina React | Modulo RBAC | Referencia HTML |
|---|---|---|---|
| `/fluxo-caixa` | `FluxoCaixaPage` | `fluxo-caixa` | `reference/legacy-html/fluxo-caixa.html` |
| `/contas-pagar` | `ContasPagarPage` | `contas-pagar` | `reference/legacy-html/contas-pagar.html` |
| `/contas-receber` | `ContasReceberPage` | `contas-receber` | `reference/legacy-html/contas-receber.html` |
| `/propostas` | `PropostasPage` | `propostas` | `reference/legacy-html/propostas.html` |
| `/contratos` | `ContratosPage` | `contratos` | `reference/legacy-html/contratos.html` |
| `/cobrancas` | `CobrancasPage` | `cobrancas` | `reference/legacy-html/cobrancas.html` |
| `/equipe` | `EquipePage` | `equipe` | `reference/legacy-html/equipe.html` |
| `/relatorios` | `RelatoriosPage` | `relatorios` | `reference/legacy-html/relatorios.html` |
| `/configuracoes` | `ConfiguracoesPage` | `configuracoes` | `reference/legacy-html/configuracoes.html` |

## Estados obrigatorios

- Carregando: skeleton/spinner coerente com as paginas ja migradas.
- Vazio por tipo de secao: cards numericos exibem zero e "Sem dados no periodo"; tabelas/listas exibem `empty-state`; graficos exibem area vazia com mensagem; previews de relatorio orientam ajustar filtros.
- Erro: mensagem recuperavel com acao de tentar novamente.
- Sem escrita: acoes de escrita nao renderizam.
- Integracao ausente: comando indisponivel ou retorno "pendente de integracao".
- Filtro sem resultado: tabelas/listas usam "Nenhum resultado encontrado"; graficos/cards refletem apenas o recorte filtrado; previews de relatorio permanecem vazios com filtros editaveis.

## Requisitos responsivos e acessiveis

- Cada rota deve funcionar em desktop e mobile sem sobreposicao de texto/controles.
- Tabelas podem virar scroll horizontal ou lista compacta em telas estreitas.
- Kanban/equipe devem permitir leitura em colunas compactas ou empilhadas.
- Controles interativos devem ter nome acessivel, foco visivel e nao depender apenas de cor para comunicar estado.

## Validacao por perfil

- Administrador: ve todas as rotas e acoes permitidas.
- Financeiro: financeiro, cobrancas e relatorios financeiros.
- Comercial: clientes, propostas, contratos, cobrancas.
- Projetos: projetos, equipe, relatorios operacionais.
- Tecnico: projetos, equipe limitada e configuracoes proprias.
- Visualizador: relatorios/dashboards permitidos somente leitura.
