#!/usr/bin/env node
// tools/inject_team_data.js
//
// EXTR-004 (JS port): Team/car data injector — tools/data/teams.json -> ROM binary patch
//
// Reads tools/data/teams.json and patches out.bin in-place at the known ROM
// addresses for all team/driver data tables.
//
// Usage:
//   node tools/inject_team_data.js [--input tools/data/teams.json]
//                                   [--rom out.bin] [--dry-run] [-v]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT, DEFAULT_OUT_PATH } = require('./lib/rom');
const { writeU8, writeS8, writeU16BE, writeS16BE, writeU32BE } = require('./lib/binary');

// ---------------------------------------------------------------------------
// ROM addresses (must match extract_team_data.js)
// ---------------------------------------------------------------------------
const ROM_ADDR = {
  PointsAwardedPerPlacement:        0x0132EA,
  Ai_performance_factor_by_team:    0x0132F0,
  Ai_performance_table:             0x013300,
  InitialDriversAndTeamMap:         0x013380,
  SecondYearDriversAndTeamsMap:     0x013392,
  Team_engine_multiplier:           0x0133A4,
  Team_car_characteristics:         0x0133B4,
  Acceleration_modifiers:           0x013404,
  Engine_data_offset_table:         0x01340C,
  Engine_data:                      0x005FAE,
  Post_race_driver_target_points:   0x00F736,
  TeamMachineScreenStats:           0x0195AC,
  Car_spec_text_table:              0x019114,
  Driver_info_table:                0x0193BE,
  Driver_portrait_palette_streams:  0x019664,
  DriverPortraitTileMappings:       0x0198A4,
  DriverPortraitTiles:              0x019A34,
  Team_palette_data:                0x020FAE,
  Team_name_tilemap_table:          0x021B7C,
};

const TABLE_SIZES = {
  PointsAwardedPerPlacement:        6,
  Ai_performance_factor_by_team:    16,
  Ai_performance_table:             128,
  InitialDriversAndTeamMap:         18,
  SecondYearDriversAndTeamsMap:     18,
  Team_engine_multiplier:           16,
  Team_car_characteristics:         80,
  Acceleration_modifiers:           8,
  Engine_data_offset_table:         12,
  Engine_data:                      180,
  Post_race_driver_target_points:   32,
  TeamMachineScreenStats:           120,
  Car_spec_text_table:              288,
  Driver_info_table:                216,
  Driver_portrait_palette_streams:  576,
  DriverPortraitTileMappings:       72,
  DriverPortraitTiles:              72,
  Team_palette_data:                896,
  Team_name_tilemap_table:          64,
};

// ---------------------------------------------------------------------------
// Table injectors — each returns [addr, bytesWritten]
// ---------------------------------------------------------------------------
function injectPointsAwarded(buf, data) {
  const addr   = ROM_ADDR.PointsAwardedPerPlacement;
  const values = data.points_awarded_per_placement;
  if (values.length !== 6) throw new Error(`points_awarded_per_placement: expected 6, got ${values.length}`);
  for (let i = 0; i < 6; i++) writeU8(buf, addr + i, values[i]);
  return [addr, 6];
}

function injectAiPerformanceFactor(buf, data) {
  const addr    = ROM_ADDR.Ai_performance_factor_by_team;
  const entries = data.ai_performance_factor;
  if (entries.length !== 16) throw new Error(`ai_performance_factor: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) writeU8(buf, addr + i, entries[i].factor);
  return [addr, 16];
}

function injectAiPerformanceTable(buf, data) {
  const addr    = ROM_ADDR.Ai_performance_table;
  const entries = data.ai_performance_table;
  if (entries.length !== 16) throw new Error(`ai_performance_table: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    const vals = entries[i].entries;
    if (vals.length !== 8) throw new Error(`ai_performance_table[${i}]: expected 8 bytes`);
    for (let j = 0; j < 8; j++) writeU8(buf, addr + i * 8 + j, vals[j]);
  }
  return [addr, 128];
}

function injectDriversAndTeamMap(buf, data, key, label) {
  const addr  = ROM_ADDR[label];
  const entry = data[key];
  const raw   = entry._raw;
  if (raw.length !== 18) throw new Error(`${key}._raw: expected 18 bytes, got ${raw.length}`);
  for (let i = 0; i < 18; i++) writeU8(buf, addr + i, raw[i]);
  return [addr, 18];
}

function injectTeamEngineMultiplier(buf, data) {
  const addr    = ROM_ADDR.Team_engine_multiplier;
  const entries = data.team_engine_multiplier;
  if (entries.length !== 16) throw new Error(`team_engine_multiplier: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) writeU8(buf, addr + i, entries[i].tire_wear_multiplier);
  return [addr, 16];
}

function injectTeamCarCharacteristics(buf, data) {
  const addr    = ROM_ADDR.Team_car_characteristics;
  const entries = data.team_car_characteristics;
  if (entries.length !== 16) throw new Error(`team_car_characteristics: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    const base = addr + i * 5;
    const e    = entries[i];
    writeU8(buf, base + 0, e.accel_index);
    writeU8(buf, base + 1, e.engine_index);
    writeU8(buf, base + 2, e.steering_idx);
    writeU8(buf, base + 3, e.steering_idx_b);
    writeU8(buf, base + 4, e.braking_idx);
  }
  return [addr, 80];
}

function injectAccelerationModifiers(buf, data) {
  const addr   = ROM_ADDR.Acceleration_modifiers;
  const values = data.acceleration_modifiers;
  if (values.length !== 4) throw new Error(`acceleration_modifiers: expected 4, got ${values.length}`);
  for (let i = 0; i < 4; i++) writeS16BE(buf, addr + i * 2, values[i]);
  return [addr, 8];
}

function injectEngineDataOffsetTable(buf, data) {
  const addr   = ROM_ADDR.Engine_data_offset_table;
  const values = data.engine_data_offset_table;
  if (values.length !== 6) throw new Error(`engine_data_offset_table: expected 6, got ${values.length}`);
  for (let i = 0; i < 6; i++) writeU16BE(buf, addr + i * 2, values[i]);
  return [addr, 12];
}

function injectEngineData(buf, data) {
  const addr     = ROM_ADDR.Engine_data;
  const variants = data.engine_data;
  if (variants.length !== 6) throw new Error(`engine_data: expected 6 variants, got ${variants.length}`);
  for (let vi = 0; vi < 6; vi++) {
    const base  = addr + vi * 30;
    const v     = variants[vi];
    const words = [...v.auto_rpms, ...v.four_shift_rpms, ...v.seven_shift_rpms];
    if (words.length !== 15) throw new Error(`engine_data[${vi}]: expected 15 words`);
    for (let j = 0; j < 15; j++) writeU16BE(buf, base + j * 2, words[j]);
  }
  return [addr, 180];
}

function injectPostRaceDriverTargetPoints(buf, data) {
  const addr    = ROM_ADDR.Post_race_driver_target_points;
  const entries = data.post_race_driver_target_points;
  if (entries.length !== 16) throw new Error(`post_race_driver_target_points: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    writeU8(buf, addr + i * 2 + 0, entries[i].promote_threshold);
    writeU8(buf, addr + i * 2 + 1, entries[i].partner_threshold);
  }
  return [addr, 32];
}

function injectTeamMachineScreenStats(buf, data) {
  const addr     = ROM_ADDR.TeamMachineScreenStats;
  const stats    = data.team_machine_screen_stats;
  const teams    = stats.teams;
  const sentinel = stats.sentinel;
  if (teams.length !== 16)    throw new Error(`team_machine_screen_stats.teams: expected 16`);
  if (sentinel.length !== 8)  throw new Error(`team_machine_screen_stats.sentinel: expected 8 bytes`);
  for (let i = 0; i < 16; i++) {
    const base = addr + i * 7;
    const t    = teams[i];
    writeU8(buf, base + 0, t.eng_bar);
    writeU8(buf, base + 1, t.tm_bar);
    writeU8(buf, base + 2, t.sus_bar);
    writeU8(buf, base + 3, t.tire_bar);
    writeU8(buf, base + 4, t.bra_bar);
    writeU8(buf, base + 5, t.pad);
    writeU8(buf, base + 6, t.tire_wear_delta);
  }
  for (let i = 0; i < 8; i++) writeU8(buf, addr + 112 + i, sentinel[i]);
  return [addr, 120];
}

function injectCarSpecTextTable(buf, data) {
  const addr    = ROM_ADDR.Car_spec_text_table;
  const entries = data.car_spec_text_table;
  if (entries.length !== 16) throw new Error(`car_spec_text_table: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    const base = addr + i * 18;
    const e    = entries[i];
    writeU32BE(buf, base + 0,  e.car_name_ptr_minus1);
    writeU16BE(buf, base + 4,  e.car_name_len);
    writeU32BE(buf, base + 6,  e.engine_ptr_minus1);
    writeU16BE(buf, base + 10, e.engine_len);
    writeU32BE(buf, base + 12, e.power_ptr_minus1);
    writeU16BE(buf, base + 16, e.power_len);
  }
  return [addr, 288];
}

function injectDriverInfoTable(buf, data) {
  const addr    = ROM_ADDR.Driver_info_table;
  const entries = data.driver_info_table;
  if (entries.length !== 18) throw new Error(`driver_info_table: expected 18, got ${entries.length}`);
  for (let i = 0; i < 18; i++) {
    const base = addr + i * 12;
    const e    = entries[i];
    writeU32BE(buf, base + 0,  e.name_ptr_minus1);
    writeU16BE(buf, base + 4,  e.name_len);
    writeU32BE(buf, base + 6,  e.country_ptr_minus1);
    writeU16BE(buf, base + 10, e.country_len);
  }
  return [addr, 216];
}

function injectDriverPortraitPaletteStreams(buf, data) {
  const addr    = ROM_ADDR.Driver_portrait_palette_streams;
  const entries = data.driver_portrait_palette_streams;
  if (entries.length !== 18) throw new Error(`driver_portrait_palette_streams: expected 18, got ${entries.length}`);
  for (let i = 0; i < 18; i++) {
    const base = addr + i * 32;
    const raw  = entries[i]._raw;
    if (raw.length !== 32) throw new Error(`driver_portrait_palette_streams[${i}]._raw: expected 32 bytes`);
    for (let j = 0; j < 32; j++) writeU8(buf, base + j, raw[j]);
  }
  return [addr, 576];
}

function injectDriverPortraitTileMappings(buf, data) {
  const addr    = ROM_ADDR.DriverPortraitTileMappings;
  const entries = data.driver_portrait_tile_mappings;
  if (entries.length !== 18) throw new Error(`driver_portrait_tile_mappings: expected 18, got ${entries.length}`);
  for (let i = 0; i < 18; i++) writeU32BE(buf, addr + i * 4, entries[i].tilemap_ptr);
  return [addr, 72];
}

function injectDriverPortraitTiles(buf, data) {
  const addr    = ROM_ADDR.DriverPortraitTiles;
  const entries = data.driver_portrait_tiles;
  if (entries.length !== 18) throw new Error(`driver_portrait_tiles: expected 18, got ${entries.length}`);
  for (let i = 0; i < 18; i++) writeU32BE(buf, addr + i * 4, entries[i].tiles_ptr);
  return [addr, 72];
}

function injectTeamPaletteData(buf, data) {
  const addr    = ROM_ADDR.Team_palette_data;
  const entries = data.team_palette_data;
  if (entries.length !== 16) throw new Error(`team_palette_data: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) {
    const base = addr + i * 56;
    const raw  = entries[i]._raw;
    if (raw.length !== 56) throw new Error(`team_palette_data[${i}]._raw: expected 56 bytes`);
    for (let j = 0; j < 56; j++) writeU8(buf, base + j, raw[j]);
  }
  return [addr, 896];
}

function injectTeamNameTilemapTable(buf, data) {
  const addr    = ROM_ADDR.Team_name_tilemap_table;
  const entries = data.team_name_tilemap_table;
  if (entries.length !== 16) throw new Error(`team_name_tilemap_table: expected 16, got ${entries.length}`);
  for (let i = 0; i < 16; i++) writeU32BE(buf, addr + i * 4, entries[i].tilemap_ptr);
  return [addr, 64];
}

// ---------------------------------------------------------------------------
// Main injector
// ---------------------------------------------------------------------------
function injectTeamData(jsonPath, romPath, dryRun = false, verbose = false) {
  const data     = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const original = fs.readFileSync(romPath);
  const buf      = Buffer.from(original);

  const injectors = [
    ['PointsAwardedPerPlacement',       injectPointsAwarded],
    ['Ai_performance_factor_by_team',   injectAiPerformanceFactor],
    ['Ai_performance_table',            injectAiPerformanceTable],
    ['InitialDriversAndTeamMap',        (b, d) => injectDriversAndTeamMap(b, d, 'initial_drivers_and_team_map', 'InitialDriversAndTeamMap')],
    ['SecondYearDriversAndTeamsMap',    (b, d) => injectDriversAndTeamMap(b, d, 'second_year_drivers_and_team_map', 'SecondYearDriversAndTeamsMap')],
    ['Team_engine_multiplier',          injectTeamEngineMultiplier],
    ['Team_car_characteristics',        injectTeamCarCharacteristics],
    ['Acceleration_modifiers',          injectAccelerationModifiers],
    ['Engine_data_offset_table',        injectEngineDataOffsetTable],
    ['Engine_data',                     injectEngineData],
    ['Post_race_driver_target_points',  injectPostRaceDriverTargetPoints],
    ['TeamMachineScreenStats',          injectTeamMachineScreenStats],
    ['Car_spec_text_table',             injectCarSpecTextTable],
    ['Driver_info_table',               injectDriverInfoTable],
    ['Driver_portrait_palette_streams', injectDriverPortraitPaletteStreams],
    ['DriverPortraitTileMappings',      injectDriverPortraitTileMappings],
    ['DriverPortraitTiles',             injectDriverPortraitTiles],
    ['Team_palette_data',               injectTeamPaletteData],
    ['Team_name_tilemap_table',         injectTeamNameTilemapTable],
  ];

  let totalBytes = 0;
  for (const [label, fn] of injectors) {
    const [addr, n] = fn(buf, data);
    let changed = 0;
    for (let k = 0; k < n; k++) {
      if (original[addr + k] !== buf[addr + k]) changed++;
    }
    totalBytes += changed;
    if (verbose) {
      const status = changed > 0 ? `${String(changed).padStart(3)} bytes changed` : '  (no change)   ';
      info(`  0x${addr.toString(16).toUpperCase().padStart(6, '0')}  ${String(n).padStart(4)} bytes  ${status}  ${label}`);
    }
  }

  if (verbose) info(`  Total bytes changed: ${totalBytes}`);

  if (!dryRun) {
    fs.writeFileSync(romPath, buf);
    if (verbose) info(`  Written: ${romPath}`);
  } else if (verbose) {
    info('  (dry-run: ROM not written)');
  }

  return totalBytes;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--dry-run', '--verbose', '-v'],
    options: ['--input', '--rom'],
  });

  const dryRun   = args.flags['--dry-run'];
  const verbose  = args.flags['--verbose'] || args.flags['-v'];
  const inputArg = args.options['--input'] || 'tools/data/teams.json';
  const romArg   = args.options['--rom']   || 'out.bin';

  const jsonPath = path.resolve(REPO_ROOT, inputArg);
  const romPath  = path.resolve(REPO_ROOT, romArg);

  if (!fs.existsSync(jsonPath)) die(`JSON not found: ${jsonPath}`);
  if (!fs.existsSync(romPath))  die(`ROM not found: ${romPath}`);

  info(`Injecting team data from ${jsonPath} into ${romPath} ...`);
  const changed = injectTeamData(jsonPath, romPath, dryRun, verbose);

  if (dryRun) {
    info(`Dry-run: ${changed} bytes would change.`);
  } else {
    if (changed === 0) {
      info('No-op: 0 bytes changed (round-trip is bit-identical).');
    } else {
      info(`Injected: ${changed} bytes changed.`);
    }
  }
}

if (require.main === module) main();

module.exports = {
  ROM_ADDR, TABLE_SIZES,
  injectPointsAwarded, injectAiPerformanceFactor, injectAiPerformanceTable,
  injectDriversAndTeamMap, injectTeamEngineMultiplier, injectTeamCarCharacteristics,
  injectAccelerationModifiers, injectEngineDataOffsetTable, injectEngineData,
  injectPostRaceDriverTargetPoints, injectTeamMachineScreenStats, injectCarSpecTextTable,
  injectDriverInfoTable, injectDriverPortraitPaletteStreams,
  injectDriverPortraitTileMappings, injectDriverPortraitTiles,
  injectTeamPaletteData, injectTeamNameTilemapTable,
  injectTeamData,
};
