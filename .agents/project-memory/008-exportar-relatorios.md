# Spec 008 - Exportar Relatorios

**Data**: 2026-07-04

## O que foi especificado

Criada a feature Spec Kit `008-exportar-relatorios` para substituir o estado atual de exportacao pendente/indisponivel por exportacao real de relatorios completos em PDF e CSV na pagina Relatorios.

## Decisoes registradas

- Exportacao deve gerar e disponibilizar download imediato.
- O arquivo exportado corresponde apenas a categoria selecionada, nao a um consolidado geral.
- O usuario informa data inicial e data final; por padrao, o modal abre com primeiro dia do mes atual e data atual.
- PDF e CSV fazem parte do escopo.
- O historico deve permitir baixar novamente arquivos anteriores.
- Arquivos gerados tem validade de 12 meses.
- Exportacoes expiradas continuam rastreaveis no historico, mas sem download.
- Visualizador permanece apenas leitura e nao pode exportar.
- Administrador, Financeiro e Projetos podem exportar quando tiverem a capacidade `relatorios.exportar`.
- Comercial, Tecnico e qualquer perfil sem capacidade de exportacao nao podem gerar nem baixar arquivos.

## Clarificacoes da especificacao

- Historico: Administrador ve e baixa exportacoes validas de todos os usuarios; Financeiro e Projetos veem e baixam somente as proprias exportacoes.
- Conteudo completo: cada relatorio exportado contem resumo executivo e linhas detalhadas da categoria.
- Periodo: cada exportacao aceita no maximo 12 meses.
- Semantica por categoria: Financeiro e DRE usam movimentacoes do periodo; Clientes e Projetos usam snapshot atual com metricas de atividade no periodo.
- CSV: quando houver resumo e detalhes, a exportacao CSV entrega um pacote com CSV de resumo e CSV de detalhes.

## Artefatos criados

- `specs/008-exportar-relatorios/spec.md`
- `specs/008-exportar-relatorios/checklists/requirements.md`

## Proxima etapa

Executar `/speckit-plan` para detalhar arquitetura, contratos de dados completos por categoria, persistencia de arquivos, historico, seguranca de download e testes por persona.
