# Contract: Download Sem Preview

## Objective

Garantir que relatorios PDF sejam entregues por download direto sem abrir preview nativo do navegador.

## Covered Flows

- Geracao imediata de relatorio na pagina `Relatorios`
- Download de item pronto pelo historico de exportacoes

## Behavior

- O usuario inicia a acao de baixar.
- O sistema obtem o artefato autorizado.
- O arquivo e entregue como download local com nome e tipo corretos.
- A pagina atual permanece utilizavel durante e apos o inicio do download.

## "Utilizavel" — Criterios Mensuraveis

A pagina e considerada "utilizavel" quando, apos o inicio do download:
- Nao ha bloqueio de UI (sem overlay, spinner global ou modal persistente).
- Nao ha navegacao forcada para outra rota ou aba.
- O toast de confirmacao ("Exportacao gerada com sucesso!") desaparece automaticamente em 3 segundos.
- O usuario pode continuar navegando, selecionar outra categoria ou abrir outro modal imediatamente.

## File Naming Convention

- **PDF executivo**: `relatorio-{categoria-slug}-{data_inicial}-{data_final}.pdf`
- **CSV operacional**: `exportacao-{categoria-slug}-{data_inicial}-{data_final}.zip`
- Prefixos distintos (`relatorio-` vs `exportacao-`) refletem a diferenciacao entre documento executivo e exportacao operacional.
- Categoria-slug: nome da categoria em lowercase, sem acentos, espacos substituidos por hifen.
- Datas no formato `YYYY-MM-DD`.

## Non-Goals

- Nao abrir o PDF em nova aba.
- Nao substituir a rota atual por URL assinada.
- Nao depender do comportamento padrao do navegador para decidir entre preview e download.

## Failure Handling

- Se o item estiver expirado, o download nao deve iniciar.
- Se a exportacao falhar, o usuario deve receber estado e mensagem apropriados.
- Se houver erro temporario de entrega, o sistema deve preservar a pagina e informar a falha sem navegar para fora do contexto atual.
