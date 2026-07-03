#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from 'fs';
import { join, relative } from 'path';

const TARGETS = [
  { dir: 'supabase/migrations', ext: '.sql' },
  { dir: 'src', ext: '.ts' },
  { dir: 'src', ext: '.tsx' },
];

// Allowlist of known-legitimate occurrences (normalized line content).
// Any new occurrence of raw_user_meta_data/user_metadata outside this list fails the CI.
const ALLOWLIST = new Set([
  // 00000000000000_usuarios_perfis.sql: schema e trigger handle_auth_user_sync
  'raw_user_meta_data jsonb,',
  'raw_user_meta_data,',
  'new.raw_user_meta_data,',
  'raw_user_meta_data = new.raw_user_meta_data,',
  "coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),",
  "coalesce(new.raw_user_meta_data->>'perfil_acesso', 'visualizador'),",
  "new.raw_user_meta_data->>'departamento'",
  "if new.raw_user_meta_data->>'nome' is not null then",
  "nome = new.raw_user_meta_data->>'nome'",

  // 20260701000010_demais_telas_rpc_config_write.sql: sincronização de nome/departamento/perfil
  'set raw_user_meta_data = raw_user_meta_data || jsonb_build_object(',
  "'perfil_acesso', coalesce(v_perfil_acesso, v_old_perfil),",
  "'departamento', coalesce(v_departamento, departamento)",
  "'nome', coalesce(v_nome, raw_user_meta_data->>'nome'),",
  "'departamento', coalesce(v_departamento, raw_user_meta_data->>'departamento')",
]);

function normalizeLine(line) {
  return line
    .replace(/--.*$/, '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function walk(dir, ext, files = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      walk(full, ext, files);
    } else if (full.endsWith(ext)) {
      files.push(full);
    }
  }
  return files;
}

function main() {
  const offenders = [];

  for (const target of TARGETS) {
    const files = walk(target.dir, target.ext);
    for (const file of files) {
      const rel = relative('.', file).replace(/\\/g, '/');
      const content = readFileSync(file, 'utf8');
      const lines = content.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const raw = lines[i];
        const norm = normalizeLine(raw);
        if (!/(?:raw_user_meta_data|user_metadata)/.test(norm)) continue;
        if (ALLOWLIST.has(norm)) continue;
        offenders.push({ file: rel, line: i + 1, text: raw.trim() });
      }
    }
  }

  if (offenders.length > 0) {
    console.log('Unexpected raw_user_meta_data/user_metadata usage found:');
    for (const o of offenders) {
      console.log(`  ${o.file}:${o.line}: ${o.text}`);
    }
    process.exit(1);
  }

  console.log('No unexpected raw_user_meta_data/user_metadata usage found.');
}

main();
