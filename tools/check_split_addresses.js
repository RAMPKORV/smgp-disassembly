#!/usr/bin/env node
// tools/index/check_split_addresses.js (also invocable as tools/check_split_addresses.js)
//
// Split-address safety checker: compares symbol addresses in the current
// smgp.lst against the baseline in tools/index/symbol_map.json.
//
// Exit 0  if all baseline symbols are present and unchanged (new symbols OK).
// Exit 1  if any baseline symbol is missing or has moved.
//
// Usage:
//   node tools/check_split_addresses.js [--lst PATH] [--map PATH]

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_LST = path.join(REPO_ROOT, 'smgp.lst');
const DEFAULT_MAP = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');

const LABEL_RE = /^([0-9A-F]{8})\s+([A-Za-z_][A-Za-z0-9_]*):\s*$/;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let lstPath = DEFAULT_LST;
let mapPath = DEFAULT_MAP;

for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--lst' && argv[i + 1]) lstPath = argv[++i];
  else if (argv[i] === '--map' && argv[i + 1]) mapPath = argv[++i];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function parseListing(lstFile) {
  const text = fs.readFileSync(lstFile, { encoding: 'utf8', errors: 'replace' });
  const symbols = {};
  for (const line of text.split('\n')) {
    const m = LABEL_RE.exec(line.trimEnd());
    if (m) {
      symbols[m[2]] = parseInt(m[1], 16);
    }
  }
  return symbols;
}

function loadBaseline(mapFile) {
  const payload = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
  const baseline = {};
  for (const [label, addrStr] of Object.entries(payload.symbols)) {
    baseline[label] = parseInt(addrStr.replace(/^0x/i, ''), 16);
  }
  return baseline;
}

function normalizeCompatibilitySymbols(baseline, current) {
	const blobLabel = 'Monaco_arcade_post_sign_tileset_blob';
	const tilesetLabel = 'Monaco_arcade_sign_tileset';
	if (!(blobLabel in baseline)) return;
	if (blobLabel in current) return;
	if (!(tilesetLabel in current) || !(tilesetLabel in baseline)) return;
	const delta = baseline[blobLabel] - baseline[tilesetLabel];
	current[blobLabel] = current[tilesetLabel] + delta;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  if (!fs.existsSync(mapPath)) {
    console.error(`ERROR: symbol_map.json not found: ${mapPath}`);
    console.error('Run: node tools/index/symbol_map.js');
    process.exit(1);
  }
  if (!fs.existsSync(lstPath)) {
    console.error(`ERROR: smgp.lst not found: ${lstPath}`);
    console.error('Run build.bat first to generate smgp.lst');
    process.exit(1);
  }

  const baseline = loadBaseline(mapPath);
  const current = parseListing(lstPath);
	normalizeCompatibilitySymbols(baseline, current);

  const missing = Object.keys(baseline)
    .filter(l => !(l in current))
    .sort();

  const moved = Object.entries(baseline)
    .filter(([l, addr]) => l in current && current[l] !== addr)
    .map(([l, oldAddr]) => [l, oldAddr, current[l]])
    .sort((a, b) => a[0] < b[0] ? -1 : 1);

  const extra = Object.keys(current)
    .filter(l => !(l in baseline))
    .sort();

  if (missing.length === 0 && moved.length === 0) {
    if (extra.length > 0) {
      console.log(`OK: ${Object.keys(baseline).length} baseline symbols match addresses; ${extra.length} new symbol(s) added`);
      for (const l of extra.slice(0, 20)) {
        console.log(`  EXTRA ${l}`);
      }
      if (extra.length > 20) console.log(`  ... and ${extra.length - 20} more`);
    } else {
      console.log(`OK: ${Object.keys(baseline).length} symbols match baseline addresses`);
    }
    return 0;
  }

  if (missing.length > 0) {
    console.log(`Missing symbols: ${missing.length}`);
    for (const l of missing.slice(0, 20)) {
      console.log(`  MISSING ${l}`);
    }
    if (missing.length > 20) console.log(`  ... and ${missing.length - 20} more`);
  }

  if (moved.length > 0) {
    console.log(`Moved symbols: ${moved.length}`);
    for (const [l, oldAddr, newAddr] of moved.slice(0, 20)) {
      console.log(`  MOVED ${l}: 0x${oldAddr.toString(16).toUpperCase().padStart(6, '0')} -> 0x${newAddr.toString(16).toUpperCase().padStart(6, '0')}`);
    }
    if (moved.length > 20) console.log(`  ... and ${moved.length - 20} more`);
  }

  if (extra.length > 0) {
    console.log(`New symbols not in baseline: ${extra.length}`);
    for (const l of extra.slice(0, 20)) {
      console.log(`  EXTRA ${l}`);
    }
    if (extra.length > 20) console.log(`  ... and ${extra.length - 20} more`);
  }

  return 1;
}

process.exit(main());
