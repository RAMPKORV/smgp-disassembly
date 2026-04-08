#!/usr/bin/env node
// tools/extract_championship_data.js
//
// EXTR-006 (JS port): Championship/progression data extractor
//                     orig.bin ROM addresses -> tools/data/championship.json
//
// Reads all championship progression tables directly from the ROM binary at
// their known ROM addresses and emits a structured JSON file at
// tools/data/championship.json.
//
// Tables extracted:
//   PointsAwardedPerPlacement      0x0132EA   6 bytes  (6 placement scores)
//   Post_race_driver_target_points 0x00F736  32 bytes  (16 teams x 2 thresholds)
//   Ai_performance_factor_by_team  0x0132F0  16 bytes  (16 multipliers)
//   Ai_performance_table           0x013300 128 bytes  (16 teams x 8 entries)
//   InitialDriversAndTeamMap       0x013380  18 bytes  (year-1 driver lineup)
//   SecondYearDriversAndTeamsMap   0x013392  18 bytes  (year-2 driver lineup)
//   Rival_grid_base_table          0x004126  16 bytes  (per-team rival grid base)
//   Rival_grid_delta_table         0x004136  11 bytes  (rival grid delta offsets)
//   Ai_placement_data              0x004141  76 bytes  (normal AI placement)
//   Ai_placement_data_easy         0x00418D  81 bytes  (easy AI placement)
//   Ai_placement_data_champ        0x0041DE  128 bytes (champ AI placement)
//   Ai_placement_champ_offsets     0x00425E  64 bytes  (per-track champ offsets)
//   Pre_race_lap_time_offset_table 0x00473C  32 bytes  (lap time offset table)
//
// Usage:
//   node tools/extract_championship_data.js [--rom orig.bin]
//                                            [--out tools/data/championship.json]
//                                            [-v]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT, DEFAULT_ROM_PATH } = require('./lib/rom');
const { readU8, readS8, readU16BE } = require('./lib/binary');

// ---------------------------------------------------------------------------
// ROM addresses (verified from smgp.lst)
// ---------------------------------------------------------------------------
const ROM_ADDR = {
  PointsAwardedPerPlacement:        0x0132EA,
  Post_race_driver_target_points:   0x00F736,
  Ai_performance_factor_by_team:    0x0132F0,
  Ai_performance_table:             0x013300,
  InitialDriversAndTeamMap:         0x013380,
  SecondYearDriversAndTeamsMap:     0x013392,
  Rival_grid_base_table:            0x004126,
  Rival_grid_delta_table:           0x004136,
  Ai_placement_data:                0x004141,
  Ai_placement_data_easy:           0x00418D,
  Ai_placement_data_champ:          0x0041DE,
  Ai_placement_champ_offsets:       0x00425E,
  Pre_race_lap_time_offset_table:   0x00473C,
};

const TABLE_SIZES = {
  PointsAwardedPerPlacement:        6,
  Post_race_driver_target_points:   32,
  Ai_performance_factor_by_team:    16,
  Ai_performance_table:             128,
  InitialDriversAndTeamMap:         18,
  SecondYearDriversAndTeamsMap:     18,
  Rival_grid_base_table:            16,
  Rival_grid_delta_table:           11,
  Ai_placement_data:                76,
  Ai_placement_data_easy:           81,
  Ai_placement_data_champ:          128,
  Ai_placement_champ_offsets:       64,
  Pre_race_lap_time_offset_table:   32,
};

// Championship track order (Track_data indices 0-15)
const CHAMPIONSHIP_TRACK_ORDER = [
  'San Marino', 'Brazil', 'France', 'Hungary', 'West Germany', 'USA',
  'Canada', 'Great Britain', 'Italy', 'Portugal', 'Spain', 'Mexico',
  'Japan', 'Belgium', 'Australia', 'Monaco',
];

const TEAM_NAMES = [
  'Madonna', 'Firenze', 'Millions', 'Bestowal', 'Blanche', 'Tyrant',
  'Losel', 'May', 'Bullets', 'Dardan', 'Linden', 'Minarae',
  'Rigel', 'Comet', 'Orchis', 'Zero Force',
];

// ---------------------------------------------------------------------------
// Extractors
// ---------------------------------------------------------------------------

function extractPointsAwarded(rom) {
  const base = ROM_ADDR.PointsAwardedPerPlacement;
  const result = [];
  for (let i = 0; i < 6; i++) result.push(readU8(rom, base + i));
  return result;
}

function extractPostRaceThresholds(rom) {
  const base = ROM_ADDR.Post_race_driver_target_points;
  return TEAM_NAMES.map((name, i) => ({
    team: i,
    name,
    promote_threshold: readU8(rom, base + i * 2),
    partner_threshold: readU8(rom, base + i * 2 + 1),
  }));
}

function extractAiPerformanceFactors(rom) {
  const base = ROM_ADDR.Ai_performance_factor_by_team;
  const result = [];
  for (let i = 0; i < 16; i++) result.push(readU8(rom, base + i));
  return result;
}

function extractAiPerformanceTable(rom) {
  const base = ROM_ADDR.Ai_performance_table;
  return TEAM_NAMES.map((name, i) => {
    const scores = [];
    for (let j = 0; j < 8; j++) scores.push(readU8(rom, base + i * 8 + j));
    return { team: i, name, scores };
  });
}

function extractDriverMap(rom, label) {
  const base = ROM_ADDR[label];
  const playerTeamRaw = readU8(rom, base);
  const driverTeamMap = [];
  for (let i = 0; i < 16; i++) driverTeamMap.push(readU8(rom, base + 1 + i));
  const rivalTeamRaw = readU8(rom, base + 17);
  return {
    player_team_raw: playerTeamRaw,
    driver_team_map: driverTeamMap,
    rival_team_raw:  rivalTeamRaw,
  };
}

function extractRivalGridBase(rom) {
  const base = ROM_ADDR.Rival_grid_base_table;
  const result = [];
  for (let i = 0; i < 16; i++) result.push(readU8(rom, base + i));
  return result;
}

function extractRivalGridDelta(rom) {
  const base = ROM_ADDR.Rival_grid_delta_table;
  const result = [];
  for (let i = 0; i < 11; i++) result.push(readS8(rom, base + i));
  return result;
}

function extractAiPlacementData(rom) {
  const base = ROM_ADDR.Ai_placement_data;
  const cars = [];
  for (let i = 0; i < 15; i++) {
    const off = base + i * 5;
    cars.push({
      speed_hi: readU8(rom, off),
      speed_lo: readU8(rom, off + 1),
      accel_hi: readU8(rom, off + 2),
      accel_lo: readU8(rom, off + 3),
      brake:    readU8(rom, off + 4),
    });
  }
  const sentinel = readU8(rom, base + 75);
  return { cars, sentinel };
}

function extractAiPlacementDataEasy(rom) {
  const base = ROM_ADDR.Ai_placement_data_easy;
  const headerRecord = {
    speed_hi: readU8(rom, base),
    speed_lo: readU8(rom, base + 1),
    accel_hi: readU8(rom, base + 2),
    accel_lo: readU8(rom, base + 3),
    brake:    readU8(rom, base + 4),
  };
  const cars = [];
  for (let i = 0; i < 15; i++) {
    const off = base + 5 + i * 5;
    cars.push({
      speed_hi: readU8(rom, off),
      speed_lo: readU8(rom, off + 1),
      accel_hi: readU8(rom, off + 2),
      accel_lo: readU8(rom, off + 3),
      brake:    readU8(rom, off + 4),
    });
  }
  const sentinel = readU8(rom, base + 80);
  return { header_record: headerRecord, cars, sentinel };
}

function extractAiPlacementDataChamp(rom) {
  const base = ROM_ADDR.Ai_placement_data_champ;
  const records = [];
  for (let i = 0; i < 16; i++) {
    const off = base + i * 5;
    records.push({
      speed_hi: readU8(rom, off),
      speed_lo: readU8(rom, off + 1),
      accel_hi: readU8(rom, off + 2),
      accel_lo: readU8(rom, off + 3),
      brake:    readU8(rom, off + 4),
    });
  }
  // 24 trailing dc.w values = 48 raw bytes (group1: 8 words at +80; group2: 16 words at +96)
  const trailingWordsRaw = Array.from(rom.slice(base + 80, base + 128));
  return { records, trailing_words_raw: trailingWordsRaw };
}

function extractAiPlacementChampOffsets(rom) {
  const base = ROM_ADDR.Ai_placement_champ_offsets;
  const pairs = [];
  for (let i = 0; i < 32; i++) {
    pairs.push([readS8(rom, base + i * 2), readS8(rom, base + i * 2 + 1)]);
  }
  return pairs;
}

function extractPreRaceLapTimeOffsets(rom) {
  const base = ROM_ADDR.Pre_race_lap_time_offset_table;
  return Array.from(rom.slice(base, base + TABLE_SIZES.Pre_race_lap_time_offset_table));
}

// ---------------------------------------------------------------------------
// Binary dump helpers (TOOL-019)
// ---------------------------------------------------------------------------

/**
 * Dump all 13 championship tables as individual .bin files to dataDir.
 * Each file is named after its table key, e.g. "PointsAwardedPerPlacement.bin".
 * This is the binary backup layer that lives under data/championship/.
 *
 * @param {Buffer|string} romOrPath — ROM buffer or path to ROM file
 * @param {string} dataDir          — destination directory (created if needed)
 * @param {boolean} verbose
 */
function dumpChampionshipBinaries(romOrPath, dataDir, verbose = false) {
  const rom = Buffer.isBuffer(romOrPath) ? romOrPath : fs.readFileSync(romOrPath);
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

  for (const [key, addr] of Object.entries(ROM_ADDR)) {
    const size = TABLE_SIZES[key];
    const slice = Buffer.from(rom.slice(addr, addr + size));
    const outFile = path.join(dataDir, `${key}.bin`);
    fs.writeFileSync(outFile, slice);
    if (verbose) info(`  Dumped ${key}.bin  (${size} bytes @ 0x${addr.toString(16).toUpperCase().padStart(6,'0')})`);
  }
}

// ---------------------------------------------------------------------------
// Main extractor
// ---------------------------------------------------------------------------

function extractChampionshipData(romPath, outPath, verbose) {
  if (verbose) info(`Reading ROM: ${romPath}`);
  const rom = fs.readFileSync(romPath);

  const data = {
    _meta: {
      source: 'extract_championship_data.js (EXTR-006)',
      rom: path.basename(romPath),
      description:
        'Championship progression tables: points, AI placement, ' +
        'rival grid, driver maps, lap-time offsets.',
      championship_track_order: CHAMPIONSHIP_TRACK_ORDER,
      team_names: TEAM_NAMES,
    },
    points_awarded_per_placement:    extractPointsAwarded(rom),
    post_race_driver_target_points:  extractPostRaceThresholds(rom),
    ai_performance_factor_by_team:   extractAiPerformanceFactors(rom),
    ai_performance_table:            extractAiPerformanceTable(rom),
    initial_drivers_and_team_map:    extractDriverMap(rom, 'InitialDriversAndTeamMap'),
    second_year_drivers_and_teams_map: extractDriverMap(rom, 'SecondYearDriversAndTeamsMap'),
    rival_grid_base_table:           extractRivalGridBase(rom),
    rival_grid_delta_table:          extractRivalGridDelta(rom),
    ai_placement_data:               extractAiPlacementData(rom),
    ai_placement_data_easy:          extractAiPlacementDataEasy(rom),
    ai_placement_data_champ:         extractAiPlacementDataChamp(rom),
    ai_placement_champ_offsets:      extractAiPlacementChampOffsets(rom),
    pre_race_lap_time_offset_table:  extractPreRaceLapTimeOffsets(rom),
  };

  const outDir = path.dirname(outPath);
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(data, null, 2), 'utf8');
  if (verbose) info(`Wrote: ${outPath}`);

  return data;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--verbose', '-v'],
    options: ['--rom', '--out', '--dump-data-dir'],
  });
  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const romArg  = args.options['--rom'] || 'orig.bin';
  const outArg  = args.options['--out'] || 'tools/data/championship.json';
  const dumpDir = args.options['--dump-data-dir'];

  const romPath = path.resolve(REPO_ROOT, romArg);
  const outPath = path.resolve(REPO_ROOT, outArg);

  if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

  if (dumpDir) {
    const resolvedDumpDir = path.resolve(REPO_ROOT, dumpDir);
    info(`Dumping championship binaries to ${resolvedDumpDir} ...`);
    dumpChampionshipBinaries(romPath, resolvedDumpDir, verbose);
    info('Done.');
  } else {
    info(`Extracting championship data from ${romPath} ...`);
    extractChampionshipData(romPath, outPath, verbose);
    info(`Wrote: ${outPath}`);
    info('Done.');
  }
}

module.exports = { extractChampionshipData, dumpChampionshipBinaries, ROM_ADDR, TABLE_SIZES };
