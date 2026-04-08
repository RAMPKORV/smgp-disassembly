#!/usr/bin/env node
// tools/index/strings.js
//
// Build tools/index/strings.json: a machine-readable index of all text
// strings in the Super Monaco GP ROM.
//
// String encoding: custom tile-index encoding via the txt assembler macro.
//   Space = $32
//   '0'-'9' = $00-$09
//   'A'-'Z' = $0A-$23
//   '.'  = $29    ','  = $2A    '/' = $2B    '-' = $2C
//   '!'  = $2D    '?'  = $2E   '\''= $26     '"' = $27
//   '('  = $34    ')'  = $35
//   \n (escape) = $FC  (in-string newline / line break)
//
// Control bytes (not part of visible text):
//   $FA = column-advance / horizontal spacer (used in packed tilemap strings)
//   $FB = VDP tilemap address prefix (followed by 2-byte address)
//   $FD = single-line layout selector prefix
//   $FF = string terminator
//
// Japanese strings use a proprietary kana/kanji tile-index encoding.
// They are stored as raw bytes; this tool records them as hex_bytes only.
//
// Usage:
//   node tools/index/strings.js [--rom PATH] [--out PATH] [--verbose]
//
// Output: tools/index/strings.json

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_ROM = path.join(REPO_ROOT, 'orig.bin');
const DEFAULT_OUT = path.join(REPO_ROOT, 'tools', 'index', 'strings.json');

// ---------------------------------------------------------------------------
// Tile-to-char decoding table
// ---------------------------------------------------------------------------

const TILE_TO_CHAR = new Map([
  [0x32, ' '], [0x26, "'"], [0x27, '"'], [0x2E, '?'], [0x29, '.'],
  [0x2A, ','], [0x2B, '/'], [0x2C, '-'], [0x2D, '!'], [0x34, '('],
  [0x35, ')'], [0xFC, '\n'],
  [0xFA, '\u00b7'],  // middle-dot: represents column-advance control byte
  [0xFD, ''],        // layout selector: silent prefix, not part of visible text
]);
for (let i = 0; i < 10; i++) TILE_TO_CHAR.set(i, String(i));
for (let i = 0; i < 26; i++) TILE_TO_CHAR.set(0x0A + i, String.fromCharCode(65 + i));

// ---------------------------------------------------------------------------
// Decode helpers
// ---------------------------------------------------------------------------

/**
 * Decode an English (tile-index) string at addr, stopping at $FF.
 * Returns { str, byteLen }.
 * $FB (VDP prefix) bytes and their 2-byte address arguments are skipped.
 * Leading $E4/$E5/$28 VDP DMA preamble bytes are skipped.
 * @param {Buffer} rom
 * @param {number} addr
 * @returns {{ str: string, byteLen: number }}
 */
function decodeEn(rom, addr) {
  // Skip leading VDP DMA preamble bytes
  while (addr < rom.length && (rom[addr] === 0xE4 || rom[addr] === 0xE5 || rom[addr] === 0x28)) {
    addr++;
  }
  const start = addr;
  const chars = [];
  while (addr < rom.length) {
    const b = rom[addr];
    if (b === 0xFF) {
      addr++;
      break;
    } else if (b === 0xFB) {
      // VDP tilemap prefix: next 2 bytes are address, skip all 3
      addr += 3;
      continue;
    }
    const c = TILE_TO_CHAR.has(b) ? TILE_TO_CHAR.get(b) : `[${b.toString(16).toUpperCase().padStart(2, '0')}]`;
    chars.push(c);
    addr++;
  }
  return { str: chars.join(''), byteLen: addr - start };
}

/**
 * Decode a fixed-length English string. $FF within the string is treated as
 * a field separator (used in car spec text).
 * @param {Buffer} rom
 * @param {number} addr
 * @param {number} length
 * @returns {string}
 */
function decodeEnFixed(rom, addr, length) {
  const chars = [];
  for (let i = 0; i < length; i++) {
    const b = rom[addr + i];
    if (b === 0xFF) {
      chars.push('|');
    } else {
      const c = TILE_TO_CHAR.has(b) ? TILE_TO_CHAR.get(b) : `[${b.toString(16).toUpperCase().padStart(2, '0')}]`;
      chars.push(c);
    }
  }
  return chars.join('');
}

/**
 * Read a JP string as hex bytes until $FF.
 * @param {Buffer} rom
 * @param {number} addr
 * @returns {{ hexBytes: string[], byteLen: number }}
 */
function rawJp(rom, addr) {
  let i = 0;
  while (addr + i < rom.length && rom[addr + i] !== 0xFF) i++;
  const hexBytes = [];
  for (let j = 0; j < i; j++) {
    hexBytes.push('0x' + rom[addr + j].toString(16).padStart(2, '0'));
  }
  return { hexBytes, byteLen: i + 1 };
}

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

// ---------------------------------------------------------------------------
// Extractors by string category
// ---------------------------------------------------------------------------

const TEAM_NAMES = [
  'Madonna', 'Firenze', 'Millions', 'Bestowal', 'Blanche', 'Tyrant',
  'Losel', 'May', 'Bullets', 'Dardan', 'Linden', 'Minarae',
  'Rigel', 'Comet', 'Orchis', 'Zeroforce',
];

function extractTeamNames(rom) {
  const TABLE = 0x3B9A2;
  const records = [];
  for (let i = 0; i < 16; i++) {
    const jpPtr = readPtr(rom, TABLE + i * 4);
    const enPtr = readPtr(rom, TABLE + (i + 16) * 4);
    const { hexBytes: jpHex } = rawJp(rom, jpPtr);
    const { str: enStr } = decodeEn(rom, enPtr);
    records.push({
      id: i,
      team: TEAM_NAMES[i],
      rom_addr_jp: '0x' + jpPtr.toString(16).padStart(6, '0'),
      rom_addr_en: '0x' + enPtr.toString(16).padStart(6, '0'),
      jp_bytes: jpHex,
      en: enStr.trim(),
    });
  }
  return records;
}

function extractTrackNames(rom) {
  const TABLE = 0xC202;
  const TRACKS = [
    'San_Marino', 'Brazil', 'France', 'Hungary', 'West_Germany',
    'USA', 'Canada', 'Great_Britain', 'Italy', 'Portugal', 'Spain',
    'Mexico', 'Japan', 'Belgium', 'Australia', 'Monaco',
  ];
  const records = [];
  for (let i = 0; i < 16; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const { str: enStr } = decodeEn(rom, ptr);
    records.push({
      id: i,
      track: TRACKS[i],
      rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
      en: enStr.trim(),
    });
  }
  return records;
}

function extractCarSpecText(rom) {
  const TABLE = 0x19114;
  const records = [];
  for (let i = 0; i < 16; i++) {
    const off = TABLE + i * 0x12;
    const namePtr = readPtr(rom, off) + 1;
    const nameLen = readWord(rom, off + 4);
    const enginePtr = readPtr(rom, off + 6) + 1;
    const engineLen = readWord(rom, off + 10);
    const powerPtr = readPtr(rom, off + 12) + 1;
    const powerLen = readWord(rom, off + 16);
    records.push({
      id: i,
      team: TEAM_NAMES[i],
      car_name: {
        rom_addr: '0x' + namePtr.toString(16).padStart(6, '0'),
        len: nameLen,
        en: decodeEnFixed(rom, namePtr, nameLen).trim(),
      },
      engine: {
        rom_addr: '0x' + enginePtr.toString(16).padStart(6, '0'),
        len: engineLen,
        en: decodeEnFixed(rom, enginePtr, engineLen).trim(),
      },
      max_power: {
        rom_addr: '0x' + powerPtr.toString(16).padStart(6, '0'),
        len: powerLen,
        en: decodeEnFixed(rom, powerPtr, powerLen).trim(),
      },
    });
  }
  return records;
}

function extractDriverInfo(rom) {
  const TABLE = 0x193BE;
  const records = [];
  for (let i = 0; i < 17; i++) {
    const off = TABLE + i * 0x0C;
    const namePtr = readPtr(rom, off) + 1;
    const nameLen = readWord(rom, off + 4);
    const countryPtr = readPtr(rom, off + 6) + 1;
    const countryLen = readWord(rom, off + 10);
    records.push({
      id: i,
      name: {
        rom_addr: '0x' + namePtr.toString(16).padStart(6, '0'),
        len: nameLen,
        en: decodeEnFixed(rom, namePtr, nameLen).trim(),
      },
      country: {
        rom_addr: '0x' + countryPtr.toString(16).padStart(6, '0'),
        len: countryLen,
        en: decodeEnFixed(rom, countryPtr, countryLen).trim(),
      },
    });
  }
  return records;
}

function extractPreRaceRivalMsgs(rom) {
  const TABLE = 0x3A27A;
  const COUNT = 145;
  const records = [];
  for (let i = 0; i < COUNT; i++) {
    const jpPtr = readPtr(rom, TABLE + i * 4);
    const enPtr = readPtr(rom, TABLE + i * 4 + COUNT * 4);
    const { hexBytes: jpHex } = rawJp(rom, jpPtr);
    const { str: enStr } = decodeEn(rom, enPtr);
    records.push({
      id: i,
      rom_addr_jp: '0x' + jpPtr.toString(16).padStart(6, '0'),
      rom_addr_en: '0x' + enPtr.toString(16).padStart(6, '0'),
      jp_bytes: jpHex,
      en: enStr.trim(),
    });
  }
  return records;
}

function extractPreRaceTips(rom) {
  const TABLE = 0x3B524;
  const COUNT = 17;
  const TRACKS = [
    'partner_challenge',
    'San_Marino', 'Brazil', 'France', 'Hungary', 'West_Germany',
    'USA', 'Canada', 'Great_Britain', 'Italy', 'Portugal', 'Spain',
    'Mexico', 'Japan', 'Belgium', 'Australia', 'Monaco',
  ];
  const records = [];
  for (let i = 0; i < COUNT; i++) {
    const jpPtr = readPtr(rom, TABLE + i * 4);
    const enPtr = readPtr(rom, TABLE + i * 4 + COUNT * 4);
    const { hexBytes: jpHex } = rawJp(rom, jpPtr);
    const { str: enStr } = decodeEn(rom, enPtr);
    records.push({
      id: i,
      context: i < TRACKS.length ? TRACKS[i] : `track_${i}`,
      rom_addr_jp: '0x' + jpPtr.toString(16).padStart(6, '0'),
      rom_addr_en: '0x' + enPtr.toString(16).padStart(6, '0'),
      jp_bytes: jpHex,
      en: enStr.trim(),
    });
  }
  return records;
}

function extractTeamIntroMsgs(rom) {
  const TABLE = 0x3B07E;
  const records = [];
  const seenEn = new Set();
  const seenJp = new Set();
  for (let i = 0; i < 64; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const isJp = i < 32;
    let entry;
    if (isJp) {
      const { hexBytes: raw } = rawJp(rom, ptr);
      entry = {
        table_index: i,
        lang: 'jp',
        rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
        jp_bytes: raw,
      };
      if (seenJp.has(ptr)) entry.shared = true;
      else seenJp.add(ptr);
    } else {
      const { str: enStr } = decodeEn(rom, ptr);
      entry = {
        table_index: i,
        lang: 'en',
        rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
        en: enStr.trim(),
      };
      if (seenEn.has(ptr)) entry.shared = true;
      else seenEn.add(ptr);
    }
    records.push(entry);
  }
  return records;
}

function extractPostRaceMsgs(rom) {
  const TABLE = 0x3BB14;
  const COUNT_JP = 160;
  const COUNT_EN = 160;
  const jp = [];
  const en = [];
  for (let i = 0; i < COUNT_JP; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const { hexBytes: raw } = rawJp(rom, ptr);
    jp.push({
      index: i,
      team_id: Math.floor(i / 10),
      result_slot: i % 10,
      rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
      jp_bytes: raw,
    });
  }
  for (let i = 0; i < COUNT_EN; i++) {
    const ptr = readPtr(rom, TABLE + (COUNT_JP + i) * 4);
    const { str: enStr } = decodeEn(rom, ptr);
    en.push({
      index: i,
      team_id: Math.floor(i / 10),
      result_slot: i % 10,
      rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
      en: enStr.trim(),
    });
  }
  return { jp, en };
}

function extractRaceQuotes(rom) {
  const TABLE = 0x32F68;
  const COUNT = 15;
  const records = [];
  for (let i = 0; i < COUNT; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const { str: enStr } = decodeEn(rom, ptr);
    records.push({
      id: i + 1,
      rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
      en: enStr.trim(),
    });
  }
  return records;
}

function extractChampionshipIntro(rom) {
  const TABLE = 0x3310A;
  const COUNT = 6;
  const records = [];
  for (let i = 0; i < COUNT; i++) {
    const ptr = readPtr(rom, TABLE + i * 4);
    const { str: enStr } = decodeEn(rom, ptr);
    records.push({
      id: i + 1,
      rom_addr: '0x' + ptr.toString(16).padStart(6, '0'),
      en: enStr.trim(),
    });
  }
  return records;
}

function extractMenuItems(rom) {
  const MAIN_ADDR = 0x3170;
  const MAIN_ITEM_LEN = 18;
  const MAIN_COUNT = 4;
  const mainItems = [];
  for (let i = 0; i < MAIN_COUNT; i++) {
    const addr = MAIN_ADDR + i * MAIN_ITEM_LEN;
    mainItems.push({
      id: i,
      rom_addr: '0x' + addr.toString(16).padStart(6, '0'),
      en: decodeEnFixed(rom, addr, MAIN_ITEM_LEN).trim(),
    });
  }

  const NEWGAME_ADDR = 0x31B8;
  const NEWGAME_ITEM_LEN = 8;
  const NEWGAME_COUNT = 2;
  const newgameItems = [];
  for (let i = 0; i < NEWGAME_COUNT; i++) {
    const addr = NEWGAME_ADDR + i * NEWGAME_ITEM_LEN;
    newgameItems.push({
      id: i,
      rom_addr: '0x' + addr.toString(16).padStart(6, '0'),
      en: decodeEnFixed(rom, addr, NEWGAME_ITEM_LEN).trim(),
    });
  }

  const OPTIONS_ADDR = 0x31C8;
  const OPTIONS_LEN = 0x30;
  const optionsRaw = decodeEnFixed(rom, OPTIONS_ADDR, OPTIONS_LEN);

  const LAPS_ADDR = 0x31F8;
  const LAPS_ITEM_LEN = 4;
  const LAPS_COUNT = 4;
  const lapsItems = [];
  for (let i = 0; i < LAPS_COUNT; i++) {
    const addr = LAPS_ADDR + i * LAPS_ITEM_LEN;
    lapsItems.push({
      id: i,
      rom_addr: '0x' + addr.toString(16).padStart(6, '0'),
      en: decodeEnFixed(rom, addr, LAPS_ITEM_LEN).trim(),
    });
  }

  return {
    main: {
      rom_addr: '0x' + MAIN_ADDR.toString(16).padStart(6, '0'),
      item_len: MAIN_ITEM_LEN,
      items: mainItems,
    },
    new_game: {
      rom_addr: '0x' + NEWGAME_ADDR.toString(16).padStart(6, '0'),
      item_len: NEWGAME_ITEM_LEN,
      items: newgameItems,
    },
    options: {
      rom_addr: '0x' + OPTIONS_ADDR.toString(16).padStart(6, '0'),
      raw: optionsRaw,
      note: 'Fixed-width blob; items have variable lengths',
    },
    laps: {
      rom_addr: '0x' + LAPS_ADDR.toString(16).padStart(6, '0'),
      item_len: LAPS_ITEM_LEN,
      items: lapsItems,
    },
  };
}

// ---------------------------------------------------------------------------
// Main build function
// ---------------------------------------------------------------------------

/**
 * @param {string} romPath
 * @param {string} outPath
 * @param {boolean} verbose
 */
function buildStringsIndex(romPath, outPath, verbose) {
  const rom = fs.readFileSync(romPath);

  if (verbose) console.log('Extracting team names...');
  const teamNames = extractTeamNames(rom);

  if (verbose) console.log('Extracting track names...');
  const trackNames = extractTrackNames(rom);

  if (verbose) console.log('Extracting car spec text...');
  const carSpecText = extractCarSpecText(rom);

  if (verbose) console.log('Extracting driver info...');
  const driverInfo = extractDriverInfo(rom);

  if (verbose) console.log('Extracting pre-race rival messages...');
  const preRaceRival = extractPreRaceRivalMsgs(rom);

  if (verbose) console.log('Extracting pre-race track tips...');
  const preRaceTips = extractPreRaceTips(rom);

  if (verbose) console.log('Extracting team intro messages...');
  const teamIntro = extractTeamIntroMsgs(rom);

  if (verbose) console.log('Extracting post-race messages...');
  const postRace = extractPostRaceMsgs(rom);

  if (verbose) console.log('Extracting race quotes...');
  const raceQuotes = extractRaceQuotes(rom);

  if (verbose) console.log('Extracting championship intro text...');
  const champIntro = extractChampionshipIntro(rom);

  if (verbose) console.log('Extracting menu items...');
  const menuItems = extractMenuItems(rom);

  const index = {
    _meta: {
      description: (
        'All text strings in the Super Monaco GP ROM, indexed by category. ' +
        'English strings are decoded using the txt macro tile-index encoding. ' +
        'Japanese strings are stored as raw hex_bytes (proprietary kana/kanji tile encoding). ' +
        'Control bytes: $FA=col-advance, $FB=VDP-addr-prefix, $FC=newline, $FD=layout-selector, $FF=terminator.'
      ),
      encoding: {
        space: '0x32',
        digits_0_9: '0x00-0x09',
        A_Z: '0x0A-0x23',
        special: {
          '0x26': "'",
          '0x27': '"',
          '0x29': '.',
          '0x2A': ',',
          '0x2B': '/',
          '0x2C': '-',
          '0x2D': '!',
          '0x2E': '?',
          '0x34': '(',
          '0x35': ')',
        },
        control: {
          '0xFA': 'col_advance',
          '0xFB': 'vdp_addr_prefix',
          '0xFC': 'newline',
          '0xFD': 'layout_selector',
          '0xFF': 'terminator',
        },
      },
      rom: path.basename(romPath),
      string_categories: [
        'team_names', 'track_names', 'car_spec_text', 'driver_info',
        'pre_race_rival_messages', 'pre_race_track_tips',
        'team_intro_messages', 'post_race_messages',
        'race_quotes', 'championship_intro', 'menu_items',
      ],
    },
    team_names: {
      _meta: {
        count: teamNames.length,
        table_addr: '0x03b9a2',
        description: (
          '16 team names in EN and JP. ' +
          'Table: Team_name_strings_table (32 dc.l pointers; JP=0-15, EN=16-31).'
        ),
      },
      entries: teamNames,
    },
    track_names: {
      _meta: {
        count: trackNames.length,
        table_addr: '0x00c202',
        description: (
          '16 championship track names in packed-tilemap format. ' +
          'Table: Track_name_tilemap_ptrs (16 dc.l pointers). ' +
          'Strings use $FA as column-advance/space separator between words.'
        ),
      },
      entries: trackNames,
    },
    car_spec_text: {
      _meta: {
        count: carSpecText.length,
        table_addr: '0x019114',
        description: (
          '16 cars x (car_name, engine, max_power) text strings. ' +
          'Table: Car_spec_text_table (16 x 3 records, stride 0x12 bytes). ' +
          'Pointers are label-1 style (add 1 to get actual string address). ' +
          'Lengths are explicit byte counts (no $FF terminator used by renderer).'
        ),
      },
      entries: carSpecText,
    },
    driver_info: {
      _meta: {
        count: driverInfo.length,
        table_addr: '0x0193be',
        description: (
          '17 drivers (16 AI + YOU) with name and country strings. ' +
          'Table: Driver_info_table (18 records, stride 0x0C bytes; index 17 is a sentinel). ' +
          'Pointers are label-1 style. Lengths are explicit byte counts.'
        ),
      },
      entries: driverInfo,
    },
    pre_race_rival_messages: {
      _meta: {
        count: preRaceRival.length,
        table_addr: '0x03a27a',
        description: (
          '145 pre-race rival challenge messages in JP and EN. ' +
          'Table: Team_msg_jp_table (290 dc.l pointers; JP=0-144, EN=145-289). ' +
          'Index 0 = error sentinel. Indexed by rival team and context. ' +
          '$FD prefix = single-line layout selector (message fits on one display line).'
        ),
      },
      entries: preRaceRival,
    },
    pre_race_track_tips: {
      _meta: {
        count: preRaceTips.length,
        table_addr: '0x03b524',
        description: (
          '17 pre-race track tip messages in JP and EN. ' +
          'Table: TeamMessagesBeforeRace (34 dc.l pointers; JP=0-16, EN=17-33). ' +
          'Index 0 = partner challenge text (team name inserted by engine at runtime). ' +
          'Indices 1-16 = per-track tips in championship order.'
        ),
      },
      entries: preRaceTips,
    },
    team_intro_messages: {
      _meta: {
        count: teamIntro.length,
        table_addr: '0x03b07e',
        description: (
          '64 team intro messages (shown when signing contract). ' +
          'Table: Team_intro_table (64 dc.l pointers; JP=0-31, EN=32-63). ' +
          'Some JP and EN indices share the same pointer (duplicate content). ' +
          'EN strings span 14 unique messages mapped to 16 teams via the table.'
        ),
      },
      entries: teamIntro,
    },
    post_race_messages: {
      _meta: {
        jp_count: postRace.jp.length,
        en_count: postRace.en.length,
        table_addr: '0x03bb14',
        description: (
          '320 post-race team messages (160 JP + 160 EN). ' +
          'Table: Team_msg_after_race_table (320 dc.l pointers). ' +
          'Indexing: jp_index = team_id * 10 + result_slot; en_index = jp_index + 160. ' +
          'result_slot 0-9 maps to race result contexts (win/lose/promotion/etc.).'
        ),
      },
      jp: postRace.jp,
      en: postRace.en,
    },
    race_quotes: {
      _meta: {
        count: raceQuotes.length,
        table_addr: '0x032f68',
        description: (
          '15 race-result quotes shown on results/podium screens. ' +
          'Table: Race_quotes_table (15 dc.l pointers). ' +
          'Strings use $FB VDP-prefix + $FA col-advance in packed tilemap format.'
        ),
      },
      entries: raceQuotes,
    },
    championship_intro: {
      _meta: {
        count: champIntro.length,
        table_addr: '0x033110',
        description: (
          '6 championship intro text lines shown before season starts. ' +
          'Table: Championship_intro_text_table (6 dc.l pointers). ' +
          'Strings use $FB VDP-prefix + $FA col-advance in packed tilemap format.'
        ),
      },
      entries: champIntro,
    },
    menu_items: {
      _meta: {
        description: (
          'Title screen and sub-menu text items. ' +
          'These are flat byte arrays (no pointer table, fixed-width items). ' +
          'Labels: Title_menu_items_main/newgame/options/laps.'
        ),
      },
      ...menuItems,
    },
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(index, null, 2), 'utf8');

  const totalStrings = (
    teamNames.length * 2 +
    trackNames.length +
    carSpecText.length * 3 +
    driverInfo.length * 2 +
    preRaceRival.length * 2 +
    preRaceTips.length * 2 +
    teamIntro.length +
    postRace.jp.length + postRace.en.length +
    raceQuotes.length +
    champIntro.length
  );

  if (verbose) {
    console.log(`Wrote ${outPath}`);
    console.log(`Total string entries: ${totalStrings}`);
  }

  return index;
}

// ---------------------------------------------------------------------------
// Arg parsing and main
// ---------------------------------------------------------------------------

if (require.main === module) {
  const argv = process.argv.slice(2);
  let romPath = DEFAULT_ROM;
  let outPath = DEFAULT_OUT;
  let verbose = false;

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--rom' && argv[i + 1]) romPath = argv[++i];
    else if (argv[i] === '--out' && argv[i + 1]) outPath = argv[++i];
    else if (argv[i] === '--verbose' || argv[i] === '-v') verbose = true;
  }

  if (!fs.existsSync(romPath)) {
    console.error(`ERROR: ROM not found: ${romPath}`);
    process.exit(1);
  }

  buildStringsIndex(romPath, outPath, verbose);
  if (!verbose) console.log(`Wrote ${outPath}`);
}

module.exports = { buildStringsIndex };
