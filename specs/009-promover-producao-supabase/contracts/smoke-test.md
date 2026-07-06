# Contract: Remote Smoke Test

## Purpose

Validar que producao possui schema, Storage, RPCs, Auth e Edge Function suficientes para a exportacao de relatorios antes de trocar `.env.local`.

## Preconditions

- Schema aplicado com sucesso.
- Edge Function `relatorios-exportacao` publicada.
- Secrets server-side verificados.
- Usuarios temporarios criados para smoke test.
- Nenhuma alteracao de `.env.local` para producao ainda.

## Temporary Users

Required users:
- Um usuario temporario autorizado a exportar relatorios.
- Um usuario temporario sem permissao de exportacao.

Rules:
- Usuarios devem ser identificaveis como temporarios.
- Usuarios devem ser removidos ou desativados ao final.
- Falha na limpeza deve bloquear encerramento da validacao operacional.

## Required Scenarios

### ST-001 Authorized Export

**Given** usuario temporario autorizado autenticado  
**When** executa exportacao permitida pela feature 008  
**Then** a funcao remota gera ou disponibiliza arquivo e registra historico conforme contrato da feature 008.

### ST-002 Unauthorized Block

**Given** usuario temporario sem capacidade de exportacao autenticado  
**When** tenta gerar ou baixar exportacao  
**Then** o backend bloqueia a acao e nenhum arquivo e gerado.

### ST-003 File Privacy

**Given** arquivo gerado pelo usuario autorizado  
**When** o acesso e solicitado pelo fluxo autorizado  
**Then** o download usa autorizacao atual e nao depende de URL publica permanente.

### ST-004 Cleanup

**Given** usuarios temporarios criados para smoke test  
**When** a validacao termina  
**Then** todos os usuarios temporarios sao removidos ou desativados e o resultado e documentado.

## Pass Criteria

- ST-001 passa.
- ST-002 passa.
- ST-003 passa.
- ST-004 passa.

## Block Criteria

Qualquer falha bloqueia:
- Alteracao de `.env.local`.
- Declaracao de promocao concluida.
- Encerramento sem pendencia documentada.
