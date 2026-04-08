#!/usr/bin/env node
// tools/audit_magic_numbers.js
//
// Flag large decimal numeric literals in code files that lack an inline
// comment explaining their meaning.
//
// "Magic number" in this context means a decimal immediate >= 100 used in an
// instruction that has no ; comment on the same line.  Small values (0-99)
// are idiomatic for bit indices, array sizes, and small constants and are not
// flagged.  Hex literals and assembly directives (dc.b/dc.w/dc.l) are also
// excluded — this lint targets executable code lines only.
//
// The goal is incremental improvement: the FROZEN_COUNT sets the baseline;
// every fix that adds an explanatory comment reduces the count.  If the count
// rises (new unexplained magic numbers introduced) the check fails.
//
// Usage:
//   node tools/audit_magic_numbers.js [-v] [--strict]
//
//   -v         Print every finding
//   --strict   Fail if count differs from frozen baseline (catches reductions
//              that were not reflected in FROZEN_COUNT)
//
// Exit codes:
//   0 — finding count is at or below the frozen baseline
//   1 — count exceeds baseline (new magic numbers introduced)

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

// ---------------------------------------------------------------------------
// Frozen baseline — update when magic numbers are documented or removed.
// The baseline is the *current* count; it should only decrease over time.
// ---------------------------------------------------------------------------

const FROZEN_COUNT = 14;

// ---------------------------------------------------------------------------
// Files exempt from this lint
// ---------------------------------------------------------------------------

const EXEMPT_FILES = new Set([
  'header.asm',
  'init.asm',
  'smgp_full.asm',
  'constants.asm',
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
  'macros.asm',
  'src/audio_engine.asm',
]);

// Data-only modules — skip (dc.b/dc.w/dc.l blobs are not code)
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
]);

// Instruction prefixes that indicate this is a data/macro directive, not code
const DATA_PREFIXES = [
  'dc.', 'dcb', 'ds.', 'txt', 'endm', 'while ', 'if ', 'elseif ',
  'else', 'endif', 'substr ', 'rept ', 'endr',
];

// Threshold: decimal literals with absolute value >= this are flagged
const MIN_DECIMAL = 100;

// Regex: decimal immediate (not preceded by $ or hex digit)
// Captures the decimal number; requires it to be preceded by # and not $ (hex)
const DECIMAL_IMM_RE = /#([0-9]{3,})\b/;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
const verbose = argv.includes('-v') || argv.includes('--verbose');
const strict  = argv.includes('--strict');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function relPath(absPath) {
  return path.relative(REPO_ROOT, absPath).replace(/\\/g, '/');
}

function iterCodeAsmFiles() {
  const files = [];
  for (const f of fs.readdirSync(REPO_ROOT).sort()) {
    if (f.endsWith('.asm') && !EXEMPT_FILES.has(f)) {
      files.push(path.join(REPO_ROOT, f));
    }
  }
  const srcDir = path.join(REPO_ROOT, 'src');
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir).sort()) {
      if (f.endsWith('.asm')) {
        const rel = `src/${f}`;
        if (!EXEMPT_FILES.has(rel) && !DATA_MODULES.has(rel)) {
          files.push(path.join(srcDir, f));
        }
      }
    }
  }
  return files;
}

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------

/**
 * @typedef {{ file: string, line: number, value: number, context: string }} Finding
 */

/**
 * Scan a single file for uncommented decimal magic numbers.
 * @param {string} absPath
 * @returns {Finding[]}
 */
function scanFile(absPath) {
  const rel    = relPath(absPath);
  const lines  = fs.readFileSync(absPath, { encoding: 'latin1' }).split('\n');
  const found  = [];

  for (let i = 0; i < lines.length; i++) {
    const raw      = lines[i];
    const stripped = raw.trim();
    if (!stripped || stripped.startsWith(';')) continue;

    const lowerStripped = stripped.toLowerCase();

    // Skip data directive lines
    if (DATA_PREFIXES.some(p => lowerStripped.startsWith(p))) continue;

    // Only inspect the code portion (before any inline comment)
    const code = raw.split(';')[0];

    // Must have a decimal immediate
    const m = DECIMAL_IMM_RE.exec(code);
    if (!m) continue;

    const value = parseInt(m[1], 10);
    if (value < MIN_DECIMAL) continue;

    // If the full line has an inline comment, it's documented — skip
    if (raw.includes(';')) continue;

    found.push({ file: rel, line: i + 1, value, context: raw.trimEnd() });
  }

  return found;
}

// ---------------------------------------------------------------------------
// Main (only runs when invoked directly, not when require()'d)
// ---------------------------------------------------------------------------

if (require.main === module) {
  const allFindings = [];

  for (const absPath of iterCodeAsmFiles()) {
    allFindings.push(...scanFile(absPath));
  }

  const totalFound = allFindings.length;

  if (verbose || totalFound > 0) {
    if (allFindings.length > 0) {
      console.log(`\nFindings (${totalFound}):`);
      for (const f of allFindings) {
        console.log(`  ${f.file}:${f.line}: [${f.value}] ${f.context.trim()}`);
      }
      console.log('');
    }
  }

  if (totalFound > FROZEN_COUNT) {
    console.error(
      `ERROR: audit_magic_numbers — ${totalFound} uncommented decimal magic numbers found; ` +
      `frozen baseline is ${FROZEN_COUNT}.`
    );
    console.error(
      'Add an inline comment (;) explaining each new literal, ' +
      'or define a named constant in the appropriate constants file.'
    );
    process.exit(1);
  }

  if (strict && totalFound !== FROZEN_COUNT) {
    console.error(
      `STRICT: magic number count changed: expected ${FROZEN_COUNT}, got ${totalFound}. ` +
      'Update FROZEN_COUNT in audit_magic_numbers.js.'
    );
    process.exit(1);
  }

  console.log(
    `OK: audit_magic_numbers — ${totalFound} uncommented decimal magic numbers ` +
    `(frozen baseline: ${FROZEN_COUNT}).`
  );
}

// ---------------------------------------------------------------------------
// Exports for tests
// ---------------------------------------------------------------------------

module.exports = {
  scanFile,
  FROZEN_COUNT,
  MIN_DECIMAL,
  EXEMPT_FILES,
  DATA_MODULES,
  DECIMAL_IMM_RE,
};
