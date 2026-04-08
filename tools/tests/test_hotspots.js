#!/usr/bin/env node
// tools/tests/test_hotspots.js
//
// Tests for tools/index/hotspots.js and its output tools/index/hotspots.json.
//
// Section A: getRefStats() unit tests (inline helper)
// Section B: buildHotspots() logic unit tests (synthetic data)
// Section C: hotspots.json structure invariants
// Section D: per-entry field invariants
// Section E: known spot-checks against the real index

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');

const REPO_ROOT      = path.resolve(__dirname, '..', '..');
const HOTSPOTS_JS    = path.join(REPO_ROOT, 'tools', 'index', 'hotspots.js');
const HOTSPOTS_JSON  = path.join(REPO_ROOT, 'tools', 'index', 'hotspots.json');

const { getRefStats, buildHotspots } = require(HOTSPOTS_JS);

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
// Synthetic data helpers
// ---------------------------------------------------------------------------

function makeCallsites(refs) {
  // refs: { LabelName: [ { kind, in_function }, ... ] }
  const full = {};
  for (const [k, v] of Object.entries(refs)) {
    full[k] = v.map((s, i) => Object.assign({
      file: 'src/test.asm', line: i + 1, context: 'JSR ' + k
    }, s));
  }
  return { _meta: {}, refs: full };
}

function makeFunctions(routines) {
  // routines: [ { name, rom_addr?, size_estimate?, source_file?, has_header?, kind? } ]
  return {
    _meta: {},
    functions: routines.map(r => Object.assign({
      rom_addr: '0x001000', size_estimate: 10,
      source_file: 'src/core.asm', has_header: false, kind: 'routine'
    }, r)),
  };
}

// ---------------------------------------------------------------------------
// Section A: getRefStats() unit tests
// ---------------------------------------------------------------------------

console.log('\n=== Section A: getRefStats() ===');

test('unknown label returns zero stats', () => {
  const stats = getRefStats('NonExistent_label_xyz');
  assert.strictEqual(stats.total, 0);
  assert.strictEqual(stats.calls, 0);
  assert.strictEqual(stats.branches, 0);
  assert.deepStrictEqual(stats.callers, []);
});

test('Wait_for_vblank has > 0 total refs', () => {
  const stats = getRefStats('Wait_for_vblank');
  assert.ok(stats.total > 0, `expected > 0, got ${stats.total}`);
});

test('Wait_for_vblank call count matches total (all calls, no branches)', () => {
  const stats = getRefStats('Wait_for_vblank');
  assert.strictEqual(stats.calls, stats.total,
    'Wait_for_vblank should be all calls');
  assert.strictEqual(stats.branches, 0);
});

test('callers array contains strings', () => {
  const stats = getRefStats('Wait_for_vblank');
  assert.ok(Array.isArray(stats.callers));
  for (const c of stats.callers) {
    assert.strictEqual(typeof c, 'string');
  }
});

test('single-call label has callers length >= 1', () => {
  // Fade_palette_to_black is a hotspot so it definitely has callers
  const stats = getRefStats('Fade_palette_to_black');
  assert.ok(stats.callers.length >= 1);
});

// ---------------------------------------------------------------------------
// Section B: buildHotspots() logic unit tests (synthetic data)
// ---------------------------------------------------------------------------

console.log('\n=== Section B: buildHotspots() logic ===');

// Minimal synthetic: one unreferenced, one single-site, one hotspot
const synCallsites = makeCallsites({
  Hot_routine: Array.from({ length: 12 }, (_, i) => ({
    kind: 'call', in_function: i < 6 ? 'Caller_A' : 'Caller_B'
  })),
  Single_routine: [{ kind: 'branch', in_function: 'Caller_A' }],
  // Dead_routine has no refs
});

const synFunctions = makeFunctions([
  { name: 'Hot_routine',    rom_addr: '0x001000', has_header: true  },
  { name: 'Single_routine', rom_addr: '0x002000', has_header: false },
  { name: 'Dead_routine',   rom_addr: '0x003000', has_header: false },
  { name: 'Data_label',     rom_addr: '0x004000', kind: 'data'      }, // not routine
]);

const synResult = buildHotspots(synCallsites, synFunctions, 10);

test('synthetic: unreferenced contains Dead_routine', () => {
  const names = synResult.unreferenced.map(r => r.name);
  assert.ok(names.includes('Dead_routine'), `names=${JSON.stringify(names)}`);
});

test('synthetic: unreferenced does NOT contain Hot_routine', () => {
  const names = synResult.unreferenced.map(r => r.name);
  assert.ok(!names.includes('Hot_routine'));
});

test('synthetic: unreferenced does NOT contain Data_label (not routine)', () => {
  const names = synResult.unreferenced.map(r => r.name);
  assert.ok(!names.includes('Data_label'));
});

test('synthetic: single_site contains Single_routine', () => {
  const names = synResult.single_site.map(r => r.name);
  assert.ok(names.includes('Single_routine'), `names=${JSON.stringify(names)}`);
});

test('synthetic: single_site entry has sole_caller field', () => {
  const entry = synResult.single_site.find(r => r.name === 'Single_routine');
  assert.ok(entry, 'Single_routine not found in single_site');
  assert.strictEqual(entry.sole_caller, 'Caller_A');
});

test('synthetic: single_site entry has branch_count 1', () => {
  const entry = synResult.single_site.find(r => r.name === 'Single_routine');
  assert.strictEqual(entry.branch_count, 1);
  assert.strictEqual(entry.call_count, 0);
});

test('synthetic: hotspots contains Hot_routine', () => {
  const names = synResult.hotspots.map(r => r.name);
  assert.ok(names.includes('Hot_routine'), `names=${JSON.stringify(names)}`);
});

test('synthetic: Hot_routine ref_count == 12', () => {
  const entry = synResult.hotspots.find(r => r.name === 'Hot_routine');
  assert.strictEqual(entry.ref_count, 12);
});

test('synthetic: Hot_routine call_count == 12', () => {
  const entry = synResult.hotspots.find(r => r.name === 'Hot_routine');
  assert.strictEqual(entry.call_count, 12);
});

test('synthetic: Hot_routine top_callers has 2 entries', () => {
  const entry = synResult.hotspots.find(r => r.name === 'Hot_routine');
  assert.strictEqual(entry.top_callers.length, 2);
});

test('synthetic: top_callers sorted descending by count', () => {
  const entry = synResult.hotspots.find(r => r.name === 'Hot_routine');
  for (let i = 0; i + 1 < entry.top_callers.length; i++) {
    assert.ok(entry.top_callers[i].count >= entry.top_callers[i + 1].count,
      'top_callers should be sorted descending');
  }
});

test('synthetic: hotspots sorted descending by ref_count', () => {
  for (let i = 0; i + 1 < synResult.hotspots.length; i++) {
    assert.ok(synResult.hotspots[i].ref_count >= synResult.hotspots[i + 1].ref_count);
  }
});

test('synthetic: Single_routine not in hotspots (only 1 ref)', () => {
  const names = synResult.hotspots.map(r => r.name);
  assert.ok(!names.includes('Single_routine'));
});

// Threshold boundary tests
test('buildHotspots threshold=1 includes single-site routines in hotspots', () => {
  const r = buildHotspots(synCallsites, synFunctions, 1);
  const names = r.hotspots.map(x => x.name);
  assert.ok(names.includes('Single_routine'), 'threshold=1 should include single-site');
});

test('buildHotspots threshold=100 returns empty hotspots', () => {
  const r = buildHotspots(synCallsites, synFunctions, 100);
  assert.strictEqual(r.hotspots.length, 0);
});

test('buildHotspots unreferenced sorted by rom_addr ascending', () => {
  // add two unreferenced routines in reverse order
  const cs = makeCallsites({});
  const fns = makeFunctions([
    { name: 'B_routine', rom_addr: '0x002000' },
    { name: 'A_routine', rom_addr: '0x001000' },
  ]);
  const r = buildHotspots(cs, fns, 10);
  assert.strictEqual(r.unreferenced[0].name, 'A_routine');
  assert.strictEqual(r.unreferenced[1].name, 'B_routine');
});

// Empty inputs
test('buildHotspots with empty refs/functions returns empty arrays', () => {
  const r = buildHotspots({ _meta: {}, refs: {} }, { _meta: {}, functions: [] }, 10);
  assert.strictEqual(r.unreferenced.length, 0);
  assert.strictEqual(r.single_site.length, 0);
  assert.strictEqual(r.hotspots.length, 0);
});

// ---------------------------------------------------------------------------
// Section C: hotspots.json structure invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section C: hotspots.json structure invariants ===');

let data;
test('hotspots.json exists and is valid JSON', () => {
  assert.ok(fs.existsSync(HOTSPOTS_JSON), 'hotspots.json not found');
  data = JSON.parse(fs.readFileSync(HOTSPOTS_JSON, 'utf8'));
});

test('hotspots.json has _meta object', () => {
  assert.ok(data && typeof data._meta === 'object');
});

test('_meta.total_routines is positive integer', () => {
  assert.ok(Number.isInteger(data._meta.total_routines) && data._meta.total_routines > 0);
});

test('_meta.headered_routines <= total_routines', () => {
  assert.ok(data._meta.headered_routines <= data._meta.total_routines);
});

test('_meta.header_coverage_pct ends with %', () => {
  assert.ok(data._meta.header_coverage_pct.endsWith('%'));
});

test('_meta.unreferenced_count matches unreferenced_routines array length', () => {
  assert.strictEqual(data._meta.unreferenced_count, data.unreferenced_routines.length);
});

test('_meta.single_site_count matches single_site_routines array length', () => {
  assert.strictEqual(data._meta.single_site_count, data.single_site_routines.length);
});

test('_meta.hotspot_count matches hotspots array length', () => {
  assert.strictEqual(data._meta.hotspot_count, data.hotspots.length);
});

test('hotspots.json has unreferenced_routines array', () => {
  assert.ok(Array.isArray(data.unreferenced_routines));
});

test('hotspots.json has single_site_routines array', () => {
  assert.ok(Array.isArray(data.single_site_routines));
});

test('hotspots.json has hotspots array', () => {
  assert.ok(Array.isArray(data.hotspots));
});

test('hotspot_threshold is a positive integer', () => {
  assert.ok(Number.isInteger(data._meta.hotspot_threshold) && data._meta.hotspot_threshold > 0);
});

test('source array contains callsites.json and functions.json', () => {
  assert.ok(Array.isArray(data._meta.source));
  assert.ok(data._meta.source.includes('callsites.json'));
  assert.ok(data._meta.source.includes('functions.json'));
});

// ---------------------------------------------------------------------------
// Section D: per-entry field invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section D: per-entry field invariants ===');

const REQUIRED_BASE = ['name', 'rom_addr', 'size_estimate', 'source_file', 'has_header'];

test('all unreferenced_routines have required base fields', () => {
  for (const r of data.unreferenced_routines) {
    for (const f of REQUIRED_BASE) {
      assert.ok(f in r, `unreferenced entry "${r.name}" missing field "${f}"`);
    }
  }
});

test('unreferenced_routines rom_addr is hex string starting with 0x', () => {
  for (const r of data.unreferenced_routines) {
    assert.ok(typeof r.rom_addr === 'string' && r.rom_addr.startsWith('0x'),
      `rom_addr "${r.rom_addr}" invalid for "${r.name}"`);
  }
});

test('unreferenced_routines sorted ascending by rom_addr', () => {
  const addrs = data.unreferenced_routines.map(r => parseInt(r.rom_addr, 16));
  for (let i = 0; i + 1 < addrs.length; i++) {
    assert.ok(addrs[i] <= addrs[i + 1],
      `unreferenced_routines not sorted at index ${i}: ${data.unreferenced_routines[i].name}`);
  }
});

test('all single_site_routines have required base fields', () => {
  for (const r of data.single_site_routines) {
    for (const f of REQUIRED_BASE) {
      assert.ok(f in r, `single_site entry "${r.name}" missing field "${f}"`);
    }
  }
});

test('all single_site_routines have ref_count == 1', () => {
  for (const r of data.single_site_routines) {
    assert.strictEqual(r.ref_count, 1,
      `single_site entry "${r.name}" has ref_count ${r.ref_count}, expected 1`);
  }
});

test('single_site_routines have sole_site field with file/line/kind', () => {
  for (const r of data.single_site_routines) {
    assert.ok(r.sole_site && typeof r.sole_site.file === 'string',
      `"${r.name}" missing sole_site.file`);
    assert.ok(typeof r.sole_site.line === 'number',
      `"${r.name}" missing sole_site.line`);
    assert.ok(typeof r.sole_site.kind === 'string',
      `"${r.name}" missing sole_site.kind`);
  }
});

test('all hotspots have required base fields', () => {
  for (const r of data.hotspots) {
    for (const f of REQUIRED_BASE) {
      assert.ok(f in r, `hotspot entry "${r.name}" missing field "${f}"`);
    }
  }
});

test('all hotspots have ref_count >= threshold', () => {
  const thresh = data._meta.hotspot_threshold;
  for (const r of data.hotspots) {
    assert.ok(r.ref_count >= thresh,
      `hotspot "${r.name}" ref_count ${r.ref_count} < threshold ${thresh}`);
  }
});

test('hotspots sorted descending by ref_count', () => {
  for (let i = 0; i + 1 < data.hotspots.length; i++) {
    assert.ok(data.hotspots[i].ref_count >= data.hotspots[i + 1].ref_count,
      `hotspots not sorted at index ${i}`);
  }
});

test('hotspots have top_callers array of <= 5 entries', () => {
  for (const r of data.hotspots) {
    assert.ok(Array.isArray(r.top_callers), `"${r.name}" missing top_callers`);
    assert.ok(r.top_callers.length <= 5,
      `"${r.name}" has ${r.top_callers.length} top_callers, expected <= 5`);
  }
});

test('top_callers entries have caller (string) and count (positive int) fields', () => {
  for (const r of data.hotspots) {
    for (const tc of r.top_callers) {
      assert.ok(typeof tc.caller === 'string', `top_caller.caller not string in "${r.name}"`);
      assert.ok(Number.isInteger(tc.count) && tc.count > 0,
        `top_caller.count invalid in "${r.name}"`);
    }
  }
});

test('has_header is boolean for all entries', () => {
  for (const section of ['unreferenced_routines', 'single_site_routines', 'hotspots']) {
    for (const r of data[section]) {
      assert.strictEqual(typeof r.has_header, 'boolean',
        `has_header not boolean for "${r.name}" in ${section}`);
    }
  }
});

test('call_count + branch_count <= ref_count for hotspots', () => {
  for (const r of data.hotspots) {
    assert.ok(r.call_count + r.branch_count <= r.ref_count,
      `"${r.name}": call+branch > ref_count`);
  }
});

// ---------------------------------------------------------------------------
// Section E: known spot-checks
// ---------------------------------------------------------------------------

console.log('\n=== Section E: known spot-checks ===');

test('Wait_for_vblank is the top hotspot', () => {
  assert.ok(data.hotspots.length > 0, 'hotspots array empty');
  assert.strictEqual(data.hotspots[0].name, 'Wait_for_vblank');
});

test('Wait_for_vblank ref_count is 94', () => {
  const h = data.hotspots.find(x => x.name === 'Wait_for_vblank');
  assert.ok(h, 'Wait_for_vblank not in hotspots');
  assert.strictEqual(h.ref_count, 94);
});

test('Wait_for_vblank has_header is true', () => {
  const h = data.hotspots.find(x => x.name === 'Wait_for_vblank');
  assert.strictEqual(h.has_header, true);
});

test('Decompress_to_vdp is in hotspots', () => {
  const h = data.hotspots.find(x => x.name === 'Decompress_to_vdp');
  assert.ok(h, 'Decompress_to_vdp not in hotspots');
});

test('Decompress_to_vdp ref_count is 44', () => {
  const h = data.hotspots.find(x => x.name === 'Decompress_to_vdp');
  assert.strictEqual(h.ref_count, 44);
});

test('EntryPoint is in unreferenced_routines', () => {
  const u = data.unreferenced_routines.find(x => x.name === 'EntryPoint');
  assert.ok(u, 'EntryPoint not in unreferenced_routines');
});

test('Vertical_blank_interrupt is in unreferenced_routines', () => {
  const u = data.unreferenced_routines.find(x => x.name === 'Vertical_blank_interrupt');
  assert.ok(u, 'Vertical_blank_interrupt not in unreferenced_routines');
});

test('EntryPoint source_file is init.asm', () => {
  const u = data.unreferenced_routines.find(x => x.name === 'EntryPoint');
  assert.ok(u && u.source_file === 'init.asm', `source_file=${u && u.source_file}`);
});

test('unreferenced_routines count >= 10 (hardware entry points always present)', () => {
  assert.ok(data.unreferenced_routines.length >= 10,
    `only ${data.unreferenced_routines.length} unreferenced routines`);
});

test('single_site_routines count > 0', () => {
  assert.ok(data.single_site_routines.length > 0);
});

test('hotspots count >= 5 (known high-frequency routines exist)', () => {
  assert.ok(data.hotspots.length >= 5, `only ${data.hotspots.length} hotspots`);
});

test('total_routines is 376 (matches functions.json)', () => {
  assert.strictEqual(data._meta.total_routines, 376);
});

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
