# Contract: Matriz de Capacidades

Este contrato define a fonte canonica de autorizacao de acoes.

## Tabela

```sql
public.capacidades_perfil(
  perfil_acesso text not null,
  capacidade text not null,
  primary key (perfil_acesso, capacidade)
)
```

## Regras

- `capacidade` usa o formato `recurso.acao`.
- Um perfil sem linha na tabela nao possui capacidades.
- `Visualizador` deve existir como perfil tecnico, mas nao deve ter linhas de capacidade.
- A matriz inicial e criada por migration e validada por pgTAP.
- Uma UI administrativa futura podera editar linhas, mas esta fora do escopo atual.

## Matriz Esperada

| Perfil | Capacidades |
|--------|-------------|
| Administrador | Todas as capacidades catalogadas |
| Financeiro | `financeiro.lancar`, `financeiro.editar_lancamento`, `financeiro.baixar_lancamento`, `cobrancas.emitir`, `cobrancas.baixar`, `relatorios.exportar`, `configuracoes.editar_proprio_perfil` |
| Projetos | `projetos.criar`, `projetos.editar`, `projetos.excluir`, `tarefas.criar`, `tarefas.excluir`, `tarefas.editar_qualquer`, `tarefas.mover_qualquer`, `equipe.adicionar_membro`, `equipe.alocar`, `equipe.inativar_membro`, `apontamentos.registrar_qualquer`, `relatorios.exportar`, `configuracoes.editar_proprio_perfil` |
| Comercial | `clientes.criar`, `clientes.editar`, `clientes.inativar`, `clientes.reativar`, `clientes.registrar_atendimento`, `propostas.criar`, `propostas.editar`, `propostas.enviar`, `propostas.gerar_contrato`, `contratos.criar`, `contratos.renovar`, `contratos.encerrar`, `cobrancas.emitir`, `cobrancas.boleto`, `cobrancas.notificar`, `configuracoes.editar_proprio_perfil` |
| Técnico | `tarefas.editar_propria`, `tarefas.mover_propria`, `apontamentos.registrar_proprio`, `configuracoes.editar_proprio_perfil` |
| Visualizador | Nenhuma capacidade |

## Leitura por Modulo

`obter_permissoes_usuario()` permanece como contrato de rota/menu/leitura.

| Perfil | Leitura de modulo esperada |
|--------|----------------------------|
| Administrador | Todos os modulos |
| Financeiro | Dashboard, financeiro, fluxo-caixa, contas-pagar, contas-receber, cobrancas, relatorios, configuracoes proprias |
| Projetos | Projetos, equipe, relatorios, configuracoes proprias |
| Comercial | Clientes, propostas, contratos, cobrancas, configuracoes proprias |
| Técnico | Projetos alocados, equipe limitada, configuracoes proprias |
| Visualizador | Relatorios e configuracoes proprias somente |

## Testes Obrigatorios

- Administrador tem contagem igual ao catalogo total.
- Visualizador tem contagem zero.
- Tecnico tem exatamente quatro capacidades.
- Comercial nao possui `cobrancas.baixar`.
- Financeiro nao possui `cobrancas.boleto` nem `cobrancas.notificar`, salvo decisao futura explicita.
- Qualquer capacidade fora do catalogo reprova o teste.
