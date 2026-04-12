#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	findTrackByIdentifier,
	getTrackCurveSegments,
	getTrackDisplayName,
	getTrackMinimapPairs,
	getTrackMinimapTrailing,
	getTrackSignData,
	getTrackSignTileset,
	getTrackSignTilesetTrailing,
	getTracks,
	requireInjectableTrackShape,
	requirePairList,
	requireRecordList,
	requireSegmentList,
	requireTrackShape,
	requireTracksDataShape,
} = require('../randomizer/track_model');

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

function makeTracksData() {
	return {
		tracks: [
			{ index: 0, slug: 'san_marino', name: 'San Marino', track_length: 4096 },
			{ index: 1, slug: 'brazil', name: 'Brazil', track_length: 4160 },
		],
	};
}

console.log('Section A: track model helpers');

test('requireTrackShape accepts a valid track', () => {
	const track = { index: 0, slug: 'san_marino', name: 'San Marino', track_length: 4096 };
	assert.strictEqual(requireTrackShape(track), track);
});

test('requireTracksDataShape accepts valid track collections', () => {
	const data = makeTracksData();
	assert.strictEqual(requireTracksDataShape(data), data);
	assert.strictEqual(getTracks(data).length, 2);
});

test('findTrackByIdentifier resolves by slug, name, and index', () => {
	const data = makeTracksData();
	assert.strictEqual(findTrackByIdentifier(data, 'san_marino').name, 'San Marino');
	assert.strictEqual(findTrackByIdentifier(data, 'Brazil').slug, 'brazil');
	assert.strictEqual(findTrackByIdentifier(data, 1).slug, 'brazil');
	assert.strictEqual(findTrackByIdentifier(data, '1').slug, 'brazil');
});

test('getTrackDisplayName prefers name then slug', () => {
	assert.strictEqual(getTrackDisplayName({ name: 'Brazil', slug: 'brazil' }), 'Brazil');
	assert.strictEqual(getTrackDisplayName({ slug: 'brazil' }), 'brazil');
	assert.strictEqual(getTrackDisplayName({}), '?');
});

test('requireTrackShape rejects missing slug', () => {
	assert.throws(() => requireTrackShape({ index: 0, name: 'X', track_length: 64 }), /slug/);
});

test('requireSegmentList accepts typed object arrays', () => {
	const segments = [{ type: 'straight', length: 10 }, { type: 'terminator' }];
	assert.strictEqual(requireSegmentList(segments, 'segments'), segments);
});

test('requireRecordList rejects non-object records', () => {
	assert.throws(() => requireRecordList([1], 'records'), /records\[0\] must be an object/);
});

test('requirePairList rejects malformed minimap pairs', () => {
	assert.throws(() => requirePairList([[1]], 'pairs'), /pair array/);
});

test('requireInjectableTrackShape validates nested track arrays', () => {
	const track = {
		index: 0,
		slug: 'san_marino',
		name: 'San Marino',
		track_length: 4096,
		curve_rle_segments: [{ type: 'straight' }],
		slope_rle_segments: [{ type: 'flat' }],
		phys_slope_rle_segments: [{ type: 'segment' }],
		sign_data: [],
		sign_tileset: [],
		minimap_pos: [[0, 0]],
	};
	assert.strictEqual(requireInjectableTrackShape(track), track);
});

test('getTrackCurveSegments and getTrackMinimapPairs return validated nested arrays', () => {
	const track = {
		curve_rle_segments: [{ type: 'straight' }],
		minimap_pos: [[0, 0]],
	};
	assert.strictEqual(getTrackCurveSegments(track), track.curve_rle_segments);
	assert.strictEqual(getTrackMinimapPairs(track), track.minimap_pos);
});

test('sign and trailing helpers return validated arrays', () => {
	const track = {
		sign_data: [{ distance: 1, count: 1, sign_id: 2 }],
		sign_tileset: [{ distance: 0, tileset_offset: 8 }],
		sign_tileset_trailing: [0, 255],
		minimap_pos_trailing: [7, 8],
	};
	assert.strictEqual(getTrackSignData(track), track.sign_data);
	assert.strictEqual(getTrackSignTileset(track), track.sign_tileset);
	assert.strictEqual(getTrackSignTilesetTrailing(track), track.sign_tileset_trailing);
	assert.strictEqual(getTrackMinimapTrailing(track), track.minimap_pos_trailing);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
