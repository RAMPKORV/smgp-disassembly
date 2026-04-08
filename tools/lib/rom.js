// tools/lib/rom.js
//
// ROM-level helpers for Super Monaco GP.
// Provides load/save and common ROM address constants used across tools.

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');

/** Default path to the original unmodified ROM. */
const DEFAULT_ROM_PATH = path.join(REPO_ROOT, 'orig.bin');

/** Default path to the assembled output ROM. */
const DEFAULT_OUT_PATH = path.join(REPO_ROOT, 'out.bin');

/** Expected ROM size in bytes (512 KiB). */
const ROM_SIZE = 524288;

/**
 * Load the ROM binary from disk.
 * @param {string} [romPath] - path to ROM file (default: orig.bin)
 * @returns {Buffer}
 */
function loadRom(romPath = DEFAULT_ROM_PATH) {
  const buf = fs.readFileSync(romPath);
  if (buf.length !== ROM_SIZE) {
    throw new Error(
      `ROM size mismatch: expected ${ROM_SIZE} bytes, got ${buf.length} (${romPath})`
    );
  }
  return buf;
}

/**
 * Load a ROM-sized Buffer from disk without enforcing size.
 * Use this when loading intermediate / output ROMs that may differ.
 * @param {string} romPath
 * @returns {Buffer}
 */
function loadBin(romPath) {
  return fs.readFileSync(romPath);
}

/**
 * Write a Buffer to disk, creating parent directories as needed.
 * @param {string} outPath
 * @param {Buffer} buf
 */
function saveBin(outPath, buf) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, buf);
}

module.exports = {
  REPO_ROOT,
  DEFAULT_ROM_PATH,
  DEFAULT_OUT_PATH,
  ROM_SIZE,
  loadRom,
  loadBin,
  saveBin,
};
