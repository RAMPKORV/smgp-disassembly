#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const {
	randomizeArtConfig,
	buildTrackConfigAsm,
	CHAMPIONSHIP_ART_SETS,
	CHAMPIONSHIP_TRACK_NAMES,
} = require('../randomizer/track_randomizer');
const {
	randomizeTeams,
	randomizeAi,
	validateTeams,
	ACCEL_INDEX_POOL,
	ENGINE_INDEX_POOL,
} = require('../randomizer/team_randomizer');
const {
	randomizeChampionship,
	validateChampionship,
	NUM_CHAMPIONSHIP_TRACKS,
	FIXED_FINAL_SLOT,
	RIVAL_BASE_MIN,
	RIVAL_BASE_MAX,
	RIVAL_DELTA_MIN,
	RIVAL_DELTA_MAX,
	LAP_TIME_TABLE_BYTES,
} = require('../randomizer/championship_randomizer');
const { buildGeneratedMinimapAssetsAsm } = require('../lib/generated_minimap_assets');
const { buildGeneratedTrackBlock, GENERATED_MINIMAP_DATA_FILE } = require('../generate_track_data_asm');
const { writeAlignedBlock } = require('../patch_all_track_minimap_assets_rom');
const { REPO_ROOT } = require('../lib/rom');
const {
	deepCopy,
	loadChampionshipJson,
	loadTeamsJson,
	loadTracksJson,
} = require('./randomizer_test_utils');

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

const teamsJson = loadTeamsJson();
const champJson = loadChampionshipJson();
const tracksJson = loadTracksJson();

console.log('Section A: Team randomizer');

test('ROM teams JSON validates clean before randomization', () => {
	const errors = validateTeams(teamsJson);
	assert.strictEqual(errors.length, 0, `ROM teams validation errors: ${errors.join('; ')}`);
});

test('randomizeTeams produces valid team data', () => {
	const data = deepCopy(teamsJson);
	randomizeTeams(data, 12345);
	const errors = validateTeams(data);
	assert.strictEqual(errors.length, 0, `Post-randomize team errors: ${errors.join('; ')}`);
});

test('randomizeAi produces valid team data', () => {
	const data = deepCopy(teamsJson);
	randomizeAi(data, 54321);
	const errors = validateTeams(data);
	assert.strictEqual(errors.length, 0, `Post-AI-randomize errors: ${errors.join('; ')}`);
});

test('randomizeTeams + randomizeAi combined produce valid data', () => {
	const data = deepCopy(teamsJson);
	randomizeTeams(data, 11111);
	randomizeAi(data, 11111);
	const errors = validateTeams(data);
	assert.strictEqual(errors.length, 0, `Combined randomize errors: ${errors.join('; ')}`);
});

test('randomizeTeams is reproducible with same seed', () => {
	const d1 = deepCopy(teamsJson);
	const d2 = deepCopy(teamsJson);
	randomizeTeams(d1, 7777);
	randomizeTeams(d2, 7777);
	assert.deepStrictEqual(d1.team_car_characteristics.map(c => c.accel_index), d2.team_car_characteristics.map(c => c.accel_index));
});

test('randomizeTeams produces different result for different seeds', () => {
	const d1 = deepCopy(teamsJson);
	const d2 = deepCopy(teamsJson);
	randomizeTeams(d1, 1);
	randomizeTeams(d2, 2);
	assert.notStrictEqual(d1.team_car_characteristics.map(c => c.accel_index).join(','), d2.team_car_characteristics.map(c => c.accel_index).join(','));
});

test('randomizeTeams preserves accel_index pool as exact multiset', () => {
	const data = deepCopy(teamsJson);
	const originalPool = data.team_car_characteristics.map(c => c.accel_index).sort((a, b) => a - b);
	randomizeTeams(data, 42);
	const newPool = data.team_car_characteristics.map(c => c.accel_index).sort((a, b) => a - b);
	assert.deepStrictEqual(newPool, originalPool);
});

test('randomizeTeams preserves engine_index pool as exact multiset', () => {
	const data = deepCopy(teamsJson);
	const originalPool = data.team_car_characteristics.map(c => c.engine_index).sort((a, b) => a - b);
	randomizeTeams(data, 42);
	const newPool = data.team_car_characteristics.map(c => c.engine_index).sort((a, b) => a - b);
	assert.deepStrictEqual(newPool, originalPool);
});

test('randomizeTeams all accel_index values are in ACCEL_INDEX_POOL', () => {
	const data = deepCopy(teamsJson);
	randomizeTeams(data, 999);
	const pool = new Set(ACCEL_INDEX_POOL);
	for (const car of data.team_car_characteristics) assert.ok(pool.has(car.accel_index), `accel_index ${car.accel_index} not in pool`);
});

test('randomizeTeams all engine_index values are in ENGINE_INDEX_POOL', () => {
	const data = deepCopy(teamsJson);
	randomizeTeams(data, 888);
	const pool = new Set(ENGINE_INDEX_POOL);
	for (const car of data.team_car_characteristics) assert.ok(pool.has(car.engine_index), `engine_index ${car.engine_index} not in pool`);
});

test('randomizeAi preserves ai_performance_factor pool as multiset', () => {
	const data = deepCopy(teamsJson);
	const originalPool = data.ai_performance_factor.map(f => f.factor).sort((a, b) => a - b);
	randomizeAi(data, 555);
	const newPool = data.ai_performance_factor.map(f => f.factor).sort((a, b) => a - b);
	assert.deepStrictEqual(newPool, originalPool);
});

test('randomizeAi partner_threshold >= promote_threshold + 2 for all teams', () => {
	const data = deepCopy(teamsJson);
	randomizeAi(data, 321);
	for (const t of data.post_race_driver_target_points) {
		assert.ok(t.partner_threshold >= t.promote_threshold + 2, `${t.name}: partner=${t.partner_threshold} must be >= promote=${t.promote_threshold}+2`);
	}
});

console.log('Section B: Championship randomizer');

test('ROM championship JSON validates clean before randomization', () => {
	const errors = validateChampionship(champJson);
	assert.strictEqual(errors.length, 0, `ROM championship validation errors: ${errors.join('; ')}`);
});

test('randomizeChampionship produces valid data', () => {
	const data = deepCopy(champJson);
	randomizeChampionship(data, 12345);
	const errors = validateChampionship(data);
	assert.strictEqual(errors.length, 0, `Post-randomize championship errors: ${errors.join('; ')}`);
});

test('randomizeChampionship Monaco stays in final slot', () => {
	const data = deepCopy(champJson);
	randomizeChampionship(data, 99999);
	assert.strictEqual(data._meta.championship_track_order[FIXED_FINAL_SLOT], 'Monaco');
});

test('randomizeChampionship track order is a valid permutation (no duplicates)', () => {
	const data = deepCopy(champJson);
	randomizeChampionship(data, 77777);
	const order = data._meta.championship_track_order;
	assert.strictEqual(order.length, NUM_CHAMPIONSHIP_TRACKS);
	assert.strictEqual(new Set(order).size, NUM_CHAMPIONSHIP_TRACKS, 'duplicate track in championship order');
});

test('randomizeChampionship contains the same set of tracks as original', () => {
	const data = deepCopy(champJson);
	const originalSet = new Set(champJson._meta.championship_track_order);
	randomizeChampionship(data, 11111);
	const newSet = new Set(data._meta.championship_track_order);
	for (const track of originalSet) assert.ok(newSet.has(track), `track ${track} missing after randomization`);
});

test('randomizeChampionship is reproducible with same seed', () => {
	const d1 = deepCopy(champJson);
	const d2 = deepCopy(champJson);
	randomizeChampionship(d1, 5555);
	randomizeChampionship(d2, 5555);
	assert.deepStrictEqual(d1._meta.championship_track_order, d2._meta.championship_track_order);
	assert.deepStrictEqual(d1.rival_grid_base_table, d2.rival_grid_base_table);
});

test('randomizeChampionship rival_grid_base values are in [0, 15]', () => {
	const data = deepCopy(champJson);
	randomizeChampionship(data, 33333);
	for (let i = 0; i < data.rival_grid_base_table.length; i++) {
		const v = data.rival_grid_base_table[i];
		assert.ok(v >= RIVAL_BASE_MIN && v <= RIVAL_BASE_MAX, `rival_base[${i}]=${v} out of [${RIVAL_BASE_MIN},${RIVAL_BASE_MAX}]`);
	}
});

test('randomizeChampionship rival_grid_delta values are in [-3, 2]', () => {
	const data = deepCopy(champJson);
	randomizeChampionship(data, 22222);
	for (let i = 0; i < data.rival_grid_delta_table.length; i++) {
		const v = data.rival_grid_delta_table[i];
		assert.ok(v >= RIVAL_DELTA_MIN && v <= RIVAL_DELTA_MAX, `rival_delta[${i}]=${v} out of [${RIVAL_DELTA_MIN},${RIVAL_DELTA_MAX}]`);
	}
});

test('randomizeChampionship pre_race_lap_time_offset_table has correct length', () => {
	const data = deepCopy(champJson);
	randomizeChampionship(data, 44444);
	assert.strictEqual(data.pre_race_lap_time_offset_table.length, LAP_TIME_TABLE_BYTES);
});

test('validateChampionship rejects non-Monaco final slot', () => {
	const data = deepCopy(champJson);
	const monacoIdx = data._meta.championship_track_order.indexOf('Monaco');
	data._meta.championship_track_order[monacoIdx] = data._meta.championship_track_order[0];
	data._meta.championship_track_order[0] = 'Monaco';
	assert.ok(validateChampionship(data).length > 0, 'expected validation error for Monaco not in final slot');
});

test('validateChampionship rejects duplicate track', () => {
	const data = deepCopy(champJson);
	data._meta.championship_track_order[0] = data._meta.championship_track_order[1];
	assert.ok(validateChampionship(data).length > 0, 'expected validation error for duplicate track');
});

console.log('Section C: Art config');

test('CHAMPIONSHIP_ART_SETS has 16 entries', () => {
	assert.strictEqual(CHAMPIONSHIP_ART_SETS.length, 16);
});

test('CHAMPIONSHIP_TRACK_NAMES has 16 entries', () => {
	assert.strictEqual(CHAMPIONSHIP_TRACK_NAMES.length, 16);
});

test('randomizeArtConfig returns 16 entries', () => {
	assert.strictEqual(randomizeArtConfig(12345).length, 16);
});

test('randomizeArtConfig is a permutation of CHAMPIONSHIP_ART_SETS', () => {
	const assignment = randomizeArtConfig(99);
	const originalNames = new Set(CHAMPIONSHIP_ART_SETS.map(s => JSON.stringify(s)));
	for (const artSet of assignment) assert.ok(originalNames.has(JSON.stringify(artSet)), `art set not from original pool: ${JSON.stringify(artSet)}`);
	const assignedNames = assignment.map(s => JSON.stringify(s));
	assert.strictEqual(new Set(assignedNames).size, 16, 'duplicate art sets in assignment');
});

test('randomizeArtConfig is reproducible with same seed', () => {
	assert.deepStrictEqual(randomizeArtConfig(777), randomizeArtConfig(777));
});

test('randomizeArtConfig produces different result for different seeds', () => {
	assert.notDeepStrictEqual(randomizeArtConfig(1), randomizeArtConfig(2));
});

test('buildTrackConfigAsm runs without throwing', () => {
	const assignment = randomizeArtConfig(42);
	const asmPath = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
	assert.doesNotThrow(() => buildTrackConfigAsm(assignment, asmPath));
});

test('buildTrackConfigAsm output contains 16 track comment headers', () => {
	const assignment = randomizeArtConfig(42);
	const asmPath = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
	const result = buildTrackConfigAsm(assignment, asmPath);
	let count = 0;
	for (const name of CHAMPIONSHIP_TRACK_NAMES) if (result.includes(`; ${name}`)) count++;
	assert.strictEqual(count, 16, `expected 16 track headers, found ${count}`);
});

test('buildGeneratedMinimapAssetsAsm emits labels for all tracks', () => {
	const result = buildGeneratedMinimapAssetsAsm(tracksJson.tracks);
	assert.ok(result.content.includes('Generated_Minimap_Track_00_San_Marino_tiles:'));
	assert.ok(result.content.includes('Generated_Minimap_Track_17_Monaco_Arcade_Main_tiles:'));
	assert.ok(result.content.includes('Generated_Minimap_Track_18_Monaco_Arcade_Wet_map:'));
});

test('buildGeneratedTrackBlock excludes generated minimap include by default', () => {
	const asm = buildGeneratedTrackBlock();
	assert.ok(!asm.includes(`\tinclude\t"${GENERATED_MINIMAP_DATA_FILE}"`));
});

test('buildGeneratedTrackBlock can include generated minimap include when requested', () => {
	const asm = buildGeneratedTrackBlock({ includeGeneratedMinimapData: true });
	assert.ok(asm.includes(`\tinclude\t"${GENERATED_MINIMAP_DATA_FILE}"`));
});

test('writeAlignedBlock appends after current ROM length without truncating larger ROMs', () => {
	const rom = Buffer.alloc(0x90010, 0xFF);
	const bytes = Buffer.from([0x12, 0x34, 0x56]);
	const cursor = 0x90000;
	const block = writeAlignedBlock(rom, cursor, bytes);
	assert.strictEqual(block.start, 0x90000);
	assert.strictEqual(block.end, 0x90003);
	assert.strictEqual(rom[0x90000], 0x12);
	assert.strictEqual(rom[0x90001], 0x34);
	assert.strictEqual(rom[0x90002], 0x56);
});

test('generated track block preserves canonical track block size using fallback symbol map', () => {
	const symbolMap = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json'), 'utf8')).symbols;
	const start = parseInt(symbolMap.San_Marino_curve_data, 16);
	const blob = parseInt(symbolMap.Monaco_arcade_post_sign_tileset_blob, 16);
	const blobSize = fs.statSync(path.join(REPO_ROOT, 'data', 'tracks', 'monaco_arcade', 'post_sign_tileset_blob.bin')).size;
	const baselineFullSize = (blob - start) + blobSize;
	const asm = buildGeneratedTrackBlock({ includeGeneratedMinimapData: false, preBlobPadBytes: 0, padBytes: 0 });
	let total = 0;
	for (const line of asm.split(/\r?\n/)) {
		const incbin = line.match(/^\s*incbin\s+"([^"]+)"/i);
		if (incbin) {
			const filePath = path.join(REPO_ROOT, incbin[1]);
			if (fs.existsSync(filePath)) total += fs.statSync(filePath).size;
			continue;
		}
		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) total += parseInt(dcb[1], 10);
	}
	assert.strictEqual(total, baselineFullSize);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
