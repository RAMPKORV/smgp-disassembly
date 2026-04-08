#!/usr/bin/env node
// tools/tests/test_coverage_report.js
//
// Tests for tools/index/coverage_report.js and its output
// tools/index/coverage_report.json.
//
// Section A: analyseFile() unit tests (synthetic content)
// Section B: pct() helper unit tests
// Section C: buildReport() logic unit tests (synthetic data)
// Section D: coverage_report.json structure invariants
// Section E: per-file entry field invariants
// Section F: known spot-checks against the real report

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const REPO_ROOT       = path.resolve(__dirname, '..', '..');
const COVERAGE_JS     = path.join(REPO_ROOT, 'tools', 'index', 'coverage_report.js');
const COVERAGE_JSON   = path.join(REPO_ROOT, 'tools', 'index', 'coverage_report.json');
const FUNCTIONS_JSON  = path.join(REPO_ROOT, 'tools', 'index', 'functions.json');

const { analyseFile, pct, buildReport } = require(COVERAGE_JS);

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

/** Write a temp file with given content, return its path. */
function tmpFile(content) {
  const p = path.join(os.tmpdir(), `test_cov_${Date.now()}_${Math.random().toString(36).slice(2)}.asm`);
  fs.writeFileSync(p, content, 'utf8');
  return p;
}

// ---------------------------------------------------------------------------
// Section A: analyseFile() unit tests
// ---------------------------------------------------------------------------

console.log('\n=== Section A: analyseFile() ===');

test('pure comment file: all comment_lines', () => {
  const f = tmpFile('; comment\n; another\n');
  const r = analyseFile(f);
  // split('\n') on '; comment\n; another\n' gives ['; comment', '; another', '']
  // so total=3, comment=2, blank=1 (the trailing empty line)
  assert.strictEqual(r.comment, 2);
  assert.strictEqual(r.blank, 1);
  assert.strictEqual(r.code, 0);
  assert.strictEqual(r.total, 3);
});

test('blank lines counted correctly', () => {
  const f = tmpFile('\n\n   \n');
  const r = analyseFile(f);
  // '\n\n   \n' splits to ['', '', '   ', ''] => 4 lines, all blank
  assert.strictEqual(r.blank, 4);
  assert.strictEqual(r.comment, 0);
  assert.strictEqual(r.code, 0);
});

test('code lines counted correctly', () => {
  const f = tmpFile('\tMOVE.w\tD0,D1\n\tRTS\n');
  const r = analyseFile(f);
  assert.strictEqual(r.code, 2);
  assert.strictEqual(r.comment, 0);
});

test('label lines count as code (no leading whitespace)', () => {
  const f = tmpFile('My_label:\n');
  const r = analyseFile(f);
  assert.strictEqual(r.code, 1);
});

test('total = comment + blank + code', () => {
  const content = '; header\n\nLabel:\n\tMOVE.w\tD0,D1\n; inline\n';
  const f = tmpFile(content);
  const r = analyseFile(f);
  assert.strictEqual(r.total, r.comment + r.blank + r.code);
});

test('inline comment after instruction counted as code (not comment-line)', () => {
  // A line like "  MOVE.w D0,D1  ; comment" starts with whitespace+instruction,
  // not ';', so it should be code.
  const f = tmpFile('\tMOVE.w\tD0,D1\t; this is code with inline comment\n');
  const r = analyseFile(f);
  assert.strictEqual(r.code, 1);
  assert.strictEqual(r.comment, 0);
});

test('indented comment line starting with ; after spaces is a comment', () => {
  // "  ; this is a comment" — trimStart starts with ';'
  const f = tmpFile('  ; an indented comment\n');
  const r = analyseFile(f);
  assert.strictEqual(r.comment, 1);
  assert.strictEqual(r.code, 0);
});

test('empty file returns all zeros', () => {
  const f = tmpFile('');
  const r = analyseFile(f);
  assert.strictEqual(r.total, 1); // split('') on '' gives ['']
  assert.strictEqual(r.comment + r.blank + r.code, r.total);
});

// ---------------------------------------------------------------------------
// Section B: pct() helper unit tests
// ---------------------------------------------------------------------------

console.log('\n=== Section B: pct() ===');

test('pct(0, 0) returns N/A', () => {
  assert.strictEqual(pct(0, 0), 'N/A');
});

test('pct(1, 2) returns 50.0%', () => {
  assert.strictEqual(pct(1, 2), '50.0%');
});

test('pct(10, 100) returns 10.0%', () => {
  assert.strictEqual(pct(10, 100), '10.0%');
});

test('pct(0, 10) returns 0.0%', () => {
  assert.strictEqual(pct(0, 10), '0.0%');
});

test('pct(10, 10) returns 100.0%', () => {
  assert.strictEqual(pct(10, 10), '100.0%');
});

test('pct returns string ending with %', () => {
  assert.ok(pct(3, 7).endsWith('%'));
});

// ---------------------------------------------------------------------------
// Section C: buildReport() logic unit tests (synthetic data)
// ---------------------------------------------------------------------------

console.log('\n=== Section C: buildReport() logic ===');

// Write a small synthetic ASM file to a temp dir
const TMPDIR = os.tmpdir();
const synFile = path.join(TMPDIR, 'syn_test.asm');
fs.writeFileSync(synFile, '; comment\n\tMOVE.w\tD0,D1\n\n', 'utf8');
const synRelPath = 'syn_test.asm';

const synFunctionsJson = {
  _meta: {},
  functions: [
    { name: 'Foo', kind: 'routine', source_file: synRelPath, has_header: true  },
    { name: 'Bar', kind: 'routine', source_file: synRelPath, has_header: false },
    { name: 'Baz', kind: 'data',    source_file: synRelPath, has_header: false },
  ],
};

const synReport = buildReport(synFunctionsJson, TMPDIR, [synRelPath]);

test('buildReport returns array with one entry for one file', () => {
  assert.strictEqual(synReport.length, 1);
});

test('buildReport entry has correct file name', () => {
  assert.strictEqual(synReport[0].file, synRelPath);
});

test('buildReport comment_lines=1', () => {
  assert.strictEqual(synReport[0].comment_lines, 1);
});

test('buildReport blank_lines >= 1', () => {
  // Content has at least one blank line (\n at end + explicit blank line)
  assert.ok(synReport[0].blank_lines >= 1,
    `blank_lines=${synReport[0].blank_lines}`);
});

test('buildReport code_lines=1', () => {
  assert.strictEqual(synReport[0].code_lines, 1);
});

test('buildReport total_lines = comment + blank + code', () => {
  const r = synReport[0];
  assert.strictEqual(r.total_lines, r.comment_lines + r.blank_lines + r.code_lines);
});

test('buildReport routines counts only routine-kind labels', () => {
  // Foo and Bar are routines, Baz is data
  assert.strictEqual(synReport[0].routines, 2);
});

test('buildReport routines_with_header=1', () => {
  assert.strictEqual(synReport[0].routines_with_header, 1);
});

test('buildReport header_coverage=50.0%', () => {
  assert.strictEqual(synReport[0].header_coverage, '50.0%');
});

test('buildReport skips missing files gracefully', () => {
  const r = buildReport(synFunctionsJson, TMPDIR, ['does_not_exist.asm', synRelPath]);
  assert.strictEqual(r.length, 1);
  assert.strictEqual(r[0].file, synRelPath);
});

test('buildReport with no routines in file has header_coverage N/A', () => {
  const noFns = { _meta: {}, functions: [] };
  const r = buildReport(noFns, TMPDIR, [synRelPath]);
  assert.strictEqual(r[0].header_coverage, 'N/A');
  assert.strictEqual(r[0].routines, 0);
  assert.strictEqual(r[0].routines_with_header, 0);
});

// ---------------------------------------------------------------------------
// Section D: coverage_report.json structure invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section D: coverage_report.json structure invariants ===');

let data;
test('coverage_report.json exists and is valid JSON', () => {
  assert.ok(fs.existsSync(COVERAGE_JSON), 'coverage_report.json not found');
  data = JSON.parse(fs.readFileSync(COVERAGE_JSON, 'utf8'));
});

test('coverage_report.json has _meta object', () => {
  assert.ok(data && typeof data._meta === 'object');
});

test('_meta.files_analysed > 0', () => {
  assert.ok(Number.isInteger(data._meta.files_analysed) && data._meta.files_analysed > 0);
});

test('_meta.total_lines > 0', () => {
  assert.ok(data._meta.total_lines > 0);
});

test('_meta.comment_density ends with %', () => {
  assert.ok(data._meta.comment_density.endsWith('%'));
});

test('_meta.header_coverage ends with %', () => {
  assert.ok(data._meta.header_coverage.endsWith('%'));
});

test('_meta.total_routines equals functions.json routine count', () => {
  const fns = JSON.parse(fs.readFileSync(FUNCTIONS_JSON, 'utf8'));
  const routineCount = fns.functions.filter(f => f.kind === 'routine').length;
  assert.strictEqual(data._meta.total_routines, routineCount);
});

test('_meta.headered_routines <= total_routines', () => {
  assert.ok(data._meta.headered_routines <= data._meta.total_routines);
});

test('coverage_report.json has files array', () => {
  assert.ok(Array.isArray(data.files));
});

test('files array length matches _meta.files_analysed', () => {
  assert.strictEqual(data.files.length, data._meta.files_analysed);
});

test('_meta total_lines equals sum of file total_lines', () => {
  const sum = data.files.reduce((acc, r) => acc + r.total_lines, 0);
  assert.strictEqual(data._meta.total_lines, sum);
});

test('_meta comment_lines equals sum of file comment_lines', () => {
  const sum = data.files.reduce((acc, r) => acc + r.comment_lines, 0);
  assert.strictEqual(data._meta.comment_lines, sum);
});

// ---------------------------------------------------------------------------
// Section E: per-file entry field invariants
// ---------------------------------------------------------------------------

console.log('\n=== Section E: per-file entry field invariants ===');

const REQUIRED_FIELDS = [
  'file', 'total_lines', 'code_lines', 'comment_lines', 'blank_lines',
  'comment_density', 'routines', 'routines_with_header', 'header_coverage',
];

test('all file entries have required fields', () => {
  for (const r of data.files) {
    for (const f of REQUIRED_FIELDS) {
      assert.ok(f in r, `file "${r.file}" missing field "${f}"`);
    }
  }
});

test('total_lines = code + comment + blank for every entry', () => {
  for (const r of data.files) {
    assert.strictEqual(
      r.total_lines,
      r.code_lines + r.comment_lines + r.blank_lines,
      `total_lines mismatch for ${r.file}`
    );
  }
});

test('comment_density ends with % or is N/A for every entry', () => {
  for (const r of data.files) {
    assert.ok(
      r.comment_density.endsWith('%') || r.comment_density === 'N/A',
      `bad comment_density "${r.comment_density}" for ${r.file}`
    );
  }
});

test('header_coverage ends with % or is N/A for every entry', () => {
  for (const r of data.files) {
    assert.ok(
      r.header_coverage.endsWith('%') || r.header_coverage === 'N/A',
      `bad header_coverage "${r.header_coverage}" for ${r.file}`
    );
  }
});

test('routines_with_header <= routines for every entry', () => {
  for (const r of data.files) {
    assert.ok(
      r.routines_with_header <= r.routines,
      `${r.file}: routines_with_header ${r.routines_with_header} > routines ${r.routines}`
    );
  }
});

test('total_lines > 0 for every entry', () => {
  for (const r of data.files) {
    assert.ok(r.total_lines > 0, `${r.file} has total_lines=0`);
  }
});

test('no internal _num fields leaked into JSON output', () => {
  for (const r of data.files) {
    assert.ok(!('comment_density_num' in r), `${r.file} leaked comment_density_num`);
    assert.ok(!('header_coverage_num' in r), `${r.file} leaked header_coverage_num`);
  }
});

// ---------------------------------------------------------------------------
// Section F: known spot-checks
// ---------------------------------------------------------------------------

console.log('\n=== Section F: known spot-checks ===');

test('src/core.asm is present in report', () => {
  const entry = data.files.find(r => r.file === 'src/core.asm');
  assert.ok(entry, 'src/core.asm not found');
});

test('src/core.asm comment_density > 10%', () => {
  const entry = data.files.find(r => r.file === 'src/core.asm');
  const d = parseFloat(entry.comment_density);
  assert.ok(d > 10, `src/core.asm comment_density=${entry.comment_density}`);
});

test('src/gameplay.asm is the largest file by total_lines', () => {
  const sorted = [...data.files].sort((a, b) => b.total_lines - a.total_lines);
  assert.strictEqual(sorted[0].file, 'src/gameplay.asm');
});

test('ram_addresses.asm has high comment_density > 30%', () => {
  const entry = data.files.find(r => r.file === 'ram_addresses.asm');
  assert.ok(entry, 'ram_addresses.asm not found');
  const d = parseFloat(entry.comment_density);
  assert.ok(d > 30, `ram_addresses.asm comment_density=${entry.comment_density}`);
});

test('src/core.asm has the most routines', () => {
  const sorted = [...data.files].sort((a, b) => b.routines - a.routines);
  assert.strictEqual(sorted[0].file, 'src/core.asm');
});

test('total files analysed is 42', () => {
  assert.strictEqual(data._meta.files_analysed, 42);
});

test('total routines in _meta is 376', () => {
  assert.strictEqual(data._meta.total_routines, 376);
});

test('headered routines in _meta is 363', () => {
  assert.strictEqual(data._meta.headered_routines, 363);
});

test('project-wide comment_density is between 4% and 10%', () => {
  const d = parseFloat(data._meta.comment_density);
  assert.ok(d >= 4 && d <= 10,
    `project comment_density ${data._meta.comment_density} outside expected range`);
});

test('src/rendering.asm routines > 0', () => {
  const entry = data.files.find(r => r.file === 'src/rendering.asm');
  assert.ok(entry && entry.routines > 0, 'src/rendering.asm has no routines recorded');
});

test('src/objects.asm routines > 0', () => {
  const entry = data.files.find(r => r.file === 'src/objects.asm');
  assert.ok(entry && entry.routines > 0, 'src/objects.asm has no routines recorded');
});

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
