#!/usr/bin/env node
'use strict';

const assert = require('assert');

const { buildGeneratedMinimapAssets } = require('../lib/generated_minimap_assets');
const { buildGeneratedMinimapPosPairs } = require('../lib/generated_minimap_pos');
const { sampleClosedPath } = require('../lib/minimap_analysis');
const { setGeneratedGeometryState } = require('../randomizer/track_metadata');
const { createBlankTile, createPreview, stampTile } = require('./minimap_synthetic_fixtures');

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

function makeTrack() {
	return {
		name: 'San Marino',
		slug: 'san_marino',
		index: 0,
		track_length: 256,
		minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]],
	};
}

function makePreviewWithTile(rows, tileX = 0, tileY = 0) {
	const preview = createPreview();
	stampTile(preview, tileX, tileY, rows);
	preview.centerline_points = [[10, 10], [20, 10], [20, 20], [10, 20]];
	preview.start_index = 0;
	return preview;
}

console.log('Section A: map-first minimap regressions');

test('runtime minimap pairs can follow transient runtime pair projection without using preview output', () => {
	const track = makeTrack();
	const runtimePairs = [[11, 12], [21, 22], [31, 32], [41, 42]];
	const tile = createBlankTile();
	tile[0][0] = 1;
	setGeneratedGeometryState(track, {
		projections: {
			minimap_runtime: { pairs: runtimePairs },
			minimap_preview: makePreviewWithTile(tile),
		},
	});
	assert.deepStrictEqual(buildGeneratedMinimapPosPairs(track), runtimePairs);
	const assets = buildGeneratedMinimapAssets(track);
	assert.strictEqual(assets.tiles.length, 1);
	assert.strictEqual(assets.words[0], 1);
});

test('runtime start anchoring can diverge from preview start index', () => {
	const track = makeTrack();
	const tile = createBlankTile();
	tile[1][1] = 1;
	const runtimeCenterline = [[1, 10], [2, 20], [3, 30], [4, 40]];
	const previewCenterline = [[9, 90], [8, 80], [7, 70], [6, 60]];
	setGeneratedGeometryState(track, {
		projections: {
			minimap_runtime: {
				centerline_points: runtimeCenterline,
				start_index: 2,
			},
			minimap_preview: Object.assign(makePreviewWithTile(tile), {
				centerline_points: previewCenterline,
				start_index: 0,
			}),
		},
	});
	const actual = buildGeneratedMinimapPosPairs(track);
	const rotatedRuntime = runtimeCenterline.slice(2).concat(runtimeCenterline.slice(0, 2));
	const expectedRuntime = sampleClosedPath(rotatedRuntime, 4).map(([x, y]) => [Math.round(y), Math.round(x)]);
	const expectedPreview = sampleClosedPath(previewCenterline, 4).map(([x, y]) => [Math.round(y), Math.round(x)]);
	assert.deepStrictEqual(actual, expectedRuntime);
	assert.notDeepStrictEqual(actual, expectedPreview);
	const assets = buildGeneratedMinimapAssets(track);
	assert.strictEqual(assets.tiles.length, 1);
});

test('preview asset cache invalidates when transient preview projection changes', () => {
	const track = makeTrack();
	const tileA = createBlankTile();
	tileA[0][0] = 1;
	const tileB = createBlankTile();
	tileB[0][0] = 1;
	tileB[0][1] = 1;
	setGeneratedGeometryState(track, {
		projections: {
			minimap_runtime: { pairs: [[1, 2], [3, 4], [5, 6], [7, 8]] },
			minimap_preview: makePreviewWithTile(tileA),
		},
	});
	const first = buildGeneratedMinimapAssets(track);
	setGeneratedGeometryState(track, {
		projections: {
			minimap_runtime: { pairs: [[1, 2], [3, 4], [5, 6], [7, 8]] },
			minimap_preview: makePreviewWithTile(tileB),
		},
	});
	const second = buildGeneratedMinimapAssets(track);
	assert.notDeepStrictEqual(first.tiles, second.tiles);
	assert.deepStrictEqual(buildGeneratedMinimapPosPairs(track), [[1, 2], [3, 4], [5, 6], [7, 8]]);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
