#!/usr/bin/env node
// tools/run_checks.js
//
// Structural integrity checks for the Super Monaco GP disassembly project.
// Equivalent to tools/run_checks.py but implemented in Node.js.
//
// Checks performed:
//   1. smgp.asm include order matches the expected 15-line module list
//   2. tools/index/symbol_map.json meta count matches symbol table size
//   3. No legacy loc_ label definitions remain in any .asm source file
//   4. No raw hardware/RAM address literals in code modules (allowlist enforced)
//   5. Split-address safety: all baseline symbols still at same addresses
//   6. Backslide lint: no new raw RAM/IO literals or raw ROM pointers in code modules
//   7. Duplicate constants lint: no constant name defined in more than one constants file
//   8. Raw VDP register writes lint: count must not exceed frozen baseline (91)
//   9. Magic numbers audit: uncommented decimal literals >=100 must not exceed baseline (14)
//
// Usage:
//   node tools/run_checks.js

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const SMGP_ASM = path.join(REPO_ROOT, 'smgp.asm');
const SYMBOL_MAP = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');
const CHECK_SPLIT = path.join(REPO_ROOT, 'tools', 'check_split_addresses.js');
const LINT_BACKSLIDE = path.join(REPO_ROOT, 'tools', 'lint_backslide.js');
const LINT_DUP_CONSTANTS = path.join(REPO_ROOT, 'tools', 'lint_dup_constants.js');
const LINT_RAW_VDP = path.join(REPO_ROOT, 'tools', 'lint_raw_vdp.js');
const AUDIT_MAGIC = path.join(REPO_ROOT, 'tools', 'audit_magic_numbers.js');

// ---------------------------------------------------------------------------
// Expected include order (15 lines)
// ---------------------------------------------------------------------------

const EXPECTED_INCLUDES = [
  'include "macros.asm"',
  'include "constants.asm"',
  'include "header.asm"',
  'include "init.asm"',
  'include "src/core.asm"',
  'include "src/menus.asm"',
  'include "src/race.asm"',
  'include "src/driving.asm"',
  'include "src/rendering.asm"',
  'include "src/race_support.asm"',
  'include "src/ai.asm"',
  'include "src/audio_effects.asm"',
  'include "src/objects.asm"',
  'include "src/endgame.asm"',
  'include "src/gameplay.asm"',
];

// ---------------------------------------------------------------------------
// Raw address detection
// ---------------------------------------------------------------------------

// Matches $FFFF####, $00FF####, $A0####, $C0000# style literals
const RAW_ADDR_RE = /(?<![#A-Za-z0-9_])(\$FFFF[0-9A-F]{4}|\$00FF[0-9A-F]{4}|\$A0[0-9A-F]{4}|\$C0000[04])(?:\.(?:w|l))?(?![0-9A-F])/;

const LOC_LABEL_RE = /^loc_[0-9A-F]+:/m;

// Files where raw addresses are allowed (constants / header files / opaque data modules)
const RAW_ADDR_ALLOW_FILES = new Set([
  'header.asm',
  'init.asm',
  'smgp_full.asm',
  'constants.asm',
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
  'audio_engine.asm',  // Z80 binary payload — opaque data, not a code module
]);

// Per-file allowlists for specific raw literals that are known exceptions
const RAW_ADDRESS_ALLOWLIST = {
  'src/core.asm': ['$00FF5980'],
  'src/race.asm': ['$00FF5980', '$00FF5AC2', '$00FF5C40'],
  'src/driving.asm': [],
  'src/rendering.asm': ['$00FF5980'],
  'src/menus.asm': [],
  'src/race_support.asm': ['$00FF5AC2', '$00FF5980'],
  'src/ai.asm': ['$00FF5980', '$00FF5AC2'],
  'src/audio_effects.asm': ['$00FF5AC4', '$00FF5AC8', '$00FF5ACC'],
  'src/objects.asm': ['$00FF5980'],
  'src/gameplay.asm': ['$00FF5980', '$00FF5AC2', '$00FF9100'],
};

// Lines starting with these tokens are data/macro lines — skip raw-addr check
const DATA_LINE_PREFIXES = [
  'dc.', 'dcb', 'ds.', 'txt macro', 'endm', 'while ', 'if ', 'elseif ', 'else', 'endif', 'substr ',
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Iterate all .asm files in the repo root and src/ subdirectory.
 * @returns {string[]} absolute paths
 */
function iterAsmFiles() {
  const files = [];
  for (const f of fs.readdirSync(REPO_ROOT).sort()) {
    if (f.endsWith('.asm')) files.push(path.join(REPO_ROOT, f));
  }
  const srcDir = path.join(REPO_ROOT, 'src');
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      if (f.endsWith('.asm')) files.push(path.join(srcDir, f));
    }
  }
  return files;
}

/**
 * Return the path relative to REPO_ROOT, using forward slashes.
 * @param {string} absPath
 * @returns {string}
 */
function relPath(absPath) {
  return path.relative(REPO_ROOT, absPath).replace(/\\/g, '/');
}

// ---------------------------------------------------------------------------
// Check implementations
// ---------------------------------------------------------------------------

function checkIncludeOrder(errors) {
  const text = fs.readFileSync(SMGP_ASM, { encoding: 'latin1' });
  const lines = text
    .split('\n')
    .map(l => l.trim())
    .filter(l => l.length > 0);

  if (JSON.stringify(lines) !== JSON.stringify(EXPECTED_INCLUDES)) {
    errors.push('smgp.asm include order does not match expected module layout');
  }
}

function checkSymbolMap(errors) {
  if (!fs.existsSync(SYMBOL_MAP)) {
    errors.push('missing tools/index/symbol_map.json');
    return;
  }
  const payload = JSON.parse(fs.readFileSync(SYMBOL_MAP, 'utf8'));
  const count = payload._meta && payload._meta.count;
  const symbols = payload.symbols || {};
  if (count !== Object.keys(symbols).length) {
    errors.push('symbol_map.json meta count does not match symbol table size');
  }
}

function checkNoLocLabels(errors) {
  for (const absPath of iterAsmFiles()) {
    const text = fs.readFileSync(absPath, { encoding: 'latin1' });
    if (LOC_LABEL_RE.test(text)) {
      errors.push(`legacy loc_ label definition found in ${relPath(absPath)}`);
    }
  }
}

function checkRawAddresses(errors) {
  for (const absPath of iterAsmFiles()) {
    const rel = relPath(absPath);
    // Skip files where raw addresses are expected
    const basename = path.basename(absPath);
    if (RAW_ADDR_ALLOW_FILES.has(basename)) continue;

    const allowedLiterals = RAW_ADDRESS_ALLOWLIST[rel] || [];
    const lines = fs.readFileSync(absPath, { encoding: 'latin1' }).split('\n');

    for (const line of lines) {
      const stripped = line.trim();
      if (!stripped || stripped.startsWith(';')) continue;
      // Skip data and macro directive lines
      const lowerStripped = stripped.toLowerCase();
      if (DATA_LINE_PREFIXES.some(p => lowerStripped.startsWith(p))) continue;

      // Only check the code portion (before any comment)
      const code = line.split(';')[0];
      const m = RAW_ADDR_RE.exec(code);
      if (m) {
        const literal = m[1];
        if (!allowedLiterals.includes(literal)) {
          errors.push(`raw address literal ${literal} found in ${rel}`);
          // continue checking remaining lines (same as Python behavior)
        }
      }
    }
  }
}

function checkBackslide(errors) {
  if (!fs.existsSync(LINT_BACKSLIDE)) {
    errors.push('missing tools/lint_backslide.js');
    return;
  }
  const { lintFile, EXEMPT_FILES } = require(LINT_BACKSLIDE);

  // Iterate the same file set the linter uses internally
  const files = [];
  for (const f of fs.readdirSync(REPO_ROOT).sort()) {
    if (f.endsWith('.asm') && !EXEMPT_FILES.has(f)) {
      files.push(path.join(REPO_ROOT, f));
    }
  }
  const srcDir = path.join(REPO_ROOT, 'src');
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      if (f.endsWith('.asm')) files.push(path.join(srcDir, f));
    }
  }

  for (const absPath of files) {
    const findings = lintFile(absPath);
    for (const f of findings) {
      if (!f.allowed) {
        errors.push(`backslide: ${f.file}:${f.line}: [${f.kind}] ${f.literal}`);
      }
    }
  }
}

function checkSplitSafety(errors) {  // check_split_addresses.js requires smgp.lst to exist
  const lstPath = path.join(REPO_ROOT, 'smgp.lst');
  if (!fs.existsSync(lstPath)) {
    // Not an error — just skip when no listing is present
    return;
  }
  if (!fs.existsSync(SYMBOL_MAP)) {
    errors.push('split-address check skipped: symbol_map.json missing');
    return;
  }

  const result = spawnSync(process.execPath, [CHECK_SPLIT], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    const message = (result.stdout || '').trim() || (result.stderr || '').trim() || 'split-address check failed';
    errors.push(message);
  }
}

function checkDupConstants(errors) {
  if (!fs.existsSync(LINT_DUP_CONSTANTS)) {
    errors.push('missing tools/lint_dup_constants.js');
    return;
  }
  const { scanConstantsFiles, findDuplicates } = require(LINT_DUP_CONSTANTS);
  const nameToFiles = scanConstantsFiles(REPO_ROOT);
  const dups = findDuplicates(nameToFiles);
  for (const { name, files } of dups) {
    errors.push(`duplicate constant: ${name} defined in ${files.join(', ')}`);
  }
}

function checkRawVdp(errors) {
  if (!fs.existsSync(LINT_RAW_VDP)) {
    errors.push('missing tools/lint_raw_vdp.js');
    return;
  }
  const { scanFile: vdpScanFile, FROZEN_COUNT: VDP_FROZEN, EXEMPT_FILES: VDP_EXEMPT } = require(LINT_RAW_VDP);

  let total = 0;
  const srcDir = path.join(REPO_ROOT, 'src');
  const allFiles = [];
  for (const f of fs.readdirSync(REPO_ROOT).sort()) {
    if (f.endsWith('.asm') && !VDP_EXEMPT.has(f)) allFiles.push(path.join(REPO_ROOT, f));
  }
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      if (f.endsWith('.asm') && !VDP_EXEMPT.has(f) && !VDP_EXEMPT.has(`src/${f}`)) {
        allFiles.push(path.join(srcDir, f));
      }
    }
  }
  for (const absPath of allFiles) total += vdpScanFile(absPath).length;

  if (total > VDP_FROZEN) {
    errors.push(
      `lint_raw_vdp: ${total} raw VDP register writes found; frozen baseline is ${VDP_FROZEN}`
    );
  }
}

function checkMagicNumbers(errors) {
  if (!fs.existsSync(AUDIT_MAGIC)) {
    errors.push('missing tools/audit_magic_numbers.js');
    return;
  }
  const { scanFile: magicScanFile, FROZEN_COUNT: MAGIC_FROZEN, EXEMPT_FILES: MAGIC_EXEMPT, DATA_MODULES } = require(AUDIT_MAGIC);

  let total = 0;
  const srcDir = path.join(REPO_ROOT, 'src');
  const allFiles = [];
  for (const f of fs.readdirSync(REPO_ROOT).sort()) {
    if (f.endsWith('.asm') && !MAGIC_EXEMPT.has(f)) allFiles.push(path.join(REPO_ROOT, f));
  }
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      const rel = `src/${f}`;
      if (f.endsWith('.asm') && !MAGIC_EXEMPT.has(rel) && !DATA_MODULES.has(rel)) {
        allFiles.push(path.join(srcDir, f));
      }
    }
  }
  for (const absPath of allFiles) total += magicScanFile(absPath).length;

  if (total > MAGIC_FROZEN) {
    errors.push(
      `audit_magic_numbers: ${total} uncommented decimal magic numbers found; frozen baseline is ${MAGIC_FROZEN}`
    );
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const errors = [];

  checkIncludeOrder(errors);
  checkSymbolMap(errors);
  checkNoLocLabels(errors);
  checkRawAddresses(errors);
  checkBackslide(errors);
  checkDupConstants(errors);
  checkRawVdp(errors);
  checkMagicNumbers(errors);
  checkSplitSafety(errors);

  if (errors.length > 0) {
    for (const err of errors) {
      console.error(`ERROR: ${err}`);
    }
    process.exit(1);
  }

  console.log('OK: all 9 checks passed (include order, symbol map, loc-label, raw-address, backslide, dup-constants, raw-vdp, magic-numbers, split)');
}

main();
