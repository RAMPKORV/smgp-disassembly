#!/usr/bin/env node
// tools/lint_raw_vdp.js
//
// Freeze check for raw VDP register writes.
//
// Detects MOVE.w #$8xxx / #$9xxx (and similar) immediate writes to
// VDP_control_port that encode a raw VDP register value inline rather than
// using the vdpComm macro or a named constant.
//
// In the current codebase these 91 writes are established/reviewed patterns
// (VDP mode registers, DMA increment, scroll-size, sprite-base, etc.).  The
// linter's job is to ensure no *new* raw VDP register writes are introduced.
// If the count rises, the new write must be justified and the FROZEN_COUNT
// updated here with a comment.
//
// VDP DMA command longs ($XXXXXXXX) are intentionally NOT flagged — those are
// VRAM/CRAM/VSRAM address words computed from the vdpComm formula and are
// expected raw values.
//
// Pattern flagged:
//   MOVE.w  #$8NNN, VDP_control_port   ; VDP register write (reg 0-23)
//   MOVE.w  #$9NNN, VDP_control_port   ; same
//
// Usage:
//   node tools/lint_raw_vdp.js [-v] [--strict]
//
//   -v         Print every flagged line including allowed ones
//   --strict   Exit 1 even when count matches (fail if count changes at all)
//
// Exit codes:
//   0 — raw VDP write count matches frozen baseline
//   1 — count exceeds baseline (new raw writes introduced)

'use strict';

const fs   = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

// ---------------------------------------------------------------------------
// Frozen baseline — DO NOT increase without a documented reason
// ---------------------------------------------------------------------------

const FROZEN_COUNT = 91;

/**
 * Per-file frozen counts for documentation purposes.
 * Informational only — the linter gates on the total count.
 */
const FROZEN_PER_FILE = {
  'src/core.asm':     7,
  'src/endgame.asm':  3,
  'src/gameplay.asm': 33,
  'src/menus.asm':    12,
  'src/objects.asm':  3,
  'src/race.asm':     33,
};

// ---------------------------------------------------------------------------
// Files exempt from the VDP check (opaque data / constants files)
// ---------------------------------------------------------------------------

const EXEMPT_FILES = new Set([
  'header.asm',
  'init.asm',          // hardware init — VDP setup lives here intentionally
  'smgp_full.asm',
  'constants.asm',
  'hw_constants.asm',
  'ram_addresses.asm',
  'sound_constants.asm',
  'game_constants.asm',
  'macros.asm',
  'src/audio_engine.asm',  // Z80 payload
]);

// ---------------------------------------------------------------------------
// Pattern: MOVE.w with a 4-digit hex immediate in the $80xx–$9Fxx range
// writing to VDP_control_port.
// ---------------------------------------------------------------------------

/** Matches #$8NNN or #$9NNN (case-insensitive) in the code portion of a line. */
const VDP_REG_RE = /#\$[89][0-9A-Fa-f]{3}/;

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
      if (f.endsWith('.asm') && !EXEMPT_FILES.has(f) && !EXEMPT_FILES.has(`src/${f}`)) {
        files.push(path.join(srcDir, f));
      }
    }
  }
  return files;
}

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------

/**
 * Scan a single file for raw VDP register writes.
 * @param {string} absPath
 * @returns {Array<{file: string, line: number, context: string}>}
 */
function scanFile(absPath) {
  const rel    = relPath(absPath);
  const lines  = fs.readFileSync(absPath, { encoding: 'latin1' }).split('\n');
  const found  = [];

  for (let i = 0; i < lines.length; i++) {
    const raw     = lines[i];
    const stripped = raw.trim();
    if (!stripped || stripped.startsWith(';')) continue;

    const code = raw.split(';')[0];
    if (
      /MOVE\.w/i.test(code) &&
      /VDP_control_port/.test(code) &&
      VDP_REG_RE.test(code)
    ) {
      found.push({ file: rel, line: i + 1, context: raw.trimEnd() });
    }
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

  if (verbose) {
    for (const f of allFindings) {
      console.log(`  ${f.file}:${f.line}: ${f.context.trim()}`);
    }
  }

  if (totalFound > FROZEN_COUNT) {
    console.error(
      `\nERROR: lint_raw_vdp — ${totalFound} raw VDP register write(s) found; ` +
      `frozen baseline is ${FROZEN_COUNT}.`
    );
    console.error(
      'New raw VDP register writes must be replaced with named macros/constants\n' +
      'or documented with a justified reason and the FROZEN_COUNT updated.'
    );
    process.exit(1);
  }

  if (strict && totalFound !== FROZEN_COUNT) {
    console.error(
      `STRICT: raw VDP write count changed: expected ${FROZEN_COUNT}, got ${totalFound}.`
    );
    process.exit(1);
  }

  console.log(
    `OK: lint_raw_vdp — ${totalFound} raw VDP register writes (frozen baseline: ${FROZEN_COUNT}).`
  );
}

// ---------------------------------------------------------------------------
// Exports for tests
// ---------------------------------------------------------------------------

module.exports = {
  scanFile,
  FROZEN_COUNT,
  FROZEN_PER_FILE,
  EXEMPT_FILES,
  VDP_REG_RE,
};
