import { describe, it, expect } from 'vitest';
import { pode } from './capacidades';

describe('pode', () => {
  it('deve retornar false quando a lista de capacidades é null', () => {
    expect(pode(null, 'clientes.criar')).toBe(false);
  });

  it('deve retornar false quando a lista de capacidades é undefined', () => {
    expect(pode(undefined, 'clientes.criar')).toBe(false);
  });

  it('deve retornar false quando a lista de capacidades está vazia', () => {
    expect(pode([], 'clientes.criar')).toBe(false);
  });

  it('deve retornar true em caso de correspondência exata', () => {
    expect(pode(['clientes.criar', 'clientes.editar'], 'clientes.criar')).toBe(true);
  });

  it('deve retornar false para capacidade vazia', () => {
    expect(pode(['clientes.criar'], '')).toBe(false);
  });

  it('não deve dar match parcial por prefixo/substring (sem wildcard)', () => {
    expect(pode(['tarefas.editar_qualquer'], 'tarefas.editar')).toBe(false);
    expect(pode(['tarefas.editar'], 'tarefas.editar_qualquer')).toBe(false);
  });

  it('deve retornar false quando a capacidade não está na lista', () => {
    expect(pode(['clientes.criar'], 'clientes.inativar')).toBe(false);
  });
});
