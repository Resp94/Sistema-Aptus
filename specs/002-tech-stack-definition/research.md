# Research Notes: Definição da Stack Tecnológica

**Feature**: Definição da Stack Tecnológica do Aptus ERP  
**Date**: 2026-06-26  
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Decisions

### DEC-001 — Hospedagem do frontend na Cloudflare

- **Decision**: Utilizar Cloudflare Pages para hospedar o frontend estático do Aptus ERP.
- **Rationale**:
  - CDN global embutido, reduzindo latência para usuários em qualquer região.
  - Integração nativa com Git para deploy contínuo a partir do repositório.
  - Suporte a previews por branch, útil para validação antes de merge.
  - Limite generoso no plano gratuito para projetos de pequeno porte.
- **Alternatives considered**:
  - Vercel: também adequado, mas Cloudflare foi explicitamente solicitado pelo usuário.
  - Netlify: similar, mas sem a vantagem de edge network da Cloudflare.
  - Hospedagem própria: adiciona custo e sobrecarga operacional desnecessários para um ERP interno.
- **Implications**: O build do frontend deve produzir assets estáticos compatíveis com Cloudflare Pages (HTML/JS/CSS). Edge functions podem ser usadas no futuro, mas não são obrigatórias para a stack base.

### DEC-002 — Backend, banco de dados e autenticação via Supabase

- **Decision**: Utilizar Supabase como plataforma unificada de backend, banco de dados PostgreSQL e autenticação.
- **Rationale**:
  - PostgreSQL gerenciado com Row Level Security (RLS) para controle de acesso granular.
  - Autenticação integrada (email/senha, magic link, OAuth, etc.) reduzindo código customizado.
  - APIs REST e GraphQL geradas automaticamente a partir do schema.
  - Real-time subscriptions para funcionalidades que precisem de atualização em tempo real.
- **Alternatives considered**:
  - Firebase: bom para prototipagem, mas menos flexível para queries relacionais complexas.
  - Backend próprio (Node/Express + Postgres): oferece controle total, mas aumenta significativamente o tempo de desenvolvimento e manutenção.
  - AWS Amplify: mais complexo e com curva de aprendizado maior.
- **Implications**: O schema deve ser modelado em PostgreSQL, as migrações versionadas e o acesso ao banco deve passar pelas APIs do Supabase para aproveitar RLS.

### DEC-003 — Frontend com Vite + React + TypeScript

- **Decision**: Construir o frontend com Vite como build tool, React como biblioteca de UI e TypeScript como linguagem.
- **Rationale**:
  - Vite oferece HMR rápido e build otimizado, melhorando a produtividade da equipe.
  - React é a diretriz global do projeto (AGENTS.md lista "vite + react").
  - TypeScript reduz erros em tempo de execução e melhora a manutenibilidade de um ERP que crescerá ao longo do tempo.
- **Alternatives considered**:
  - Next.js: adiciona complexidade de SSR/SSG desnecessária para um ERP interno.
  - Vue + Vite: opção válida, mas React já é a direção do projeto.
  - Manter HTML/CSS/JS puro: inviável à medida que o sistema cresce em estado e interatividade.
- **Implications**: O projeto precisará de `package.json`, `vite.config.ts`, `tsconfig.json` e reestruturação das telas HTML em componentes React.

### DEC-004 — Desenvolvimento local via Supabase CLI + Docker

- **Decision**: Usar Supabase CLI para orquestrar localmente o PostgreSQL, Auth, Storage e Edge Functions via Docker.
- **Rationale**:
  - O Supabase CLI inicia containers Docker que espelham os serviços da nuvem.
  - Permite desenvolver e testar sem custo e sem risco de afetar dados de produção.
  - Migrações e seeds são versionados e podem ser aplicados tanto local quanto na nuvem.
- **Alternatives considered**:
  - Desenvolver direto contra a nuvem: arriscado, lento e impossibilita testes destrutivos.
  - PostgreSQL local manual + Auth customizado: alta complexidade de setup e manutenção.
- **Implications**: Cada desenvolvedor precisa ter Docker disponível. O arquivo `supabase/config.toml` deve ser versionado e configurado para apontar para o projeto correto na nuvem quando vinculado.

### DEC-005 — Processo de promoção local → nuvem

- **Decision**: As mudanças em migrações/configurações do Supabase são validadas localmente antes de serem aplicadas na nuvem via `supabase db push` (ou equivalente).
- **Rationale**:
  - Garante que o schema na nuvem só receba alterações testadas.
  - Reduz risco de downtime ou corrupção de dados.
  - Alinha-se ao critério SC-004 (no máximo 2 passos manuais documentados).
- **Implications**: O processo deve ser documentado em `docs/stack.md` e no `quickstart.md`. CI/CD pode automatizar a validação futuramente.

## Open Questions

Nenhum. Todas as decisões de stack foram resolvidas com base nos requisitos fornecidos.

## References

- [Supabase CLI Local Development](https://supabase.com/docs/guides/cli/local-development)
- [Cloudflare Pages](https://developers.cloudflare.com/pages/)
- [Vite](https://vitejs.dev/)
- [React](https://react.dev/)
