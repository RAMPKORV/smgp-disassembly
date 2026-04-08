#!/usr/bin/env node
// tools/extract_strings.js
//
// Extract editable text strings from the Super Monaco GP ROM and emit
// tools/data/strings.json — the structured edit layer for the string injector.
//
// Only the four mutable EN string categories are extracted into the editable
// layer; VDP-packed and fixed-width strings are included as read-only reference.
//
// Mutable categories (can be injected with inject_strings.js):
//   post_race_messages     (EN only; JP stored as hex reference)
//   pre_race_rival_messages (EN only; JP stored as hex reference)
//   team_intro_messages    (EN only; JP stored as hex reference)
//   team_names             (EN only; JP stored as hex reference)
//
// Read-only reference (injector will not touch these):
//   race_quotes            (complex VDP packed-tilemap format)
//   championship_intro     (complex VDP packed-tilemap format)
//   pre_race_track_tips    (JP/EN pointer strings — tips)
//   car_spec_text          (fixed-length fields, no slack)
//   driver_info            (fixed-length fields, no slack)
//   track_names            (packed-tilemap with $FA separators)
//
// Each mutable entry includes:
//   rom_addr   — hex address in ROM where the string payload begins
//   prefix_raw — hex bytes before visible text (e.g. $FD layout-selector)
//   en         — decoded English text (editable)
//   raw_bytes  — hex encoding of the full current payload (prefix + chars + $FF)
//   capacity   — total bytes available for this slot (raw_bytes.length ≤ capacity)
//
// Usage:
//   node tools/extract_strings.js [--rom PATH] [--out PATH] [--verbose]
//
// Output: tools/data/strings.json

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_ROM = path.join(REPO_ROOT, 'orig.bin');
const DEFAULT_OUT = path.join(REPO_ROOT, 'tools', 'data', 'strings.json');

// ---------------------------------------------------------------------------
// Character encoding (tile-index encoding used by the txt macro)
// ---------------------------------------------------------------------------

const TILE_TO_CHAR = new Map([
  [0x32, ' '], [0x26, "'"], [0x27, '"'], [0x2E, '?'], [0x29, '.'],
  [0x2A, ','], [0x2B, '/'], [0x2C, '-'], [0x2D, '!'], [0x34, '('],
  [0x35, ')'], [0xFC, '\n'], [0xFA, '\u00b7'],
]);
for (let i = 0; i < 10; i++) TILE_TO_CHAR.set(i, String(i));
for (let i = 0; i < 26; i++) TILE_TO_CHAR.set(0x0A + i, String.fromCharCode(65 + i));

const CHAR_TO_TILE = new Map();
for (const [b, c] of TILE_TO_CHAR) {
  if (!CHAR_TO_TILE.has(c)) CHAR_TO_TILE.set(c, b);
}

const ROM_SIZE = 0x80000;

// ---------------------------------------------------------------------------
// Low-level ROM read helpers
// ---------------------------------------------------------------------------

/**
 * Read a big-endian 32-bit pointer.
 * @param {Buffer} rom
 * @param {number} addr
 * @returns {number}
 */
function readPtr(rom, addr) {
  return rom.readUInt32BE(addr);
}

/**
 * Read a big-endian 16-bit word.
 * @param {Buffer} rom
 * @param {number} addr
 * @returns {number}
 */
function readWord(rom, addr) {
  return rom.readUInt16BE(addr);
}

/**
 * Format an address as a 0x-prefixed hex string.
 * @param {number} addr
 * @returns {string}
 */
function hex(addr) {
  return '0x' + addr.toString(16).padStart(6, '0');
}

// ---------------------------------------------------------------------------
// String parse helpers
// ---------------------------------------------------------------------------

/**
 * Parse an EN string at the given ROM address.
 *
 * Returns:
 *   prefix_raw  — array of raw byte values before the visible text (e.g. [0xFD])
 *   en          — decoded visible English text
 *   raw_bytes   — full sequence: prefix_raw + encoded_chars + [0xFF]
 *   encoded_len — total byte count (= raw_bytes.length)
 *
 * Prefix bytes consumed:
 *   0xFD — layout-selector: 1-byte prefix, consumed silently
 *   0xE4, 0xE5, 0x28 — VDP DMA preamble bytes, consumed silently
 *   0xFB — VDP tilemap prefix: next 2 bytes are an address (3-byte group, consumed silently)
 *
 * @param {Buffer} rom
 * @param {number} addr
 * @returns {{ prefix_raw: number[], en: string, raw_bytes: number[], encoded_len: number }}
 */
function parseEnString(rom, addr) {
  const raw_bytes = [];
  const prefix_raw = [];
  const chars = [];
  let pos = addr;

  // Collect prefix bytes
  while (pos < rom.length) {
    const b = rom[pos];
    if (b === 0xFD || b === 0xE4 || b === 0xE5 || b === 0x28) {
      prefix_raw.push(b);
      raw_bytes.push(b);
      pos++;
    } else if (b === 0xFB) {
      // VDP tilemap prefix: consume 3 bytes (0xFB + 2-byte address)
      prefix_raw.push(b, rom[pos + 1], rom[pos + 2]);
      raw_bytes.push(b, rom[pos + 1], rom[pos + 2]);
      pos += 3;
    } else {
      break;
    }
  }

  // Decode visible characters
  while (pos < rom.length) {
    const b = rom[pos];
    if (b === 0xFF) {
      raw_bytes.push(0xFF);
      pos++;
      break;
    }
    raw_bytes.push(b);
    const c = TILE_TO_CHAR.has(b) ? TILE_TO_CHAR.get(b) : `[${b.toString(16).toUpperCase().padStart(2, '0')}]`;
    chars.push(c);
    pos++;
  }

  return {
    prefix_raw,
    en: chars.join(''),
    raw_bytes,
    encoded_len: raw_bytes.length,
  };
}

/**
 * Compute the capacity (max bytes available) for each unique address.
 *
 * Capacity = min(gap to next address, own_encoded_len + MAX_SLACK).
 * MAX_SLACK prevents cross-region capacity bleed when two string blocks are
 * far apart but their unique-address lists happen to be sorted together.
 *
 * @param {number[]} sortedAddrs — sorted unique addresses
 * @param {Map<number, number>} encodedLenByAddr — encoded_len for each addr
 * @param {number} regionEnd — exclusive end address of the string region
 * @returns {Map<number, number>} capacity by address
 */
function computeCapacities(sortedAddrs, encodedLenByAddr, regionEnd) {
  const MAX_SLACK = 4;
  const cap = new Map();
  for (let i = 0; i < sortedAddrs.length; i++) {
    const addr = sortedAddrs[i];
    const next = i + 1 < sortedAddrs.length ? sortedAddrs[i + 1] : regionEnd;
    const gap = next - addr;
    const own = encodedLenByAddr.get(addr) || 1;
    cap.set(addr, Math.min(gap, own + MAX_SLACK));
  }
  return cap;
}

// ---------------------------------------------------------------------------
// JP raw reader (for reference only)
// ---------------------------------------------------------------------------

/**
 * Read a JP string as an array of hex byte strings until $FF.
 * @param {Buffer} rom
 * @param {number} addr
 * @returns {string[]}
 */
function rawJpHex(rom, addr) {
  const out = [];
  let i = 0;
  while (addr + i < rom.length && rom[addr + i] !== 0xFF) {
    out.push('0x' + rom[addr + i].toString(16).padStart(2, '0'));
    i++;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Category extractors
// ---------------------------------------------------------------------------

const TEAM_NAMES = [
  'Madonna', 'Firenze', 'Millions', 'Bestowal', 'Blanche', 'Tyrant',
  'Losel', 'May', 'Bullets', 'Dardan', 'Linden', 'Minarae',
  'Rigel', 'Comet', 'Orchis', 'Zeroforce',
];

/**
 * Extract the 16 team name EN strings.
 * Table: Team_name_strings_table at 0x3B9A2 (32 dc.l pointers; JP=0-15, EN=16-31).
 * @param {Buffer} rom
 * @returns {object[]}
 */
function extractTeamNames(rom) {
  const TABLE = 0x3B9A2;
  const entries = [];
  for (let i = 0; i < 16; i++) {
    const jpPtr = readPtr(rom, TABLE + i * 4);
    const enPtr = readPtr(rom, TABLE + (i + 16) * 4);
    const { prefix_raw, en, raw_bytes, encoded_len } = parseEnString(rom, enPtr);
    entries.push({
      id: i,
      team: TEAM_NAMES[i],
      rom_addr: hex(enPtr),
      prefix_raw: prefix_raw.map(b => '0x' + b.toString(16).padStart(2, '0')),
      en,
      raw_bytes: raw_bytes.map(b => '0x' + b.toString(16).padStart(2, '0')),
      capacity: encoded_len,        // team names have no inter-string slack
      jp_ref: { rom_addr: hex(jpPtr), bytes: rawJpHex(rom, jpPtr) },
    });
  }
  return entries;
}

/**
 * Extract the 64 team intro EN strings (indices 32-63 in the pointer table).
 * Table: Team_intro_table at 0x3B07E.
 * @param {Buffer} rom
 * @returns {object[]}
 */
function extractTeamIntroEN(rom) {
  const TABLE = 0x3B07E;
  const rawEntries = [];
  for (let i = 32; i < 64; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    rawEntries.push({ table_index: i, rom_addr: ptr });
  }

  // Compute unique addresses and their capacities
  const addrSet = [...new Set(rawEntries.map(e => e.rom_addr))].sort((a, b) => a - b);
  const parsedByAddr = new Map();
  for (const addr of addrSet) {
    parsedByAddr.set(addr, parseEnString(rom, addr));
  }
  const lenByAddr = new Map(addrSet.map(a => [a, parsedByAddr.get(a).encoded_len]));
  // Region end: use last addr + its encoded_len
  const regionEnd = addrSet[addrSet.length - 1] + lenByAddr.get(addrSet[addrSet.length - 1]);
  const capByAddr = computeCapacities(addrSet, lenByAddr, regionEnd);

  const entries = [];
  const seenAddr = new Set();
  for (const e of rawEntries) {
    const addr = e.rom_addr;
    const { prefix_raw, en, raw_bytes } = parsedByAddr.get(addr);
    const entry = {
      table_index: e.table_index,
      rom_addr: hex(addr),
      prefix_raw: prefix_raw.map(b => '0x' + b.toString(16).padStart(2, '0')),
      en,
      raw_bytes: raw_bytes.map(b => '0x' + b.toString(16).padStart(2, '0')),
      capacity: capByAddr.get(addr),
    };
    if (seenAddr.has(addr)) entry.shared = true;
    else seenAddr.add(addr);
    entries.push(entry);
  }
  return entries;
}

/**
 * Extract the 145 pre-race rival message EN strings.
 * Table: Team_msg_jp_table at 0x3A27A (290 dc.l pointers; JP=0-144, EN=145-289).
 * Index 0 is the error sentinel (shared pointer, both JP and EN point to "ERROR").
 * @param {Buffer} rom
 * @returns {object[]}
 */
function extractPreRaceRivalEN(rom) {
  const TABLE = 0x3A27A;
  const COUNT = 145;
  const rawEntries = [];
  for (let i = 0; i < COUNT; i++) {
    const enPtr = readPtr(rom, TABLE + i * 4 + COUNT * 4);
    // Filter out obviously bad pointers (outside ROM)
    if (enPtr >= ROM_SIZE || enPtr < 0x1000) {
      rawEntries.push({ id: i, rom_addr: null });
    } else {
      rawEntries.push({ id: i, rom_addr: enPtr });
    }
  }

  // Unique valid addresses, sorted
  const addrSet = [...new Set(rawEntries.filter(e => e.rom_addr !== null).map(e => e.rom_addr))].sort((a, b) => a - b);
  const parsedByAddr = new Map();
  for (const addr of addrSet) {
    parsedByAddr.set(addr, parseEnString(rom, addr));
  }
  const lenByAddr = new Map(addrSet.map(a => [a, parsedByAddr.get(a).encoded_len]));
  const regionEnd = addrSet[addrSet.length - 1] + lenByAddr.get(addrSet[addrSet.length - 1]);
  const capByAddr = computeCapacities(addrSet, lenByAddr, regionEnd);

  const entries = [];
  const seenAddr = new Set();
  for (const e of rawEntries) {
    if (e.rom_addr === null) {
      entries.push({ id: e.id, rom_addr: null, note: 'invalid_pointer' });
      continue;
    }
    const addr = e.rom_addr;
    const { prefix_raw, en, raw_bytes } = parsedByAddr.get(addr);
    const entry = {
      id: e.id,
      rom_addr: hex(addr),
      prefix_raw: prefix_raw.map(b => '0x' + b.toString(16).padStart(2, '0')),
      en,
      raw_bytes: raw_bytes.map(b => '0x' + b.toString(16).padStart(2, '0')),
      capacity: capByAddr.get(addr),
    };
    if (seenAddr.has(addr)) entry.shared = true;
    else seenAddr.add(addr);
    entries.push(entry);
  }
  return entries;
}

/**
 * Extract the 160 post-race EN strings.
 * Table: Team_msg_after_race_table at 0x3BB14 (320 dc.l pointers; JP=0-159, EN=160-319).
 * Index = team_id * 10 + result_slot.
 * @param {Buffer} rom
 * @returns {object[]}
 */
function extractPostRaceEN(rom) {
  const TABLE = 0x3BB14;
  const COUNT_JP = 160;
  const COUNT_EN = 160;

  const rawEntries = [];
  for (let i = 0; i < COUNT_EN; i++) {
    const ptr = readPtr(rom, TABLE + (COUNT_JP + i) * 4);
    rawEntries.push({
      index: i,
      team_id: Math.floor(i / 10),
      result_slot: i % 10,
      rom_addr: ptr,
    });
  }

  // Unique valid addresses, sorted
  const addrSet = [...new Set(rawEntries.map(e => e.rom_addr))].sort((a, b) => a - b);
  const parsedByAddr = new Map();
  for (const addr of addrSet) {
    parsedByAddr.set(addr, parseEnString(rom, addr));
  }
  const lenByAddr = new Map(addrSet.map(a => [a, parsedByAddr.get(a).encoded_len]));
  const regionEnd = addrSet[addrSet.length - 1] + lenByAddr.get(addrSet[addrSet.length - 1]);
  const capByAddr = computeCapacities(addrSet, lenByAddr, regionEnd);

  const entries = [];
  const seenAddr = new Set();
  for (const e of rawEntries) {
    const addr = e.rom_addr;
    const { prefix_raw, en, raw_bytes } = parsedByAddr.get(addr);
    const entry = {
      index: e.index,
      team_id: e.team_id,
      team: TEAM_NAMES[e.team_id] || `team_${e.team_id}`,
      result_slot: e.result_slot,
      rom_addr: hex(addr),
      prefix_raw: prefix_raw.map(b => '0x' + b.toString(16).padStart(2, '0')),
      en,
      raw_bytes: raw_bytes.map(b => '0x' + b.toString(16).padStart(2, '0')),
      capacity: capByAddr.get(addr),
    };
    if (seenAddr.has(addr)) entry.shared = true;
    else seenAddr.add(addr);
    entries.push(entry);
  }
  return entries;
}

// ---------------------------------------------------------------------------
// Read-only reference extractors (not injected, just for human reference)
// ---------------------------------------------------------------------------

function extractPreRaceTipsRef(rom) {
  const TABLE = 0x3B524;
  const COUNT = 17;
  const TRACKS = [
    'partner_challenge',
    'San_Marino', 'Brazil', 'France', 'Hungary', 'West_Germany',
    'USA', 'Canada', 'Great_Britain', 'Italy', 'Portugal', 'Spain',
    'Mexico', 'Japan', 'Belgium', 'Australia', 'Monaco',
  ];
  const entries = [];
  for (let i = 0; i < COUNT; i++) {
    const enPtr = readPtr(rom, TABLE + i * 4 + COUNT * 4);
    const { en } = parseEnString(rom, enPtr);
    entries.push({
      id: i,
      context: i < TRACKS.length ? TRACKS[i] : `track_${i}`,
      rom_addr: hex(enPtr),
      en: en.trim(),
      note: 'read_only',
    });
  }
  return entries;
}

function extractCarSpecRef(rom) {
  const TABLE = 0x19114;
  const entries = [];
  for (let i = 0; i < 16; i++) {
    const off = TABLE + i * 0x12;
    const namePtr = readPtr(rom, off) + 1;
    const nameLen = readWord(rom, off + 4);
    const enginePtr = readPtr(rom, off + 6) + 1;
    const engineLen = readWord(rom, off + 10);
    const powerPtr = readPtr(rom, off + 12) + 1;
    const powerLen = readWord(rom, off + 16);

    function decodeFixed(addr, len) {
      const chars = [];
      for (let j = 0; j < len; j++) {
        const b = rom[addr + j];
        if (b === 0xFF) { chars.push('|'); continue; }
        const c = TILE_TO_CHAR.has(b) ? TILE_TO_CHAR.get(b) : `[${b.toString(16).toUpperCase().padStart(2, '0')}]`;
        chars.push(c);
      }
      return chars.join('').trim();
    }

    entries.push({
      id: i,
      team: TEAM_NAMES[i],
      car_name: { rom_addr: hex(namePtr), len: nameLen, en: decodeFixed(namePtr, nameLen) },
      engine:   { rom_addr: hex(enginePtr), len: engineLen, en: decodeFixed(enginePtr, engineLen) },
      max_power:{ rom_addr: hex(powerPtr), len: powerLen, en: decodeFixed(powerPtr, powerLen) },
      note: 'read_only',
    });
  }
  return entries;
}

function extractRaceQuotesRef(rom) {
  const TABLE = 0x32F68;
  const COUNT = 15;
  const entries = [];
  for (let i = 0; i < COUNT; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const { en } = parseEnString(rom, ptr);
    entries.push({ id: i + 1, rom_addr: hex(ptr), en: en.trim(), note: 'read_only_vdp_packed' });
  }
  return entries;
}

function extractChampionshipIntroRef(rom) {
  const TABLE = 0x3310A;
  const COUNT = 6;
  const entries = [];
  for (let i = 0; i < COUNT; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const { en } = parseEnString(rom, ptr);
    entries.push({ id: i + 1, rom_addr: hex(ptr), en: en.trim(), note: 'read_only_vdp_packed' });
  }
  return entries;
}

// ---------------------------------------------------------------------------
// Main extraction
// ---------------------------------------------------------------------------

/**
 * Build and return the strings data object.
 * @param {string} romPath
 * @param {boolean} verbose
 * @returns {object}
 */
function extractStrings(romPath, verbose) {
  const rom = fs.readFileSync(romPath);

  if (verbose) process.stderr.write('Extracting team names...\n');
  const teamNames = extractTeamNames(rom);

  if (verbose) process.stderr.write('Extracting team intro EN strings...\n');
  const teamIntroEN = extractTeamIntroEN(rom);

  if (verbose) process.stderr.write('Extracting pre-race rival EN strings...\n');
  const preRaceRivalEN = extractPreRaceRivalEN(rom);

  if (verbose) process.stderr.write('Extracting post-race EN strings...\n');
  const postRaceEN = extractPostRaceEN(rom);

  if (verbose) process.stderr.write('Extracting read-only references...\n');
  const preRaceTipsRef = extractPreRaceTipsRef(rom);
  const carSpecRef = extractCarSpecRef(rom);
  const raceQuotesRef = extractRaceQuotesRef(rom);
  const champIntroRef = extractChampionshipIntroRef(rom);

  const uniquePostRace = new Set(postRaceEN.filter(e => !e.shared).map(e => e.rom_addr));
  const uniquePreRace = new Set(preRaceRivalEN.filter(e => e.rom_addr && !e.shared).map(e => e.rom_addr));
  const uniqueTeamIntro = new Set(teamIntroEN.filter(e => !e.shared).map(e => e.rom_addr));

  return {
    _meta: {
      description: (
        'Editable text strings extracted from the Super Monaco GP ROM. ' +
        'Four mutable categories (team_names, team_intro_messages, ' +
        'pre_race_rival_messages, post_race_messages) can be patched in-place ' +
        'with inject_strings.js within their per-entry capacity constraints. ' +
        'Read-only categories are included for reference only and will not be ' +
        'modified by the injector.'
      ),
      encoding_note: (
        'EN strings use tile-index encoding: space=0x32, 0-9=0x00-0x09, ' +
        'A-Z=0x0A-0x23. Special: \'=0x26, "=0x27, .=0x29, ,=0x2A, /=0x2B, ' +
        '-=0x2C, !=0x2D, ?=0x2E, (=0x34, )=0x35, \\n=0xFC. ' +
        'Prefix bytes: 0xFD=layout_selector. Terminator: 0xFF. ' +
        'Middle-dot (\u00b7) in decoded text = 0xFA column-advance control byte.'
      ),
      mutable_categories: [
        'team_names', 'team_intro_messages',
        'pre_race_rival_messages', 'post_race_messages',
      ],
      injection_constraint: (
        'Each entry has a capacity field (bytes). ' +
        'The re-encoded string (prefix_raw + encode(en) + 0xFF) must be ' +
        '\u2264 capacity. Shorter strings are padded with 0xFF. ' +
        'Shared entries (shared:true) share their ROM address with another entry; ' +
        'editing one also changes all entries at the same address.'
      ),
      stats: {
        team_names: teamNames.length,
        team_intro_unique_en: uniqueTeamIntro.size,
        pre_race_rival_unique_en: uniquePreRace.size,
        post_race_unique_en: uniquePostRace.size,
      },
    },
    team_names: {
      _meta: {
        count: teamNames.length,
        table_addr: '0x03b9a2',
        mutable: true,
        description: '16 team name EN strings. One per team, tight packing (capacity = own length).',
      },
      entries: teamNames,
    },
    team_intro_messages: {
      _meta: {
        count: teamIntroEN.length,
        unique_addresses: uniqueTeamIntro.size,
        table_addr: '0x03b07e',
        mutable: true,
        description: (
          '32 EN team intro messages (table indices 32-63). ' +
          'Some entries share the same ROM address (shared:true); ' +
          'editing the first occurrence updates all copies automatically.'
        ),
      },
      entries: teamIntroEN,
    },
    pre_race_rival_messages: {
      _meta: {
        count: preRaceRivalEN.length,
        unique_addresses: uniquePreRace.size,
        table_addr: '0x03a27a',
        mutable: true,
        description: (
          '145 pre-race rival EN messages. Index 0 = error sentinel. ' +
          'Many entries share pointers; editing the first occurrence is sufficient. ' +
          'Entries with invalid_pointer have corrupt pointer table values.'
        ),
      },
      entries: preRaceRivalEN,
    },
    post_race_messages: {
      _meta: {
        count: postRaceEN.length,
        unique_addresses: uniquePostRace.size,
        table_addr: '0x03bb14',
        mutable: true,
        description: (
          '160 post-race EN messages. Index = team_id * 10 + result_slot. ' +
          'result_slots: 0=win, 1=2nd, 2=3rd, 3=bottom-half, 4=lose-to-partner, ' +
          '5=beat-partner, 6=promoted, 7=relegated, 8=continue, 9=retire.'
        ),
      },
      entries: postRaceEN,
    },
    pre_race_track_tips: {
      _meta: {
        count: preRaceTipsRef.length,
        table_addr: '0x03b524',
        mutable: false,
        description: '17 pre-race track tip EN messages (read-only reference).',
      },
      entries: preRaceTipsRef,
    },
    car_spec_text: {
      _meta: {
        count: carSpecRef.length,
        table_addr: '0x019114',
        mutable: false,
        description: '16 car spec text entries with car_name/engine/max_power (read-only, fixed-width).',
      },
      entries: carSpecRef,
    },
    race_quotes: {
      _meta: {
        count: raceQuotesRef.length,
        table_addr: '0x032f68',
        mutable: false,
        description: '15 race-result quotes (read-only; VDP packed-tilemap format, not injectable).',
      },
      entries: raceQuotesRef,
    },
    championship_intro: {
      _meta: {
        count: champIntroRef.length,
        table_addr: '0x03310a',
        mutable: false,
        description: '6 championship intro text lines (read-only; VDP packed-tilemap format).',
      },
      entries: champIntroRef,
    },
  };
}

// ---------------------------------------------------------------------------
// Binary dump helpers (TOOL-019)
// ---------------------------------------------------------------------------

/**
 * Compute the contiguous ROM region covering all strings in a mutable category.
 * Returns { start_addr, end_addr, size } covering from the first string address
 * to the end of the last string's encoded bytes.
 *
 * @param {object[]} entries — parsed entries with rom_addr and raw_bytes fields
 * @returns {{ start_addr: number, end_addr: number, size: number } | null}
 */
function computeStringRegion(entries) {
  const validEntries = entries.filter(e => e.rom_addr && e.note !== 'invalid_pointer');
  if (validEntries.length === 0) return null;

  // Collect unique addresses and their encoded lengths
  const addrLenMap = new Map();
  for (const e of validEntries) {
    if (e.shared) continue; // only count first occurrence
    const addr = parseInt(e.rom_addr, 16);
    const len = e.raw_bytes.length;
    if (!addrLenMap.has(addr) || addrLenMap.get(addr) < len) {
      addrLenMap.set(addr, len);
    }
  }

  const addrs = [...addrLenMap.keys()].sort((a, b) => a - b);
  const startAddr = addrs[0];
  const lastAddr = addrs[addrs.length - 1];
  const endAddr = lastAddr + addrLenMap.get(lastAddr);

  return { start_addr: startAddr, end_addr: endAddr, size: endAddr - startAddr };
}

/**
 * Dump the four mutable text categories as contiguous binary slices to dataDir.
 * Each category produces two files:
 *   <category>.bin       — raw ROM bytes for the contiguous string region
 *   <category>.meta.json — { start_addr, end_addr, size } for the injector
 *
 * The binary files under data/text/ serve as a stable backup layer: they
 * capture the exact bytes that inject_strings.js will patch.
 *
 * @param {Buffer|string} romOrPath — ROM buffer or path to ROM file
 * @param {string} dataDir          — destination directory (created if needed)
 * @param {boolean} verbose
 */
function dumpTextBinaries(romOrPath, dataDir, verbose = false) {
  const rom = Buffer.isBuffer(romOrPath) ? romOrPath : fs.readFileSync(romOrPath);
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

  const categories = [
    { name: 'team_names',             entries: extractTeamNames(rom) },
    { name: 'team_intro_messages',    entries: extractTeamIntroEN(rom) },
    { name: 'pre_race_rival_messages',entries: extractPreRaceRivalEN(rom) },
    { name: 'post_race_messages',     entries: extractPostRaceEN(rom) },
  ];

  for (const { name, entries } of categories) {
    const region = computeStringRegion(entries);
    if (!region) {
      if (verbose) process.stderr.write(`  Skipping ${name}: no valid string addresses\n`);
      continue;
    }

    const { start_addr, end_addr, size } = region;
    const slice = Buffer.from(rom.slice(start_addr, end_addr));
    const binFile  = path.join(dataDir, `${name}.bin`);
    const metaFile = path.join(dataDir, `${name}.meta.json`);

    fs.writeFileSync(binFile, slice);
    fs.writeFileSync(metaFile, JSON.stringify({
      category:   name,
      start_addr: '0x' + start_addr.toString(16).padStart(6, '0'),
      end_addr:   '0x' + end_addr.toString(16).padStart(6, '0'),
      size,
    }, null, 2));

    if (verbose) {
      process.stderr.write(
        `  Dumped ${name}.bin  (${size} bytes @ 0x${start_addr.toString(16).toUpperCase().padStart(6,'0')}–0x${end_addr.toString(16).toUpperCase().padStart(6,'0')})\n`
      );
    }
  }
}

/**
 * Verify that all text binary files in dataDir match the corresponding ROM bytes.
 * Returns an array of mismatch descriptors (empty = all match).
 *
 * @param {string} dataDir
 * @param {string|Buffer} romOrPath
 * @returns {{ category: string, start_addr: number, mismatches: number }[]}
 */
function verifyTextBinaries(dataDir, romOrPath) {
  const rom = Buffer.isBuffer(romOrPath) ? romOrPath : fs.readFileSync(romOrPath);
  const CATEGORIES = ['team_names', 'team_intro_messages', 'pre_race_rival_messages', 'post_race_messages'];
  const errors = [];

  for (const name of CATEGORIES) {
    const binFile  = path.join(dataDir, `${name}.bin`);
    const metaFile = path.join(dataDir, `${name}.meta.json`);
    if (!fs.existsSync(binFile) || !fs.existsSync(metaFile)) continue;

    const meta = JSON.parse(fs.readFileSync(metaFile, 'utf8'));
    const startAddr = parseInt(meta.start_addr, 16);
    const slice = fs.readFileSync(binFile);
    let mismatches = 0;
    for (let i = 0; i < slice.length; i++) {
      if (rom[startAddr + i] !== slice[i]) mismatches++;
    }
    if (mismatches > 0) errors.push({ category: name, start_addr: startAddr, mismatches });
  }
  return errors;
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

if (require.main === module) {
  const argv = process.argv.slice(2);
  let romPath = DEFAULT_ROM;
  let outPath = DEFAULT_OUT;
  let dumpDataDir = null;
  let verbose = false;

  for (let i = 0; i < argv.length; i++) {
    if ((argv[i] === '--rom' || argv[i] === '-r') && argv[i + 1]) romPath = argv[++i];
    else if ((argv[i] === '--out' || argv[i] === '-o') && argv[i + 1]) outPath = argv[++i];
    else if (argv[i] === '--dump-data-dir' && argv[i + 1]) dumpDataDir = argv[++i];
    else if (argv[i] === '--verbose' || argv[i] === '-v') verbose = true;
  }

  if (!fs.existsSync(romPath)) {
    process.stderr.write(`ERROR: ROM not found: ${romPath}\n`);
    process.exit(1);
  }

  if (dumpDataDir) {
    const resolvedDumpDir = path.resolve(REPO_ROOT, dumpDataDir);
    if (verbose) process.stderr.write(`Dumping text binaries to ${resolvedDumpDir} ...\n`);
    dumpTextBinaries(romPath, resolvedDumpDir, verbose);
    if (!verbose) console.log(`Dumped text binaries to ${resolvedDumpDir}`);
  } else {
    const data = extractStrings(romPath, verbose);

    const dir = path.dirname(outPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(data, null, 2) + '\n', 'utf8');

    const stats = data._meta.stats;
    if (verbose) {
      process.stderr.write(`Wrote ${outPath}\n`);
      process.stderr.write(`  team_names: ${stats.team_names}\n`);
      process.stderr.write(`  team_intro unique: ${stats.team_intro_unique_en}\n`);
      process.stderr.write(`  pre_race_rival unique: ${stats.pre_race_rival_unique_en}\n`);
      process.stderr.write(`  post_race unique: ${stats.post_race_unique_en}\n`);
    } else {
      console.log(`Wrote ${outPath}`);
    }
  }
}

module.exports = {
  extractStrings, parseEnString, CHAR_TO_TILE, TILE_TO_CHAR,
  dumpTextBinaries, verifyTextBinaries, computeStringRegion,
};
