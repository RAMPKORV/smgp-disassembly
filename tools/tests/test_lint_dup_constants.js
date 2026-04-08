#!/usr/bin/env node
// tools/tests/test_lint_dup_constants.js
//
// Tests for tools/lint_dup_constants.js.
//
// Section A: CONSTANTS_FILES configuration invariants
// Section B: scanConstantsFiles() — synthetic temp dirs
// Section C: findDuplicates() — unit tests on plain Maps
// Section D: scanConstantsFiles() against real repo — 0 duplicates
// Section E: CONST_RE pattern correctness (via scanConstantsFiles with synthetic data)

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const LINT_JS   = path.join(REPO_ROOT, 'tools', 'lint_dup_constants.js');

const { CONSTANTS_FILES, scanConstantsFiles, findDuplicates } = require(LINT_JS);

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
// Helpers — create a synthetic repo root with stub constants files
// ---------------------------------------------------------------------------

let tmpDir = null;
function getTmpDir() {
  if (!tmpDir) tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-dup-test-'));
  return tmpDir;
}

/**
 * Write synthetic constants files under tmpRoot.
 * @param {string} tmpRoot
 * @param {Object<string,string>} fileContents  rel path → content
 * @returns {string} tmpRoot (for chaining)
 */
function writeSyntheticRepo(fileContents) {
  const tmpRoot = getTmpDir();
  for (const [rel, content] of Object.entries(fileContents)) {
    const abs = path.join(tmpRoot, rel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, content, 'latin1');
  }
  return tmpRoot;
}

// ---------------------------------------------------------------------------
// Section A: CONSTANTS_FILES configuration invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section A: Configuration invariants ===');

test('CONSTANTS_FILES is an Array', () => {
  assert.ok(Array.isArray(CONSTANTS_FILES), 'CONSTANTS_FILES should be an Array');
});

test('CONSTANTS_FILES has exactly 4 entries', () => {
  assert.strictEqual(CONSTANTS_FILES.length, 4, `Expected 4, got ${CONSTANTS_FILES.length}`);
});

test('CONSTANTS_FILES contains hw_constants.asm', () => {
  assert.ok(CONSTANTS_FILES.includes('hw_constants.asm'));
});

test('CONSTANTS_FILES contains ram_addresses.asm', () => {
  assert.ok(CONSTANTS_FILES.includes('ram_addresses.asm'));
});

test('CONSTANTS_FILES contains sound_constants.asm', () => {
  assert.ok(CONSTANTS_FILES.includes('sound_constants.asm'));
});

test('CONSTANTS_FILES contains game_constants.asm', () => {
  assert.ok(CONSTANTS_FILES.includes('game_constants.asm'));
});

// ---------------------------------------------------------------------------
// Section B: scanConstantsFiles() — synthetic repos
// ---------------------------------------------------------------------------

console.log('\n=== Section B: scanConstantsFiles() synthetic ===');

test('empty constants files — returns empty Map', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    '',
    'ram_addresses.asm':   '',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(result instanceof Map);
  assert.strictEqual(result.size, 0);
});

test('single unique constant — appears in Map once', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    'VDP_data_port = $C00000\n',
    'ram_addresses.asm':   '',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(result.has('VDP_data_port'), 'Expected VDP_data_port');
  assert.deepStrictEqual(result.get('VDP_data_port'), ['hw_constants.asm']);
});

test('constant in two files — appears in Map with both files', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    'Some_const = $1234\n',
    'ram_addresses.asm':   'Some_const = $5678\n',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(result.has('Some_const'));
  const files = result.get('Some_const');
  assert.ok(files.includes('hw_constants.asm'));
  assert.ok(files.includes('ram_addresses.asm'));
  assert.strictEqual(files.length, 2);
});

test('comment-only lines are skipped', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    '; VDP_data_port = $C00000\n',
    'ram_addresses.asm':   '',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(!result.has('VDP_data_port'), 'Comment line should not register a constant');
});

test('blank lines are skipped', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    '\n\n\nFoo = 1\n\n',
    'ram_addresses.asm':   '',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(result.has('Foo'));
  assert.strictEqual(result.size, 1);
});

test('multiple constants in one file — all captured', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    'Alpha = 1\nBeta = 2\nGamma = 3\n',
    'ram_addresses.asm':   '',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(result.has('Alpha'));
  assert.ok(result.has('Beta'));
  assert.ok(result.has('Gamma'));
  assert.strictEqual(result.size, 3);
});

test('UPPER_SNAKE_CASE constant name recognised', () => {
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    'KEY_START = $40\n',
    'ram_addresses.asm':   '',
    'sound_constants.asm': '',
    'game_constants.asm':  '',
  });
  const result = scanConstantsFiles(tmpRoot);
  assert.ok(result.has('KEY_START'));
});

test('missing constants file is silently skipped (no crash)', () => {
  // Only provide 2 of the 4 files; the others are absent
  const tmpRoot = writeSyntheticRepo({
    'hw_constants.asm':    'Only_hw = 1\n',
    'ram_addresses.asm':   'Only_ram = 2\n',
    // sound_constants.asm and game_constants.asm deliberately absent
  });
  // Should not throw
  let threw = false;
  try {
    scanConstantsFiles(tmpRoot);
  } catch (e) {
    threw = true;
  }
  assert.ok(!threw, 'scanConstantsFiles should not throw for missing files');
});

// ---------------------------------------------------------------------------
// Section C: findDuplicates() — unit tests
// ---------------------------------------------------------------------------

console.log('\n=== Section C: findDuplicates() ===');

test('empty Map — returns empty array', () => {
  const result = findDuplicates(new Map());
  assert.deepStrictEqual(result, []);
});

test('all unique entries — returns empty array', () => {
  const m = new Map([
    ['Foo', ['hw_constants.asm']],
    ['Bar', ['ram_addresses.asm']],
  ]);
  assert.deepStrictEqual(findDuplicates(m), []);
});

test('one duplicate — returns that entry', () => {
  const m = new Map([
    ['Foo', ['hw_constants.asm', 'ram_addresses.asm']],
    ['Bar', ['game_constants.asm']],
  ]);
  const dups = findDuplicates(m);
  assert.strictEqual(dups.length, 1);
  assert.strictEqual(dups[0].name, 'Foo');
  assert.deepStrictEqual(dups[0].files, ['hw_constants.asm', 'ram_addresses.asm']);
});

test('two duplicates — returns both', () => {
  const m = new Map([
    ['A', ['hw_constants.asm', 'ram_addresses.asm']],
    ['B', ['sound_constants.asm', 'game_constants.asm']],
    ['C', ['hw_constants.asm']],
  ]);
  const dups = findDuplicates(m);
  assert.strictEqual(dups.length, 2);
  const names = dups.map(d => d.name).sort();
  assert.deepStrictEqual(names, ['A', 'B']);
});

test('entry in all four files — returned as duplicate', () => {
  const m = new Map([
    ['Multi', ['hw_constants.asm', 'ram_addresses.asm', 'sound_constants.asm', 'game_constants.asm']],
  ]);
  const dups = findDuplicates(m);
  assert.strictEqual(dups.length, 1);
  assert.strictEqual(dups[0].files.length, 4);
});

test('findDuplicates result has name and files properties', () => {
  const m = new Map([['X', ['a.asm', 'b.asm']]]);
  const dups = findDuplicates(m);
  assert.ok(typeof dups[0].name === 'string');
  assert.ok(Array.isArray(dups[0].files));
});

// ---------------------------------------------------------------------------
// Section D: Real repo — 0 duplicates
// ---------------------------------------------------------------------------

console.log('\n=== Section D: Real repo — 0 duplicates ===');

test('real repo — scanConstantsFiles returns a non-empty Map', () => {
  const result = scanConstantsFiles(REPO_ROOT);
  assert.ok(result instanceof Map);
  assert.ok(result.size > 0, `Expected >0 constants, got ${result.size}`);
});

test('real repo — total constant count >= 500 (sanity)', () => {
  const result = scanConstantsFiles(REPO_ROOT);
  assert.ok(result.size >= 500, `Expected >= 500 constants, got ${result.size}`);
});

test('real repo — findDuplicates returns empty array (0 duplicates)', () => {
  const map  = scanConstantsFiles(REPO_ROOT);
  const dups = findDuplicates(map);
  assert.deepStrictEqual(
    dups,
    [],
    `Unexpected duplicates: ${JSON.stringify(dups.map(d => d.name))}`
  );
});

test('real repo — hw_constants.asm contributes at least 10 constants', () => {
  const result = scanConstantsFiles(REPO_ROOT);
  let hwCount = 0;
  for (const files of result.values()) {
    if (files.includes('hw_constants.asm')) hwCount++;
  }
  assert.ok(hwCount >= 10, `Expected >= 10 from hw_constants.asm, got ${hwCount}`);
});

test('real repo — ram_addresses.asm contributes at least 100 constants', () => {
  const result = scanConstantsFiles(REPO_ROOT);
  let ramCount = 0;
  for (const files of result.values()) {
    if (files.includes('ram_addresses.asm')) ramCount++;
  }
  assert.ok(ramCount >= 100, `Expected >= 100 from ram_addresses.asm, got ${ramCount}`);
});

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
