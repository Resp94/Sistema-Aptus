# Design — Preferências de Notificações como estado "Em breve"

**Data:** 2026-07-08
**Contexto:** `src/pages/ConfiguracoesPage.tsx`, `src/services/configuracoes.service.ts`, `supabase/seed.sql`

## Problema

A seção **Preferências de Notificações** da aba `Minha Conta` hoje comunica uma capacidade que o produto não entrega.

- O frontend renderiza toggles reais e tenta ler/salvar preferências por RPC.
- O backend persiste preferências por perfil, mas essas preferências **não dirigem nenhuma entrega real de notificação** no sistema.
- Em ambientes sem seed completo, a lista pode aparecer vazia, o que reforça a percepção de bug.
- Mesmo quando a lista aparece, a experiência continua enganosa: o usuário altera controles que não produzem efeito de negócio.

Isso caracteriza uma feature cosmética com semântica falsa. O problema principal não é seed, e sim **promessa de produto sem implementação correspondente**.

## Objetivo

Preservar a intenção futura da funcionalidade sem induzir o usuário ao erro.

O estado desejado é:

- manter a presença da seção na página de `Configurações`;
- remover a aparência de configuração ativa;
- substituir os toggles por um estado estático e honesto de **`Em breve`**;
- eliminar a dependência visual de dados seedados ou preferências previamente cadastradas.

## Abordagens consideradas

### 1. Placeholder honesto na própria seção

Manter o card de notificações, mas trocar os toggles por um conteúdo estático com badge/status `Em breve` e texto explicativo curto.

**Vantagens**
- preserva o espaço do roadmap no produto;
- evita falsa impressão de funcionalidade pronta;
- remove a dependência do seed e da leitura RPC para a experiência principal;
- implementação pequena e reversível.

**Desvantagens**
- a feature continua visível mesmo sem entrega funcional.

### 2. Toggles desabilitados com rótulo "Em breve"

Manter a UI atual, mas deixar os controles desabilitados.

**Vantagens**
- mostra o formato futuro com mais fidelidade.

**Desvantagens**
- continua parecendo feature quebrada ou bloqueada;
- reforça a pergunta "por que existe um controle que não posso usar?".

### 3. Remover a seção inteira

Ocultar o card até existir backend e entrega reais.

**Vantagens**
- elimina completamente a inconsistência visual.

**Desvantagens**
- perde contexto de roadmap;
- faz a tela parecer menor e muda mais o produto do que o necessário.

## Decisão aprovada

Seguir a **Abordagem 1**.

A seção continua existindo, mas passa a representar claramente uma funcionalidade planejada, e não uma configuração disponível hoje.

## Design proposto

### Experiência do usuário

Na aba `Minha Conta`:

- o card continua com o título `Preferências de Notificações`;
- abaixo do título, o usuário vê um estado estático com:
  - badge ou label `Em breve`;
  - mensagem curta, por exemplo: `As notificações personalizadas por canal serão disponibilizadas em uma próxima versão.`

O card não deve conter:

- toggles interativos;
- lista de tipos/canais vindos do backend;
- ações de salvar;
- mensagens de sucesso ligadas a preferências.

### Comportamento técnico

- `ConfiguracoesPage` deixa de depender de `listarPreferenciasNotificacoes()` para renderizar essa seção.
- O fluxo de toggle (`handleTogglePreferencia`) deixa de participar da experiência da página enquanto a funcionalidade estiver em `Em breve`.
- A tabela, RPCs e seeds de `preferencias_notificacoes` podem permanecer intactos nesta etapa, mas passam a ser tratadas como infraestrutura dormente, não como feature ativa.

### Conteúdo e linguagem

O texto deve ser direto e não prometer data.

Requisitos de copy:

- deixar claro que a personalização ainda não está disponível;
- evitar linguagem de erro, bloqueio ou falha;
- não sugerir que o usuário precise configurar algo agora.

## Critérios de aceitação

1. A seção `Preferências de Notificações` continua visível em `Configurações > Minha Conta`.
2. Nenhum toggle de notificação é exibido.
3. A seção mostra explicitamente o estado `Em breve`.
4. A experiência da página não depende de linhas em `public.preferencias_notificacoes`.
5. O usuário não recebe feedback de "preferência salva" nessa seção.
6. A UI não comunica que notificações personalizadas já funcionam hoje.

## Impacto em arquitetura e produto

- **Produto**: corrige uma promessa falsa sem remover a intenção futura da funcionalidade.
- **Frontend**: simplifica a renderização da página e elimina um estado vazio confuso.
- **Backend**: nenhuma mudança obrigatória nesta etapa; o contrato existente pode permanecer sem uso ativo.
- **Seeds**: deixam de ser requisito para essa parte da experiência.

## Fora de escopo

- implementar sino na navbar;
- criar central de notificações;
- ativar envio real por e-mail, sistema ou relatório semanal;
- remover tabela/RPCs de `preferencias_notificacoes` do Supabase;
- modelar cronograma de entrega da feature completa.

## Reativação futura

Quando notificações reais existirem, a seção pode voltar a ser interativa. Para isso, a implementação futura deve cumprir duas condições antes de restaurar toggles:

1. existir pelo menos um fluxo real de entrega que consuma as preferências;
2. existir estratégia explícita de defaults para todos os perfis, sem depender de seed oportunista para montar a UI.
