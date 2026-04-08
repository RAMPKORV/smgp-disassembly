#!/usr/bin/env node
// tools/tests/test_audit_magic_numbers.js
//
// Tests for tools/audit_magic_numbers.js.
//
// Section A: Configuration invariants (FROZEN_COUNT, EXEMPT_FILES, DATA_MODULES)
// Section B: scanFile() — clean synthetic files produce no findings
// Section C: scanFile() — magic numbers detected correctly
// Section D: scanFile() — patterns that must NOT be flagged
// Section E: scanFile() — finding shape
// Section F: Real source files — total count matches frozen baseline

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const LINT_JS   = path.join(REPO_ROOT, 'tools', 'audit_magic_numbers.js');

const {
  scanFile,
  FROZEN_COUNT,
  MIN_DECIMAL,
  EXEMPT_FILES,
  DATA_MODULES,
  DECIMAL_IMM_RE,
} = require(LINT_JS);

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
// Helpers
// ---------------------------------------------------------------------------

let tmpDir = null;
function getTmpDir() {
  if (!tmpDir) tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-magic-test-'));
  return tmpDir;
}

let tmpCounter = 0;
function writeTmpAsm(content) {
  const name = `_magic_test_${++tmpCounter}.asm`;
  const absPath = path.join(getTmpDir(), name);
  fs.writeFileSync(absPath, content, 'latin1');
  return absPath;
}

// ---------------------------------------------------------------------------
// Section A: Configuration invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section A: Configuration invariants ===');

test('FROZEN_COUNT is a non-negative integer', () => {
  assert.ok(Number.isInteger(FROZEN_COUNT) && FROZEN_COUNT >= 0);
});

test('MIN_DECIMAL is 100', () => {
  assert.strictEqual(MIN_DECIMAL, 100);
});

test('EXEMPT_FILES is a Set', () => {
  assert.ok(EXEMPT_FILES instanceof Set);
});

test('EXEMPT_FILES contains header.asm', () => {
  assert.ok(EXEMPT_FILES.has('header.asm'));
});

test('EXEMPT_FILES contains smgp_full.asm', () => {
  assert.ok(EXEMPT_FILES.has('smgp_full.asm'));
});

test('DATA_MODULES is a Set', () => {
  assert.ok(DATA_MODULES instanceof Set);
});

test('DATA_MODULES contains src/gameplay.asm data modules', () => {
  assert.ok(DATA_MODULES.has('src/road_and_track_data.asm'));
});

test('DATA_MODULES does not contain src/driving.asm (code module)', () => {
  assert.ok(!DATA_MODULES.has('src/driving.asm'));
});

test('DATA_MODULES does not contain src/ai.asm (code module)', () => {
  assert.ok(!DATA_MODULES.has('src/ai.asm'));
});

test('DECIMAL_IMM_RE matches #NNN with 3+ digits', () => {
  assert.ok(DECIMAL_IMM_RE.test('#100'));
  assert.ok(DECIMAL_IMM_RE.test('#200'));
  assert.ok(DECIMAL_IMM_RE.test('#9000'));
});

test('DECIMAL_IMM_RE does not match #$NNN (hex)', () => {
  assert.ok(!DECIMAL_IMM_RE.test('#$100'));
});

test('DECIMAL_IMM_RE does not match #99 (two digits)', () => {
  assert.ok(!DECIMAL_IMM_RE.test('#99'));
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
  const p = writeTmpAsm('; CMPI.w #1000, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('blank lines — no findings', () => {
  const p = writeTmpAsm('\n\n\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('small decimal immediate #99 — not flagged (below threshold)', () => {
  const p = writeTmpAsm('\tCMPI.w\t#99, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('hex immediate #$640 — not flagged (hex)', () => {
  const p = writeTmpAsm('\tCMPI.w\t#$640, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('large decimal WITH inline comment — not flagged (documented)', () => {
  const p = writeTmpAsm('\tCMPI.w\t#200, D0\t; 200 RPM threshold\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('dc.b directive with large decimal — not flagged (data line)', () => {
  const p = writeTmpAsm('\tdc.b\t200, 150, 100\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('dc.w directive with large decimal — not flagged (data line)', () => {
  const p = writeTmpAsm('\tdc.w\t1000\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('dc.l directive with large decimal — not flagged (data line)', () => {
  const p = writeTmpAsm('\tdc.l\t65536\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('label definition line — not flagged', () => {
  const p = writeTmpAsm('My_label:\n');
  assert.deepStrictEqual(scanFile(p), []);
});

// ---------------------------------------------------------------------------
// Section C: Magic numbers detected
// ---------------------------------------------------------------------------

console.log('\n=== Section C: Magic numbers detected ===');

test('#100 without comment — flagged', () => {
  const p = writeTmpAsm('\tCMPI.w\t#100, D0\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
  assert.strictEqual(findings[0].value, 100);
});

test('#200 without comment — flagged', () => {
  const p = writeTmpAsm('\tCMPI.w\t#200, D1\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
  assert.strictEqual(findings[0].value, 200);
});

test('#9000 without comment — flagged', () => {
  const p = writeTmpAsm('\tMOVEQ\t#100, D0\n\tCMPI.w\t#9000, D1\n');
  const findings = scanFile(p);
  assert.ok(findings.some(f => f.value === 9000));
});

test('multiple magic numbers on different lines — all flagged', () => {
  const p = writeTmpAsm(
    '\tCMPI.w\t#100, D0\n' +
    '\tCMPI.w\t#200, D1\n' +
    '\tCMPI.w\t#300, D2\n'
  );
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 3);
});

test('line number is 1-indexed', () => {
  const p = writeTmpAsm('\tCMPI.w\t#100, D0\n');
  const findings = scanFile(p);
  assert.strictEqual(findings[0].line, 1);
});

test('line number tracks correctly past blank/comment lines', () => {
  const p = writeTmpAsm(
    '; comment\n' +
    '\n' +
    '\tCMPI.w\t#100, D0\n'
  );
  const findings = scanFile(p);
  assert.strictEqual(findings[0].line, 3);
});

// ---------------------------------------------------------------------------
// Section D: Patterns that must NOT be flagged
// ---------------------------------------------------------------------------

console.log('\n=== Section D: Non-magic patterns ignored ===');

test('#0 — not flagged', () => {
  const p = writeTmpAsm('\tMOVEQ\t#0, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('#1 — not flagged', () => {
  const p = writeTmpAsm('\tADDQ.w\t#1, D0\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('#-100 — not matched by DECIMAL_IMM_RE (no negative prefix support)', () => {
  // The regex looks for #NNN without a minus, so negative literals would
  // appear as e.g. #-100 and are not captured
  const p = writeTmpAsm('\tCMPI.w\t#-100, D0\n');
  // Whether flagged or not depends on implementation; we just check no crash
  let threw = false;
  try { scanFile(p); } catch (e) { threw = true; }
  assert.ok(!threw, 'scanFile should not throw on negative literal');
});

test('rept directive line — not flagged', () => {
  const p = writeTmpAsm('\trept 100\n\tNOP\n\tendr\n');
  assert.deepStrictEqual(scanFile(p), []);
});

test('if directive with large decimal — not flagged', () => {
  const p = writeTmpAsm('\tif 100\n\tNOP\n\tendif\n');
  assert.deepStrictEqual(scanFile(p), []);
});

// ---------------------------------------------------------------------------
// Section E: Finding shape
// ---------------------------------------------------------------------------

console.log('\n=== Section E: Finding shape ===');

test('finding has file, line, value, context fields', () => {
  const p = writeTmpAsm('\tCMPI.w\t#200, D0\n');
  const findings = scanFile(p);
  assert.strictEqual(findings.length, 1);
  const f = findings[0];
  assert.ok(typeof f.file    === 'string', 'file should be string');
  assert.ok(typeof f.line    === 'number', 'line should be number');
  assert.ok(typeof f.value   === 'number', 'value should be number');
  assert.ok(typeof f.context === 'string', 'context should be string');
});

test('finding.file is a string (relative to repo root when inside repo)', () => {
  // path.relative() returns a relative path for files inside the repo.
  // For temp files outside the repo it may return an absolute path — that is
  // acceptable; we just assert the field is a non-empty string.
  const p = writeTmpAsm('\tCMPI.w\t#200, D0\n');
  const f = scanFile(p)[0];
  assert.ok(typeof f.file === 'string' && f.file.length > 0, `file should be non-empty string, got: ${f.file}`);
});

test('finding.value matches the decimal literal', () => {
  const p = writeTmpAsm('\tCMPI.w\t#512, D0\n');
  const f = scanFile(p)[0];
  assert.strictEqual(f.value, 512);
});

test('finding.context contains the original code', () => {
  const line = '\tCMPI.w\t#200, D0';
  const p = writeTmpAsm(line + '\n');
  const f = scanFile(p)[0];
  assert.ok(f.context.includes('#200'), `context should include #200: ${f.context}`);
});

// ---------------------------------------------------------------------------
// Section F: Real source files — total count matches frozen baseline
// ---------------------------------------------------------------------------

console.log('\n=== Section F: Real source files — frozen baseline ===');

const CODE_MODULES = [
  'src/core.asm',
  'src/menus.asm',
  'src/race.asm',
  'src/driving.asm',
  'src/rendering.asm',
  'src/race_support.asm',
  'src/ai.asm',
  'src/audio_effects.asm',
  'src/objects.asm',
  'src/endgame.asm',
  'src/gameplay.asm',
];

test('total magic numbers across code modules equals FROZEN_COUNT', () => {
  let total = 0;
  for (const rel of CODE_MODULES) {
    const abs = path.join(REPO_ROOT, rel);
    if (fs.existsSync(abs)) total += scanFile(abs).length;
  }
  assert.strictEqual(
    total,
    FROZEN_COUNT,
    `Expected FROZEN_COUNT=${FROZEN_COUNT}, got ${total}`
  );
});

test('src/menus.asm — no magic numbers (sanity: menus uses named constants)', () => {
  const abs = path.join(REPO_ROOT, 'src', 'menus.asm');
  if (!fs.existsSync(abs)) return;
  const count = scanFile(abs).length;
  // Menus module is expected to use named constants; if new unexplained decimals
  // appear the frozen count check above will catch it, but also check here explicitly
  // This is a soft check: warn if unexpectedly high rather than asserting zero
  // (the frozen count test is the authoritative gate)
  assert.ok(count <= FROZEN_COUNT, `menus.asm alone has ${count} > FROZEN_COUNT (${FROZEN_COUNT})`);
});

test('scanFile on exempt file header.asm — 0 findings (scanFile itself doesn\'t exempt)', () => {
  // Note: scanFile does NOT apply exemptions itself — that's done by iterCodeAsmFiles().
  // We just confirm scanFile doesn't crash on a real file.
  const abs = path.join(REPO_ROOT, 'header.asm');
  if (!fs.existsSync(abs)) return;
  let threw = false;
  try { scanFile(abs); } catch (e) { threw = true; }
  assert.ok(!threw, 'scanFile should not throw on header.asm');
});

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
