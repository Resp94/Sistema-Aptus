#!/usr/bin/env node
import { readdirSync, readFileSync } from 'fs';
import { join } from 'path';

const MIGRATIONS_DIR = 'supabase/migrations';

const AUDIT_EXCEPTIONS = new Set(['registrar_evento_auditoria']);
const HELPERS = new Set([
  'permissao_modulo',
  'obter_permissoes_usuario',
  'obter_perfil_usuario',
  'existe_perfil_admin',
]);
// Funções admin-only guardadas por existe_perfil_admin em vez de permissao_modulo
// (gestão de perfis de terceiros não é uma permissão de módulo). Ver FR-005 /
// contracts/rpc-signatures.md.
const ADMIN_GATED = new Set(['atualizar_usuario_perfil']);

function normalizeArgs(args) {
  if (!args || !args.trim()) return '';
  return args
    .split(',')
    .map((a) => {
      const withoutDefault = a.replace(/\s+(?:DEFAULT|=)\s+.*/i, '').trim();
      const tokens = withoutDefault.split(/\s+/);
      return tokens[tokens.length - 1];
    })
    .filter(Boolean)
    .join(',');
}

function funcKey(name, args) {
  return `${name}(${normalizeArgs(args)})`;
}

function parseMigrations() {
  const files = readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  const functions = new Map();
  const grants = new Map();

  for (const file of files) {
    const content = readFileSync(join(MIGRATIONS_DIR, file), 'utf8');

    // DROP FUNCTION honors removal from the catalog
    const dropRegex = /DROP\s+FUNCTION\s+(?:IF\s+EXISTS\s+)?public\.(\w+)\s*\(([^)]*)\)/gi;
    let m;
    while ((m = dropRegex.exec(content)) !== null) {
      const k = funcKey(m[1], m[2]);
      functions.set(k, { ...(functions.get(k) || {}), dropped: true, dropFile: file });
    }

    // CREATE [OR REPLACE] FUNCTION
    const createRegex = /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+public\.(\w+)\s*\(([^)]*)\)([\s\S]*?)AS\s*\$\$([\s\S]*?)\$\$/gi;
    while ((m = createRegex.exec(content)) !== null) {
      const name = m[1];
      const args = m[2];
      const header = m[3];
      const body = m[4];
      const k = funcKey(name, args);
      functions.set(k, {
        name,
        args,
        header,
        body,
        file,
        dropped: false,
      });
    }

    // REVOKE / GRANT EXECUTE ON FUNCTION
    const grantRegex = /(REVOKE|GRANT)\s+EXECUTE\s+ON\s+FUNCTION\s+public\.(\w+)\s*\(([^)]*)\)\s+(?:FROM|TO)\s+([^;]+)/gi;
    while ((m = grantRegex.exec(content)) !== null) {
      const k = funcKey(m[2], m[3]);
      const kind = m[1].toUpperCase();
      const targets = m[4]
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .filter(Boolean);
      const existing = grants.get(k) || { hasRevoke: false, hasGrant: false, grantTo: new Set() };
      if (kind === 'REVOKE') existing.hasRevoke = true;
      if (kind === 'GRANT') {
        existing.hasGrant = true;
        for (const t of targets) existing.grantTo.add(t);
      }
      grants.set(k, existing);
    }
  }

  return { functions, grants };
}

function isTrigger(header) {
  return /RETURNS\s+trigger\b/i.test(header);
}

function isSecurityDefiner(header) {
  return /SECURITY\s+DEFINER/i.test(header);
}

function hasSearchPath(header) {
  return /SET\s+search_path\s*=\s*public/i.test(header);
}

function checkFunction(fn, grants) {
  const { name, header, body } = fn;
  const issues = [];

  if (!isSecurityDefiner(header)) {
    issues.push('missing SECURITY DEFINER');
  }

  if (!hasSearchPath(header)) {
    issues.push('missing SET search_path');
  }

  if (isTrigger(header)) {
    return issues;
  }

  const isHelper = HELPERS.has(name) || ADMIN_GATED.has(name);
  const isAudit = AUDIT_EXCEPTIONS.has(name);

  if (!isHelper && !isAudit) {
    if (!/permissao_modulo\s*\(/i.test(body)) {
      issues.push('missing permissao_modulo check');
    }
  }

  if (!/auth\.uid\s*\(\)|existe_perfil_admin\s*\(/i.test(body)) {
    issues.push('missing identity guard (auth.uid()/existe_perfil_admin)');
  }

  const grant = grants.get(funcKey(name, fn.args)) || { hasRevoke: false, hasGrant: false, grantTo: new Set() };

  if (!grant.hasRevoke) {
    issues.push('missing REVOKE EXECUTE FROM PUBLIC');
  }

  if (!grant.hasGrant) {
    issues.push('missing GRANT EXECUTE');
  } else if (isAudit) {
    if (!grant.grantTo.has('anon') || !grant.grantTo.has('authenticated')) {
      issues.push('audit function must GRANT to anon and authenticated');
    }
  } else {
    if (!grant.grantTo.has('authenticated')) {
      issues.push('must GRANT EXECUTE TO authenticated');
    }
  }

  return issues;
}

function main() {
  const { functions, grants } = parseMigrations();

  const active = [];
  const failures = [];

  for (const [k, fn] of functions.entries()) {
    if (fn.dropped) continue;
    active.push(fn);
    const issues = checkFunction(fn, grants);
    if (issues.length > 0) {
      failures.push({ key: k, file: fn.file, issues });
    }
  }

  const total = active.length;
  const pass = total - failures.length;

  console.log(`RPC guardrail audit: ${pass}/${total} functions compliant`);
  if (failures.length > 0) {
    console.log('\nFailures:');
    for (const f of failures) {
      console.log(`  ${f.key} (${f.file})`);
      for (const issue of f.issues) {
        console.log(`    - ${issue}`);
      }
    }
    process.exit(1);
  }
}

main();
