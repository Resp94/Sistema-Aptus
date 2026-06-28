import { describe, it, expect } from 'vitest';
import { podeLer, podeEscrever } from './permissoes';
import type { PermissaoModulo } from '../types/auth';

const permissoesMock: PermissaoModulo[] = [
  { modulo: 'dashboard', pode_ler: true, pode_escrever: false },
  { modulo: 'clientes', pode_ler: true, pode_escrever: true },
  { modulo: 'projetos', pode_ler: false, pode_escrever: false },
];

describe('podeLer', () => {
  it('deve retornar true quando o módulo tem permissão de leitura', () => {
    expect(podeLer(permissoesMock, 'clientes')).toBe(true);
    expect(podeLer(permissoesMock, 'dashboard')).toBe(true);
  });

  it('deve retornar false quando o módulo não tem permissão de leitura', () => {
    expect(podeLer(permissoesMock, 'projetos')).toBe(false);
  });

  it('deve retornar false quando o módulo não está na lista', () => {
    expect(podeLer(permissoesMock, 'financeiro')).toBe(false);
  });

  it('deve retornar false quando a lista de permissões é vazia, nula ou indefinida', () => {
    expect(podeLer([], 'clientes')).toBe(false);
    expect(podeLer(null, 'clientes')).toBe(false);
    expect(podeLer(undefined, 'clientes')).toBe(false);
  });
});

describe('podeEscrever', () => {
  it('deve retornar true quando o módulo tem permissão de escrita', () => {
    expect(podeEscrever(permissoesMock, 'clientes')).toBe(true);
  });

  it('deve retornar false quando o módulo não tem permissão de escrita', () => {
    expect(podeEscrever(permissoesMock, 'dashboard')).toBe(false);
    expect(podeEscrever(permissoesMock, 'projetos')).toBe(false);
  });

  it('deve retornar false quando o módulo não está na lista', () => {
    expect(podeEscrever(permissoesMock, 'financeiro')).toBe(false);
  });

  it('deve retornar false quando a lista de permissões é vazia, nula ou indefinida', () => {
    expect(podeEscrever([], 'clientes')).toBe(false);
    expect(podeEscrever(null, 'clientes')).toBe(false);
    expect(podeEscrever(undefined, 'clientes')).toBe(false);
  });
});
