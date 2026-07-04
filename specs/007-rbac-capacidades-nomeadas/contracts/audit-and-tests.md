# Contract: Auditoria e Testes

## `scripts/audit-rpc.mjs`

### Novo criterio

O script continua resolvendo a ultima definicao ativa de cada funcao nas migrations. Para funcoes de acao sensivel, alem dos guardrails da feature 006, passa a exigir `tem_capacidade(...)`.

### Classificacao

| Classe | Guard esperado |
|--------|----------------|
| Leitura de dominio | `permissao_modulo(...)` |
| Escrita direta | `tem_capacidade(...)` |
| Efeito de negocio | `tem_capacidade(...)` |
| Helper de autorizacao | allowlist especifica (`tem_capacidade`, `obter_capacidades_usuario`, `permissao_modulo`, `obter_permissoes_usuario`) |
| Admin-only legado | `existe_perfil_admin(...)` quando explicitamente catalogado |
| Auditoria auth | regra propria da feature 006 |

### Falhas esperadas

- RPC de escrita sem `tem_capacidade`.
- RPC de boleto/notificacao/exportacao/envio/geracao sem `tem_capacidade`.
- RPC de leitura sem `permissao_modulo`, salvo allowlist.
- Funcao nova sem `REVOKE`/`GRANT`, `search_path` ou guarda de identidade.

## pgTAP

### Novo arquivo

`supabase/tests/05_capacidades.sql`

### Cobertura obrigatoria

- Catalogo completo de capacidades.
- Matriz por perfil:
  - Administrador tem todas.
  - Financeiro tem financeiro + cobrancas.baixar/emitir + relatorios.exportar + perfil proprio.
  - Projetos tem projetos/tarefas/equipe/apontamentos qualquer + relatorios.exportar + perfil proprio.
  - Comercial tem clientes/propostas/contratos/cobrancas comerciais + perfil proprio.
  - Tecnico tem exatamente tarefas proprias + apontamento proprio + perfil proprio.
  - Visualizador tem zero capacidades.
- `tem_capacidade` retorna false para anonimo.
- `obter_capacidades_usuario` retorna lista esperada por perfil.
- Tecnico nao cria/exclui projeto.
- Tecnico nao move/edita tarefa alheia.
- Tecnico move/edita tarefa propria.
- Tecnico nao registra apontamento para outro membro.
- Tecnico registra apontamento proprio.
- Apontamento com `tarefa_id = null` grava sem erro.
- `listar_membros_equipe` retorna colegas com alocacao ativa nos mesmos projetos em andamento para Tecnico.
- `listar_membros_equipe` nao expõe para Tecnico `perfil_id`, `custo_hora`, permissoes, contatos sensiveis, historico de apontamentos nem alocacoes fora dos projetos compartilhados de colegas.

### Ajuste em `02_rbac_por_perfil.sql`

- Remover Visualizador da matriz de personas operacionais.
- Manter teste separado de Visualizador como estado tecnico minimo:
  - zero capacidades;
  - leitura restrita a `relatorios` e `configuracoes`;
  - nenhuma escrita.

## Vitest

### Novos/ajustados

- `src/lib/capacidades.test.ts`
  - lista ausente retorna false;
  - match exato retorna true;
  - capacidade semelhante nao da match parcial;
  - string vazia retorna false.
- `src/services/equipe.service.test.ts` ou teste equivalente
  - "sem tarefa" normaliza para `null`;
  - nunca envia `"geral"` como `tarefa_id`.
- Testes de pages/helpers onde ja existirem mocks de permissao devem passar a mockar `capacidades`.

## Validacao E2E

Rodar nas 5 personas operacionais:

```text
Administrador
Financeiro
Projetos
Comercial
Técnico
```

Visualizador e validado apenas como signup/minimo tecnico, nao como persona de negocio.

## Gates finais

```text
npm run build
npm run test
npm run db:test
npm run audit
```

Validacao Playwright/E2E complementar:

- Login nas 5 personas.
- Rota direta bloqueada sem flash de dados.
- Acoes visiveis batem com capacidades.
- Chamadas diretas proibidas falham no backend.
