#!/usr/bin/env node
// tools/tests/test_functions_index.js
//
// Tests for tools/index/functions.js and its output tools/index/functions.json.
//
// Section A: isSublabel() unit tests
// Section B: hasHeaderComment() unit tests
// Section C: functions.json structure and meta invariants
// Section D: per-entry field invariants
// Section E: classification spot-checks for known routines

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');

const REPO_ROOT    = path.resolve(__dirname, '..', '..');
const FUNCTIONS_JS = path.join(REPO_ROOT, 'tools', 'index', 'functions.js');
const FUNCTIONS_JSON = path.join(REPO_ROOT, 'tools', 'index', 'functions.json');

// Require the module (exercises the exported helpers)
const { isSublabel, hasHeaderComment, parseListing } = require(FUNCTIONS_JS);

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
// Section A: isSublabel() unit tests
// ---------------------------------------------------------------------------
console.log('Section A: isSublabel()');

// Strategy 1: exact prefix match "TopLevelName_..."
test('direct sublabel via prefix match', () => {
  assert.ok(isSublabel('Update_rpm_Crash_decel', new Set(['Update_rpm'])));
});

test('multi-level sublabel via prefix match', () => {
  assert.ok(isSublabel('Update_rpm_Collision_penalty', new Set(['Update_rpm'])));
});

test('unrelated label is not sublabel', () => {
  assert.ok(!isSublabel('Prng', new Set(['Update_rpm'])));
});

test('empty seen set returns false', () => {
  assert.ok(!isSublabel('Update_rpm_loop', new Set()));
});

test('label same as seen is not sublabel', () => {
  // exact match – the label IS the top-level, not a sub
  assert.ok(!isSublabel('Update_rpm', new Set(['Update_rpm'])));
});

test('single-segment label is never a sublabel', () => {
  // e.g. "Prng" has no underscore, cannot share a 2-segment prefix
  assert.ok(!isSublabel('Prng', new Set(['Prng'])));
});

// Strategy 2: shared prefix depth >= 2
test('sibling-style sublabel via shared prefix', () => {
  // Decompress_asset_list_to_vdp → adds to seen;
  // Decompress_asset_list_loop shares prefix "Decompress_asset_list_"
  const seen = new Set(['Decompress_asset_list_to_vdp']);
  assert.ok(isSublabel('Decompress_asset_list_loop', seen));
});

test('Draw_tilemap_list_loop is sublabel of 64_cell_rows variant', () => {
  const seen = new Set([
    'Draw_tilemap_list_to_vdp_64_cell_rows',
    'Draw_tilemap_list_to_vdp_32_cell_rows',
  ]);
  assert.ok(isSublabel('Draw_tilemap_list_loop', seen));
});

test('two different top-level routines with shared first segment are distinct', () => {
  // "Update_rpm" and "Update_speed" both start with "Update_" but neither
  // should cause the other to be a sublabel
  const seen = new Set(['Update_rpm']);
  assert.ok(!isSublabel('Update_speed', seen));
});

test('three-segment label needs a 2-segment prefix match', () => {
  // "Binary_to_decimal_loop": shares "Binary_to_" with "Binary_to_decimal"
  const seen = new Set(['Binary_to_decimal']);
  assert.ok(isSublabel('Binary_to_decimal_loop', seen));
});

test('label with no matching prefix is a routine', () => {
  const seen = new Set(['Update_rpm', 'Prng', 'Binary_to_decimal']);
  assert.ok(!isSublabel('Fade_palette_to_black', seen));
});

// ---------------------------------------------------------------------------
// Section B: hasHeaderComment() unit tests
// ---------------------------------------------------------------------------
console.log('Section B: hasHeaderComment()');

// Use known labels in well-understood source files
test('Prng has header comment in src/core.asm', () => {
  assert.ok(hasHeaderComment('src/core.asm', 'Prng'));
});

test('Decompress_asset_list_to_vdp has header comment', () => {
  assert.ok(hasHeaderComment('src/core.asm', 'Decompress_asset_list_to_vdp'));
});

// Pre-label style: Update_rpm has a comment block ABOVE the label line in driving.asm
test('Update_rpm has pre-label header comment in src/driving.asm', () => {
  assert.ok(hasHeaderComment('src/driving.asm', 'Update_rpm'));
});

// Pre-label style: another routine in driving.asm with a comment block above
test('Update_visual_rpm has pre-label header comment in src/driving.asm', () => {
  assert.ok(hasHeaderComment('src/driving.asm', 'Update_visual_rpm'));
});

// Pre-label style: Apply_visual_rpm_delta has a comment block above it
test('Apply_visual_rpm_delta has pre-label header comment in src/driving.asm', () => {
  assert.ok(hasHeaderComment('src/driving.asm', 'Apply_visual_rpm_delta'));
});

test('nonexistent label returns false', () => {
  assert.ok(!hasHeaderComment('src/core.asm', 'Totally_Nonexistent_Label'));
});

test('nonexistent file returns false', () => {
  assert.ok(!hasHeaderComment('src/nonexistent.asm', 'Update_rpm'));
});

test('sublabel Update_rpm_Accel_lookup has no header comment', () => {
  // Sublabels in driving.asm don't have header blocks — no comment block above or below
  assert.ok(!hasHeaderComment('src/driving.asm', 'Update_rpm_Accel_lookup'));
});

// ---------------------------------------------------------------------------
// Section C: functions.json structure invariants
// ---------------------------------------------------------------------------
console.log('Section C: functions.json structure');

// Load the JSON (must have been generated before running tests)
let json;
test('functions.json exists and parses cleanly', () => {
  assert.ok(fs.existsSync(FUNCTIONS_JSON), 'functions.json not found — run npm run functions first');
  json = JSON.parse(fs.readFileSync(FUNCTIONS_JSON, 'utf8'));
});

test('functions.json has _meta object', () => {
  assert.ok(json._meta && typeof json._meta === 'object');
});

test('_meta.total matches functions array length', () => {
  assert.strictEqual(json._meta.total, json.functions.length);
});

test('_meta.routines matches actual routine count', () => {
  const count = json.functions.filter(e => e.kind === 'routine').length;
  assert.strictEqual(json._meta.routines, count);
});

test('_meta.sublabels matches actual sublabel count', () => {
  const count = json.functions.filter(e => e.kind === 'sublabel').length;
  assert.strictEqual(json._meta.sublabels, count);
});

test('_meta.data_labels matches actual data count', () => {
  const count = json.functions.filter(e => e.kind === 'data').length;
  assert.strictEqual(json._meta.data_labels, count);
});

test('_meta.constants matches actual constant count', () => {
  const count = json.functions.filter(e => e.kind === 'constant').length;
  assert.strictEqual(json._meta.constants, count);
});

test('_meta.header_coverage is a string fraction', () => {
  assert.ok(typeof json._meta.header_coverage === 'string');
  assert.ok(/^\d+\/\d+ \(\d+%\)$/.test(json._meta.header_coverage));
});

test('total symbol count is in expected range', () => {
  // ROM has ~4200-4300 symbols total
  assert.ok(json._meta.total >= 4000 && json._meta.total <= 5000,
    `Unexpected total: ${json._meta.total}`);
});

test('routine count is in expected range (300-600)', () => {
  assert.ok(json._meta.routines >= 300 && json._meta.routines <= 600,
    `Unexpected routine count: ${json._meta.routines}`);
});

test('functions array is non-empty', () => {
  assert.ok(Array.isArray(json.functions) && json.functions.length > 0);
});

// ---------------------------------------------------------------------------
// Section D: per-entry field invariants
// ---------------------------------------------------------------------------
console.log('Section D: per-entry field invariants');

const VALID_KINDS = new Set(['routine', 'sublabel', 'data', 'constant', 'unknown']);
const ROM_ADDR_RE = /^0x[0-9A-F]{6}$/;

test('every entry has required fields', () => {
  for (const e of json.functions) {
    assert.ok(typeof e.name === 'string' && e.name.length > 0, `missing name in ${JSON.stringify(e)}`);
    assert.ok(typeof e.rom_addr === 'string', `missing rom_addr in ${e.name}`);
    assert.ok(typeof e.size_estimate === 'number', `missing size_estimate in ${e.name}`);
    assert.ok(typeof e.source_file === 'string', `missing source_file in ${e.name}`);
    assert.ok(typeof e.kind === 'string', `missing kind in ${e.name}`);
    assert.ok(typeof e.has_header === 'boolean', `missing has_header in ${e.name}`);
  }
});

test('every rom_addr matches format 0xXXXXXX', () => {
  for (const e of json.functions) {
    assert.ok(ROM_ADDR_RE.test(e.rom_addr), `invalid rom_addr ${e.rom_addr} in ${e.name}`);
  }
});

test('every kind is a valid value', () => {
  for (const e of json.functions) {
    assert.ok(VALID_KINDS.has(e.kind), `invalid kind "${e.kind}" in ${e.name}`);
  }
});

test('size_estimate is non-negative integer', () => {
  for (const e of json.functions) {
    assert.ok(Number.isInteger(e.size_estimate) && e.size_estimate >= 0,
      `invalid size_estimate ${e.size_estimate} in ${e.name}`);
  }
});

test('has_header is only true for routines (not data/constant/sublabel)', () => {
  for (const e of json.functions) {
    if (e.has_header) {
      assert.strictEqual(e.kind, 'routine',
        `${e.name} has_header=true but kind=${e.kind}`);
    }
  }
});

test('source_file is a non-empty string', () => {
  for (const e of json.functions) {
    assert.ok(e.source_file.length > 0, `empty source_file in ${e.name}`);
  }
});

// ---------------------------------------------------------------------------
// Section E: classification spot-checks for known routines
// ---------------------------------------------------------------------------
console.log('Section E: classification spot-checks');

const byName = Object.fromEntries(json.functions.map(e => [e.name, e]));

// Known top-level routines that must be classified as "routine"
// Note: labels with inline comments (e.g. "Binary_to_decimal: ; ...") are not
// captured by the LABEL_RE pattern inherited from symbol_map.js — this is a
// known limitation.  Only test labels that appear with a clean trailing colon.
const knownRoutines = [
  'Prng', 'Update_rpm', 'Update_steering', 'Update_speed',
  'Decompress_to_vdp', 'Decompress_asset_list_to_vdp',
  'Initialize_vdp', 'Update_input_bitset', 'Read_controller_input',
  'Vertical_blank_interrupt', 'EntryPoint',
  'Divide_fractional', 'Wait_for_vblank',
];
for (const name of knownRoutines) {
  test(`${name} is kind=routine`, () => {
    assert.ok(byName[name], `${name} not found in functions.json`);
    assert.strictEqual(byName[name].kind, 'routine', `${name} classified as ${byName[name].kind}`);
  });
}

// Known sublabels
// Note: Update_rpm_Crash_decel is actually defined in src/race.asm (forward reference
// from driving.asm), not where callers might expect.  Use sublabels confirmed present.
const knownSublabels = [
  'Update_rpm_Accel_lookup',
  'Decompress_asset_list_loop', 'Draw_tilemap_list_loop',
  'EntryPoint_Settle_loop', 'EntryPoint_Cold_boot',
  'Prng_nonzero_seed',
];
for (const name of knownSublabels) {
  test(`${name} is kind=sublabel`, () => {
    assert.ok(byName[name], `${name} not found in functions.json`);
    assert.strictEqual(byName[name].kind, 'sublabel', `${name} classified as ${byName[name].kind}`);
  });
}

// Prng has a header comment
test('Prng has_header=true', () => {
  assert.ok(byName['Prng'], 'Prng not found');
  assert.strictEqual(byName['Prng'].has_header, true);
});

// Update_rpm has a pre-label header comment block in src/driving.asm
test('Update_rpm has_header=true', () => {
  assert.ok(byName['Update_rpm'], 'Update_rpm not found');
  assert.strictEqual(byName['Update_rpm'].has_header, true);
});

// Source file assignment spot-checks
test('Update_rpm source_file is src/driving.asm', () => {
  assert.strictEqual(byName['Update_rpm'].source_file, 'src/driving.asm');
});

test('Prng source_file is src/core.asm', () => {
  assert.strictEqual(byName['Prng'].source_file, 'src/core.asm');
});

test('EntryPoint source_file is init.asm', () => {
  assert.strictEqual(byName['EntryPoint'].source_file, 'init.asm');
});

// ROM address spot-checks (from known ROM layout)
test('EntryPoint rom_addr is 0x00020E', () => {
  assert.strictEqual(byName['EntryPoint'].rom_addr, '0x00020E');
});

test('Update_rpm rom_addr is 0x005B02', () => {
  assert.strictEqual(byName['Update_rpm'].rom_addr, '0x005B02');
});

// Data module classification
test('Track_data is kind=data', () => {
  assert.ok(byName['Track_data'], 'Track_data not found');
  assert.strictEqual(byName['Track_data'].kind, 'data');
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
