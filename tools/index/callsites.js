#!/usr/bin/env node
// tools/index/callsites.js
//
// Build tools/index/callsites.json: a cross-reference index mapping every
// named label to all of the sites where it is referenced in the source.
//
// A "reference site" is any source line in a .asm file where a known label
// name appears as an instruction operand or data value — concretely:
//
//   JSR / BSR            — direct call to a subroutine label
//   BRA / Bcc            — branch to a label (BNE, BEQ, BCS, BCC, etc.)
//   LEA / MOVEA.l        — address load of a label
//   MOVE.l               — long move where operand is a label address
//   dc.l                 — long data pointer to a label
//   dc.w                 — word reference (e.g. offset tables)
//
// For each reference, the output records:
//   file       : source file path relative to repo root (e.g. "src/core.asm")
//   line       : 1-based line number in that file
//   kind       : "call" | "branch" | "lea" | "data_ptr" | "data_word" | "other"
//   context    : the trimmed source line text
//   in_function: name of the containing top-level routine label, or null
//
// Output JSON:
//   {
//     "_meta": { ... summary ... },
//     "refs": {
//       "LabelName": [ { file, line, kind, context, in_function }, ... ],
//       ...
//     }
//   }
//
// Usage:
//   node tools/index/callsites.js [--src PATH] [--symbols PATH] [--out PATH] [-v]

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT      = path.resolve(__dirname, '..', '..');
const DEFAULT_SYMS   = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');
const DEFAULT_OUT    = path.join(REPO_ROOT, 'tools', 'index', 'callsites.json');

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let symPath  = DEFAULT_SYMS;
let outPath  = DEFAULT_OUT;
let verbose  = false;

for (let i = 0; i < argv.length; i++) {
  const arg = argv[i];
  if ((arg === '--symbols' || arg === '-s') && argv[i + 1]) {
    symPath = argv[++i];
  } else if ((arg === '--out' || arg === '-o') && argv[i + 1]) {
    outPath = argv[++i];
  } else if (arg === '--verbose' || arg === '-v') {
    verbose = true;
  }
}

// ---------------------------------------------------------------------------
// Source files to scan — all .asm files that are part of the build
// ---------------------------------------------------------------------------

/** Top-level and constants files (not under src/) */
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

/**
 * Collect all .asm source files to scan.
 * @returns {string[]} relative paths from repo root
 */
function collectSourceFiles() {
  const files = [...TOP_LEVEL_FILES];

  // All files under src/
  const srcDir = path.join(REPO_ROOT, 'src');
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      if (f.endsWith('.asm')) {
        files.push('src/' + f);
      }
    }
  }

  // Keep only files that actually exist
  return files.filter(f => fs.existsSync(path.join(REPO_ROOT, f)));
}

// ---------------------------------------------------------------------------
// Instruction kind classification
// ---------------------------------------------------------------------------

/**
 * Classify the reference kind from the instruction mnemonic.
 * @param {string} mnemonic  — uppercased mnemonic string (e.g. "JSR", "BNE.W", "LEA")
 * @returns {'call'|'branch'|'lea'|'data_ptr'|'data_word'|'other'}
 */
function classifyKind(mnemonic) {
  const base = mnemonic.split('.')[0].toUpperCase();
  if (base === 'JSR' || base === 'BSR')          return 'call';
  if (base === 'BRA' || base === 'JMP')          return 'branch';
  if (base.startsWith('B') && base.length >= 2)  return 'branch';  // Bcc variants
  if (base === 'LEA')                            return 'lea';
  if (base === 'DCL' || base === 'DC')           return 'data_ptr'; // dc.l
  if (base === 'DCW')                            return 'data_word'; // dc.w
  return 'other';
}

// ---------------------------------------------------------------------------
// Label reference extraction
// ---------------------------------------------------------------------------

/**
 * Regex matching a label definition at column 0 in a source file.
 * Matches:  "LabelName:"  or  "LabelName:\t; comment"
 * Does NOT match instructions (which are indented).
 */
const LABEL_DEF_RE = /^([A-Za-z_][A-Za-z0-9_]*):/;

/**
 * Regex matching a data directive keyword at the start of an operand field.
 * We use this to classify dc.l vs dc.w.
 */
const DATA_DIRECTIVE_RE = /^\s+(dc\.[lLwWbB])\s+/;

/**
 * Regex matching an instruction mnemonic (first word after leading whitespace,
 * possibly with a size suffix like .w, .b, .l).
 *
 * Handles both:
 *   "\tJSR\tLabel"
 *   "  BNE.w  Label"
 *   "\tdc.l\tLabel"
 */
const INSTR_RE = /^\s+([A-Za-z][A-Za-z0-9]*(?:\.[bBwWlLsS])?)\s+(.*)/;

/**
 * A set of bare register names and other non-label operand tokens to skip.
 * We don't want to false-positive on D0, A1, SP, SR, CCR, PC, etc.
 */
const REGISTER_NAMES = new Set([
  'D0','D1','D2','D3','D4','D5','D6','D7',
  'A0','A1','A2','A3','A4','A5','A6','A7',
  'SP','USP','SSP','SR','CCR','PC',
  'VBR','CACR','CAAR',
]);

/**
 * Instructions whose operands are never label references.
 */
const NO_LABEL_INSTRS = new Set([
  'MOVE','MOVEM','MOVEQ','MOVEP','MOVEA',
  'ADD','ADDA','ADDI','ADDQ','ADDX',
  'SUB','SUBA','SUBI','SUBQ','SUBX',
  'AND','ANDI','OR','ORI','EOR','EORI',
  'CMP','CMPA','CMPI','CMPM',
  'NEG','NEGX','NOT','CLR',
  'MULS','MULU','DIVS','DIVU',
  'ASL','ASR','LSL','LSR','ROL','ROR','ROXL','ROXR',
  'BTST','BSET','BCLR','BCHG',
  'EXT','EXTB','SWAP','ABCD','SBCD','NBCD',
  'CHK','TAS','TST',
  'PUSH','POP',
  'STOP','NOP','RTS','RTE','RTR','RTD',
  'RESET','ILLEGAL','TRAPV','TRAP',
  'LINK','UNLK',
  'DBF','DBRA','DBT','DBCC',
  'Scc','SCC','SCS','SEQ','SF','SGE','SGT','SHI','SLE','SLS','SLT','SMI','SNE','SPL','ST','SVC','SVS',
]);

/**
 * Instructions whose operands CAN contain label references.
 */
const LABEL_REF_INSTRS = new Set([
  // Calls
  'JSR','BSR',
  // Branches
  'BRA','JMP',
  'BCC','BCS','BEQ','BGE','BGT','BHI','BLE','BLS','BLT','BMI','BNE','BPL','BVC','BVS',
  // Address loads
  'LEA','PEA',
  // Long address moves (source operand may be a label address)
  // We handle MOVEA.l and MOVE.l specially by checking .l size
  'MOVEA',
  // Data directives
  'DCL','DCW','DCB',
]);

/**
 * Extract all label names referenced in a single source line.
 * Returns an array of { label, kind } objects.
 *
 * @param {string} line           - raw source line (not trimmed)
 * @param {Set<string>} knownSyms - set of all valid label names
 * @returns {{ label: string, kind: string }[]}
 */
function extractRefs(line, knownSyms) {
  const refs = [];

  // Data directives: dc.l, dc.w  (these can have comma-separated label lists)
  const dataMatch = DATA_DIRECTIVE_RE.exec(line);
  if (dataMatch) {
    const directive = dataMatch[1].toLowerCase();
    const kind = directive === 'dc.l' ? 'data_ptr'
               : directive === 'dc.w' ? 'data_word'
               : 'other';
    // Everything after the directive keyword up to first semicolon
    const rest = line.slice(line.indexOf(dataMatch[1]) + dataMatch[1].length).replace(/;.*$/, '').trim();
    for (const token of rest.split(',')) {
      const label = extractLabelFromToken(token.trim(), knownSyms);
      if (label) refs.push({ label, kind });
    }
    return refs;
  }

  // Instruction lines
  const instrMatch = INSTR_RE.exec(line);
  if (!instrMatch) return refs;

  const mnemonic = instrMatch[1];
  const mnemonicUpper = mnemonic.toUpperCase();
  const mnemonicBase  = mnemonicUpper.split('.')[0];
  const operands      = instrMatch[2].replace(/;.*$/, '').trim(); // strip inline comment

  // Skip instructions that never reference labels
  if (NO_LABEL_INSTRS.has(mnemonicBase)) return refs;

  // For MOVEA.l (address loads), classify as lea-like
  if (mnemonicBase === 'MOVEA') {
    const sizePart = mnemonic.includes('.') ? mnemonic.split('.')[1].toLowerCase() : '';
    if (sizePart !== 'l') return refs;
    // MOVEA.l  Source, Ax  — source may be a label
    const src = operands.split(',')[0].trim();
    const label = extractLabelFromToken(src, knownSyms);
    if (label) refs.push({ label, kind: 'lea' });
    return refs;
  }

  // For MOVE.l  Label, dest — detect label address loads
  if (mnemonicBase === 'MOVE') {
    const sizePart = mnemonic.includes('.') ? mnemonic.split('.')[1].toLowerCase() : '';
    if (sizePart !== 'l') return refs;
    const parts = splitOperands(operands);
    for (const part of parts) {
      const label = extractLabelFromToken(part, knownSyms);
      if (label) refs.push({ label, kind: 'lea' });
    }
    return refs;
  }

  // Branches and calls
  const kind = classifyKind(mnemonic);

  // For branches/calls/lea the target is typically the whole operand (or first operand)
  // Some may be: JSR Label(PC)  or  LEA Label(PC),A0
  const firstOperand = splitOperands(operands)[0] || '';
  const label = extractLabelFromToken(firstOperand, knownSyms);
  if (label) {
    refs.push({ label, kind });
    return refs;
  }

  return refs;
}

/**
 * Split an operand string on commas, but respecting parentheses.
 * e.g. "Label(PC), A0" -> ["Label(PC)", "A0"]
 * @param {string} s
 * @returns {string[]}
 */
function splitOperands(s) {
  const parts = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < s.length; i++) {
    if (s[i] === '(') depth++;
    else if (s[i] === ')') depth--;
    else if (s[i] === ',' && depth === 0) {
      parts.push(s.slice(start, i).trim());
      start = i + 1;
    }
  }
  parts.push(s.slice(start).trim());
  return parts;
}

/**
 * Try to extract a known label name from an operand token.
 * Handles forms like:
 *   Label
 *   Label(PC)
 *   Label.w
 *   #Label          (immediate address)
 *   (Label)
 *
 * Returns the label name string if found in knownSyms, else null.
 *
 * @param {string} token
 * @param {Set<string>} knownSyms
 * @returns {string|null}
 */
function extractLabelFromToken(token, knownSyms) {
  if (!token) return null;

  // Strip leading # (immediate)
  let t = token.replace(/^#/, '');

  // Strip (PC) or (An) suffix: Label(PC) -> Label, Label(A0) -> Label
  // Must be done before general paren stripping
  t = t.replace(/\([A-Za-z][A-Za-z0-9]*\)$/, '');

  // Strip size suffix .w .l .b
  t = t.replace(/\.(w|l|b|W|L|B)$/, '');

  // Strip surrounding parens for (Label) form
  // Only strip if the token is entirely wrapped: (Label) -> Label
  if (t.startsWith('(') && t.endsWith(')')) {
    t = t.slice(1, -1);
  }

  // Must look like an identifier
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(t)) return null;

  // Skip register names
  if (REGISTER_NAMES.has(t.toUpperCase())) return null;

  // Must be a known symbol
  if (knownSyms.has(t)) return t;

  return null;
}

// ---------------------------------------------------------------------------
// Top-level function tracker
// ---------------------------------------------------------------------------

/**
 * Given a label definition at column 0, decide if it counts as a
 * "top-level function" for the purposes of attributing references.
 *
 * A label is treated as a top-level function if:
 *   - It lives in a code module (not a data-only module)
 *   - It has an address > 0 (not a constant / EQU)
 *
 * For simplicity we just track any label definition and reset the
 * current_function on each new label in code modules.
 *
 * @param {string} file - source file relative path
 * @returns {boolean}
 */
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
  'header.asm',
]);

// ---------------------------------------------------------------------------
// Main scanning pass
// ---------------------------------------------------------------------------

/**
 * Scan a single source file and return all reference records found.
 *
 * @param {string} relPath       - path relative to repo root
 * @param {Set<string>} knownSyms
 * @returns {{ label: string, file: string, line: number, kind: string, context: string, in_function: string|null }[]}
 */
function scanFile(relPath, knownSyms) {
  const fullPath = path.join(REPO_ROOT, relPath);
  const lines = fs.readFileSync(fullPath, { encoding: 'utf8', errors: 'replace' }).split('\n');
  const results = [];
  const isDataModule = DATA_MODULES.has(relPath);

  let currentFunction = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNo = i + 1;  // 1-based

    // Track current function (label definitions at column 0 in code modules)
    if (!isDataModule) {
      const defMatch = LABEL_DEF_RE.exec(line);
      if (defMatch) {
        currentFunction = defMatch[1];
        // Don't scan the label definition line itself for refs
        continue;
      }
    }

    // Skip blank lines and pure comment lines
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith(';')) continue;

    // Extract references from this line
    const refs = extractRefs(line, knownSyms);
    for (const { label, kind } of refs) {
      // Don't record self-references (a function referencing itself)
      if (label === currentFunction) continue;

      results.push({
        label,
        file:        relPath,
        line:        lineNo,
        kind,
        context:     trimmed,
        in_function: currentFunction,
      });
    }
  }

  return results;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  // Load symbol map
  if (!fs.existsSync(symPath)) {
    console.error(`ERROR: symbol map not found: ${symPath}`);
    console.error('Run: node tools/index/symbol_map.js');
    process.exit(1);
  }
  const symData   = JSON.parse(fs.readFileSync(symPath, 'utf8'));
  const knownSyms = new Set(Object.keys(symData.symbols));
  if (verbose) console.log(`Loaded ${knownSyms.size} symbols from ${path.basename(symPath)}`);

  // Collect source files
  const sourceFiles = collectSourceFiles();
  if (verbose) console.log(`Scanning ${sourceFiles.length} source files ...`);

  // Scan all files
  const allRefs = [];
  for (const relPath of sourceFiles) {
    const fileRefs = scanFile(relPath, knownSyms);
    if (verbose) console.log(`  ${relPath}: ${fileRefs.length} refs`);
    allRefs.push(...fileRefs);
  }

  if (verbose) console.log(`Total raw references: ${allRefs.length}`);

  // Build the refs map: label -> sorted list of callsite records
  const refsMap = {};
  for (const { label, file, line, kind, context, in_function } of allRefs) {
    if (!refsMap[label]) refsMap[label] = [];
    refsMap[label].push({ file, line, kind, context, in_function });
  }

  // Sort each label's refs by file, then line
  for (const label of Object.keys(refsMap)) {
    refsMap[label].sort((a, b) => {
      if (a.file < b.file) return -1;
      if (a.file > b.file) return  1;
      return a.line - b.line;
    });
  }

  // Sort the outer keys alphabetically
  const sortedRefs = {};
  for (const label of Object.keys(refsMap).sort()) {
    sortedRefs[label] = refsMap[label];
  }

  // Summary statistics
  const totalRefs     = allRefs.length;
  const referencedLabels = Object.keys(sortedRefs).length;
  const unreferencedLabels = [...knownSyms].filter(l => !sortedRefs[l]).length;

  // Compute kind breakdown
  const kindCounts = {};
  for (const { kind } of allRefs) {
    kindCounts[kind] = (kindCounts[kind] || 0) + 1;
  }

  // Most-referenced labels (top 10)
  const topReferenced = Object.entries(sortedRefs)
    .sort((a, b) => b[1].length - a[1].length)
    .slice(0, 10)
    .map(([label, refs]) => ({ label, count: refs.length }));

  const payload = {
    _meta: {
      source:               'smgp.asm source files',
      generated:            new Date().toISOString().slice(0, 10),
      total_refs:           totalRefs,
      referenced_labels:    referencedLabels,
      unreferenced_labels:  unreferencedLabels,
      kind_counts:          kindCounts,
      top_referenced:       topReferenced,
    },
    refs: sortedRefs,
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2) + '\n', 'utf8');

  console.log(`Wrote callsites index to ${outPath}`);
  console.log(`  ${totalRefs} total references, ${referencedLabels} labels referenced`);
  console.log(`  ${unreferencedLabels} labels have no recorded references`);
  console.log(`  Kind breakdown: ${JSON.stringify(kindCounts)}`);
  if (topReferenced.length > 0) {
    console.log(`  Most referenced: ${topReferenced.slice(0, 5).map(e => `${e.label}(${e.count})`).join(', ')}`);
  }
}

if (require.main === module) {
  main();
}

module.exports = { extractRefs, extractLabelFromToken, scanFile, collectSourceFiles };
