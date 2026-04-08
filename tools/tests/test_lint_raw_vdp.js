#!/usr/bin/env node
// tools/tests/test_lint_raw_vdp.js
//
// Tests for tools/lint_raw_vdp.js.
//
// Section A: Configuration invariants (FROZEN_COUNT, EXEMPT_FILES, VDP_REG_RE)
// Section B: scanFile() — clean synthetic files produce no findings
// Section C: scanFile() — VDP register writes are detected
// Section D: scanFile() — patterns that must NOT be flagged
// Section E: scanFile() — finding shape
// Section F: Real source files — total count matches frozen baseline

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const REPO_ROOT  = path.resolve(__dirname, '..', '..');
const LINT_JS    = path.join(REPO_ROOT, 'tools', 'lint_raw_vdp.js');

const { scanFile, FROZEN_COUNT, FROZEN_PER_FILE, EXEMPT_FILES, VDP_REG_RE } = require(LINT_JS);

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
  } catch (err) {
    failed++;
    console.error(`FAIL: ${name}`);
    console.error(`  ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// Helpers — write a temporary .asm file
// ---------------------------------------------------------------------------

let tmpDir = null;
function getTmpDir() {
  if (!tmpDir) tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-vdp-test-'));
  return tmpDir;
}

let tmpCounter = 0;
function writeTmpAsm(content) {
  const name = `_vdp_test_${++tmpCounter}.asm`;
  const absPath = path.join(getTmpDir(), name);
  fs.writeFileSync(absPath, content, 'latin1');
  return absPath;
}

// ---------------------------------------------------------------------------
// Section A: Configuration invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section A: Configuration invariants ===');

test('FROZEN_COUNT is a positive integer', () => {
  assert.ok(Number.isInteger(FROZEN_COUNT) && FROZEN_COUNT > 0);
});

test('FROZEN_COUNT matches sum of FROZEN_PER_FILE', () => {
  const sum = Object.values(FROZEN_PER_FILE).reduce((a, b) => a + b, 0);
  assert.strictEqual(sum, FROZEN_COUNT, `Sum of per-file counts (${sum}) != FROZEN_COUNT (${FROZEN_COUNT})`);
});

test('EXEMPT_FILES is a Set', () => {
  assert.ok(EXEMPT_FILES instanceof Set);
});

test('EXEMPT_FILES contains init.asm (intentional hardware setup)', () => {
  assert.ok(EXEMPT_FILES.has('init.asm'));
});

test('EXEMPT_FILES contains smgp_full.asm', () => {
  assert.ok(EXEMPT_FILES.has('smgp_full.asm'));
});

test('EXEMPT_FILES contains hw_constants.asm', () => {
  assert.ok(EXEMPT_FILES.has('hw_constants.asm'));
});

test('FROZEN_PER_FILE is a plain object', () => {
  assert.ok(typeof FROZEN_PER_FILE === 'object' && !Array.isArray(FROZEN_PER_FILE));
});

test('FROZEN_PER_FILE keys are all src/ paths', () => {
  for (const k of Object.keys(FROZEN_PER_FILE)) {
    assert.ok(k.startsWith('src/'), `Expected src/ path, got: ${k}`);
  }
});

test('VDP_REG_RE matches #$8NNN pattern', () => {
  assert.ok(VDP_REG_RE.test('#$8100'));
  assert.ok(VDP_REG_RE.test('#$8F00'));
  assert.ok(VDP_REG_RE.test('#$8000'));
});

test('VDP_REG_RE matches #$9NNN pattern', () => {
  assert.ok(VDP_REG_RE.test('#$9300'));
  assert.ok(VDP_REG_RE.test('#$9FFF'));
});

test('VDP_REG_RE does not match #$A000 (outside range)', () => {
  assert.ok(!VDP_REG_RE.test('#$A000'));
});

test('VDP_REG_RE does not match #$7FFF (outside range)', () => {
  assert.ok(!VDP_REG_RE.test('#$7FFF'));
});

test('VDP_REG_RE is case-insensitive for hex digits', () => {
  assert.ok(VDP_REG_RE.test('#$8a00'));
  assert.ok(VDP_REG_RE.test('#$8A00'));
});

// ---------------------------------------------------------------------------
// Section B: Clean files — no findings
// ---------------------------------------------------------------------------

console.log('\n=== Section B: Clean files produce no findings ===');

test('empty file — no findings', () => {
  const p = writeTmpAsm('');
  assert.deepStrictEqual(scanFile(p), []);
});

test('comment-only file — no findings', () => {
  const p = writeTmpAsm('; MOVE.w #$8100, VDP_control_port\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('blank lines — no findings', () => {
  const p = writeTmpAsm('\n\n\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('MOVE.w with named constant, no raw immediate — no findings', () => {
  const p = writeTmpAsm('\tMOVE.w\tVDP_reg_mode2, VDP_control_port\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('MOVE.l with raw VDP address (not MOVE.w) — not flagged', () => {
  // The linter only flags MOVE.w specifically
  const p = writeTmpAsm('\tMOVE.l\t#$8100, VDP_control_port\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('MOVE.w with $8xxx but NO VDP_control_port reference — not flagged', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$8100, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('MOVE.w writing #$8xxx to other destination — not flagged', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$8800, Some_ram_var\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('inline comment portion only has the pattern — not flagged', () => {
  // Raw VDP write is in the comment portion, code part is clean
  const p = writeTmpAsm('\tRTS\t; was MOVE.w #$8100, VDP_control_port\n');
  assert.deepStrictEqual(scanFile(p), []);
});

// ---------------------------------------------------------------------------
// Section C: VDP register writes are detected
// ---------------------------------------------------------------------------

console.log('\n=== Section C: VDP writes detected ===');

test('MOVE.w #$8100, VDP_control_port — flagged', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$8100, VDP_control_port\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
});

test('MOVE.w #$8F00, VDP_control_port — flagged', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$8F00, VDP_control_port\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
});

test('MOVE.w #$9300, VDP_control_port — flagged', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$9300, VDP_control_port\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
});

test('lowercase move.w #$8100 — flagged (case-insensitive)', () => {
  const p = writeTmpAsm('\tmove.w\t#$8100, VDP_control_port\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
});

test('multiple VDP writes in one file — all flagged', () => {
  const p = writeTmpAsm(
    '\tMOVE.w\t#$8100, VDP_control_port\n' +
    '\tMOVE.w\t#$8F00, VDP_control_port\n' +
    '\tMOVE.w\t#$9300, VDP_control_port\n'
  );
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 3);
});

test('line number is 1-indexed', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$8100, VDP_control_port\n');
  const findings = scanFile(p);
  assert.strictEqual(findings[0].line, 1);
});

test('line number tracks position correctly', () => {
  const p = writeTmpAsm(
    '; comment\n' +
    '\n' +
    '\tMOVE.w\t#$8100, VDP_control_port\n'
  );
  const findings = scanFile(p);
  assert.strictEqual(findings[0].line, 3);
});

// ---------------------------------------------------------------------------
// Section D: Patterns that must NOT be flagged
// ---------------------------------------------------------------------------

console.log('\n=== Section D: Non-VDP patterns ignored ===');

test('dc.b line with $81 byte — not flagged', () => {
  const p = writeTmpAsm('\tdc.b\t$81, $00\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('MOVE.w DMA command long #$40000080 — not flagged (8 hex digits)', () => {
  const p = writeTmpAsm('\tMOVE.l\t#$40000080, VDP_control_port\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('CMPI.w with $8000 but no VDP_control_port — not flagged', () => {
  const p = writeTmpAsm('\tCMPI.w\t#$8000, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

// ---------------------------------------------------------------------------
// Section E: Finding shape
// ---------------------------------------------------------------------------

console.log('\n=== Section E: Finding shape ===');

test('finding has file, line, context fields', () => {
  const p = writeTmpAsm('\tMOVE.w\t#$8100, VDP_control_port\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
  const f = findings[0];
  assert.ok(typeof f.file    === 'string', 'file should be string');
  assert.ok(typeof f.line    === 'number', 'line should be number');
  assert.ok(typeof f.context === 'string', 'context should be string');
});

test('finding.file is a string (path relative to repo root when inside repo)', () => {
  // When scanning a file inside the repo, relPath() produces a relative path.
  // When scanning a temp file outside the repo root, Node's path.relative()
  // returns an absolute path — that is acceptable behaviour for out-of-repo files.
  // We just assert the field is a non-empty string.
  const p = writeTmpAsm('\tMOVE.w\t#$8100, VDP_control_port\n');
  const f = scanFile(p)[0];
  assert.ok(typeof f.file === 'string' && f.file.length > 0, `file should be non-empty string, got: ${f.file}`);
});

test('finding.context contains the original line content', () => {
  const line = '\tMOVE.w\t#$8100, VDP_control_port';
  const p = writeTmpAsm(line + '\n');
  const f = scanFile(p)[0];
  assert.ok(f.context.includes('#$8100'), `context should include raw line: ${f.context}`);
});

// ---------------------------------------------------------------------------
// Section F: Real source files — total count matches frozen baseline
// ---------------------------------------------------------------------------

console.log('\n=== Section F: Real source files — frozen baseline ===');

const CODE_MODULES = [
  'src/core.asm',
  'src/endgame.asm',
  'src/gameplay.asm',
  'src/menus.asm',
  'src/objects.asm',
  'src/race.asm',
  'src/driving.asm',
  'src/rendering.asm',
  'src/race_support.asm',
  'src/ai.asm',
  'src/audio_effects.asm',
];

test('total raw VDP writes across all code modules equals FROZEN_COUNT', () => {
  let total = 0;
  for (const rel of CODE_MODULES) {
    const abs = path.join(REPO_ROOT, rel);
    if (fs.existsSync(abs)) total += scanFile(abs).length;
  }
  assert.strictEqual(
    total,
    FROZEN_COUNT,
    `Expected ${FROZEN_COUNT} total VDP writes, got ${total}`
  );
});

// Per-file counts for the frozen files
for (const [rel, expectedCount] of Object.entries(FROZEN_PER_FILE)) {
  test(`${rel} — VDP write count matches FROZEN_PER_FILE (${expectedCount})`, () => {
    const abs = path.join(REPO_ROOT, rel);
    if (!fs.existsSync(abs)) return; // skip if module absent
    const count = scanFile(abs).length;
    assert.strictEqual(
      count,
      expectedCount,
      `Expected ${expectedCount} in ${rel}, got ${count}`
    );
  });
}

test('src/driving.asm — 0 raw VDP writes (not in FROZEN_PER_FILE)', () => {
  const abs = path.join(REPO_ROOT, 'src', 'driving.asm');
  if (!fs.existsSync(abs)) return;
  assert.strictEqual(scanFile(abs).length, 0);
});

test('src/ai.asm — 0 raw VDP writes (not in FROZEN_PER_FILE)', () => {
  const abs = path.join(REPO_ROOT, 'src', 'ai.asm');
  if (!fs.existsSync(abs)) return;
  assert.strictEqual(scanFile(abs).length, 0);
});

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
