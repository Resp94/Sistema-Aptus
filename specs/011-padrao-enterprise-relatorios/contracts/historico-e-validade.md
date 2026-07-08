# Contract: Historico e Validade

## Objective

Preservar a rastreabilidade da exportacao e comunicar estados de disponibilidade com clareza.

## Required Statuses

| Estado | Icone | Aparencia | Acao Disponivel |
|--------|-------|-----------|-----------------|
| `Pronto` | Check verde | Texto normal | Botao "Baixar" ativo |
| `Falhou` | X vermelho | Texto normal + opacidade reduzida | Nenhuma (apenas informativo) |
| `Expirado` | Relogio cinza | Badge "Expirado" + tooltip | Botao "Baixar" desabilitado + tooltip |
| `Indisponivel` | Proibido cinza | Linha com opacidade 50% | Nenhuma (legado/fora de contrato) |

## History Rules

- Itens continuam ordenados do mais recente para o mais antigo, inclusive itens expirados (mantem posicao cronologica).
- Itens expirados permanecem visiveis no historico.
- O usuario deve entender, pela propria linha do historico, se o item e executivo (badge "PDF" azul) ou operacional (badge "CSV" cinza).
- O download so aparece como acao disponivel quando o item estiver apto para entrega.

## Expired Behavior

- `Expirado` bloqueia download.
- O historico continua exibindo periodo, formato e validade.
- Tooltip exibe: "Este relatorio expirou em DD/MM/AAAA. Gere um novo para o mesmo periodo."
- O bloqueio deve parecer regra de negocio, nao defeito de interface.
