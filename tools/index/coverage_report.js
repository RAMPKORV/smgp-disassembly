#!/usr/bin/env node
// tools/index/coverage_report.js
//
// Build tools/index/coverage_report.json: a per-file comment-density and
// function-header coverage report for the Super Monaco GP disassembly source.
//
// Metrics computed per source file:
//
//   total_lines        : total line count
//   code_lines         : non-blank, non-comment lines (instructions / data / labels)
//   comment_lines      : lines where the first non-whitespace character is ';'
//   blank_lines        : completely empty or whitespace-only lines
//   comment_density    : comment_lines / total_lines (as a percentage)
//   routines           : number of "routine"-kind labels in this file (from functions.json)
//   routines_with_header : routines that have has_header=true
//   header_coverage    : routines_with_header / routines (as a percentage, or "N/A")
//
// Files analysed: all .asm files that are part of the build (same set as callsites.js).
//
// Usage:
//   node tools/index/coverage_report.js [--functions PATH] [--out PATH] [-v]
//
// Outputs: tools/index/coverage_report.json  (machine-readable)
//          Human-readable table to stdout

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT         = path.resolve(__dirname, '..', '..');
const DEFAULT_FUNCTIONS = path.join(REPO_ROOT, 'tools', 'index', 'functions.json');
const DEFAULT_OUT       = path.join(REPO_ROOT, 'tools', 'index', 'coverage_report.json');

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let functionsPath = DEFAULT_FUNCTIONS;
let outPath       = DEFAULT_OUT;
let verbose       = false;

for (let i = 0; i < argv.length; i++) {
  const arg = argv[i];
  if ((arg === '--functions' || arg === '-f') && argv[i + 1]) {
    functionsPath = argv[++i];
  } else if ((arg === '--out' || arg === '-o') && argv[i + 1]) {
    outPath = argv[++i];
  } else if (arg === '--verbose' || arg === '-v') {
    verbose = true;
  }
}

// ---------------------------------------------------------------------------
// Source file list — same ordering as callsites.js
// ---------------------------------------------------------------------------

const TOP_LEVEL_FILES = [
  'macros.asm',
  'header.asm',
  'init.asm',
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
  'constants.asm',
];

const SRC_FILES = [
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
  'src/endgame_game_over_data.asm',
  'src/endgame_result_data.asm',
  'src/endgame_credits_data.asm',
  'src/endgame_data.asm',
  'src/track_config_data.asm',
  'src/sprite_frame_data.asm',
  'src/result_screen_lists.asm',
  'src/result_sprite_anim_data.asm',
  'src/result_screen_assets.asm',
  'src/result_screen_tiles_b.asm',
  'src/driver_standings_data.asm',
  'src/car_spec_text_data.asm',
  'src/car_select_metadata.asm',
  'src/driver_portrait_tilemaps.asm',
  'src/driver_portrait_tiles.asm',
  'src/team_messages_data.asm',
  'src/crash_gauge_data.asm',
  'src/car_sprite_blobs.asm',
  'src/hud_and_minimap_data.asm',
  'src/screen_art_data.asm',
  'src/track_bg_data.asm',
  'src/road_and_track_data.asm',
  'src/audio_engine.asm',
];

const ALL_FILES = [...TOP_LEVEL_FILES, ...SRC_FILES];

// ---------------------------------------------------------------------------
// Load functions.json
// ---------------------------------------------------------------------------

if (!fs.existsSync(functionsPath)) {
  console.error(`functions.json not found at: ${functionsPath}`);
  console.error('Run: node tools/index/functions.js');
  process.exit(1);
}

const functionsData = JSON.parse(fs.readFileSync(functionsPath, 'utf8'));

// Build per-file routine stats from functions.json
// key: source_file value (relative to repo root, as stored in functions.json)
/** @type {Map<string, { total: number, headered: number }>} */
const routineStats = new Map();
for (const fn of functionsData.functions) {
  if (fn.kind !== 'routine') continue;
  const f = fn.source_file;
  if (!routineStats.has(f)) routineStats.set(f, { total: 0, headered: 0 });
  const s = routineStats.get(f);
  s.total++;
  if (fn.has_header) s.headered++;
}

// ---------------------------------------------------------------------------
// Analyse each source file
// ---------------------------------------------------------------------------

/**
 * Count comment/blank/code lines in an ASM file.
 * @param {string} filePath  absolute path
 * @returns {{ total: number, comment: number, blank: number, code: number }}
 */
function analyseFile(filePath) {
  const text  = fs.readFileSync(filePath, { encoding: 'utf8', errors: 'replace' });
  const lines = text.split('\n');
  let comment = 0;
  let blank   = 0;
  let code    = 0;

  for (const line of lines) {
    const trimmed = line.trimStart();
    if (trimmed === '') {
      blank++;
    } else if (trimmed.startsWith(';')) {
      comment++;
    } else {
      code++;
    }
  }

  return { total: lines.length, comment, blank, code };
}

/**
 * Format a ratio as a percentage string "XX.X%", or "N/A" when denom=0.
 */
function pct(num, denom) {
  if (denom === 0) return 'N/A';
  return ((num / denom) * 100).toFixed(1) + '%';
}

const fileReports = [];

for (const relPath of ALL_FILES) {
  const absPath = path.join(REPO_ROOT, relPath);
  if (!fs.existsSync(absPath)) {
    if (verbose) console.warn(`  SKIP (not found): ${relPath}`);
    continue;
  }

  const { total, comment, blank, code } = analyseFile(absPath);
  const rs = routineStats.get(relPath) || { total: 0, headered: 0 };

  fileReports.push({
    file:                   relPath,
    total_lines:            total,
    code_lines:             code,
    comment_lines:          comment,
    blank_lines:            blank,
    comment_density:        pct(comment, total),
    comment_density_num:    total > 0 ? (comment / total) * 100 : 0,
    routines:               rs.total,
    routines_with_header:   rs.headered,
    header_coverage:        pct(rs.headered, rs.total),
    header_coverage_num:    rs.total > 0 ? (rs.headered / rs.total) * 100 : null,
  });
}

// ---------------------------------------------------------------------------
// Project-wide totals
// ---------------------------------------------------------------------------

const totals = fileReports.reduce(
  (acc, r) => ({
    total_lines:          acc.total_lines          + r.total_lines,
    code_lines:           acc.code_lines           + r.code_lines,
    comment_lines:        acc.comment_lines        + r.comment_lines,
    blank_lines:          acc.blank_lines          + r.blank_lines,
    routines:             acc.routines             + r.routines,
    routines_with_header: acc.routines_with_header + r.routines_with_header,
  }),
  { total_lines: 0, code_lines: 0, comment_lines: 0, blank_lines: 0,
    routines: 0, routines_with_header: 0 }
);

const summary = {
  files_analysed:       fileReports.length,
  total_lines:          totals.total_lines,
  code_lines:           totals.code_lines,
  comment_lines:        totals.comment_lines,
  blank_lines:          totals.blank_lines,
  comment_density:      pct(totals.comment_lines, totals.total_lines),
  total_routines:       totals.routines,
  headered_routines:    totals.routines_with_header,
  header_coverage:      pct(totals.routines_with_header, totals.routines),
};

// Strip the internal _num fields from JSON output (only used for sorting/display)
const outputReports = fileReports.map(r => {
  const out = Object.assign({}, r);
  delete out.comment_density_num;
  delete out.header_coverage_num;
  return out;
});

const output = {
  _meta: {
    source:    'smgp source files + functions.json',
    generated: new Date().toISOString().slice(0, 10),
    ...summary,
  },
  files: outputReports,
};

// ---------------------------------------------------------------------------
// Write JSON
// ---------------------------------------------------------------------------

fs.writeFileSync(outPath, JSON.stringify(output, null, 2) + '\n', 'utf8');
if (verbose) console.log(`Wrote ${outPath}`);

// ---------------------------------------------------------------------------
// Human-readable table
// ---------------------------------------------------------------------------

console.log('=== Super Monaco GP — Comment Density & Header Coverage ===\n');

// Column widths
const FILE_W = Math.max(...fileReports.map(r => r.file.length), 20);
const HDR = [
  'File'.padEnd(FILE_W),
  'Lines'.padStart(6),
  'Cmts'.padStart(5),
  'Density'.padStart(8),
  'Rout'.padStart(5),
  'Hdr'.padStart(4),
  'HdrCov'.padStart(7),
].join('  ');

console.log(HDR);
console.log('-'.repeat(HDR.length));

// Sort by comment density ascending (lowest first — most work needed)
const sorted = [...fileReports].sort((a, b) => a.comment_density_num - b.comment_density_num);

for (const r of sorted) {
  const line = [
    r.file.padEnd(FILE_W),
    String(r.total_lines).padStart(6),
    String(r.comment_lines).padStart(5),
    r.comment_density.padStart(8),
    String(r.routines).padStart(5),
    String(r.routines_with_header).padStart(4),
    r.header_coverage.padStart(7),
  ].join('  ');
  console.log(line);
}

console.log('-'.repeat(HDR.length));
const totLine = [
  'TOTAL'.padEnd(FILE_W),
  String(summary.total_lines).padStart(6),
  String(summary.comment_lines).padStart(5),
  summary.comment_density.padStart(8),
  String(summary.total_routines).padStart(5),
  String(summary.headered_routines).padStart(4),
  summary.header_coverage.padStart(7),
].join('  ');
console.log(totLine);

console.log('');
console.log(`Files analysed: ${summary.files_analysed}`);
console.log(`Output: ${outPath}`);

// ---------------------------------------------------------------------------
// Exported helpers (used by tests)
// ---------------------------------------------------------------------------

module.exports = {
  analyseFile,
  pct,
  buildReport: (functionsJson, srcRoot, fileList) => {
    const rStats = new Map();
    for (const fn of functionsJson.functions) {
      if (fn.kind !== 'routine') continue;
      if (!rStats.has(fn.source_file)) rStats.set(fn.source_file, { total: 0, headered: 0 });
      const s = rStats.get(fn.source_file);
      s.total++;
      if (fn.has_header) s.headered++;
    }
    const reports = [];
    for (const relPath of fileList) {
      const absPath = path.join(srcRoot, relPath);
      if (!fs.existsSync(absPath)) continue;
      const { total, comment, blank, code } = analyseFile(absPath);
      const rs = rStats.get(relPath) || { total: 0, headered: 0 };
      reports.push({
        file: relPath,
        total_lines: total,
        code_lines: code,
        comment_lines: comment,
        blank_lines: blank,
        comment_density: pct(comment, total),
        comment_density_num: total > 0 ? (comment / total) * 100 : 0,
        routines: rs.total,
        routines_with_header: rs.headered,
        header_coverage: pct(rs.headered, rs.total),
        header_coverage_num: rs.total > 0 ? (rs.headered / rs.total) * 100 : null,
      });
    }
    return reports;
  },
};
