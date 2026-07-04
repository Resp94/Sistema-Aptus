# Quickstart: Validacao da Feature 007

Este roteiro valida a feature de RBAC por capacidades nomeadas depois da implementacao.

## Pre-requisitos

- Ambiente local Supabase funcional.
- Dependencias instaladas.
- Banco resetado com migrations e seed atualizados.

```powershell
npm install
npm run supabase:start
npm run supabase:reset
```

## 1. Validar build e testes unitarios

```powershell
npm run build
npm run test
```

Esperado:

- Build sem erros TypeScript.
- Testes de `pode()` passam.
- Teste de normalizacao de apontamento confirma `tarefa_id: null` para atividade geral.

## 2. Validar testes de banco

```powershell
npm run db:test
```

Esperado:

- `02_rbac_por_perfil.sql` cobre 5 personas operacionais.
- `05_capacidades.sql` valida catalogo, matriz, ownership e leitura de equipe do Tecnico.
- Visualizador aparece somente como caso tecnico minimo.

**Nota (descoberta na validacao):** `05_capacidades.sql` cria fixtures (`[FIXTURE 05] ...`) via chamadas reais as RPCs de escrita para provar ownership e guardas de capacidade. Essas linhas nao sao revertidas automaticamente pelo `supabase test db` e ficam visiveis no frontend (clientes, propostas, contratos, lancamentos, membros de equipe). Rode `npm run supabase:reset` novamente antes da secao 5 (validacao de frontend por persona) para partir de um estado limpo.

## 3. Validar auditorias

```powershell
npm run audit
```

Esperado:

- `audit-rpc.mjs` aceita RPCs de leitura com `permissao_modulo`.
- `audit-rpc.mjs` exige `tem_capacidade` em escrita e efeitos de negocio.
- `check-no-from.mjs` continua permitindo apenas `health-check.ts`.
- `check-no-user-metadata.mjs` segue sem novas autorizacoes baseadas em metadata.

## 4. Validar matriz de capacidades no banco

Executar consultas via ferramenta SQL local/Supabase Studio:

```sql
select perfil_acesso, count(*) as total
from public.capacidades_perfil
group by perfil_acesso
order by perfil_acesso;
```

Esperado:

- Administrador tem todas as capacidades.
- Visualizador nao tem linhas.
- Tecnico tem exatamente 4 capacidades.

## 5. Validar frontend por persona

Subir app:

```powershell
npm run dev
```

### Administrador

- Ve todos os modulos permitidos.
- Ve acoes sensiveis principais.
- Consegue criar/inativar/reativar cliente.

### Financeiro

- Ve Dashboard, financeiro, cobrancas, relatorios e configuracoes proprias.
- Ve baixa financeira.
- Nao ve boleto/notificacao comercial se nao possuir as capacidades correspondentes.

### Projetos

- Ve Projetos, Equipe e Relatorios.
- Consegue criar/excluir projeto e mover tarefa de qualquer responsavel.
- Consegue apontar horas para qualquer membro.

### Comercial

- Ve Clientes, Propostas, Contratos e Cobrancas.
- Ve boleto/notificacao.
- Nao ve baixa financeira.

### Técnico

- Nao ve criar/excluir projeto.
- Consegue mover/editar tarefa propria.
- Nao consegue mover/editar tarefa alheia por chamada direta.
- Consegue apontar as proprias horas.
- Nao consegue apontar para outro membro.
- Ve a si mesmo e colegas alocados nos mesmos projetos.

## 6. Validar bugs funcionais corrigidos

- Equipe: apontamento com "Atividade Geral do Projeto (Sem tarefa)" grava sem 400.
- Propostas: painel de detalhe fecha por botao visivel e Esc.
- Contratos: painel de detalhe fecha por botao visivel e Esc.
- Clientes: cliente inativo exibe `Reativar Contato` para usuario com `clientes.reativar`.

## 7. Validar Visualizador tecnico

- Usuario recem-cadastrado com Visualizador nao aparece como persona operacional.
- Possui zero capacidades.
- Acessa apenas leitura minima de Relatorios e Configuracoes proprias.
- Nao ve botoes de acao sensivel.

## Resultado esperado final

Todos os comandos passam e a validacao Playwright/E2E das cinco personas confirma que acoes visiveis no frontend batem com a autorizacao real das RPCs.
