> Validating a feature means running through the scenarios in this guide and confirming the outcomes match expectations.

# Quickstart: Validação do Ambiente Aptus

**Feature**: Definição da Stack Tecnológica do Aptus ERP  
**Date**: 2026-06-26  
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Prerequisites

- Node.js LTS (20.x+) instalado.
- Docker instalado e em execução.
- Conta Cloudflare (para deploy futuro).
- Projeto Supabase criado na nuvem (para vinculação futura).

## 1. Clone e instalação

```bash
cd "C:\Users\respl\OneDrive\Aptus Flow\sistema-aptus"
npm install
```

**Expected outcome**: `node_modules/` criado sem erros.

## 2. Inicie o Supabase local

```bash
npx supabase start
```

**Expected outcome**: O CLI reporta todos os serviços healthy e exibe URLs e chaves.

## 3. Valide a saúde dos serviços

```bash
npx supabase status
```

**Expected outcome**: `postgres`, `auth`, `rest`, `storage` reportam `healthy`.

## 4. Execute o frontend localmente

```bash
npm run dev
```

**Expected outcome**: Vite inicia o servidor de dev em `http://localhost:5173` e a aplicação React carrega sem erros.

## 5. Teste a conexão com Supabase

Acesse `http://localhost:5173` e verifique no console do navegador se a chamada inicial ao Supabase REST retorna status 200.

**Expected outcome**: Nenhum erro de CORS ou conexão; resposta `200 OK`.

## 6. Valide migrações locais

```bash
npx supabase db reset
```

**Expected outcome**: O banco é recriado, migrações e seeds aplicados sem erros.

## 7. Valide o build de produção

```bash
npm run build
```

**Expected outcome**: Pasta `dist/` gerada com `index.html` e assets estáticos.

## 8. Executar os testes automatizados

```bash
npm run test
```

**Expected outcome**: O Vitest executa o teste de fumaça da conexão REST com o Supabase e reporta sucesso (testes passando).

## Atalhos de Scripts npm

Para simplificar a orquestração do ambiente local, foram criados atalhos de comando em `package.json`:

- **Iniciar Supabase**: `npm run supabase:start` (executa `npx supabase start`)
- **Parar Supabase**: `npm run supabase:stop` (executa `npx supabase stop`)
- **Status do Ambiente**: `npm run supabase:status` (executa `npx supabase status`)
- **Reset do Banco**: `npm run supabase:reset` (executa `npx supabase db reset`)

## Next Steps

- Vincular o projeto local ao Supabase Cloud: `npx supabase link`.
- Configurar deploys na Cloudflare Pages a partir de pushes na branch `main`.
- Promover migrações validadas: `npm run supabase:reset` (para testar local) -> `npx supabase db push` (para aplicar em cloud).

