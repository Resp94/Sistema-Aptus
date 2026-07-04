/**
 * Verifica se o usuário possui uma capacidade nomeada específica.
 *
 * Regras:
 * - Retorna `false` quando a lista de capacidades é nula, indefinida ou não é um array.
 * - Retorna `false` quando a capacidade informada é uma string vazia.
 * - Retorna `true` apenas em caso de correspondência exata (sem wildcard/prefixo).
 *
 * Esta função serve apenas para UX no frontend (mostrar/ocultar botões).
 * A autorização real é sempre validada pelas RPCs no backend.
 *
 * @param capacidades Lista de capacidades do usuário
 * @param capacidade Nome exato da capacidade a ser verificada
 * @returns boolean indicando se a capacidade está presente
 */
export function pode(
  capacidades: string[] | null | undefined,
  capacidade: string
): boolean {
  if (!capacidades || !Array.isArray(capacidades)) {
    return false;
  }
  if (!capacidade) {
    return false;
  }
  return capacidades.includes(capacidade);
}
