// tools/randomizer/championship_randomizer.js
//
// RAND-009: Championship randomizer module.
//
// Randomizes championship progression data for Super Monaco GP.
// Reads tools/data/championship.json (produced by extract_championship_data.js).
//
// FLAG_CHAMPIONSHIP (0x10):
//   - Shuffle championship_track_order slots 0-14 (slot 15 / Monaco fixed)
//   - Shuffle rival_grid_base_table (Fisher-Yates on 16-entry pool)
//   - Lightly perturb rival_grid_delta_table entries (±1, 50% chance)
//   - Redistribute inner 14 pairs of pre_race_lap_time_offset_table
//
// Usage (standalone):
//   node tools/randomizer/championship_randomizer.js --seed SMGP-1-10-12345
//   node tools/randomizer/championship_randomizer.js --seed SMGP-1-10-12345 --verbose

'use strict';

const path = require('path');

const {
  XorShift32,
  deriveSubseed,
  parseSeed,
  MOD_CHAMPIONSHIP,
  FLAG_CHAMPIONSHIP,
} = require('./track_randomizer');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const NUM_CHAMPIONSHIP_TRACKS = 16;
const FIXED_FINAL_SLOT        = 15;

const RIVAL_BASE_MIN = 0;
const RIVAL_BASE_MAX = 15;

const RIVAL_DELTA_MIN   = -3;
const RIVAL_DELTA_MAX   = 2;
const RIVAL_DELTA_COUNT = 11;

const POINTS_COUNT = 6;
const POINTS_MIN   = 1;
const POINTS_MAX   = 20;

const LAP_TIME_TABLE_BYTES = 32;
const LAP_TIME_ENTRIES     = 16;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Fisher-Yates in-place shuffle using XorShift32 rng.
 * @param {any[]} lst
 * @param {XorShift32} rng
 */
function _shuffleListInPlace(lst, rng) {
  const n = lst.length;
  for (let i = n - 1; i > 0; i--) {
    const j = rng.next() % (i + 1);
    const tmp = lst[i];
    lst[i] = lst[j];
    lst[j] = tmp;
  }
}

// ---------------------------------------------------------------------------
// RAND-009 / FLAG_CHAMPIONSHIP: Championship randomizer
// ---------------------------------------------------------------------------

/**
 * Randomize championship progression data in-place.
 * @param {object} championshipData  - loaded from tools/data/championship.json (modified in-place)
 * @param {number} masterSeed        - integer master seed
 * @param {boolean} [verbose=false]
 */
function randomizeChampionship(championshipData, masterSeed, verbose = false) {
  const rng = new XorShift32(deriveSubseed(masterSeed, MOD_CHAMPIONSHIP));

  const trackOrder = championshipData._meta.championship_track_order;
  const rivalBase  = championshipData.rival_grid_base_table;
  const rivalDelta = championshipData.rival_grid_delta_table;
  const lapRaw     = championshipData.pre_race_lap_time_offset_table;

  // 1. Shuffle championship track order (slots 0-14, keep slot 15 fixed)
  if (trackOrder.length !== NUM_CHAMPIONSHIP_TRACKS) {
    throw new Error(
      `championship_track_order: expected ${NUM_CHAMPIONSHIP_TRACKS} entries, got ${trackOrder.length}`
    );
  }

  const oldOrder = trackOrder.slice();
  const movable  = trackOrder.slice(0, FIXED_FINAL_SLOT);  // slots 0-14
  _shuffleListInPlace(movable, rng);
  for (let i = 0; i < FIXED_FINAL_SLOT; i++) {
    trackOrder[i] = movable[i];
  }
  // slot 15 (Monaco) untouched

  if (verbose) {
    const changedSlots = [];
    for (let i = 0; i < FIXED_FINAL_SLOT; i++) {
      if (trackOrder[i] !== oldOrder[i]) changedSlots.push(i);
    }
    process.stdout.write(
      `  [CHAMPIONSHIP] Track order shuffled: ${changedSlots.length} of ${FIXED_FINAL_SLOT} movable slots changed.\n`
    );
    for (const i of changedSlots) {
      process.stdout.write(`    slot ${String(i).padStart(2)}: ${JSON.stringify(oldOrder[i])} -> ${JSON.stringify(trackOrder[i])}\n`);
    }
  }

  // 2. Shuffle rival_grid_base_table
  if (rivalBase.length !== NUM_CHAMPIONSHIP_TRACKS) {
    throw new Error(
      `rival_grid_base_table: expected ${NUM_CHAMPIONSHIP_TRACKS} entries, got ${rivalBase.length}`
    );
  }

  const oldBase = rivalBase.slice();
  _shuffleListInPlace(rivalBase, rng);

  if (verbose) {
    const changed = oldBase.reduce((n, v, i) => n + (v !== rivalBase[i] ? 1 : 0), 0);
    process.stdout.write(
      `  [CHAMPIONSHIP] rival_grid_base_table: ${changed} of ${NUM_CHAMPIONSHIP_TRACKS} entries shuffled.\n`
    );
  }

  // 3. Lightly perturb rival_grid_delta_table (±1, 50% chance, clamped)
  if (rivalDelta.length !== RIVAL_DELTA_COUNT) {
    throw new Error(
      `rival_grid_delta_table: expected ${RIVAL_DELTA_COUNT} entries, got ${rivalDelta.length}`
    );
  }

  const oldDelta = rivalDelta.slice();
  for (let i = 0; i < RIVAL_DELTA_COUNT; i++) {
    if (rng.next() % 2 === 0) {  // 50% chance
      const delta = (rng.next() % 2 === 0) ? 1 : -1;
      rivalDelta[i] = Math.max(RIVAL_DELTA_MIN, Math.min(RIVAL_DELTA_MAX, rivalDelta[i] + delta));
    }
  }

  if (verbose) {
    const changed = oldDelta.reduce((n, v, i) => n + (v !== rivalDelta[i] ? 1 : 0), 0);
    process.stdout.write(
      `  [CHAMPIONSHIP] rival_grid_delta_table: ${changed} of ${RIVAL_DELTA_COUNT} entries perturbed.\n`
    );
    for (let i = 0; i < RIVAL_DELTA_COUNT; i++) {
      if (oldDelta[i] !== rivalDelta[i]) {
        process.stdout.write(`    delta[${i}]: ${oldDelta[i]} -> ${rivalDelta[i]}\n`);
      }
    }
  }

  // 4. Redistribute inner 14 word pairs of pre_race_lap_time_offset_table
  if (lapRaw.length !== LAP_TIME_TABLE_BYTES) {
    throw new Error(
      `pre_race_lap_time_offset_table: expected ${LAP_TIME_TABLE_BYTES} bytes, got ${lapRaw.length}`
    );
  }

  const oldLap = lapRaw.slice();
  // Extract 14 inner pairs (indices 1-14, bytes 2-29)
  const innerPairs = [];
  for (let i = 0; i < 14; i++) {
    innerPairs.push([lapRaw[2 + i * 2], lapRaw[2 + i * 2 + 1]]);
  }
  _shuffleListInPlace(innerPairs, rng);
  for (let i = 0; i < 14; i++) {
    lapRaw[2 + i * 2]     = innerPairs[i][0];
    lapRaw[2 + i * 2 + 1] = innerPairs[i][1];
  }

  if (verbose) {
    const changed = oldLap.reduce((n, v, i) => n + (v !== lapRaw[i] ? 1 : 0), 0);
    process.stdout.write(
      `  [CHAMPIONSHIP] pre_race_lap_time_offset_table: ${changed} of ${LAP_TIME_TABLE_BYTES} bytes changed.\n`
    );
    process.stdout.write('  [CHAMPIONSHIP] Championship shuffle complete.\n');
  }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/**
 * Validate championship_data after randomization.
 * @param {object} championshipData
 * @returns {string[]}  error strings (empty = pass)
 */
function validateChampionship(championshipData) {
  const errors = [];

  // championship_track_order
  const trackOrder = (championshipData._meta || {}).championship_track_order || [];
  if (trackOrder.length !== NUM_CHAMPIONSHIP_TRACKS) {
    errors.push(`championship_track_order: expected ${NUM_CHAMPIONSHIP_TRACKS} entries, got ${trackOrder.length}`);
  } else {
    if (trackOrder[trackOrder.length - 1] !== 'Monaco') {
      errors.push(`championship_track_order: final slot must be Monaco, got ${JSON.stringify(trackOrder[trackOrder.length - 1])}`);
    }
    const seen = new Set();
    for (let i = 0; i < trackOrder.length; i++) {
      const name = trackOrder[i];
      if (typeof name !== 'string' || !name) {
        errors.push(`championship_track_order[${i}]: expected non-empty string, got ${JSON.stringify(name)}`);
      }
      if (seen.has(name)) {
        errors.push(`championship_track_order: duplicate track ${JSON.stringify(name)} at slot ${i}`);
      }
      seen.add(name);
    }
  }

  // rival_grid_base_table
  const rivalBase = championshipData.rival_grid_base_table || [];
  if (rivalBase.length !== NUM_CHAMPIONSHIP_TRACKS) {
    errors.push(`rival_grid_base_table: expected ${NUM_CHAMPIONSHIP_TRACKS} entries, got ${rivalBase.length}`);
  } else {
    for (let i = 0; i < rivalBase.length; i++) {
      const v = rivalBase[i];
      if (v < RIVAL_BASE_MIN || v > RIVAL_BASE_MAX) {
        errors.push(`rival_grid_base_table[${i}]=${v} out of range [${RIVAL_BASE_MIN}, ${RIVAL_BASE_MAX}]`);
      }
    }
  }

  // rival_grid_delta_table
  const rivalDelta = championshipData.rival_grid_delta_table || [];
  if (rivalDelta.length !== RIVAL_DELTA_COUNT) {
    errors.push(`rival_grid_delta_table: expected ${RIVAL_DELTA_COUNT} entries, got ${rivalDelta.length}`);
  } else {
    for (let i = 0; i < rivalDelta.length; i++) {
      const v = rivalDelta[i];
      if (v < RIVAL_DELTA_MIN || v > RIVAL_DELTA_MAX) {
        errors.push(`rival_grid_delta_table[${i}]=${v} out of range [${RIVAL_DELTA_MIN}, ${RIVAL_DELTA_MAX}]`);
      }
    }
  }

  // pre_race_lap_time_offset_table
  const lapRaw = championshipData.pre_race_lap_time_offset_table || [];
  if (lapRaw.length !== LAP_TIME_TABLE_BYTES) {
    errors.push(`pre_race_lap_time_offset_table: expected ${LAP_TIME_TABLE_BYTES} bytes, got ${lapRaw.length}`);
  } else {
    for (let i = 0; i < lapRaw.length; i++) {
      const v = lapRaw[i];
      if (v < 0 || v > 255) {
        errors.push(`pre_race_lap_time_offset_table[${i}]=${v} out of range [0, 255]`);
      }
    }
    if (lapRaw[lapRaw.length - 2] !== 0 || lapRaw[lapRaw.length - 1] !== 0) {
      errors.push(
        `pre_race_lap_time_offset_table: last two bytes must be 0x00 0x00, ` +
        `got 0x${lapRaw[lapRaw.length-2].toString(16).toUpperCase().padStart(2,'0')} ` +
        `0x${lapRaw[lapRaw.length-1].toString(16).toUpperCase().padStart(2,'0')}`
      );
    }
  }

  // points_awarded_per_placement
  const points = championshipData.points_awarded_per_placement || [];
  if (points.length !== POINTS_COUNT) {
    errors.push(`points_awarded_per_placement: expected ${POINTS_COUNT} entries, got ${points.length}`);
  } else {
    for (let i = 0; i < points.length; i++) {
      const v = points[i];
      if (v < POINTS_MIN || v > POINTS_MAX) {
        errors.push(`points_awarded_per_placement[${i}]=${v} out of range [${POINTS_MIN}, ${POINTS_MAX}]`);
      }
    }
    for (let i = 0; i < points.length - 1; i++) {
      if (points[i] <= points[i + 1]) {
        errors.push(`points_awarded_per_placement not strictly descending: [${i}]=${points[i]} <= [${i+1}]=${points[i+1]}`);
      }
    }
  }

  // post_race_driver_target_points
  const thresholds = championshipData.post_race_driver_target_points || [];
  if (thresholds.length !== 16) {
    errors.push(`post_race_driver_target_points: expected 16 entries, got ${thresholds.length}`);
  } else {
    for (const t of thresholds) {
      const promote = t.promote_threshold;
      const partner = t.partner_threshold;
      const team    = t.name || t.team || '?';
      if (promote < 0 || promote > 15) errors.push(`${team} promote_threshold=${promote} out of range [0, 15]`);
      if (partner < 0 || partner > 15) errors.push(`${team} partner_threshold=${partner} out of range [0, 15]`);
      if (partner < promote + 2) {
        errors.push(`${team} partner_threshold (${partner}) must be >= promote_threshold (${promote}) + 2`);
      }
    }
  }

  return errors;
}

// ---------------------------------------------------------------------------
// Standalone CLI
// ---------------------------------------------------------------------------

if (require.main === module) {
  const { parseArgs, die, info } = require('../lib/cli');
  const { readJson, writeJson } = require('../lib/json');
  const { REPO_ROOT } = require('../lib/rom');
  const fs = require('fs');

  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--dry-run', '--verbose', '-v'],
    options: ['--seed', '--input', '--output'],
  });

  const seedStr   = args.options['--seed'] || 'SMGP-1-10-12345';
  const inputRel  = args.options['--input'] || 'tools/data/championship.json';
  const outputRel = args.options['--output'];
  const verbose   = args.flags['--verbose'] || args.flags['-v'];
  const dryRun    = args.flags['--dry-run'];

  let version, flags, seedInt;
  try {
    [version, flags, seedInt] = parseSeed(seedStr);
  } catch (e) {
    die(e.message);
  }

  info(`Seed    : ${seedStr}`);
  info(`Version : ${version}`);
  info(`Flags   : 0x${flags.toString(16).toUpperCase().padStart(2,'0')}`);
  info(`Seed int: ${seedInt}`);

  if (!(flags & FLAG_CHAMPIONSHIP)) {
    info('FLAG_CHAMPIONSHIP (0x10) is not set — nothing to do.');
    process.exit(0);
  }

  const inputPath  = path.resolve(REPO_ROOT, inputRel);
  const outputPath = outputRel ? path.resolve(REPO_ROOT, outputRel) : inputPath;

  if (!fs.existsSync(inputPath)) die(`championship JSON not found: ${inputPath}`);

  const championshipData = readJson(inputPath);

  info('\n[FLAG_CHAMPIONSHIP] Randomizing championship progression ...');
  randomizeChampionship(championshipData, seedInt, verbose);

  const errors = validateChampionship(championshipData);
  if (errors.length > 0) {
    process.stderr.write(`\nValidation FAILED: ${errors.length} error(s):\n`);
    for (const e of errors) process.stderr.write(`  ${e}\n`);
    process.exit(1);
  }
  info('Validation passed.');

  if (dryRun) {
    info('\nDRY RUN — not writing output.');
    process.exit(0);
  }

  writeJson(outputPath, championshipData);
  info(`\nWritten: ${outputPath}`);
  info('Run node tools/inject_championship_data.js --rom out.bin then verify.');
}

module.exports = {
  randomizeChampionship,
  validateChampionship,
  NUM_CHAMPIONSHIP_TRACKS,
  FIXED_FINAL_SLOT,
  RIVAL_BASE_MIN,
  RIVAL_BASE_MAX,
  RIVAL_DELTA_MIN,
  RIVAL_DELTA_MAX,
  RIVAL_DELTA_COUNT,
  LAP_TIME_TABLE_BYTES,
};
