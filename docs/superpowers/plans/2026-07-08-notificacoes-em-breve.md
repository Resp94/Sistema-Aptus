# Notificações Em Breve Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar a seção `Preferências de Notificações` de `Configurações > Minha Conta` em um placeholder honesto `Em breve`, removendo toggles interativos e a dependência visual de RPCs/seeds.

**Architecture:** A implementação fica restrita ao frontend e à documentação funcional. Primeiro fixamos a nova expectativa com testes de regressão da página, depois trocamos a UI por um estado estático e removemos do frontend a superfície morta de leitura/escrita de preferências, mantendo backend e schema Supabase intactos como infraestrutura dormente.

**Tech Stack:** Vite, React, TypeScript, Vitest, Testing Library, documentação local em `docs/`, `.agents` e `.sauron`

---

### Task 1: Fixar o novo comportamento com testes de regressão

**Files:**
- Modify: `src/pages/ConfiguracoesPage.test.tsx`

- [ ] **Step 1: Adicionar teste para o placeholder `Em breve` na aba Minha Conta**

Inserir um teste com esta estrutura no bloco existente:

```tsx
it('exibe placeholder de notificações em breve sem toggles e sem carregar preferências', async () => {
  render(
    <MemoryRouter>
      <ConfiguracoesPage />
    </MemoryRouter>,
  )

  await screen.findByDisplayValue('admin@aptusflow.local')

  expect(screen.getByText('Preferências de Notificações')).toBeInTheDocument()
  expect(screen.getByText(/em breve/i)).toBeInTheDocument()
  expect(
    screen.getByText(/notificações personalizadas por canal/i),
  ).toBeInTheDocument()
  expect(screen.queryByRole('checkbox')).not.toBeInTheDocument()
  expect(mockListarPreferenciasNotificacoes).not.toHaveBeenCalled()
})
```

- [ ] **Step 2: Rodar o teste direcionado para confirmar falha vermelha**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx`

Expected:
- FAIL porque a página ainda renderiza a lista/toggles
- FAIL porque `mockListarPreferenciasNotificacoes` ainda é chamado no carregamento

- [ ] **Step 3: Ajustar o setup de teste para refletir o novo contrato da página**

No `beforeEach`, manter o mock disponível, mas explicitar que ele não deve ser usado no fluxo `Minha Conta`:

```tsx
mockListarPreferenciasNotificacoes.mockResolvedValue([
  {
    id: 'pref-1',
    perfil_id: 'perfil-1',
    canal: 'Email',
    tipo: 'Lembretes',
    ativo: true,
  },
])
```

Objetivo:
- provar que mesmo havendo dados mockados, a tela não depende mais deles

- [ ] **Step 4: Rodar novamente o mesmo teste após o ajuste do mock**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx`

Expected:
- continua FAIL até a implementação real da Task 2
- falha centrada no markup atual e na chamada indevida da RPC

- [ ] **Step 5: Registrar os arquivos alterados para integração**

Listar explicitamente no handoff:
- `src/pages/ConfiguracoesPage.test.tsx`

### Task 2: Implementar o placeholder e remover a superfície morta do frontend

**Files:**
- Modify: `src/pages/ConfiguracoesPage.tsx`
- Modify: `src/pages/ConfiguracoesPage.css`
- Modify: `src/services/configuracoes.service.ts`
- Modify: `src/types/configuracoes.ts`

- [ ] **Step 1: Remover da página o estado e o fluxo de preferências reais**

Aplicar esta limpeza em `src/pages/ConfiguracoesPage.tsx`:

```tsx
import type {
  ConfiguracaoEmpresa,
  UsuarioConfigItem,
  AuditoriaEventoItem,
  CriarUsuarioConfiguracoesPayload,
} from '../types/configuracoes'

const [minhaConta, setMinhaConta] = useState<{ perfil: any; usuario: any } | null>(null)
```

E trocar o carregamento da aba `minha-conta` para:

```tsx
if (activeTab === 'minha-conta') {
  const me = await configuracoesService.obterMinhasConfiguracoes()
  setMinhaConta(me)
  setFormNome(me.perfil?.nome || '')
  setFormDepto(me.perfil?.departamento || '')
}
```

Também remover:
- `PreferenciaNotificacaoItem` do import de tipos
- `preferencias` / `setPreferencias`
- `handleTogglePreferencia`

- [ ] **Step 2: Substituir a lista de toggles por markup estático**

Trocar o bloco atual da seção por algo nesta linha:

```tsx
<div className="card-box flex-col gap-4">
  <div className="coming-soon-header">
    <h2 className="section-title">Preferências de Notificações</h2>
    <span className="coming-soon-badge">Em breve</span>
  </div>
  <p className="text-sm text-muted">
    As notificações personalizadas por canal serão disponibilizadas em uma próxima versão.
  </p>
  <div className="coming-soon-panel">
    <p className="coming-soon-title">Personalização de alertas ainda não disponível</p>
    <p className="coming-soon-copy">
      Quando essa funcionalidade for lançada, você poderá definir como deseja receber alertas e lembretes do sistema.
    </p>
  </div>
</div>
```

- [ ] **Step 3: Atualizar o CSS da seção para o estado `Em breve`**

Substituir/remover os estilos de `.notification-list`, `.notification-item`, `.switch` e `.slider` por estilos focados no placeholder:

```css
.coming-soon-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  flex-wrap: wrap;
}

.coming-soon-badge {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--border-soft);
  border-radius: 999px;
  padding: 4px 10px;
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--accent);
  background: var(--surface-alt);
}

.coming-soon-panel {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  padding: var(--space-4);
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-alt);
}
```

- [ ] **Step 4: Remover do frontend os métodos e tipos mortos ligados a preferências**

Em `src/types/configuracoes.ts`, remover:

```ts
export interface PreferenciaNotificacaoItem {
  id: string
  perfil_id: string
  canal: 'Email' | 'Sistema'
  tipo: 'Lembretes' | 'Alertas' | 'Relatorio semanal' | 'Cobrancas'
  ativo: boolean
}
```

Em `src/services/configuracoes.service.ts`, remover:

```ts
async listarPreferenciasNotificacoes(): Promise<PreferenciaNotificacaoItem[]> { ... }

async atualizarPreferenciasNotificacoes(
  payload: Array<{ canal: string; tipo: string; ativo: boolean }> | { canal: string; tipo: string; ativo: boolean }
): Promise<boolean> { ... }
```

E também retirar `PreferenciaNotificacaoItem` do import do service.

- [ ] **Step 5: Rodar os testes direcionados para validar a nova UX**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx`

Expected:
- PASS
- teste novo confirma `Em breve`
- teste de cadastro de usuário continua verde

### Task 3: Atualizar documentação funcional e memória obrigatória

**Files:**
- Modify: `docs/telas.md`
- Modify: `docs/banco-de-dados.md`
- Modify: `.agents/project-memory/005-demais-telas-perfis.md`
- Modify: `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`

- [ ] **Step 1: Atualizar a descrição funcional da tela Configurações**

Em `docs/telas.md`, substituir a parte de notificações ativas por um estado compatível com o produto atual:

```md
- **Notificações**: card informativo com status `Em breve`, sem toggles ativos nesta etapa
```

E ajustar as ações principais para remover a promessa de “ajustar notificações”.

- [ ] **Step 2: Registrar no documento de banco que a tabela continua existente, mas sem uso ativo na UI**

Adicionar uma observação em `docs/banco-de-dados.md` logo abaixo de `## preferencias_notificacoes`:

```md
Observação atual: em 2026-07-08, a UI de `Configurações > Minha Conta` passou a tratar essa funcionalidade como `Em breve`. A tabela e as RPCs permanecem disponíveis no backend, mas não sustentam uma configuração ativa no frontend nesta etapa.
```

- [ ] **Step 3: Atualizar a memória do projeto com a implementação do plano**

Adicionar entradas em:
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`

Conteúdo mínimo a registrar:
- o que foi feito: troca dos toggles por placeholder `Em breve`
- por que foi feito: evitar promessa falsa de notificações ativas
- como funciona: UI estática, backend mantido dormente
- arquivos afetados
- data `2026-07-08`

- [ ] **Step 4: Verificar contradições documentais remanescentes**

Run: `rg -n "ajustar notificações|Preferências de Notificações|Em breve|preferencias_notificacoes" docs .agents .sauron`

Expected:
- documentação atual aponta placeholder `Em breve`
- nenhuma página funcional afirma que o usuário já configura notificações ativas no frontend

- [ ] **Step 5: Registrar os arquivos alterados para integração**

Listar explicitamente no handoff:
- `docs/telas.md`
- `docs/banco-de-dados.md`
- `.agents/project-memory/005-demais-telas-perfis.md`
- `.sauron/wiki/modules/feature-005-demais-telas-perfis.md`

### Task 4: Verificação final e handoff

**Files:**
- Review only: diff completo dos arquivos alterados

- [ ] **Step 1: Rodar a suíte direcionada da página e do service**

Run: `npm test -- src/pages/ConfiguracoesPage.test.tsx src/services/configuracoes.service.test.ts`

Expected:
- PASS
- nenhum teste depende mais de toggles ou RPC de preferências no frontend

- [ ] **Step 2: Rodar o build completo para validar TypeScript e uso morto removido**

Run: `npm run build`

Expected:
- PASS
- sem erros por imports/tipos removidos

- [ ] **Step 3: Fazer uma busca final por resíduos do fluxo interativo de preferências no frontend**

Run: `rg -n "listarPreferenciasNotificacoes|atualizarPreferenciasNotificacoes|PreferenciaNotificacaoItem|Preferência de notificação salva|notification-list|notification-item|switch|slider" src`

Expected:
- nenhuma ocorrência em `ConfiguracoesPage.tsx`, `ConfiguracoesPage.css`, `configuracoes.service.ts` e `types/configuracoes.ts`
- ocorrências restantes só se forem históricas ou não relacionadas

- [ ] **Step 4: Revisar a cobertura da spec antes do encerramento**

Conferir explicitamente:
- card continua visível
- nenhum toggle é exibido
- estado `Em breve` está explícito
- tela independe de seed/RPC para essa seção
- não existe toast de “preferência salva”
- backend ficou fora de escopo

- [ ] **Step 5: Preparar resumo final com evidências**

Reportar no handoff:
- arquivos alterados
- comandos executados
- resultado dos testes
- resultado do build
- confirmação de que backend/schema de `preferencias_notificacoes` não foram modificados
