# Sistema Aptus Constitution

## Core Principles

### I. Spec-Driven Delivery

Toda feature MUST ter uma especificação ativa (`spec.md`) com requisitos funcionais (FR-###), critérios de sucesso mensuráveis (SC-###) e user stories com cenários de aceitação antes do início da implementação. O plano de implementação (`plan.md`) MUST ser derivado da spec, e as tarefas (`tasks.md`) MUST cobrir todos os FRs e SCs buildáveis. Features sem spec ativa não entram em fase de implementação.

### II. RPC-First / Backend Authorization

Toda lógica de negócio e autorização MUST residir no backend (Supabase RPC + Edge Functions). O frontend React NEVER toma decisões de autorização — apenas renderiza estados recebidos e inicia ações autorizadas. Nenhuma validação de permissão no lado do cliente substitui a validação no backend. URLs assinadas de Storage MUST ser de curta duração e nunca expostas publicamente.

### III. RBAC by Named Capabilities

Permissões MUST ser modeladas como capacidades nomeadas (ex: `relatorios.exportar`, `projetos.editar`) e verificadas no backend via RLS/RPC. O frontend MUST usar os mesmos nomes de capacidade para controle de UI (ex: desabilitar botão, esconder seção), mas apenas como conveniência de UX — nunca como mecanismo de segurança. Novas capacidades MUST ser documentadas no schema e nos contratos.

### IV. No Mock Success

Nenhum teste, validação manual ou checklist pode ser considerado aprovado com dados mockados ou cenários simulados que não reflitam o ambiente real. Testes de aceite MUST usar o stack real (Supabase, Edge Functions, Storage privado). O artefato final entregue ao usuário (PDF, CSV) MUST ser gerado pelo pipeline real e validado visualmente. Estados de erro e empty states MUST ser testados com dados reais ou fixtures que reproduzam fielmente o payload do backend.

### V. Auditability & Documentation

Toda decisão de arquitetura, mudança de contrato ou regra de negócio MUST ser registrada nos artefatos da feature (`research.md`, `data-model.md`, `contracts/`) e na memória do projeto (`.agents/`, `.sauron/`). O histórico de exportações e ações do usuário MUST ser rastreável. Features concluídas MUST atualizar a memória das features relacionadas (ex: feature 011 atualiza memória da feature 008).

### VI. Supabase Security

O bucket de Storage para artefatos exportados MUST permanecer privado. Nenhuma URL pública permanente pode ser gerada. O frontend NEVER deve ter acesso à service role key. Tokens JWT de usuário MUST ser usados para todas as chamadas autenticadas. RLS policies MUST ser revisadas a cada feature que toca o schema.

## Security Requirements

- Storage bucket `relatorios-exportados`: privado, sem políticas públicas.
- URLs assinadas: duração máxima de 10 minutos (`DOWNLOAD_EXPIRES_IN = 600`).
- Edge Functions: validam JWT antes de qualquer operação.
- Frontend: nunca expõe `service_role` key; usa apenas `anon` key + JWT do usuário.
- RLS: todas as tabelas com dados de usuário devem ter políticas RLS ativas.

## Development Workflow

1. **Specify**: Feature spec com FRs, SCs, user stories e edge cases.
2. **Plan**: Pesquisa técnica, modelo de dados, contratos e constitution check.
3. **Tasks**: Tarefas ordenadas por dependência, com testes antes de implementação.
4. **Implement**: Testes → implementação → validação manual → documentação.
5. **Analyze**: Cross-artifact consistency check antes de merge.

**Quality Gates**:
- Constitution check MUST passar antes de Phase 0 research e após Phase 1 design.
- Checklist de export quality MUST ter todos os itens resolvidos.
- `npm run test` e `npm run build` MUST passar.
- Validação manual no navegador MUST cobrir todos os cenários do quickstart.

## Governance

Esta constituição tem autoridade sobre todas as práticas de desenvolvimento do projeto. Qualquer violação de um princípio MUST requer ajuste da spec, plan ou tasks — nunca diluição ou reinterpretação do princípio. Alterações na constituição MUST ser feitas via `/speckit-constitution` com documentação, aprovação e plano de migração quando aplicável.

**Version**: 1.0.0 | **Ratified**: 2026-07-08 | **Last Amended**: 2026-07-08
