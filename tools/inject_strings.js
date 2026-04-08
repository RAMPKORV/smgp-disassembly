#!/usr/bin/env node
// tools/inject_strings.js
//
// Inject modified EN text strings from tools/data/strings.json back into
// the ROM binary (out.bin) by patching the bytes at each string's rom_addr.
//
// Only the four mutable categories are written:
//   team_names, team_intro_messages, pre_race_rival_messages, post_race_messages
//
// Injection constraints:
//   - Re-encoded bytes (prefix_raw + encode(en) + 0xFF) must fit in capacity.
//   - Shorter strings are padded to capacity with 0xFF bytes.
//   - Shared entries (shared:true) share their ROM address; only the first
//     occurrence at each address is written (the rest are identical).
//   - JP strings are never touched.
//   - Read-only categories (race_quotes, etc.) are skipped.
//
// Usage:
//   node tools/inject_strings.js [--input PATH] [--rom PATH] [--dry-run] [-v]
//
//   --input PATH   Path to strings.json (default: tools/data/strings.json)
//   --rom PATH     Path to ROM binary to patch (default: out.bin)
//   --dry-run      Validate and report changes without writing
//   -v, --verbose  Print per-string change details
//
// Exit 0 = success (or dry-run clean), exit 1 = error.

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_INPUT = path.join(REPO_ROOT, 'tools', 'data', 'strings.json');
const DEFAULT_ROM = path.join(REPO_ROOT, 'out.bin');

// ---------------------------------------------------------------------------
// Character encoding (tile-index encoding used by the txt macro)
// ---------------------------------------------------------------------------

const CHAR_TO_TILE = new Map([
  [' ', 0x32], ["'", 0x26], ['"', 0x27], ['?', 0x2E], ['.', 0x29],
  [',', 0x2A], ['/', 0x2B], ['-', 0x2C], ['!', 0x2D], ['(', 0x34],
  [')', 0x35], ['\n', 0xFC],
  ['\u00b7', 0xFA],  // middle-dot = column-advance control byte
]);
for (let i = 0; i < 10; i++) CHAR_TO_TILE.set(String(i), i);
for (let i = 0; i < 26; i++) CHAR_TO_TILE.set(String.fromCharCode(65 + i), 0x0A + i);

/**
 * Encode an EN string to tile bytes (without prefix or terminator).
 * Returns null if any character is unmappable.
 * @param {string} en
 * @returns {number[] | null}
 */
function encodeEN(en) {
  const out = [];
  for (const c of en) {
    if (!CHAR_TO_TILE.has(c)) return null;
    out.push(CHAR_TO_TILE.get(c));
  }
  return out;
}

/**
 * Parse a hex-string array (e.g. ['0x0e', '0x1b']) to byte values.
 * @param {string[]} hexArr
 * @returns {number[]}
 */
function hexArrToBytes(hexArr) {
  return hexArr.map(h => parseInt(h, 16));
}

// ---------------------------------------------------------------------------
// Inject a single mutable category
// ---------------------------------------------------------------------------

/**
 * Build a patch map from a list of mutable entries.
 * Returns a Map<number, number[]> from romAddr -> new bytes to write.
 * Throws an error if any string exceeds its capacity.
 *
 * @param {object[]} entries
 * @param {boolean} verbose
 * @returns {{ patches: Map<number, number[]>, changes: number, total: number }}
 */
function buildPatches(entries, verbose) {
  const patches = new Map();
  let changes = 0;
  let total = 0;

  for (const entry of entries) {
    // Skip invalid entries
    if (!entry.rom_addr || entry.note === 'invalid_pointer') continue;

    const addr = parseInt(entry.rom_addr, 16);
    if (isNaN(addr)) continue;

    // Only patch the first occurrence at each address (shared entries are identical)
    if (patches.has(addr)) continue;

    total++;

    const prefixBytes = hexArrToBytes(entry.prefix_raw || []);
    const capacity = entry.capacity;
    const originalRaw = hexArrToBytes(entry.raw_bytes || []);

    // Encode the (possibly modified) en text
    const encodedChars = encodeEN(entry.en);
    if (encodedChars === null) {
      throw new Error(
        `Cannot encode string at ${entry.rom_addr}: ` +
        `"${entry.en}" contains unmappable characters. ` +
        `Allowed: A-Z, 0-9, space, and: ' " . , / - ! ? ( ) \\n \\u00b7`
      );
    }

    // Full payload: prefix + chars + 0xFF
    const newBytes = [...prefixBytes, ...encodedChars, 0xFF];

    if (newBytes.length > capacity) {
      throw new Error(
        `String at ${entry.rom_addr} exceeds capacity: ` +
        `encoded ${newBytes.length} bytes but capacity is ${capacity} bytes. ` +
        `String: "${entry.en}" (${encodedChars.length} chars + ${prefixBytes.length} prefix + 1 terminator)`
      );
    }

    // Check if this is actually a change by comparing the new payload
    // against the stored raw_bytes. raw_bytes stores exactly the bytes
    // currently in ROM for this string (prefix + chars + 0xFF).
    // We compare newBytes against the same slice of originalRaw.
    const isChange = JSON.stringify(newBytes) !== JSON.stringify(originalRaw.slice(0, newBytes.length)) ||
                     newBytes.length !== originalRaw.length;

    if (isChange) {
      changes++;
      if (verbose) {
        // Decode original for comparison
        const origChars = originalRaw.slice(prefixBytes.length, originalRaw.lastIndexOf(0xFF));
        const TILE_TO_CHAR = new Map([
          [0x32, ' '], [0x26, "'"], [0x27, '"'], [0x2E, '?'], [0x29, '.'],
          [0x2A, ','], [0x2B, '/'], [0x2C, '-'], [0x2D, '!'], [0x34, '('],
          [0x35, ')'], [0xFC, '\n'], [0xFA, '\u00b7'],
        ]);
        for (let i = 0; i < 10; i++) TILE_TO_CHAR.set(i, String(i));
        for (let i = 0; i < 26; i++) TILE_TO_CHAR.set(0x0A + i, String.fromCharCode(65 + i));
        const origStr = origChars.map(b => TILE_TO_CHAR.get(b) || `[${b.toString(16).toUpperCase().padStart(2,'0')}]`).join('');
        console.log(`  CHANGE @ ${entry.rom_addr}: "${origStr}" -> "${entry.en}" (${newBytes.length}/${capacity} bytes)`);
      }
    }

    // Write only the natural payload bytes (prefix + chars + 0xFF).
    // Do NOT pad to capacity — bytes beyond the string terminator must not
    // be overwritten (the ROM may store 0x00 or other data there).
    patches.set(addr, newBytes);
  }

  return { patches, changes, total };
}

/**
 * Apply a patch map to a ROM buffer.
 * @param {Buffer} rom
 * @param {Map<number, number[]>} patches
 */
function applyPatches(rom, patches) {
  for (const [addr, bytes] of patches) {
    for (let i = 0; i < bytes.length; i++) {
      rom[addr + i] = bytes[i];
    }
  }
}

// ---------------------------------------------------------------------------
// Main injection logic
// ---------------------------------------------------------------------------

/**
 * Inject strings from data into the ROM buffer.
 * @param {object} data — parsed strings.json content
 * @param {Buffer} rom — ROM buffer to patch in-place
 * @param {{ dryRun?: boolean, verbose?: boolean }} opts
 * @returns {{ totalChanges: number, totalPatched: number }}
 */
function injectStrings(data, rom, opts = {}) {
  const { dryRun = false, verbose = false } = opts;

  const MUTABLE = [
    ['team_names', data.team_names.entries],
    ['team_intro_messages', data.team_intro_messages.entries],
    ['pre_race_rival_messages', data.pre_race_rival_messages.entries],
    ['post_race_messages', data.post_race_messages.entries],
  ];

  let totalChanges = 0;
  let totalPatched = 0;

  for (const [name, entries] of MUTABLE) {
    if (verbose) console.log(`\nProcessing ${name}...`);
    const { patches, changes, total } = buildPatches(entries, verbose);
    totalChanges += changes;
    totalPatched += total;

    if (!dryRun) {
      applyPatches(rom, patches);
    }

    if (verbose) console.log(`  ${name}: ${total} unique addresses, ${changes} changes`);
  }

  return { totalChanges, totalPatched };
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

if (require.main === module) {
  const argv = process.argv.slice(2);
  let inputPath = DEFAULT_INPUT;
  let romPath = DEFAULT_ROM;
  let dryRun = false;
  let verbose = false;

  for (let i = 0; i < argv.length; i++) {
    if ((argv[i] === '--input' || argv[i] === '-i') && argv[i + 1]) inputPath = argv[++i];
    else if ((argv[i] === '--rom' || argv[i] === '-r') && argv[i + 1]) romPath = argv[++i];
    else if (argv[i] === '--dry-run') dryRun = true;
    else if (argv[i] === '--verbose' || argv[i] === '-v') verbose = true;
  }

  if (!fs.existsSync(inputPath)) {
    process.stderr.write(`ERROR: Input not found: ${inputPath}\n`);
    process.exit(1);
  }
  if (!fs.existsSync(romPath)) {
    process.stderr.write(`ERROR: ROM not found: ${romPath}\n`);
    process.exit(1);
  }

  let data;
  try {
    data = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  } catch (e) {
    process.stderr.write(`ERROR: Failed to parse ${inputPath}: ${e.message}\n`);
    process.exit(1);
  }

  const rom = fs.readFileSync(romPath);

  let result;
  try {
    result = injectStrings(data, rom, { dryRun, verbose });
  } catch (e) {
    process.stderr.write(`ERROR: ${e.message}\n`);
    process.exit(1);
  }

  const { totalChanges, totalPatched } = result;

  if (dryRun) {
    console.log(`Dry-run: ${totalPatched} unique string slots checked, ${totalChanges} would change.`);
  } else {
    if (totalChanges > 0) {
      fs.writeFileSync(romPath, rom);
      console.log(`Patched ${romPath}: ${totalPatched} unique slots, ${totalChanges} strings changed.`);
    } else {
      console.log(`No changes: ${totalPatched} unique string slots, all bytes match.`);
    }
  }
}

module.exports = { injectStrings, encodeEN, buildPatches, hexArrToBytes, CHAR_TO_TILE };
