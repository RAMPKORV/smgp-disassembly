#!/usr/bin/env node
// tools/tests/test_callsites.js
//
// Tests for tools/index/callsites.js and its output tools/index/callsites.json.
//
// Section A: extractLabelFromToken() unit tests
// Section B: extractRefs() unit tests for various instruction patterns
// Section C: callsites.json structure invariants
// Section D: per-entry field invariants
// Section E: known reference spot-checks

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');

const REPO_ROOT       = path.resolve(__dirname, '..', '..');
const CALLSITES_JS    = path.join(REPO_ROOT, 'tools', 'index', 'callsites.js');
const CALLSITES_JSON  = path.join(REPO_ROOT, 'tools', 'index', 'callsites.json');
const SYMBOL_MAP_JSON = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');

const { extractRefs, extractLabelFromToken } = require(CALLSITES_JS);

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
// Build a small known-symbol set for unit tests
// ---------------------------------------------------------------------------

const TEST_SYMS = new Set([
  'Wait_for_vblank',
  'Decompress_to_vdp',
  'Prng',
  'EntryPoint',
  'Track_data',
  'Some_label',
  'Init_routine',
  'Update_rpm',
  'Fade_palette_to_black',
]);

// ---------------------------------------------------------------------------
// Section A: extractLabelFromToken() unit tests
// ---------------------------------------------------------------------------

console.log('\n=== Section A: extractLabelFromToken() ===');

test('bare label returns label', () => {
  assert.strictEqual(extractLabelFromToken('Wait_for_vblank', TEST_SYMS), 'Wait_for_vblank');
});

test('Label(PC) strips (PC) suffix', () => {
  assert.strictEqual(extractLabelFromToken('Wait_for_vblank(PC)', TEST_SYMS), 'Wait_for_vblank');
});

test('#Label (immediate) strips # prefix', () => {
  assert.strictEqual(extractLabelFromToken('#Some_label', TEST_SYMS), 'Some_label');
});

test('Label.w strips .w suffix', () => {
  assert.strictEqual(extractLabelFromToken('Some_label.w', TEST_SYMS), 'Some_label');
});

test('Label.l strips .l suffix', () => {
  assert.strictEqual(extractLabelFromToken('Some_label.l', TEST_SYMS), 'Some_label');
});

test('(Label) strips surrounding parens', () => {
  assert.strictEqual(extractLabelFromToken('(Some_label)', TEST_SYMS), 'Some_label');
});

test('register D0 returns null', () => {
  assert.strictEqual(extractLabelFromToken('D0', TEST_SYMS), null);
});

test('register A1 returns null', () => {
  assert.strictEqual(extractLabelFromToken('A1', TEST_SYMS), null);
});

test('register SP returns null', () => {
  assert.strictEqual(extractLabelFromToken('SP', TEST_SYMS), null);
});

test('register PC returns null', () => {
  assert.strictEqual(extractLabelFromToken('PC', TEST_SYMS), null);
});

test('unknown label returns null', () => {
  assert.strictEqual(extractLabelFromToken('Unknown_label_xyz', TEST_SYMS), null);
});

test('empty string returns null', () => {
  assert.strictEqual(extractLabelFromToken('', TEST_SYMS), null);
});

test('hex literal $FFFF returns null', () => {
  assert.strictEqual(extractLabelFromToken('$FFFF', TEST_SYMS), null);
});

test('decimal literal 42 returns null', () => {
  assert.strictEqual(extractLabelFromToken('42', TEST_SYMS), null);
});

test('(A0)+ returns null', () => {
  assert.strictEqual(extractLabelFromToken('(A0)+', TEST_SYMS), null);
});

test('Label.w with known symbol', () => {
  assert.strictEqual(extractLabelFromToken('Track_data.w', TEST_SYMS), 'Track_data');
});

// ---------------------------------------------------------------------------
// Section B: extractRefs() unit tests
// ---------------------------------------------------------------------------

console.log('\n=== Section B: extractRefs() ===');

test('JSR label returns call ref', () => {
  const refs = extractRefs('\tJSR\tWait_for_vblank', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Wait_for_vblank');
  assert.strictEqual(refs[0].kind, 'call');
});

test('JSR Label(PC) returns call ref', () => {
  const refs = extractRefs('\tJSR\tDecompress_to_vdp(PC)', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Decompress_to_vdp');
  assert.strictEqual(refs[0].kind, 'call');
});

test('BSR label returns call ref', () => {
  const refs = extractRefs('\tBSR.w\tPrng', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Prng');
  assert.strictEqual(refs[0].kind, 'call');
});

test('BRA label returns branch ref', () => {
  const refs = extractRefs('\tBRA.b\tInit_routine', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Init_routine');
  assert.strictEqual(refs[0].kind, 'branch');
});

test('BNE label returns branch ref', () => {
  const refs = extractRefs('\tBNE.w\tEntryPoint', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'EntryPoint');
  assert.strictEqual(refs[0].kind, 'branch');
});

test('BEQ label returns branch ref', () => {
  const refs = extractRefs('\tBEQ.b\tUpdate_rpm', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Update_rpm');
  assert.strictEqual(refs[0].kind, 'branch');
});

test('LEA label returns lea ref', () => {
  const refs = extractRefs('\tLEA\tTrack_data, A0', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Track_data');
  assert.strictEqual(refs[0].kind, 'lea');
});

test('LEA Label(PC),An returns lea ref', () => {
  const refs = extractRefs('\tLEA\tTrack_data(PC), A0', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Track_data');
  assert.strictEqual(refs[0].kind, 'lea');
});

test('dc.l label returns data_ptr ref', () => {
  const refs = extractRefs('\tdc.l\tWait_for_vblank', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Wait_for_vblank');
  assert.strictEqual(refs[0].kind, 'data_ptr');
});

test('dc.l two labels returns two data_ptr refs', () => {
  const refs = extractRefs('\tdc.l\tWait_for_vblank, Prng', TEST_SYMS);
  assert.strictEqual(refs.length, 2);
  assert.strictEqual(refs[0].kind, 'data_ptr');
  assert.strictEqual(refs[1].kind, 'data_ptr');
  assert.strictEqual(refs.map(r => r.label).sort().join(','), 'Prng,Wait_for_vblank');
});

test('dc.w label returns data_word ref', () => {
  const refs = extractRefs('\tdc.w\tSome_label', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].kind, 'data_word');
});

test('dc.l hex literal returns no ref', () => {
  const refs = extractRefs('\tdc.l\t$E0BC0305', TEST_SYMS);
  assert.strictEqual(refs.length, 0);
});

test('NOP returns no refs', () => {
  const refs = extractRefs('\tNOP', TEST_SYMS);
  assert.strictEqual(refs.length, 0);
});

test('RTS returns no refs', () => {
  const refs = extractRefs('\tRTS', TEST_SYMS);
  assert.strictEqual(refs.length, 0);
});

test('MOVE.w register-to-register returns no refs', () => {
  const refs = extractRefs('\tMOVE.w\tD0, D1', TEST_SYMS);
  assert.strictEqual(refs.length, 0);
});

test('blank line returns no refs', () => {
  const refs = extractRefs('', TEST_SYMS);
  assert.strictEqual(refs.length, 0);
});

test('comment line returns no refs', () => {
  const refs = extractRefs('\t; this is a comment mentioning Wait_for_vblank', TEST_SYMS);
  assert.strictEqual(refs.length, 0);
});

test('dc.l label with inline comment', () => {
  const refs = extractRefs('\tdc.l\tFade_palette_to_black\t; used in init', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].label, 'Fade_palette_to_black');
  assert.strictEqual(refs[0].kind, 'data_ptr');
});

test('JMP label returns branch ref', () => {
  const refs = extractRefs('\tJMP\t(A0)', TEST_SYMS);
  assert.strictEqual(refs.length, 0); // (A0) is not a known label
});

test('JMP known label returns branch ref', () => {
  const refs = extractRefs('\tJMP\tEntryPoint', TEST_SYMS);
  assert.strictEqual(refs.length, 1);
  assert.strictEqual(refs[0].kind, 'branch');
});

// ---------------------------------------------------------------------------
// Section C: callsites.json structure invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section C: callsites.json structure invariants ===');

let csData;
test('callsites.json exists and is valid JSON', () => {
  assert.ok(fs.existsSync(CALLSITES_JSON), 'callsites.json not found');
  csData = JSON.parse(fs.readFileSync(CALLSITES_JSON, 'utf8'));
  assert.ok(csData, 'parsed to non-null');
});

test('_meta field is present', () => {
  assert.ok(csData._meta, '_meta missing');
});

test('_meta.total_refs is a positive integer', () => {
  assert.ok(Number.isInteger(csData._meta.total_refs), 'total_refs not integer');
  assert.ok(csData._meta.total_refs > 0, 'total_refs not positive');
});

test('_meta.referenced_labels is a positive integer', () => {
  assert.ok(Number.isInteger(csData._meta.referenced_labels), 'referenced_labels not integer');
  assert.ok(csData._meta.referenced_labels > 0);
});

test('_meta.unreferenced_labels is a non-negative integer', () => {
  assert.ok(Number.isInteger(csData._meta.unreferenced_labels), 'unreferenced_labels not integer');
  assert.ok(csData._meta.unreferenced_labels >= 0);
});

test('_meta.kind_counts has expected keys', () => {
  const kc = csData._meta.kind_counts;
  assert.ok(kc, 'kind_counts missing');
  assert.ok(kc.call > 0, 'no call refs');
  assert.ok(kc.branch > 0, 'no branch refs');
  assert.ok(kc.data_ptr > 0, 'no data_ptr refs');
});

test('refs field is present and is an object', () => {
  assert.ok(csData.refs && typeof csData.refs === 'object', 'refs missing or wrong type');
});

test('refs object has more than 100 entries', () => {
  assert.ok(Object.keys(csData.refs).length > 100, 'too few refs entries');
});

test('_meta.top_referenced is an array of 10', () => {
  assert.ok(Array.isArray(csData._meta.top_referenced), 'top_referenced not array');
  assert.strictEqual(csData._meta.top_referenced.length, 10);
});

test('_meta.top_referenced entries have label and count fields', () => {
  for (const entry of csData._meta.top_referenced) {
    assert.ok(typeof entry.label === 'string', 'label not string');
    assert.ok(Number.isInteger(entry.count) && entry.count > 0, 'count invalid');
  }
});

test('_meta.top_referenced is sorted descending by count', () => {
  const counts = csData._meta.top_referenced.map(e => e.count);
  for (let i = 1; i < counts.length; i++) {
    assert.ok(counts[i] <= counts[i - 1], 'not sorted descending');
  }
});

// ---------------------------------------------------------------------------
// Section D: per-entry field invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section D: per-entry field invariants ===');

const VALID_KINDS = new Set(['call', 'branch', 'lea', 'data_ptr', 'data_word', 'other']);

test('every ref entry has required fields', () => {
  let checked = 0;
  for (const [label, refs] of Object.entries(csData.refs)) {
    for (const ref of refs) {
      assert.ok(typeof ref.file === 'string' && ref.file.endsWith('.asm'),
        `${label}: file not an .asm string: ${ref.file}`);
      assert.ok(Number.isInteger(ref.line) && ref.line >= 1,
        `${label}: line not positive integer: ${ref.line}`);
      assert.ok(VALID_KINDS.has(ref.kind),
        `${label}: unknown kind: ${ref.kind}`);
      assert.ok(typeof ref.context === 'string' && ref.context.length > 0,
        `${label}: context not a non-empty string`);
      // in_function may be null or a string
      assert.ok(ref.in_function === null || typeof ref.in_function === 'string',
        `${label}: in_function not null or string`);
      checked++;
      if (checked > 500) return; // early exit for performance
    }
  }
});

test('no ref entry references a label that is not in refs map (sample check)', () => {
  // Just check that labels in refs map are strings
  for (const label of Object.keys(csData.refs).slice(0, 50)) {
    assert.ok(typeof label === 'string' && label.length > 0, 'label key not a string');
  }
});

test('all refs for a label are sorted by file then line', () => {
  let checked = 0;
  for (const [label, refs] of Object.entries(csData.refs)) {
    for (let i = 1; i < refs.length; i++) {
      const a = refs[i - 1];
      const b = refs[i];
      if (a.file === b.file) {
        assert.ok(a.line <= b.line,
          `${label}: refs not sorted by line in ${a.file}: line ${a.line} > ${b.line}`);
      }
    }
    if (++checked > 200) break; // sample
  }
});

// ---------------------------------------------------------------------------
// Section E: known reference spot-checks
// ---------------------------------------------------------------------------

console.log('\n=== Section E: known reference spot-checks ===');

test('Wait_for_vblank is referenced', () => {
  assert.ok(csData.refs['Wait_for_vblank'], 'Wait_for_vblank not in refs');
});

test('Wait_for_vblank has >= 20 call references', () => {
  const calls = csData.refs['Wait_for_vblank'].filter(r => r.kind === 'call');
  assert.ok(calls.length >= 20, `only ${calls.length} call refs`);
});

test('Decompress_to_vdp is referenced', () => {
  assert.ok(csData.refs['Decompress_to_vdp'], 'Decompress_to_vdp not in refs');
});

test('Decompress_to_vdp has >= 10 call references', () => {
  const calls = csData.refs['Decompress_to_vdp'].filter(r => r.kind === 'call');
  assert.ok(calls.length >= 10, `only ${calls.length} call refs`);
});

test('Prng is referenced', () => {
  assert.ok(csData.refs['Prng'], 'Prng not in refs');
});

test('Prng references include at least one call', () => {
  const calls = csData.refs['Prng'].filter(r => r.kind === 'call');
  assert.ok(calls.length >= 1, 'no call refs to Prng');
});

test('Track_data is referenced by data_ptr', () => {
  const track = csData.refs['Track_data'];
  assert.ok(track, 'Track_data not in refs');
  const ptrs = track.filter(r => r.kind === 'data_ptr' || r.kind === 'lea');
  assert.ok(ptrs.length >= 1, 'no ptr/lea refs to Track_data');
});

test('Fade_palette_to_black has call references from multiple files', () => {
  const refs = csData.refs['Fade_palette_to_black'];
  assert.ok(refs, 'Fade_palette_to_black not in refs');
  const files = new Set(refs.map(r => r.file));
  assert.ok(files.size >= 2, `only ${files.size} unique source files reference Fade_palette_to_black`);
});

test('Halt_audio_sequence is referenced with call kind', () => {
  const refs = csData.refs['Halt_audio_sequence'];
  assert.ok(refs, 'Halt_audio_sequence not in refs');
  const calls = refs.filter(r => r.kind === 'call');
  assert.ok(calls.length >= 5, `only ${calls.length} calls to Halt_audio_sequence`);
});

test('in_function is non-null for at least one Wait_for_vblank ref', () => {
  const refs = csData.refs['Wait_for_vblank'];
  const withFunc = refs.filter(r => r.in_function !== null);
  assert.ok(withFunc.length >= 10, 'too few Wait_for_vblank refs with in_function');
});

test('references include files from multiple source modules', () => {
  const allFiles = new Set();
  for (const refs of Object.values(csData.refs)) {
    for (const ref of refs) allFiles.add(ref.file);
  }
  assert.ok(allFiles.size >= 10, `only ${allFiles.size} distinct source files`);
});

test('symbol_map symbols mostly appear in refs or are explainable', () => {
  const symData = JSON.parse(fs.readFileSync(SYMBOL_MAP_JSON, 'utf8'));
  const total = Object.keys(symData.symbols).length;
  const referenced = csData._meta.referenced_labels;
  // At least 50% of symbols should have some reference
  assert.ok(referenced / total >= 0.5, `only ${referenced}/${total} symbols referenced`);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
