#!/usr/bin/env node
// tools/index/functions.js
//
// Build tools/index/functions.json: a machine-readable index of every named
// symbol defined in smgp.lst, enriched with:
//
//   - rom_addr      : hex ROM address ("0xXXXXXX")
//   - size_estimate : bytes to the next symbol with a strictly higher address
//                     (0 when unknown / last entry in its region)
//   - source_file   : which .asm include contributed this label
//   - kind          : "routine" | "sublabel" | "data" | "constant" | "unknown"
//   - has_header    : true if the source line immediately after the label
//                     definition starts with a ';' comment (excluding ;loc_)
//
// Kind classification:
//   "constant"  – label appears only in the constants files (address 0x000000)
//   "data"      – label is in a data-only module (see DATA_MODULES below)
//   "sublabel"  – label name contains an underscore-separated suffix that
//                 matches a previously seen top-level label (e.g. Update_rpm
//                 is a top-level routine, Update_rpm_Crash_decel is its sublabel)
//   "routine"   – everything else in a code module that has a non-zero address
//
// Usage:
//   node tools/index/functions.js [--lst PATH] [--src PATH] [--out PATH]
//
// Inputs:  smgp.lst (assembler listing), src/*.asm source files
// Outputs: tools/index/functions.json

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT   = path.resolve(__dirname, '..', '..');
const DEFAULT_LST = path.join(REPO_ROOT, 'smgp.lst');
const DEFAULT_SRC = REPO_ROOT;            // resolve source files relative to repo root
const DEFAULT_OUT = path.join(REPO_ROOT, 'tools', 'index', 'functions.json');

// ---------------------------------------------------------------------------
// Data-only modules — labels here get kind="data" regardless of name
// ---------------------------------------------------------------------------

const DATA_MODULES = new Set([
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
  // header/init contain some data too, but classify by sub-type at label level
  'header.asm',
]);

// Constants files — labels at address 0 get kind="constant"
const CONSTANT_MODULES = new Set([
  'constants.asm',
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
  'macros.asm',
]);

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let lstPath = DEFAULT_LST;
let srcRoot = DEFAULT_SRC;
let outPath = DEFAULT_OUT;
let verbose = false;

for (let i = 0; i < argv.length; i++) {
  const arg = argv[i];
  if ((arg === '--lst' || arg === '-l') && argv[i + 1]) {
    lstPath = argv[++i];
  } else if ((arg === '--src') && argv[i + 1]) {
    srcRoot = argv[++i];
  } else if ((arg === '--out' || arg === '-o') && argv[i + 1]) {
    outPath = argv[++i];
  } else if (arg === '--verbose' || arg === '-v') {
    verbose = true;
  }
}

// ---------------------------------------------------------------------------
// Parse listing: extract (address, label, source_file, lst_line_index)
// ---------------------------------------------------------------------------

/**
 * Regex matching a label definition line in the listing file.
 * e.g. "0000020E                            EntryPoint:"
 */
const LABEL_RE     = /^([0-9A-F]{8})\s+([A-Za-z_][A-Za-z0-9_]*):\s*$/;

/**
 * Regex matching an include directive line in the listing file.
 * e.g. "00000518                            	include "src/core.asm""
 */
const INCLUDE_RE   = /^[0-9A-F]{8}\s+\t?include\s+["']([^"']+)["']/;

/**
 * @typedef {{ name: string, romAddr: number, sourceFile: string, lstLine: number }} RawLabel
 */

/**
 * Parse smgp.lst and return an array of RawLabel sorted by lstLine order.
 * @param {string} lstFile
 * @returns {RawLabel[]}
 */
function parseListing(lstFile) {
  const lines = fs.readFileSync(lstFile, { encoding: 'utf8', errors: 'replace' }).split('\n');
  const labels = [];
  let currentFile = '(unknown)';

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trimEnd();

    // Track current source file via include directives
    const inc = INCLUDE_RE.exec(line);
    if (inc) {
      currentFile = inc[1];
      continue;
    }

    // Label definition
    const lm = LABEL_RE.exec(line);
    if (lm) {
      labels.push({
        name:       lm[2],
        romAddr:    parseInt(lm[1], 16),
        sourceFile: currentFile,
        lstLine:    i,
      });
    }
  }

  return labels;
}

// ---------------------------------------------------------------------------
// Load source files and build a line-indexed map for header comment lookup
// ---------------------------------------------------------------------------

/**
 * @type {Map<string, string[]>}  filePath -> lines array
 */
const sourceCache = new Map();

/**
 * Get the lines of a source file, cached.
 * @param {string} relPath   - path relative to repo root, e.g. "src/core.asm"
 * @returns {string[] | null}
 */
function getSourceLines(relPath) {
  if (sourceCache.has(relPath)) return sourceCache.get(relPath);
  const fullPath = path.join(srcRoot, relPath);
  if (!fs.existsSync(fullPath)) {
    sourceCache.set(relPath, null);
    return null;
  }
  const lines = fs.readFileSync(fullPath, { encoding: 'utf8', errors: 'replace' }).split('\n');
  sourceCache.set(relPath, lines);
  return lines;
}

// ---------------------------------------------------------------------------
// For each label, find its line number within its source file
// We do this by scanning the source for "LabelName:" at column 0
// ---------------------------------------------------------------------------

/**
 * Build a map of label name -> line index (0-based) within the given file.
 * Scans all source files lazily and caches results.
 *
 * @type {Map<string, Map<string, number>>}  filePath -> { labelName -> lineIdx }
 */
const labelLineCache = new Map();

/**
 * Get the line index of a label definition within its source file.
 * @param {string} relPath
 * @param {string} labelName
 * @returns {number} 0-based line index, or -1 if not found
 */
function getLabelLineInSource(relPath, labelName) {
  if (!labelLineCache.has(relPath)) {
    const lines = getSourceLines(relPath);
    const map = new Map();
    if (lines) {
      const labelDefRe = /^([A-Za-z_][A-Za-z0-9_]*):\s*$/;
      for (let i = 0; i < lines.length; i++) {
        const m = labelDefRe.exec(lines[i].trimEnd());
        if (m) map.set(m[1], i);
      }
    }
    labelLineCache.set(relPath, map);
  }
  return labelLineCache.get(relPath).get(labelName) ?? -1;
}

// ---------------------------------------------------------------------------
// Determine whether a label has a header comment in its source file
//
// Two styles are accepted:
//
//   Post-label style (comment appears AFTER the label line):
//       Label:
//       ; Header comment text
//       ; more lines...
//       <code>
//
//   Pre-label style (comment appears BEFORE the label line):
//       ; Header comment text
//       ; more lines...
//       Label:
//       <code>
//
// A bare ";loc_XXXX" preservation comment is NOT treated as a header.
// ---------------------------------------------------------------------------

/**
 * @param {string} relPath
 * @param {string} labelName
 * @returns {boolean}
 */
function hasHeaderComment(relPath, labelName) {
  const lines = getSourceLines(relPath);
  if (!lines) return false;
  const lineIdx = getLabelLineInSource(relPath, labelName);
  if (lineIdx < 0) return false;

  // --- Post-label style: check up to 3 lines after the label definition ---
  // (some labels have a blank line or another sub-label before the header)
  for (let offset = 1; offset <= 3; offset++) {
    const nextLine = lines[lineIdx + offset];
    if (nextLine === undefined) break;
    const trimmed = nextLine.trimStart();
    if (trimmed === '') continue;      // skip blank lines
    if (trimmed.startsWith(';loc_')) break;  // preservation comment is not a header
    if (trimmed.startsWith(';')) return true;
    break;  // first non-blank, non-comment line ends the check
  }

  // --- Pre-label style: scan backward from the line immediately above the label ---
  // Walk up through blank lines and comment lines.  Stop at the first non-blank,
  // non-comment line (code/data).  If we collected at least one ';' line that is
  // not a bare ";loc_XXXX" preservation comment, consider it a header.
  const MAX_LOOKBACK = 20;
  let foundRealComment = false;
  for (let offset = 1; offset <= MAX_LOOKBACK; offset++) {
    const prevIdx = lineIdx - offset;
    if (prevIdx < 0) break;
    const trimmed = lines[prevIdx].trimStart();
    if (trimmed === '') continue;            // blank line — keep scanning
    if (!trimmed.startsWith(';')) break;     // hit code/data — stop
    // It's a comment line.  Check whether it's only a preservation marker.
    if (/^;loc_[0-9A-Fa-f]+\s*$/.test(trimmed)) continue; // skip ;loc_XXXX
    foundRealComment = true;
    // Keep scanning upward to consume the full comment block.
  }
  return foundRealComment;
}

// ---------------------------------------------------------------------------
// Classify label kind
// ---------------------------------------------------------------------------

/**
 * Check if labelName looks like a sublabel of any top-level name seen so far.
 *
 * Two detection strategies are applied:
 *
 * 1. Prefix match: labelName starts with "TopLevelName_" for some
 *    TopLevelName in seenTopLevel.  This handles the common case where the
 *    parent is e.g. "Update_rpm" and the sublabel is "Update_rpm_Crash_decel".
 *
 * 2. Shared-prefix match: labelName and some seenTopLevel entry share a
 *    common underscore-delimited prefix of at least 2 segments.  This handles
 *    sibling-style naming like "Decompress_asset_list_to_vdp" (parent) and
 *    "Decompress_asset_list_loop" (sublabel) which share the prefix
 *    "Decompress_asset_list_".
 *
 * @param {string} name
 * @param {Set<string>} seenTopLevel
 * @returns {boolean}
 */
function isSublabel(name, seenTopLevel) {
  // Strategy 1: exact prefix "TopLevelName_..."
  for (const top of seenTopLevel) {
    if (name.startsWith(top + '_')) return true;
  }

  // Strategy 2: shared underscore-prefix of depth >= 2
  // Build candidate prefixes of name (all lengths >= 2 segments)
  const nameParts = name.split('_');
  for (let len = 2; len < nameParts.length; len++) {
    const prefix = nameParts.slice(0, len).join('_') + '_';
    for (const top of seenTopLevel) {
      if (top.startsWith(prefix) || top === prefix.slice(0, -1)) return true;
    }
  }

  return false;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  if (!fs.existsSync(lstPath)) {
    console.error(`ERROR: listing file not found: ${lstPath}`);
    console.error('Run build.bat first to generate smgp.lst');
    process.exit(1);
  }

  if (verbose) console.log(`Parsing ${lstPath} ...`);
  const rawLabels = parseListing(lstPath);
  if (verbose) console.log(`  ${rawLabels.length} label definitions found`);

  // Build an address-sorted view for size estimates
  const byAddr = [...rawLabels].sort((a, b) => a.romAddr - b.romAddr || a.lstLine - b.lstLine);

  // Build a quick address->next-address map for size estimation
  // For each unique address, we want the next strictly-higher address
  const addrSet = [];
  for (const lbl of byAddr) {
    if (addrSet.length === 0 || addrSet[addrSet.length - 1] !== lbl.romAddr) {
      addrSet.push(lbl.romAddr);
    }
  }
  // addrSet is sorted; build a map addr -> nextAddr
  const nextAddrMap = new Map();
  for (let i = 0; i < addrSet.length - 1; i++) {
    nextAddrMap.set(addrSet[i], addrSet[i + 1]);
  }

  // Process labels in listing order, tracking top-level names per file
  // (Reset the top-level set when we change files so sublabel detection is file-scoped)
  const seenTopLevelGlobal = new Set();

  const entries = [];

  for (const lbl of rawLabels) {
    const { name, romAddr, sourceFile } = lbl;

    // Determine kind
    let kind;
    if (CONSTANT_MODULES.has(sourceFile) || romAddr === 0) {
      kind = 'constant';
    } else if (DATA_MODULES.has(sourceFile)) {
      kind = 'data';
    } else if (isSublabel(name, seenTopLevelGlobal)) {
      kind = 'sublabel';
    } else {
      kind = 'routine';
    }

    // Register as top-level if it's a routine (not a sublabel or data/constant)
    if (kind === 'routine') {
      seenTopLevelGlobal.add(name);
    }

    // Size estimate: bytes to next higher address
    const nextAddr = nextAddrMap.get(romAddr);
    const sizeEstimate = (nextAddr !== undefined) ? nextAddr - romAddr : 0;

    // Has header comment
    const headerComment = (kind === 'routine') ? hasHeaderComment(sourceFile, name) : false;

    entries.push({
      name,
      rom_addr:     '0x' + romAddr.toString(16).toUpperCase().padStart(6, '0'),
      size_estimate: sizeEstimate,
      source_file:  sourceFile,
      kind,
      has_header:   headerComment,
    });
  }

  // Compute summary statistics
  const routines  = entries.filter(e => e.kind === 'routine');
  const sublabels = entries.filter(e => e.kind === 'sublabel');
  const dataLabels= entries.filter(e => e.kind === 'data');
  const constants = entries.filter(e => e.kind === 'constant');
  const withHeader = routines.filter(e => e.has_header);

  if (verbose) {
    console.log(`  routines: ${routines.length}`);
    console.log(`  sublabels: ${sublabels.length}`);
    console.log(`  data labels: ${dataLabels.length}`);
    console.log(`  constants: ${constants.length}`);
    console.log(`  routines with header comment: ${withHeader.length} / ${routines.length}`);
  }

  const payload = {
    _meta: {
      source:       path.basename(lstPath),
      generated:    new Date().toISOString().slice(0, 10),
      total:        entries.length,
      routines:     routines.length,
      sublabels:    sublabels.length,
      data_labels:  dataLabels.length,
      constants:    constants.length,
      header_coverage: routines.length > 0
        ? `${withHeader.length}/${routines.length} (${Math.round(100 * withHeader.length / routines.length)}%)`
        : '0/0',
    },
    functions: entries,
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2) + '\n', 'utf8');

  console.log(`Wrote ${entries.length} symbols to ${outPath}`);
  console.log(
    `  ${routines.length} routines (${withHeader.length} with header), ` +
    `${sublabels.length} sublabels, ${dataLabels.length} data, ${constants.length} constants`
  );
}

if (require.main === module) {
  main();
}

module.exports = { parseListing, hasHeaderComment, isSublabel };
