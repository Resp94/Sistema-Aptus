# Quickstart: Validacao do Padrao Enterprise de Relatorios

## Prerequisites

- Dependencias instaladas
- Ambiente Supabase disponivel
- Feature 008 de exportacao existente como baseline
- Usuario com permissao de exportar relatorios

## Validation Commands

```bash
npm run test
npm run build
```

## Manual Validation Scenarios

### 1. Download imediato de PDF sem preview

1. Acessar `/relatorios`
2. Gerar um relatorio PDF em categoria suportada
3. Confirmar que o download inicia sem abrir preview
4. Confirmar que a pagina continua na rota de relatorios

### 2. Leitura do PDF executivo

1. Abrir o arquivo baixado
2. Confirmar titulo, periodo, solicitante e validade em PT-BR
3. Confirmar resumo executivo sem `label:` ou `valor:`
4. Confirmar detalhes legiveis e coerentes com a categoria

### 3. Exportacao tabular operacional

1. Gerar ou baixar um artefato tabular
2. Confirmar nomenclatura operacional, nao executiva
3. Confirmar encoding legivel e headers compreensiveis

### 4. Historico de itens expirados

1. Localizar item expirado no historico
2. Confirmar badge/estado `Expirado`
3. Confirmar ausencia de download disponivel

## Expected Outcomes

- PDF baixa sem preview em todos os fluxos cobertos
- PDF apresenta padrao executivo consistente
- Exportacao tabular nao se apresenta como documento enterprise
- Historico comunica disponibilidade e validade com clareza
