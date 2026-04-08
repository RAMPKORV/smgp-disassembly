#!/usr/bin/env node
// tools/inject_championship_data.js
//
// EXTR-006 (JS port): Championship/progression data injector
//                     tools/data/championship.json -> ROM binary patch
//
// Reads tools/data/championship.json (produced by extract_championship_data.js
// or a championship editor) and patches a ROM binary (default: out.bin)
// in-place at the known ROM addresses for all championship tables.
//
// Usage:
//   node tools/inject_championship_data.js [--input tools/data/championship.json]
//                                           [--rom out.bin]
//                                           [--dry-run]
//                                           [-v]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT, DEFAULT_OUT_PATH } = require('./lib/rom');
const { writeU8, writeS8 } = require('./lib/binary');

// ---------------------------------------------------------------------------
// ROM addresses (must match extract_championship_data.js)
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

// ---------------------------------------------------------------------------
// Table injectors — each returns [addr, bytesWritten]
// ---------------------------------------------------------------------------

function injectPointsAwarded(buf, data) {
  const addr = ROM_ADDR.PointsAwardedPerPlacement;
  const values = data.points_awarded_per_placement;
  if (values.length !== 6)
    throw new Error(`points_awarded_per_placement: expected 6 entries, got ${values.length}`);
  for (let i = 0; i < 6; i++) writeU8(buf, addr + i, values[i]);
  return [addr, 6];
}

function injectPostRaceDriverTargetPoints(buf, data) {
  const addr = ROM_ADDR.Post_race_driver_target_points;
  const entries = data.post_race_driver_target_points;
  if (entries.length !== 16)
    throw new Error(`post_race_driver_target_points: expected 16 entries, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    writeU8(buf, addr + i * 2,     entries[i].promote_threshold);
    writeU8(buf, addr + i * 2 + 1, entries[i].partner_threshold);
  }
  return [addr, 32];
}

function injectAiPerformanceFactor(buf, data) {
  const addr = ROM_ADDR.Ai_performance_factor_by_team;
  const values = data.ai_performance_factor_by_team;
  if (values.length !== 16)
    throw new Error(`ai_performance_factor_by_team: expected 16 entries, got ${values.length}`);
  for (let i = 0; i < 16; i++) writeU8(buf, addr + i, values[i]);
  return [addr, 16];
}

function injectAiPerformanceTable(buf, data) {
  const addr = ROM_ADDR.Ai_performance_table;
  const entries = data.ai_performance_table;
  if (entries.length !== 16)
    throw new Error(`ai_performance_table: expected 16 entries, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    const scores = entries[i].scores;
    if (scores.length !== 8)
      throw new Error(`ai_performance_table[${i}].scores: expected 8 bytes, got ${scores.length}`);
    for (let j = 0; j < 8; j++) writeU8(buf, addr + i * 8 + j, scores[j]);
  }
  return [addr, 128];
}

function injectDriverMap(buf, data, key, label) {
  const addr = ROM_ADDR[label];
  const entry = data[key];
  writeU8(buf, addr, entry.player_team_raw);
  const driverMap = entry.driver_team_map;
  if (driverMap.length !== 16)
    throw new Error(`${key}.driver_team_map: expected 16 entries, got ${driverMap.length}`);
  for (let i = 0; i < 16; i++) writeU8(buf, addr + 1 + i, driverMap[i]);
  writeU8(buf, addr + 17, entry.rival_team_raw);
  return [addr, 18];
}

function injectRivalGridBase(buf, data) {
  const addr = ROM_ADDR.Rival_grid_base_table;
  const values = data.rival_grid_base_table;
  if (values.length !== 16)
    throw new Error(`rival_grid_base_table: expected 16 entries, got ${values.length}`);
  for (let i = 0; i < 16; i++) writeU8(buf, addr + i, values[i]);
  return [addr, 16];
}

function injectRivalGridDelta(buf, data) {
  const addr = ROM_ADDR.Rival_grid_delta_table;
  const values = data.rival_grid_delta_table;
  if (values.length !== 11)
    throw new Error(`rival_grid_delta_table: expected 11 entries, got ${values.length}`);
  for (let i = 0; i < 11; i++) writeS8(buf, addr + i, values[i]);
  return [addr, 11];
}

function injectAiPlacementData(buf, data) {
  const addr = ROM_ADDR.Ai_placement_data;
  const entry = data.ai_placement_data;
  const cars = entry.cars;
  if (cars.length !== 15)
    throw new Error(`ai_placement_data.cars: expected 15 entries, got ${cars.length}`);
  for (let i = 0; i < 15; i++) {
    const base = addr + i * 5;
    writeU8(buf, base,     cars[i].speed_hi);
    writeU8(buf, base + 1, cars[i].speed_lo);
    writeU8(buf, base + 2, cars[i].accel_hi);
    writeU8(buf, base + 3, cars[i].accel_lo);
    writeU8(buf, base + 4, cars[i].brake);
  }
  writeU8(buf, addr + 75, entry.sentinel);
  return [addr, 76];
}

function injectAiPlacementDataEasy(buf, data) {
  const addr = ROM_ADDR.Ai_placement_data_easy;
  const entry = data.ai_placement_data_easy;
  const hdr = entry.header_record;
  writeU8(buf, addr,     hdr.speed_hi);
  writeU8(buf, addr + 1, hdr.speed_lo);
  writeU8(buf, addr + 2, hdr.accel_hi);
  writeU8(buf, addr + 3, hdr.accel_lo);
  writeU8(buf, addr + 4, hdr.brake);
  const cars = entry.cars;
  if (cars.length !== 15)
    throw new Error(`ai_placement_data_easy.cars: expected 15 entries, got ${cars.length}`);
  for (let i = 0; i < 15; i++) {
    const base = addr + 5 + i * 5;
    writeU8(buf, base,     cars[i].speed_hi);
    writeU8(buf, base + 1, cars[i].speed_lo);
    writeU8(buf, base + 2, cars[i].accel_hi);
    writeU8(buf, base + 3, cars[i].accel_lo);
    writeU8(buf, base + 4, cars[i].brake);
  }
  writeU8(buf, addr + 80, entry.sentinel);
  return [addr, 81];
}

function injectAiPlacementDataChamp(buf, data) {
  const addr = ROM_ADDR.Ai_placement_data_champ;
  const entry = data.ai_placement_data_champ;
  const records = entry.records;
  if (records.length !== 16)
    throw new Error(`ai_placement_data_champ.records: expected 16 entries, got ${records.length}`);
  for (let i = 0; i < 16; i++) {
    const base = addr + i * 5;
    writeU8(buf, base,     records[i].speed_hi);
    writeU8(buf, base + 1, records[i].speed_lo);
    writeU8(buf, base + 2, records[i].accel_hi);
    writeU8(buf, base + 3, records[i].accel_lo);
    writeU8(buf, base + 4, records[i].brake);
  }
  // Trailing 48 raw bytes (group1: 8 words at offset +80; group2: 16 words at offset +96)
  const trailing = entry.trailing_words_raw;
  if (trailing.length !== 48)
    throw new Error(`ai_placement_data_champ.trailing_words_raw: expected 48 bytes, got ${trailing.length}`);
  for (let i = 0; i < 48; i++) writeU8(buf, addr + 80 + i, trailing[i]);
  return [addr, 128];
}

function injectAiPlacementChampOffsets(buf, data) {
  const addr = ROM_ADDR.Ai_placement_champ_offsets;
  const pairs = data.ai_placement_champ_offsets;
  if (pairs.length !== 32)
    throw new Error(`ai_placement_champ_offsets: expected 32 pairs, got ${pairs.length}`);
  for (let i = 0; i < 32; i++) {
    if (pairs[i].length !== 2)
      throw new Error(`ai_placement_champ_offsets[${i}]: expected 2 values, got ${pairs[i].length}`);
    writeS8(buf, addr + i * 2,     pairs[i][0]);
    writeS8(buf, addr + i * 2 + 1, pairs[i][1]);
  }
  return [addr, 64];
}

function injectPreRaceLapTimeOffsets(buf, data) {
  const addr = ROM_ADDR.Pre_race_lap_time_offset_table;
  const raw = data.pre_race_lap_time_offset_table;
  if (raw.length !== 32)
    throw new Error(`pre_race_lap_time_offset_table: expected 32 bytes, got ${raw.length}`);
  for (let i = 0; i < 32; i++) writeU8(buf, addr + i, raw[i]);
  return [addr, 32];
}

// ---------------------------------------------------------------------------
// Main injector
// ---------------------------------------------------------------------------

function injectChampionshipData(jsonPath, romPath, dryRun = false, verbose = false) {
  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const original = fs.readFileSync(romPath);
  const buf = Buffer.from(original);

  const injectors = [
    ['PointsAwardedPerPlacement',      (b, d) => injectPointsAwarded(b, d)],
    ['Post_race_driver_target_points', (b, d) => injectPostRaceDriverTargetPoints(b, d)],
    ['Ai_performance_factor_by_team',  (b, d) => injectAiPerformanceFactor(b, d)],
    ['Ai_performance_table',           (b, d) => injectAiPerformanceTable(b, d)],
    ['InitialDriversAndTeamMap',       (b, d) => injectDriverMap(b, d, 'initial_drivers_and_team_map', 'InitialDriversAndTeamMap')],
    ['SecondYearDriversAndTeamsMap',   (b, d) => injectDriverMap(b, d, 'second_year_drivers_and_teams_map', 'SecondYearDriversAndTeamsMap')],
    ['Rival_grid_base_table',          (b, d) => injectRivalGridBase(b, d)],
    ['Rival_grid_delta_table',         (b, d) => injectRivalGridDelta(b, d)],
    ['Ai_placement_data',              (b, d) => injectAiPlacementData(b, d)],
    ['Ai_placement_data_easy',         (b, d) => injectAiPlacementDataEasy(b, d)],
    ['Ai_placement_data_champ',        (b, d) => injectAiPlacementDataChamp(b, d)],
    ['Ai_placement_champ_offsets',     (b, d) => injectAiPlacementChampOffsets(b, d)],
    ['Pre_race_lap_time_offset_table', (b, d) => injectPreRaceLapTimeOffsets(b, d)],
  ];

  let totalChanged = 0;
  for (const [label, fn] of injectors) {
    const [addr, n] = fn(buf, data);
    let changed = 0;
    for (let i = 0; i < n; i++) {
      if (original[addr + i] !== buf[addr + i]) changed++;
    }
    totalChanged += changed;
    if (verbose) {
      const status = changed > 0 ? `${String(changed).padStart(3)} bytes changed` : '  (no change)    ';
      info(`  0x${addr.toString(16).toUpperCase().padStart(6, '0')}  ${String(n).padStart(4)} bytes  ${status}  ${label}`);
    }
  }

  if (verbose) info(`  Total bytes changed: ${totalChanged}`);

  if (dryRun) {
    if (verbose) info('  (dry-run: ROM not written)');
    return totalChanged;
  }

  fs.writeFileSync(romPath, buf);
  if (verbose) info(`  Written: ${romPath}`);
  return totalChanged;
}

// ---------------------------------------------------------------------------
// Binary layer helpers (TOOL-019)
// ---------------------------------------------------------------------------

/**
 * Load all 13 championship tables from .bin files in dataDir.
 * Returns a Map<string, Buffer> keyed by table name.
 * Throws if any expected .bin file is missing.
 *
 * @param {string} dataDir — directory containing <TableName>.bin files
 * @returns {Map<string, Buffer>}
 */
function loadChampionshipBinaries(dataDir) {
  const result = new Map();
  for (const [key, size] of Object.entries(TABLE_SIZES)) {
    const binFile = path.join(dataDir, `${key}.bin`);
    if (!fs.existsSync(binFile))
      throw new Error(`Missing championship binary: ${binFile}`);
    const buf = fs.readFileSync(binFile);
    if (buf.length !== size)
      throw new Error(`${key}.bin: expected ${size} bytes, got ${buf.length}`);
    result.set(key, buf);
  }
  return result;
}

/**
 * Verify that all championship .bin files in dataDir match the corresponding
 * bytes in the ROM buffer.  Returns an array of mismatch descriptors
 * (empty array = all match).
 *
 * @param {string} dataDir
 * @param {string|Buffer} romOrPath
 * @returns {{ key: string, addr: number, size: number, mismatches: number }[]}
 */
function verifyChampionshipBinaries(dataDir, romOrPath) {
  const rom = Buffer.isBuffer(romOrPath) ? romOrPath : fs.readFileSync(romOrPath);
  const bins = loadChampionshipBinaries(dataDir);
  const errors = [];
  for (const [key, buf] of bins) {
    const addr = ROM_ADDR[key];
    const size = TABLE_SIZES[key];
    let mismatches = 0;
    for (let i = 0; i < size; i++) {
      if (rom[addr + i] !== buf[i]) mismatches++;
    }
    if (mismatches > 0) errors.push({ key, addr, size, mismatches });
  }
  return errors;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--verbose', '-v', '--dry-run'],
    options: ['--input', '--rom'],
  });
  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const dryRun  = args.flags['--dry-run'];
  const jsonArg = args.options['--input'] || 'tools/data/championship.json';
  const romArg  = args.options['--rom']   || 'out.bin';

  const jsonPath = path.resolve(REPO_ROOT, jsonArg);
  const romPath  = path.resolve(REPO_ROOT, romArg);

  if (!fs.existsSync(jsonPath)) die(`JSON not found: ${jsonPath}`);
  if (!fs.existsSync(romPath))  die(`ROM not found: ${romPath}`);

  info(`Injecting championship data from ${jsonPath} into ${romPath} ...`);
  const changed = injectChampionshipData(jsonPath, romPath, dryRun, verbose);

  if (dryRun) {
    info(`Dry-run: ${changed} bytes would change.`);
  } else if (changed === 0) {
    info('No-op: 0 bytes changed (round-trip is bit-identical).');
  } else {
    info(`Injected: ${changed} bytes changed.`);
  }
}

module.exports = { injectChampionshipData, loadChampionshipBinaries, verifyChampionshipBinaries, ROM_ADDR, TABLE_SIZES };
