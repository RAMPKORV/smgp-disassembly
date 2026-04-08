#!/usr/bin/env node
// tools/editor/text_editor.js
//
// EDIT-004: Text and string editor CLI.
//
// Argument-driven CLI for editing Super Monaco GP text strings.  All edits
// operate on tools/data/strings.json (the structured edit layer), validate
// that changes stay within per-entry capacity constraints, then inject modified
// bytes to out.bin at known ROM addresses via inject_strings.js.
//
// Only the four mutable categories can be edited:
//   team_names             (16 entries)
//   team_intro_messages    (32 entries, 18 unique ROM addresses)
//   pre_race_rival_messages (145 entries, 57 unique ROM addresses)
//   post_race_messages     (160 entries, 49 unique ROM addresses)
//
// Read-only categories (pre_race_track_tips, car_spec_text, race_quotes,
// championship_intro) are shown in list/show commands but cannot be edited.
//
// Usage:
//   node tools/editor/text_editor.js list
//   node tools/editor/text_editor.js show CATEGORY [INDEX]
//   node tools/editor/text_editor.js set CATEGORY INDEX TEXT
//   node tools/editor/text_editor.js validate
//   node tools/editor/text_editor.js inject [--dry-run]
//
// CATEGORY: category name or unique prefix (team_names, team_intro,
//           pre_race_rival, post_race).
// INDEX:    0-based entry index within the category.
// TEXT:     New string value. Use \n for newlines. Must use only A-Z, 0-9,
//           and special chars: space ' " . , / - ! ? ( ) newline middle-dot.
//           Leading/trailing spaces are significant (some team names start with
//           a space: " MADONNA").
//
// Examples:
//   node tools/editor/text_editor.js show team_names
//   node tools/editor/text_editor.js show post_race 0
//   node tools/editor/text_editor.js set team_names 0 " FERRARI"
//   node tools/editor/text_editor.js set team_intro 0 "DO YOUR BEST!"
//   node tools/editor/text_editor.js validate
//   node tools/editor/text_editor.js inject --dry-run
//   node tools/editor/text_editor.js inject

'use strict';

const fs   = require('fs');
const path = require('path');

const TOOLS_DIR    = path.resolve(__dirname, '..');
const REPO_ROOT    = path.resolve(TOOLS_DIR, '..');
const STRINGS_JSON = path.join(TOOLS_DIR, 'data', 'strings.json');
const OUT_BIN      = path.join(REPO_ROOT, 'out.bin');

const { injectStrings, encodeEN } = require('../inject_strings');

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------
function out(msg)  { process.stdout.write(msg + '\n'); }
function err(msg)  { process.stderr.write('ERROR: ' + msg + '\n'); }
function die(msg)  { err(msg); process.exit(1); }
function warn(msg) { process.stderr.write('WARNING: ' + msg + '\n'); }

// ---------------------------------------------------------------------------
// JSON load / save
// ---------------------------------------------------------------------------
function loadStringsJson(jsonPath) {
  jsonPath = jsonPath || STRINGS_JSON;
  if (!fs.existsSync(jsonPath)) {
    die(`strings.json not found: ${jsonPath}\n  Run: node tools/extract_strings.js`);
  }
  try {
    return JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  } catch (e) {
    die(`Failed to parse ${jsonPath}: ${e.message}`);
  }
}

function saveStringsJson(data, jsonPath) {
  jsonPath = jsonPath || STRINGS_JSON;
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// ---------------------------------------------------------------------------
// Category resolution
// ---------------------------------------------------------------------------
const CATEGORY_NAMES = [
  'team_names',
  'team_intro_messages',
  'pre_race_rival_messages',
  'post_race_messages',
  'pre_race_track_tips',
  'car_spec_text',
  'race_quotes',
  'championship_intro',
];

const MUTABLE_CATEGORIES = new Set([
  'team_names',
  'team_intro_messages',
  'pre_race_rival_messages',
  'post_race_messages',
]);

/**
 * Resolve a category spec (full name or prefix) to a canonical name.
 * Calls die() on ambiguity or no match.
 * @param {string} spec
 * @returns {string}
 */
function resolveCategory(spec) {
  const lower = spec.toLowerCase().replace(/-/g, '_');

  // Exact match
  if (CATEGORY_NAMES.includes(lower)) return lower;

  // Prefix match
  const matches = CATEGORY_NAMES.filter(n => n.startsWith(lower));
  if (matches.length === 1) return matches[0];
  if (matches.length > 1) {
    die(`Ambiguous CATEGORY ${JSON.stringify(spec)} — matches: ${matches.join(', ')}`);
  }

  die(`Unknown CATEGORY ${JSON.stringify(spec)}. Valid categories:\n  ${CATEGORY_NAMES.join('\n  ')}`);
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/**
 * Validate a single entry: check that its en string encodes within capacity.
 * Returns null on success, or an error message string on failure.
 * @param {object} entry
 * @returns {string|null}
 */
function validateEntry(entry) {
  if (entry.note === 'invalid_pointer') return null;
  if (!entry.rom_addr) return null;

  const encoded = encodeEN(entry.en);
  if (encoded === null) {
    return `String contains unmappable characters: "${entry.en}"`;
  }

  const prefixLen = (entry.prefix_raw || []).length;
  const payloadLen = prefixLen + encoded.length + 1; // +1 for 0xFF terminator
  if (payloadLen > entry.capacity) {
    return (
      `String too long: ${payloadLen} bytes (${encoded.length} chars + ` +
      `${prefixLen} prefix + 1 terminator) but capacity is ${entry.capacity}`
    );
  }

  return null;
}

/**
 * Validate all mutable categories. Returns an array of { category, index, error } objects.
 * @param {object} data
 * @returns {Array<{category: string, index: number, error: string}>}
 */
function validateAll(data) {
  const errors = [];
  for (const cat of MUTABLE_CATEGORIES) {
    const entries = (data[cat] && data[cat].entries) || [];
    for (let i = 0; i < entries.length; i++) {
      const msg = validateEntry(entries[i]);
      if (msg) errors.push({ category: cat, index: i, error: msg });
    }
  }
  return errors;
}

// ---------------------------------------------------------------------------
// Subcommands
// ---------------------------------------------------------------------------

/** list — show all categories with entry counts and mutable status */
function cmdList(data) {
  out('Category                  Entries  Unique  Mutable');
  out('─'.repeat(54));
  for (const cat of CATEGORY_NAMES) {
    const catData = data[cat];
    if (!catData) continue;
    const entries = catData.entries || [];
    const unique = new Set(
      entries.filter(e => e.rom_addr && !e.note).map(e => e.rom_addr)
    ).size;
    const mutable = (catData._meta && catData._meta.mutable) ? 'yes' : 'no (read-only)';
    const name = cat.padEnd(26);
    const cnt  = String(entries.length).padStart(7);
    const uniq = String(unique).padStart(7);
    out(`${name}${cnt}  ${uniq}  ${mutable}`);
  }
  out('');
  out('Use: node tools/editor/text_editor.js show CATEGORY [INDEX]');
}

/** show CATEGORY [INDEX] — display entries for a category */
function cmdShow(data, catName, indexSpec) {
  const catData = data[catName];
  if (!catData) die(`Category not found: ${catName}`);
  const entries = catData.entries || [];
  const mutable = catData._meta && catData._meta.mutable;

  if (indexSpec !== undefined) {
    // Show single entry
    const idx = parseInt(indexSpec, 10);
    if (isNaN(idx) || idx < 0 || idx >= entries.length) {
      die(`INDEX ${JSON.stringify(indexSpec)} out of range 0-${entries.length - 1}`);
    }
    const e = entries[idx];
    out(`Category: ${catName}  Index: ${idx}`);
    out(`rom_addr:  ${e.rom_addr || '(none)'}`);
    out(`capacity:  ${e.capacity || '?'}`);
    out(`mutable:   ${mutable ? 'yes' : 'no (read-only)'}`);
    if (e.shared) out(`shared:    yes (same ROM address as another entry)`);
    if (e.note)   out(`note:      ${e.note}`);
    out(`text:`);
    const text = (e.en || '').replace(/\n/g, '\\n');
    out(`  "${text}"`);
    const encoded = encodeEN(e.en || '');
    if (encoded) {
      const prefixLen = (e.prefix_raw || []).length;
      const payloadLen = prefixLen + encoded.length + 1;
      out(`encoded:   ${encoded.length} chars + ${prefixLen} prefix + 1 term = ${payloadLen}/${e.capacity || '?'} bytes`);
    }
    return;
  }

  // Show all entries
  out(`${catName} (${entries.length} entries, ${mutable ? 'mutable' : 'read-only'})`);
  out('─'.repeat(72));
  for (let i = 0; i < entries.length; i++) {
    const e = entries[i];
    if (e.note === 'invalid_pointer') {
      out(`[${String(i).padStart(3)}] (invalid pointer)`);
      continue;
    }
    const prefix = e.shared ? '*' : ' ';
    const addr   = e.rom_addr || '(no addr)';
    const text   = (e.en || '').replace(/\n/g, '\\n');
    const cap    = e.capacity ? `${String(e.capacity).padStart(3)}b` : '   ';
    // Show extra identifier if available
    let label = '';
    if (e.team)         label = ` [${e.team}]`;
    else if (e.table_index !== undefined) label = ` [tbl:${e.table_index}]`;
    out(`[${String(i).padStart(3)}]${prefix} ${addr} cap=${cap}${label}: "${text}"`);
  }
  out('');
  out(`* = shared ROM address (editing updates all entries at that address)`);
}

/** set CATEGORY INDEX TEXT — modify a string entry */
function cmdSet(data, catName, indexSpec, newText) {
  if (!MUTABLE_CATEGORIES.has(catName)) {
    die(`Category "${catName}" is read-only. Only mutable categories can be edited:\n  ${[...MUTABLE_CATEGORIES].join(', ')}`);
  }

  const entries = (data[catName] && data[catName].entries) || [];
  const idx = parseInt(indexSpec, 10);
  if (isNaN(idx) || idx < 0 || idx >= entries.length) {
    die(`INDEX ${JSON.stringify(indexSpec)} out of range 0-${entries.length - 1}`);
  }

  const entry = entries[idx];
  if (entry.note === 'invalid_pointer') {
    die(`Entry ${idx} is an invalid pointer and cannot be edited.`);
  }

  // Validate the new text
  const encoded = encodeEN(newText);
  if (encoded === null) {
    die(
      `Text contains unmappable characters.\n` +
      `Allowed: A-Z, 0-9, space, and: ' " . , / - ! ? ( ) \\n middle-dot(·)\n` +
      `Note: lowercase letters are not supported.`
    );
  }

  const prefixLen = (entry.prefix_raw || []).length;
  const payloadLen = prefixLen + encoded.length + 1;
  if (payloadLen > entry.capacity) {
    die(
      `Text too long: ${payloadLen} bytes (${encoded.length} chars + ` +
      `${prefixLen} prefix + 1 terminator) but capacity is ${entry.capacity}.\n` +
      `Shorten by ${payloadLen - entry.capacity} byte(s).`
    );
  }

  const oldText = entry.en;
  entry.en = newText;

  // If this entry shares a ROM address, update all entries at the same address
  const sharedAddr = entry.rom_addr;
  let sharedCount = 0;
  if (sharedAddr) {
    for (let i = 0; i < entries.length; i++) {
      if (i !== idx && entries[i].rom_addr === sharedAddr && !entries[i].note) {
        entries[i].en = newText;
        sharedCount++;
      }
    }
  }

  saveStringsJson(data);
  out(`Updated [${idx}] "${oldText.replace(/\n/g,'\\n')}" -> "${newText.replace(/\n/g,'\\n')}"`);
  out(`Payload: ${encoded.length} char(s) + ${prefixLen} prefix + 1 term = ${payloadLen}/${entry.capacity} bytes`);
  if (sharedCount > 0) {
    out(`Also updated ${sharedCount} shared entr${sharedCount === 1 ? 'y' : 'ies'} at ${sharedAddr}`);
  }
}

/** validate — check all mutable entries fit within capacity */
function cmdValidate(data) {
  const errors = validateAll(data);
  if (errors.length === 0) {
    out('Validation passed: all entries fit within capacity.');
    return;
  }
  for (const { category, index, error } of errors) {
    out(`FAIL [${category}][${index}]: ${error}`);
  }
  die(`Validation failed: ${errors.length} error(s)`);
}

/** inject [--dry-run] — write changes to out.bin */
function cmdInject(data, dryRun) {
  // Validate first
  const errors = validateAll(data);
  if (errors.length > 0) {
    for (const { category, index, error } of errors) {
      err(`[${category}][${index}]: ${error}`);
    }
    die(`Aborting: ${errors.length} validation error(s). Fix strings before injecting.`);
  }

  if (!fs.existsSync(OUT_BIN)) {
    die(`ROM not found: ${OUT_BIN}\n  Run: cmd //c build.bat`);
  }

  const rom = fs.readFileSync(OUT_BIN);

  let result;
  try {
    result = injectStrings(data, rom, { dryRun, verbose: true });
  } catch (e) {
    die(`Injection failed: ${e.message}`);
  }

  const { totalChanges, totalPatched } = result;

  if (dryRun) {
    out(`\nDry-run: ${totalPatched} unique string slots checked, ${totalChanges} would change.`);
  } else {
    if (totalChanges > 0) {
      fs.writeFileSync(OUT_BIN, rom);
      out(`\nPatched ${OUT_BIN}: ${totalPatched} slots, ${totalChanges} string(s) changed.`);
      out(`Run: cmd //c verify.bat   (only meaningful against unmodified ROM)`);
    } else {
      out(`\nNo changes: ${totalPatched} unique string slots, all bytes already match.`);
    }
  }
}

// ---------------------------------------------------------------------------
// Charset reference helper (show encoding table)
// ---------------------------------------------------------------------------
function cmdCharset() {
  out('Tile-index encoding used by the txt macro:');
  out('');
  out('  Char   Tile    Char   Tile    Char   Tile');
  out('  ─────────────────────────────────────────');
  const rows = [
    ['space', '0x32'], ["'(apos)", '0x26'], ['"(quot)', '0x27'],
    ['.(period)', '0x29'], [',(comma)', '0x2A'], ['/(slash)', '0x2B'],
    ['-(hyphen)', '0x2C'], ['!(excl)', '0x2D'], ['?(quest)', '0x2E'],
    ['((lparen)', '0x34'], [')(rparen)', '0x35'], ['\\n(newline)', '0xFC'],
    ['·(mid-dot)', '0xFA'],
  ];
  for (let i = 0; i < rows.length; i += 3) {
    const cols = rows.slice(i, i + 3).map(([c, t]) => `${c.padEnd(11)} ${t.padEnd(6)}`).join('  ');
    out(`  ${cols}`);
  }
  out('');
  out('  Digits: 0-9 → 0x00-0x09');
  out('  Letters: A-Z → 0x0A-0x23');
  out('  Terminator: 0xFF');
  out('  Prefix: 0xFD layout-selector (stored in prefix_raw, not part of visible text)');
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

function usage() {
  out('Usage:');
  out('  node tools/editor/text_editor.js list');
  out('  node tools/editor/text_editor.js show CATEGORY [INDEX]');
  out('  node tools/editor/text_editor.js set CATEGORY INDEX TEXT');
  out('  node tools/editor/text_editor.js validate');
  out('  node tools/editor/text_editor.js inject [--dry-run]');
  out('  node tools/editor/text_editor.js charset');
  out('');
  out('CATEGORY (mutable): team_names | team_intro | pre_race_rival | post_race');
  out('CATEGORY (read-only): pre_race_track_tips | car_spec_text | race_quotes | championship_intro');
  out('INDEX: 0-based entry index');
  out('TEXT:  Use \\n for newlines. A-Z 0-9 and special chars only (see: charset).');
}

if (require.main === module) {
  const argv = process.argv.slice(2);

  if (argv.length === 0 || argv[0] === '--help' || argv[0] === '-h') {
    usage();
    process.exit(0);
  }

  const subcmd = argv[0];
  const args = argv.slice(1);

  // Parse flags
  const dryRun = args.includes('--dry-run');
  const filteredArgs = args.filter(a => a !== '--dry-run');

  let jsonPath = STRINGS_JSON;
  const jsonIdx = filteredArgs.indexOf('--input');
  if (jsonIdx !== -1 && filteredArgs[jsonIdx + 1]) {
    jsonPath = filteredArgs[jsonIdx + 1];
    filteredArgs.splice(jsonIdx, 2);
  }

  if (subcmd === 'list') {
    const data = loadStringsJson(jsonPath);
    cmdList(data);

  } else if (subcmd === 'show') {
    if (filteredArgs.length === 0) die('Usage: show CATEGORY [INDEX]');
    const data = loadStringsJson(jsonPath);
    const catName = resolveCategory(filteredArgs[0]);
    cmdShow(data, catName, filteredArgs[1]);

  } else if (subcmd === 'set') {
    if (filteredArgs.length < 3) die('Usage: set CATEGORY INDEX TEXT');
    const catName = resolveCategory(filteredArgs[0]);
    const indexSpec = filteredArgs[1];
    // Join remaining args as the text (allows spaces without quoting in some shells)
    const newText = filteredArgs.slice(2).join(' ').replace(/\\n/g, '\n');
    const data = loadStringsJson(jsonPath);
    cmdSet(data, catName, indexSpec, newText);

  } else if (subcmd === 'validate') {
    const data = loadStringsJson(jsonPath);
    cmdValidate(data);

  } else if (subcmd === 'inject') {
    const data = loadStringsJson(jsonPath);
    cmdInject(data, dryRun);

  } else if (subcmd === 'charset') {
    cmdCharset();

  } else {
    err(`Unknown subcommand: ${subcmd}`);
    usage();
    process.exit(1);
  }
}

module.exports = { resolveCategory, validateEntry, validateAll, MUTABLE_CATEGORIES, CATEGORY_NAMES };
