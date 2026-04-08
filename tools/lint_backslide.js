#!/usr/bin/env node
// tools/lint_backslide.js
//
// Backslide lint: detect raw address literals and raw pointer dc.l values
// that have been (re)introduced into code modules after symbolisation.
//
// Two classes of findings are reported:
//
//   RAW_ADDR  — raw RAM/IO literal ($FFFF####, $00FF####, $A0####, $C0000x)
//               in an instruction line of a code module.  These should have
//               been replaced with named constants; finding them means the
//               symbolisation work has been partially reversed.
//
//   RAW_PTR   — a dc.l or dc.w line in a *code* module (not a data module)
//               where the value looks like a 6-digit ROM address ($[0-9A-F]{6}),
//               i.e. a raw pointer that should have been replaced with a label.
//               Data modules and constants files are exempt.
//
// The allowlist in this file is intentionally *frozen* — the expectation is
// that the number of known exceptions never increases.  A new finding that
// is a genuine false positive should be added to the per-file allowlist here
// WITH a comment explaining why it is safe to keep as a raw literal.
//
// Usage:
//   node tools/lint_backslide.js [--strict] [-v]
//
//   --strict   Exit 1 even for warning-level finds (new allowlisted items)
//   -v         Print all findings including allowlisted ones
//
// Exit codes:
//   0 — no findings outside the allowlist
//   1 — one or more new raw literals found outside the allowlist

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

// Files entirely exempt from this lint (constants/header/data files where
// raw values are expected or where symbolisation is not required).
const EXEMPT_FILES = new Set([
  'header.asm',
  'init.asm',            // hardware initialisation — some raw I/O addresses expected
  'smgp_full.asm',       // concatenated reference — not part of build
  'constants.asm',
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
  'macros.asm',
]);

// Data-only modules — RAW_PTR check is skipped for these (they contain blob
// data that may include ROM-address-like values as legitimate data payload).
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
  'src/audio_engine.asm',   // Z80 payload — opaque binary blobs
]);

// ---------------------------------------------------------------------------
// Frozen allowlists
//
// Each entry: { literal: '$XXXXXX', reason: '...' }
// These are the ONLY raw literals permitted in code modules.
// Do not expand this list without a documented reason.
// ---------------------------------------------------------------------------

/** @type {Object.<string, Array<{literal: string, reason: string}>>} */
const RAW_ADDR_ALLOWLIST = {
  'src/core.asm': [
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/race.asm': [
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5AC2', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5C40', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/driving.asm': [],
  'src/rendering.asm': [
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/menus.asm': [],
  'src/race_support.asm': [
    { literal: '$00FF5AC2', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/ai.asm': [
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5AC2', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/audio_effects.asm': [
    { literal: '$00FF5AC4', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5AC8', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5ACC', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/objects.asm': [
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
  ],
  'src/gameplay.asm': [
    { literal: '$00FF5980', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF5AC2', reason: 'Z80 RAM window — named constant pending AUDIO-001' },
    { literal: '$00FF9100', reason: 'Z80 YM2612 register — named constant pending AUDIO-001' },
  ],
};

// ---------------------------------------------------------------------------
// Regex patterns
// ---------------------------------------------------------------------------

// Raw RAM/IO address literals in instruction lines (same as run_checks.js)
const RAW_ADDR_RE = /(?<![#A-Za-z0-9_])(\$FFFF[0-9A-F]{4}|\$00FF[0-9A-F]{4}|\$A0[0-9A-F]{4}|\$C0000[04])(?:\.(?:w|l))?(?![0-9A-F])/gi;

// Raw 6-digit ROM pointer in dc.l — matches $XXXXXX where XXXXXX is 6 uppercase hex chars
// Only flags values in the ROM range $000000–$07FFFF (512KB ROM window)
const RAW_PTR_RE = /(?<![#A-Za-z0-9_])\$([0-9A-F]{6})(?:\.l)?(?![0-9A-F])/gi;

// Lines starting with these tokens are data directives
const DATA_PREFIXES = [
  'dc.', 'dcb', 'ds.', 'txt macro', 'endm', 'while ', 'if ', 'elseif ', 'else', 'endif', 'substr ',
];

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let strict  = false;
let verbose = false;

for (const arg of argv) {
  if (arg === '--strict') strict = true;
  if (arg === '--verbose' || arg === '-v') verbose = true;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function relPath(absPath) {
  return path.relative(REPO_ROOT, absPath).replace(/\\/g, '/');
}

function iterCodeAsmFiles() {
  const files = [];
  for (const f of fs.readdirSync(REPO_ROOT).sort()) {
    if (f.endsWith('.asm')) {
      const rel = f;
      if (!EXEMPT_FILES.has(rel)) files.push(path.join(REPO_ROOT, f));
    }
  }
  const srcDir = path.join(REPO_ROOT, 'src');
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      if (f.endsWith('.asm')) files.push(path.join(srcDir, f));
    }
  }
  return files;
}

function allowedRawAddrs(rel) {
  const entries = RAW_ADDR_ALLOWLIST[rel] || [];
  return new Set(entries.map(e => e.literal.toUpperCase()));
}

// ---------------------------------------------------------------------------
// Finding types
// ---------------------------------------------------------------------------

/**
 * @typedef {{ file: string, line: number, kind: 'RAW_ADDR'|'RAW_PTR',
 *             literal: string, context: string, allowed: boolean }} Finding
 */

// ---------------------------------------------------------------------------
// Lint logic
// ---------------------------------------------------------------------------

/**
 * Scan a single file for backslide findings.
 * @param {string} absPath
 * @returns {Finding[]}
 */
function lintFile(absPath) {
  const rel = relPath(absPath);
  const isDataModule = DATA_MODULES.has(rel);
  const allowed = allowedRawAddrs(rel);

  const text  = fs.readFileSync(absPath, { encoding: 'latin1' });
  const lines = text.split('\n');
  const findings = [];

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const stripped = raw.trim();

    // Skip blank lines and pure comment lines
    if (!stripped || stripped.startsWith(';')) continue;

    // Code portion only (strip inline comments)
    const code = raw.split(';')[0];
    const lowerStripped = stripped.toLowerCase();

    // --- RAW_ADDR check (code modules only, not data prefix lines) ---
    if (!isDataModule && !DATA_PREFIXES.some(p => lowerStripped.startsWith(p))) {
      RAW_ADDR_RE.lastIndex = 0;
      let m;
      while ((m = RAW_ADDR_RE.exec(code)) !== null) {
        const literal = m[1].toUpperCase();
        findings.push({
          file:    rel,
          line:    i + 1,
          kind:    'RAW_ADDR',
          literal,
          context: raw.trimEnd(),
          allowed: allowed.has(literal),
        });
      }
    }

    // --- RAW_PTR check (code modules only, on dc.l/dc.w lines) ---
    if (!isDataModule && (lowerStripped.startsWith('dc.l') || lowerStripped.startsWith('dc.w'))) {
      RAW_PTR_RE.lastIndex = 0;
      let m;
      while ((m = RAW_PTR_RE.exec(code)) !== null) {
        const hex = m[1].toUpperCase();
        const value = parseInt(hex, 16);
        // Only flag addresses in the ROM range (0x000100–0x07FFFF)
        // Skip very small values that are likely data constants, not pointers
        if (value >= 0x000100 && value <= 0x07FFFF) {
          const literal = `$${hex}`;
          findings.push({
            file:    rel,
            line:    i + 1,
            kind:    'RAW_PTR',
            literal,
            context: raw.trimEnd(),
            allowed: false, // no allowlist for raw pointers in code modules
          });
        }
      }
    }
  }

  return findings;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const allFindings = [];

for (const absPath of iterCodeAsmFiles()) {
  allFindings.push(...lintFile(absPath));
}

const newFindings = allFindings.filter(f => !f.allowed);
const knownFindings = allFindings.filter(f => f.allowed);

if (verbose && knownFindings.length > 0) {
  console.log(`\n[INFO] ${knownFindings.length} allowlisted finding(s) (known exceptions):`);
  for (const f of knownFindings) {
    console.log(`  ${f.file}:${f.line}: [${f.kind}] ${f.literal}`);
  }
}

if (newFindings.length > 0) {
  console.error(`\nERROR: ${newFindings.length} backslide finding(s) outside allowlist:\n`);
  for (const f of newFindings) {
    console.error(`  ${f.file}:${f.line}: [${f.kind}] ${f.literal}`);
    console.error(`    ${f.context.trim()}`);
  }
  console.error('');
  console.error('Fix: replace raw literals with named constants from the constants files,');
  console.error('or add a justified entry to RAW_ADDR_ALLOWLIST in tools/lint_backslide.js.');
  process.exit(1);
}

if (strict && knownFindings.length > 0) {
  console.error(`STRICT: ${knownFindings.length} allowlisted finding(s) present (use --strict to fail on these)`);
  process.exit(1);
}

console.log(`OK: lint_backslide — 0 new raw literals found (${knownFindings.length} known exceptions).`);

// ---------------------------------------------------------------------------
// Exports for tests
// ---------------------------------------------------------------------------

module.exports = {
  lintFile,
  RAW_ADDR_ALLOWLIST,
  EXEMPT_FILES,
  DATA_MODULES,
};
