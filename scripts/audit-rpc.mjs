import { readdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { pathToFileURL } from 'url';

const MIGRATIONS_DIR = 'supabase/migrations';

const AUDIT_EXCEPTIONS = new Set(['registrar_evento_auditoria']);

// Funções helper de autorização: elas SÃO os guards (permissao_modulo,
// tem_capacidade, etc.) e não precisam chamar a si mesmas ou umas às outras
// dentro do próprio corpo. Ver contracts/audit-and-tests.md e
// contracts/rpc-capability-contract.md.
const HELPERS = new Set([
  'permissao_modulo',
  'obter_permissoes_usuario',
  'obter_perfil_usuario',
  'existe_perfil_admin',
  'tem_capacidade',
  'obter_capacidades_usuario',
  // Feature 008 (exportar-relatorios, T072): categoria_relatorio_exportavel
  // e validar_periodo_exportacao são primitivas puras de
  // autorização/validação (perfil x categoria; regras de período),
  // chamadas internamente por iniciar_exportacao_relatorio/
  // autorizar_download_exportacao_relatorio/listar_exportacoes_relatorios —
  // mesmo papel de guard que permissao_modulo/tem_capacidade, não exigem
  // checar a si mesmas. Continuam exigindo SECURITY DEFINER + guarda de
  // identidade, que ambas possuem.
  'categoria_relatorio_exportavel',
  'validar_periodo_exportacao',
  // Feature 008: registrar_evento_exportacao é uma função interna de
  // observabilidade (grava em audit_log), mesma natureza de
  // registrar_evento_auditoria, mas sempre exige usuário autenticado — por
  // isso é HELPER (não precisa de tem_capacidade própria) em vez de entrar
  // em AUDIT_EXCEPTIONS (que exigiria GRANT também para anon, sem sentido
  // aqui pois a função sempre rejeita chamadas anônimas).
  'registrar_evento_exportacao',
]);
// Funções admin-only guardadas por existe_perfil_admin em vez de
// permissao_modulo/tem_capacidade (gestão de perfis de terceiros não é uma
// permissão de módulo nem uma capacidade nomeada comum). Ver FR-005 /
// contracts/rpc-signatures.md.
const ADMIN_GATED = new Set(['atualizar_usuario_perfil']);

// Feature 008 (exportar-relatorios, T072): concluir_exportacao_relatorio e
// falhar_exportacao_relatorio autorizam por posse do registro
// (`criado_por = auth.uid()`) em vez de capacidade nomeada — decisão
// documentada na migration 20260704235640_exportar_relatorios.sql (#7):
// a Edge Function sempre chama estas RPCs com o JWT do usuário dono do
// processo, e só quem já passou por tem_capacidade('relatorios.exportar')
// em iniciar_exportacao_relatorio pode ser dono de uma linha 'Pendente'.
const OWNERSHIP_GATED = new Set([
  'concluir_exportacao_relatorio',
  'falhar_exportacao_relatorio',
]);

// Feature 008 (exportar-relatorios, T072): os payload builders de relatório
// são STABLE (logo, classificados como "read" pela heurística), mas a regra
// de negócio que os autoriza é a capacidade nomeada
// 'relatorios.exportar' (contracts/rpc-exportacao-relatorios.md), não uma
// permissão de leitura do módulo 'relatorios' — usar permissao_modulo aqui
// vazaria dados detalhados de exportação para perfis que só têm leitura de
// preview (ex.: Visualizador), que não podem exportar. Por isso exigem
// tem_capacidade(...) no corpo em vez de permissao_modulo(...).
const CAPABILITY_GATED_READS = new Set([
  'montar_payload_relatorio_financeiro',
  'montar_payload_relatorio_dre',
  'montar_payload_relatorio_clientes',
  'montar_payload_relatorio_projetos',
]);

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

function parseMigrations(migrationsDir = MIGRATIONS_DIR) {
  const files = readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  const functions = new Map();
  const grants = new Map();

  for (const file of files) {
    const content = readFileSync(join(migrationsDir, file), 'utf8');

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

// Heurística de classificação (T070): a marca mais confiável de "leitura de
// domínio" vs "escrita direta/efeito de negócio" é a presença de STABLE no
// header da função (LANGUAGE plpgsql STABLE ...). Funções STABLE são
// leituras puras (listar_*, obter_*, e até algum gerar_*_previa que apenas
// consulta dados) e continuam exigindo permissao_modulo(...). Funções sem
// STABLE têm efeito colateral (criar_*, atualizar_*, excluir_*, inativar_*,
// registrar_*, mover_*, alocar_*, solicitar_*, renovar_*, encerrar_*,
// agendar_*, etc.) e passam a exigir tem_capacidade(...). Essa heurística foi
// validada contra todas as funções reais das migrations: 100% de aderência.
function isReadFunction(header) {
  return /\bSTABLE\b/i.test(header);
}

/**
 * Classifica uma função (não-trigger, não-helper, não-admin-gated,
 * não-audit) como 'read' (leitura de domínio) ou 'write' (escrita direta ou
 * efeito de negócio), de acordo com a heurística baseada em STABLE.
 */
function classifyFunction(header) {
  return isReadFunction(header) ? 'read' : 'write';
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
  const isOwnershipGated = OWNERSHIP_GATED.has(name);
  const isCapabilityGatedRead = CAPABILITY_GATED_READS.has(name);

  if (!isHelper && !isAudit && !isOwnershipGated) {
    const kind = classifyFunction(header);
    if (kind === 'read' && !isCapabilityGatedRead) {
      if (!/permissao_modulo\s*\(/i.test(body)) {
        issues.push('missing permissao_modulo check');
      }
    } else {
      if (!/tem_capacidade\s*\(/i.test(body)) {
        issues.push('missing tem_capacidade check');
      }
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

function runAudit(migrationsDir = MIGRATIONS_DIR) {
  const { functions, grants } = parseMigrations(migrationsDir);

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

  return { active, failures };
}

function main() {
  const { active, failures } = runAudit();

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

export {
  AUDIT_EXCEPTIONS,
  HELPERS,
  ADMIN_GATED,
  OWNERSHIP_GATED,
  CAPABILITY_GATED_READS,
  normalizeArgs,
  funcKey,
  parseMigrations,
  isTrigger,
  isSecurityDefiner,
  hasSearchPath,
  isReadFunction,
  classifyFunction,
  checkFunction,
  runAudit,
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
