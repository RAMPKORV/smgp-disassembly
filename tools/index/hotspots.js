#!/usr/bin/env node
// tools/index/hotspots.js
//
// Build tools/index/hotspots.json: a hotspot and dead-code analysis report
// derived from tools/index/callsites.json and tools/index/functions.json.
//
// Three sections are computed:
//
//   unreferenced_routines
//     Routine-kind labels with zero recorded call/branch references.
//     These are candidates for dead code, hardware entry points, or
//     labels only reached indirectly (e.g. via function-pointer tables).
//
//   single_site_routines
//     Routines referenced from exactly one site.  Candidates for inlining,
//     but also useful for understanding tightly-coupled helpers.
//
//   hotspots
//     Routines referenced from 10 or more distinct sites.  These are
//     high-impact targets for documentation since changes here affect many
//     callers.
//
// Each entry in unreferenced_routines and single_site_routines carries:
//   name, rom_addr, size_estimate, source_file, has_header
//
// Each entry in hotspots carries:
//   name, rom_addr, size_estimate, source_file, has_header,
//   ref_count, call_count, branch_count, top_callers (up to 5)
//
// Usage:
//   node tools/index/hotspots.js [--callsites PATH] [--functions PATH]
//                                 [--out PATH] [--threshold N] [-v]
//
// Outputs: tools/index/hotspots.json  (machine-readable)
//          Human-readable summary to stdout

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT           = path.resolve(__dirname, '..', '..');
const DEFAULT_CALLSITES   = path.join(REPO_ROOT, 'tools', 'index', 'callsites.json');
const DEFAULT_FUNCTIONS   = path.join(REPO_ROOT, 'tools', 'index', 'functions.json');
const DEFAULT_OUT         = path.join(REPO_ROOT, 'tools', 'index', 'hotspots.json');
const DEFAULT_THRESHOLD   = 10;   // min refs to be a "hotspot"

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let callsitesPath = DEFAULT_CALLSITES;
let functionsPath = DEFAULT_FUNCTIONS;
let outPath       = DEFAULT_OUT;
let threshold     = DEFAULT_THRESHOLD;
let verbose       = false;

for (let i = 0; i < argv.length; i++) {
  const arg = argv[i];
  if ((arg === '--callsites' || arg === '-c') && argv[i + 1]) {
    callsitesPath = argv[++i];
  } else if ((arg === '--functions' || arg === '-f') && argv[i + 1]) {
    functionsPath = argv[++i];
  } else if ((arg === '--out' || arg === '-o') && argv[i + 1]) {
    outPath = argv[++i];
  } else if ((arg === '--threshold' || arg === '-t') && argv[i + 1]) {
    threshold = parseInt(argv[++i], 10);
    if (isNaN(threshold) || threshold < 1) {
      console.error('--threshold must be a positive integer');
      process.exit(1);
    }
  } else if (arg === '--verbose' || arg === '-v') {
    verbose = true;
  }
}

// ---------------------------------------------------------------------------
// Load inputs
// ---------------------------------------------------------------------------

if (!fs.existsSync(callsitesPath)) {
  console.error(`callsites.json not found at: ${callsitesPath}`);
  console.error('Run: node tools/index/callsites.js');
  process.exit(1);
}
if (!fs.existsSync(functionsPath)) {
  console.error(`functions.json not found at: ${functionsPath}`);
  console.error('Run: node tools/index/functions.js');
  process.exit(1);
}

const callsitesData = JSON.parse(fs.readFileSync(callsitesPath, 'utf8'));
const functionsData = JSON.parse(fs.readFileSync(functionsPath, 'utf8'));

const refs      = callsitesData.refs;        // label -> array of site objects
const functions = functionsData.functions;   // array of function entry objects

// ---------------------------------------------------------------------------
// Build a map of routine entries from functions.json
// We only analyse "routine" kind entries — data labels and constants are
// not subject to the same call-site reasoning.
// ---------------------------------------------------------------------------

/** @type {Map<string, object>} name -> function entry */
const routineMap = new Map();

for (const fn of functions) {
  if (fn.kind === 'routine') {
    routineMap.set(fn.name, fn);
  }
}

// ---------------------------------------------------------------------------
// Count call+branch references per routine
// ---------------------------------------------------------------------------

/**
 * For each routine, count total refs and the breakdown by kind.
 * Also collect the set of distinct containing functions (callers).
 *
 * @param {string} labelName
 * @returns {{ total: number, calls: number, branches: number, callers: string[] }}
 */
function getRefStats(labelName) {
  const sites = refs[labelName];
  if (!sites || sites.length === 0) {
    return { total: 0, calls: 0, branches: 0, callers: [] };
  }

  let calls = 0;
  let branches = 0;
  const callerSet = new Set();

  for (const site of sites) {
    if (site.kind === 'call') calls++;
    else if (site.kind === 'branch') branches++;
    if (site.in_function) callerSet.add(site.in_function);
  }

  return {
    total: sites.length,
    calls,
    branches,
    callers: [...callerSet],
  };
}

// ---------------------------------------------------------------------------
// Categorise each routine
// ---------------------------------------------------------------------------

/** Routine entries with zero references */
const unreferenced = [];

/** Routine entries referenced from exactly one site */
const singleSite = [];

/** Routine entries referenced from >= threshold sites */
const hotspots = [];

for (const [name, fn] of routineMap) {
  const stats = getRefStats(name);

  const entry = {
    name,
    rom_addr:      fn.rom_addr,
    size_estimate: fn.size_estimate,
    source_file:   fn.source_file,
    has_header:    fn.has_header,
  };

  if (stats.total === 0) {
    unreferenced.push(entry);
  } else if (stats.total === 1) {
    // Attach site detail for single-site entries
    const site = refs[name][0];
    singleSite.push(Object.assign({}, entry, {
      ref_count:    1,
      call_count:   stats.calls,
      branch_count: stats.branches,
      sole_caller:  site.in_function || null,
      sole_site:    { file: site.file, line: site.line, kind: site.kind },
    }));
  }

  if (stats.total >= threshold) {
    // Compute top callers by frequency
    const callerFreq = {};
    for (const site of refs[name]) {
      const key = site.in_function || '(top-level)';
      callerFreq[key] = (callerFreq[key] || 0) + 1;
    }
    const topCallers = Object.entries(callerFreq)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([caller, count]) => ({ caller, count }));

    hotspots.push(Object.assign({}, entry, {
      ref_count:    stats.total,
      call_count:   stats.calls,
      branch_count: stats.branches,
      top_callers:  topCallers,
    }));
  }
}

// Sort outputs for stable, useful ordering
unreferenced.sort((a, b) => parseInt(a.rom_addr, 16) - parseInt(b.rom_addr, 16));
singleSite.sort((a, b) => parseInt(a.rom_addr, 16) - parseInt(b.rom_addr, 16));
hotspots.sort((a, b) => b.ref_count - a.ref_count);

// ---------------------------------------------------------------------------
// Build summary statistics
// ---------------------------------------------------------------------------

const totalRoutines   = routineMap.size;
const headeredRoutines = [...routineMap.values()].filter(fn => fn.has_header).length;

const output = {
  _meta: {
    source:               ['callsites.json', 'functions.json'],
    generated:            new Date().toISOString().slice(0, 10),
    total_routines:       totalRoutines,
    headered_routines:    headeredRoutines,
    header_coverage_pct:  totalRoutines > 0
      ? `${((headeredRoutines / totalRoutines) * 100).toFixed(1)}%`
      : '0%',
    unreferenced_count:   unreferenced.length,
    single_site_count:    singleSite.length,
    hotspot_threshold:    threshold,
    hotspot_count:        hotspots.length,
  },
  unreferenced_routines: unreferenced,
  single_site_routines:  singleSite,
  hotspots,
};

// ---------------------------------------------------------------------------
// Write JSON
// ---------------------------------------------------------------------------

fs.writeFileSync(outPath, JSON.stringify(output, null, 2) + '\n', 'utf8');

if (verbose) {
  console.log(`Wrote ${outPath}`);
}

// ---------------------------------------------------------------------------
// Human-readable summary
// ---------------------------------------------------------------------------

console.log('=== Super Monaco GP — Hotspot / Dead-Code Analysis ===\n');

console.log(`Routines analysed : ${totalRoutines}`);
console.log(`With header       : ${headeredRoutines} (${output._meta.header_coverage_pct})`);
console.log(`Unreferenced      : ${unreferenced.length}`);
console.log(`Single-site       : ${singleSite.length}`);
console.log(`Hotspots (>=${String(threshold).padStart(2, ' ')} refs) : ${hotspots.length}`);
console.log('');

// --- Hotspots table ---
if (hotspots.length > 0) {
  console.log(`--- Top hotspots (>= ${threshold} references) ---`);
  const colW = Math.max(...hotspots.map(h => h.name.length), 30);
  console.log(
    'Refs'.padStart(5) + '  ' +
    'Calls'.padStart(5) + '  ' +
    'Branches'.padStart(8) + '  ' +
    'Hdr'.padStart(3) + '  ' +
    'Routine'
  );
  console.log('-'.repeat(5 + 2 + 5 + 2 + 8 + 2 + 3 + 2 + colW));
  for (const h of hotspots) {
    console.log(
      String(h.ref_count).padStart(5) + '  ' +
      String(h.call_count).padStart(5) + '  ' +
      String(h.branch_count).padStart(8) + '  ' +
      (h.has_header ? ' Y ' : ' - ') + '  ' +
      h.name
    );
  }
  console.log('');
}

// --- Unreferenced routines ---
if (unreferenced.length > 0) {
  console.log(`--- Unreferenced routines (${unreferenced.length} total) ---`);
  console.log('(These may be hardware entry points, interrupt handlers, or dead code.)');
  for (const r of unreferenced) {
    const hdr = r.has_header ? '[H]' : '   ';
    console.log(`  ${hdr}  ${r.rom_addr}  ${r.name}  (${r.source_file})`);
  }
  console.log('');
}

// --- Module breakdown of unreferenced routines ---
if (unreferenced.length > 0) {
  const byFile = {};
  for (const r of unreferenced) {
    byFile[r.source_file] = (byFile[r.source_file] || 0) + 1;
  }
  const sorted = Object.entries(byFile).sort((a, b) => b[1] - a[1]);
  console.log('--- Unreferenced by module ---');
  for (const [file, count] of sorted) {
    console.log(`  ${String(count).padStart(3)}  ${file}`);
  }
  console.log('');
}

console.log(`Output: ${outPath}`);

// ---------------------------------------------------------------------------
// Exported helpers (used by tests)
// ---------------------------------------------------------------------------

module.exports = {
  getRefStats,
  buildHotspots: (callsitesJson, functionsJson, thresh = DEFAULT_THRESHOLD) => {
    const r   = callsitesJson.refs;
    const fns = functionsJson.functions;
    const rMap = new Map();
    for (const fn of fns) {
      if (fn.kind === 'routine') rMap.set(fn.name, fn);
    }
    const unref = [];
    const single = [];
    const hot = [];
    for (const [name, fn] of rMap) {
      const sites = r[name] || [];
      const entry = { name, rom_addr: fn.rom_addr, size_estimate: fn.size_estimate,
                      source_file: fn.source_file, has_header: fn.has_header };
      if (sites.length === 0) {
        unref.push(entry);
      } else if (sites.length === 1) {
        const site = sites[0];
        single.push(Object.assign({}, entry, {
          ref_count: 1,
          call_count: sites.filter(s => s.kind === 'call').length,
          branch_count: sites.filter(s => s.kind === 'branch').length,
          sole_caller: site.in_function || null,
          sole_site: { file: site.file, line: site.line, kind: site.kind },
        }));
      }
      if (sites.length >= thresh) {
        const freq = {};
        for (const site of sites) {
          const key = site.in_function || '(top-level)';
          freq[key] = (freq[key] || 0) + 1;
        }
        const topCallers = Object.entries(freq)
          .sort((a, b) => b[1] - a[1]).slice(0, 5)
          .map(([caller, count]) => ({ caller, count }));
        hot.push(Object.assign({}, entry, {
          ref_count: sites.length,
          call_count: sites.filter(s => s.kind === 'call').length,
          branch_count: sites.filter(s => s.kind === 'branch').length,
          top_callers: topCallers,
        }));
      }
    }
    unref.sort((a, b) => parseInt(a.rom_addr, 16) - parseInt(b.rom_addr, 16));
    single.sort((a, b) => parseInt(a.rom_addr, 16) - parseInt(b.rom_addr, 16));
    hot.sort((a, b) => b.ref_count - a.ref_count);
    return { unreferenced: unref, single_site: single, hotspots: hot };
  },
};
