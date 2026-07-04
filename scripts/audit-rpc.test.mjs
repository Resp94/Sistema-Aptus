import { describe, expect, it } from 'vitest';
import { HELPERS, checkFunction, classifyFunction, isReadFunction } from './audit-rpc.mjs';

const BASE_GRANTS = new Map();

function grantsFor(name, args = '') {
  const grants = new Map(BASE_GRANTS);
  grants.set(`${name}(${args})`, {
    hasRevoke: true,
    hasGrant: true,
    grantTo: new Set(['authenticated']),
  });
  return grants;
}

const COMPLIANT_HEADER_READ = `
RETURNS TABLE (id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
`;

const COMPLIANT_HEADER_WRITE = `
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
`;

describe('isReadFunction / classifyFunction', () => {
  it('classifies a STABLE header as read', () => {
    expect(isReadFunction(COMPLIANT_HEADER_READ)).toBe(true);
    expect(classifyFunction(COMPLIANT_HEADER_READ)).toBe('read');
  });

  it('classifies a non-STABLE header as write', () => {
    expect(isReadFunction(COMPLIANT_HEADER_WRITE)).toBe(false);
    expect(classifyFunction(COMPLIANT_HEADER_WRITE)).toBe('write');
  });
});

describe('checkFunction: leitura de domínio (STABLE)', () => {
  it('reports missing permissao_modulo check when a STABLE function lacks it', () => {
    const fn = {
      name: 'listar_clientes',
      args: '',
      header: COMPLIANT_HEADER_READ,
      body: `
        IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'Unauthorized';
        END IF;
        SELECT * FROM clientes;
      `,
      file: 'fake.sql',
    };
    const issues = checkFunction(fn, grantsFor('listar_clientes'));
    expect(issues).toContain('missing permissao_modulo check');
    expect(issues).not.toContain('missing tem_capacidade check');
  });

  it('does not report missing permissao_modulo when present', () => {
    const fn = {
      name: 'listar_clientes',
      args: '',
      header: COMPLIANT_HEADER_READ,
      body: `
        IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'Unauthorized';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM public.permissao_modulo('clientes')) THEN
          RAISE EXCEPTION 'Forbidden';
        END IF;
      `,
      file: 'fake.sql',
    };
    const issues = checkFunction(fn, grantsFor('listar_clientes'));
    expect(issues).not.toContain('missing permissao_modulo check');
  });
});

describe('checkFunction: escrita/efeito de negócio (não-STABLE)', () => {
  it('reports missing tem_capacidade check for a write function without it', () => {
    const fn = {
      name: 'criar_cliente',
      args: 'p_nome text',
      header: COMPLIANT_HEADER_WRITE,
      body: `
        IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'Unauthorized';
        END IF;
        INSERT INTO clientes (nome) VALUES (p_nome);
      `,
      file: 'fake.sql',
    };
    const issues = checkFunction(fn, grantsFor('criar_cliente', 'text'));
    expect(issues).toContain('missing tem_capacidade check');
    expect(issues).not.toContain('missing permissao_modulo check');
  });

  it('does not report the issue when tem_capacidade is present in the body', () => {
    const fn = {
      name: 'criar_cliente',
      args: 'p_nome text',
      header: COMPLIANT_HEADER_WRITE,
      body: `
        IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'Unauthorized';
        END IF;
        IF NOT public.tem_capacidade('clientes.criar') THEN
          RAISE EXCEPTION 'Forbidden';
        END IF;
        INSERT INTO clientes (nome) VALUES (p_nome);
      `,
      file: 'fake.sql',
    };
    const issues = checkFunction(fn, grantsFor('criar_cliente', 'text'));
    expect(issues).not.toContain('missing tem_capacidade check');
  });
});

describe('checkFunction: helpers de autorização', () => {
  it('does not require permissao_modulo or tem_capacidade inside tem_capacidade itself', () => {
    expect(HELPERS.has('tem_capacidade')).toBe(true);
    const fn = {
      name: 'tem_capacidade',
      args: 'p_capacidade text',
      header: COMPLIANT_HEADER_READ,
      body: `
        IF auth.uid() IS NULL THEN
          RETURN false;
        END IF;
        RETURN EXISTS (SELECT 1 FROM public.capacidades_perfil);
      `,
      file: 'fake.sql',
    };
    const issues = checkFunction(fn, grantsFor('tem_capacidade', 'text'));
    expect(issues).not.toContain('missing permissao_modulo check');
    expect(issues).not.toContain('missing tem_capacidade check');
  });

  it('does not require permissao_modulo or tem_capacidade inside obter_capacidades_usuario itself', () => {
    expect(HELPERS.has('obter_capacidades_usuario')).toBe(true);
    const fn = {
      name: 'obter_capacidades_usuario',
      args: '',
      header: COMPLIANT_HEADER_READ,
      body: `
        IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'Unauthorized';
        END IF;
        RETURN ARRAY[]::text[];
      `,
      file: 'fake.sql',
    };
    const issues = checkFunction(fn, grantsFor('obter_capacidades_usuario'));
    expect(issues).not.toContain('missing permissao_modulo check');
    expect(issues).not.toContain('missing tem_capacidade check');
  });
});
