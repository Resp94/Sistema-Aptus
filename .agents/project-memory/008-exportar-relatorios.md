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

## Planejamento tecnico

Executado `/speckit-plan` para detalhar arquitetura, contratos de dados completos por categoria, persistencia de arquivos, historico, seguranca de download e testes por persona.

### Decisoes de arquitetura

- A exportacao sera centralizada na Supabase Edge Function `relatorios-exportacao`, com acoes `gerar` e `download`.
- O frontend chamara a Edge Function com JWT do usuario; a funcao usara RPCs user-scoped para autorizacao e service role somente no servidor para upload/assinatura de Storage.
- Os arquivos serao salvos em bucket privado `relatorios-exportados`; o banco armazenara `arquivo_path` e metadados, nao URL publica permanente.
- O download imediato e o re-download historico retornarao signed URLs curtos gerados sob autorizacao atual.
- `exportacoes_relatorios` sera expandida com periodo, metadados do arquivo, expiracao, erro e status de exibicao computado.
- `Expirado` sera status de exibicao computado quando `status = Pronto` e `expira_em < now()`, preservando historico sem exigir cron no MVP.
- O CSV sera entregue como ZIP com `resumo.csv` e `detalhes.csv` quando houver resumo e linhas detalhadas.
- O fluxo novo nao deve usar `arquivo_url`; o campo pode permanecer apenas por compatibilidade com historico legado.

### Artefatos de planejamento criados

- `specs/008-exportar-relatorios/plan.md`
- `specs/008-exportar-relatorios/research.md`
- `specs/008-exportar-relatorios/data-model.md`
- `specs/008-exportar-relatorios/quickstart.md`
- `specs/008-exportar-relatorios/contracts/edge-function-exportacao.md`
- `specs/008-exportar-relatorios/contracts/rpc-exportacao-relatorios.md`
- `specs/008-exportar-relatorios/contracts/storage-and-retention.md`
- `specs/008-exportar-relatorios/contracts/frontend-relatorios.md`
- `specs/008-exportar-relatorios/contracts/audit-and-tests.md`

## Checklist de qualidade do plano

Executado `/speckit-checklist` sobre `specs/008-exportar-relatorios/plan.md` e criado `specs/008-exportar-relatorios/checklists/plan-quality.md`.

O checklist possui 46 itens de revisao de qualidade dos requisitos e do plano, cobrindo completude, clareza, consistencia, criterios de aceite, cobertura de cenarios, edge cases, requisitos nao funcionais, dependencias e ambiguidades. O foco e revisar se os artefatos estao claros e completos antes de `/speckit-tasks`, nao testar implementacao.

### Validacao do checklist

Validado item a item em 2026-07-04. Resultado: 32 de 46 checkpoints aprovados e 14 abertos.

Pontos abertos antes de `/speckit-tasks`: fonte canonica das categorias exportaveis, campos completos por categoria, conteudo PDF/CSV por categoria, quantificacao de "relatorio completo", semantica exata de periodo de 12 meses, definicao de "volumes operacionais comuns", cobertura PDF/CSV por persona exportadora, boundary exatamente 12 meses, acessibilidade/responsividade do modal e historico, observabilidade, decisao final das bibliotecas PDF/ZIP, fonte canonica de categoria por persona, visibilidade da coluna solicitante por perfil e caminho unico para descontinuar a RPC legada.

### Fechamento dos checkpoints abertos

Deliberado e aprovado em 2026-07-04 o fechamento dos 14 checkpoints pendentes. `spec.md`, `plan.md`, `research.md`, `data-model.md`, contratos e quickstart foram atualizados.

Decisoes finais:

- Categorias exportaveis iniciais: Financeiro, DRE, Clientes e Projetos.
- `Personalizado` fica fora da exportacao 008 ate existir contrato completo proprio.
- Fonte canonica: `listar_categorias_relatorios` para leitura/preview e helper/RPC derivado para categoria exportavel por persona em geracao/download.
- Admin exporta as quatro categorias; Financeiro exporta Financeiro/DRE; Projetos exporta Projetos; Visualizador/Comercial/Tecnico nao exportam.
- Periodo usa datas inclusivas; mesmo dia e permitido; `2026-01-01` a `2026-12-31` permitido; `2026-01-01` a `2027-01-01` bloqueado.
- Volume operacional comum: ate 5.000 linhas detalhadas ou 10 MB antes de compressao.
- Bibliotecas decididas: `pdf-lib` para PDF, `fflate` para ZIP e serializador CSV interno.
- Modal/historico devem cobrir acessibilidade, responsividade a partir de 320px, teclado, labels, foco, Esc e status textual.
- Observabilidade minima: `exportacao_id`, usuario, categoria, formato, periodo, status, duracao, tamanho e erro sanitizado.
- Historico: Admin ve solicitante em todas as linhas; Financeiro/Projetos recebem dado do solicitante, mas UI pode mostrar o proprio nome ou omitir em layout compacto.
- RPC legada `solicitar_exportacao_relatorio` permanece apenas compatibilidade, sem uso novo pelo frontend e sem re-roteamento para o novo fluxo.

Checklist `plan-quality.md` atualizado para 46 de 46 checkpoints aprovados.

## Proxima etapa

Executar `/speckit-tasks` para transformar o plano em backlog test-first cobrindo migracao Supabase, RPCs, Edge Function, Storage privado, frontend, historico e validacao por persona.
