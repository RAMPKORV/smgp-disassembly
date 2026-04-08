#!/usr/bin/env node
// tools/index/symbol_map.js
//
// Build tools/index/symbol_map.json: a machine-readable symbol map parsed from
// smgp.lst (the assembler listing file produced by build.bat).
//
// Each line in smgp.lst that defines a label has the form:
//   XXXXXXXX  LabelName:
// where XXXXXXXX is an 8-digit uppercase hex ROM address.
//
// Output JSON:
//   {
//     "_meta": { "source": "smgp.lst", "count": N },
//     "symbols": { "LabelName": "0xXXXXXX", ... }   // sorted by address
//   }
//
// Usage:
//   node tools/index/symbol_map.js [--lst PATH] [--out PATH]

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_LST = path.join(REPO_ROOT, 'smgp.lst');
const DEFAULT_OUT = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');

// LABEL_RE matches lines like: "00000000  StartOfRom:"
const LABEL_RE = /^([0-9A-F]{8})\s+([A-Za-z_][A-Za-z0-9_]*):\s*$/;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let lstPath = DEFAULT_LST;
let outPath = DEFAULT_OUT;

for (let i = 0; i < argv.length; i++) {
  if ((argv[i] === '--lst' || argv[i] === '-l') && argv[i + 1]) {
    lstPath = argv[++i];
  } else if ((argv[i] === '--out' || argv[i] === '-o') && argv[i + 1]) {
    outPath = argv[++i];
  }
}

// ---------------------------------------------------------------------------
// Parse listing
// ---------------------------------------------------------------------------

/**
 * Parse smgp.lst and return { labelName -> romAddress } object sorted by address.
 * @param {string} lstFile
 * @returns {{ [label: string]: number }}
 */
function parseListing(lstFile) {
  const text = fs.readFileSync(lstFile, { encoding: 'utf8', errors: 'replace' });
  const symbols = {};
  for (const line of text.split('\n')) {
    const m = LABEL_RE.exec(line.trimEnd());
    if (m) {
      const [, addrHex, label] = m;
      symbols[label] = parseInt(addrHex, 16);
    }
  }
  return symbols;
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

  const symbols = parseListing(lstPath);

  // Sort by address value
  const sortedEntries = Object.entries(symbols)
    .sort((a, b) => a[1] - b[1]);

  const symbolsObj = {};
  for (const [label, addr] of sortedEntries) {
    symbolsObj[label] = '0x' + addr.toString(16).toUpperCase().padStart(6, '0');
  }

  const payload = {
    _meta: {
      source: 'smgp.lst',
      count: sortedEntries.length,
    },
    symbols: symbolsObj,
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2) + '\n', 'utf8');
  console.log(`Wrote ${sortedEntries.length} symbols to ${outPath}`);
}

main();
