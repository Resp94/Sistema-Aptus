# Research: RBAC por Capacidades Nomeadas

## Decision: Capacidades em tabela auditavel, nao enum fechado

**Decision**: Criar `public.capacidades_perfil(perfil_acesso text, capacidade text)` com chave primaria composta e seed versionado por migration.

**Rationale**: A tabela permite auditoria em git agora e abre caminho para uma UI administrativa futura sem alterar schema. Um enum PostgreSQL deixaria o catalogo mais rigido e exigiria migrations para cada nova capacidade; texto livre sem restricao seria fragil. O equilibrio e usar texto `recurso.acao`, PK composta e testes de matriz.

**Alternatives considered**:

- Enum por capacidade: mais forte, mas ruim para evolucao operacional futura.
- JSON em `perfis`: facil de adicionar, ruim para auditoria, joins, testes e constraints.
- Apenas hardcode em RPCs: resolve no banco, mas deixa frontend sem fonte canonica comum.

## Decision: `tem_capacidade` complementa `permissao_modulo`

**Decision**: Manter `permissao_modulo`/`obter_permissoes_usuario` para leitura, rota e navegacao; usar `tem_capacidade(p_capacidade text)` para acoes sensiveis.

**Rationale**: A validacao provou que a rota pode estar correta enquanto a acao esta errada. Separar leitura de acao evita quebrar o roteamento existente e permite migracao gradual do frontend. `tem_capacidade` consulta o perfil ativo do usuario autenticado e a matriz `capacidades_perfil`.

**Alternatives considered**:

- Substituir tudo por capacidades, inclusive leitura: alto risco e grande reescrita de rotas.
- Manter apenas `pode_escrever`: preserva a causa raiz dos bugs.
- Retornar acoes por pagina em cada RPC de listagem: reduz drift em telas especificas, mas cria acoplamento pagina-a-pagina.

## Decision: Acoes com efeito de negocio exigem capacidade

**Decision**: Toda escrita e toda acao sensivel com efeito de negocio deve validar capacidade, incluindo boleto, notificacao, exportacao, baixa, envio e geracao.

**Rationale**: Algumas funcoes nao parecem "write" por nome ou por volume de persistencia, mas disparam efeitos de negocio ou auditoria. Tratar todas como protegidas evita lacunas no `audit-rpc` e no frontend.

**Alternatives considered**:

- Proteger apenas INSERT/UPDATE/DELETE diretos: deixaria boleto/notificacao/exportacao ambiguos.
- Proteger todas as leituras: desnecessario agora, pois leitura continua governada por modulo e RLS.

## Decision: Guardrails seguem padrao Supabase + feature 006

**Decision**: Novas funcoes expostas seguem `SECURITY DEFINER`, `SET search_path = public`, guarda de identidade, `REVOKE EXECUTE FROM PUBLIC` e `GRANT EXECUTE TO authenticated`.

**Rationale**: O padrao ja foi consolidado na feature 006 e esta alinhado com a documentacao atual do Supabase sobre funcoes: funcoes podem ser chamadas pela API, `SECURITY DEFINER` exige `search_path` controlado, e funcoes tem execucao publica por padrao se nao houver revoke/grant explicito. Fonte: Supabase Database Functions docs, https://supabase.com/docs/guides/database/functions.

**Alternatives considered**:

- `SECURITY INVOKER`: desejavel por padrao, mas as RPCs atuais usam `SECURITY DEFINER` para encapsular dominio com guardas internas.
- Acesso direto a tabela de capacidades pelo frontend: violaria RPC-first e aumentaria superficie de permissao.

## Decision: Tabela de capacidades com RLS habilitado e acesso por RPC

**Decision**: Habilitar RLS em `public.capacidades_perfil` e nao depender de acesso direto pelo frontend. A leitura de capacidades ocorre por `obter_capacidades_usuario()`.

**Rationale**: O projeto ja evita `supabase.from()` em dominio. Mesmo com RLS, acesso direto a uma tabela de autorizacao aumenta risco de exposicao desnecessaria. A documentacao Supabase reforca RLS para tabelas em schema exposto e o uso de politicas com autorizacao real, nao apenas `TO authenticated`. Fonte: Supabase Row Level Security docs, https://supabase.com/docs/guides/database/postgres/row-level-security.

**Alternatives considered**:

- Expor SELECT direto para authenticated: simples, mas contraria RPC-first e torna a matriz uma API REST acidental.
- Tabela em schema privado: mais isolado, mas destoaria da estrutura atual; pode ser reavaliado se o projeto mover helpers de autorizacao para schema privado.

## Decision: Visualizador vira perfil tecnico minimo

**Decision**: Visualizador deixa de ser persona operacional. Permanece como valor valido para signup com zero capacidades e leitura minima em `relatorios` e `configuracoes` proprias.

**Rationale**: O perfil atual esta amplo demais e contradiz a persona desejada. Mantê-lo como estado inicial protege contra auto-escalacao enquanto permite uma experiencia minima ate promocao administrativa.

**Alternatives considered**:

- Remover Visualizador do banco: quebraria o fluxo anti-escalacao de signup.
- Manter read-only amplo: preservaria a divergencia e exposição de dados.
- Bloquear todas as rotas: mais seguro, mas pior para usuario recem-cadastrado que precisa ao menos ajustar perfil/aguardar promocao.

## Decision: Ownership por relacionamento, nao por nome de perfil

**Decision**: Capacidades `*_propria`/`*_proprio` exigem checagem de ownership no corpo da RPC. Para tarefas, ownership e `tarefas.responsavel_id = membros_equipe.id` do membro vinculado ao perfil do usuario autenticado (`perfis.usuario_id = auth.uid()`). Para apontamentos, ownership e o `membro_equipe` vinculado ao perfil do usuario autenticado.

**Rationale**: Regras por nome de perfil geram excecoes espalhadas. Capacidades expressam o que pode ser feito; ownership define em quais registros.

**Alternatives considered**:

- Hardcode `perfil = 'Técnico'`: facil no curto prazo, ruim para evoluir perfis.
- Confiar no frontend para escolher o proprio membro/tarefa: inseguro; chamadas diretas burlariam.

## Decision: Leitura de equipe do Tecnico por projetos compartilhados

**Decision**: `listar_membros_equipe` retorna, para usuarios sem leitura ampla de equipe, o proprio membro e colegas que compartilham projeto ativo via `alocacoes_equipe`. O compartilhamento exige alocacao ativa dos dois membros (`data_fim` nula ou maior/igual a data atual) no mesmo projeto em andamento.

**Rationale**: A persona pede saber quem trabalha nos mesmos projetos. Retornar apenas si mesmo quebra a historia; retornar toda equipe expõe mais que o necessario. O retorno limitado preserva o shape operacional existente, mas reduz campos sensiveis: colegas podem expor somente identificador de membro, nome, funcao, habilidades, status, capacidade e projeto compartilhado; `perfil_id`, `custo_hora`, permissoes, contatos sensiveis, historico de apontamentos e alocacoes fora dos projetos compartilhados devem ficar ocultos ou nulos.

**Alternatives considered**:

- Somente proprio membro: bug atual.
- Toda equipe: excesso de exposicao para Tecnico.
- Filtrar por departamento: menos preciso que alocacao real em projeto.

## Decision: Reativacao de cliente usa `atualizar_cliente`

**Decision**: Nao criar RPC nova de reativacao. `atualizar_cliente` deve aceitar status `Ativo` para cliente inativo quando o usuario tem `clientes.reativar`; demais edicoes continuam exigindo `clientes.editar`.

**Rationale**: A RPC existente ja atualiza status. A lacuna e autorizacao/UX, nao necessidade de novo endpoint.

**Alternatives considered**:

- Criar `reativar_cliente`: mais explicito, mas contraria o requisito do usuario de "zero RPC nova".
- Usar apenas `clientes.editar`: permitiria reativacao por quem so deveria editar campos.

## Decision: Auditoria diferencia guard de modulo e guard de acao

**Decision**: `scripts/audit-rpc.mjs` passa a aceitar `tem_capacidade` como guard valido para funcoes de escrita/efeito e a exigir esse guard para funcoes classificadas como acao sensivel. Leituras seguem com `permissao_modulo`.

**Rationale**: O script atual detecta `permissao_modulo`, mas isso ficaria insuficiente e poderia reprovar funcoes corretamente migradas. A classificacao precisa acompanhar o novo contrato.

**Alternatives considered**:

- Aceitar qualquer uma das guardas em qualquer funcao: flexivel demais; deixaria leitura/escrita misturadas.
- Remover exigencia de `permissao_modulo`: quebraria a protecao de leituras.
