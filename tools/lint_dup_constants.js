#!/usr/bin/env node
// tools/lint_dup_constants.js
//
// Detect duplicate constant names across the four split constants files.
// A constant name appearing in two or more files is always a bug (or at least
// ambiguous), because the assembler will silently use whichever definition it
// sees last.
//
// Constants files checked:
//   hw_constants.asm     — VDP, Z80 bus, I/O port registers
//   ram_addresses.asm    — all work-RAM variable addresses
//   sound_constants.asm  — Z80 audio interface, music/SFX IDs
//   game_constants.asm   — menu states, shift types, key codes
//
// Usage:
//   node tools/lint_dup_constants.js [-v]
//
//   -v   Print every constant found (not just duplicates)
//
// Exit codes:
//   0 — no duplicate constant names found
//   1 — one or more duplicate names found

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

const CONSTANTS_FILES = [
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
];

// Matches:  SomeName = $1234   or   SOME_NAME = 42
// Captures the name only.
const CONST_RE = /^([A-Za-z_]\w*)\s*=/;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
const verbose = argv.includes('-v') || argv.includes('--verbose');

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/** @type {Map<string, string[]>} name → list of files that define it */
const nameToFiles = new Map();

for (const rel of CONSTANTS_FILES) {
  const absPath = path.join(REPO_ROOT, rel);
  if (!fs.existsSync(absPath)) {
    console.error(`ERROR: constants file not found: ${rel}`);
    process.exit(1);
  }
  const lines = fs.readFileSync(absPath, { encoding: 'latin1' }).split('\n');
  for (const line of lines) {
    const stripped = line.trim();
    if (!stripped || stripped.startsWith(';')) continue;
    const m = CONST_RE.exec(stripped);
    if (m) {
      const name = m[1];
      if (!nameToFiles.has(name)) nameToFiles.set(name, []);
      nameToFiles.get(name).push(rel);
      if (verbose) {
        console.log(`  ${rel}: ${name}`);
      }
    }
  }
}

const duplicates = [];
for (const [name, files] of nameToFiles) {
  if (files.length > 1) {
    duplicates.push({ name, files });
  }
}

if (duplicates.length > 0) {
  console.error(`\nERROR: ${duplicates.length} duplicate constant name(s) found:\n`);
  for (const { name, files } of duplicates) {
    console.error(`  ${name}  (defined in: ${files.join(', ')})`);
  }
  console.error(
    '\nFix: each constant must appear in exactly one constants file. ' +
    'Move or rename the duplicate.'
  );
  process.exit(1);
}

console.log(
  `OK: lint_dup_constants — 0 duplicate constant names across ${CONSTANTS_FILES.length} files ` +
  `(${nameToFiles.size} total constants).`
);

// ---------------------------------------------------------------------------
// Exports for tests
// ---------------------------------------------------------------------------

module.exports = {
  CONSTANTS_FILES,
  scanConstantsFiles,
  findDuplicates,
};

/**
 * Scan the constants files and return a Map from name → list of files.
 * @param {string} repoRoot
 * @returns {Map<string, string[]>}
 */
function scanConstantsFiles(repoRoot) {
  const root = repoRoot || REPO_ROOT;
  const result = new Map();
  for (const rel of CONSTANTS_FILES) {
    const absPath = path.join(root, rel);
    if (!fs.existsSync(absPath)) continue;
    const lines = fs.readFileSync(absPath, { encoding: 'latin1' }).split('\n');
    for (const line of lines) {
      const stripped = line.trim();
      if (!stripped || stripped.startsWith(';')) continue;
      const m = CONST_RE.exec(stripped);
      if (m) {
        const name = m[1];
        if (!result.has(name)) result.set(name, []);
        result.get(name).push(rel);
      }
    }
  }
  return result;
}

/**
 * Return entries from nameToFiles where the name appears more than once.
 * @param {Map<string, string[]>} nameToFiles
 * @returns {Array<{name: string, files: string[]}>}
 */
function findDuplicates(nameToFiles) {
  const dups = [];
  for (const [name, files] of nameToFiles) {
    if (files.length > 1) dups.push({ name, files });
  }
  return dups;
}
