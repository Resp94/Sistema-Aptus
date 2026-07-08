# Contract: Exportacao Tabular

## Objective

Definir o papel e o comportamento das exportacoes tabulares dentro do escopo enterprise.

## Product Positioning

- Exportacao tabular e um artefato operacional.
- Ela nao substitui o PDF executivo.
- A nomenclatura do produto deve deixar essa distincao explicita.
- Na UI: PDF rotulado como "Documento Executivo", CSV/ZIP rotulado como "Exportacao Operacional (.zip)".
- No historico: badge "PDF" (azul) ou "CSV" (cinza) ao lado do nome do arquivo.

## Required Rules

- O formato deve usar encoding UTF-8 com BOM (`\uFEFF`) para deteccao automatica em ferramentas de escritorio.
- Headers devem ser compreensiveis por usuarios de negocio, usando os MESMOS mapas de traducao definidos em [rotulos-negocio.md](./rotulos-negocio.md) — nao ha mapa separado para CSV.
- Mesmo sem dados detalhados, o arquivo precisa manter estrutura legivel:
  - Header padrao: `Observacao` (substitui o fallback tecnico `mensagem`).
  - Conteudo da celula: mensagem de empty state padronizada (mesma do PDF).
- O nome do arquivo e o rotulo no historico precisam refletir o tipo real de artefato entregue:
  - Nome: `exportacao-{categoria-slug}-{data_inicial}-{data_final}.zip` (prefixo `exportacao-`, nao `relatorio-`).

## Out of Scope

- Nao ha obrigacao de layout executivo em formato tabular.
- Nao ha requisito de planilha nativa `XLSX` nesta feature.
