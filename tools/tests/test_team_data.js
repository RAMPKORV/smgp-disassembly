#!/usr/bin/env node
// tools/tests/test_team_data.js
//
// Tests for extract_team_data.js and inject_team_data.js.
//
// Sections:
//   A. JSON structure validation — all expected keys/types/counts present
//   B. Value range and consistency checks
//   C. No-op round-trip — inject unchanged JSON -> 0 bytes changed
//   D. Mutation round-trip — modify a value, inject, re-extract, verify changed

'use strict';

const assert = require('assert');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');

const { extractTeamData } = require('../extract_team_data');
const { injectTeamData  } = require('../inject_team_data');

const { REPO_ROOT } = require('../lib/rom');
const TEAMS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'teams.json');
const ORIG_BIN   = path.join(REPO_ROOT, 'orig.bin');
const OUT_BIN    = path.join(REPO_ROOT, 'out.bin');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
  } catch (err) {
    failed++;
    console.error(`FAIL: ${name}`);
    console.error(`  ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// Load teams.json once for structure/sanity tests
// ---------------------------------------------------------------------------
if (!fs.existsSync(TEAMS_JSON)) {
  test('teams_json_exists', () => {
    throw new Error(`${TEAMS_JSON} not found — run extract_team_data.js first`);
  });
  if (require.main === module) {
    console.log(`Results: ${passed} passed, ${failed} failed`);
    process.exit(1);
  }
}

const JSON_DATA = JSON.parse(fs.readFileSync(TEAMS_JSON, 'utf8'));
const D = JSON_DATA;

// ===========================================================================
// Section A: JSON structure validation
// ===========================================================================

// _meta
test('A.meta_present', () => assert.ok('_meta' in D, '_meta key missing'));

if ('_meta' in D) {
  const m = D._meta;
  test('A.meta_team_count',      () => assert.strictEqual(m.team_count,      16));
  test('A.meta_driver_count',    () => assert.strictEqual(m.driver_count,    17));
  test('A.meta_format_version',  () => assert.strictEqual(m.format_version,   1));
  test('A.meta_rom_addresses',   () => assert.ok('rom_addresses' in m, 'rom_addresses missing from _meta'));
}

// Top-level keys
const REQUIRED_KEYS = [
  'points_awarded_per_placement',
  'ai_performance_factor',
  'ai_performance_table',
  'initial_drivers_and_team_map',
  'second_year_drivers_and_team_map',
  'team_engine_multiplier',
  'team_car_characteristics',
  'acceleration_modifiers',
  'engine_data_offset_table',
  'engine_data',
  'post_race_driver_target_points',
  'team_machine_screen_stats',
  'car_spec_text_table',
  'driver_info_table',
  'driver_portrait_palette_streams',
  'driver_portrait_tile_mappings',
  'driver_portrait_tiles',
  'team_palette_data',
  'team_name_tilemap_table',
];
for (const key of REQUIRED_KEYS) {
  test(`A.key_${key}`, () => assert.ok(key in D, `missing top-level key: ${key}`));
}

// List lengths
test('A.points_len',          () => assert.strictEqual(D.points_awarded_per_placement.length,    6));
test('A.ai_factor_len',       () => assert.strictEqual(D.ai_performance_factor.length,           16));
test('A.ai_table_len',        () => assert.strictEqual(D.ai_performance_table.length,            16));
test('A.engine_mult_len',     () => assert.strictEqual(D.team_engine_multiplier.length,          16));
test('A.car_chars_len',       () => assert.strictEqual(D.team_car_characteristics.length,        16));
test('A.accel_mods_len',      () => assert.strictEqual(D.acceleration_modifiers.length,           4));
test('A.engine_offsets_len',  () => assert.strictEqual(D.engine_data_offset_table.length,         6));
test('A.engine_data_len',     () => assert.strictEqual(D.engine_data.length,                     6));
test('A.post_race_len',       () => assert.strictEqual(D.post_race_driver_target_points.length,  16));
test('A.car_spec_len',        () => assert.strictEqual(D.car_spec_text_table.length,             16));
test('A.driver_info_len',     () => assert.strictEqual(D.driver_info_table.length,               18));
test('A.palette_streams_len', () => assert.strictEqual(D.driver_portrait_palette_streams.length, 18));
test('A.tile_mappings_len',   () => assert.strictEqual(D.driver_portrait_tile_mappings.length,   18));
test('A.portrait_tiles_len',  () => assert.strictEqual(D.driver_portrait_tiles.length,           18));
test('A.team_palette_len',    () => assert.strictEqual(D.team_palette_data.length,               16));
test('A.name_tilemap_len',    () => assert.strictEqual(D.team_name_tilemap_table.length,         16));

// team_machine_screen_stats subkeys
const tms = D.team_machine_screen_stats;
test('A.tms_teams_key',    () => assert.ok('teams'    in tms, 'missing teams'));
test('A.tms_sentinel_key', () => assert.ok('sentinel' in tms, 'missing sentinel'));
if ('teams'    in tms) test('A.tms_teams_len',    () => assert.strictEqual(tms.teams.length,    16));
if ('sentinel' in tms) test('A.tms_sentinel_len', () => assert.strictEqual(tms.sentinel.length,  8));

// Per-entry spot-checks
if (D.ai_performance_factor.length > 0) {
  const e = D.ai_performance_factor[0];
  test('A.ai_factor_team_key',   () => assert.ok('team'   in e));
  test('A.ai_factor_factor_key', () => assert.ok('factor' in e));
}

if (D.ai_performance_table.length > 0) {
  const e = D.ai_performance_table[0];
  test('A.ai_table_team_key',    () => assert.ok('team'    in e));
  test('A.ai_table_entries_key', () => assert.ok('entries' in e));
  if ('entries' in e) test('A.ai_table_entry_len', () => assert.strictEqual(e.entries.length, 8));
}

if (D.team_car_characteristics.length > 0) {
  const e = D.team_car_characteristics[0];
  for (const k of ['team', 'accel_index', 'engine_index', 'steering_idx', 'steering_idx_b', 'braking_idx']) {
    test(`A.car_chars_${k}`, () => assert.ok(k in e, `missing key ${k}`));
  }
}

if (D.engine_data.length > 0) {
  const e = D.engine_data[0];
  for (const k of ['variant', 'auto_rpms', 'four_shift_rpms', 'seven_shift_rpms']) {
    test(`A.engine_data_${k}`, () => assert.ok(k in e, `missing key ${k}`));
  }
  if ('auto_rpms'        in e) test('A.engine_auto_len',  () => assert.strictEqual(e.auto_rpms.length,        4));
  if ('four_shift_rpms'  in e) test('A.engine_four_len',  () => assert.strictEqual(e.four_shift_rpms.length,  4));
  if ('seven_shift_rpms' in e) test('A.engine_seven_len', () => assert.strictEqual(e.seven_shift_rpms.length, 7));
}

if (D.driver_portrait_palette_streams.length > 0) {
  const e = D.driver_portrait_palette_streams[0];
  for (const k of ['index', 'driver', 'header', 'palette_words', '_raw']) {
    test(`A.palette_stream_${k}`, () => assert.ok(k in e, `missing key ${k}`));
  }
  if ('header'        in e) test('A.palette_header_len', () => assert.strictEqual(e.header.length,        2));
  if ('palette_words' in e) test('A.palette_words_len',  () => assert.strictEqual(e.palette_words.length, 15));
  if ('_raw'          in e) test('A.palette_raw_len',    () => assert.strictEqual(e._raw.length,          32));
}

if (D.team_palette_data.length > 0) {
  const e = D.team_palette_data[0];
  for (const k of ['team', 'truck_colors', 'car_colors_words', 'extended_palette', '_raw']) {
    test(`A.team_palette_${k}`, () => assert.ok(k in e, `missing key ${k}`));
  }
  if ('truck_colors'     in e) test('A.truck_colors_len',     () => assert.strictEqual(e.truck_colors.length,     10));
  if ('car_colors_words' in e) test('A.car_colors_len',       () => assert.strictEqual(e.car_colors_words.length,  4));
  if ('extended_palette' in e) test('A.ext_palette_len',      () => assert.strictEqual(e.extended_palette.length, 38));
  if ('_raw'             in e) test('A.team_palette_raw_len', () => assert.strictEqual(e._raw.length,             56));
}

for (const mapKey of ['initial_drivers_and_team_map', 'second_year_drivers_and_team_map']) {
  if (mapKey in D) {
    const m = D[mapKey];
    for (const k of ['player_team', 'driver_team_map', 'rival_team_initial', '_raw']) {
      test(`A.${mapKey}_${k}`, () => assert.ok(k in m, `${mapKey} missing key ${k}`));
    }
    if ('driver_team_map' in m) test(`A.${mapKey}_driver_map_len`, () => assert.strictEqual(m.driver_team_map.length, 16));
    if ('_raw'            in m) test(`A.${mapKey}_raw_len`,        () => assert.strictEqual(m._raw.length,            18));
  }
}

// ===========================================================================
// Section B: Value range and consistency checks
// ===========================================================================

// Points: descending and positive
const pts = D.points_awarded_per_placement;
for (let i = 0; i < pts.length; i++) {
  test(`B.points[${i}]_positive`, () => assert.ok(pts[i] > 0, `points[${i}] = ${pts[i]}`));
}
for (let i = 0; i < pts.length - 1; i++) {
  test(`B.points_descending_${i}`, () =>
    assert.ok(pts[i] > pts[i + 1], `pts[${i}]=${pts[i]} <= pts[${i+1}]=${pts[i+1]}`));
}

// AI performance factors in 0-255
for (const e of D.ai_performance_factor) {
  test(`B.ai_factor_${e.team}`, () =>
    assert.ok(e.factor >= 0 && e.factor <= 255, `factor ${e.factor} not in [0,255]`));
}

// AI performance table: each of 8 bytes in 0-255
for (const e of D.ai_performance_table) {
  for (let j = 0; j < e.entries.length; j++) {
    test(`B.ai_table_${e.team}[${j}]`, () =>
      assert.ok(e.entries[j] >= 0 && e.entries[j] <= 255, `entries[${j}]=${e.entries[j]} not in [0,255]`));
  }
}

// Engine multiplier in 0-255
for (const e of D.team_engine_multiplier) {
  test(`B.eng_mult_${e.team}`, () =>
    assert.ok(e.tire_wear_multiplier >= 0 && e.tire_wear_multiplier <= 255,
      `tire_wear_multiplier ${e.tire_wear_multiplier} not in [0,255]`));
}

// Car characteristics: valid index sets
const ACCEL_VALID  = new Set([0, 2, 4, 6]);
const ENGINE_VALID = new Set([0, 2, 4, 6, 8, 10]);
for (const e of D.team_car_characteristics) {
  test(`B.car_chars_accel_${e.team}`,  () =>
    assert.ok(ACCEL_VALID.has(e.accel_index),   `accel_index=${e.accel_index} not valid`));
  test(`B.car_chars_engine_${e.team}`, () =>
    assert.ok(ENGINE_VALID.has(e.engine_index), `engine_index=${e.engine_index} not valid`));
  for (const fld of ['steering_idx', 'steering_idx_b', 'braking_idx']) {
    test(`B.car_chars_${fld}_${e.team}`, () =>
      assert.ok(e[fld] >= 0 && e[fld] <= 255, `${fld}=${e[fld]} not in [0,255]`));
  }
}

// Acceleration modifiers: signed 16-bit
for (let i = 0; i < D.acceleration_modifiers.length; i++) {
  test(`B.accel_mod[${i}]`, () =>
    assert.ok(D.acceleration_modifiers[i] >= -32768 && D.acceleration_modifiers[i] <= 32767,
      `accel_mod[${i}]=${D.acceleration_modifiers[i]} out of signed-word range`));
}

// Engine data offset table: [0, 30, 60, 90, 120, 150]
const offsets = D.engine_data_offset_table;
for (let i = 0; i < offsets.length; i++) {
  test(`B.engine_offset[${i}]`, () =>
    assert.strictEqual(offsets[i], i * 30, `offset[${i}] expected ${i*30}, got ${offsets[i]}`));
}

// Engine data: RPM values in 0-65535
for (const v of D.engine_data) {
  const allRpms = [...v.auto_rpms, ...v.four_shift_rpms, ...v.seven_shift_rpms];
  for (let j = 0; j < allRpms.length; j++) {
    test(`B.engine_v${v.variant}_word${j}`, () =>
      assert.ok(allRpms[j] >= 0 && allRpms[j] <= 65535, `rpm=${allRpms[j]} out of range`));
  }
}

// Post-race thresholds in 0-255
for (const e of D.post_race_driver_target_points) {
  test(`B.post_race_promote_${e.team}`, () =>
    assert.ok(e.promote_threshold >= 0 && e.promote_threshold <= 255));
  test(`B.post_race_partner_${e.team}`, () =>
    assert.ok(e.partner_threshold >= 0 && e.partner_threshold <= 255));
}

// TeamMachineScreenStats bars in 0-100, tire_wear_delta in 0-255
for (const t of tms.teams) {
  for (const bar of ['eng_bar', 'tm_bar', 'sus_bar', 'tire_bar', 'bra_bar']) {
    test(`B.tms_${bar}_${t.team}`, () =>
      assert.ok(t[bar] >= 0 && t[bar] <= 100, `${bar}=${t[bar]} not in [0,100]`));
  }
  test(`B.tms_tire_delta_${t.team}`, () =>
    assert.ok(t.tire_wear_delta >= 0 && t.tire_wear_delta <= 255));
}

// Sentinel: first 5 bytes are 0xFF
const sentinel = tms.sentinel;
for (let i = 0; i < 5; i++) {
  test(`B.sentinel[${i}]`, () => assert.strictEqual(sentinel[i], 0xFF));
}

// Car spec text table: ptr values < 0x80000, lengths 1-256
for (const e of D.car_spec_text_table) {
  for (const ptrKey of ['car_name_ptr_minus1', 'engine_ptr_minus1', 'power_ptr_minus1']) {
    test(`B.car_spec_${ptrKey}_${e.team}`, () =>
      assert.ok(e[ptrKey] >= 0 && e[ptrKey] <= 0x7FFFF, `${ptrKey}=${e[ptrKey]} out of range`));
  }
  for (const lenKey of ['car_name_len', 'engine_len', 'power_len']) {
    test(`B.car_spec_${lenKey}_${e.team}`, () =>
      assert.ok(e[lenKey] >= 1 && e[lenKey] <= 256, `${lenKey}=${e[lenKey]} not in [1,256]`));
  }
}

// Driver info table: ptr values < 0x80000, lengths 1-256
for (const e of D.driver_info_table) {
  for (const ptrKey of ['name_ptr_minus1', 'country_ptr_minus1']) {
    test(`B.driver_info_${ptrKey}[${e.index}]`, () =>
      assert.ok(e[ptrKey] >= 0 && e[ptrKey] <= 0x7FFFF));
  }
  for (const lenKey of ['name_len', 'country_len']) {
    test(`B.driver_info_${lenKey}[${e.index}]`, () =>
      assert.ok(e[lenKey] >= 1 && e[lenKey] <= 256));
  }
}

// Palette streams: header[0] == 2, words in 0-65535
for (const e of D.driver_portrait_palette_streams) {
  test(`B.palette_header0[${e.index}]`, () => assert.strictEqual(e.header[0], 2));
  for (let j = 0; j < e.palette_words.length; j++) {
    test(`B.palette_word[${e.index}][${j}]`, () =>
      assert.ok(e.palette_words[j] >= 0 && e.palette_words[j] <= 65535));
  }
}

// Portrait tile/tilemap pointers: valid ROM addresses
for (const e of D.driver_portrait_tile_mappings) {
  test(`B.tilemap_ptr[${e.index}]`, () =>
    assert.ok(e.tilemap_ptr >= 0 && e.tilemap_ptr <= 0x80000));
}
for (const e of D.driver_portrait_tiles) {
  test(`B.tiles_ptr[${e.index}]`, () =>
    assert.ok(e.tiles_ptr >= 0 && e.tiles_ptr <= 0x80000));
}

// Team palette _raw: all bytes in 0-255
for (const e of D.team_palette_data) {
  if (e._raw.length === 56) {
    for (let i = 0; i < e._raw.length; i++) {
      test(`B.palette_raw_${e.team}[${i}]`, () =>
        assert.ok(e._raw[i] >= 0 && e._raw[i] <= 255));
    }
  }
}

// Team name tilemap pointers: valid ROM addresses
for (const e of D.team_name_tilemap_table) {
  test(`B.name_tilemap_${e.team}`, () =>
    assert.ok(e.tilemap_ptr >= 0 && e.tilemap_ptr <= 0x80000));
}

// drivers-and-team-map raw byte range checks
for (const mapKey of ['initial_drivers_and_team_map', 'second_year_drivers_and_team_map']) {
  if (mapKey in D) {
    const m = D[mapKey];
    for (let i = 0; i < m.driver_team_map.length; i++) {
      test(`B.${mapKey}_slot${i}`, () =>
        assert.ok(m.driver_team_map[i] >= 0 && m.driver_team_map[i] <= 255));
    }
    test(`B.${mapKey}_player_team`, () =>
      assert.ok(m.player_team >= 0 && m.player_team <= 255));
    test(`B.${mapKey}_rival_init`, () =>
      assert.ok(m.rival_team_initial >= 0 && m.rival_team_initial <= 255));
  }
}

// ===========================================================================
// Section C: No-op round-trip
// ===========================================================================

test('C.out_bin_exists', () => {
  assert.ok(fs.existsSync(OUT_BIN), `${OUT_BIN} not found — run build.bat first`);
});

if (fs.existsSync(OUT_BIN)) {
  test('C.noop_bytes_changed', () => {
    const changed = injectTeamData(TEAMS_JSON, OUT_BIN, /* dryRun= */ true, /* verbose= */ false);
    assert.strictEqual(changed, 0);
  });

  test('C.orig_bin_noop', () => {
    assert.ok(fs.existsSync(ORIG_BIN), `${ORIG_BIN} not found`);
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp_team_'));
    try {
      const tmpRom = path.join(tmpDir, 'test.bin');
      fs.copyFileSync(ORIG_BIN, tmpRom);
      const changed = injectTeamData(TEAMS_JSON, tmpRom, false, false);
      assert.strictEqual(changed, 0);
      const patched = fs.readFileSync(tmpRom);
      const orig    = fs.readFileSync(ORIG_BIN);
      assert.ok(patched.equals(orig), 'patched ROM differs from original');
    } finally {
      fs.unlinkSync(path.join(tmpDir, 'test.bin'));
      fs.rmdirSync(tmpDir);
    }
  });
}

// ===========================================================================
// Section D: Mutation round-trip
// ===========================================================================

function withMutatedJson(mutate, callback) {
  const tmpDir  = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp_team_'));
  try {
    const tmpJson = path.join(tmpDir, 'teams.json');
    const tmpRom  = path.join(tmpDir, 'test.bin');
    const modified = JSON.parse(JSON.stringify(JSON_DATA));
    mutate(modified);
    fs.writeFileSync(tmpJson, JSON.stringify(modified));
    fs.copyFileSync(ORIG_BIN, tmpRom);
    callback(tmpJson, tmpRom);
  } finally {
    // cleanup
    try {
      for (const f of fs.readdirSync(tmpDir)) fs.unlinkSync(path.join(tmpDir, f));
      fs.rmdirSync(tmpDir);
    } catch (_) {}
  }
}

if (fs.existsSync(ORIG_BIN)) {
  // D.1: modify points_awarded_per_placement[0]
  test('D.points_changed_count', () => {
    withMutatedJson(m => {
      m.points_awarded_per_placement[0] = (m.points_awarded_per_placement[0] + 1) % 256;
    }, (tmpJson, tmpRom) => {
      const changed = injectTeamData(tmpJson, tmpRom, false, false);
      assert.strictEqual(changed, 1);
    });
  });

  test('D.points_re_extracted', () => {
    const originalVal = D.points_awarded_per_placement[0];
    const newVal = (originalVal + 1) % 256;
    withMutatedJson(m => { m.points_awarded_per_placement[0] = newVal; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.points_awarded_per_placement[0], newVal);
    });
  });

  test('D.points_rest_unchanged', () => {
    withMutatedJson(m => {
      m.points_awarded_per_placement[0] = (m.points_awarded_per_placement[0] + 1) % 256;
    }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.deepStrictEqual(re.points_awarded_per_placement.slice(1),
        D.points_awarded_per_placement.slice(1));
    });
  });

  // D.2: modify ai_performance_factor team 0
  test('D.ai_factor_mutated', () => {
    const origFactor = D.ai_performance_factor[0].factor;
    const newFactor  = (origFactor + 5) % 256;
    withMutatedJson(m => { m.ai_performance_factor[0].factor = newFactor; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.ai_performance_factor[0].factor, newFactor);
    });
  });

  for (let i = 1; i < 16; i++) {
    const idx = i;
    test(`D.ai_factor_team${idx}_unchanged`, () => {
      withMutatedJson(m => {
        m.ai_performance_factor[0].factor = (m.ai_performance_factor[0].factor + 5) % 256;
      }, (tmpJson, tmpRom) => {
        injectTeamData(tmpJson, tmpRom, false, false);
        const re = extractTeamData(tmpRom);
        assert.strictEqual(re.ai_performance_factor[idx].factor,
          D.ai_performance_factor[idx].factor);
      });
    });
  }

  // D.3: modify team_car_characteristics accel_index for team 0
  test('D.car_char_accel_mutated', () => {
    const VALID_ACCEL = [0, 2, 4, 6];
    const origAccel   = D.team_car_characteristics[0].accel_index;
    const newAccel    = VALID_ACCEL[(VALID_ACCEL.indexOf(origAccel) + 1) % VALID_ACCEL.length];
    withMutatedJson(m => { m.team_car_characteristics[0].accel_index = newAccel; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.team_car_characteristics[0].accel_index, newAccel);
    });
  });

  for (const fld of ['engine_index', 'steering_idx', 'steering_idx_b', 'braking_idx']) {
    test(`D.car_char_${fld}_unchanged`, () => {
      const VALID_ACCEL = [0, 2, 4, 6];
      const origAccel = D.team_car_characteristics[0].accel_index;
      const newAccel  = VALID_ACCEL[(VALID_ACCEL.indexOf(origAccel) + 1) % VALID_ACCEL.length];
      withMutatedJson(m => { m.team_car_characteristics[0].accel_index = newAccel; }, (tmpJson, tmpRom) => {
        injectTeamData(tmpJson, tmpRom, false, false);
        const re = extractTeamData(tmpRom);
        assert.strictEqual(re.team_car_characteristics[0][fld],
          D.team_car_characteristics[0][fld]);
      });
    });
  }

  // D.4: modify engine_data variant 0, auto_rpms[0]
  test('D.engine_rpm_mutated', () => {
    const origRpm = D.engine_data[0].auto_rpms[0];
    const newRpm  = (origRpm + 100) % 65536;
    withMutatedJson(m => { m.engine_data[0].auto_rpms[0] = newRpm; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.engine_data[0].auto_rpms[0], newRpm);
    });
  });

  for (let vi = 1; vi < 6; vi++) {
    const idx = vi;
    test(`D.engine_v${idx}_unchanged`, () => {
      withMutatedJson(m => {
        m.engine_data[0].auto_rpms[0] = (m.engine_data[0].auto_rpms[0] + 100) % 65536;
      }, (tmpJson, tmpRom) => {
        injectTeamData(tmpJson, tmpRom, false, false);
        const re = extractTeamData(tmpRom);
        assert.deepStrictEqual(re.engine_data[idx], D.engine_data[idx]);
      });
    });
  }

  // D.5: modify team_machine_screen_stats eng_bar for team 0
  test('D.tms_engbar_mutated', () => {
    const origBar = D.team_machine_screen_stats.teams[0].eng_bar;
    const newBar  = Math.max(0, origBar - 10);
    withMutatedJson(m => { m.team_machine_screen_stats.teams[0].eng_bar = newBar; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.team_machine_screen_stats.teams[0].eng_bar, newBar);
    });
  });

  test('D.tms_sentinel_unchanged', () => {
    const origBar = D.team_machine_screen_stats.teams[0].eng_bar;
    const newBar  = Math.max(0, origBar - 10);
    withMutatedJson(m => { m.team_machine_screen_stats.teams[0].eng_bar = newBar; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.deepStrictEqual(re.team_machine_screen_stats.sentinel,
        D.team_machine_screen_stats.sentinel);
    });
  });

  // D.6: modify post_race_driver_target_points promote_threshold team 0
  test('D.post_race_mutated', () => {
    const origThresh = D.post_race_driver_target_points[0].promote_threshold;
    const newThresh  = (origThresh + 1) % 256;
    withMutatedJson(m => { m.post_race_driver_target_points[0].promote_threshold = newThresh; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.post_race_driver_target_points[0].promote_threshold, newThresh);
    });
  });

  // D.7: modify acceleration_modifiers[2]
  test('D.accel_mod_mutated', () => {
    const origAcm = D.acceleration_modifiers[2];
    const newAcm  = origAcm + 1;
    withMutatedJson(m => { m.acceleration_modifiers[2] = newAcm; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.acceleration_modifiers[2], newAcm);
    });
  });

  for (const i of [0, 1, 3]) {
    test(`D.accel_mod[${i}]_unchanged`, () => {
      const origAcm = D.acceleration_modifiers[2];
      withMutatedJson(m => { m.acceleration_modifiers[2] = origAcm + 1; }, (tmpJson, tmpRom) => {
        injectTeamData(tmpJson, tmpRom, false, false);
        const re = extractTeamData(tmpRom);
        assert.strictEqual(re.acceleration_modifiers[i], D.acceleration_modifiers[i]);
      });
    });
  }

  // D.8: team_palette_data _raw mutation for team 0, byte 0
  test('D.palette_raw_mutated', () => {
    const origRaw0 = D.team_palette_data[0]._raw[0];
    const newRaw0  = (origRaw0 + 2) % 256;
    withMutatedJson(m => { m.team_palette_data[0]._raw[0] = newRaw0; }, (tmpJson, tmpRom) => {
      injectTeamData(tmpJson, tmpRom, false, false);
      const re = extractTeamData(tmpRom);
      assert.strictEqual(re.team_palette_data[0]._raw[0], newRaw0);
    });
  });
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
if (require.main === module) {
  console.log(`Results: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

module.exports = { passed, failed };
