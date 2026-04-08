#!/usr/bin/env node
// tools/editor/championship_editor.js
//
// NODE-005: Championship editor CLI (JS port of tools/editor/championship_editor.py)
//
// Argument-driven CLI for editing Super Monaco GP championship and progression
// data.  All edits operate on tools/data/championship.json (the structured edit
// layer), validate that changes stay within known-good ranges, then inject
// modified bytes to out.bin at known ROM addresses via inject_championship_data.js.
//
// The editor NEVER touches src/*.asm files directly.
// Run verify.bat after inject to confirm the build is still bit-perfect (only
// meaningful against the unmodified ROM — see docs/modding_architecture.md).
//
// Usage:
//   node tools/editor/championship_editor.js show-order
//   node tools/editor/championship_editor.js show-points
//   node tools/editor/championship_editor.js show-thresholds
//   node tools/editor/championship_editor.js show-rivals
//   node tools/editor/championship_editor.js show-lap-times
//   node tools/editor/championship_editor.js show-ai-factor
//   node tools/editor/championship_editor.js show-ai-table
//   node tools/editor/championship_editor.js show-ai-placement [standard|easy|champ]
//
//   node tools/editor/championship_editor.js set-order INDEX TRACK_NAME
//   node tools/editor/championship_editor.js move-track FROM_INDEX TO_INDEX
//   node tools/editor/championship_editor.js set-points INDEX VALUE
//   node tools/editor/championship_editor.js set-threshold TEAM [--promote N] [--partner N]
//   node tools/editor/championship_editor.js set-rival-base INDEX VALUE
//   node tools/editor/championship_editor.js set-rival-delta INDEX VALUE
//   node tools/editor/championship_editor.js set-ai-factor TEAM VALUE
//   node tools/editor/championship_editor.js set-ai-table TEAM INDEX VALUE
//
//   node tools/editor/championship_editor.js validate
//   node tools/editor/championship_editor.js inject [--dry-run]
//
// TEAM argument: team index (0-15), name substring (case-insensitive),
//                or exact team name slug (e.g. "madonna", "zero_force").

'use strict';

const fs   = require('fs');
const path = require('path');

const TOOLS_DIR  = path.resolve(__dirname, '..');
const REPO_ROOT  = path.resolve(TOOLS_DIR, '..');
const CHAMP_JSON = path.join(TOOLS_DIR, 'data', 'championship.json');
const OUT_BIN    = path.join(REPO_ROOT, 'out.bin');

const { injectChampionshipData } = require('../inject_championship_data');

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------
function out(msg)  { process.stdout.write(msg + '\n'); }
function err(msg)  { process.stderr.write('ERROR: ' + msg + '\n'); }
function die(msg)  { err(msg); process.exit(1); }

// ---------------------------------------------------------------------------
// JSON load / save
// ---------------------------------------------------------------------------
function loadChampJson(jsonPath) {
  jsonPath = jsonPath || CHAMP_JSON;
  if (!fs.existsSync(jsonPath)) {
    die(`championship.json not found: ${jsonPath}\n  Run: node tools/extract_championship_data.js`);
  }
  return JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
}

function saveChampJson(data, jsonPath) {
  jsonPath = jsonPath || CHAMP_JSON;
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const FIXED_FINAL_SLOT  = 15;
const MONACO_NAME       = 'Monaco';
const POINTS_COUNT      = 6;
const POINTS_MIN        = 1;
const POINTS_MAX        = 20;
const RIVAL_BASE_MIN    = 0;
const RIVAL_BASE_MAX    = 15;
const RIVAL_DELTA_MIN   = -3;
const RIVAL_DELTA_MAX   = 2;
const RIVAL_DELTA_COUNT = 11;
const LAP_TIME_BYTES    = 32;
const THRESHOLD_MIN     = 0;
const THRESHOLD_MAX     = 15;

const TRACK_NAMES = [
  'San Marino', 'Brazil', 'France', 'Hungary', 'West Germany',
  'USA', 'Canada', 'Great Britain', 'Italy', 'Portugal',
  'Spain', 'Mexico', 'Japan', 'Belgium', 'Australia', 'Monaco',
];

// ---------------------------------------------------------------------------
// Team resolution
// ---------------------------------------------------------------------------
function getTeamNames(data) {
  return (data.ai_performance_table || []).map((e, i) => e.name || e.team || String(i));
}

function resolveTeam(data, spec) {
  const teamNames = getTeamNames(data);

  const asInt = parseInt(spec, 10);
  if (!isNaN(asInt) && String(asInt) === String(spec)) {
    if (asInt < 0 || asInt > 15) die(`Team index ${asInt} out of range 0-15`);
    return asInt;
  }

  const specLower = spec.toLowerCase().replace(/-/g, '_').replace(/ /g, '_');

  for (let i = 0; i < teamNames.length; i++) {
    if (teamNames[i].toLowerCase().replace(/ /g, '_') === specLower) return i;
  }

  const matches = teamNames
    .map((name, i) => ({ i, name }))
    .filter(({ name }) => name.toLowerCase().includes(specLower));

  if (matches.length === 1) return matches[0].i;
  if (matches.length > 1) {
    const desc = matches.map(m => `[${m.i}] ${m.name}`).join(', ');
    die(`Ambiguous TEAM ${JSON.stringify(spec)} — matches: ${desc}`);
  }

  die(`No team matching ${JSON.stringify(spec)}`);
}

// ---------------------------------------------------------------------------
// Track name resolution
// ---------------------------------------------------------------------------
function resolveTrackName(spec) {
  const specLower = spec.toLowerCase().replace(/_/g, ' ');

  for (const name of TRACK_NAMES) {
    if (name.toLowerCase() === specLower) return name;
  }

  const matches = TRACK_NAMES.filter(name => name.toLowerCase().includes(specLower));
  if (matches.length === 1) return matches[0];
  if (matches.length > 1) {
    die(`Ambiguous track ${JSON.stringify(spec)} — matches: ${matches.map(n => JSON.stringify(n)).join(', ')}`);
  }

  err(`No track matching ${JSON.stringify(spec)}. Valid tracks:`);
  for (const t of TRACK_NAMES) process.stderr.write(`  ${JSON.stringify(t)}\n`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------
function validateData(data) {
  const errors = [];

  // championship_track_order
  const order = (data._meta || {}).championship_track_order || [];
  if (order.length !== 16) {
    errors.push(`championship_track_order: expected 16 entries, got ${order.length}`);
  } else {
    if (order[FIXED_FINAL_SLOT] !== MONACO_NAME) {
      errors.push(`championship_track_order[${FIXED_FINAL_SLOT}] must be ${JSON.stringify(MONACO_NAME)}, got ${JSON.stringify(order[FIXED_FINAL_SLOT])}`);
    }
    const seen = {};
    for (let i = 0; i < order.length; i++) {
      const name = order[i];
      if (typeof name !== 'string' || !name)
        errors.push(`championship_track_order[${i}]: must be a non-empty string`);
      else {
        if (!TRACK_NAMES.includes(name))
          errors.push(`championship_track_order[${i}]=${JSON.stringify(name)}: not in known track list`);
        if (seen[name] !== undefined)
          errors.push(`championship_track_order: duplicate ${JSON.stringify(name)} at slots ${seen[name]} and ${i}`);
        seen[name] = i;
      }
    }
  }

  // points_awarded_per_placement
  const pts = data.points_awarded_per_placement || [];
  if (pts.length !== POINTS_COUNT) {
    errors.push(`points_awarded_per_placement: expected ${POINTS_COUNT} values, got ${pts.length}`);
  } else {
    for (let i = 0; i < pts.length; i++) {
      if (pts[i] < POINTS_MIN || pts[i] > POINTS_MAX)
        errors.push(`points_awarded_per_placement[${i}]=${pts[i]}: must be ${POINTS_MIN}-${POINTS_MAX}`);
    }
    for (let i = 0; i < pts.length - 1; i++) {
      if (pts[i] <= pts[i + 1])
        errors.push(`points not strictly descending: pts[${i}]=${pts[i]} <= pts[${i+1}]=${pts[i+1]}`);
    }
  }

  // post_race_driver_target_points
  const thresholds = data.post_race_driver_target_points || [];
  if (thresholds.length !== 16) {
    errors.push(`post_race_driver_target_points: expected 16 entries, got ${thresholds.length}`);
  } else {
    for (const e of thresholds) {
      const team = e.name || e.team || '?';
      const promote = e.promote_threshold;
      const partner = e.partner_threshold;
      if (promote < THRESHOLD_MIN || promote > THRESHOLD_MAX)
        errors.push(`${team} promote_threshold=${promote}: must be ${THRESHOLD_MIN}-${THRESHOLD_MAX}`);
      if (partner < THRESHOLD_MIN || partner > THRESHOLD_MAX)
        errors.push(`${team} partner_threshold=${partner}: must be ${THRESHOLD_MIN}-${THRESHOLD_MAX}`);
      if (partner < promote + 2)
        errors.push(`${team} partner_threshold (${partner}) must be >= promote_threshold (${promote}) + 2`);
    }
  }

  // rival_grid_base_table
  const rivalBase = data.rival_grid_base_table || [];
  if (rivalBase.length !== 16) {
    errors.push(`rival_grid_base_table: expected 16 entries, got ${rivalBase.length}`);
  } else {
    for (let i = 0; i < rivalBase.length; i++) {
      if (rivalBase[i] < RIVAL_BASE_MIN || rivalBase[i] > RIVAL_BASE_MAX)
        errors.push(`rival_grid_base_table[${i}]=${rivalBase[i]}: must be ${RIVAL_BASE_MIN}-${RIVAL_BASE_MAX}`);
    }
  }

  // rival_grid_delta_table
  const rivalDelta = data.rival_grid_delta_table || [];
  if (rivalDelta.length !== RIVAL_DELTA_COUNT) {
    errors.push(`rival_grid_delta_table: expected ${RIVAL_DELTA_COUNT} entries, got ${rivalDelta.length}`);
  } else {
    for (let i = 0; i < rivalDelta.length; i++) {
      if (rivalDelta[i] < RIVAL_DELTA_MIN || rivalDelta[i] > RIVAL_DELTA_MAX)
        errors.push(`rival_grid_delta_table[${i}]=${rivalDelta[i]}: must be ${RIVAL_DELTA_MIN} to ${RIVAL_DELTA_MAX}`);
    }
  }

  // ai_performance_factor_by_team
  const apf = data.ai_performance_factor_by_team || [];
  if (apf.length !== 16) {
    errors.push(`ai_performance_factor_by_team: expected 16 entries, got ${apf.length}`);
  } else {
    for (let i = 0; i < apf.length; i++) {
      if (apf[i] < 0 || apf[i] > 255)
        errors.push(`ai_performance_factor_by_team[${i}]=${apf[i]}: must be 0-255`);
    }
  }

  // ai_performance_table
  const apt = data.ai_performance_table || [];
  if (apt.length !== 16) {
    errors.push(`ai_performance_table: expected 16 entries, got ${apt.length}`);
  } else {
    for (let i = 0; i < apt.length; i++) {
      const scores = apt[i].scores || [];
      if (scores.length !== 8) {
        errors.push(`ai_performance_table[${i}].scores: expected 8 entries, got ${scores.length}`);
      } else {
        for (let j = 0; j < scores.length; j++) {
          if (scores[j] < 0 || scores[j] > 255)
            errors.push(`ai_performance_table[${i}].scores[${j}]=${scores[j]}: must be 0-255`);
        }
      }
    }
  }

  // pre_race_lap_time_offset_table
  const lap = data.pre_race_lap_time_offset_table || [];
  if (lap.length !== LAP_TIME_BYTES) {
    errors.push(`pre_race_lap_time_offset_table: expected ${LAP_TIME_BYTES} bytes, got ${lap.length}`);
  } else {
    for (let i = 0; i < lap.length; i++) {
      if (lap[i] < 0 || lap[i] > 255)
        errors.push(`pre_race_lap_time_offset_table[${i}]=${lap[i]}: must be 0-255`);
    }
    if (lap[lap.length - 2] !== 0 || lap[lap.length - 1] !== 0)
      errors.push(`pre_race_lap_time_offset_table: last two bytes must be 0x00 0x00, got 0x${lap[lap.length-2].toString(16).padStart(2,'0').toUpperCase()} 0x${lap[lap.length-1].toString(16).padStart(2,'0').toUpperCase()}`);
  }

  return errors;
}

// ---------------------------------------------------------------------------
// Display helpers
// ---------------------------------------------------------------------------
function places() { return ['1st', '2nd', '3rd', '4th', '5th', '6th']; }

function cmdShowOrder(argv, data) {
  const order = (data._meta || {}).championship_track_order || [];
  out('Championship race order:');
  for (let i = 0; i < order.length; i++) {
    const fixedNote = (i === FIXED_FINAL_SLOT) ? '  [FIXED - final race]' : '';
    out(`  [${String(i).padStart(2)}] ${order[i]}${fixedNote}`);
  }
}

function cmdShowPoints(argv, data) {
  const pts = data.points_awarded_per_placement || [];
  out('Points awarded per placement:');
  for (let i = 0; i < pts.length; i++) {
    out(`  [${i}] ${places()[i]}: ${pts[i]}`);
  }
}

function cmdShowThresholds(argv, data) {
  const thresholds = data.post_race_driver_target_points || [];
  out('Post-race driver target points (per team):');
  out(`  ${'#'.padStart(2)}  ${'Team'.padEnd(14)}  ${'Promote'.padStart(7)}  ${'Partner'.padStart(7)}`);
  out(`  ${'--'.padStart(2)}  ${'----'.padEnd(14)}  ${'-------'.padStart(7)}  ${'-------'.padStart(7)}`);
  for (let i = 0; i < thresholds.length; i++) {
    const e = thresholds[i];
    const name = e.name || `Team ${i}`;
    out(`  [${String(i).padStart(2)}] ${name.padEnd(14)}  ${String(e.promote_threshold).padStart(7)}  ${String(e.partner_threshold).padStart(7)}`);
  }
}

function cmdShowRivals(argv, data) {
  const rivalBase  = data.rival_grid_base_table || [];
  const rivalDelta = data.rival_grid_delta_table || [];
  out('Rival grid base table (one value per championship slot):');
  for (let i = 0; i < rivalBase.length; i++) {
    out(`  [${String(i).padStart(2)}] ${rivalBase[i]}`);
  }
  out(`\nRival grid delta table (${rivalDelta.length} entries):`);
  for (let i = 0; i < rivalDelta.length; i++) {
    const v = rivalDelta[i];
    out(`  [${String(i).padStart(2)}] ${v >= 0 ? '+' : ''}${v}`);
  }
}

function cmdShowLapTimes(argv, data) {
  const lap = data.pre_race_lap_time_offset_table || [];
  out(`Pre-race lap time offset table (${lap.length} raw bytes = 16 word pairs):`);
  for (let i = 0; i < 16; i++) {
    const hi = lap[i * 2];
    const lo = lap[i * 2 + 1];
    let note = '';
    if (i === 0)  note = '  [BCD start time anchor - fixed]';
    if (i === 15) note = '  [terminator 0x0000 - fixed]';
    const word = (hi << 8) | lo;
    out(`  [${String(i).padStart(2)}] 0x${hi.toString(16).padStart(2,'0').toUpperCase()} 0x${lo.toString(16).padStart(2,'0').toUpperCase()}  (word: 0x${word.toString(16).padStart(4,'0').toUpperCase()})${note}`);
  }
}

function cmdShowAiFactor(argv, data) {
  const apf   = data.ai_performance_factor_by_team || [];
  const names = getTeamNames(data);
  out('AI performance factor by team:');
  for (let i = 0; i < apf.length; i++) {
    out(`  [${String(i).padStart(2)}] ${(names[i] || '').padEnd(14)}  ${apf[i]}`);
  }
}

function cmdShowAiTable(argv, data) {
  const apt = data.ai_performance_table || [];
  out('AI performance table (8 scores per team):');
  out(`  ${'#'.padStart(2)}  ${'Team'.padEnd(14)}  scores`);
  for (let i = 0; i < apt.length; i++) {
    const name   = apt[i].name || `Team ${i}`;
    const scores = apt[i].scores || [];
    out(`  [${String(i).padStart(2)}] ${name.padEnd(14)}  [${scores.join(', ')}]`);
  }
}

function cmdShowAiPlacement(argv, data) {
  const variant = argv[0] || 'standard';
  const keyMap = {
    standard: 'ai_placement_data',
    easy:     'ai_placement_data_easy',
    champ:    'ai_placement_data_champ',
  };
  const key = keyMap[variant] || 'ai_placement_data';
  const entry = data[key];
  if (!entry) die(`No ${JSON.stringify(key)} in championship.json`);

  out(`AI placement data (${key}):`);
  if (entry.header_record) {
    const h = entry.header_record;
    out(`  header: speed=0x${h.speed_hi.toString(16).padStart(2,'0').toUpperCase()}${h.speed_lo.toString(16).padStart(2,'0').toUpperCase()}  accel=0x${h.accel_hi.toString(16).padStart(2,'0').toUpperCase()}${h.accel_lo.toString(16).padStart(2,'0').toUpperCase()}  brake=0x${h.brake.toString(16).padStart(2,'0').toUpperCase()}`);
  }
  const cars = entry.records || entry.cars || [];
  for (let i = 0; i < cars.length; i++) {
    const car   = cars[i];
    const speed = (car.speed_hi << 8) | car.speed_lo;
    const accel = (car.accel_hi << 8) | car.accel_lo;
    out(`  [${String(i).padStart(2)}] speed=0x${speed.toString(16).padStart(4,'0').toUpperCase()}  accel=0x${accel.toString(16).padStart(4,'0').toUpperCase()}  brake=0x${car.brake.toString(16).padStart(2,'0').toUpperCase()}`);
  }
  if (entry.sentinel !== undefined) {
    out(`  sentinel: 0x${entry.sentinel.toString(16).padStart(2,'0').toUpperCase()}`);
  }
}

// ---------------------------------------------------------------------------
// Subcommand handlers — mutations
// ---------------------------------------------------------------------------
function cmdSetOrder(argv, data) {
  const slot = parseInt(argv[0], 10);
  if (isNaN(slot) || slot < 0 || slot > 15) die('INDEX must be an integer 0-15');
  if (slot === FIXED_FINAL_SLOT) die(`Slot ${FIXED_FINAL_SLOT} (Monaco) is fixed and cannot be changed.`);

  const canonical = resolveTrackName(argv[1] || '');
  if (canonical === MONACO_NAME) die(`Monaco can only appear at slot ${FIXED_FINAL_SLOT} (the final race).`);

  const order = data._meta.championship_track_order;

  // If canonical already exists at another slot, swap
  let swapped = false;
  for (let i = 0; i < order.length; i++) {
    if (order[i] === canonical && i !== slot) {
      const oldAtSlot = order[slot];
      out(`  Swapping slot ${slot} (${JSON.stringify(oldAtSlot)}) <-> slot ${i} (${JSON.stringify(canonical)})`);
      order[slot] = canonical;
      order[i]    = oldAtSlot;
      swapped = true;
      break;
    }
  }
  if (!swapped) {
    out(`  Set slot ${slot}: ${JSON.stringify(order[slot])} -> ${JSON.stringify(canonical)}`);
    order[slot] = canonical;
  }

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: slot ${slot} = ${JSON.stringify(canonical)}`);
}

function cmdMoveTrack(argv, data) {
  const fromIdx = parseInt(argv[0], 10);
  const toIdx   = parseInt(argv[1], 10);
  if (isNaN(fromIdx) || isNaN(toIdx)) die('FROM_INDEX and TO_INDEX must be integers 0-15');
  if (fromIdx < 0 || fromIdx > 15) die(`FROM_INDEX ${fromIdx} out of range 0-15`);
  if (toIdx < 0   || toIdx > 15)   die(`TO_INDEX ${toIdx} out of range 0-15`);
  if (fromIdx === toIdx) { out('No-op: FROM_INDEX == TO_INDEX'); return; }
  if (fromIdx === FIXED_FINAL_SLOT || toIdx === FIXED_FINAL_SLOT)
    die(`Slot ${FIXED_FINAL_SLOT} (Monaco) is fixed and cannot be moved.`);

  const order   = data._meta.championship_track_order;
  const oldFrom = order[fromIdx];
  const oldTo   = order[toIdx];
  out(`  Swapping slot ${fromIdx} (${JSON.stringify(oldFrom)}) <-> slot ${toIdx} (${JSON.stringify(oldTo)})`);
  [order[fromIdx], order[toIdx]] = [order[toIdx], order[fromIdx]];

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: slot ${fromIdx}=${JSON.stringify(order[fromIdx])}  slot ${toIdx}=${JSON.stringify(order[toIdx])}`);
}

function cmdSetPoints(argv, data) {
  const idx = parseInt(argv[0], 10);
  const val = parseInt(argv[1], 10);
  if (isNaN(idx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (idx < 0 || idx >= POINTS_COUNT) die(`INDEX ${idx} out of range 0-${POINTS_COUNT - 1}`);
  if (val < POINTS_MIN || val > POINTS_MAX) die(`VALUE ${val} out of range ${POINTS_MIN}-${POINTS_MAX}`);

  const old = data.points_awarded_per_placement[idx];
  data.points_awarded_per_placement[idx] = val;
  out(`  points_awarded_per_placement[${idx}]: ${old} -> ${val}`);

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: points_awarded_per_placement[${idx}] = ${val}`);
}

function cmdSetThreshold(argv, data) {
  const teamIdx = resolveTeam(data, argv[0]);
  const entry   = data.post_race_driver_target_points[teamIdx];

  const promote = getFlagInt(argv.slice(1), '--promote');
  const partner = getFlagInt(argv.slice(1), '--partner');

  if (promote === null && partner === null)
    die('At least one of --promote or --partner is required.');

  if (promote !== null) {
    if (promote < THRESHOLD_MIN || promote > THRESHOLD_MAX)
      die(`--promote ${promote} out of range ${THRESHOLD_MIN}-${THRESHOLD_MAX}`);
    const old = entry.promote_threshold;
    entry.promote_threshold = promote;
    out(`  ${entry.name || teamIdx} promote_threshold: ${old} -> ${promote}`);
  }

  if (partner !== null) {
    if (partner < THRESHOLD_MIN || partner > THRESHOLD_MAX)
      die(`--partner ${partner} out of range ${THRESHOLD_MIN}-${THRESHOLD_MAX}`);
    const old = entry.partner_threshold;
    entry.partner_threshold = partner;
    out(`  ${entry.name || teamIdx} partner_threshold: ${old} -> ${partner}`);
  }

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: ${entry.name || `team ${teamIdx}`} promote=${entry.promote_threshold}  partner=${entry.partner_threshold}`);
}

function cmdSetRivalBase(argv, data) {
  const idx = parseInt(argv[0], 10);
  const val = parseInt(argv[1], 10);
  if (isNaN(idx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (idx < 0 || idx > 15) die(`INDEX ${idx} out of range 0-15`);
  if (val < RIVAL_BASE_MIN || val > RIVAL_BASE_MAX)
    die(`VALUE ${val} out of range ${RIVAL_BASE_MIN}-${RIVAL_BASE_MAX}`);

  const old = data.rival_grid_base_table[idx];
  data.rival_grid_base_table[idx] = val;
  out(`  rival_grid_base_table[${idx}]: ${old} -> ${val}`);

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: rival_grid_base_table[${idx}] = ${val}`);
}

function cmdSetRivalDelta(argv, data) {
  const idx = parseInt(argv[0], 10);
  const val = parseInt(argv[1], 10);
  if (isNaN(idx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (idx < 0 || idx >= RIVAL_DELTA_COUNT) die(`INDEX ${idx} out of range 0-${RIVAL_DELTA_COUNT - 1}`);
  if (val < RIVAL_DELTA_MIN || val > RIVAL_DELTA_MAX)
    die(`VALUE ${val} out of range ${RIVAL_DELTA_MIN} to ${RIVAL_DELTA_MAX}`);

  const old = data.rival_grid_delta_table[idx];
  data.rival_grid_delta_table[idx] = val;
  out(`  rival_grid_delta_table[${idx}]: ${old >= 0 ? '+' : ''}${old} -> ${val >= 0 ? '+' : ''}${val}`);

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: rival_grid_delta_table[${idx}] = ${val >= 0 ? '+' : ''}${val}`);
}

function cmdSetAiFactor(argv, data) {
  const teamIdx = resolveTeam(data, argv[0]);
  const val = parseInt(argv[1], 10);
  if (isNaN(val)) die('VALUE must be an integer');
  if (val < 0 || val > 255) die(`VALUE ${val} out of range 0-255`);

  const name = getTeamNames(data)[teamIdx];
  const old  = data.ai_performance_factor_by_team[teamIdx];
  data.ai_performance_factor_by_team[teamIdx] = val;
  out(`  ${name} ai_performance_factor_by_team[${teamIdx}]: ${old} -> ${val}`);

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: ${name} ai_performance_factor_by_team[${teamIdx}] = ${val}`);
}

function cmdSetAiTable(argv, data) {
  const teamIdx  = resolveTeam(data, argv[0]);
  const scoreIdx = parseInt(argv[1], 10);
  const val      = parseInt(argv[2], 10);
  if (isNaN(scoreIdx) || isNaN(val)) die('INDEX and VALUE must be integers');
  if (scoreIdx < 0 || scoreIdx > 7) die(`INDEX ${scoreIdx} out of range 0-7`);
  if (val < 0 || val > 255) die(`VALUE ${val} out of range 0-255`);

  const name  = getTeamNames(data)[teamIdx];
  const entry = data.ai_performance_table[teamIdx];
  const old   = entry.scores[scoreIdx];
  entry.scores[scoreIdx] = val;
  out(`  ${name} ai_performance_table[${scoreIdx}]: ${old} -> ${val}`);

  const errors = validateData(data);
  if (errors.length) {
    out('ERROR: Change produces invalid state:');
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  saveChampJson(data);
  out(`Saved: ${name} ai_performance_table[${scoreIdx}] = ${val}`);
}

function cmdValidate(argv, data) {
  const errors = validateData(data);
  if (errors.length) {
    out(`Validation FAILED: ${errors.length} error(s):`);
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }
  out('Validation passed: championship.json is valid.');
}

function cmdInject(argv, data) {
  const dryRun = argv.includes('--dry-run');

  const errors = validateData(data);
  if (errors.length) {
    out(`Validation FAILED: ${errors.length} error(s):`);
    for (const e of errors) out(`  ${e}`);
    process.exit(1);
  }

  if (!fs.existsSync(OUT_BIN))
    die(`ROM not found: ${OUT_BIN}\n  Run build.bat to produce out.bin first.`);

  const changed = injectChampionshipData(CHAMP_JSON, OUT_BIN, { dryRun, verbose: true });

  if (dryRun) {
    out(`Dry-run: ${changed} bytes would change.`);
  } else {
    if (changed === 0) {
      out('No-op: 0 bytes changed.');
    } else {
      out(`Injected: ${changed} bytes changed.`);
      out('Run verify.bat to check if the result is still bit-perfect.');
    }
  }
}

// ---------------------------------------------------------------------------
// Argument parsing helpers
// ---------------------------------------------------------------------------
function getFlagValue(argv, flag) {
  const i = argv.indexOf(flag);
  if (i === -1 || i + 1 >= argv.length) return null;
  return argv[i + 1];
}

function getFlagInt(argv, flag) {
  const i = argv.indexOf(flag);
  if (i === -1) return null;
  if (i + 1 >= argv.length) die(`${flag} requires a value`);
  const v = parseInt(argv[i + 1], 10);
  if (isNaN(v)) die(`${flag} value must be an integer, got ${JSON.stringify(argv[i + 1])}`);
  return v;
}

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------
const COMMAND_MAP = {
  'show-order':        cmdShowOrder,
  'show-points':       cmdShowPoints,
  'show-thresholds':   cmdShowThresholds,
  'show-rivals':       cmdShowRivals,
  'show-lap-times':    cmdShowLapTimes,
  'show-ai-factor':    cmdShowAiFactor,
  'show-ai-table':     cmdShowAiTable,
  'show-ai-placement': cmdShowAiPlacement,
  'set-order':         cmdSetOrder,
  'move-track':        cmdMoveTrack,
  'set-points':        cmdSetPoints,
  'set-threshold':     cmdSetThreshold,
  'set-rival-base':    cmdSetRivalBase,
  'set-rival-delta':   cmdSetRivalDelta,
  'set-ai-factor':     cmdSetAiFactor,
  'set-ai-table':      cmdSetAiTable,
  'validate':          cmdValidate,
  'inject':            cmdInject,
};

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
function main() {
  const argv = process.argv.slice(2);
  if (!argv.length) {
    out('Usage: node tools/editor/championship_editor.js COMMAND [args...]');
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

  const data = loadChampJson();
  handler(rest, data);
}

if (require.main === module) main();

module.exports = {
  validateData, resolveTeam, resolveTrackName, loadChampJson, saveChampJson,
  TRACK_NAMES, FIXED_FINAL_SLOT, MONACO_NAME,
};
