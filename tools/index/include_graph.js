#!/usr/bin/env node
// tools/index/include_graph.js
//
// Build tools/index/include_graph.json: the full include tree rooted at
// smgp.asm, showing file dependencies and include order.
//
// The JSON output has two top-level fields:
//
//   nodes
//     One entry per file that participates in the build.  Each entry has:
//       file        - relative path from repo root (forward slashes)
//       kind        - "hub" | "code" | "data" | "constants" | "support"
//       depth       - 0=root, 1=direct includes of root, 2=sub-includes, etc.
//       include_order - 0-based integer position in a depth-first traversal
//       included_by   - relative path of the file that includes this one
//                       (null for the root)
//       includes      - array of relative paths directly included by this file
//
//   edges
//     One entry per include directive encountered.  Each entry has:
//       from        - including file (relative path)
//       to          - included file (relative path)
//       line        - 1-based line number of the include directive in "from"
//
// Usage:
//   node tools/index/include_graph.js [--root PATH] [--out PATH] [-v]
//
// Outputs: tools/index/include_graph.json  (machine-readable)
//          Human-readable summary to stdout

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT   = path.resolve(__dirname, '..', '..');
const DEFAULT_ROOT = path.join(REPO_ROOT, 'smgp.asm');
const DEFAULT_OUT  = path.join(REPO_ROOT, 'tools', 'index', 'include_graph.json');

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let rootFile = DEFAULT_ROOT;
let outPath  = DEFAULT_OUT;
let verbose  = false;

for (let i = 0; i < argv.length; i++) {
  const arg = argv[i];
  if (arg === '--root' && argv[i + 1]) { rootFile = path.resolve(argv[++i]); }
  else if (arg === '--out'  && argv[i + 1]) { outPath  = path.resolve(argv[++i]); }
  else if (arg === '-v' || arg === '--verbose') { verbose = true; }
  else if (arg === '--help') {
    console.log('Usage: node include_graph.js [--root FILE] [--out FILE] [-v]');
    process.exit(0);
  }
}

// ---------------------------------------------------------------------------
// File classification
// ---------------------------------------------------------------------------

/**
 * Classify a file by its path/name.
 * @param {string} rel - relative path (forward slashes)
 * @returns {string}
 */
function classifyFile(rel) {
  if (rel === 'smgp.asm' || rel === 'constants.asm') return 'hub';
  if (rel === 'macros.asm') return 'support';
  if (
    rel === 'hw_constants.asm' ||
    rel === 'ram_addresses.asm' ||
    rel === 'sound_constants.asm' ||
    rel === 'game_constants.asm'
  ) return 'constants';
  if (rel === 'header.asm' || rel === 'init.asm') return 'code';
  // src/ files: code vs data heuristic
  const base = path.basename(rel, '.asm');
  const CODE_MODULES = new Set([
    'core', 'menus', 'race', 'driving', 'rendering', 'race_support',
    'ai', 'audio_effects', 'objects', 'endgame', 'gameplay',
  ]);
  if (CODE_MODULES.has(base)) return 'code';
  return 'data';
}

// ---------------------------------------------------------------------------
// Include extraction
// ---------------------------------------------------------------------------

// Matches:   include "path"   or   include 'path'  (with optional leading tabs/spaces)
const INCLUDE_RE = /^\s*include\s+["']([^"']+)["']/i;

/**
 * Return all include directives found in a file.
 *
 * SN 68k (asm68k) resolves include paths relative to the assembler's working
 * directory (the directory of the top-level file, i.e. the repo root), NOT
 * relative to the including file.  However many editors and linters expect
 * file-relative resolution, so we try both:
 *   1. Relative to the including file's directory.
 *   2. Relative to the repo root (REPO_ROOT).
 *
 * @param {string} absPath
 * @returns {{ line: number, target: string }[]}
 */
function extractIncludes(absPath) {
  const lines  = fs.readFileSync(absPath, 'utf8').split('\n');
  const result = [];
  const fileDir = path.dirname(absPath);
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(INCLUDE_RE);
    if (m) {
      const raw = m[1].replace(/\\/g, '/');
      // Try file-relative first; fall back to repo-root-relative
      let candidate = path.resolve(fileDir, raw);
      if (!fs.existsSync(candidate)) {
        candidate = path.resolve(REPO_ROOT, raw);
      }
      result.push({ line: i + 1, target: candidate });
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Graph traversal (depth-first, cycle-safe)
// ---------------------------------------------------------------------------

/**
 * @typedef {{ file: string, kind: string, depth: number, include_order: number,
 *             included_by: string|null, includes: string[] }} NodeEntry
 * @typedef {{ from: string, to: string, line: number }} EdgeEntry
 */

/** @type {Map<string, NodeEntry>} keyed by relative path */
const nodes = new Map();
/** @type {EdgeEntry[]} */
const edges = [];

let includeOrder = 0;

/**
 * Convert an absolute path to a repo-relative path with forward slashes.
 * @param {string} abs
 * @returns {string}
 */
function toRel(abs) {
  return path.relative(REPO_ROOT, abs).replace(/\\/g, '/');
}

/**
 * Recursively walk includes.
 * @param {string} absFile  - absolute path of the current file
 * @param {number} depth
 * @param {string|null} includedBy - relative path of parent, or null for root
 * @param {Set<string>} visiting   - cycle detection (abs paths)
 */
function walk(absFile, depth, includedBy, visiting) {
  const rel = toRel(absFile);

  if (!fs.existsSync(absFile)) {
    if (verbose) console.warn(`  [warn] file not found: ${rel}`);
    return;
  }

  if (visiting.has(absFile)) {
    if (verbose) console.warn(`  [warn] cycle detected at: ${rel}`);
    return;
  }

  if (nodes.has(rel)) {
    // Already visited; just record the extra edge if new parent
    return;
  }

  visiting.add(absFile);

  const childIncludes = extractIncludes(absFile);
  const childRels     = [];

  // Register node early so recursive calls can see it
  const node = {
    file:          rel,
    kind:          classifyFile(rel),
    depth,
    include_order: includeOrder++,
    included_by:   includedBy,
    includes:      [],  // filled below
  };
  nodes.set(rel, node);

  for (const { line, target } of childIncludes) {
    const childRel = toRel(target);
    childRels.push(childRel);
    edges.push({ from: rel, to: childRel, line });
    walk(target, depth + 1, rel, new Set(visiting));
  }

  node.includes = childRels;

  visiting.delete(absFile);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

if (verbose) console.log(`Scanning include tree from: ${toRel(rootFile)}`);

walk(rootFile, 0, null, new Set());

// ---------------------------------------------------------------------------
// Serialise
// ---------------------------------------------------------------------------

const nodesArr = Array.from(nodes.values());

const meta = {
  generated:     new Date().toISOString(),
  root:          toRel(rootFile),
  total_files:   nodesArr.length,
  total_edges:   edges.length,
  kind_counts:   {},
  max_depth:     Math.max(...nodesArr.map(n => n.depth)),
};

// Count by kind
for (const n of nodesArr) {
  meta.kind_counts[n.kind] = (meta.kind_counts[n.kind] || 0) + 1;
}

const output = { _meta: meta, nodes: nodesArr, edges };

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(output, null, 2));

// ---------------------------------------------------------------------------
// Human-readable summary
// ---------------------------------------------------------------------------

console.log(`\nInclude graph: ${nodesArr.length} files, ${edges.length} edges`);
console.log(`Max depth: ${meta.max_depth}`);
console.log('');

// Print kind breakdown
const kindOrder = ['hub', 'code', 'data', 'constants', 'support'];
for (const k of kindOrder) {
  if (meta.kind_counts[k]) {
    console.log(`  ${k.padEnd(12)}: ${meta.kind_counts[k]}`);
  }
}

console.log('');
console.log('Include tree (depth-first order):');
for (const n of nodesArr) {
  const indent = '  '.repeat(n.depth);
  const childCount = n.includes.length ? ` (${n.includes.length} includes)` : '';
  console.log(`  ${indent}${n.file}${childCount}  [${n.kind}]`);
}

console.log('');
console.log(`Wrote ${nodesArr.length} nodes to ${path.relative(REPO_ROOT, outPath)}`);
