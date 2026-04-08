#!/usr/bin/env node
// tools/editor/team_editor.js
//
// NODE-005: Team editor CLI (JS port of tools/editor/team_editor.py)
//
// Argument-driven CLI for editing Super Monaco GP team and car data.  All
// edits operate on tools/data/teams.json (the structured edit layer), validate
// that changes stay within known-good ranges, then inject modified bytes to
// out.bin at known ROM addresses via inject_team_data.js.
//
// The editor NEVER touches src/*.asm files directly.
// Run verify.bat after inject to confirm the build is still bit-perfect (only
// meaningful against the unmodified ROM — see docs/modding_architecture.md).
//
// Usage:
//   node tools/editor/team_editor.js list-teams
//   node tools/editor/team_editor.js list-drivers
//   node tools/editor/team_editor.js show TEAM [--section car|ai|stats|all]
//   node tools/editor/team_editor.js show-engine VARIANT
//   node tools/editor/team_editor.js show-points
//   node tools/editor/team_editor.js show-accel
//
//   node tools/editor/team_editor.js set-ai-factor TEAM VALUE
//   node tools/editor/team_editor.js set-ai-table TEAM INDEX VALUE
//
//   node tools/editor/team_editor.js set-car TEAM [--accel-index N] [--engine-index N]
//                                                  [--steering N] [--steering-b N] [--braking N]
//   node tools/editor/team_editor.js set-engine VARIANT [--auto INDEX VALUE]
//                                                        [--four INDEX VALUE]
//                                                        [--seven INDEX VALUE]
//
//   node tools/editor/team_editor.js set-tire-wear TEAM VALUE
//   node tools/editor/team_editor.js set-stats TEAM [--eng N] [--tm N] [--sus N]
//                                                    [--tire N] [--bra N] [--tire-delta N]
//   node tools/editor/team_editor.js set-thresholds TEAM [--promote N] [--partner N]
//   node tools/editor/team_editor.js set-points INDEX VALUE
//   node tools/editor/team_editor.js set-accel-mod INDEX VALUE
//
//   node tools/editor/team_editor.js validate
//   node tools/editor/team_editor.js inject [--dry-run]
//
// TEAM argument: team index (0-15), name substring match (case-insensitive),
//                or exact team name slug (e.g. "madonna", "zero_force").

'use strict';

const fs   = require('fs');
const path = require('path');

const TOOLS_DIR  = path.resolve(__dirname, '..');
const REPO_ROOT  = path.resolve(TOOLS_DIR, '..');
const TEAMS_JSON = path.join(TOOLS_DIR, 'data', 'teams.json');
const OUT_BIN    = path.join(REPO_ROOT, 'out.bin');

const { injectTeamData } = require('../inject_team_data');

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------
function out(msg)  { process.stdout.write(msg + '\n'); }
function err(msg)  { process.stderr.write('ERROR: ' + msg + '\n'); }
function die(msg)  { err(msg); process.exit(1); }

// ---------------------------------------------------------------------------
// JSON load / save
// ---------------------------------------------------------------------------
function loadTeamsJson(jsonPath) {
  jsonPath = jsonPath || TEAMS_JSON;
  if (!fs.existsSync(jsonPath)) {
    die(`teams.json not found: ${jsonPath}\n  Run: node tools/extract_team_data.js`);
  }
  return JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
}

function saveTeamsJson(data, jsonPath) {
  jsonPath = jsonPath || TEAMS_JSON;
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// ---------------------------------------------------------------------------
// Team resolution
// ---------------------------------------------------------------------------
function resolveTeam(data, spec) {
  // Returns [index, teamName] or calls die()
  const teams = data.ai_performance_factor || [];

  // Integer index
  const asInt = parseInt(spec, 10);
  if (!isNaN(asInt) && String(asInt) === String(spec)) {
    if (asInt < 0 || asInt > 15) die(`Team index ${asInt} out of range 0-15`);
    return [asInt, teams[asInt].team];
  }

  const specLower = spec.toLowerCase().replace(/-/g, '_').replace(/ /g, '_');

  // Exact slug match
  for (let i = 0; i < teams.length; i++) {
    if (teams[i].team.toLowerCase().replace(/ /g, '_') === specLower) {
      return [i, teams[i].team];
    }
  }

  // Substring match
  const matches = teams
    .map((e, i) => ({ i, name: e.team }))
    .filter(({ name }) => name.toLowerCase().includes(specLower));

  if (matches.length === 1) return [matches[0].i, matches[0].name];
  if (matches.length > 1) {
    const desc = matches.map(m => `[${m.i}] ${m.name}`).join(', ');
    die(`Ambiguous TEAM ${JSON.stringify(spec)} — matches: ${desc}`);
  }

  die(`No team matching ${JSON.stringify(spec)}`);
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------
const ACCEL_VALID  = new Set([0, 2, 4, 6]);
const ENGINE_VALID = new Set([0, 2, 4, 6, 8, 10]);

function validateData(data) {
  const errors = [];

  // points_awarded_per_placement: 6 values, all positive, strictly descending
  const pts = data.points_awarded_per_placement || [];
  if (pts.length !== 6) {
    errors.push(`points_awarded_per_placement: expected 6 values, got ${pts.length}`);
  } else {
    for (let i = 0; i < pts.length; i++) {
      if (pts[i] < 1 || pts[i] > 255)
        errors.push(`points_awarded_per_placement[${i}]=${pts[i]}: must be 1-255`);
    }
    for (let i = 0; i < pts.length - 1; i++) {
      if (pts[i] <= pts[i + 1])
        errors.push(`points not strictly descending: pts[${i}]=${pts[i]} <= pts[${i+1}]=${pts[i+1]}`);
    }
  }

  // ai_performance_factor: 16 entries, factor 0-255
  for (const e of (data.ai_performance_factor || [])) {
    const f = e.factor;
    if (f < 0 || f > 255)
      errors.push(`ai_performance_factor[${e.team}].factor=${f}: must be 0-255`);
  }

  // ai_performance_table: 16 entries, 8 bytes each 0-255
  for (const e of (data.ai_performance_table || [])) {
    const entries = e.entries || [];
    for (let j = 0; j < entries.length; j++) {
      if (entries[j] < 0 || entries[j] > 255)
        errors.push(`ai_performance_table[${e.team}].entries[${j}]=${entries[j]}: must be 0-255`);
    }
  }

  // team_car_characteristics
  for (const e of (data.team_car_characteristics || [])) {
    const t = e.team;
    if (!ACCEL_VALID.has(e.accel_index))
      errors.push(`team_car_characteristics[${t}].accel_index=${e.accel_index}: must be one of [${[...ACCEL_VALID].sort((a,b)=>a-b).join(', ')}]`);
    if (!ENGINE_VALID.has(e.engine_index))
      errors.push(`team_car_characteristics[${t}].engine_index=${e.engine_index}: must be one of [${[...ENGINE_VALID].sort((a,b)=>a-b).join(', ')}]`);
    for (const fld of ['steering_idx', 'steering_idx_b', 'braking_idx']) {
      const v = e[fld];
      if (v < 0 || v > 255)
        errors.push(`team_car_characteristics[${t}].${fld}=${v}: must be 0-255`);
    }
  }

  // engine_data: 6 variants
  for (const e of (data.engine_data || [])) {
    const vi = e.variant;
    for (const [k, n] of [['auto_rpms', 4], ['four_shift_rpms', 4], ['seven_shift_rpms', 7]]) {
      const vals = e[k] || [];
      if (vals.length !== n)
        errors.push(`engine_data[${vi}].${k}: expected ${n} values, got ${vals.length}`);
      for (let j = 0; j < vals.length; j++) {
        if (vals[j] < 0 || vals[j] > 65535)
          errors.push(`engine_data[${vi}].${k}[${j}]=${vals[j]}: must be 0-65535`);
      }
    }
  }

  // team_engine_multiplier: 1 or 2
  for (const e of (data.team_engine_multiplier || [])) {
    const v = e.tire_wear_multiplier;
    if (v !== 1 && v !== 2)
      errors.push(`team_engine_multiplier[${e.team}].tire_wear_multiplier=${v}: must be 1 or 2`);
  }

  // team_machine_screen_stats
  const tms = data.team_machine_screen_stats || {};
  for (const t of (tms.teams || [])) {
    const team = t.team;
    for (const bar of ['eng_bar', 'tm_bar', 'sus_bar', 'tire_bar', 'bra_bar']) {
      const v = t[bar];
      if (v < 0 || v > 100)
        errors.push(`team_machine_screen_stats[${team}].${bar}=${v}: must be 0-100`);
    }
    const v = t.tire_wear_delta;
    if (v < 0 || v > 255)
      errors.push(`team_machine_screen_stats[${team}].tire_wear_delta=${v}: must be 0-255`);
  }

  // post_race_driver_target_points
  for (const e of (data.post_race_driver_target_points || [])) {
    const t = e.team;
    for (const fld of ['promote_threshold', 'partner_threshold']) {
      const v = e[fld];
      if (v < 0 || v > 255)
        errors.push(`post_race_driver_target_points[${t}].${fld}=${v}: must be 0-255`);
    }
  }

  // acceleration_modifiers: 4 signed 16-bit values
  for (let i = 0; i < (data.acceleration_modifiers || []).length; i++) {
    const v = data.acceleration_modifiers[i];
    if (v < -32768 || v > 32767)
      errors.push(`acceleration_modifiers[${i}]=${v}: must be -32768 to 32767`);
  }

  return errors;
}

// ---------------------------------------------------------------------------
// Display helpers
// ---------------------------------------------------------------------------
function teamRow(data, idx) {
  const af = data.ai_performance_factor[idx];
  const cc = data.team_car_characteristics[idx];
  const em = data.team_engine_multiplier[idx];
  return `[${String(idx).padStart(2)}] ${af.team.padEnd(12)}  ` +
    `ai_factor=${String(af.factor).padStart(3)}  ` +
    `engine_idx=${String(cc.engine_index).padStart(2)}  ` +
    `accel_idx=${cc.accel_index}  ` +
    `tire_wear_mult=${em.tire_wear_multiplier}`;
}

function showTeam(data, idx, section) {
  section = section || 'all';
  const af  = data.ai_performance_factor[idx];
  const at  = data.ai_performance_table[idx];
  const cc  = data.team_car_characteristics[idx];
  const em  = data.team_engine_multiplier[idx];
  const tms = data.team_machine_screen_stats.teams[idx];
  const pr  = data.post_race_driver_target_points[idx];
  const team = af.team;

  out(`Team [${idx}]: ${team}`);

  if (section === 'car' || section === 'all') {
    out('  Car characteristics:');
    out(`    accel_index   = ${cc.accel_index}  (byte offset into Acceleration_modifiers; entry ${cc.accel_index / 2})`);
    out(`    engine_index  = ${cc.engine_index}  (byte offset into Engine_data_offset_table; variant ${cc.engine_index / 2})`);
    out(`    steering_idx  = ${cc.steering_idx}`);
    out(`    steering_idx_b= ${cc.steering_idx_b}`);
    out(`    braking_idx   = ${cc.braking_idx}`);
    out(`  Tire wear multiplier: ${em.tire_wear_multiplier}`);
    out(`  Post-race thresholds: promote=${pr.promote_threshold}  partner=${pr.partner_threshold}`);
  }

  if (section === 'ai' || section === 'all') {
    out(`  AI performance factor: ${af.factor}`);
    out(`  AI performance table: [${at.entries.join(', ')}]`);
  }

  if (section === 'stats' || section === 'all') {
    out('  Machine screen stats:');
    out(`    ENG=${tms.eng_bar}  TM=${tms.tm_bar}  SUS=${tms.sus_bar}  TIRE=${tms.tire_bar}  BRA=${tms.bra_bar}  tire_wear_delta=${tms.tire_wear_delta}`);
  }
}

function showEngine(data, variant) {
  const e = (data.engine_data || []).find(x => x.variant === variant);
  if (!e) die(`No engine variant ${variant} (valid: 0-5)`);
  out(`Engine variant ${variant}:`);
  out(`  auto (4 gears):       [${e.auto_rpms.join(', ')}]`);
  out(`  four-shift (4 gears): [${e.four_shift_rpms.join(', ')}]`);
  out(`  seven-shift (7 gears):[${e.seven_shift_rpms.join(', ')}]`);
  const offset = variant * 2;
  const users = (data.team_car_characteristics || [])
    .filter(cc => cc.engine_index === offset)
    .map(cc => cc.team);
  out(`  Used by: ${users.length ? users.join(', ') : '(none)'}`);
}

// ---------------------------------------------------------------------------
// Subcommand handlers
// ---------------------------------------------------------------------------
function cmdListTeams(argv, data) {
  out('Teams (index, name, ai_factor, engine_index, accel_index, tire_wear_mult):');
  for (let i = 0; i < 16; i++) out('  ' + teamRow(data, i));
}

function cmdListDrivers(argv, data) {
  out('Drivers:');
  for (const e of data.driver_info_table) {
    out(`  [${String(e.index).padStart(2)}] driver=${e.driver || '?'}`);
  }
}

function cmdShow(argv, data) {
  const [idx] = resolveTeam(data, argv[0]);
  const section = getFlagValue(argv, '--section') || 'all';
  showTeam(data, idx, section);
}

function cmdShowEngine(argv, data) {
  const variant = parseInt(argv[0], 10);
  if (isNaN(variant)) die('VARIANT must be an integer 0-5');
  showEngine(data, variant);
}

function cmdShowPoints(argv, data) {
  const pts = data.points_awarded_per_placement;
  const places = ['1st', '2nd', '3rd', '4th', '5th', '6th'];
  out('Points awarded per placement:');
  for (let i = 0; i < pts.length; i++) {
    out(`  [${i}] ${places[i]}: ${pts[i]}`);
  }
}

function cmdShowAccel(argv, data) {
  const mods = data.acceleration_modifiers;
  out('Acceleration modifiers (signed 16-bit, byte-offset indexed):');
  for (let i = 0; i < mods.length; i++) {
    const offset = i * 2;
    const users = (data.team_car_characteristics || [])
      .filter(cc => cc.accel_index === offset)
      .map(cc => cc.team);
    out(`  [${i}] offset=${offset}  value=${mods[i]}  used_by=${users.length ? users.join(', ') : '(none)'}`);
  }
}

function cmdSetAiFactor(argv, data) {
  const [idx, name] = resolveTeam(data, argv[0]);
  const val = parseInt(argv[1], 10);
  if (isNaN(val)) die('VALUE must be an integer');
  if (val < 0 || val > 255) die(`ai_factor must be 0-255, got ${val}`);
  const old = data.ai_performance_factor[idx].factor;
  data.ai_performance_factor[idx].factor = val;
  out(`Set ai_performance_factor[${name}].factor: ${old} -> ${val}`);
  return true;
}

function cmdSetAiTable(argv, data) {
  const [idx, name] = resolveTeam(data, argv[0]);
  const entryIdx = parseInt(argv[1], 10);
  const val = parseInt(argv[2], 10);
  if (isNaN(entryIdx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (entryIdx < 0 || entryIdx > 7) die(`INDEX must be 0-7, got ${entryIdx}`);
  if (val < 0 || val > 255) die(`VALUE must be 0-255, got ${val}`);
  const old = data.ai_performance_table[idx].entries[entryIdx];
  data.ai_performance_table[idx].entries[entryIdx] = val;
  out(`Set ai_performance_table[${name}].entries[${entryIdx}]: ${old} -> ${val}`);
  return true;
}

function cmdSetCar(argv, data) {
  const [idx, name] = resolveTeam(data, argv[0]);
  const cc = data.team_car_characteristics[idx];
  let changed = false;

  const accelIndex = getFlagInt(argv, '--accel-index');
  if (accelIndex !== null) {
    if (!ACCEL_VALID.has(accelIndex))
      die(`accel_index must be one of [${[...ACCEL_VALID].sort((a,b)=>a-b).join(', ')}], got ${accelIndex}`);
    const old = cc.accel_index;
    cc.accel_index = accelIndex;
    out(`Set team_car_characteristics[${name}].accel_index: ${old} -> ${accelIndex}`);
    changed = true;
  }

  const engineIndex = getFlagInt(argv, '--engine-index');
  if (engineIndex !== null) {
    if (!ENGINE_VALID.has(engineIndex))
      die(`engine_index must be one of [${[...ENGINE_VALID].sort((a,b)=>a-b).join(', ')}], got ${engineIndex}`);
    const old = cc.engine_index;
    cc.engine_index = engineIndex;
    out(`Set team_car_characteristics[${name}].engine_index: ${old} -> ${engineIndex}`);
    changed = true;
  }

  for (const [flag, field] of [
    ['--steering',   'steering_idx'],
    ['--steering-b', 'steering_idx_b'],
    ['--braking',    'braking_idx'],
  ]) {
    const v = getFlagInt(argv, flag);
    if (v !== null) {
      if (v < 0 || v > 255) die(`${field} must be 0-255, got ${v}`);
      const old = cc[field];
      cc[field] = v;
      out(`Set team_car_characteristics[${name}].${field}: ${old} -> ${v}`);
      changed = true;
    }
  }

  if (!changed)
    die('No car field specified. Use --accel-index, --engine-index, --steering, --steering-b, or --braking.');
  return true;
}

function cmdSetEngine(argv, data) {
  const variant = parseInt(argv[0], 10);
  if (isNaN(variant) || variant < 0 || variant > 5) die('VARIANT must be an integer 0-5');

  const e = (data.engine_data || []).find(x => x.variant === variant);
  if (!e) die(`engine_data variant ${variant} not found in JSON`);

  let changed = false;
  for (const [flag, key, count] of [
    ['--auto',  'auto_rpms',       4],
    ['--four',  'four_shift_rpms', 4],
    ['--seven', 'seven_shift_rpms', 7],
  ]) {
    const pair = getFlagPair(argv, flag);
    if (pair === null) continue;
    const rpmIdx = parseInt(pair[0], 10);
    const val    = parseInt(pair[1], 10);
    if (isNaN(rpmIdx) || isNaN(val)) die(`${flag} INDEX VALUE must be integers`);
    if (rpmIdx < 0 || rpmIdx >= count) die(`${flag} INDEX must be 0-${count-1}, got ${rpmIdx}`);
    if (val < 0 || val > 65535) die(`RPM value must be 0-65535, got ${val}`);
    const old = e[key][rpmIdx];
    e[key][rpmIdx] = val;
    out(`Set engine_data[${variant}].${key}[${rpmIdx}]: ${old} -> ${val}`);
    changed = true;
  }

  if (!changed)
    die('No engine field specified. Use --auto, --four, or --seven.');
  return true;
}

function cmdSetTireWear(argv, data) {
  const [idx, name] = resolveTeam(data, argv[0]);
  const val = parseInt(argv[1], 10);
  if (isNaN(val)) die('VALUE must be an integer');
  if (val !== 1 && val !== 2) die(`tire_wear_multiplier must be 1 or 2, got ${val}`);
  const old = data.team_engine_multiplier[idx].tire_wear_multiplier;
  data.team_engine_multiplier[idx].tire_wear_multiplier = val;
  out(`Set team_engine_multiplier[${name}].tire_wear_multiplier: ${old} -> ${val}`);
  return true;
}

function cmdSetStats(argv, data) {
  const [idx, name] = resolveTeam(data, argv[0]);
  const tms = data.team_machine_screen_stats.teams[idx];
  let changed = false;

  for (const [flag, field, lo, hi] of [
    ['--eng',        'eng_bar',        0, 100],
    ['--tm',         'tm_bar',         0, 100],
    ['--sus',        'sus_bar',        0, 100],
    ['--tire',       'tire_bar',       0, 100],
    ['--bra',        'bra_bar',        0, 100],
    ['--tire-delta', 'tire_wear_delta', 0, 255],
  ]) {
    const v = getFlagInt(argv, flag);
    if (v === null) continue;
    if (v < lo || v > hi) die(`${field} must be ${lo}-${hi}, got ${v}`);
    const old = tms[field];
    tms[field] = v;
    out(`Set team_machine_screen_stats[${name}].${field}: ${old} -> ${v}`);
    changed = true;
  }

  if (!changed)
    die('No stat field specified. Use --eng, --tm, --sus, --tire, --bra, or --tire-delta.');
  return true;
}

function cmdSetThresholds(argv, data) {
  const [idx, name] = resolveTeam(data, argv[0]);
  const pr = data.post_race_driver_target_points[idx];
  let changed = false;

  const promote = getFlagInt(argv, '--promote');
  if (promote !== null) {
    if (promote < 0 || promote > 255) die(`promote_threshold must be 0-255, got ${promote}`);
    const old = pr.promote_threshold;
    pr.promote_threshold = promote;
    out(`Set post_race_driver_target_points[${name}].promote_threshold: ${old} -> ${promote}`);
    changed = true;
  }

  const partner = getFlagInt(argv, '--partner');
  if (partner !== null) {
    if (partner < 0 || partner > 255) die(`partner_threshold must be 0-255, got ${partner}`);
    const old = pr.partner_threshold;
    pr.partner_threshold = partner;
    out(`Set post_race_driver_target_points[${name}].partner_threshold: ${old} -> ${partner}`);
    changed = true;
  }

  if (!changed)
    die('No threshold specified. Use --promote and/or --partner.');
  return true;
}

function cmdSetPoints(argv, data) {
  const idx = parseInt(argv[0], 10);
  const val = parseInt(argv[1], 10);
  if (isNaN(idx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (idx < 0 || idx > 5) die(`INDEX must be 0-5, got ${idx}`);
  if (val < 1 || val > 255) die(`VALUE must be 1-255, got ${val}`);
  const old = data.points_awarded_per_placement[idx];
  data.points_awarded_per_placement[idx] = val;
  out(`Set points_awarded_per_placement[${idx}]: ${old} -> ${val}`);
  return true;
}

function cmdSetAccelMod(argv, data) {
  const idx = parseInt(argv[0], 10);
  const val = parseInt(argv[1], 10);
  if (isNaN(idx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (idx < 0 || idx > 3) die(`INDEX must be 0-3, got ${idx}`);
  if (val < -32768 || val > 32767) die(`VALUE must be -32768 to 32767, got ${val}`);
  const old = data.acceleration_modifiers[idx];
  data.acceleration_modifiers[idx] = val;
  out(`Set acceleration_modifiers[${idx}]: ${old} -> ${val}`);
  return true;
}

function cmdValidate(argv, data) {
  const errors = validateData(data);
  if (errors.length) {
    out(`Validation failed (${errors.length} error(s)):`);
    for (const e of errors) out(`  ${e}`);
    return false;
  }
  out('Validation passed.');
  return true;
}

function cmdInject(argv, data) {
  const dryRun = argv.includes('--dry-run');

  const errors = validateData(data);
  if (errors.length) {
    out(`Validation failed — aborting inject (${errors.length} error(s)):`);
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  if (!fs.existsSync(OUT_BIN))
    die(`out.bin not found: ${OUT_BIN}\n  Run: build.bat`);

  saveTeamsJson(data);
  const changed = injectTeamData(TEAMS_JSON, OUT_BIN, { dryRun, verbose: true });

  if (dryRun) {
    out(`Dry run: ${changed} byte(s) would change.`);
  } else {
    out(`Injected ${changed} byte(s) into ${OUT_BIN}.`);
    if (changed > 0) out('Run verify.bat to confirm build (only meaningful against unmodified ROM).');
  }
}

// ---------------------------------------------------------------------------
// Argument parsing helpers
// ---------------------------------------------------------------------------

// Returns the string value after a flag, or null if absent
function getFlagValue(argv, flag) {
  const i = argv.indexOf(flag);
  if (i === -1 || i + 1 >= argv.length) return null;
  return argv[i + 1];
}

// Returns the integer value after a flag, or null if absent; dies on non-integer
function getFlagInt(argv, flag) {
  const i = argv.indexOf(flag);
  if (i === -1) return null;
  if (i + 1 >= argv.length) die(`${flag} requires a value`);
  const v = parseInt(argv[i + 1], 10);
  if (isNaN(v)) die(`${flag} value must be an integer, got ${JSON.stringify(argv[i + 1])}`);
  return v;
}

// Returns [value1, value2] for a two-argument flag (--flag INDEX VALUE), or null if absent
function getFlagPair(argv, flag) {
  const i = argv.indexOf(flag);
  if (i === -1) return null;
  if (i + 2 >= argv.length) die(`${flag} requires two arguments: INDEX VALUE`);
  return [argv[i + 1], argv[i + 2]];
}

// ---------------------------------------------------------------------------
// Mutating commands — after success, validate+save
// ---------------------------------------------------------------------------
const MUTATING_COMMANDS = new Set([
  'set-ai-factor', 'set-ai-table', 'set-car', 'set-engine',
  'set-tire-wear', 'set-stats', 'set-thresholds', 'set-points', 'set-accel-mod',
]);

const COMMAND_MAP = {
  'list-teams':     cmdListTeams,
  'list-drivers':   cmdListDrivers,
  'show':           cmdShow,
  'show-engine':    cmdShowEngine,
  'show-points':    cmdShowPoints,
  'show-accel':     cmdShowAccel,
  'set-ai-factor':  cmdSetAiFactor,
  'set-ai-table':   cmdSetAiTable,
  'set-car':        cmdSetCar,
  'set-engine':     cmdSetEngine,
  'set-tire-wear':  cmdSetTireWear,
  'set-stats':      cmdSetStats,
  'set-thresholds': cmdSetThresholds,
  'set-points':     cmdSetPoints,
  'set-accel-mod':  cmdSetAccelMod,
  'validate':       cmdValidate,
  'inject':         cmdInject,
};

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
function main() {
  const argv = process.argv.slice(2);
  if (!argv.length) {
    out('Usage: node tools/editor/team_editor.js COMMAND [args...]');
    out('Commands: ' + Object.keys(COMMAND_MAP).join(', '));
    process.exit(1);
  }

  const command = argv[0];
  const rest    = argv.slice(1);

  const handler = COMMAND_MAP[command];
  if (!handler) {
    err(`Unknown command ${JSON.stringify(command)}`);
    out('Commands: ' + Object.keys(COMMAND_MAP).join(', '));
    process.exit(1);
  }

  const data = loadTeamsJson();

  const result = handler(rest, data);

  // Mutating commands: validate then save
  if (MUTATING_COMMANDS.has(command) && result) {
    const errors = validateData(data);
    if (errors.length) {
      out(`Validation failed after edit — changes NOT saved (${errors.length} error(s)):`);
      for (const e of errors) out(`  ${e}`);
      process.exit(1);
    }
    saveTeamsJson(data);
    out(`Saved ${TEAMS_JSON}`);
  }

  if (command === 'validate' && result === false) process.exit(1);
}

if (require.main === module) main();

module.exports = { validateData, resolveTeam, loadTeamsJson, saveTeamsJson, ACCEL_VALID, ENGINE_VALID };
