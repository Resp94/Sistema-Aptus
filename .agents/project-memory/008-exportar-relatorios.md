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

## Backlog de implementacao

Executado `/speckit-tasks` em 2026-07-04 e criado `specs/008-exportar-relatorios/tasks.md`.

O backlog possui 80 tarefas em formato checklist Spec Kit:

- Setup: 6 tarefas.
- Fundacional: 17 tarefas.
- US1 Exportar relatorio completo imediatamente: 20 tarefas.
- US2 Baixar exportacoes anteriores: 15 tarefas.
- US3 Respeitar personas e leitura sem exportacao: 9 tarefas.
- Polish/cross-cutting: 13 tarefas.

As tarefas seguem abordagem test-first com pgTAP para RPCs/RBAC/historico, Vitest para services/UI, validacao de Edge Function e gates finais `npm run db:test`, `npm run test`, `npm run build` e `npm run audit`.

### Correcao pos-analise das tarefas

Executado `/speckit-analyze` em 2026-07-04 e identificadas lacunas nao bloqueantes no backlog: acessibilidade estava especificada, mas sem teste explicito; Storage privado/policies estavam previstos, mas sem assertiva direta; o TTL de signed URL estava no contrato como 600 segundos, mas generico nas tarefas; observabilidade possuia implementacao prevista, mas sem campos obrigatorios explicitados.

`specs/008-exportar-relatorios/tasks.md` foi refinado sem renumerar tarefas:

- T023 e T075 agora exigem assertivas pgTAP/SQL para bucket privado e negacao de leitura publica/ampla em Storage.
- T027, T036, T047 e T051 agora exigem `download_expires_in = 600` e ausencia de URL publica permanente nos fluxos de gerar/download.
- T028 e T048 agora exigem testes de foco inicial, labels, teclado, Escape, responsividade minima e status nao dependente apenas de cor.
- T029, T037 e T052 agora exigem testes/implementacao de observabilidade com campos minimos: `exportacao_id`, usuario, categoria, formato, periodo, status, duracao, tamanho quando existir e erro sanitizado quando aplicavel.

## Proxima etapa

Executar `/speckit-implement` para iniciar a implementacao da feature 008 com o backlog refinado.

## Implementacao

Executado `/speckit-implement` sobre `specs/008-exportar-relatorios/tasks.md` (80 tarefas, todas concluidas). Resultado:

### O que foi construido

- **Migration** `supabase/migrations/20260704235640_exportar_relatorios.sql`: colunas novas em `exportacoes_relatorios` (periodo, metadados de arquivo, expiracao, erro, timestamps), bucket privado `relatorios-exportados` com policy de `SELECT` autenticado (defesa em profundidade) e nenhuma policy de escrita para `authenticated`/`anon`, helpers `categoria_relatorio_exportavel` e `validar_periodo_exportacao`, quatro builders de payload completo por categoria (`montar_payload_relatorio_financeiro/dre/clientes/projetos`), RPCs `iniciar_exportacao_relatorio`, `concluir_exportacao_relatorio`, `falhar_exportacao_relatorio`, `autorizar_download_exportacao_relatorio`, `listar_exportacoes_relatorios` (assinatura de retorno expandida) e extensao de `public.audit_log` (coluna `detalhes jsonb` + funcao `registrar_evento_exportacao`) para observabilidade.
- **Edge Function** `supabase/functions/relatorios-exportacao/` (`index.ts`, `_shared.ts`, `payload.ts`, `renderers.ts` + testes): acoes `gerar` e `download`, client user-scoped (JWT) para todas as RPCs de negocio, client de service role usado apenas para upload/assinatura de Storage, renderizacao PDF via `pdf-lib` e CSV/ZIP via `fflate`, signed URLs de 600 segundos, logs estruturados por evento e limite de volume operacional (5.000 linhas/10MB) aplicado antes de renderizar.
- **Frontend**: `src/services/relatorios.service.ts` ganhou `exportarRelatorio`/`baixarExportacaoRelatorio` (invocam a Edge Function) mantendo `solicitarExportacaoRelatorio` apenas como `@deprecated`; `src/pages/RelatoriosPage.tsx` ganhou modal de exportacao (categoria, periodo com defaults de primeiro dia do mes/hoje, formato PDF ou CSV) e historico completo com estados `Pronto`/`Falhou`/`Expirado`/`Indisponivel`, gates de UI por capacidade `relatorios.exportar` e por categoria exportavel da persona.

### Decisoes tecnicas tomadas por ambiguidade

1. **Path de Storage por ano de geracao**: `<tipo>/<yyyy>/<exportacao_id>/<arquivo_nome>`, onde `<yyyy>` vem de `gerado_em` (data de geracao), nao do periodo do relatorio filtrado — mantem a retencao de 12 meses coerente com a data em que o objeto foi de fato criado, independente do periodo consultado.
2. **Reaproveitamento de `audit_log` para observabilidade**: em vez de criar uma tabela nova, a tabela de auditoria existente ganhou uma coluna `detalhes jsonb` e uma funcao dedicada `registrar_evento_exportacao` (nao altera a assinatura de 3 args de `registrar_evento_auditoria`, usada por eventos de seguranca/sessao). Cinco novos valores de evento foram adicionados ao check constraint.
3. **`resumo`/`detalhes` como arrays de objetos**: formato `[{"label":..,"valor":..}, ...]` para resumo e lista de linhas nomeadas para detalhes, mapeando diretamente para `resumo.csv`/`detalhes.csv` sem transformacao extra na Edge Function.
4. **Campos sem fonte no schema atual**: `projeto` nas linhas de Financeiro/DRE e sempre `NULL` (lancamentos nao tem `projeto_id`); "responsavel" de um projeto e derivado da primeira alocacao em `alocacoes_projeto` por ordem de criacao (projetos nao tem coluna propria de responsavel).
5. **Ownership em `concluir_exportacao_relatorio`/`falhar_exportacao_relatorio`**: validado apenas por `criado_por = auth.uid()`, pois a arquitetura nao tem fila/worker assincrono — a Edge Function sempre chama essas RPCs com o JWT do proprio usuario que iniciou a exportacao.

### Bugs reais encontrados e corrigidos durante a implementacao

- **`listar_exportacoes_relatorios` lancava excecao para Comercial/Tecnico**: a checagem de permissao de modulo (`permissao_modulo('relatorios')`) estava posicionada antes do corte por perfil, entao qualquer perfil sem `pode_ler` em relatorios recebia uma excecao `permission_denied` em vez do historico vazio esperado pelo contrato (`rpc-exportacao-relatorios.md`: "Visualizador/Comercial/Tecnico: no exportable history"). Corrigido para retornar lista vazia (`RETURN;`) de forma graciosa, no mesmo padrao ja usado pela RPC irma `listar_categorias_relatorios`.
- **`relatorios.service.ts` vazava mensagem tecnica generica do Supabase**: o client `@supabase/functions-js` sempre preenche `error.message` com o texto fixo `"Edge Function returned a non-2xx status code"` para qualquer resposta HTTP nao-2xx da Edge Function, independente do corpo JSON real de erro (`{ error: { code, message } }"`). Usar `error.message` diretamente (como um primeiro rascunho faria) mostraria sempre esse texto tecnico ao usuario final, nunca a mensagem de negocio (ex.: "Periodo maximo permitido e de 12 meses"). Corrigido com `resolverMensagemErroExportacao`, que le o corpo JSON real de `error.context` (uma `Response` ainda nao consumida) antes de cair para o mapa local de mensagens amigaveis por codigo.

### Estado final dos testes

- pgTAP (`npm run db:test`): 367 assertions.
- Vitest (`npm run test`): 113 testes.
- `npm run build`: OK.
