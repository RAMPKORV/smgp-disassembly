// tools/randomizer/team_randomizer.js
//
// RAND-008: Team/AI randomizer module.
//
// Randomizes team car-stats and AI difficulty parameters for Super Monaco GP.
// Reads tools/data/teams.json (produced by extract_team_data.js / EXTR-003).
//
// Two independent randomization modes:
//
//   FLAG_TEAMS (0x04) — Shuffle team car performance:
//       - Shuffle accel_index and engine_index assignments (Fisher-Yates)
//       - Lightly perturb steering_idx, steering_idx_b, braking_idx (40% chance)
//       - Shuffle tire_wear_multiplier assignments
//       - Re-derive team_machine_screen_stats bars
//
//   FLAG_AI (0x08) — Shuffle AI difficulty parameters:
//       - Shuffle ai_performance_factor values (Fisher-Yates)
//       - Shuffle ai_performance_table rows (Fisher-Yates on rows)
//       - Lightly perturb post_race_driver_target_points thresholds
//
// Usage (standalone):
//   node tools/randomizer/team_randomizer.js --seed SMGP-1-04-12345
//   node tools/randomizer/team_randomizer.js --seed SMGP-1-0C-12345 --verbose

'use strict';

const path = require('path');

const {
  XorShift32,
  deriveSubseed,
  parseSeed,
  MOD_TEAMS,
  MOD_AI,
  FLAG_TEAMS,
  FLAG_AI,
} = require('./track_randomizer');

// ---------------------------------------------------------------------------
// Constants derived from ROM data
// ---------------------------------------------------------------------------

const ACCEL_INDEX_POOL  = [0, 2, 4, 6];
const ENGINE_INDEX_POOL = [0, 2, 4, 6, 8, 10];

const STEERING_IDX_RANGE = [2, 10];
const BRAKING_IDX_RANGE  = [2, 10];

const TIRE_WEAR_POOL = [1, 2];

const AI_FACTOR_MIN = 1;
const AI_FACTOR_MAX = 15;

const AI_SCORE_MIN = 0;
const AI_SCORE_MAX = 9;

const TIRE_DELTA_MIN = 1;
const TIRE_DELTA_MAX = 5;

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

/**
 * Derive plausible machine-screen stat bars from car characteristics.
 * @param {object} car
 * @returns {[number, number, number, number, number]}  [eng_bar, tm_bar, sus_bar, tire_bar, bra_bar]
 */
function _deriveScreenStatsFromCar(car) {
  // accel_index: 0=worst, 6=best -> tm_bar 20..80
  const accelLevel = Math.floor(car.accel_index / 2);  // 0-3
  const tmBar = 20 + accelLevel * 20;                  // 20, 40, 60, 80

  // engine_index: 0=worst, 10=best -> eng_bar 20..100
  const engLevel = Math.floor(car.engine_index / 2);   // 0-5
  let engBar = 20 + engLevel * 16;                     // 20, 36, 52, 68, 84, 100 (approx)
  engBar = Math.min(100, Math.floor((engBar + 9) / 10) * 10);

  // braking_idx: higher -> better braking -> higher bra_bar
  let braBar = Math.min(100, Math.max(20, Math.floor(car.braking_idx / 2) * 20));
  braBar = Math.floor((braBar + 9) / 10) * 10;

  // steering_idx: higher -> better suspension handling -> sus_bar
  let susBar = Math.min(100, Math.max(20, Math.floor(car.steering_idx / 2) * 20));
  susBar = Math.floor((susBar + 9) / 10) * 10;

  // tire_bar: tire_wear_multiplier 1 = harder tires -> higher
  const tireBar = (car.tire_wear_multiplier === 1) ? 80 : 60;

  return [engBar, tmBar, susBar, tireBar, braBar];
}

// ---------------------------------------------------------------------------
// RAND-008 / FLAG_TEAMS: Car stats randomizer
// ---------------------------------------------------------------------------

/**
 * Randomize team car performance stats in-place.
 * @param {object} teamsData  - loaded from tools/data/teams.json (modified in-place)
 * @param {number} masterSeed - integer master seed
 * @param {boolean} [verbose=false]
 */
function randomizeTeams(teamsData, masterSeed, verbose = false) {
  const rng   = new XorShift32(deriveSubseed(masterSeed, MOD_TEAMS));
  const cars  = teamsData.team_car_characteristics;       // array of 16
  const tire  = teamsData.team_engine_multiplier;         // array of 16
  const stats = teamsData.team_machine_screen_stats.teams; // array of 16

  // 1. Shuffle accel_index assignments
  const accelPool = cars.map(c => c.accel_index);
  _shuffleListInPlace(accelPool, rng);
  for (let i = 0; i < cars.length; i++) {
    const old = cars[i].accel_index;
    cars[i].accel_index = accelPool[i];
    if (verbose && cars[i].accel_index !== old) {
      process.stdout.write(`  [TEAMS] ${cars[i].team} accel_index: ${old} -> ${cars[i].accel_index}\n`);
    }
  }

  // 2. Shuffle engine_index assignments
  const enginePool = cars.map(c => c.engine_index);
  _shuffleListInPlace(enginePool, rng);
  for (let i = 0; i < cars.length; i++) {
    const old = cars[i].engine_index;
    cars[i].engine_index = enginePool[i];
    if (verbose && cars[i].engine_index !== old) {
      process.stdout.write(`  [TEAMS] ${cars[i].team} engine_index: ${old} -> ${cars[i].engine_index}\n`);
    }
  }

  // 3. Lightly perturb steering_idx, steering_idx_b, braking_idx (40% chance ±2, keep even)
  for (const car of cars) {
    const fieldsRanges = [
      ['steering_idx',   STEERING_IDX_RANGE],
      ['steering_idx_b', STEERING_IDX_RANGE],
      ['braking_idx',    BRAKING_IDX_RANGE],
    ];
    for (const [field, [lo, hi]] of fieldsRanges) {
      const old = car[field];
      if (rng.next() % 100 < 40) {
        const step  = 2;
        const delta = (rng.next() % 2 === 0) ? step : -step;
        let nv = Math.max(lo, Math.min(hi, old + delta));
        nv = Math.floor(nv / 2) * 2;
        if (nv < lo) nv = lo;
        car[field] = nv;
      }
      if (verbose && car[field] !== old) {
        process.stdout.write(`  [TEAMS] ${car.team} ${field}: ${old} -> ${car[field]}\n`);
      }
    }
  }

  // 4. Shuffle tire_wear_multiplier pool
  const tirePool = tire.map(t => t.tire_wear_multiplier);
  _shuffleListInPlace(tirePool, rng);
  for (let i = 0; i < tire.length; i++) {
    const old = tire[i].tire_wear_multiplier;
    tire[i].tire_wear_multiplier = tirePool[i];
    cars[i].tire_wear_multiplier = tirePool[i];  // mirror into car for stat derivation
    if (verbose && tire[i].tire_wear_multiplier !== old) {
      process.stdout.write(`  [TEAMS] ${tire[i].team} tire_wear_multiplier: ${old} -> ${tire[i].tire_wear_multiplier}\n`);
    }
  }

  // 5. Re-derive machine-screen stats
  for (let i = 0; i < cars.length; i++) {
    const car  = cars[i];
    const stat = stats[i];
    const [engBar, tmBar, susBar, tireBar, braBar] = _deriveScreenStatsFromCar(car);
    stat.eng_bar  = engBar;
    stat.tm_bar   = tmBar;
    stat.sus_bar  = susBar;
    stat.tire_bar = tireBar;
    stat.bra_bar  = braBar;
    // Lightly randomize tire_wear_delta (±1, clamped to 1-5)
    const oldDelta = stat.tire_wear_delta;
    const delta = (rng.next() % 3) - 1;  // -1, 0, or +1
    stat.tire_wear_delta = Math.max(TIRE_DELTA_MIN, Math.min(TIRE_DELTA_MAX, oldDelta + delta));
    if (verbose) {
      process.stdout.write(
        `  [TEAMS] ${stat.team} screen stats: eng=${engBar} tm=${tmBar} ` +
        `sus=${susBar} tire=${tireBar} bra=${braBar} delta=${stat.tire_wear_delta}\n`
      );
    }
  }

  if (verbose) process.stdout.write('  [TEAMS] Car stats shuffle complete.\n');
}

// ---------------------------------------------------------------------------
// RAND-008 / FLAG_AI: AI difficulty randomizer
// ---------------------------------------------------------------------------

/**
 * Randomize AI placement parameters in-place.
 * @param {object} teamsData  - loaded from tools/data/teams.json (modified in-place)
 * @param {number} masterSeed - integer master seed
 * @param {boolean} [verbose=false]
 */
function randomizeAi(teamsData, masterSeed, verbose = false) {
  const rng        = new XorShift32(deriveSubseed(masterSeed, MOD_AI));
  const factors    = teamsData.ai_performance_factor;          // array of 16
  const table      = teamsData.ai_performance_table;           // array of 16
  const thresholds = teamsData.post_race_driver_target_points; // array of 16

  // 1. Shuffle ai_performance_factor values
  const factorPool = factors.map(f => f.factor);
  _shuffleListInPlace(factorPool, rng);
  for (let i = 0; i < factors.length; i++) {
    const old = factors[i].factor;
    factors[i].factor = factorPool[i];
    if (verbose && factors[i].factor !== old) {
      process.stdout.write(`  [AI] ${factors[i].team} ai_factor: ${old} -> ${factors[i].factor}\n`);
    }
  }

  // 2. Shuffle ai_performance_table rows
  const scoreRows = table.map(t => t.entries.slice());  // deep copy rows
  _shuffleListInPlace(scoreRows, rng);
  for (let i = 0; i < table.length; i++) {
    const old = table[i].entries;
    table[i].entries = scoreRows[i];
    if (verbose && JSON.stringify(table[i].entries) !== JSON.stringify(old)) {
      process.stdout.write(`  [AI] ${table[i].team} ai_table row: [${old}] -> [${table[i].entries}]\n`);
    }
  }

  // 3. Lightly perturb post-race driver target point thresholds
  for (const t of thresholds) {
    const oldPromote = t.promote_threshold;
    const oldPartner = t.partner_threshold;
    if (rng.next() % 2 === 0) {  // 50% chance
      const delta      = (rng.next() % 2 === 0) ? 1 : -1;
      const newPromote = Math.max(1, Math.min(10, oldPromote + delta));
      const newPartner = Math.max(newPromote + 2, Math.min(15, oldPartner + delta));
      t.promote_threshold = newPromote;
      t.partner_threshold = newPartner;
      if (verbose && (newPromote !== oldPromote || newPartner !== oldPartner)) {
        process.stdout.write(
          `  [AI] ${t.team || '?'} thresholds: promote ${oldPromote}->${newPromote}  partner ${oldPartner}->${newPartner}\n`
        );
      }
    }
  }

  if (verbose) process.stdout.write('  [AI] AI parameter shuffle complete.\n');
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

const VALID_ACCEL_INDICES  = new Set([0, 2, 4, 6]);
const VALID_ENGINE_INDICES = new Set([0, 2, 4, 6, 8, 10]);

/**
 * Validate teams_data after randomization.
 * @param {object} teamsData
 * @returns {string[]}  error strings (empty = pass)
 */
function validateTeams(teamsData) {
  const errors     = [];
  const cars       = teamsData.team_car_characteristics || [];
  const tire       = teamsData.team_engine_multiplier || [];
  const factors    = teamsData.ai_performance_factor || [];
  const table      = teamsData.ai_performance_table || [];
  const thresholds = teamsData.post_race_driver_target_points || [];
  const statsData  = teamsData.team_machine_screen_stats || {};
  const stats      = statsData.teams || [];
  const points     = teamsData.points_awarded_per_placement || [];

  if (cars.length !== 16)       errors.push(`team_car_characteristics: expected 16 entries, got ${cars.length}`);
  if (tire.length !== 16)       errors.push(`team_engine_multiplier: expected 16 entries, got ${tire.length}`);
  if (factors.length !== 16)    errors.push(`ai_performance_factor: expected 16 entries, got ${factors.length}`);
  if (table.length !== 16)      errors.push(`ai_performance_table: expected 16 entries, got ${table.length}`);
  if (thresholds.length !== 16) errors.push(`post_race_driver_target_points: expected 16 entries, got ${thresholds.length}`);
  if (stats.length !== 16)      errors.push(`team_machine_screen_stats.teams: expected 16 entries, got ${stats.length}`);

  for (let i = 0; i < cars.length; i++) {
    const car  = cars[i];
    const team = car.team || String(i);
    if (!VALID_ACCEL_INDICES.has(car.accel_index)) {
      errors.push(`${team} accel_index ${car.accel_index} not in {${[...VALID_ACCEL_INDICES].join(',')}}`);
    }
    if (!VALID_ENGINE_INDICES.has(car.engine_index)) {
      errors.push(`${team} engine_index ${car.engine_index} not in {${[...VALID_ENGINE_INDICES].join(',')}}`);
    }
    const [sLo, sHi] = STEERING_IDX_RANGE;
    for (const field of ['steering_idx', 'steering_idx_b']) {
      const v = car[field];
      if (v < sLo || v > sHi) errors.push(`${team} ${field}=${v} out of range [${sLo}, ${sHi}]`);
    }
    const [bLo, bHi] = BRAKING_IDX_RANGE;
    const bv = car.braking_idx;
    if (bv < bLo || bv > bHi) errors.push(`${team} braking_idx=${bv} out of range [${bLo}, ${bHi}]`);
  }

  for (let i = 0; i < tire.length; i++) {
    const t    = tire[i];
    const team = t.team || String(i);
    if (!TIRE_WEAR_POOL.includes(t.tire_wear_multiplier)) {
      errors.push(`${team} tire_wear_multiplier ${t.tire_wear_multiplier} not in [${TIRE_WEAR_POOL.join(',')}]`);
    }
  }

  for (let i = 0; i < factors.length; i++) {
    const f    = factors[i];
    const team = f.team || String(i);
    if (f.factor < AI_FACTOR_MIN || f.factor > AI_FACTOR_MAX) {
      errors.push(`${team} ai_factor=${f.factor} out of range [${AI_FACTOR_MIN}, ${AI_FACTOR_MAX}]`);
    }
  }

  for (let i = 0; i < table.length; i++) {
    const t       = table[i];
    const team    = t.team || String(i);
    const entries = t.entries || [];
    if (entries.length !== 8) {
      errors.push(`${team} ai_table: expected 8 entries, got ${entries.length}`);
    }
    for (let j = 0; j < entries.length; j++) {
      const v = entries[j];
      if (v < AI_SCORE_MIN || v > AI_SCORE_MAX) {
        errors.push(`${team} ai_table[${j}]=${v} out of range [${AI_SCORE_MIN}, ${AI_SCORE_MAX}]`);
      }
    }
  }

  for (let i = 0; i < thresholds.length; i++) {
    const t       = thresholds[i];
    const team    = t.team || String(i);
    const promote = t.promote_threshold;
    const partner = t.partner_threshold;
    if (promote < 0 || promote > 15) errors.push(`${team} promote_threshold=${promote} out of range [0, 15]`);
    if (partner < 0 || partner > 15) errors.push(`${team} partner_threshold=${partner} out of range [0, 15]`);
    if (partner < promote + 2) {
      errors.push(`${team} partner_threshold (${partner}) must be >= promote_threshold (${promote}) + 2`);
    }
  }

  for (let i = 0; i < stats.length; i++) {
    const stat = stats[i];
    const team = stat.team || String(i);
    for (const field of ['eng_bar', 'tm_bar', 'sus_bar', 'tire_bar', 'bra_bar']) {
      const v = stat[field];
      if (v < 0 || v > 100) errors.push(`${team} ${field}=${v} out of range [0, 100]`);
    }
    const dv = stat.tire_wear_delta;
    if (dv < TIRE_DELTA_MIN || dv > TIRE_DELTA_MAX) {
      errors.push(`${team} tire_wear_delta=${dv} out of range [${TIRE_DELTA_MIN}, ${TIRE_DELTA_MAX}]`);
    }
  }

  // Points must be strictly descending and all >= 1
  for (let i = 0; i < points.length - 1; i++) {
    if (points[i] <= points[i + 1]) {
      errors.push(`points_awarded_per_placement not strictly descending: [${i}]=${points[i]} <= [${i+1}]=${points[i+1]}`);
    }
  }
  for (let i = 0; i < points.length; i++) {
    if (points[i] < 1) errors.push(`points_awarded_per_placement[${i}]=${points[i]} must be >= 1`);
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

  const seedStr   = args.options['--seed'] || 'SMGP-1-04-12345';
  const inputRel  = args.options['--input'] || 'tools/data/teams.json';
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

  if (!(flags & (FLAG_TEAMS | FLAG_AI))) {
    info('Neither FLAG_TEAMS (0x04) nor FLAG_AI (0x08) is set — nothing to do.');
    process.exit(0);
  }

  const inputPath  = path.resolve(REPO_ROOT, inputRel);
  const outputPath = outputRel ? path.resolve(REPO_ROOT, outputRel) : inputPath;

  if (!fs.existsSync(inputPath)) die(`teams JSON not found: ${inputPath}`);

  const teamsData = readJson(inputPath);

  if (flags & FLAG_TEAMS) {
    info('\n[FLAG_TEAMS] Randomizing team car stats ...');
    randomizeTeams(teamsData, seedInt, verbose);
  }

  if (flags & FLAG_AI) {
    info('\n[FLAG_AI] Randomizing AI parameters ...');
    randomizeAi(teamsData, seedInt, verbose);
  }

  const errors = validateTeams(teamsData);
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

  writeJson(outputPath, teamsData);
  info(`\nWritten: ${outputPath}`);
  info('Run node tools/inject_team_data.js --rom out.bin then verify.');
}

module.exports = {
  randomizeTeams,
  randomizeAi,
  validateTeams,
  ACCEL_INDEX_POOL,
  ENGINE_INDEX_POOL,
  STEERING_IDX_RANGE,
  BRAKING_IDX_RANGE,
  TIRE_WEAR_POOL,
  AI_FACTOR_MIN,
  AI_FACTOR_MAX,
  AI_SCORE_MIN,
  AI_SCORE_MAX,
  TIRE_DELTA_MIN,
  TIRE_DELTA_MAX,
};
