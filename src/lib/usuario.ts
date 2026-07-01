import type { PerfilAcesso } from '../types/auth'

export function obterIniciais(nome: string): string {
  const partes = nome.trim().split(/\s+/).filter(Boolean)
  if (partes.length === 0) return ''
  if (partes.length === 1) return partes[0][0].toUpperCase()
  return (partes[0][0] + partes[partes.length - 1][0]).toUpperCase()
}

export function saudacaoPorHora(hora: number): string {
  if (hora < 12) return 'Bom dia'
  if (hora < 18) return 'Boa tarde'
  return 'Boa noite'
}

export function rotaInicialPorPerfil(perfil: PerfilAcesso): string {
  switch (perfil) {
    case 'Administrador':
    case 'Financeiro':
      return '/dashboard'
    case 'Projetos':
    case 'Técnico':
      return '/projetos'
    case 'Comercial':
      return '/clientes'
    case 'Visualizador':
      return '/dashboard'
    default:
      return '/dashboard'
  }
}
