#!/usr/bin/env node
// tools/extract_team_data.js
//
// EXTR-003 (JS port): Team/car data extractor — orig.bin ROM addresses -> tools/data/teams.json
//
// Reads all team and driver data tables directly from the ROM binary at their
// known ROM addresses and emits a structured JSON file at tools/data/teams.json.
//
// Usage:
//   node tools/extract_team_data.js [--rom orig.bin] [--out tools/data/teams.json] [-v]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT, DEFAULT_ROM_PATH } = require('./lib/rom');
const { readU8, readS8, readU16BE, readS16BE, readU32BE } = require('./lib/binary');

// ---------------------------------------------------------------------------
// ROM addresses (verified from smgp.lst)
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

const TEAM_NAMES = [
  'Madonna', 'Firenze', 'Millions', 'Bestowal', 'Blanche', 'Tyrant',
  'Losel', 'May', 'Bullets', 'Dardan', 'Linden', 'Minarae',
  'Rigel', 'Comet', 'Orchis', 'Zero Force',
];

const DRIVER_NAMES = [
  'G.CEARA', 'A.ASSELIN', 'F.ELSSLER', 'G.ALBERTI', 'A.PICOS',
  'J.HERBIN', 'M.HAMANO', 'E.PACHECO', 'G.TURNER', 'B.MILLER',
  'E.BELLINI', 'M.MOREAU', 'R.COTMAN', 'E.TORNIO', 'C.TEGNER',
  'P.KLINGER', 'YOU',
];

// ---------------------------------------------------------------------------
// Table extractors
// ---------------------------------------------------------------------------
function extractPointsAwarded(rom) {
  const addr = ROM_ADDR.PointsAwardedPerPlacement;
  return Array.from(rom.slice(addr, addr + 6));
}

function extractAiPerformanceFactor(rom) {
  const addr = ROM_ADDR.Ai_performance_factor_by_team;
  return Array.from({ length: 16 }, (_, i) => ({
    team:   TEAM_NAMES[i],
    factor: readU8(rom, addr + i),
  }));
}

function extractAiPerformanceTable(rom) {
  const addr = ROM_ADDR.Ai_performance_table;
  return Array.from({ length: 16 }, (_, i) => ({
    team:    TEAM_NAMES[i],
    entries: Array.from(rom.slice(addr + i * 8, addr + i * 8 + 8)),
  }));
}

function extractDriversAndTeamMap(rom, addr, label) {
  const data = Array.from(rom.slice(addr, addr + 18));
  return {
    _label:          label,
    player_team:     data[0],
    driver_team_map: data.slice(1, 17),
    rival_team_initial: data[17],
    _raw:            data,
  };
}

function extractTeamEngineMultiplier(rom) {
  const addr = ROM_ADDR.Team_engine_multiplier;
  return Array.from({ length: 16 }, (_, i) => ({
    team:                TEAM_NAMES[i],
    tire_wear_multiplier: readU8(rom, addr + i),
  }));
}

function extractTeamCarCharacteristics(rom) {
  const addr = ROM_ADDR.Team_car_characteristics;
  return Array.from({ length: 16 }, (_, i) => {
    const base = addr + i * 5;
    return {
      team:          TEAM_NAMES[i],
      accel_index:   readU8(rom, base + 0),
      engine_index:  readU8(rom, base + 1),
      steering_idx:  readU8(rom, base + 2),
      steering_idx_b: readU8(rom, base + 3),
      braking_idx:   readU8(rom, base + 4),
    };
  });
}

function extractAccelerationModifiers(rom) {
  const addr = ROM_ADDR.Acceleration_modifiers;
  return Array.from({ length: 4 }, (_, i) => readS16BE(rom, addr + i * 2));
}

function extractEngineDataOffsetTable(rom) {
  const addr = ROM_ADDR.Engine_data_offset_table;
  return Array.from({ length: 6 }, (_, i) => readU16BE(rom, addr + i * 2));
}

function extractEngineData(rom) {
  const addr = ROM_ADDR.Engine_data;
  return Array.from({ length: 6 }, (_, variant) => {
    const base = addr + variant * 30;
    const words = Array.from({ length: 15 }, (_, j) => readU16BE(rom, base + j * 2));
    return {
      variant,
      auto_rpms:        words.slice(0, 4),
      four_shift_rpms:  words.slice(4, 8),
      seven_shift_rpms: words.slice(8, 15),
    };
  });
}

function extractPostRaceDriverTargetPoints(rom) {
  const addr = ROM_ADDR.Post_race_driver_target_points;
  return Array.from({ length: 16 }, (_, i) => ({
    team:               TEAM_NAMES[i],
    promote_threshold:  readU8(rom, addr + i * 2 + 0),
    partner_threshold:  readU8(rom, addr + i * 2 + 1),
  }));
}

function extractTeamMachineScreenStats(rom) {
  const addr = ROM_ADDR.TeamMachineScreenStats;
  const teams = Array.from({ length: 16 }, (_, i) => {
    const base = addr + i * 7;
    const data = Array.from(rom.slice(base, base + 7));
    return {
      team:            TEAM_NAMES[i],
      eng_bar:         data[0],
      tm_bar:          data[1],
      sus_bar:         data[2],
      tire_bar:        data[3],
      bra_bar:         data[4],
      pad:             data[5],
      tire_wear_delta: data[6],
    };
  });
  const sentinel = Array.from(rom.slice(addr + 16 * 7, addr + 16 * 7 + 8));
  return { teams, sentinel };
}

function extractCarSpecTextTable(rom) {
  const addr = ROM_ADDR.Car_spec_text_table;
  return Array.from({ length: 16 }, (_, i) => {
    const base = addr + i * 18;
    return {
      team:                  TEAM_NAMES[i],
      car_name_ptr_minus1:   readU32BE(rom, base + 0),
      car_name_len:          readU16BE(rom, base + 4),
      engine_ptr_minus1:     readU32BE(rom, base + 6),
      engine_len:            readU16BE(rom, base + 10),
      power_ptr_minus1:      readU32BE(rom, base + 12),
      power_len:             readU16BE(rom, base + 16),
    };
  });
}

function extractDriverInfoTable(rom) {
  const addr = ROM_ADDR.Driver_info_table;
  return Array.from({ length: 18 }, (_, i) => {
    const base = addr + i * 12;
    const driverName = i < 17 ? DRIVER_NAMES[i] : 'YOU (duplicate)';
    return {
      index:              i,
      driver:             driverName,
      name_ptr_minus1:    readU32BE(rom, base + 0),
      name_len:           readU16BE(rom, base + 4),
      country_ptr_minus1: readU32BE(rom, base + 6),
      country_len:        readU16BE(rom, base + 10),
    };
  });
}

function extractDriverPortraitPaletteStreams(rom) {
  const addr = ROM_ADDR.Driver_portrait_palette_streams;
  const nEntries = Math.floor((ROM_ADDR.DriverPortraitTileMappings - addr) / 32);
  return Array.from({ length: nEntries }, (_, i) => {
    const base = addr + i * 32;
    const raw  = Array.from(rom.slice(base, base + 32));
    const header = raw.slice(0, 2);
    const paletteWords = Array.from({ length: 15 }, (_, j) => readU16BE(rom, base + 2 + j * 2));
    const driverName = i < 17 ? DRIVER_NAMES[i] : 'YOU (extra)';
    return { index: i, driver: driverName, header, palette_words: paletteWords, _raw: raw };
  });
}

function extractDriverPortraitTileMappings(rom) {
  const addr = ROM_ADDR.DriverPortraitTileMappings;
  return Array.from({ length: 18 }, (_, i) => {
    const driverName = i < 17 ? DRIVER_NAMES[i] : 'YOU (duplicate)';
    return { index: i, driver: driverName, tilemap_ptr: readU32BE(rom, addr + i * 4) };
  });
}

function extractDriverPortraitTiles(rom) {
  const addr = ROM_ADDR.DriverPortraitTiles;
  return Array.from({ length: 18 }, (_, i) => {
    const driverName = i < 17 ? DRIVER_NAMES[i] : 'YOU (duplicate)';
    return { index: i, driver: driverName, tiles_ptr: readU32BE(rom, addr + i * 4) };
  });
}

function extractTeamPaletteData(rom) {
  const addr = ROM_ADDR.Team_palette_data;
  return Array.from({ length: 16 }, (_, i) => {
    const base = addr + i * 56;
    const raw  = Array.from(rom.slice(base, base + 56));
    const truckColors    = raw.slice(0, 10);
    const carColorsWords = Array.from({ length: 4 }, (_, j) => readU16BE(rom, base + 10 + j * 2));
    const extendedPalette = raw.slice(18, 56);
    return {
      team:             TEAM_NAMES[i],
      truck_colors:     truckColors,
      car_colors_words: carColorsWords,
      extended_palette: extendedPalette,
      _raw:             raw,
    };
  });
}

function extractTeamNameTilemapTable(rom) {
  const addr = ROM_ADDR.Team_name_tilemap_table;
  return Array.from({ length: 16 }, (_, i) => ({
    team:        TEAM_NAMES[i],
    tilemap_ptr: readU32BE(rom, addr + i * 4),
  }));
}

// ---------------------------------------------------------------------------
// Main extractor
// ---------------------------------------------------------------------------
function extractTeamData(romPath, verbose = false) {
  const rom = fs.readFileSync(romPath);
  if (verbose) info(`  ROM size: ${rom.length} bytes (0x${rom.length.toString(16).toUpperCase()})`);

  const data = {};

  if (verbose) info('  Extracting PointsAwardedPerPlacement...');
  data.points_awarded_per_placement = extractPointsAwarded(rom);

  if (verbose) info('  Extracting Ai_performance_factor_by_team...');
  data.ai_performance_factor = extractAiPerformanceFactor(rom);

  if (verbose) info('  Extracting Ai_performance_table...');
  data.ai_performance_table = extractAiPerformanceTable(rom);

  if (verbose) info('  Extracting InitialDriversAndTeamMap...');
  data.initial_drivers_and_team_map = extractDriversAndTeamMap(
    rom, ROM_ADDR.InitialDriversAndTeamMap, 'InitialDriversAndTeamMap');

  if (verbose) info('  Extracting SecondYearDriversAndTeamsMap...');
  data.second_year_drivers_and_team_map = extractDriversAndTeamMap(
    rom, ROM_ADDR.SecondYearDriversAndTeamsMap, 'SecondYearDriversAndTeamsMap');

  if (verbose) info('  Extracting Team_engine_multiplier...');
  data.team_engine_multiplier = extractTeamEngineMultiplier(rom);

  if (verbose) info('  Extracting Team_car_characteristics...');
  data.team_car_characteristics = extractTeamCarCharacteristics(rom);

  if (verbose) info('  Extracting Acceleration_modifiers...');
  data.acceleration_modifiers = extractAccelerationModifiers(rom);

  if (verbose) info('  Extracting Engine_data_offset_table...');
  data.engine_data_offset_table = extractEngineDataOffsetTable(rom);

  if (verbose) info('  Extracting Engine_data...');
  data.engine_data = extractEngineData(rom);

  if (verbose) info('  Extracting Post_race_driver_target_points...');
  data.post_race_driver_target_points = extractPostRaceDriverTargetPoints(rom);

  if (verbose) info('  Extracting TeamMachineScreenStats...');
  data.team_machine_screen_stats = extractTeamMachineScreenStats(rom);

  if (verbose) info('  Extracting Car_spec_text_table...');
  data.car_spec_text_table = extractCarSpecTextTable(rom);

  if (verbose) info('  Extracting Driver_info_table...');
  data.driver_info_table = extractDriverInfoTable(rom);

  if (verbose) info('  Extracting Driver_portrait_palette_streams...');
  data.driver_portrait_palette_streams = extractDriverPortraitPaletteStreams(rom);

  if (verbose) info('  Extracting DriverPortraitTileMappings...');
  data.driver_portrait_tile_mappings = extractDriverPortraitTileMappings(rom);

  if (verbose) info('  Extracting DriverPortraitTiles...');
  data.driver_portrait_tiles = extractDriverPortraitTiles(rom);

  if (verbose) info('  Extracting Team_palette_data...');
  data.team_palette_data = extractTeamPaletteData(rom);

  if (verbose) info('  Extracting Team_name_tilemap_table...');
  data.team_name_tilemap_table = extractTeamNameTilemapTable(rom);

  return data;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--verbose', '-v'],
    options: ['--rom', '--out'],
  });

  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const romArg  = args.options['--rom'] || 'orig.bin';
  const outArg  = args.options['--out'] || 'tools/data/teams.json';

  const romPath = path.resolve(REPO_ROOT, romArg);
  const outPath = path.resolve(REPO_ROOT, outArg);

  if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

  info(`Extracting team data from ${romPath} ...`);
  const data = extractTeamData(romPath, verbose);

  const output = {
    _meta: {
      description:    'Super Monaco GP team/car data — extracted from ROM binary',
      generated_by:   'tools/extract_team_data.js (EXTR-003)',
      rom_addresses:  Object.fromEntries(
        Object.entries(ROM_ADDR).map(([k, v]) => [k, `0x${v.toString(16).toUpperCase().padStart(6, '0')}`])
      ),
      team_count:     16,
      driver_count:   17,
      format_version: 1,
    },
    ...data,
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2));

  info(`Written: ${outPath}`);
  info('  16 teams, 17 drivers extracted.');
}

main();

module.exports = {
  ROM_ADDR, TEAM_NAMES, DRIVER_NAMES,
  extractPointsAwarded, extractAiPerformanceFactor, extractAiPerformanceTable,
  extractDriversAndTeamMap, extractTeamEngineMultiplier, extractTeamCarCharacteristics,
  extractAccelerationModifiers, extractEngineDataOffsetTable, extractEngineData,
  extractPostRaceDriverTargetPoints, extractTeamMachineScreenStats, extractCarSpecTextTable,
  extractDriverInfoTable, extractDriverPortraitPaletteStreams,
  extractDriverPortraitTileMappings, extractDriverPortraitTiles,
  extractTeamPaletteData, extractTeamNameTilemapTable,
  extractTeamData,
};
