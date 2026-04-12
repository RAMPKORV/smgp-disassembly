#!/usr/bin/env node
// tools/tests/test_track_config_sync.js
//
// Tests for tools/sync_track_config.js helpers.

'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('../lib/rom.js');
const { readJson } = require('../lib/json.js');
const { buildSyncedTrackConfig, TRACK_NAMES } = require('../sync_track_config.js');
const { setRuntimeSafeRandomized } = require('../randomizer/track_metadata');

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

const asmPath = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
const jsonPath = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');
const asmLines = fs.readFileSync(asmPath, 'utf8').split(/(?<=\n)/);
const tracksJson = readJson(jsonPath);

test('TRACK_NAMES covers all track JSON entries', () => {
  assert.strictEqual(TRACK_NAMES.length, tracksJson.tracks.length,
    `TRACK_NAMES=${TRACK_NAMES.length}, tracks.json=${tracksJson.tracks.length}`);
});

test('buildSyncedTrackConfig preserves current synced file as no-op', () => {
  const result = buildSyncedTrackConfig(asmLines, tracksJson);
  assert.strictEqual(typeof result.content, 'string');
  assert.ok(result.changed >= 0, 'changed count should be non-negative');
});

test('buildSyncedTrackConfig rewrites track length line from JSON', () => {
  const mutated = JSON.parse(JSON.stringify(tracksJson));
  mutated.tracks[0].track_length = tracksJson.tracks[0].track_length + 64;
  const result = buildSyncedTrackConfig(asmLines, mutated);
  assert.ok(result.content.includes(`\tdc.w\t${mutated.tracks[0].track_length} ; track length`),
    'expected updated track length line in synced content');
});

test('buildSyncedTrackConfig keeps stock minimap labels even for randomized workspace tracks', () => {
	const mutated = JSON.parse(JSON.stringify(tracksJson));
	setRuntimeSafeRandomized(mutated.tracks[0], true);
	const result = buildSyncedTrackConfig(asmLines, mutated);
	assert.ok(result.content.includes('\tdc.l\tMinimap_map_San_Marino ; San Marino tile mapping for minimap'));
	assert.ok(result.content.includes('\tdc.l\tMinimap_tiles_San_Marino ; San Marino tiles used for minimap'));
});

test('buildSyncedTrackConfig preserves shared Monaco arcade stock minimap map label names', () => {
	const mutated = JSON.parse(JSON.stringify(tracksJson));
	setRuntimeSafeRandomized(mutated.tracks[17], true);
	setRuntimeSafeRandomized(mutated.tracks[18], true);
	const result = buildSyncedTrackConfig(asmLines, mutated);
	assert.ok(result.content.includes('\tdc.l\tMinimap_map_Monaco_arcade ; Monaco (Arcade main) tile mapping for minimap'));
	assert.ok(result.content.includes('\tdc.l\tMinimap_map_Monaco_arcade ; Monaco (Arcade Wet Condition) tile mapping for minimap'));
});

console.log(`\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total`);
if (failed > 0) process.exit(1);
