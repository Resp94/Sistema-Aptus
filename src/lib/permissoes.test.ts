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
    expect(podeEscrever(undefined, 'clientes')).toBe(false);
  });
});

describe('Módulos Financeiros e Ações da Feature 005', () => {
  const permissoesFinanceiro: PermissaoModulo[] = [
    { modulo: 'fluxo-caixa', pode_ler: true, pode_escrever: true },
    { modulo: 'contas-pagar', pode_ler: true, pode_escrever: true },
    { modulo: 'contas-receber', pode_ler: true, pode_escrever: true },
    { modulo: 'cobrancas', pode_ler: true, pode_escrever: true },
    { modulo: 'propostas', pode_ler: false, pode_escrever: false },
    { modulo: 'contratos', pode_ler: false, pode_escrever: false }
  ];

  const permissoesTecnico: PermissaoModulo[] = [
    { modulo: 'fluxo-caixa', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-pagar', pode_ler: false, pode_escrever: false },
    { modulo: 'contas-receber', pode_ler: false, pode_escrever: false },
    { modulo: 'cobrancas', pode_ler: false, pode_escrever: false },
    { modulo: 'projetos', pode_ler: true, pode_escrever: true },
    { modulo: 'equipe', pode_ler: true, pode_escrever: false }
  ];

  it('deve permitir leitura e escrita de fluxo e contas para o Financeiro', () => {
    expect(podeLer(permissoesFinanceiro, 'fluxo-caixa')).toBe(true);
    expect(podeEscrever(permissoesFinanceiro, 'fluxo-caixa')).toBe(true);
    expect(podeLer(permissoesFinanceiro, 'contas-pagar')).toBe(true);
    expect(podeEscrever(permissoesFinanceiro, 'contas-pagar')).toBe(true);
    expect(podeLer(permissoesFinanceiro, 'contas-receber')).toBe(true);
    expect(podeEscrever(permissoesFinanceiro, 'contas-receber')).toBe(true);
    expect(podeLer(permissoesFinanceiro, 'cobrancas')).toBe(true);
    expect(podeEscrever(permissoesFinanceiro, 'cobrancas')).toBe(true);
  });

  it('deve bloquear acesso financeiro para o Técnico', () => {
    expect(podeLer(permissoesTecnico, 'fluxo-caixa')).toBe(false);
    expect(podeEscrever(permissoesTecnico, 'fluxo-caixa')).toBe(false);
    expect(podeLer(permissoesTecnico, 'contas-pagar')).toBe(false);
    expect(podeEscrever(permissoesTecnico, 'contas-receber')).toBe(false);
    expect(podeLer(permissoesTecnico, 'cobrancas')).toBe(false);
  });

  it('deve bloquear comercial para o Financeiro', () => {
    expect(podeLer(permissoesFinanceiro, 'propostas')).toBe(false);
    expect(podeEscrever(permissoesFinanceiro, 'contratos')).toBe(false);
  });
});

