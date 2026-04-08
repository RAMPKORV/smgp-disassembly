#!/usr/bin/env node
// tools/tests/test_lint_backslide.js
//
// Tests for tools/lint_backslide.js.
//
// Section A: EXEMPT_FILES / DATA_MODULES configuration invariants
// Section B: lintFile() — clean synthetic files produce no findings
// Section C: lintFile() — RAW_ADDR detection (new violations flagged)
// Section D: lintFile() — RAW_ADDR allowlist suppression
// Section E: lintFile() — RAW_PTR detection in dc.l lines
// Section F: lintFile() — lines that must NOT be flagged (comment lines, data lines)
// Section G: RAW_ADDR_ALLOWLIST frozen count invariant
// Section H: lintFile() against real source files — 0 new findings

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const REPO_ROOT       = path.resolve(__dirname, '..', '..');
const LINT_JS         = path.join(REPO_ROOT, 'tools', 'lint_backslide.js');

const { lintFile, RAW_ADDR_ALLOWLIST, EXEMPT_FILES, DATA_MODULES } = require(LINT_JS);

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
// Helpers — write a temporary .asm file and call lintFile on it
// ---------------------------------------------------------------------------

let tmpDir = null;

function getTmpDir() {
  if (!tmpDir) tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-lint-test-'));
  return tmpDir;
}

/**
 * Write content to a temp file that lintFile() will treat as if it were at
 * relativeRepoPath inside REPO_ROOT.  We achieve this by writing the file
 * at a path under REPO_ROOT so relPath() resolves correctly.
 *
 * Because we must NOT corrupt real source files, we write to a unique name
 * inside an otherwise-empty sub-path that isn't monitored by the linter
 * (lintFile takes a specific abs path — we pass it directly).
 *
 * Returns the absolute path written.
 */
let tmpCounter = 0;
function writeTmpAsm(content) {
  const name = `_lint_test_${++tmpCounter}.asm`;
  const absPath = path.join(getTmpDir(), name);
  fs.writeFileSync(absPath, content, 'latin1');
  return absPath;
}

// ---------------------------------------------------------------------------
// Section A: EXEMPT_FILES / DATA_MODULES configuration invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section A: Configuration invariants ===');

test('EXEMPT_FILES is a Set', () => {
  assert.ok(EXEMPT_FILES instanceof Set, 'EXEMPT_FILES should be a Set');
});

test('EXEMPT_FILES contains hw_constants.asm', () => {
  assert.ok(EXEMPT_FILES.has('hw_constants.asm'));
});

test('EXEMPT_FILES contains ram_addresses.asm', () => {
  assert.ok(EXEMPT_FILES.has('ram_addresses.asm'));
});

test('EXEMPT_FILES contains sound_constants.asm', () => {
  assert.ok(EXEMPT_FILES.has('sound_constants.asm'));
});

test('EXEMPT_FILES contains header.asm', () => {
  assert.ok(EXEMPT_FILES.has('header.asm'));
});

test('EXEMPT_FILES contains smgp_full.asm', () => {
  assert.ok(EXEMPT_FILES.has('smgp_full.asm'));
});

test('DATA_MODULES is a Set', () => {
  assert.ok(DATA_MODULES instanceof Set, 'DATA_MODULES should be a Set');
});

test('DATA_MODULES contains src/road_and_track_data.asm', () => {
  assert.ok(DATA_MODULES.has('src/road_and_track_data.asm'));
});

test('DATA_MODULES contains src/audio_engine.asm', () => {
  assert.ok(DATA_MODULES.has('src/audio_engine.asm'));
});

test('DATA_MODULES contains src/track_config_data.asm', () => {
  assert.ok(DATA_MODULES.has('src/track_config_data.asm'));
});

test('DATA_MODULES does not contain src/core.asm (code module)', () => {
  assert.ok(!DATA_MODULES.has('src/core.asm'));
});

test('DATA_MODULES does not contain src/driving.asm (code module)', () => {
  assert.ok(!DATA_MODULES.has('src/driving.asm'));
});

test('RAW_ADDR_ALLOWLIST is an object', () => {
  assert.strictEqual(typeof RAW_ADDR_ALLOWLIST, 'object');
  assert.ok(RAW_ADDR_ALLOWLIST !== null);
});

test('RAW_ADDR_ALLOWLIST keys are src/ paths or empty', () => {
  for (const key of Object.keys(RAW_ADDR_ALLOWLIST)) {
    assert.ok(key.startsWith('src/'), `Expected src/ path, got: ${key}`);
  }
});

test('each allowlist entry has literal and reason fields', () => {
  for (const [file, entries] of Object.entries(RAW_ADDR_ALLOWLIST)) {
    for (const entry of entries) {
      assert.ok(typeof entry.literal === 'string', `${file}: entry missing literal`);
      assert.ok(typeof entry.reason  === 'string', `${file}: entry missing reason`);
    }
  }
});

test('all allowlisted literals start with $', () => {
  for (const [file, entries] of Object.entries(RAW_ADDR_ALLOWLIST)) {
    for (const entry of entries) {
      assert.ok(entry.literal.startsWith('$'), `${file}: literal should start with $: ${entry.literal}`);
    }
  }
});

// ---------------------------------------------------------------------------
// Section B: Clean synthetic files — no findings
// ---------------------------------------------------------------------------

console.log('\n=== Section B: Clean files produce no findings ===');

test('empty file — no findings', () => {
  const p = writeTmpAsm('');
  assert.deepStrictEqual(lintFile(p), []);
});

test('comment-only file — no findings', () => {
  const p = writeTmpAsm('; This is a comment\n; Another comment\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('clean instruction with named constant — no findings', () => {
  const p = writeTmpAsm('\tMOVE.w\tPlayer_shift.w, D0\n\tRTS\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('clean dc.l with named label — no findings', () => {
  const p = writeTmpAsm('\tdc.l\tUpdate_shift\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('dc.b blob data — no findings (not a pointer-range value)', () => {
  const p = writeTmpAsm('\tdc.b\t$FF, $00, $01, $7F\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('instruction with small hex constant — not flagged', () => {
  // $00FF and $FFFF prefixes define the pattern, $001F is not in that range
  const p = writeTmpAsm('\tCMPI.w\t#$001F, D0\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('instruction with VDP write pattern — $C00004 not flagged outside regex', () => {
  // $C00004 matches $C0000[04], but only in exempt files — in a code module it should be flagged
  // Here we confirm it IS flagged (tested in section C), not silently skipped
  const p = writeTmpAsm('\tMOVE.w\t#$0000, $C00004\n');
  const findings = lintFile(p);
  // The VDP port pattern is flagged as a RAW_ADDR finding in code modules
  assert.ok(findings.length >= 1, 'Expected at least one finding for $C00004 in code');
});

// ---------------------------------------------------------------------------
// Section C: RAW_ADDR detection — new violations are flagged
// ---------------------------------------------------------------------------

console.log('\n=== Section C: RAW_ADDR detection ===');

test('$FFFF9100 in instruction line — flagged as RAW_ADDR', () => {
  const p = writeTmpAsm('\tMOVE.w\tD0, $FFFF9100\n');
  const findings = lintFile(p);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.ok(addrs.length >= 1, 'Expected RAW_ADDR finding');
  assert.ok(addrs.some(f => f.literal === '$FFFF9100'), 'Expected $FFFF9100');
});

test('$00FF5980 in instruction line — flagged as RAW_ADDR', () => {
  const p = writeTmpAsm('\tMOVEQ\t#0, $00FF5980\n');
  const findings = lintFile(p);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.ok(addrs.some(f => f.literal === '$00FF5980'), 'Expected $00FF5980');
});

test('$A09000 in instruction line — flagged as RAW_ADDR', () => {
  const p = writeTmpAsm('\tMOVE.b\t$A09000, D1\n');
  const findings = lintFile(p);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.ok(addrs.some(f => f.literal === '$A09000'), 'Expected $A09000');
});

test('$C00000 in instruction line — flagged as RAW_ADDR', () => {
  const p = writeTmpAsm('\tMOVE.w\tD0, $C00000\n');
  const findings = lintFile(p);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.ok(addrs.some(f => f.literal === '$C00000'), 'Expected $C00000');
});

test('$C00004 in instruction line — flagged as RAW_ADDR', () => {
  const p = writeTmpAsm('\tMOVE.l\tD0, $C00004\n');
  const findings = lintFile(p);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.ok(addrs.some(f => f.literal === '$C00004'), 'Expected $C00004');
});

test('finding has correct file, line, kind, literal, context fields', () => {
  const p = writeTmpAsm('\tMOVE.w\tD0, $FFFF9100\n');
  const findings = lintFile(p);
  assert.ok(findings.length >= 1);
  const f = findings[0];
  assert.ok(typeof f.file    === 'string');
  assert.ok(typeof f.line    === 'number');
  assert.ok(typeof f.kind    === 'string');
  assert.ok(typeof f.literal === 'string');
  assert.ok(typeof f.context === 'string');
  assert.ok(typeof f.allowed === 'boolean');
  assert.strictEqual(f.line, 1);
  assert.strictEqual(f.kind, 'RAW_ADDR');
});

test('finding allowed=false for unlisted literal', () => {
  const p = writeTmpAsm('\tMOVE.w\tD0, $FFFF9100\n');
  const findings = lintFile(p);
  assert.ok(findings.length >= 1);
  assert.strictEqual(findings[0].allowed, false);
});

test('multiple raw addresses on different lines — all flagged', () => {
  const p = writeTmpAsm('\tMOVE.w\tD0, $FFFF9100\n\tMOVE.b\t$A09000, D1\n');
  const findings = lintFile(p);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.ok(addrs.length >= 2, `Expected >=2 RAW_ADDR findings, got ${addrs.length}`);
});

// ---------------------------------------------------------------------------
// Section D: RAW_ADDR allowlist suppression
// ---------------------------------------------------------------------------

console.log('\n=== Section D: Allowlist suppression ===');

test('src/core.asm allowlist contains $00FF5980', () => {
  const entries = RAW_ADDR_ALLOWLIST['src/core.asm'] || [];
  assert.ok(entries.some(e => e.literal === '$00FF5980'), 'Expected $00FF5980 in core.asm allowlist');
});

test('src/audio_effects.asm allowlist has 3 entries', () => {
  const entries = RAW_ADDR_ALLOWLIST['src/audio_effects.asm'] || [];
  assert.strictEqual(entries.length, 3, `Expected 3, got ${entries.length}`);
});

test('lintFile finding.allowed=true for a literal matching the file allowlist', () => {
  // We need to call lintFile on the real src/core.asm which has the allowlisted $00FF5980
  const realCore = path.join(REPO_ROOT, 'src', 'core.asm');
  if (!fs.existsSync(realCore)) {
    // skip gracefully if file not present
    return;
  }
  const findings = lintFile(realCore);
  const ff = findings.filter(f => f.literal === '$00FF5980');
  assert.ok(ff.length >= 1, 'Expected at least one $00FF5980 finding in core.asm');
  assert.ok(ff.every(f => f.allowed === true), 'All $00FF5980 findings should be allowed');
});

test('lintFile on real src/audio_effects.asm — all findings are allowed', () => {
  const realFile = path.join(REPO_ROOT, 'src', 'audio_effects.asm');
  if (!fs.existsSync(realFile)) return;
  const findings = lintFile(realFile);
  const newFindings = findings.filter(f => !f.allowed);
  assert.strictEqual(newFindings.length, 0, `Unexpected new findings in audio_effects.asm: ${JSON.stringify(newFindings)}`);
});

test('lintFile on real src/driving.asm — no RAW_ADDR findings (empty allowlist)', () => {
  const realFile = path.join(REPO_ROOT, 'src', 'driving.asm');
  if (!fs.existsSync(realFile)) return;
  const findings = lintFile(realFile);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.strictEqual(addrs.length, 0, `Unexpected RAW_ADDR findings in driving.asm: ${JSON.stringify(addrs)}`);
});

test('lintFile on real src/menus.asm — no RAW_ADDR findings (empty allowlist)', () => {
  const realFile = path.join(REPO_ROOT, 'src', 'menus.asm');
  if (!fs.existsSync(realFile)) return;
  const findings = lintFile(realFile);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.strictEqual(addrs.length, 0, `Unexpected RAW_ADDR findings in menus.asm: ${JSON.stringify(addrs)}`);
});

// ---------------------------------------------------------------------------
// Section E: RAW_PTR detection in dc.l lines
// ---------------------------------------------------------------------------

console.log('\n=== Section E: RAW_PTR detection ===');

test('dc.l with ROM-range address — flagged as RAW_PTR', () => {
  const p = writeTmpAsm('\tdc.l\t$012345\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.ok(ptrs.length >= 1, 'Expected RAW_PTR finding');
  assert.ok(ptrs.some(f => f.literal === '$012345'), 'Expected $012345');
});

test('dc.l with address at ROM boundary $000100 — flagged', () => {
  const p = writeTmpAsm('\tdc.l\t$000100\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.ok(ptrs.length >= 1, `Expected RAW_PTR for $000100, got ${ptrs.length}`);
});

test('dc.l with address $07FFFF (top of ROM) — flagged', () => {
  const p = writeTmpAsm('\tdc.l\t$07FFFF\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.ok(ptrs.length >= 1, 'Expected RAW_PTR for $07FFFF');
});

test('dc.l with very small value $0000FF — NOT flagged (below $000100 threshold)', () => {
  const p = writeTmpAsm('\tdc.l\t$0000FF\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.strictEqual(ptrs.length, 0, 'Expected no RAW_PTR for $0000FF');
});

test('dc.l with value above ROM range $080000 — NOT flagged (outside ROM window)', () => {
  const p = writeTmpAsm('\tdc.l\t$080000\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.strictEqual(ptrs.length, 0, 'Expected no RAW_PTR for $080000 (above ROM range)');
});

test('dc.l with RAM address $FFFF0000 — NOT flagged as RAW_PTR (only 6 hex digits match)', () => {
  // $FFFF0000 is 8 hex digits so doesn't match RAW_PTR_RE; $FF0000 is in RAM range above $07FFFF
  const p = writeTmpAsm('\tdc.l\t$FF0000\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.strictEqual(ptrs.length, 0, 'Expected no RAW_PTR for $FF0000 (RAM, above ROM range)');
});

test('RAW_PTR finding has correct kind and allowed=false', () => {
  const p = writeTmpAsm('\tdc.l\t$012345\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.ok(ptrs.length >= 1);
  assert.strictEqual(ptrs[0].kind, 'RAW_PTR');
  assert.strictEqual(ptrs[0].allowed, false);
  assert.strictEqual(ptrs[0].line, 1);
});

test('dc.w with ROM-range address — flagged as RAW_PTR', () => {
  const p = writeTmpAsm('\tdc.w\t$012345\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.ok(ptrs.length >= 1, 'Expected RAW_PTR on dc.w line');
});

test('instruction line with ROM-range value — NOT flagged as RAW_PTR (only dc.l/dc.w checked)', () => {
  // An instruction referencing e.g. a literal $012345 is not a dc.l line
  const p = writeTmpAsm('\tMOVE.l\tD0, $012345\n');
  const findings = lintFile(p);
  const ptrs = findings.filter(f => f.kind === 'RAW_PTR');
  assert.strictEqual(ptrs.length, 0, 'RAW_PTR should not fire on instruction lines');
});

// ---------------------------------------------------------------------------
// Section F: Lines that must NOT be flagged
// ---------------------------------------------------------------------------

console.log('\n=== Section F: Lines immune to flagging ===');

test('pure comment line with raw address — not flagged', () => {
  const p = writeTmpAsm('; MOVE.w D0, $FFFF9100  <- old code\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('inline comment portion of line — only code portion checked', () => {
  // The raw address is only in the comment, not before the semicolon
  const p = writeTmpAsm('\tRTS\t; was $FFFF9100\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('dc.b line — RAW_ADDR not checked (data prefix)', () => {
  // dc.b lines are in DATA_PREFIXES so should be skipped for RAW_ADDR check
  const p = writeTmpAsm('\tdc.b\t$FF, $A0, $C0\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('blank line — not flagged', () => {
  const p = writeTmpAsm('\n\n\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('label definition line — not flagged', () => {
  const p = writeTmpAsm('My_label:\n');
  assert.deepStrictEqual(lintFile(p), []);
});

test('data module dc.l with ROM pointer — NOT flagged (data module exempt from RAW_PTR)', () => {
  // We use src/road_and_track_data.asm which is in DATA_MODULES
  // lintFile is called with real path so rel path resolves correctly
  // Simulate by checking that DATA_MODULES membership actually skips checks:
  // We write a temp file and can't easily make it "look like" a data module,
  // but we can verify via the real data module file instead.
  const realFile = path.join(REPO_ROOT, 'src', 'road_and_track_data.asm');
  if (!fs.existsSync(realFile)) return;
  const findings = lintFile(realFile);
  // road_and_track_data.asm uses incbin — should have 0 findings of any kind
  assert.strictEqual(findings.length, 0, `Expected 0 findings in road_and_track_data.asm`);
});

// ---------------------------------------------------------------------------
// Section G: RAW_ADDR_ALLOWLIST frozen count invariant
// ---------------------------------------------------------------------------

console.log('\n=== Section G: Allowlist frozen count ===');

// Count total individual allowlisted entries across all files
const totalAllowlisted = Object.values(RAW_ADDR_ALLOWLIST)
  .reduce((sum, arr) => sum + arr.length, 0);

test('total allowlisted entries is at most 29 (frozen — must not grow)', () => {
  assert.ok(totalAllowlisted <= 29, `Allowlist has grown beyond 29: ${totalAllowlisted}`);
});

test('total allowlisted entries is at least 1 (sanity check)', () => {
  assert.ok(totalAllowlisted >= 1, 'Allowlist should have at least 1 entry');
});

test('all allowlisted entries reference pending AUDIO-001 or similar justification', () => {
  for (const [file, entries] of Object.entries(RAW_ADDR_ALLOWLIST)) {
    for (const entry of entries) {
      assert.ok(entry.reason.length > 0, `${file}: allowlist entry has empty reason for ${entry.literal}`);
    }
  }
});

test('src/gameplay.asm allowlist contains $00FF9100 (YM2612 register)', () => {
  const entries = RAW_ADDR_ALLOWLIST['src/gameplay.asm'] || [];
  assert.ok(entries.some(e => e.literal === '$00FF9100'), 'Expected $00FF9100 in gameplay.asm allowlist');
});

test('src/race.asm allowlist contains $00FF5C40', () => {
  const entries = RAW_ADDR_ALLOWLIST['src/race.asm'] || [];
  assert.ok(entries.some(e => e.literal === '$00FF5C40'), 'Expected $00FF5C40 in race.asm allowlist');
});

test('src/audio_effects.asm allowlist contains $00FF5AC4, $00FF5AC8, $00FF5ACC', () => {
  const entries = RAW_ADDR_ALLOWLIST['src/audio_effects.asm'] || [];
  const lits = entries.map(e => e.literal);
  assert.ok(lits.includes('$00FF5AC4'), 'Expected $00FF5AC4');
  assert.ok(lits.includes('$00FF5AC8'), 'Expected $00FF5AC8');
  assert.ok(lits.includes('$00FF5ACC'), 'Expected $00FF5ACC');
});

// ---------------------------------------------------------------------------
// Section H: Real source files — 0 new (unapproved) findings
// ---------------------------------------------------------------------------

console.log('\n=== Section H: Real source files — 0 new findings ===');

// The code modules to check (same set the linter iterates internally)
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

for (const rel of CODE_MODULES) {
  test(`${rel} — 0 new unapproved findings`, () => {
    const absPath = path.join(REPO_ROOT, rel);
    if (!fs.existsSync(absPath)) return; // skip if module not present
    const findings = lintFile(absPath);
    const newFindings = findings.filter(f => !f.allowed);
    assert.strictEqual(
      newFindings.length,
      0,
      `New findings in ${rel}: ${JSON.stringify(newFindings.map(f => `${f.line}: ${f.literal}`))}`
    );
  });
}

// Also check that endgame.asm (empty allowlist) has no RAW_ADDR violations
test('src/endgame.asm — no RAW_ADDR findings', () => {
  const absPath = path.join(REPO_ROOT, 'src', 'endgame.asm');
  if (!fs.existsSync(absPath)) return;
  const findings = lintFile(absPath);
  const addrs = findings.filter(f => f.kind === 'RAW_ADDR');
  assert.strictEqual(addrs.length, 0, `Unexpected RAW_ADDR in endgame.asm: ${JSON.stringify(addrs)}`);
});

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
