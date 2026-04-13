#!/usr/bin/env node
'use strict';

const assert = require('assert');
const { loadTracksJson } = require('./randomizer_test_utils');
const {
	createBlankTile,
	createPreview,
	createStockPreview,
	degeneratePreview,
	sparsePreview,
	stampTile,
} = require('./minimap_synthetic_fixtures');

const {
	buildGeneratedMinimapAssetsFromPreviews,
	buildTilesAndWordsFromPreview,
	resolvePreservedExternalCellIndexSet,
	buildGeneratedMinimapAssets,
} = require('../lib/generated_minimap_assets');
const {
	buildPreviewRawMap,
	buildHudRawMap,
} = require('../patch_all_track_minimap_raw_maps_rom');
const { getMinimapPreview } = require('../lib/minimap_preview');
const { buildGeneratedMinimapPreview } = require('../lib/minimap_render');
const { chooseStartIndex, styleRoadPreview } = require('../lib/minimap_raster');
const { resolvePreviewSlug } = require('../lib/minimap_analysis');
const { getCourseSelectReservedLocalTileIndices } = require('../lib/course_select_preview_tiles');
const { getTracks, requireTracksDataShape } = require('../randomizer/track_model');
const { setGeneratedGeometryState } = require('../randomizer/track_metadata');
const { randomizeTracks } = require('../randomizer/track_randomizer');

const PREVIEW_WIDTH = 56;
const PREVIEW_HEIGHT = 88;
const PREVIEW_TILE_COLUMNS = 7;
const PREVIEW_TILE_ROWS = 11;
const PREVIEW_TILE_COUNT = PREVIEW_TILE_COLUMNS * PREVIEW_TILE_ROWS;

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

console.log('Section A: generated minimap asset helpers');

test('buildTilesAndWordsFromPreview keeps blank preview fully empty', () => {
	const preview = createPreview();
	const result = buildTilesAndWordsFromPreview(preview);
	assert.strictEqual(result.tiles.length, 0);
	assert.strictEqual(result.words.length, PREVIEW_TILE_COUNT);
	assert.ok(result.words.every(word => word === 0));
});

test('buildTilesAndWordsFromPreview reuses duplicate tile patterns', () => {
	const preview = createPreview();
	const repeatedTile = createBlankTile();
	for (let i = 0; i < 8; i++) repeatedTile[i][i] = 1;
	stampTile(preview, 0, 0, repeatedTile);
	stampTile(preview, 1, 0, repeatedTile);
	const result = buildTilesAndWordsFromPreview(preview);
	assert.strictEqual(result.tiles.length, 1);
	assert.strictEqual(result.words[0], 1);
	assert.strictEqual(result.words[1], 1);
	assert.ok(result.words.slice(2).every(word => word === 0));
});

test('buildTilesAndWordsFromPreview reuses horizontally flipped tile patterns', () => {
	const preview = createPreview();
	const tileA = createBlankTile();
	tileA[1][1] = 1;
	tileA[2][3] = 1;
	tileA[5][0] = 1;
	const tileB = tileA.map(row => row.slice().reverse());
	stampTile(preview, 0, 0, tileA);
	stampTile(preview, 1, 0, tileB);
	const result = buildTilesAndWordsFromPreview(preview);
	assert.strictEqual(result.tiles.length, 1);
	assert.strictEqual(result.words[0], 1);
	assert.strictEqual(result.words[1], 0x1001);
});

test('buildTilesAndWordsFromPreview reuses vertically flipped tile patterns', () => {
	const preview = createPreview();
	const tileA = createBlankTile();
	tileA[0][2] = 1;
	tileA[3][5] = 1;
	tileA[6][1] = 1;
	const tileB = tileA.slice().reverse().map(row => row.slice());
	stampTile(preview, 0, 0, tileA);
	stampTile(preview, 1, 0, tileB);
	const result = buildTilesAndWordsFromPreview(preview);
	assert.strictEqual(result.tiles.length, 1);
	assert.strictEqual(result.words[0], 1);
	assert.strictEqual(result.words[1], 0x0801);
});

test('raw minimap map builders preserve tile flip bits', () => {
	const preview = createPreview();
	const tileA = createBlankTile();
	tileA[1][1] = 1;
	tileA[2][3] = 1;
	tileA[5][0] = 1;
	const tileB = tileA.map(row => row.slice().reverse());
	stampTile(preview, 0, 0, tileA);
	stampTile(preview, 1, 0, tileB);
	const assets = buildGeneratedMinimapAssetsFromPreviews(preview, null, 'synthetic');
	const previewRaw = buildPreviewRawMap({ slug: 'synthetic' }, assets);
	const hudRaw = buildHudRawMap({ slug: 'synthetic' }, assets);
	assert.strictEqual(previewRaw.readUInt16BE(0), 0x0001);
	assert.strictEqual(previewRaw.readUInt16BE(2), 0x1001);
	assert.strictEqual(hudRaw.readUInt16BE(0), 0x8001);
	assert.strictEqual(hudRaw.readUInt16BE(2), 0x9001);
});

test('buildGeneratedMinimapAssetsFromPreviews preserves tiles beyond stock capacity', () => {
	const preview = createPreview();
	const tileA = createBlankTile(1);
	const tileB = createBlankTile(2);
	stampTile(preview, 0, 0, tileA);
	stampTile(preview, 1, 0, tileB);
	const result = buildGeneratedMinimapAssetsFromPreviews(preview, createStockPreview(1, PREVIEW_TILE_COUNT));
	assert.strictEqual(result.tiles.length, 2);
	assert.strictEqual(result.words[0], 1);
	assert.strictEqual(result.words[1], 2);
	assert.ok(result.map_bytes.length > 0);
});

test('buildGeneratedMinimapAssetsFromPreviews does not pad back to stock tile count', () => {
	const preview = createPreview();
	const tileA = createBlankTile();
	for (let x = 0; x < 8; x++) tileA[0][x] = 3;
	stampTile(preview, 0, 0, tileA);
	const stockPreview = createStockPreview(3, PREVIEW_TILE_COUNT);
	const result = buildGeneratedMinimapAssetsFromPreviews(preview, stockPreview);
	assert.strictEqual(result.tiles.length, 1);
	assert.deepStrictEqual(result.tiles[0], tileA);
	assert.ok(result.tile_bytes.length > 0);
	assert.ok(result.map_bytes.length > 0);
	assert.strictEqual(result.words[0], 1);
});

test('resolvePreservedExternalCellIndexSet reads explicit config entries', () => {
	const set = resolvePreservedExternalCellIndexSet('monaco', { monaco: [0, 5, 9] });
	assert.deepStrictEqual(Array.from(set).sort((a, b) => a - b), [0, 5, 9]);
});

test('buildTilesAndWordsFromPreview preserves configured external stock cell when tile is blank', () => {
	const preview = createPreview();
	const stockPreview = createStockPreview(2, PREVIEW_TILE_COUNT);
	stockPreview.words[0] = 0x8003;
	const result = buildTilesAndWordsFromPreview(preview, stockPreview, 'monaco', {
		preservedExternalCellIndexConfig: { monaco: [0] },
	});
	assert.strictEqual(result.words[0], 0x8003);
	assert.ok(result.words.slice(1).every(word => word === 0));
});

test('buildTilesAndWordsFromPreview keeps sparse under-drawn preview within tile budget', () => {
	const preview = sparsePreview();
	const result = buildTilesAndWordsFromPreview(preview);
	assert.ok(result.tiles.length <= 2);
	assert.ok(result.words.some(word => word !== 0));
});

test('buildTilesAndWordsFromPreview handles degenerate vertical-stroke preview', () => {
	const preview = degeneratePreview();
	const result = buildTilesAndWordsFromPreview(preview);
	assert.ok(result.tiles.length > 0);
	assert.strictEqual(result.words.length, PREVIEW_TILE_COUNT);
});

test('fixed-seed randomized Canada keeps all generated minimap tiles', () => {
	const tracksData = requireTracksDataShape(loadTracksJson());
	randomizeTracks(tracksData, 12345, new Set(['canada']), false);
	const track = getTracks(tracksData).find(entry => entry.slug === 'canada');
	const previewSlug = resolvePreviewSlug(track);
	const stockPreview = getMinimapPreview(previewSlug);
	const generatedPreview = buildGeneratedMinimapPreview(track);
	const raw = buildTilesAndWordsFromPreview(generatedPreview, stockPreview, previewSlug);
	const finalAssets = buildGeneratedMinimapAssetsFromPreviews(generatedPreview, stockPreview, previewSlug);
	assert.ok(raw.tiles.length > 0, 'expected generated preview tiles');
	assert.strictEqual(finalAssets.tiles.length, raw.tiles.length);
	assert.strictEqual(Math.max(...finalAssets.words), Math.max(...raw.words));
});

test('generated minimap assets preserve course-select reserved local tiles for Spain seed', () => {
	const tracksData = requireTracksDataShape(loadTracksJson());
	randomizeTracks(tracksData, 12345, new Set(['spain']), false);
	const track = getTracks(tracksData).find(entry => entry.slug === 'spain');
	const previewSlug = resolvePreviewSlug(track);
	const stockPreview = getMinimapPreview(previewSlug);
	const reserved = getCourseSelectReservedLocalTileIndices(track.index, stockPreview.tile_count);
	assert.ok(reserved.size > 0, 'expected reserved course-select tile indices');
	assert.ok(Array.from(reserved).every(index => index < stockPreview.tiles.length), 'reserved tile index fell outside stock preview tile range');
});

test('styleRoadPreview draws a horizontal start-finish bar across the road span', () => {
	const tracksData = requireTracksDataShape(loadTracksJson());
	const track = getTracks(tracksData).find(entry => entry.slug === 'canada');
	const preview = buildGeneratedMinimapPreview(track);
	const startIndex = chooseStartIndex(preview.centerline_points, preview.width, preview.height, preview.road_pixels);
	const styled = styleRoadPreview(preview.centerline_points, preview.width, preview.height, startIndex);
	const point = preview.centerline_points[startIndex];
	let row = Math.round(point[1]);
	for (let dy = -2; dy <= 2; dy++) {
		const candidateRow = Math.round(point[1]) + dy;
		if (candidateRow < 0 || candidateRow >= preview.height) continue;
		let candidateRun = 0;
		let candidateBest = 0;
		for (let x = 0; x < preview.width; x++) {
			const value = styled.pixels[(candidateRow * preview.width) + x];
			if (value === 1) {
				candidateRun += 1;
				candidateBest = Math.max(candidateBest, candidateRun);
			} else {
				candidateRun = 0;
			}
		}
		if (candidateBest > 0) {
			row = candidateRow;
			break;
		}
	}
	let longestRun = 0;
	let currentRun = 0;
	for (let x = 0; x < preview.width; x++) {
		const value = styled.pixels[(row * preview.width) + x];
		if (value === 1) {
			currentRun += 1;
			longestRun = Math.max(longestRun, currentRun);
		} else {
			currentRun = 0;
		}
	}
	assert.ok(longestRun >= 2, `expected visible horizontal start line, got run length ${longestRun}`);
	assert.ok(longestRun <= 4, `expected compact horizontal start line, got run length ${longestRun}`);
});

test('generated preview start line stays on-road for fixed-seed randomized tracks', () => {
	const tracksData = requireTracksDataShape(loadTracksJson());
	randomizeTracks(tracksData, 12345, null, false);
	for (const track of getTracks(tracksData)) {
		const preview = buildGeneratedMinimapPreview(track);
		const withMarker = styleRoadPreview(preview.centerline_points, preview.width, preview.height, preview.start_index);
		const withoutMarker = styleRoadPreview(preview.centerline_points, preview.width, preview.height, null);
		let onRoadMarkerPixels = 0;
		for (let index = 0; index < withMarker.pixels.length; index++) {
			if (withMarker.pixels[index] === withoutMarker.pixels[index]) continue;
			if (!withoutMarker.road_pixels[index]) continue;
			onRoadMarkerPixels += 1;
		}
		assert.ok(onRoadMarkerPixels >= 3, `${track.slug} expected visible on-road start line`);
	}
});

test('generated preview start line stays on a narrow near-vertical road section', () => {
	const tracksData = requireTracksDataShape(loadTracksJson());
	for (const slug of ['san_marino', 'hungary', 'japan']) {
		const track = getTracks(tracksData).find(entry => entry.slug === slug);
		const preview = buildGeneratedMinimapPreview(track);
		assert.ok(preview.start_verticality >= 0.9, `${slug} start section not vertical enough: ${preview.start_verticality}`);
		const point = preview.centerline_points[preview.start_index];
		const row = Math.round(point[1]);
		let longestRun = 0;
		let currentRun = 0;
		for (let x = 0; x < preview.width; x++) {
			const value = preview.pixels[(row * preview.width) + x];
			if (value === 1) {
				currentRun += 1;
				longestRun = Math.max(longestRun, currentRun);
			} else {
				currentRun = 0;
			}
		}
		assert.ok(longestRun <= 6, `${slug} start line too wide for clean finish marker: ${longestRun}`);
	}
});

test('buildGeneratedMinimapAssets prefers transient preview projection when present', () => {
	const track = { slug: 'san_marino', name: 'San Marino', index: 0, track_length: 256, minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]] };
	const tile = createBlankTile();
	tile[0][0] = 1;
	const preview = createPreview();
	stampTile(preview, 0, 0, tile);
	setGeneratedGeometryState(track, {
		projections: {
			minimap_preview: preview,
		},
	});
	const assets = buildGeneratedMinimapAssets(track);
	assert.strictEqual(assets.tiles.length, 1);
	assert.strictEqual(assets.words[0], 1);
});

test('buildGeneratedMinimapPreview can rasterize directly from geometry resampled_centerline', () => {
	const track = { slug: 'san_marino', name: 'San Marino', index: 0, track_length: 256, minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]] };
	setGeneratedGeometryState(track, {
		resampled_centerline: [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]],
	});
	const preview = buildGeneratedMinimapPreview(track);
	assert.strictEqual(preview.transform, 'geometry_identity');
	assert.ok(preview.centerline_points.length > 0);
	assert.ok(preview.road_pixels.some(Boolean));
	const assets = buildGeneratedMinimapAssets(track);
	assert.ok(assets.words.some(word => word !== 0));
});

test('buildGeneratedMinimapPreview marks underpass branch distinctly for crossing geometry', () => {
	const track = { slug: 'san_marino', name: 'San Marino', index: 0, track_length: 256, minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]] };
	setGeneratedGeometryState(track, {
		resampled_centerline: [[10, 10], [30, 10], [40, 24], [30, 38], [10, 38], [0, 24]],
		projections: {
			slope: {
				grade_separated_crossing: {
					classification: 'grade_separated_crossing',
					lower_branch: { start_index: 1, end_index: 3 },
				},
			},
		},
	});
	const preview = buildGeneratedMinimapPreview(track);
	assert.strictEqual(preview.crossing_classification, 'grade_separated_crossing');
	assert.ok(preview.pixels.some(value => value === 1));
	const assets = buildGeneratedMinimapAssets(track);
	assert.ok(assets.words.some(word => word !== 0));
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
