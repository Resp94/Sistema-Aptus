# Contract: Comercial RPC

Abrange Propostas, Contratos e Cobrancas. Todas as funcoes validam autenticacao e RBAC.

## Propostas

### `listar_propostas(p_status text, p_cliente_id uuid, p_busca text)`

Retorna `id`, `cliente`, `titulo`, `valor`, `status`, `enviada_em`, `created_at`.

### `obter_proposta_detalhe(p_id uuid)`

Retorna proposta, cliente, historico de status e contrato originado quando existir.

### `criar_proposta(payload jsonb)`

Campos obrigatorios: `cliente_id`, `titulo`, `valor`.

### `atualizar_proposta(p_id uuid, payload jsonb)`

Atualiza titulo, descricao, valor e status permitido.

### `registrar_envio_proposta(p_id uuid)`

Se nao houver integracao de e-mail, atualiza estado para pendente/indisponivel e retorna mensagem clara. Nao retorna sucesso falso.

## Contratos

### `listar_contratos(p_status text, p_cliente_id uuid, p_busca text)`

Retorna `id`, `cliente`, `titulo`, `data_inicio`, `data_fim`, `status_exibicao`, `valor_recorrente`.

### `obter_contrato_detalhe(p_id uuid)`

Retorna contrato, proposta de origem, documentos, cobrancas vinculadas.

### `criar_contrato(payload jsonb)`

Campos obrigatorios: `cliente_id`, `titulo`, `data_inicio`, `data_fim`.

### `renovar_contrato(p_id uuid, p_nova_data_fim date)`

Atualiza vigencia e registra auditoria quando aplicavel.

### `encerrar_contrato(p_id uuid, p_motivo text)`

Marca como encerrado e audita.

## Cobrancas

### `listar_cobrancas(p_status text, p_cliente_id uuid, p_data_inicio date, p_data_fim date)`

Retorna `id`, `cliente`, `contrato`, `valor`, `data_vencimento`, `status_exibicao`, `boleto_status`, `lembrete_status`.

### `obter_cobranca_detalhe(p_id uuid)`

Retorna cobranca, pagamentos, contrato, cliente e lancamento financeiro associado.

### `criar_cobranca(payload jsonb)`

Cria cobranca e opcionalmente lancamento financeiro `a_receber`.

Regra de duplicidade: se o payload apontar contrato/competencia/valor ja representado por cobranca ou `lancamento_id` existente, a funcao deve rejeitar a duplicidade ou retornar o registro existente explicitamente.

### `registrar_pagamento_cobranca(p_id uuid, payload jsonb)`

Registra pagamento e sincroniza lancamento associado quando existir.

### `solicitar_emissao_boleto(p_id uuid)`

Sem integracao externa configurada, retorna estado `Indisponivel`/`Pendente de integracao`, sem boleto falso.

### `solicitar_lembrete_cobranca(p_id uuid)`

Sem integracao externa configurada, registra pendencia/indisponibilidade, sem envio falso.

## Ownership de `cobrancas`

- Comercial: criar cobranca comercial, acompanhar status, solicitar lembrete, consultar vinculo com cliente/contrato.
- Financeiro: registrar pagamento, conciliar/cancelar cobranca financeira, criar/atualizar lancamento associado.
- Administrador: ambos.
- Perfil com leitura em `cobrancas` mas sem escrita financeira nao recebe acoes de pagamento/conciliacao e a RPC rejeita tentativa direta.

## Resultados de integracao ausente

| Funcao | Estado sem integracao |
|---|---|
| `registrar_envio_proposta` | envio `Indisponivel` ou `Pendente de integracao`; status comercial nao muda para enviado por falso sucesso |
| `solicitar_emissao_boleto` | `boleto_status = 'Nao configurado'` ou `Indisponivel`; `boleto_url` nulo |
| `solicitar_lembrete_cobranca` | `lembrete_status = 'Indisponivel'` ou `Pendente`; nenhum envio registrado como concluido |
