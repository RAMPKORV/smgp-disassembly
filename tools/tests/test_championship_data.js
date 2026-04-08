#!/usr/bin/env node
// tools/tests/test_championship_data.js
//
// Tests for EXTR-006 (extract_championship_data.js + inject_championship_data.js).
//
// Sections:
//   A. JSON structure validation — all expected keys/types present and counts correct
//   B. Table content sanity — value ranges and internal consistency
//   C. No-op round-trip — inject(championship.json, out.bin) changes 0 bytes
//   D. Mutation round-trip — modify a value, inject, re-extract, verify value changed
//
// Run from repo root:
//   node tools/tests/test_championship_data.js [-v]
//
// Exit 0 = all tests pass.
// Exit 1 = one or more failures.

'use strict';

const assert = require('assert');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');

const { extractChampionshipData } = require('../extract_championship_data');
const { injectChampionshipData  } = require('../inject_championship_data');

const { REPO_ROOT } = require('../lib/rom');
const CHAMP_JSON = path.join(REPO_ROOT, 'tools', 'data', 'championship.json');
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
// Load championship.json once for structure/sanity tests
// ---------------------------------------------------------------------------
if (!fs.existsSync(CHAMP_JSON)) {
  test('championship_json_exists', () => {
    throw new Error(`${CHAMP_JSON} not found — run extract_championship_data.js first`);
  });
  if (require.main === module) {
    console.log(`Results: ${passed} passed, ${failed} failed`);
    process.exit(1);
  }
}

const CHAMP = JSON.parse(fs.readFileSync(CHAMP_JSON, 'utf8'));

// ===========================================================================
// Section A: JSON structure validation
// ===========================================================================

console.log('Section A: JSON structure validation');

// Top-level keys
const TOP_KEYS = [
  '_meta',
  'points_awarded_per_placement',
  'post_race_driver_target_points',
  'ai_performance_factor_by_team',
  'ai_performance_table',
  'initial_drivers_and_team_map',
  'second_year_drivers_and_teams_map',
  'rival_grid_base_table',
  'rival_grid_delta_table',
  'ai_placement_data',
  'ai_placement_data_easy',
  'ai_placement_data_champ',
  'ai_placement_champ_offsets',
  'pre_race_lap_time_offset_table',
];
for (const k of TOP_KEYS) {
  test(`A.top_key/${k}`, () => {
    assert.ok(k in CHAMP, `missing key '${k}'`);
  });
}

// _meta sub-keys
for (const mk of ['source', 'rom', 'description', 'championship_track_order', 'team_names']) {
  test(`A.meta/${mk}`, () => {
    assert.ok(mk in CHAMP['_meta'], `_meta missing key '${mk}'`);
  });
}

// championship_track_order: 16 entries
test('A.championship_track_order/len', () => {
  assert.strictEqual(CHAMP['_meta']['championship_track_order'].length, 16);
});

// team_names: 16 entries
test('A.team_names/len', () => {
  assert.strictEqual(CHAMP['_meta']['team_names'].length, 16);
});

// points_awarded_per_placement: list of 6 ints
test('A.points_awarded/type', () => {
  assert.ok(Array.isArray(CHAMP['points_awarded_per_placement']));
});
test('A.points_awarded/len', () => {
  assert.strictEqual(CHAMP['points_awarded_per_placement'].length, 6);
});

// post_race_driver_target_points: 16 entries with expected keys
const prdtp = CHAMP['post_race_driver_target_points'];
test('A.post_race_targets/len', () => {
  assert.strictEqual(prdtp.length, 16);
});
for (const k of ['team', 'name', 'promote_threshold', 'partner_threshold']) {
  test(`A.post_race_targets[0]/${k}`, () => {
    assert.ok(k in prdtp[0], `missing key '${k}' in post_race_driver_target_points[0]`);
  });
}

// ai_performance_factor_by_team: list of 16 ints
test('A.ai_perf_factor/type', () => {
  assert.ok(Array.isArray(CHAMP['ai_performance_factor_by_team']));
});
test('A.ai_perf_factor/len', () => {
  assert.strictEqual(CHAMP['ai_performance_factor_by_team'].length, 16);
});

// ai_performance_table: 16 entries, each with team/name/scores[8]
const apt = CHAMP['ai_performance_table'];
test('A.ai_perf_table/len', () => {
  assert.strictEqual(apt.length, 16);
});
for (const k of ['team', 'name', 'scores']) {
  test(`A.ai_perf_table[0]/${k}`, () => {
    assert.ok(k in apt[0], `missing key '${k}' in ai_performance_table[0]`);
  });
}
test('A.ai_perf_table[0]/scores/len', () => {
  assert.strictEqual(apt[0]['scores'].length, 8);
});

// initial_drivers_and_team_map
const idtm = CHAMP['initial_drivers_and_team_map'];
for (const k of ['player_team_raw', 'driver_team_map', 'rival_team_raw']) {
  test(`A.initial_driver_map/${k}`, () => {
    assert.ok(k in idtm, `missing key '${k}' in initial_drivers_and_team_map`);
  });
}
test('A.initial_driver_map/driver_team_map/len', () => {
  assert.strictEqual(idtm['driver_team_map'].length, 16);
});

// second_year_drivers_and_teams_map
const sytm = CHAMP['second_year_drivers_and_teams_map'];
for (const k of ['player_team_raw', 'driver_team_map', 'rival_team_raw']) {
  test(`A.second_year_map/${k}`, () => {
    assert.ok(k in sytm, `missing key '${k}' in second_year_drivers_and_teams_map`);
  });
}
test('A.second_year_map/driver_team_map/len', () => {
  assert.strictEqual(sytm['driver_team_map'].length, 16);
});

// rival_grid_base_table: list of 16 ints
test('A.rival_grid_base/len', () => {
  assert.strictEqual(CHAMP['rival_grid_base_table'].length, 16);
});

// rival_grid_delta_table: list of 11 ints
test('A.rival_grid_delta/len', () => {
  assert.strictEqual(CHAMP['rival_grid_delta_table'].length, 11);
});

// ai_placement_data: cars (15), sentinel
const apd = CHAMP['ai_placement_data'];
for (const k of ['cars', 'sentinel']) {
  test(`A.ai_placement_data/${k}`, () => {
    assert.ok(k in apd, `missing key '${k}' in ai_placement_data`);
  });
}
test('A.ai_placement_data/cars/len', () => {
  assert.strictEqual(apd['cars'].length, 15);
});
for (const k of ['speed_hi', 'speed_lo', 'accel_hi', 'accel_lo', 'brake']) {
  test(`A.ai_placement_data/cars[0]/${k}`, () => {
    assert.ok(k in apd['cars'][0], `missing key '${k}' in ai_placement_data.cars[0]`);
  });
}

// ai_placement_data_easy: header_record, cars (15), sentinel
const apde = CHAMP['ai_placement_data_easy'];
for (const k of ['header_record', 'cars', 'sentinel']) {
  test(`A.ai_placement_easy/${k}`, () => {
    assert.ok(k in apde, `missing key '${k}' in ai_placement_data_easy`);
  });
}
test('A.ai_placement_easy/cars/len', () => {
  assert.strictEqual(apde['cars'].length, 15);
});

// ai_placement_data_champ: records (16), trailing_words_raw (48 bytes)
const apdc = CHAMP['ai_placement_data_champ'];
for (const k of ['records', 'trailing_words_raw']) {
  test(`A.ai_placement_champ/${k}`, () => {
    assert.ok(k in apdc, `missing key '${k}' in ai_placement_data_champ`);
  });
}
test('A.ai_placement_champ/records/len', () => {
  assert.strictEqual(apdc['records'].length, 16);
});
test('A.ai_placement_champ/trailing_words_raw/len', () => {
  assert.strictEqual(apdc['trailing_words_raw'].length, 48);
});

// ai_placement_champ_offsets: 32 pairs of 2 ints
const apco = CHAMP['ai_placement_champ_offsets'];
test('A.ai_placement_champ_offsets/len', () => {
  assert.strictEqual(apco.length, 32);
});
test('A.ai_placement_champ_offsets[0]/len', () => {
  assert.strictEqual(apco[0].length, 2);
});

// pre_race_lap_time_offset_table: 32 raw bytes
test('A.pre_race_lap_time/len', () => {
  assert.strictEqual(CHAMP['pre_race_lap_time_offset_table'].length, 32);
});

// ===========================================================================
// Section B: Table content sanity
// ===========================================================================

console.log('Section B: Table content sanity');

// points_awarded_per_placement: in 0-255
const pts = CHAMP['points_awarded_per_placement'];
for (let i = 0; i < pts.length; i++) {
  test(`B.points_awarded[${i}]/range`, () => {
    assert.ok(pts[i] >= 0 && pts[i] <= 255,
      `pts[${i}]=${pts[i]} not in [0, 255]`);
  });
}
// non-increasing
for (let i = 0; i < pts.length - 1; i++) {
  test(`B.points_awarded/non_increasing/${i}`, () => {
    assert.ok(pts[i] >= pts[i + 1],
      `pts[${i}]=${pts[i]} < pts[${i + 1}]=${pts[i + 1]}: not non-increasing`);
  });
}

// post_race_driver_target_points: all in 0-255, partner >= promote
for (const entry of CHAMP['post_race_driver_target_points']) {
  const i = entry['team'];
  test(`B.post_race[${i}]/promote`, () => {
    assert.ok(entry['promote_threshold'] >= 0 && entry['promote_threshold'] <= 255,
      `promote_threshold=${entry['promote_threshold']} not in [0, 255]`);
  });
  test(`B.post_race[${i}]/partner`, () => {
    assert.ok(entry['partner_threshold'] >= 0 && entry['partner_threshold'] <= 255,
      `partner_threshold=${entry['partner_threshold']} not in [0, 255]`);
  });
  test(`B.post_race[${i}]/partner_ge_promote`, () => {
    assert.ok(entry['partner_threshold'] >= entry['promote_threshold'],
      `partner=${entry['partner_threshold']} < promote=${entry['promote_threshold']}`);
  });
}

// ai_performance_factor_by_team: valid byte values
for (let i = 0; i < CHAMP['ai_performance_factor_by_team'].length; i++) {
  const v = CHAMP['ai_performance_factor_by_team'][i];
  test(`B.ai_perf_factor[${i}]`, () => {
    assert.ok(v >= 0 && v <= 255, `ai_performance_factor_by_team[${i}]=${v} not in [0, 255]`);
  });
}

// ai_performance_table: each score 0-255
for (const entry of CHAMP['ai_performance_table']) {
  const i = entry['team'];
  const scores = entry['scores'];
  for (let j = 0; j < scores.length; j++) {
    test(`B.ai_perf_table[${i}][${j}]`, () => {
      assert.ok(scores[j] >= 0 && scores[j] <= 255,
        `ai_performance_table[${i}][${j}]=${scores[j]} not in [0, 255]`);
    });
  }
}

// rival_grid_base_table: valid byte values
for (let i = 0; i < CHAMP['rival_grid_base_table'].length; i++) {
  const v = CHAMP['rival_grid_base_table'][i];
  test(`B.rival_grid_base[${i}]`, () => {
    assert.ok(v >= 0 && v <= 255, `rival_grid_base_table[${i}]=${v} not in [0, 255]`);
  });
}

// rival_grid_delta_table: valid signed byte range
for (let i = 0; i < CHAMP['rival_grid_delta_table'].length; i++) {
  const v = CHAMP['rival_grid_delta_table'][i];
  test(`B.rival_grid_delta[${i}]`, () => {
    assert.ok(v >= -128 && v <= 127,
      `rival_grid_delta_table[${i}]=${v} not in [-128, 127]`);
  });
}

// ai_placement_data: speed/accel/brake byte ranges
for (let i = 0; i < CHAMP['ai_placement_data']['cars'].length; i++) {
  const car = CHAMP['ai_placement_data']['cars'][i];
  for (const field of ['speed_hi', 'speed_lo', 'accel_hi', 'accel_lo', 'brake']) {
    test(`B.ai_placement[${i}]/${field}`, () => {
      assert.ok(car[field] >= 0 && car[field] <= 255,
        `ai_placement_data.cars[${i}].${field}=${car[field]} not in [0, 255]`);
    });
  }
}
test('B.ai_placement/sentinel', () => {
  const v = CHAMP['ai_placement_data']['sentinel'];
  assert.ok(v >= 0 && v <= 255, `sentinel=${v} not in [0, 255]`);
});

// ai_placement_data_easy: header + cars
const hdr = CHAMP['ai_placement_data_easy']['header_record'];
for (const field of ['speed_hi', 'speed_lo', 'accel_hi', 'accel_lo', 'brake']) {
  test(`B.ai_placement_easy/header/${field}`, () => {
    assert.ok(hdr[field] >= 0 && hdr[field] <= 255,
      `ai_placement_data_easy.header_record.${field}=${hdr[field]} not in [0, 255]`);
  });
}
for (let i = 0; i < CHAMP['ai_placement_data_easy']['cars'].length; i++) {
  const car = CHAMP['ai_placement_data_easy']['cars'][i];
  for (const field of ['speed_hi', 'speed_lo', 'accel_hi', 'accel_lo', 'brake']) {
    test(`B.ai_placement_easy[${i}]/${field}`, () => {
      assert.ok(car[field] >= 0 && car[field] <= 255,
        `ai_placement_data_easy.cars[${i}].${field}=${car[field]} not in [0, 255]`);
    });
  }
}

// ai_placement_data_champ: 16 records
for (let i = 0; i < CHAMP['ai_placement_data_champ']['records'].length; i++) {
  const rec = CHAMP['ai_placement_data_champ']['records'][i];
  for (const field of ['speed_hi', 'speed_lo', 'accel_hi', 'accel_lo', 'brake']) {
    test(`B.ai_placement_champ[${i}]/${field}`, () => {
      assert.ok(rec[field] >= 0 && rec[field] <= 255,
        `ai_placement_data_champ.records[${i}].${field}=${rec[field]} not in [0, 255]`);
    });
  }
}

// trailing_words_raw: all valid bytes
for (let i = 0; i < CHAMP['ai_placement_data_champ']['trailing_words_raw'].length; i++) {
  const v = CHAMP['ai_placement_data_champ']['trailing_words_raw'][i];
  test(`B.ai_placement_champ/trailing[${i}]`, () => {
    assert.ok(v >= 0 && v <= 255,
      `ai_placement_data_champ.trailing_words_raw[${i}]=${v} not in [0, 255]`);
  });
}

// ai_placement_champ_offsets: all signed bytes
for (let i = 0; i < CHAMP['ai_placement_champ_offsets'].length; i++) {
  const pair = CHAMP['ai_placement_champ_offsets'][i];
  for (let j = 0; j < pair.length; j++) {
    test(`B.ai_placement_champ_offsets[${i}][${j}]`, () => {
      assert.ok(pair[j] >= -128 && pair[j] <= 127,
        `ai_placement_champ_offsets[${i}][${j}]=${pair[j]} not in [-128, 127]`);
    });
  }
}

// pre_race_lap_time_offset_table: valid bytes
for (let i = 0; i < CHAMP['pre_race_lap_time_offset_table'].length; i++) {
  const v = CHAMP['pre_race_lap_time_offset_table'][i];
  test(`B.pre_race_lap_time[${i}]`, () => {
    assert.ok(v >= 0 && v <= 255,
      `pre_race_lap_time_offset_table[${i}]=${v} not in [0, 255]`);
  });
}

// team indices in post_race are 0-15 in order
for (const entry of CHAMP['post_race_driver_target_points']) {
  const i = entry['team'];
  test(`B.post_race[${i}]/team_index`, () => {
    assert.strictEqual(entry['team'], i);
  });
}

// team indices in ai_performance_table are 0-15 in order
for (const entry of CHAMP['ai_performance_table']) {
  const i = entry['team'];
  test(`B.ai_perf_table[${i}]/team_index`, () => {
    assert.strictEqual(entry['team'], i);
  });
}

// Known values from smgp.lst / source ASM cross-check
// PointsAwardedPerPlacement: 9, 6, 4, 3, 2, 1
test('B.points_awarded/known_1st', () => {
  assert.strictEqual(CHAMP['points_awarded_per_placement'][0], 9);
});
test('B.points_awarded/known_2nd', () => {
  assert.strictEqual(CHAMP['points_awarded_per_placement'][1], 6);
});
test('B.points_awarded/known_6th', () => {
  assert.strictEqual(CHAMP['points_awarded_per_placement'][5], 1);
});

// ai_placement_data sentinel must be 0x00
test('B.ai_placement/sentinel_zero', () => {
  assert.strictEqual(CHAMP['ai_placement_data']['sentinel'], 0);
});
test('B.ai_placement_easy/sentinel_zero', () => {
  assert.strictEqual(CHAMP['ai_placement_data_easy']['sentinel'], 0);
});

// ===========================================================================
// Section C: No-op round-trip
// ===========================================================================

console.log('Section C: No-op round-trip (inject changes 0 bytes)');

if (!fs.existsSync(OUT_BIN)) {
  test('C.no_op_roundtrip', () => {
    throw new Error(`out.bin not found: ${OUT_BIN}`);
  });
} else {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-'));
  try {
    const tmpRom = path.join(tmpDir, 'out.bin');
    fs.copyFileSync(OUT_BIN, tmpRom);

    test('C.no_op_roundtrip/bytes_changed', () => {
      const changed = injectChampionshipData(CHAMP_JSON, tmpRom, false, false);
      assert.strictEqual(changed, 0,
        `expected 0 bytes changed, got ${changed}`);
    });

    test('C.no_op_roundtrip/byte_identical', () => {
      const originalBytes = fs.readFileSync(OUT_BIN);
      const patchedBytes  = fs.readFileSync(tmpRom);
      assert.deepStrictEqual(patchedBytes, originalBytes,
        'ROM bytes differ after no-op inject');
    });
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

// ===========================================================================
// Section D: Mutation round-trip
// ===========================================================================

console.log('Section D: Mutation round-trip');

if (!fs.existsSync(ORIG_BIN)) {
  test('D.mutation_roundtrip', () => {
    throw new Error(`orig.bin not found: ${ORIG_BIN}`);
  });
} else {
  // --- Mutation 1: change first points value by +1 (wrap 255) ---
  {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-'));
    try {
      const tmpRom  = path.join(tmpDir, 'out.bin');
      const tmpJson = path.join(tmpDir, 'championship.json');
      fs.copyFileSync(ORIG_BIN, tmpRom);

      const mutated = JSON.parse(JSON.stringify(CHAMP));
      const origVal = mutated['points_awarded_per_placement'][0];
      const newVal  = (origVal + 1) & 0xFF;
      mutated['points_awarded_per_placement'][0] = newVal;
      fs.writeFileSync(tmpJson, JSON.stringify(mutated, null, 2), 'utf8');

      test('D.mutation/bytes_changed_nonzero', () => {
        const changed = injectChampionshipData(tmpJson, tmpRom, false, false);
        assert.ok(changed > 0, `expected >0 bytes changed, got ${changed}`);
      });

      const tmpReJson = path.join(tmpDir, 're.json');
      const reExtracted = extractChampionshipData(tmpRom, tmpReJson);

      test('D.mutation/points_awarded[0]', () => {
        assert.strictEqual(reExtracted['points_awarded_per_placement'][0], newVal);
      });
      for (let i = 1; i < 6; i++) {
        const orig = CHAMP['points_awarded_per_placement'][i];
        const idx  = i;
        test(`D.mutation/points_awarded[${idx}]/unchanged`, () => {
          assert.strictEqual(reExtracted['points_awarded_per_placement'][idx], orig);
        });
      }
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }

  // --- Mutation 2: change AI performance factor for team 0 ---
  {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-'));
    try {
      const tmpRom  = path.join(tmpDir, 'out.bin');
      const tmpJson = path.join(tmpDir, 'championship.json');
      fs.copyFileSync(ORIG_BIN, tmpRom);

      const mutated   = JSON.parse(JSON.stringify(CHAMP));
      const origFactor = mutated['ai_performance_factor_by_team'][0];
      const newFactor  = (origFactor + 5) & 0xFF;
      mutated['ai_performance_factor_by_team'][0] = newFactor;
      fs.writeFileSync(tmpJson, JSON.stringify(mutated, null, 2), 'utf8');

      injectChampionshipData(tmpJson, tmpRom, false, false);
      const tmpReJson   = path.join(tmpDir, 're.json');
      const reExtracted = extractChampionshipData(tmpRom, tmpReJson);

      test('D.mutation/ai_perf_factor[0]', () => {
        assert.strictEqual(reExtracted['ai_performance_factor_by_team'][0], newFactor);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }

  // --- Mutation 3: change promote_threshold for team 5 ---
  {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-'));
    try {
      const tmpRom  = path.join(tmpDir, 'out.bin');
      const tmpJson = path.join(tmpDir, 'championship.json');
      fs.copyFileSync(ORIG_BIN, tmpRom);

      const mutated   = JSON.parse(JSON.stringify(CHAMP));
      const origThresh = mutated['post_race_driver_target_points'][5]['promote_threshold'];
      const newThresh  = Math.max(origThresh - 1, 0);
      mutated['post_race_driver_target_points'][5]['promote_threshold'] = newThresh;
      fs.writeFileSync(tmpJson, JSON.stringify(mutated, null, 2), 'utf8');

      injectChampionshipData(tmpJson, tmpRom, false, false);
      const tmpReJson   = path.join(tmpDir, 're.json');
      const reExtracted = extractChampionshipData(tmpRom, tmpReJson);

      test('D.mutation/post_race_promote[5]', () => {
        assert.strictEqual(
          reExtracted['post_race_driver_target_points'][5]['promote_threshold'],
          newThresh
        );
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }

  // --- Mutation 4: change rival_grid_delta[0] ---
  {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-'));
    try {
      const tmpRom  = path.join(tmpDir, 'out.bin');
      const tmpJson = path.join(tmpDir, 'championship.json');
      fs.copyFileSync(ORIG_BIN, tmpRom);

      const mutated  = JSON.parse(JSON.stringify(CHAMP));
      const origDelta = mutated['rival_grid_delta_table'][0];
      const newDelta  = origDelta < 127 ? origDelta + 1 : origDelta - 1;
      mutated['rival_grid_delta_table'][0] = newDelta;
      fs.writeFileSync(tmpJson, JSON.stringify(mutated, null, 2), 'utf8');

      injectChampionshipData(tmpJson, tmpRom, false, false);
      const tmpReJson   = path.join(tmpDir, 're.json');
      const reExtracted = extractChampionshipData(tmpRom, tmpReJson);

      test('D.mutation/rival_grid_delta[0]', () => {
        assert.strictEqual(reExtracted['rival_grid_delta_table'][0], newDelta);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }
}

// ===========================================================================
// Section E: Binary layer (dumpChampionshipBinaries / loadChampionshipBinaries / verifyChampionshipBinaries)
// ===========================================================================

console.log('Section E: Binary layer — dump / load / verify');

{
  const os = require('os');
  const { dumpChampionshipBinaries }                               = require('../extract_championship_data');
  const { loadChampionshipBinaries, verifyChampionshipBinaries }   = require('../inject_championship_data');
  const DATA_CHAMP = path.join(REPO_ROOT, 'data', 'championship');

  // E.1 — data/championship/ exists and contains 13 .bin files
  const TABLE_NAMES = [
    'PointsAwardedPerPlacement',
    'Post_race_driver_target_points',
    'Ai_performance_factor_by_team',
    'Ai_performance_table',
    'InitialDriversAndTeamMap',
    'SecondYearDriversAndTeamsMap',
    'Rival_grid_base_table',
    'Rival_grid_delta_table',
    'Ai_placement_data',
    'Ai_placement_data_easy',
    'Ai_placement_data_champ',
    'Ai_placement_champ_offsets',
    'Pre_race_lap_time_offset_table',
  ];
  const TABLE_SIZES_LOCAL = {
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

  test('E.data_dir_exists', () => {
    assert.ok(fs.existsSync(DATA_CHAMP), `data/championship/ does not exist: ${DATA_CHAMP}`);
  });

  for (const name of TABLE_NAMES) {
    const binFile = path.join(DATA_CHAMP, `${name}.bin`);
    test(`E.bin_exists/${name}`, () => {
      assert.ok(fs.existsSync(binFile), `Missing: ${binFile}`);
    });
    test(`E.bin_size/${name}`, () => {
      const buf = fs.readFileSync(binFile);
      assert.strictEqual(buf.length, TABLE_SIZES_LOCAL[name],
        `${name}.bin: expected ${TABLE_SIZES_LOCAL[name]} bytes, got ${buf.length}`);
    });
  }

  // E.2 — loadChampionshipBinaries reads them back correctly
  test('E.load_returns_map', () => {
    const m = loadChampionshipBinaries(DATA_CHAMP);
    assert.ok(m instanceof Map, 'loadChampionshipBinaries should return a Map');
    assert.strictEqual(m.size, TABLE_NAMES.length, `Expected ${TABLE_NAMES.length} entries in map`);
  });

  for (const name of TABLE_NAMES) {
    test(`E.load_size/${name}`, () => {
      const m = loadChampionshipBinaries(DATA_CHAMP);
      assert.strictEqual(m.get(name).length, TABLE_SIZES_LOCAL[name]);
    });
  }

  // E.3 — loadChampionshipBinaries throws on missing file
  test('E.load_throws_missing', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-load-'));
    try {
      assert.throws(
        () => loadChampionshipBinaries(tmpDir),
        /Missing championship binary/
      );
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  // E.4 — verifyChampionshipBinaries returns no mismatches against orig.bin
  if (fs.existsSync(ORIG_BIN)) {
    test('E.verify_no_mismatches', () => {
      const errors = verifyChampionshipBinaries(DATA_CHAMP, ORIG_BIN);
      assert.strictEqual(errors.length, 0,
        `verifyChampionshipBinaries returned mismatches: ${JSON.stringify(errors)}`);
    });
  }

  // E.5 — dumpChampionshipBinaries writes identical files to a temp dir
  if (fs.existsSync(ORIG_BIN)) {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-champ-dump-'));
    try {
      dumpChampionshipBinaries(ORIG_BIN, tmpDir, false);

      for (const name of TABLE_NAMES) {
        const srcFile = path.join(DATA_CHAMP, `${name}.bin`);
        const dstFile = path.join(tmpDir, `${name}.bin`);
        test(`E.dump_identical/${name}`, () => {
          assert.ok(fs.existsSync(dstFile), `Dump did not create ${name}.bin`);
          const src = fs.readFileSync(srcFile);
          const dst = fs.readFileSync(dstFile);
          assert.deepStrictEqual(dst, src,
            `Dumped ${name}.bin differs from data/championship/${name}.bin`);
        });
      }
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }
}

// ===========================================================================
// Results
// ===========================================================================

console.log();
console.log(`Results: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
