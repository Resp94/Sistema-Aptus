#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from 'fs';
import { join, relative } from 'path';

const SERVICES_DIR = 'src/services';
const ALLOWLIST = new Set(['src/services/health-check.ts']);

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      walk(full, files);
    } else if (full.endsWith('.ts')) {
      files.push(full);
    }
  }
  return files;
}

function main() {
  const files = walk(SERVICES_DIR);
  const offenders = [];

  for (const file of files) {
    const rel = relative('.', file).replace(/\\/g, '/');
    if (ALLOWLIST.has(rel)) continue;

    const content = readFileSync(file, 'utf8');
    const lines = content.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      // Skip comments
      const code = line.replace(/\/\/.*/, '');
      if (/supabase\.from\s*\(/.test(code)) {
        offenders.push({ file: rel, line: i + 1, text: line.trim() });
      }
    }
  }

  if (offenders.length > 0) {
    console.log('Forbidden supabase.from() calls found in src/services:');
    for (const o of offenders) {
      console.log(`  ${o.file}:${o.line}: ${o.text}`);
    }
    process.exit(1);
  }

  console.log('No forbidden supabase.from() calls in src/services (allowlist respected).');
}

main();
