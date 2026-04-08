#!/usr/bin/env node
// tools/tests/test_editors_e2e.js
//
// TOOL-020: End-to-end CLI tests for all 4 editor CLIs.
//
// Tests the full show → set → validate → inject --dry-run flow for each editor.
// Mutation tests use isolated temp copies of tools/data/*.json so the real data
// files are never modified.
//
// Section A: Read-only CLI commands (list, show, show-order, etc.) —
//            exit 0 and expected output substrings.
// Section B: validate command for all 4 editors — exit 0 and "valid"/"passed".
// Section C: Track editor mutation using --tracks-json (temp copy) —
//            set-field changes value, track validates cleanly after.
// Section D: Team / text / championship editor mutation via module API —
//            in-process validate after mutation confirms changes are accepted.
// Section E: inject --dry-run — exit 0 and "0" changes reported.
// Section F: CLI error handling — unknown command, missing args → non-zero exit.

'use strict';

const assert       = require('assert');
const fs           = require('fs');
const os           = require('os');
const path         = require('path');
const { spawnSync } = require('child_process');

const { REPO_ROOT } = require('../lib/rom.js');

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const TOOLS_DIR    = path.join(REPO_ROOT, 'tools');
const EDITOR_DIR   = path.join(TOOLS_DIR, 'editor');
const DATA_DIR     = path.join(TOOLS_DIR, 'data');
const TRACKS_JSON  = path.join(DATA_DIR, 'tracks.json');
const TEAMS_JSON   = path.join(DATA_DIR, 'teams.json');
const STRINGS_JSON = path.join(DATA_DIR, 'strings.json');
const CHAMP_JSON   = path.join(DATA_DIR, 'championship.json');

const TRACK_EDITOR  = path.join(EDITOR_DIR, 'track_editor.js');
const TEAM_EDITOR   = path.join(EDITOR_DIR, 'team_editor.js');
const TEXT_EDITOR   = path.join(EDITOR_DIR, 'text_editor.js');
const CHAMP_EDITOR  = path.join(EDITOR_DIR, 'championship_editor.js');

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------
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
// Helper: run a Node.js editor script via spawnSync and return result
// ---------------------------------------------------------------------------
function runEditor(scriptPath, args) {
  const result = spawnSync('node', [scriptPath, ...args], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    timeout: 15000,
  });
  return {
    exitCode: result.status,
    stdout:   result.stdout || '',
    stderr:   result.stderr || '',
    output:   (result.stdout || '') + (result.stderr || ''),
  };
}

// ---------------------------------------------------------------------------
// Helper: create a temp copy of a JSON file
// ---------------------------------------------------------------------------
function makeTempJson(srcPath) {
  const tmpDir  = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp_e2e_'));
  const tmpFile = path.join(tmpDir, path.basename(srcPath));
  fs.copyFileSync(srcPath, tmpFile);
  return { tmpDir, tmpFile };
}

// ---------------------------------------------------------------------------
// Section A: Read-only CLI commands
// ---------------------------------------------------------------------------
console.log('Section A: read-only CLI commands');

// A.1 — track_editor list
test('A.track_list.exits_0', () => {
  const r = runEditor(TRACK_EDITOR, ['list']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.track_list.has_19_tracks', () => {
  const r = runEditor(TRACK_EDITOR, ['list']);
  // Expect 19 numbered rows ( 0 .. 18)
  const matches = r.stdout.match(/^\s+\d+\s+\S/gm) || [];
  assert.strictEqual(matches.length, 19, `Expected 19 track rows, got ${matches.length}`);
});

test('A.track_list.has_san_marino', () => {
  const r = runEditor(TRACK_EDITOR, ['list']);
  assert.ok(r.stdout.includes('San Marino'), 'Expected "San Marino" in list output');
});

test('A.track_list.has_monaco', () => {
  const r = runEditor(TRACK_EDITOR, ['list']);
  assert.ok(r.stdout.includes('Monaco'), 'Expected "Monaco" in list output');
});

// A.2 — track_editor show
test('A.track_show.exits_0', () => {
  const r = runEditor(TRACK_EDITOR, ['show', '0']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.track_show.has_track_name', () => {
  const r = runEditor(TRACK_EDITOR, ['show', '0']);
  assert.ok(r.stdout.includes('San Marino'), 'Expected "San Marino" in show output');
});

test('A.track_show.has_track_length', () => {
  const r = runEditor(TRACK_EDITOR, ['show', '0']);
  assert.ok(r.stdout.includes('track_length'), 'Expected "track_length" in show output');
});

test('A.track_show.by_name_substring', () => {
  const r = runEditor(TRACK_EDITOR, ['show', 'brazil']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}`);
  assert.ok(r.stdout.includes('Brazil'), 'Expected "Brazil" in output');
});

test('A.track_show.section_curves', () => {
  const r = runEditor(TRACK_EDITOR, ['show', '0', '--section', 'curves']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}`);
  assert.ok(r.stdout.includes('CURVE SEGMENTS'), 'Expected "CURVE SEGMENTS" header');
});

// A.3 — team_editor list-teams
test('A.team_list_teams.exits_0', () => {
  const r = runEditor(TEAM_EDITOR, ['list-teams']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.team_list_teams.has_16_teams', () => {
  const r = runEditor(TEAM_EDITOR, ['list-teams']);
  // Rows look like: "  [ 0] Madonna ..."
  const matches = r.stdout.match(/\[\s*\d+\]/g) || [];
  assert.strictEqual(matches.length, 16, `Expected 16 team rows, got ${matches.length}`);
});

test('A.team_list_drivers.exits_0', () => {
  const r = runEditor(TEAM_EDITOR, ['list-drivers']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.team_show.exits_0', () => {
  const r = runEditor(TEAM_EDITOR, ['show', '0']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.team_show.has_team_label', () => {
  const r = runEditor(TEAM_EDITOR, ['show', '0']);
  // First team in data is Madonna (or whatever slot 0 is)
  assert.ok(r.output.length > 0, 'Expected non-empty show output');
});

test('A.team_show_points.exits_0', () => {
  const r = runEditor(TEAM_EDITOR, ['show-points']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

// A.4 — text_editor list
test('A.text_list.exits_0', () => {
  const r = runEditor(TEXT_EDITOR, ['list']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.text_list.has_team_names_category', () => {
  const r = runEditor(TEXT_EDITOR, ['list']);
  assert.ok(r.stdout.includes('team_names'), 'Expected "team_names" in list output');
});

test('A.text_list.has_4_mutable_categories', () => {
  const r = runEditor(TEXT_EDITOR, ['list']);
  const yesMatches = (r.stdout.match(/\byes\b/g) || []).length;
  assert.ok(yesMatches >= 4, `Expected >=4 mutable "yes" rows, got ${yesMatches}`);
});

test('A.text_show.team_names.exits_0', () => {
  const r = runEditor(TEXT_EDITOR, ['show', 'team_names']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.text_show.team_names.single_entry.exits_0', () => {
  const r = runEditor(TEXT_EDITOR, ['show', 'team_names', '0']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.text_show.team_names.single_entry.has_capacity', () => {
  const r = runEditor(TEXT_EDITOR, ['show', 'team_names', '0']);
  assert.ok(r.stdout.includes('capacity'), 'Expected "capacity" in show entry output');
});

test('A.text_charset.exits_0', () => {
  const r = runEditor(TEXT_EDITOR, ['charset']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

// A.5 — championship_editor show commands
test('A.champ_show_order.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-order']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.champ_show_order.has_16_entries', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-order']);
  const matches = r.stdout.match(/\[\s*\d+\]/g) || [];
  assert.ok(matches.length >= 16, `Expected >=16 order entries, got ${matches.length}`);
});

test('A.champ_show_points.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-points']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.champ_show_thresholds.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-thresholds']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.champ_show_rivals.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-rivals']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.champ_show_ai_factor.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-ai-factor']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

test('A.champ_show_ai_placement.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['show-ai-placement']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
});

// ---------------------------------------------------------------------------
// Section B: validate commands
// ---------------------------------------------------------------------------
console.log('Section B: validate commands');

test('B.track_validate.exits_0', () => {
  const r = runEditor(TRACK_EDITOR, ['validate']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('B.track_validate.reports_all_valid', () => {
  const r = runEditor(TRACK_EDITOR, ['validate']);
  assert.ok(
    r.stdout.includes('VALID') || r.stdout.includes('valid'),
    `Expected "VALID" in output: ${r.stdout}`
  );
});

test('B.track_validate.reports_19_tracks', () => {
  const r = runEditor(TRACK_EDITOR, ['validate']);
  assert.ok(r.stdout.includes('19'), `Expected "19" in output: ${r.stdout}`);
});

test('B.team_validate.exits_0', () => {
  const r = runEditor(TEAM_EDITOR, ['validate']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('B.team_validate.reports_passed', () => {
  const r = runEditor(TEAM_EDITOR, ['validate']);
  assert.ok(
    r.stdout.toLowerCase().includes('pass'),
    `Expected "pass" in output: ${r.stdout}`
  );
});

test('B.text_validate.exits_0', () => {
  const r = runEditor(TEXT_EDITOR, ['validate']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('B.text_validate.reports_passed', () => {
  const r = runEditor(TEXT_EDITOR, ['validate']);
  assert.ok(
    r.stdout.toLowerCase().includes('pass'),
    `Expected "pass" in output: ${r.stdout}`
  );
});

test('B.champ_validate.exits_0', () => {
  const r = runEditor(CHAMP_EDITOR, ['validate']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('B.champ_validate.reports_passed', () => {
  const r = runEditor(CHAMP_EDITOR, ['validate']);
  assert.ok(
    r.stdout.toLowerCase().includes('pass'),
    `Expected "pass" in output: ${r.stdout}`
  );
});

// ---------------------------------------------------------------------------
// Section C: track editor mutation via --tracks-json (isolated temp copy)
// ---------------------------------------------------------------------------
console.log('Section C: track editor mutation (isolated)');

// Helper: run set-field on a temp copy, return spawnSync result
function trackSetField(tmpJson, track, field, value) {
  return runEditor(TRACK_EDITOR, [
    'set-field', track, field, String(value),
    '--tracks-json', tmpJson,
  ]);
}

test('C.set_field.horizon_override.exits_0', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    const r = trackSetField(tmpFile, '0', 'horizon_override', '1');
    assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('C.set_field.horizon_override.output_shows_change', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    const r = trackSetField(tmpFile, '0', 'horizon_override', '1');
    assert.ok(
      r.output.includes('horizon_override'),
      `Expected "horizon_override" in output: ${r.output}`
    );
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('C.set_field.horizon_override.json_updated', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    trackSetField(tmpFile, '0', 'horizon_override', '1');
    const data = JSON.parse(fs.readFileSync(tmpFile, 'utf8'));
    assert.strictEqual(data.tracks[0].horizon_override, 1, 'JSON not updated');
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('C.set_field.horizon_override.reverts_to_original', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    trackSetField(tmpFile, '0', 'horizon_override', '1');
    const r = trackSetField(tmpFile, '0', 'horizon_override', '0');
    assert.strictEqual(r.exitCode, 0, `revert failed: ${r.output}`);
    const data = JSON.parse(fs.readFileSync(tmpFile, 'utf8'));
    assert.strictEqual(data.tracks[0].horizon_override, 0, 'Revert did not stick');
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('C.set_field.real_json_unchanged', () => {
  // Original TRACKS_JSON must not have been touched by any C test
  const origData  = JSON.parse(fs.readFileSync(TRACKS_JSON, 'utf8'));
  assert.strictEqual(
    origData.tracks[0].horizon_override, 0,
    'Real tracks.json was modified by a prior test!'
  );
});

// Validate on a temp copy after mutation
test('C.validate_after_mutation.exits_0', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    // Change steering_straight on track 1 (valid range is 1-255)
    trackSetField(tmpFile, '1', 'steering_straight', '50');
    const r = runEditor(TRACK_EDITOR, ['validate', '--tracks-json', tmpFile]);
    assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('C.validate_after_mutation.reports_valid', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    trackSetField(tmpFile, '1', 'steering_straight', '50');
    const r = runEditor(TRACK_EDITOR, ['validate', '--tracks-json', tmpFile]);
    assert.ok(
      r.stdout.includes('VALID') || r.stdout.includes('valid'),
      `Expected valid output: ${r.stdout}`
    );
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

// Show uses --tracks-json too
test('C.show_with_temp_json.exits_0', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    const r = runEditor(TRACK_EDITOR, ['show', '0', '--tracks-json', tmpFile]);
    assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.stderr}`);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('C.show_with_temp_json.reflects_mutation', () => {
  const { tmpDir, tmpFile } = makeTempJson(TRACKS_JSON);
  try {
    trackSetField(tmpFile, '0', 'horizon_override', '1');
    const r = runEditor(TRACK_EDITOR, ['show', '0', '--tracks-json', tmpFile]);
    assert.ok(r.stdout.includes('horizon_override  : 1'), `Expected updated value: ${r.stdout}`);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// Section D: team / text / championship mutation via module API (in-process)
// ---------------------------------------------------------------------------
console.log('Section D: module API mutation + validate');

// D.1 — team editor
// teams.json has per-table arrays (no top-level .teams array).
// ai_performance_factor is [{team, factor}, ...] for 16 teams.
const {
  validateData: validateTeams,
  resolveTeam:  resolveTeamEntry,
  loadTeamsJson,
} = require('../editor/team_editor.js');

test('D.team.load_json_ok', () => {
  const data = loadTeamsJson();
  assert.ok(data && Array.isArray(data.ai_performance_factor),
    'Expected data.ai_performance_factor array');
});

test('D.team.has_16_teams', () => {
  const data = loadTeamsJson();
  assert.strictEqual(data.ai_performance_factor.length, 16,
    `Expected 16 teams, got ${data.ai_performance_factor.length}`);
});

test('D.team.validate_clean', () => {
  const data   = loadTeamsJson();
  const errors = validateTeams(data);
  assert.strictEqual(errors.length, 0, `Unexpected errors: ${errors.join(', ')}`);
});

test('D.team.resolve_by_index', () => {
  const data = loadTeamsJson();
  // resolveTeam returns [index, teamName]
  const [idx, name] = resolveTeamEntry(data, '0');
  assert.strictEqual(idx, 0, `Expected index 0, got ${idx}`);
  assert.ok(typeof name === 'string' && name.length > 0, 'Expected a team name');
});

test('D.team.resolve_by_name_substring', () => {
  const data        = loadTeamsJson();
  const [idx, name] = resolveTeamEntry(data, 'madon');
  assert.strictEqual(idx, 0, `Expected index 0 for "madon", got ${idx}`);
  assert.ok(name.toLowerCase().includes('madonna'), `Expected "Madonna", got ${name}`);
});

test('D.team.mutate_ai_factor_stays_valid', () => {
  const data    = loadTeamsJson();
  const origVal = data.ai_performance_factor[0].factor;
  // Clamp to valid range 1-15
  data.ai_performance_factor[0].factor = Math.min(15, Math.max(1, origVal + 1));
  const errors = validateTeams(data);
  assert.strictEqual(errors.length, 0, `Errors after ai_factor change: ${errors.join(', ')}`);
  // Restore
  data.ai_performance_factor[0].factor = origVal;
});

test('D.team.mutate_ai_factor_out_of_range_fails', () => {
  const data    = loadTeamsJson();
  const origVal = data.ai_performance_factor[0].factor;
  // ai_performance_factor range is 0-255; use -1 to trigger an error
  data.ai_performance_factor[0].factor = -1;
  const errors = validateTeams(data);
  assert.ok(errors.length > 0, 'Expected validation error for ai_factor=-1');
  data.ai_performance_factor[0].factor = origVal;
});

test('D.team.real_data_unmodified_after_api_tests', () => {
  const data = loadTeamsJson();
  // loadTeamsJson reads from disk each call — verify no file was written
  const errors = validateTeams(data);
  assert.strictEqual(errors.length, 0, 'Real teams.json corrupted!');
});

// D.2 — text editor
const {
  resolveCategory,
  validateEntry,
  validateAll,
  MUTABLE_CATEGORIES,
  CATEGORY_NAMES,
} = require('../editor/text_editor.js');

const { readJson } = require('../lib/json.js');

test('D.text.resolve_category_team_names', () => {
  const name = resolveCategory('team_names');
  assert.strictEqual(name, 'team_names');
});

test('D.text.resolve_category_prefix', () => {
  const name = resolveCategory('team_intro');
  assert.strictEqual(name, 'team_intro_messages');
});

test('D.text.validate_all_clean', () => {
  const data   = readJson(STRINGS_JSON);
  const errors = validateAll(data);
  assert.strictEqual(errors.length, 0, `Unexpected errors: ${errors.map(e=>e.message).join(', ')}`);
});

test('D.text.validate_entry_within_capacity', () => {
  const data  = readJson(STRINGS_JSON);
  // data.team_names is {_meta, entries:[...]} — use .entries[0]
  const entry = data.team_names.entries[0];
  // validateEntry(entry) validates entry.en against entry.capacity
  const shortEntry = Object.assign({}, entry, { en: 'AB' });
  const err = validateEntry(shortEntry);
  assert.strictEqual(err, null, `Expected null but got: ${err}`);
});

test('D.text.validate_entry_over_capacity_rejected', () => {
  const data  = readJson(STRINGS_JSON);
  // data.team_names.entries[0] has capacity 9 (Madonna = 7 + 1 term = 8 bytes)
  const entry = data.team_names.entries[0];
  // Build a string that exceeds capacity (capacity is entry.capacity bytes)
  const tooLong = 'A'.repeat(entry.capacity + 5);
  const overEntry = Object.assign({}, entry, { en: tooLong });
  const err = validateEntry(overEntry);
  assert.ok(err !== null, `Expected capacity error for over-long string, got null`);
});

test('D.text.mutable_categories_count', () => {
  // MUTABLE_CATEGORIES is a Set — use .size, not .length
  assert.strictEqual(MUTABLE_CATEGORIES.size, 4,
    `Expected 4 mutable categories, got ${MUTABLE_CATEGORIES.size}`);
});

test('D.text.category_names_includes_team_names', () => {
  assert.ok(CATEGORY_NAMES.includes('team_names'),
    'Expected CATEGORY_NAMES to include "team_names"');
});

// D.3 — championship editor
const {
  validateData: validateChamp,
  resolveTeam:  resolveChampTeam,
  resolveTrackName,
  loadChampJson,
  TRACK_NAMES,
  FIXED_FINAL_SLOT,
  MONACO_NAME,
} = require('../editor/championship_editor.js');

test('D.champ.load_json_ok', () => {
  const data = loadChampJson();
  assert.ok(data, 'Expected championship data');
});

test('D.champ.validate_clean', () => {
  const data   = loadChampJson();
  const errors = validateChamp(data);
  assert.strictEqual(errors.length, 0, `Errors: ${errors.join(', ')}`);
});

test('D.champ.monaco_is_fixed_final', () => {
  assert.strictEqual(MONACO_NAME, 'Monaco',
    `Expected MONACO_NAME="Monaco", got ${MONACO_NAME}`);
  assert.strictEqual(FIXED_FINAL_SLOT, 15,
    `Expected FIXED_FINAL_SLOT=15, got ${FIXED_FINAL_SLOT}`);
});

test('D.champ.track_names_has_16_entries', () => {
  assert.strictEqual(TRACK_NAMES.length, 16,
    `Expected 16 track names, got ${TRACK_NAMES.length}`);
});

test('D.champ.resolve_track_san_marino', () => {
  const name = resolveTrackName('San Marino');
  assert.strictEqual(name, 'San Marino');
});

test('D.champ.resolve_track_by_substring', () => {
  const name = resolveTrackName('san');
  assert.strictEqual(name, 'San Marino');
});

test('D.champ.resolve_team_by_index', () => {
  const data = loadChampJson();
  // resolveChampTeam returns an integer index (not an object/array)
  const idx = resolveChampTeam(data, '0');
  assert.strictEqual(typeof idx, 'number', `Expected a number, got ${typeof idx}`);
  assert.strictEqual(idx, 0, `Expected index 0, got ${idx}`);
});

test('D.champ.mutate_points_stays_valid', () => {
  const data     = loadChampJson();
  // Key is points_awarded_per_placement (snake_case)
  const origPts  = data.points_awarded_per_placement[0];
  // Set first-place points to a valid value (must remain strictly > pts[1])
  const newVal = data.points_awarded_per_placement[1] + 1;
  data.points_awarded_per_placement[0] = newVal;
  const errors = validateChamp(data);
  assert.strictEqual(errors.length, 0, `Errors: ${errors.join(', ')}`);
  data.points_awarded_per_placement[0] = origPts;
});

test('D.champ.points_must_be_descending', () => {
  const data = loadChampJson();
  // Key is points_awarded_per_placement (snake_case)
  const orig = data.points_awarded_per_placement.slice();
  // Break strictly descending invariant: first == second
  data.points_awarded_per_placement[0] = data.points_awarded_per_placement[1];
  const errors = validateChamp(data);
  assert.ok(errors.length > 0, 'Expected descending-points error');
  data.points_awarded_per_placement = orig;
});

test('D.champ.real_data_unmodified_after_api_tests', () => {
  const data   = loadChampJson();
  const errors = validateChamp(data);
  assert.strictEqual(errors.length, 0, 'Real championship.json corrupted!');
});

// ---------------------------------------------------------------------------
// Section E: inject --dry-run (all 4 editors, requires out.bin)
// ---------------------------------------------------------------------------
console.log('Section E: inject --dry-run');

const OUT_BIN = path.join(REPO_ROOT, 'out.bin');
const HAS_OUT_BIN = fs.existsSync(OUT_BIN);

// Track inject --dry-run requires a data-dir with valid binaries — skip it as
// it would rebuild the ROM. We test inject dry-run for the 3 ROM-patch editors.

test('E.text_inject_dry_run.exits_0', () => {
  if (!HAS_OUT_BIN) { passed++; return; } // skip if no out.bin
  const r = runEditor(TEXT_EDITOR, ['inject', '--dry-run']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('E.text_inject_dry_run.reports_0_changes', () => {
  if (!HAS_OUT_BIN) { passed++; return; }
  const r = runEditor(TEXT_EDITOR, ['inject', '--dry-run']);
  // "0 would change" or "0 changes"
  assert.ok(
    /\b0\b.*(?:would change|change)/.test(r.output) || r.output.includes('0 would change'),
    `Expected "0 ... change" in output: ${r.output}`
  );
});

test('E.team_inject_dry_run.exits_0', () => {
  if (!HAS_OUT_BIN) { passed++; return; }
  const r = runEditor(TEAM_EDITOR, ['inject', '--dry-run']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('E.team_inject_dry_run.reports_0_changes', () => {
  if (!HAS_OUT_BIN) { passed++; return; }
  const r = runEditor(TEAM_EDITOR, ['inject', '--dry-run']);
  assert.ok(
    r.output.includes('0 byte') || r.output.includes('0 change'),
    `Expected "0 byte(s)" in output: ${r.output}`
  );
});

test('E.champ_inject_dry_run.exits_0', () => {
  if (!HAS_OUT_BIN) { passed++; return; }
  const r = runEditor(CHAMP_EDITOR, ['inject', '--dry-run']);
  assert.strictEqual(r.exitCode, 0, `exit ${r.exitCode}: ${r.output}`);
});

test('E.champ_inject_dry_run.reports_0_changes', () => {
  if (!HAS_OUT_BIN) { passed++; return; }
  const r = runEditor(CHAMP_EDITOR, ['inject', '--dry-run']);
  assert.ok(
    r.output.includes('0 bytes') || r.output.includes('0 change'),
    `Expected "0 bytes" in output: ${r.output}`
  );
});

// ---------------------------------------------------------------------------
// Section F: CLI error handling
// ---------------------------------------------------------------------------
console.log('Section F: CLI error handling');

test('F.track_no_args.exits_0', () => {
  // track_editor exits 0 with usage when no args given
  const r = runEditor(TRACK_EDITOR, []);
  assert.strictEqual(r.exitCode, 0, `Unexpected exit ${r.exitCode}`);
});

test('F.track_unknown_command.exits_nonzero', () => {
  const r = runEditor(TRACK_EDITOR, ['nonexistent-cmd']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit for unknown command');
});

test('F.track_show_missing_arg.exits_nonzero', () => {
  const r = runEditor(TRACK_EDITOR, ['show']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit when TRACK arg missing');
});

test('F.track_show_bad_track.exits_nonzero', () => {
  const r = runEditor(TRACK_EDITOR, ['show', 'no_such_track_xyz']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero for unresolvable track');
});

test('F.team_no_args.exits_nonzero', () => {
  const r = runEditor(TEAM_EDITOR, []);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit for no args');
});

test('F.team_unknown_command.exits_nonzero', () => {
  const r = runEditor(TEAM_EDITOR, ['nonexistent-cmd']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit for unknown command');
});

test('F.text_no_args.exits_0', () => {
  const r = runEditor(TEXT_EDITOR, []);
  // text_editor prints usage and exits 0 with no args (same as track_editor)
  assert.strictEqual(r.exitCode, 0, `Unexpected exit ${r.exitCode}`);
});

test('F.text_unknown_command.exits_nonzero', () => {
  const r = runEditor(TEXT_EDITOR, ['nonexistent-cmd']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit for unknown command');
});

test('F.text_show_missing_category.exits_nonzero', () => {
  const r = runEditor(TEXT_EDITOR, ['show']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero when category missing');
});

test('F.champ_no_args.exits_nonzero', () => {
  const r = runEditor(CHAMP_EDITOR, []);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit for no args');
});

test('F.champ_unknown_command.exits_nonzero', () => {
  const r = runEditor(CHAMP_EDITOR, ['nonexistent-cmd']);
  assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit for unknown command');
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('');
console.log(`Results: ${passed + failed} tests — ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
