#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	TRACK_METADATA_FIELDS,
	ensureAssignedHorizonOverride,
	getGeneratedGeometryState,
	ensureOriginalMinimapPos,
	getAssignedArtName,
	getAssignedHorizonOverride,
	getGeneratedMinimapPreview,
	getGeneratedSpecialRoadFeatures,
	getTrackTopologyReport,
	isRuntimeSafeRandomized,
	preservesOriginalSignCadence,
	setAssignedArtName,
	setAssignedHorizonOverride,
	setGeneratedGeometryState,
	setGeneratedMinimapPreview,
	setGeneratedSpecialRoadFeatures,
	setPreserveOriginalSignCadence,
	setTrackTopologyReport,
	setRuntimeSafeRandomized,
} = require('../randomizer/track_metadata');

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

console.log('Section A: track metadata helpers');

test('runtime safe flag helper round-trips', () => {
	const track = {};
	setRuntimeSafeRandomized(track, true);
	assert.strictEqual(isRuntimeSafeRandomized(track), true);
	setRuntimeSafeRandomized(track, false);
	assert.strictEqual(isRuntimeSafeRandomized(track), false);
});

test('preserve original sign cadence helper defaults true and stores false', () => {
	const track = {};
	assert.strictEqual(preservesOriginalSignCadence(track), true);
	setPreserveOriginalSignCadence(track, false);
	assert.strictEqual(track[TRACK_METADATA_FIELDS.preserveOriginalSignCadence], false);
	assert.strictEqual(preservesOriginalSignCadence(track), false);
});

test('assigned horizon helper falls back to base field and can be ensured', () => {
	const track = { horizon_override: 1 };
	assert.strictEqual(getAssignedHorizonOverride(track), 1);
	ensureAssignedHorizonOverride(track);
	assert.strictEqual(track[TRACK_METADATA_FIELDS.assignedHorizonOverride], 1);
	setAssignedHorizonOverride(track, 0);
	assert.strictEqual(getAssignedHorizonOverride(track), 0);
});

test('original minimap helper clones current minimap once', () => {
	const track = { minimap_pos: [[1, 2], [3, 4]] };
	const original = ensureOriginalMinimapPos(track);
	assert.deepStrictEqual(original, [[1, 2], [3, 4]]);
	track.minimap_pos[0][0] = 9;
	assert.deepStrictEqual(track[TRACK_METADATA_FIELDS.originalMinimapPos], [[1, 2], [3, 4]]);
});

test('generated minimap preview helper defaults to empty object', () => {
	const track = {};
	assert.deepStrictEqual(getGeneratedMinimapPreview(track), {});
	setGeneratedMinimapPreview(track, { match_percent: 88 });
	assert.strictEqual(getGeneratedMinimapPreview(track).match_percent, 88);
});

test('assigned art name helper falls back to track name and stores override', () => {
	const track = { name: 'Brazil' };
	assert.strictEqual(getAssignedArtName(track), 'Brazil');
	setAssignedArtName(track, 'Monaco');
	assert.strictEqual(getAssignedArtName(track), 'Monaco');
});

test('generated special road features helper defaults empty and stores array', () => {
	const track = {};
	assert.deepStrictEqual(getGeneratedSpecialRoadFeatures(track), []);
	setGeneratedSpecialRoadFeatures(track, [{ kind: 'tunnel' }]);
	assert.strictEqual(getGeneratedSpecialRoadFeatures(track).length, 1);
});

test('generated geometry helper stores a cloned transient geometry state', () => {
	const track = {};
	const geometryState = { resampled_centerline: [[1, 2], [3, 4]], topology: { crossing_count: 0 } };
	setGeneratedGeometryState(track, geometryState);
	const stored = getGeneratedGeometryState(track);
	assert.deepStrictEqual(stored, geometryState);
	geometryState.resampled_centerline[0][0] = 99;
	assert.deepStrictEqual(getGeneratedGeometryState(track).resampled_centerline, [[1, 2], [3, 4]]);
});

test('track topology helper stores a cloned topology report summary', () => {
	const track = {};
	const topology = { crossing_count: 1, proper_crossing_count: 1, eligible_for_single_crossing_rule: true };
	setTrackTopologyReport(track, topology);
	assert.deepStrictEqual(getTrackTopologyReport(track), topology);
	topology.crossing_count = 7;
	assert.strictEqual(getTrackTopologyReport(track).crossing_count, 1);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
