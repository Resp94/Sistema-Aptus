# Research: Exportar Relatorios

**Date**: 2026-07-04

## Decision 1: Geracao centralizada em Supabase Edge Function

**Decision**: Criar a Edge Function `relatorios-exportacao` para gerar PDF/CSV, fazer upload no Storage privado e retornar signed URL temporaria.

**Rationale**: A geracao precisa ser server-side para manter contratos completos de dados, evitar expor segredos, registrar historico confiavel e garantir que status `Pronto` so exista depois do arquivo real estar persistido. A documentacao oficial de Edge Functions descreve funcoes TypeScript server-side, Deno-compatible, com acesso a APIs Supabase e validacao de JWT.

**Alternatives considered**:

- Gerar PDF/CSV no navegador: rejeitado porque fragiliza autorizacao, dificulta historico auditavel e pode materializar dados alem do escopo autorizado.
- Apenas RPC que retorna dados para o frontend montar arquivo: rejeitado porque desloca regra sensivel de formato e armazenamento para o cliente.
- Job assíncrono sem download imediato: rejeitado porque contraria o requisito de gerar e baixar na hora.

**Source**: https://supabase.com/docs/guides/functions.md

## Decision 2: Storage privado com arquivo persistente e signed URL curto

**Decision**: Criar bucket privado `relatorios-exportados`; persistir somente `arquivo_path` e metadados no banco; gerar signed URL curto no momento do download imediato ou posterior.

**Rationale**: Relatorios exportados podem conter dados empresariais sensiveis. A documentacao oficial de Storage reforca que acesso a objetos deve ser governado por politicas de RLS em `storage.objects` e que a service key bypassa RLS, portanto ela deve ficar apenas no servidor.

**Alternatives considered**:

- Salvar URL publica em `arquivo_url`: rejeitado por violar FR-021.
- Salvar binario no PostgreSQL: rejeitado por piorar custo, backup e performance para arquivos.
- Gerar arquivo sempre de novo para cada download historico: rejeitado porque historico precisa baixar o artefato anterior enquanto valido.

**Source**: https://supabase.com/docs/guides/storage/security/access-control.md

## Decision 3: Historico com status armazenado e expiracao computada

**Decision**: Manter status persistido `Pendente`, `Pronto`, `Falhou` e `Indisponível` para compatibilidade; expor `Expirado` como `status_exibicao` quando `status = 'Pronto'` e `expira_em < now()`.

**Rationale**: Expiracao e uma regra temporal. Computar no RPC de listagem/download evita depender de cron para virar status e preserva rastreabilidade. Downloads expirados sao bloqueados por RPC mesmo se o objeto ainda existir no Storage.

**Alternatives considered**:

- Mutar status para `Expirado` por cron: rejeitado no MVP porque adiciona agendamento sem necessidade funcional.
- Deletar objeto exatamente no aniversario de 12 meses: rejeitado porque o requisito exige bloqueio de download e rastreabilidade, nao limpeza fisica imediata.

## Decision 4: Autorizacao por capacidade e escopo de historico

**Decision**: Usar `tem_capacidade('relatorios.exportar')` para gerar e baixar arquivos. Administrador pode listar/baixar todos; Financeiro e Projetos apenas proprios; Visualizador, Comercial, Tecnico e perfis sem capacidade nao geram nem baixam.

**Rationale**: A feature 007 definiu capacidades nomeadas como fonte canonica para acoes sensiveis. Exportar arquivo e baixar historico sao extracoes sensiveis, diferentes de leitura de Relatorios.

**Alternatives considered**:

- Usar `permissao_modulo('relatorios')` como autorizacao de exportacao: rejeitado porque mistura leitura com extracao.
- Autorizar download apenas por posse do `exportacao_id`: rejeitado porque precisa validar permissao atual e categoria permitida.

## Decision 5: Periodo por categoria

**Decision**: Financeiro e DRE filtram movimentacoes do periodo; Clientes e Projetos usam snapshot atual com metricas de atividade do periodo.

**Rationale**: Essa regra foi definida na clarificacao da especificacao. Ela evita relatorios de Clientes/Projetos que apaguem registros ativos sem atividade no periodo, mas ainda respeita o filtro temporal nas metricas.

**Alternatives considered**:

- Aplicar filtro de periodo igualmente a todas as linhas: rejeitado porque para Clientes/Projetos isso perderia o snapshot atual.
- Ignorar periodo em Clientes/Projetos: rejeitado porque FR-006 exige que o periodo afete os dados exportados.

## Decision 6: CSV como pacote ZIP quando houver resumo e detalhes

**Decision**: Para formato CSV, entregar ZIP contendo `resumo.csv` e `detalhes.csv` quando a categoria tiver ambos. A implementacao inicial usa serializador CSV interno e `fflate` para ZIP.

**Rationale**: CSV puro representa bem uma tabela por arquivo, mas nao representa dois conjuntos com granularidades diferentes sem ambiguidades. O ZIP preserva formato planilhavel e cumpre a regra de resumo executivo + linhas detalhadas.

**Alternatives considered**:

- CSV unico com secoes separadas por linhas vazias: rejeitado por quebrar importacao em planilhas/BI.
- XLSX: rejeitado porque nao foi solicitado e adiciona dependencia/superficie maior.

## Decision 7: Edge Function curta e sem chamadas recursivas

**Decision**: A funcao deve executar geracao, upload e assinatura em uma chamada curta. O alvo de 10 segundos vale para ate 5.000 linhas detalhadas ou ate 10 MB antes de compressao. Se volumes futuros excederem esse limite, a evolucao sera fila/background worker fora do MVP.

**Rationale**: O objetivo mensuravel e download imediato para volumes operacionais comuns. O changelog da Supabase registra limites para chamadas recursivas/nested de Edge Functions, entao a funcao nao deve chamar outra Edge Function para concluir o mesmo fluxo.

**Source**: https://supabase.com/changelog.md

## Decision 8: Compatibilidade com mudanca de exposicao de tabelas

**Decision**: Nao depender de acesso direto do frontend a novas tabelas. Frontend deve consumir RPCs e Edge Function.

**Rationale**: O changelog da Supabase registra mudanca em 2026-04-28 sobre tabelas nao serem automaticamente expostas para Data/GraphQL APIs. A arquitetura RPC-first ja reduz acoplamento com exposicao direta de tabelas.

**Source**: https://supabase.com/changelog.md

## Decision 9: Supabase CLI local

**Decision**: Antes da implementacao, confirmar comandos disponiveis com `supabase --help` e `supabase functions --help`; considerar upgrade da CLI local de `2.75.0` para a versao atual indicada pela CLI (`2.109.0`) se comandos de functions/storage/advisors divergirem.

**Rationale**: O plano envolve Edge Functions e Storage; manter CLI atualizada reduz divergencia entre ambiente local e documentacao atual.

## Decision 10: PDF renderer

**Decision**: Usar `pdf-lib` para PDF na implementacao inicial.

**Rationale**: `pdf-lib` e compatível com runtime server-side/Edge sem depender de browser DOM, permitindo montar documentos em memoria a partir do payload autorizado.

**Alternatives considered**:

- HTML-to-PDF/headless browser: rejeitado para o MVP por ser mais pesado e menos adequado ao runtime Edge.
- PDF manual sem biblioteca: rejeitado por aumentar risco de layout quebrado e custo de manutencao.

## Decision 11: Categorias exportaveis e categoria Personalizado

**Decision**: Exportacao inicial cobre Financeiro, DRE, Clientes e Projetos. `Personalizado` fica fora do escopo 008.

**Rationale**: As quatro categorias possuem preview e semantica de periodo definida. `Personalizado` nao possui contrato de conteudo completo, portanto exporta-lo agora geraria ambiguidade.

## Decision 12: RPC legada

**Decision**: O frontend novo abandona `solicitar_exportacao_relatorio` para exportacao manual. A RPC permanece somente para compatibilidade legada, podendo registrar `Indisponível`, mas nunca o fluxo principal da feature 008.

**Rationale**: Manter dois caminhos ativos para exportacao manual criaria divergencia entre front e back e risco de sucesso simulado.
