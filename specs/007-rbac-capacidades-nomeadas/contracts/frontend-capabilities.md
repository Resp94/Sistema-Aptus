# Contract: Frontend e Capacidades

Este contrato define como o cliente React consome capacidades para UX sem virar fonte de autorizacao.

## Auth Context

`AuthState` passa a expor:

```ts
interface AuthState {
  carregando: boolean
  perfil: PerfilUsuario | null
  permissoes: PermissaoModulo[]
  capacidades: string[]
  sair: () => Promise<void>
}
```

## Auth Service

Adicionar:

```ts
async function getCapacidadesUsuario(): Promise<string[]>
```

Contrato:

- Chama somente `supabase.rpc('obter_capacidades_usuario')`.
- Retorna `[]` em estado sem sessao.
- Propaga erro real para o AuthContext tratar logout/perfil ausente da mesma forma que perfil/permissoes.

## Helper

Novo helper em `src/lib/capacidades.ts`:

```ts
function pode(capacidades: string[] | null | undefined, capacidade: string): boolean
```

Regras:

- `false` para lista ausente.
- `false` para capacidade vazia.
- `true` apenas para match exato.
- Sem wildcard no frontend.

## Uso por Pagina

| Pagina | Gates por capacidade |
|--------|----------------------|
| `ClientesPage.tsx` | Criar, editar, inativar, reativar, registrar atendimento |
| `PropostasPage.tsx` | Criar, editar, enviar, gerar contrato, fechar detalhe |
| `ContratosPage.tsx` | Criar, renovar, encerrar, fechar detalhe |
| `CobrancasPage.tsx` | Emitir, boleto, notificar, baixar |
| `ProjetosPage.tsx` | Criar/editar/excluir projeto; criar/excluir tarefa; editar/mover propria ou qualquer |
| `EquipePage.tsx` | Adicionar/editar membro, alocar, inativar, apontar proprio/qualquer |
| `FluxoCaixaPage.tsx` | Lancar e editar lancamento |
| `ContasPagarPage.tsx` | Lancar, editar e baixar conforme financeiro |
| `ContasReceberPage.tsx` | Lancar, editar e baixar conforme financeiro |
| `RelatoriosPage.tsx` | Exportar/agendar relatorio |
| `ConfiguracoesPage.tsx` | Gerenciar usuarios, editar empresa, editar proprio perfil |

## Compatibilidade com Permissoes por Modulo

- `podeLer(permissoes, modulo)` permanece para rota, menu e leitura.
- `podeEscrever(permissoes, modulo)` nao deve ser usado para botoes de acao sensivel apos a migracao.
- Testes existentes de `podeEscrever` podem permanecer como compatibilidade, mas novos testes de botoes devem usar `pode()`.

## Payloads

### Apontamento sem tarefa

Antes:

```ts
{ tarefa_id: 'geral' }
```

Depois:

```ts
{ tarefa_id: null }
```

O service normaliza qualquer escolha de "atividade geral" para `null` antes de chamar a RPC.

## Estados de UI

- Botao sem capacidade nao deve ser renderizado.
- Se a capacidade existe mas a RPC rejeita por ownership, exibir toast de erro de permissao sem mutar a lista local.
- Detalhes de Propostas e Contratos devem ter botao de fechar visivel e suporte a Esc.
- Cliente inativo deve exibir `Reativar Contato` apenas com `clientes.reativar`.
