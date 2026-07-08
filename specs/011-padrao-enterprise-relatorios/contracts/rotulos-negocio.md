# Contract: Rotulos de Negocio (Translation Map)

**Objective**: Mapear todas as chaves internas do payload da RPC `iniciar_exportacao_relatorio` para rótulos de negócio em PT-BR, utilizados tanto no PDF executivo quanto no CSV tabular.

**Source**: Payload real das funções `public.montar_payload_relatorio_*` (migration `20260704235640_exportar_relatorios.sql`).

---

## Regra Geral para Resumo (`resumo`)

O array `resumo` em TODAS as categorias segue a estrutura `{ "label": string, "valor": number }`. Regra de renderização:

- **NÃO** renderizar a chave `label` como texto — usar o **valor** de `label` como rótulo de exibição.
- **NÃO** renderizar a chave `valor` como texto — usar o **valor** de `valor` como dado, formatado conforme o tipo (moeda BRL para valores financeiros, número inteiro para contagens, número decimal para horas).
- Exemplo: `{ "label": "Receitas", "valor": 15000.00 }` → renderiza como **"Receitas: R$ 15.000,00"**.

---

## Mapas de Tradução por Categoria — Detalhes (`detalhes`)

### Financeiro

| Chave Interna | Rótulo de Negócio | Formato |
|--------------|-------------------|---------|
| `data` | Data | DD/MM/AAAA |
| `tipo` | Tipo | Texto: "Receita" ou "Despesa" |
| `natureza` | Natureza | Texto |
| `status` | Status | Texto: "Pago" ou "Pendente" |
| `categoria` | Categoria | Texto |
| `descricao` | Descrição | Texto |
| `cliente` | Cliente | Texto |
| `projeto` | Projeto | Texto |
| `valor` | Valor | Moeda BRL |

### DRE

| Chave Interna | Rótulo de Negócio | Formato |
|--------------|-------------------|---------|
| `data` | Data | DD/MM/AAAA |
| `grupo_dre` | Grupo DRE | Texto |
| `categoria` | Categoria | Texto |
| `descricao` | Descrição | Texto |
| `valor` | Valor | Moeda BRL |

### Clientes

| Chave Interna | Rótulo de Negócio | Formato |
|--------------|-------------------|---------|
| `id` | ID | UUID |
| `nome_contato` | Nome do Contato | Texto |
| `empresa` | Empresa | Texto |
| `email` | E-mail | Texto |
| `telefone` | Telefone | Texto |
| `tipo` | Tipo | Texto |
| `status` | Status | Texto |
| `criado_em` | Criado em | DD/MM/AAAA HH:mm |
| `atualizado_em` | Atualizado em | DD/MM/AAAA HH:mm |
| `atendimentos_no_periodo` | Atendimentos no Período | Número inteiro |

### Projetos

| Chave Interna | Rótulo de Negócio | Formato |
|--------------|-------------------|---------|
| `id` | ID | UUID |
| `nome` | Nome | Texto |
| `cliente` | Cliente | Texto |
| `status` | Status | Texto |
| `prazo` | Prazo | DD/MM/AAAA |
| `responsavel` | Responsável | Texto |
| `progresso` | Progresso | Porcentagem (ex: "45%") |
| `orcamento` | Orçamento | Moeda BRL |
| `orcamento_utilizado` | Orçamento Utilizado | Moeda BRL |
| `horas_apontadas_no_periodo` | Horas Apontadas no Período | Número decimal (ex: "45,50h") |
| `tarefas_concluidas_no_periodo` | Tarefas Concluídas no Período | Número inteiro |

---

## Aplicação Cruzada (PDF + CSV)

- **PDF**: Os mapas acima regem títulos de coluna na seção "Detalhes" e nomes de indicadores na seção "Resumo Executivo".
- **CSV**: Os MESMOS mapas regem os headers das colunas em `resumo.csv` e `detalhes.csv`. Não há mapa separado para CSV.
- **Fallback**: Se uma chave não estiver no mapa de sua categoria, usar a própria chave como rótulo (comportamento seguro).

---

## Implementação

O mapa será codificado como dicionário estático em `supabase/functions/relatorios-exportacao/renderers.ts`, organizado por categoria:

```ts
const LABEL_MAP: Record<string, Record<string, string>> = {
  Financeiro: { data: 'Data', tipo: 'Tipo', /* ... */ },
  DRE: { data: 'Data', grupo_dre: 'Grupo DRE', /* ... */ },
  Clientes: { id: 'ID', nome_contato: 'Nome do Contato', /* ... */ },
  Projetos: { id: 'ID', nome: 'Nome', /* ... */ },
}
```
