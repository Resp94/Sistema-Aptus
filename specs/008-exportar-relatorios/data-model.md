# Data Model: Exportar Relatorios

**Date**: 2026-07-04

## Existing Entity: `public.exportacoes_relatorios`

Tabela existente usada pela pagina Relatorios para historico. A implementacao deve evoluir a tabela sem quebrar registros legados `Indisponível`.

### Current known fields

- `id uuid`
- `agendamento_id uuid null`
- `tipo text`
- `formato text`
- `arquivo_url text null`
- `status text`
- `criado_por uuid`
- `gerado_em timestamptz null`

### New/changed fields

- `data_inicial date not null`: inicio do periodo solicitado.
- `data_final date not null`: fim do periodo solicitado.
- `arquivo_path text null`: caminho interno do objeto no bucket privado.
- `arquivo_nome text null`: nome amigavel para download.
- `mime_type text null`: `application/pdf` para PDF ou `application/zip` para pacote CSV.
- `tamanho_bytes bigint null`: tamanho do arquivo persistido.
- `hash_sha256 text null`: hash opcional para auditoria/integridade.
- `expira_em timestamptz null`: `gerado_em + interval '12 months'`.
- `erro text null`: mensagem tecnica resumida quando falhar.
- `criado_em timestamptz not null default now()`: data da solicitacao, se ainda nao existir.
- `atualizado_em timestamptz not null default now()`: ultima transicao de estado.

### Compatibility

- `arquivo_url` deve permanecer nullable/deprecated durante a migracao para evitar quebra de UI/tipos legados.
- Novos downloads nao devem depender de `arquivo_url`.
- Registros antigos `Indisponível` continuam listaveis como historico sem download.

## Derived Read Model: `listar_exportacoes_relatorios`

Cada item retornado ao frontend deve conter:

- `id`
- `tipo`
- `formato`
- `formato_entrega`: `PDF` ou `ZIP_CSV`.
- `status`: status armazenado.
- `status_exibicao`: `Pendente`, `Pronto`, `Falhou`, `Expirado` ou `Indisponível`.
- `data_inicial`
- `data_final`
- `arquivo_nome`
- `mime_type`
- `tamanho_bytes`
- `criado_por`
- `criado_por_nome`
- `gerado_em`
- `expira_em`
- `pode_baixar`: boolean computado por status, validade e permissao atual.
- `erro`: mensagem resumida para status `Falhou`.

## Status Lifecycle

```text
Pendente
  ├─ upload concluido + metadados salvos -> Pronto
  └─ erro de dados/geracao/upload -> Falhou

Pronto
  └─ expira_em < now() -> status_exibicao Expirado

Indisponível
  └─ legado/compatibilidade, sem download
```

Rules:

- `Pronto` so pode ser salvo depois que `arquivo_path`, `arquivo_nome`, `mime_type`, `tamanho_bytes`, `gerado_em` e `expira_em` estiverem preenchidos.
- `Falhou` deve preencher `erro` e nao pode expor download.
- `Expirado` nao precisa ser persistido como status; deve ser computado em listagem/download.
- Download deve ser bloqueado se `status_exibicao != 'Pronto'`.

## Entity: Report File

Representa o objeto salvo no Storage.

Fields:

- `bucket`: `relatorios-exportados`
- `path`: `<tipo>/<yyyy>/<exportacao_id>/<arquivo_nome>`
- `filename`: `relatorio-<tipo>-<data_inicial>-<data_final>-<exportacao_id-curto>.<pdf|zip>`
- `mime_type`: `application/pdf` ou `application/zip`
- `valid_until`: valor de `expira_em`
- `owner`: `criado_por`

Rules:

- Objetos nunca sao publicos.
- Signed URLs sao gerados sob demanda e devem ter expiracao curta.
- A validade de negocio e 12 meses; limpeza fisica pos-expiracao pode ser tarefa posterior, desde que download esteja bloqueado.

## Entity: Export Period

Fields:

- `data_inicial date`
- `data_final date`

Validation:

- `data_inicial <= data_final`
- Datas sao inclusivas.
- Periodo de um dia (`data_inicial = data_final`) e permitido.
- O maximo permitido e o intervalo inclusivo de ate 12 meses calendario: `2026-01-01` a `2026-12-31` e permitido; `2026-01-01` a `2027-01-01` e bloqueado.
- Frontend valida antes de chamar a funcao.
- RPC valida novamente para impedir bypass.

Category semantics:

- Financeiro/DRE: periodo filtra movimentacoes financeiras consideradas.
- Clientes/Projetos: snapshot atual dos registros + metricas de atividade dentro do periodo.

## Entity: Report Payload

Estrutura interna retornada pela RPC de preparacao para a Edge Function.

Fields:

- `exportacao_id uuid`
- `tipo text`
- `formato text`
- `periodo`
- `solicitante`
- `resumo jsonb`
- `detalhes jsonb`
- `mensagem_sem_dados text null`

Rules:

- Sempre deve conter identificacao de categoria e periodo.
- Sempre deve conter resumo executivo, ainda que indique ausencia de dados.
- Sempre deve conter detalhes; se nao houver registros, detalhes pode ser lista vazia acompanhada de mensagem clara.
- O payload de exportacao nao pode reutilizar apenas a previa da tela como fonte completa.

### Category Payload Requirements

**Financeiro**

- `resumo`: receitas, despesas, saldo, quantidade de lancamentos, periodo.
- `detalhes`: linhas de lancamentos do periodo com data, tipo, natureza/status, categoria, descricao, cliente/projeto quando aplicavel e valor.

**DRE**

- `resumo`: faturamento bruto, deducoes, custos operacionais, resultado liquido, periodo.
- `detalhes`: linhas/classificacoes dos lancamentos do periodo que compoem cada grupo da DRE.

**Clientes**

- `resumo`: total de clientes, ativos, inativos, metricas de atividade no periodo.
- `detalhes`: snapshot atual por cliente com identificacao, empresa/contato, status, tipo, data de cadastro/atualizacao e metricas de atividade do periodo quando existirem.

**Projetos**

- `resumo`: total de projetos por status e metricas de atividade no periodo.
- `detalhes`: snapshot atual por projeto com identificacao, cliente, status, periodo planejado/real, responsavel quando existir, progresso/valor quando disponivel e metricas de atividade do periodo.

## Entity: Exportable Category Policy

Fonte canonica:

- `listar_categorias_relatorios` continua determinando categorias visiveis para leitura/preview.
- A exportacao deve implementar helper/RPC derivado da mesma matriz, por exemplo `categoria_relatorio_exportavel(p_tipo text, p_perfil text)`, usado por `iniciar_exportacao_relatorio` e `autorizar_download_exportacao_relatorio`.

Matrix:

| Persona | Categorias exportaveis |
|---------|------------------------|
| Administrador | Financeiro, DRE, Clientes, Projetos |
| Financeiro | Financeiro, DRE |
| Projetos | Projetos |
| Visualizador | Nenhuma |
| Comercial | Nenhuma |
| Tecnico | Nenhuma |

`Personalizado` nao e exportavel no escopo 008.

## Observability Model

Cada geracao/download deve produzir rastreabilidade minima:

- `exportacao_id`
- `usuario_id`
- `tipo`
- `formato`
- `data_inicial`
- `data_final`
- `status`
- `duracao_ms`
- `tamanho_bytes`, quando houver arquivo
- `erro` sanitizado, quando falhar

Se houver mecanismo de auditoria existente, registrar eventos de geracao concluida, falha de geracao e download autorizado.

## Indexes

Recommended indexes:

- `exportacoes_relatorios (criado_por, gerado_em desc nulls last, criado_em desc)`
- `exportacoes_relatorios (tipo, gerado_em desc nulls last)`
- `exportacoes_relatorios (status)`
- `exportacoes_relatorios (expira_em)`

## RLS and Access Rules

- Direct table access from frontend should not be the primary contract.
- Reads should happen through `listar_exportacoes_relatorios`.
- Mutations should happen through RPCs called by the Edge Function.
- Admin can list/download all valid exports.
- Financeiro and Projetos can list/download only exports where `criado_por = auth.uid()`.
- All export/download flows require `tem_capacidade('relatorios.exportar')`.
- Visualizador can read allowed Relatorios data but cannot generate or download report files.
