import type { PermissaoModulo } from '../types/auth'

export type SecaoNav = 'Principal' | 'Gestão'

export interface ItemNav {
  modulo: string
  rotulo: string
  rota: string
  secao: SecaoNav
  icone: string
}

// Ordem e rótulos idênticos à sidebar de reference/legacy-html/dashboard.html
export const ITENS_NAV: ItemNav[] = [
  { modulo: 'dashboard', rotulo: 'Dashboard', rota: '/dashboard', secao: 'Principal', icone: 'grid' },
  { modulo: 'fluxo-caixa', rotulo: 'Fluxo de Caixa', rota: '/fluxo-caixa', secao: 'Principal', icone: 'activity' },
  { modulo: 'contas-pagar', rotulo: 'Contas a Pagar', rota: '/contas-pagar', secao: 'Principal', icone: 'pagar' },
  { modulo: 'contas-receber', rotulo: 'Contas a Receber', rota: '/contas-receber', secao: 'Principal', icone: 'receber' },
  { modulo: 'clientes', rotulo: 'Clientes / Fornecedores', rota: '/clientes', secao: 'Gestão', icone: 'users' },
  { modulo: 'propostas', rotulo: 'Propostas', rota: '/propostas', secao: 'Gestão', icone: 'file' },
  { modulo: 'contratos', rotulo: 'Contratos', rota: '/contratos', secao: 'Gestão', icone: 'contract' },
  { modulo: 'cobrancas', rotulo: 'Cobranças', rota: '/cobrancas', secao: 'Gestão', icone: 'clock' },
  { modulo: 'projetos', rotulo: 'Projetos', rota: '/projetos', secao: 'Gestão', icone: 'kanban' },
  { modulo: 'equipe', rotulo: 'Equipe', rota: '/equipe', secao: 'Gestão', icone: 'team' },
  { modulo: 'relatorios', rotulo: 'Relatórios / Exportação', rota: '/relatorios', secao: 'Gestão', icone: 'report' },
  { modulo: 'configuracoes', rotulo: 'Configurações', rota: '/configuracoes', secao: 'Gestão', icone: 'gear' },
]

export function filtrarNavPorPermissoes(
  itens: ItemNav[],
  permissoes: PermissaoModulo[],
): ItemNav[] {
  const legiveis = new Set(
    permissoes.filter((p) => p.pode_ler).map((p) => p.modulo),
  )
  return itens.filter((item) => legiveis.has(item.modulo))
}
