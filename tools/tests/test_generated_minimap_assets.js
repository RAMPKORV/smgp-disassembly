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
} = require('../lib/generated_minimap_assets');
const { getMinimapPreview } = require('../lib/minimap_preview');
const { buildGeneratedMinimapPreview } = require('../lib/minimap_render');
const { resolvePreviewSlug } = require('../lib/minimap_analysis');
const { getTracks, requireTracksDataShape } = require('../randomizer/track_model');
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
	assert.ok(raw.tiles.length > stockPreview.tiles.length, `expected over-budget fixture, got ${raw.tiles.length} <= ${stockPreview.tiles.length}`);
	assert.strictEqual(finalAssets.tiles.length, raw.tiles.length);
	assert.strictEqual(Math.max(...finalAssets.words), Math.max(...raw.words));
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
