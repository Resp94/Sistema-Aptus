# Contract: PDF Executivo

## Objective

Definir o comportamento esperado do PDF como documento executivo oficial dos relatorios exportados.

## Required Sections

Cada PDF deve conter, nesta ordem logica:

1. Identificacao do relatorio
2. Metadados do periodo e solicitante
3. Resumo executivo
4. Detalhes do periodo
5. Mensagem de empty state quando aplicavel

## Visual Hierarchy (Measurable Criteria)

| Elemento | Fonte | Tamanho | Peso |
|----------|-------|---------|------|
| Titulo do relatorio | Noto Sans | 18pt | Bold |
| Subtitulos de secao | Noto Sans | 14pt | Bold |
| Corpo / linhas de dados | Noto Sans | 11pt | Regular |
| Metadados (periodo, solicitante, etc.) | Noto Sans | 11pt | Regular |

- Margens: 50pt em todos os lados (A4: 595.28 x 841.89 pt).
- Espacamento entre linhas: 16pt (`LINE_HEIGHT`).
- Cores: texto preto `rgb(0, 0, 0)` sobre fundo branco.
- Estes criterios aplicam-se identicamente a Financeiro, DRE, Clientes e Projetos.

## Presentation Rules

- Todos os textos visiveis devem estar em PT-BR correto com acentuacao completa.
- Titulos e subtitulos devem usar nomenclatura de negocio.
- O resumo executivo deve apresentar rotulo e valor final, nunca nomes de campo internos. Regra de renderizacao do resumo: usar o VALOR do campo `label` como rotulo de exibicao e o VALOR do campo `valor` como dado formatado — NUNCA expor as chaves `label` ou `valor` como texto.
- Os detalhes devem usar os rotulos de negocio definidos em [rotulos-negocio.md](./rotulos-negocio.md) como titulos de coluna.
- O documento deve manter hierarquia visual coerente entre Financeiro, DRE, Clientes e Projetos.

## Category Expectations

- **Financeiro**: resumo com entradas, saidas, saldo e volume; detalhes de movimentacoes.
- **DRE**: resumo com indicadores executivos de resultado; detalhes agrupados por natureza/linha do periodo.
- **Clientes**: resumo de base ativa e atividade do periodo; detalhes de clientes e sinais operacionais relevantes.
- **Projetos**: resumo de carteira e andamento; detalhes de projetos e atividade associada.

## Empty State

Quando nao houver dados suficientes:

- o documento continua valido;
- a secao de resumo permanece legivel;
- a secao de detalhes mostra a seguinte mensagem de negocio:
  > "Nao ha dados disponiveis para o periodo selecionado. Selecione um intervalo diferente ou entre em contato com o administrador."
- nenhum header tecnico ou chave interna deve aparecer como fallback.
