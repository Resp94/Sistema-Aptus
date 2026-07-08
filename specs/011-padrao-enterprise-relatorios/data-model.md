# Data Model: Padrao Enterprise Relatorios

## Overview

Esta feature nao introduz novas tabelas obrigatorias. Ela redefine o comportamento e a apresentacao dos artefatos ja suportados pela feature 008.

## Entities

### 1. Solicitacao de Exportacao

**Purpose**: Representa o pedido do usuario por um relatorio exportado.

**Fields**:
- `tipo`
- `formato`
- `data_inicial`
- `data_final`
- `solicitante`
- `status`

**Validation rules**:
- `tipo` deve corresponder a uma categoria exportavel.
- `formato` deve distinguir documento executivo (`PDF`) de exportacao operacional tabular.
- `data_inicial` e `data_final` seguem a regra vigente de periodo.

### 2. Artefato Executivo

**Purpose**: Documento PDF voltado a leitura institucional e executiva.

**Fields**:
- `titulo`
- `categoria`
- `periodo`
- `solicitante`
- `gerado_em`
- `expira_em`
- `resumo_executivo`
- `detalhes`
- `mensagem_sem_dados`

**Relationships**:
- Deriva de uma `Solicitacao de Exportacao`.
- Usa os mesmos metadados de historico do registro de exportacao.

**Validation rules**:
- Nao pode expor chaves internas do payload.
- Deve usar linguagem PT-BR e empty state legivel.
- Deve manter identidade visual consistente entre categorias.

### 3. Exportacao Tabular

**Purpose**: Artefato operacional para manipulacao de dados por usuario administrativo.

**Fields**:
- `arquivo_nome`
- `mime_type`
- `resumo_tabular`
- `detalhes_tabulares`
- `headers`
- `encoding`

**Relationships**:
- Deriva da mesma `Solicitacao de Exportacao`.
- Compartilha historico, validade e autorizacao com o artefato executivo.

**Validation rules**:
- Deve ser identificado como exportacao operacional, nao como documento executivo.
- Deve sair com encoding legivel em ferramentas comuns de escritorio.
- Deve usar headers de negocio mesmo quando nao houver detalhes.

### 4. Item de Historico de Exportacao

**Purpose**: Registro consultavel do resultado de exportacao.

**Fields**:
- `id`
- `tipo`
- `formato`
- `status_exibicao`
- `arquivo_nome`
- `gerado_em`
- `expira_em`
- `pode_baixar`
- `criado_por`
- `criado_por_nome`

**State transitions**:
- `Processando` → `Pronto`
- `Processando` → `Falhou`
- `Pronto` → `Expirado` (estado exibido a partir da validade)

**Validation rules**:
- Item expirado permanece visivel.
- `pode_baixar` e falso quando a validade expira.
- O rotulo do formato precisa refletir o artefato real entregue.

## Derived View Rules

- `PDF` = documento executivo oficial.
- `CSV/ZIP` = exportacao operacional.
- `Expirado` sempre prevalece sobre o botao de download.
- `Sem dados` deve aparecer como mensagem de negocio, nunca como dump tecnico.
