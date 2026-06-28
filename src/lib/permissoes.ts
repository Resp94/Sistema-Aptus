import type { PermissaoModulo } from '../types/auth';

/**
 * Verifica se o usuário tem permissão de leitura para um determinado módulo.
 * 
 * @param permissoes Lista de permissões do usuário
 * @param modulo Nome do módulo a ser verificado
 * @returns boolean indicando se a leitura é permitida
 */
export function podeLer(
  permissoes: PermissaoModulo[] | null | undefined,
  modulo: string
): boolean {
  if (!permissoes || !Array.isArray(permissoes)) {
    return false;
  }
  const permissao = permissoes.find((p) => p.modulo === modulo);
  return permissao ? permissao.pode_ler : false;
}

/**
 * Verifica se o usuário tem permissão de escrita para um determinado módulo.
 * 
 * @param permissoes Lista de permissões do usuário
 * @param modulo Nome do módulo a ser verificado
 * @returns boolean indicando se a escrita é permitida
 */
export function podeEscrever(
  permissoes: PermissaoModulo[] | null | undefined,
  modulo: string
): boolean {
  if (!permissoes || !Array.isArray(permissoes)) {
    return false;
  }
  const permissao = permissoes.find((p) => p.modulo === modulo);
  return permissao ? permissao.pode_escrever : false;
}
