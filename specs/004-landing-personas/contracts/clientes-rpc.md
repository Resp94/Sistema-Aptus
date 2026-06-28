# Contrato RPC: Módulo Clientes / Fornecedores

Todas as funções são `SECURITY DEFINER`, validam RBAC via `permissao_modulo('clientes')` e são chamadas pelo frontend via `supabase.rpc(...)`. Erros são lançados como exceções PostgreSQL e chegam ao frontend em `error.message`.

Módulo RBAC: `clientes`. Leitura exige `pode_ler`; escrita exige `pode_escrever`.

> **Retorno vazio**: todas as RPCs de leitura retornam conjunto vazio (`TABLE` sem linhas) ou objeto com listas vazias quando não há dados — nunca `null` quebrado —, sustentando o estado vazio das telas (FR-007, SC-004).

---

## Leitura

### `listar_clientes(p_tipo text default null, p_busca text default null, p_status text default null)`

Lista contatos do tipo informado, com busca e filtro de status opcionais.

- **Gate**: `pode_ler('clientes')`, senão exceção `Sem permissão de leitura`.
- **Parâmetros**: `p_tipo` (`cliente`|`fornecedor`|null = ambos), `p_busca` (nome/empresa/e-mail, ILIKE), `p_status` (`Ativo`|`Inativo`|null).
- **Retorno** `TABLE`: `id uuid, nome_contato text, empresa text, email text, telefone text, tipo text, status text, receita numeric`.
  - `receita` = soma de `lancamentos.valor` do tipo `receita` vinculados ao cliente.
- **Ordenação**: por `receita` desc.

### `obter_estatisticas_clientes()`

Stats bar da landing.

- **Gate**: `pode_ler('clientes')`.
- **Retorno** `TABLE`: `total_contatos int, receita_acumulada numeric, ativos int, fornecedores int`.

### `obter_cliente_detalhe(p_cliente_id uuid)`

Painel de detalhes + histórico de atendimento.

- **Gate**: `pode_ler('clientes')`.
- **Retorno** `json`:
  ```json
  {
    "id": "uuid",
    "nome_contato": "Lucas Andrade",
    "empresa": "Inovatec",
    "email": "lucas@inovatec.com",
    "telefone": "(11) 99999-0001",
    "tipo": "cliente",
    "status": "Ativo",
    "receita": 142300.00,
    "historico": [
      { "id": "uuid", "data": "2026-06-20", "descricao": "Reunião de alinhamento", "responsavel": "Comercial Persona" }
    ]
  }
  ```
- **Erro**: `Cliente não encontrado` quando id inexistente.

---

## Escrita

### `criar_cliente(p_nome_contato text, p_empresa text, p_email text, p_telefone text, p_tipo text)`

- **Gate**: `pode_escrever('clientes')`, senão exceção `Sem permissão de escrita`.
- **Validação**: `p_tipo` ∈ {`cliente`,`fornecedor`}; `p_nome_contato`/`p_empresa` não vazios.
- **Efeito**: insere `clientes` com `status='Ativo'`, `created_by=auth.uid()`.
- **Retorno**: `uuid` (id criado).

### `atualizar_cliente(p_cliente_id uuid, p_nome_contato text, p_empresa text, p_email text, p_telefone text, p_tipo text, p_status text)`

- **Gate**: `pode_escrever('clientes')`.
- **Validação**: mesmos CHECKs; `p_status` ∈ {`Ativo`,`Inativo`}.
- **Efeito**: atualiza o registro; `updated_at=now()`.
- **Retorno**: `void`. **Erro**: `Cliente não encontrado`.

### `inativar_cliente(p_cliente_id uuid)`

Exclusão lógica (soft delete) — ação "excluir" da UI.

- **Gate**: `pode_escrever('clientes')`.
- **Efeito**: `status='Inativo'`. Mantém lançamentos/atendimentos vinculados. **Audita**: chama `registrar_evento_auditoria('cliente_inativado', auth.uid(), null, null)` — `p_ip_origem`/`p_user_agent` são `null` (sem contexto HTTP em RPC `SECURITY DEFINER`) (FR-015).
- **Retorno**: `void`.

### `registrar_atendimento(p_cliente_id uuid, p_descricao text, p_data date default current_date)`

- **Gate**: `pode_escrever('clientes')`.
- **Efeito**: insere `atendimentos` com `responsavel_id=auth.uid()`.
- **Retorno**: `uuid` (id do atendimento). **Erro**: `Cliente não encontrado`.
