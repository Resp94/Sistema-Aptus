import type { PermissaoModulo, PerfilAcesso } from '../types/auth'

/**
 * Matriz de permissões simuladas para fins de testes unitários de rotas e componentes
 */
export const permissoesPorPerfil: Record<PerfilAcesso, PermissaoModulo[]> = {
  Administrador: [
    { modulo: 'dashboard', pode_ler: true, pode_escrever: true },
    { modulo: 'clientes', pode_ler: true, pode_escrever: true },
    { modulo: 'propostas', pode_ler: true, pode_escrever: true },
    { modulo: 'contratos', pode_ler: true, pode_escrever: true },
    { modulo: 'cobrancas', pode_ler: true, pode_escrever: true },
    { modulo: 'projetos', pode_ler: true, pode_escrever: true },
    { modulo: 'equipe', pode_ler: true, pode_escrever: true },
    { modulo: 'financeiro', pode_ler: true, pode_escrever: true },
    { modulo: 'fluxo-caixa', pode_ler: true, pode_escrever: true },
    { modulo: 'contas-pagar', pode_ler: true, pode_escrever: true },
    { modulo: 'contas-receber', pode_ler: true, pode_escrever: true },
    { modulo: 'relatorios', pode_ler: true, pode_escrever: true },
    { modulo: 'configuracoes', pode_ler: true, pode_escrever: true }
  ],
  Financeiro: [
    { modulo: 'dashboard', pode_ler: true, pode_escrever: true },
    { modulo: 'clientes', pode_ler: false, pode_escrever: false },
    { modulo: 'propostas', pode_ler: false, pode_escrever: false },
    { modulo: 'contratos', pode_ler: false, pode_escrever: false },
    { modulo: 'cobrancas', pode_ler: true, pode_escrever: true },
    { modulo: 'projetos', pode_ler: false, pode_escrever: false },
    { modulo: 'equipe', pode_ler: false, pode_escrever: false },
    { modulo: 'financeiro', pode_ler: true, pode_escrever: true },
    { modulo: 'fluxo-caixa', pode_ler: true, pode_escrever: true },
    { modulo: 'contas-pagar', pode_ler: true, pode_escrever: true },
    { modulo: 'contas-receber', pode_ler: true, pode_escrever: true },
    { modulo: 'relatorios', pode_ler: true, pode_escrever: true },
    { modulo: 'configuracoes', pode_ler: true, pode_escrever: true }
  ],
  Projetos: [
    { modulo: 'dashboard', pode_ler: false, pode_escrever: false },
    { modulo: 'clientes', pode_ler: false, pode_escrever: false },
    { modulo: 'propostas', pode_ler: false, pode_escrever: false },
    { modulo: 'contratos', pode_ler: false, pode_escrever: false },
    { modulo: 'cobrancas', pode_ler: false, pode_escrever: false },
    { modulo: 'projetos', pode_ler: true, pode_escrever: true },
    { modulo: 'equipe', pode_ler: true, pode_escrever: true },
    { modulo: 'financeiro', pode_ler: false, pode_escrever: false },
    { modulo: 'fluxo-caixa', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-pagar', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-receber', pode_ler: false, pode_escrever: false },
    { modulo: 'relatorios', pode_ler: true, pode_escrever: true },
    { modulo: 'configuracoes', pode_ler: true, pode_escrever: true }
  ],
  Comercial: [
    { modulo: 'dashboard', pode_ler: false, pode_escrever: false },
    { modulo: 'clientes', pode_ler: true, pode_escrever: true },
    { modulo: 'propostas', pode_ler: true, pode_escrever: true },
    { modulo: 'contratos', pode_ler: true, pode_escrever: true },
    { modulo: 'cobrancas', pode_ler: true, pode_escrever: true },
    { modulo: 'projetos', pode_ler: false, pode_escrever: false },
    { modulo: 'equipe', pode_ler: false, pode_escrever: false },
    { modulo: 'financeiro', pode_ler: false, pode_escrever: false },
    { modulo: 'fluxo-caixa', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-pagar', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-receber', pode_ler: false, pode_escrever: false },
    { modulo: 'relatorios', pode_ler: false, pode_escrever: false },
    { modulo: 'configuracoes', pode_ler: true, pode_escrever: true }
  ],
  'Técnico': [
    { modulo: 'dashboard', pode_ler: false, pode_escrever: false },
    { modulo: 'clientes', pode_ler: false, pode_escrever: false },
    { modulo: 'propostas', pode_ler: false, pode_escrever: false },
    { modulo: 'contratos', pode_ler: false, pode_escrever: false },
    { modulo: 'cobrancas', pode_ler: false, pode_escrever: false },
    { modulo: 'projetos', pode_ler: true, pode_escrever: true },
    { modulo: 'equipe', pode_ler: true, pode_escrever: false },
    { modulo: 'financeiro', pode_ler: false, pode_escrever: false },
    { modulo: 'fluxo-caixa', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-pagar', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-receber', pode_ler: false, pode_escrever: false },
    { modulo: 'relatorios', pode_ler: false, pode_escrever: false },
    { modulo: 'configuracoes', pode_ler: true, pode_escrever: true }
  ],
  Visualizador: [
    { modulo: 'dashboard', pode_ler: false, pode_escrever: false },
    { modulo: 'clientes', pode_ler: true, pode_escrever: false },
    { modulo: 'propostas', pode_ler: true, pode_escrever: false },
    { modulo: 'contratos', pode_ler: true, pode_escrever: false },
    { modulo: 'cobrancas', pode_ler: true, pode_escrever: false },
    { modulo: 'projetos', pode_ler: true, pode_escrever: false },
    { modulo: 'equipe', pode_ler: true, pode_escrever: false },
    { modulo: 'financeiro', pode_ler: true, pode_escrever: false },
    { modulo: 'fluxo-caixa', pode_ler: true, pode_escrever: false },
    { modulo: 'contas-pagar', pode_ler: true, pode_escrever: false },
    { modulo: 'contas-receber', pode_ler: true, pode_escrever: false },
    { modulo: 'relatorios', pode_ler: true, pode_escrever: false },
    { modulo: 'configuracoes', pode_ler: true, pode_escrever: false }
  ]
}

/**
 * Helper para verificar se um perfil tem acesso de leitura a uma rota / módulo
 */
export function testPerfilPodeAcessar(perfil: PerfilAcesso, modulo: string): boolean {
  const permissoes = permissoesPorPerfil[perfil]
  const perm = permissoes.find(p => p.modulo === modulo)
  return perm ? perm.pode_ler : false
}

/**
 * Helper para verificar se um perfil tem acesso de escrita em um rota / módulo
 */
export function testPerfilPodeEscrever(perfil: PerfilAcesso, modulo: string): boolean {
  const permissoes = permissoesPorPerfil[perfil]
  const perm = permissoes.find(p => p.modulo === modulo)
  return perm ? perm.pode_escrever : false
}
