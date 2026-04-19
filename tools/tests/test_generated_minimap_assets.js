#!/usr/bin/env node
'use strict';

const assert = require('assert');
const { loadTracksJson } = require('./randomizer_test_utils');
const {
	createBlankTile,
	bottomAttachedStubWithOrphansPreview,
	createPreview,
	createStockPreview,
	degeneratePreview,
	isolatedOutlineSpurPreview,
	mixedCellOutlineSpurPreview,
	narrowSeamBridgePreview,
	monacoOutlineBridgePreview,
	rightSideThicknessRectangleLoop,
	rightSideThicknessBendLoop,
	sparsePreview,
	stampTile,
} = require('./minimap_synthetic_fixtures');

const {
	buildGeneratedMinimapAssetsFromPreviews,
	buildTilesAndWordsFromPreview,
	resolvePreservedExternalCellIndexSet,
	buildGeneratedMinimapAssets,
	COURSE_SELECT_PREVIEW_TILE_BUDGET,
	buildAssetPreview,
	emitLegalContourPreview,
	applyStockOccupancyMask,
} = require('../lib/generated_minimap_assets');
const {
	buildPreviewRawMap,
	buildHudRawMap,
} = require('../patch_all_track_minimap_raw_maps_rom');
const { getMinimapPreview, renderMinimapPixels } = require('../lib/minimap_preview');
const { buildGeneratedMinimapPreview } = require('../lib/minimap_render');
const { chooseStartIndex, styleRoadPreview } = require('../lib/minimap_raster');
const { resolvePreviewSlug } = require('../lib/minimap_analysis');
const {
	decodePackedTilemapWords,
	getCourseSelectReservedLocalTileIndices,
	getTrackPreviewTilemapEntryBytes,
} = require('../lib/course_select_preview_tiles');
const { getTracks } = require('../randomizer/track_model');
const { setGeneratedGeometryState, setRuntimeSafeRandomized } = require('../randomizer/track_metadata');

const PREVIEW_WIDTH = 56;
const PREVIEW_HEIGHT = 88;
const PREVIEW_TILE_COLUMNS = 7;
const PREVIEW_TILE_ROWS = 11;
const PREVIEW_TILE_COUNT = PREVIEW_TILE_COLUMNS * PREVIEW_TILE_ROWS;

let passed = 0;
let failed = 0;
const RUN_SLOW = process.argv.includes('--slow') || process.env.SMGP_SLOW_TESTS === '1';
let skippedSlowTests = 0;
const trackAssetPreviewCache = new WeakMap();
const trackRenderedAssetsCache = new WeakMap();
const previewAnalysisCache = new WeakMap();
const renderedAnalysisCache = new WeakMap();
const stockTracks = getTracks(loadTracksJson());

function getTrackAssetPreview(track) {
	if (trackAssetPreviewCache.has(track)) return trackAssetPreviewCache.get(track);
	const preview = buildGeneratedMinimapAssets(track).preview;
	trackAssetPreviewCache.set(track, preview);
	return preview;
}

function getStockTrackList() {
	return stockTracks;
}

function makeSyntheticTrackUsingStockPreview() {
	const baseTrack = getStockTrackList()[0];
	if (!baseTrack) throw new Error('expected at least one stock track');
	return {
		slug: baseTrack.slug,
		name: 'Synthetic Track',
		index: baseTrack.index,
		track_length: 256,
		minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]],
		curve_rle_segments: [],
	};
}

function slowTest(name, fn) {
	if (!RUN_SLOW) {
		skippedSlowTests++;
		return;
	}
	test(name, fn);
}

function getRenderedGeneratedAssets(track) {
	if (trackRenderedAssetsCache.has(track)) return trackRenderedAssetsCache.get(track);
	const assets = buildGeneratedMinimapAssets(track);
	const rendered = Array.from(renderMinimapPixels(assets.tiles, assets.words, PREVIEW_TILE_COLUMNS, PREVIEW_TILE_ROWS));
	trackRenderedAssetsCache.set(track, rendered);
	return rendered;
}

function getPreviewAnalysis(track) {
	if (previewAnalysisCache.has(track)) return previewAnalysisCache.get(track);
	const preview = getTrackAssetPreview(track);
	const analysis = {
		preview,
		orphans: orphanBlackComponentCount(preview.pixels, preview.road_pixels, preview.start_marker_pixels, preview.width, preview.height),
		fragments: countRoadlessSingleHandoffFragments(preview.pixels, preview.road_pixels, preview.start_marker_pixels, preview.width, preview.height),
	};
	previewAnalysisCache.set(track, analysis);
	return analysis;
}

function getRenderedAnalysis(track) {
	if (renderedAnalysisCache.has(track)) return renderedAnalysisCache.get(track);
	const preview = getTrackAssetPreview(track);
	const rendered = getRenderedGeneratedAssets(track);
	const mask = rendered.map((value, index) => (value === 1 && !(preview.start_marker_pixels && preview.start_marker_pixels[index])) ? 1 : 0);
	const analysis = {
		preview,
		rendered,
		orphans: orphanBlackComponentCount(rendered, preview.road_pixels, preview.start_marker_pixels, preview.width, preview.height),
		fragments: countRoadlessSingleHandoffFragments(rendered, preview.road_pixels, preview.start_marker_pixels, preview.width, preview.height),
		blackComponents: connectedComponents(mask, preview.width, preview.height),
	};
	renderedAnalysisCache.set(track, analysis);
	return analysis;
}

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
	assert.strictEqual(result.words[1], 0x0801);
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
	assert.strictEqual(result.words[1], 0x1001);
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
	assert.strictEqual(previewRaw.readUInt16BE(2), 0x0801);
	assert.strictEqual(hudRaw.readUInt16BE(0), 0x8001);
	assert.strictEqual(hudRaw.readUInt16BE(2), 0x8801);
});

test('buildGeneratedMinimapAssetsFromPreviews preserves tiles beyond stock capacity', () => {
	const preview = createPreview();
	const tileA = createBlankTile(1);
	const tileB = createBlankTile(2);
	stampTile(preview, 0, 0, tileA);
	stampTile(preview, 1, 0, tileB);
	const result = buildGeneratedMinimapAssetsFromPreviews(preview, createStockPreview(1, PREVIEW_TILE_COUNT));
	assert.ok(result.tiles.length >= 1);
	assert.strictEqual(result.words[0], 1);
	assert.ok(result.words[1] !== 0);
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
	const set = resolvePreservedExternalCellIndexSet('example_preview', { example_preview: [0, 5, 9] });
	assert.deepStrictEqual(Array.from(set).sort((a, b) => a - b), [0, 5, 9]);
});

test('buildTilesAndWordsFromPreview preserves configured external stock cell when tile is blank', () => {
	const preview = createPreview();
	const stockPreview = createStockPreview(2, PREVIEW_TILE_COUNT);
	stockPreview.words[0] = 0x8003;
	const result = buildTilesAndWordsFromPreview(preview, stockPreview, 'example_preview', {
		preservedExternalCellIndexConfig: { example_preview: [0] },
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

test('course-select reserved local tiles stay within the stock preview tile range', () => {
	for (const track of getStockTrackList()) {
		const previewSlug = resolvePreviewSlug(track);
		const stockPreview = getMinimapPreview(previewSlug);
		const reserved = getCourseSelectReservedLocalTileIndices(track.index, stockPreview.tile_count);
		assert.ok(
			Array.from(reserved).every(index => index < stockPreview.tiles.length),
			`${track.slug} reserved tile index fell outside stock preview tile range`,
		);
	}
});

test('course-select packed tilemap decoder follows assembly control-byte semantics', () => {
	const bytes = Uint8Array.from([
		0x00,
		0xFA,
		0xFB, 0x20, 0x40,
		0x02,
		0xFC,
		0xFD,
		0xFE,
		0x01,
		0xFF,
	]);
	assert.deepStrictEqual(decodePackedTilemapWords(bytes), [0x2032, 0x2032, 0x2042, 0x2041]);
});

test('course-select reserved local tiles are derived from decoded packed overlay refs', () => {
	for (const track of getStockTrackList()) {
		const stockPreview = getMinimapPreview(resolvePreviewSlug(track));
		const entryBytes = getTrackPreviewTilemapEntryBytes(track.index);
		const expected = new Set(
			decodePackedTilemapWords(entryBytes)
				.map(word => (word & 0x07FF) - 65)
				.filter(index => index >= 0 && index < stockPreview.tile_count),
		);
		assert.deepStrictEqual(
			Array.from(getCourseSelectReservedLocalTileIndices(track.index, stockPreview.tile_count)).sort((a, b) => a - b),
			Array.from(expected).sort((a, b) => a - b),
			`${track.slug} reserved local tile set diverged from decoded packed overlay refs`,
		);
	}
});

test('generated minimap assets keep reserved course-select tile graphics identical to stock', () => {
	for (const track of getStockTrackList()) {
		const previewSlug = resolvePreviewSlug(track);
		const stockPreview = getMinimapPreview(previewSlug);
		const reserved = Array.from(getCourseSelectReservedLocalTileIndices(track.index, stockPreview.tiles.length)).sort((a, b) => a - b);
		if (reserved.length === 0) continue;
		const assets = buildGeneratedMinimapAssets(track);
		for (const localIndex of reserved) {
			assert.deepStrictEqual(
				assets.tiles[localIndex],
				stockPreview.tiles[localIndex],
				`${track.slug} reserved local tile ${localIndex} diverged from stock overlay graphics`,
			);
		}
		const rendered = getRenderedGeneratedAssets(track);
		assert.deepStrictEqual(rendered, getTrackAssetPreview(track).pixels, `${track.slug} rendered assets changed after reserving stock overlay tiles`);
	}
});

test('generated minimap assets stay within the course-select live tile budget', () => {
	for (const track of getStockTrackList()) {
		const randomizedTrack = JSON.parse(JSON.stringify(track));
		setRuntimeSafeRandomized(randomizedTrack, true);
		const assets = buildGeneratedMinimapAssets(randomizedTrack);
		assert.ok(
			assets.tiles.length <= COURSE_SELECT_PREVIEW_TILE_BUDGET,
			`${track.slug} generated ${assets.tiles.length} minimap tiles, above course-select budget ${COURSE_SELECT_PREVIEW_TILE_BUDGET}`,
		);
	}
});

test('stock tile count bounds only remove out-of-range overlay refs', () => {
	let sawOutOfRangeRef = false;
	for (const track of getStockTrackList()) {
		const stockPreview = getMinimapPreview(resolvePreviewSlug(track));
		const limited = getCourseSelectReservedLocalTileIndices(track.index, stockPreview.tile_count);
		const unbounded = getCourseSelectReservedLocalTileIndices(track.index);
		const outOfRange = Array.from(unbounded).filter(index => index >= stockPreview.tile_count);
		if (outOfRange.length === 0) continue;
		sawOutOfRangeRef = true;
		for (const localIndex of outOfRange) {
			assert.ok(!limited.has(localIndex), `${track.slug} stock-limited reserved set should omit out-of-range overlay tile ${localIndex}`);
			assert.ok(unbounded.has(localIndex), `${track.slug} unbounded reserved set should retain overlay tile ${localIndex}`);
		}
	}
	assert.ok(sawOutOfRangeRef, 'expected at least one stock track to reference an overlay tile beyond the stock minimap tile count');
});

slowTest('generated minimap assets render back to the generated preview for stock tracks', () => {
	for (const track of getStockTrackList()) {
		const preview = getTrackAssetPreview(track);
		const rendered = getRenderedGeneratedAssets(track);
		assert.deepStrictEqual(rendered, preview.pixels, `${track.slug} generated assets do not match asset preview pixels`);
	}
});

slowTest('buildAssetPreview reduces outline-only minimap cells without per-track special casing', () => {
	for (const track of getStockTrackList()) {
		const rawPreview = buildGeneratedMinimapPreview(track);
		const preview = buildAssetPreview(track, rawPreview);
		const countOutlineOnlyCells = candidate => {
			let count = 0;
			for (let tileY = 0; tileY < PREVIEW_TILE_ROWS; tileY++) {
				for (let tileX = 0; tileX < PREVIEW_TILE_COLUMNS; tileX++) {
					let pixelCount = 0;
					let roadCount = 0;
					for (let y = 0; y < 8; y++) {
						for (let x = 0; x < 8; x++) {
							const index = ((tileY * 8 + y) * candidate.width) + (tileX * 8 + x);
							if (candidate.pixels[index]) pixelCount += 1;
							if (candidate.road_pixels[index]) roadCount += 1;
						}
					}
					if (pixelCount > 0 && roadCount === 0) count += 1;
				}
			}
			return count;
		};
		assert.ok(countOutlineOnlyCells(preview) <= countOutlineOnlyCells(rawPreview), `${track.slug} asset preview should not increase outline-only cells`);
		assert.ok(preview.pixels.length === rawPreview.pixels.length, `${track.slug} preview dimensions changed unexpectedly`);
	}
});

function tileHasLayerPixels(preview, layerName, tileX, tileY) {
	for (let y = 0; y < 8; y++) {
		for (let x = 0; x < 8; x++) {
			const px = (tileX * 8) + x;
			const py = (tileY * 8) + y;
			if (preview[layerName][(py * preview.width) + px]) return true;
		}
	}
	return false;
}

test('buildAssetPreview keeps Monaco-style outline-only seam bridges', () => {
	const rawPreview = monacoOutlineBridgePreview();
	const rebuilt = buildAssetPreview({ slug: 'synthetic_monaco_outline_bridge' }, rawPreview);

	assert.ok(tileHasLayerPixels(rawPreview, 'pixels', 4, 2));
	assert.ok(!tileHasLayerPixels(rawPreview, 'road_pixels', 4, 2));
	assert.ok(tileHasLayerPixels(rawPreview, 'pixels', 1, 4));
	assert.ok(!tileHasLayerPixels(rawPreview, 'road_pixels', 1, 4));
	assert.ok(tileHasLayerPixels(rawPreview, 'pixels', 4, 5));
	assert.ok(!tileHasLayerPixels(rawPreview, 'road_pixels', 4, 5));

	assert.ok(tileHasLayerPixels(rebuilt, 'pixels', 4, 2), 'top-right bridge tile should survive');
	assert.ok(tileHasLayerPixels(rebuilt, 'pixels', 1, 4), 'left bridge tile should survive');
	assert.ok(tileHasLayerPixels(rebuilt, 'pixels', 4, 5), 'bottom-right bridge tile should survive');
});

test('buildAssetPreview drops isolated outline-only spur cells', () => {
	const rawPreview = isolatedOutlineSpurPreview();
	const rebuilt = buildAssetPreview({ slug: 'synthetic_isolated_outline_spur' }, rawPreview);
	assert.ok(tileHasLayerPixels(rawPreview, 'pixels', 3, 2));
	assert.ok(!tileHasLayerPixels(rawPreview, 'road_pixels', 3, 2));
	assert.ok(!tileHasLayerPixels(rebuilt, 'pixels', 3, 2), 'isolated outline spur tile should be dropped');
});

test('buildAssetPreview drops detached outline spur components inside road-bearing cells', () => {
	const rawPreview = mixedCellOutlineSpurPreview();
	const rebuilt = buildAssetPreview({ slug: 'synthetic_mixed_outline_spur' }, rawPreview);
	assert.ok(tileHasLayerPixels(rawPreview, 'pixels', 2, 2));
	assert.ok(tileHasLayerPixels(rawPreview, 'road_pixels', 2, 2));
	assert.strictEqual(rebuilt.pixels[(18 * rawPreview.width) + 20], 0, 'detached mixed-cell spur pixel should be removed');
	assert.strictEqual(rebuilt.pixels[(19 * rawPreview.width) + 20], 0, 'detached mixed-cell spur pixel should be removed');
	assert.strictEqual(rebuilt.pixels[(20 * rawPreview.width) + 20], 0, 'detached mixed-cell spur pixel should be removed');
	assert.strictEqual(rebuilt.road_pixels[(19 * rawPreview.width) + 18], 1, 'road-bearing pixels must remain');
});

test('buildAssetPreview preserves narrow seam outline continuation', () => {
	const rawPreview = narrowSeamBridgePreview();
	const rebuilt = buildAssetPreview({ slug: 'synthetic_narrow_seam_bridge' }, rawPreview);
	assert.strictEqual(rebuilt.pixels[(19 * rawPreview.width) + 22], 1, 'narrow seam bridge left pixel should survive');
	assert.strictEqual(rebuilt.pixels[(19 * rawPreview.width) + 23], 1, 'narrow seam bridge center pixel should survive');
	assert.strictEqual(rebuilt.pixels[(20 * rawPreview.width) + 24], 1, 'narrow seam bridge vertical continuation should survive');
});

test('emitLegalContourPreview preserves legal seam bridges while removing isolated spurs before fallback cleanup', () => {
	const seamSource = monacoOutlineBridgePreview();
	const seamEmitted = emitLegalContourPreview(seamSource);
	assert.ok(tileHasLayerPixels(seamEmitted, 'pixels', 4, 2), 'legal top-right bridge tile should survive direct emission');
	assert.ok(tileHasLayerPixels(seamEmitted, 'pixels', 1, 4), 'legal left bridge tile should survive direct emission');
	assert.ok(tileHasLayerPixels(seamEmitted, 'pixels', 4, 5), 'legal bottom-right bridge tile should survive direct emission');

	const spurSource = isolatedOutlineSpurPreview();
	const spurEmitted = emitLegalContourPreview(spurSource);
	assert.ok(!tileHasLayerPixels(spurEmitted, 'pixels', 3, 2), 'isolated outline spur should be dropped during direct emission');
});

test('emitLegalContourPreview removes roadless single-handoff bottom stubs without increasing contour components', () => {
	const source = bottomAttachedStubWithOrphansPreview();
	const emitted = emitLegalContourPreview(source);
	assert.strictEqual(
		countRoadlessSingleHandoffFragments(emitted.pixels, emitted.road_pixels, emitted.start_marker_pixels, emitted.width, emitted.height),
		0,
		'direct contour emission should remove illegal roadless stub/orphan fragments',
	);
	const sourceComponents = connectedComponents(blackMask(source.pixels, source.start_marker_pixels, source.width, source.height), source.width, source.height).length;
	const emittedComponents = connectedComponents(blackMask(emitted.pixels, emitted.start_marker_pixels, emitted.width, emitted.height), emitted.width, emitted.height).length;
	assert.ok(emittedComponents <= sourceComponents, 'direct contour emission should not create extra black contour components');
});

test('emitLegalContourPreview removes mixed-cell spurs while preserving narrow seam continuations', () => {
	const mixedSource = mixedCellOutlineSpurPreview();
	const mixedEmitted = emitLegalContourPreview(mixedSource);
	assert.strictEqual(mixedEmitted.pixels[(18 * mixedSource.width) + 20], 0, 'direct contour emission should remove detached mixed-cell spur pixels');
	assert.strictEqual(mixedEmitted.pixels[(19 * mixedSource.width) + 20], 0, 'direct contour emission should remove detached mixed-cell spur pixels');
	assert.strictEqual(mixedEmitted.pixels[(20 * mixedSource.width) + 20], 0, 'direct contour emission should remove detached mixed-cell spur pixels');
	assert.strictEqual(mixedEmitted.road_pixels[(19 * mixedSource.width) + 18], 1, 'direct contour emission must preserve road-bearing pixels');

	const seamSource = narrowSeamBridgePreview();
	const seamEmitted = emitLegalContourPreview(seamSource);
	assert.strictEqual(seamEmitted.pixels[(19 * seamSource.width) + 22], 1, 'direct contour emission should preserve narrow seam left pixel');
	assert.strictEqual(seamEmitted.pixels[(19 * seamSource.width) + 23], 1, 'direct contour emission should preserve narrow seam center pixel');
	assert.strictEqual(seamEmitted.pixels[(20 * seamSource.width) + 24], 1, 'direct contour emission should preserve narrow seam continuation');
});

slowTest('emitLegalContourPreview leaves no orphan or roadless single-handoff fragments on stock tracks', () => {
	for (const track of getStockTrackList()) {
		const emitted = emitLegalContourPreview(getTrackAssetPreview(track));
		assert.strictEqual(
			orphanBlackComponentCount(emitted.pixels, emitted.road_pixels, emitted.start_marker_pixels, emitted.width, emitted.height),
			0,
			`${track.slug} direct contour emission still contains orphan black components`,
		);
		assert.strictEqual(
			countRoadlessSingleHandoffFragments(emitted.pixels, emitted.road_pixels, emitted.start_marker_pixels, emitted.width, emitted.height),
			0,
			`${track.slug} direct contour emission still contains roadless stub/orphan fragments`,
		);
	}
});

test('styleRoadPreview keeps straight right walls to a single extra outline column', () => {
	const preview = styleRoadPreview(rightSideThicknessRectangleLoop(), PREVIEW_WIDTH, PREVIEW_HEIGHT, null);
	assert.strictEqual(preview.pixels[(22 * PREVIEW_WIDTH) + 34], 1, 'straight right wall should keep the first right-side black pixel');
	assert.strictEqual(preview.pixels[(22 * PREVIEW_WIDTH) + 35], 0, 'straight right wall should stop after a single extra right-side outline column');
	assert.strictEqual(preview.pixels[(22 * PREVIEW_WIDTH) + 36], 0, 'straight right wall should not extend beyond the thinner right-side outline');
});

test('styleRoadPreview does not over-thicken inner bend rows while preserving the outer right wall', () => {
	const preview = styleRoadPreview(rightSideThicknessBendLoop(), PREVIEW_WIDTH, PREVIEW_HEIGHT, null);
	assert.strictEqual(preview.pixels[(22 * PREVIEW_WIDTH) + 32], 1, 'outer right wall should remain present before the bend');
	assert.strictEqual(preview.pixels[(22 * PREVIEW_WIDTH) + 33], 0, 'outer right wall should no longer retain the extra second black column before the bend');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 26], 1, 'inner bend row should keep the local turn outline');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 27], 1, 'inner bend row should keep adjacent turn support');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 28], 1, 'bend join may touch the horizontal contour run');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 29], 1, 'bend join may touch the horizontal contour run');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 30], 1, 'bend join may touch the horizontal contour run');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 31], 1, 'bend join may touch the horizontal contour run');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 32], 0, 'inner bend row should not inherit unrelated right-wall thickness');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 33], 0, 'inner bend row should not square off into a fat right-side shelf');
	assert.strictEqual(preview.pixels[(26 * PREVIEW_WIDTH) + 34], 0, 'inner bend row should stop before the outer wall extension zone');
});

function orphanBlackComponentCount(pixels, roadPixels, startMarkerPixels = null, width = PREVIEW_WIDTH, height = PREVIEW_HEIGHT) {
	const seen = new Uint8Array(width * height);
	let orphanCount = 0;
	for (let index = 0; index < seen.length; index++) {
		if (seen[index]) continue;
		if (pixels[index] !== 1) continue;
		if (startMarkerPixels && startMarkerPixels[index]) continue;
		const queue = [index];
		seen[index] = 1;
		let touchesRoad = false;
		while (queue.length > 0) {
			const current = queue.pop();
			const x = current % width;
			const y = Math.floor(current / width);
			for (let dy = -1; dy <= 1; dy++) {
				for (let dx = -1; dx <= 1; dx++) {
					if (dx === 0 && dy === 0) continue;
					const nx = x + dx;
					const ny = y + dy;
					if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
					const next = (ny * width) + nx;
					if (roadPixels[next]) touchesRoad = true;
					if (seen[next]) continue;
					if (pixels[next] !== 1) continue;
					if (startMarkerPixels && startMarkerPixels[next]) continue;
					seen[next] = 1;
					queue.push(next);
				}
			}
		}
		if (!touchesRoad) orphanCount += 1;
	}
	return orphanCount;
}

function connectedComponents(mask, width, height) {
	const seen = new Uint8Array(width * height);
	const components = [];
	for (let index = 0; index < seen.length; index++) {
		if (seen[index] || !mask[index]) continue;
		const queue = [index];
		seen[index] = 1;
		const cells = [];
		let minX = width;
		let minY = height;
		let maxX = -1;
		let maxY = -1;
		while (queue.length > 0) {
			const current = queue.pop();
			cells.push(current);
			const x = current % width;
			const y = Math.floor(current / width);
			if (x < minX) minX = x;
			if (y < minY) minY = y;
			if (x > maxX) maxX = x;
			if (y > maxY) maxY = y;
			for (let dy = -1; dy <= 1; dy++) {
				for (let dx = -1; dx <= 1; dx++) {
					if (dx === 0 && dy === 0) continue;
					const nx = x + dx;
					const ny = y + dy;
					if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
					const next = (ny * width) + nx;
					if (seen[next] || !mask[next]) continue;
					seen[next] = 1;
					queue.push(next);
				}
			}
		}
		components.push({ cells, minX, minY, maxX, maxY });
	}
	return components;
}

function blackMask(pixels, startMarkerPixels = null, width = PREVIEW_WIDTH, height = PREVIEW_HEIGHT) {
	const mask = new Uint8Array(width * height);
	for (let index = 0; index < mask.length; index++) {
		if (pixels[index] !== 1) continue;
		if (startMarkerPixels && startMarkerPixels[index]) continue;
		mask[index] = 1;
	}
	return mask;
}

function withMarkerPromotedToRoad(preview) {
	const markerMask = Array.isArray(preview.start_marker_pixels)
		? preview.start_marker_pixels.slice()
		: Array(preview.width * preview.height).fill(0);
	return {
		markerMask,
		preview: Object.assign({}, preview, {
			pixels: preview.pixels.map((value, index) => markerMask[index] ? 3 : value),
			road_pixels: Array.isArray(preview.road_pixels) ? preview.road_pixels.slice() : preview.pixels.slice(),
			start_marker_pixels: Array(preview.width * preview.height).fill(0),
		}),
	};
}

function removingPixelsSplitsBlackContour(pixels, removedIndices, startMarkerPixels = null, width = PREVIEW_WIDTH, height = PREVIEW_HEIGHT) {
	const before = connectedComponents(blackMask(pixels, startMarkerPixels, width, height), width, height).length;
	const nextPixels = pixels.slice();
	for (const index of removedIndices) nextPixels[index] = 0;
	const after = connectedComponents(blackMask(nextPixels, startMarkerPixels, width, height), width, height).length;
	return after > before;
}

function countRoadlessSingleHandoffFragments(pixels, roadPixels, startMarkerPixels = null, width = PREVIEW_WIDTH, height = PREVIEW_HEIGHT) {
	let invalid = 0;
	for (let tileY = 0; tileY < PREVIEW_TILE_ROWS; tileY++) {
		for (let tileX = 0; tileX < PREVIEW_TILE_COLUMNS; tileX++) {
			const cellMask = new Uint8Array(width * height);
			let hasRoadOrMarker = false;
			for (let y = tileY * 8; y < tileY * 8 + 8; y++) {
				for (let x = tileX * 8; x < tileX * 8 + 8; x++) {
					const index = (y * width) + x;
					if (roadPixels[index] || (startMarkerPixels && startMarkerPixels[index])) hasRoadOrMarker = true;
					if (pixels[index] === 1 && !(startMarkerPixels && startMarkerPixels[index])) cellMask[index] = 1;
				}
			}
			if (hasRoadOrMarker) continue;
			const components = connectedComponents(cellMask, width, height);
			for (const component of components) {
				let outsideHandoffs = 0;
				for (const index of component.cells) {
					const x = index % width;
					const y = Math.floor(index / width);
					let hasOutsideNeighbor = false;
					for (let dy = -1; dy <= 1 && !hasOutsideNeighbor; dy++) {
						for (let dx = -1; dx <= 1; dx++) {
							if (dx === 0 && dy === 0) continue;
							const nx = x + dx;
							const ny = y + dy;
							if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
							if (Math.floor(nx / 8) === tileX && Math.floor(ny / 8) === tileY) continue;
							const next = (ny * width) + nx;
							if (pixels[next] === 1 && !(startMarkerPixels && startMarkerPixels[next])) hasOutsideNeighbor = true;
						}
					}
					if (hasOutsideNeighbor) outsideHandoffs += 1;
				}
				if (outsideHandoffs > 1) continue;
				if (removingPixelsSplitsBlackContour(pixels, component.cells, startMarkerPixels, width, height)) continue;
				invalid += 1;
			}
		}
	}
	return invalid;
}

slowTest('stock tracks have no orphan black components after asset-preview cleanup', () => {
	for (const track of getStockTrackList()) {
		const analysis = getPreviewAnalysis(track);
		assert.strictEqual(
			analysis.orphans,
			0,
			`${track.slug} asset preview still contains orphan black components`,
		);
	}
});

slowTest('final rendered generated assets have no orphan black components on stock tracks', () => {
	for (const track of getStockTrackList()) {
		const analysis = getRenderedAnalysis(track);
		assert.strictEqual(
			analysis.orphans,
			0,
			`${track.slug} rendered assets still contain orphan black components`,
		);
	}
});

slowTest('rendered start marker stays a single compact on-road bar', () => {
	for (const track of getStockTrackList()) {
		const preview = getTrackAssetPreview(track);
		if (!Array.isArray(preview.start_marker_pixels) || !preview.start_marker_pixels.some(Boolean)) continue;
		const rendered = getRenderedGeneratedAssets(track);
		const markerMask = rendered.map((value, index) => (preview.start_marker_pixels[index] ? 1 : 0));
		const markerComponents = connectedComponents(markerMask, preview.width, preview.height);
		const markerPixels = markerMask.reduce((sum, value) => sum + value, 0);
		assert.strictEqual(markerComponents.length, 1, `${track.slug} expected a single marker component`);
		assert.ok(markerPixels >= 3 && markerPixels <= 4, `${track.slug} expected compact marker length, got ${markerPixels}`);
		const component = markerComponents[0];
		assert.ok((component.maxX - component.minX + 1) >= 2 && (component.maxX - component.minX + 1) <= 4, `${track.slug} marker width out of range`);
		assert.ok((component.maxY - component.minY + 1) <= 2, `${track.slug} marker height out of range`);
		for (const index of component.cells) assert.strictEqual(preview.road_pixels[index], 1, `${track.slug} marker pixel fell off-road`);
	}
});

slowTest('final rendered minimap has exactly two black contour components on stock tracks', () => {
	for (const track of getStockTrackList()) {
		const analysis = getRenderedAnalysis(track);
		assert.strictEqual(analysis.blackComponents.length, 2, `${track.slug} expected exactly outer and inner black contour components`);
	}
	});

slowTest('outline-only empty cells cannot contain tiny non-bridging stubs on stock tracks', () => {
		for (const track of getStockTrackList()) {
			const preview = getTrackAssetPreview(track);
			const rendered = getRenderedGeneratedAssets(track);
			for (let tileY = 0; tileY < PREVIEW_TILE_ROWS; tileY++) {
				for (let tileX = 0; tileX < PREVIEW_TILE_COLUMNS; tileX++) {
					let roadCount = 0;
					let markerCount = 0;
					let blackCount = 0;
					const cellBlackIndices = [];
					let touchesLeft = false;
					let touchesRight = false;
					let touchesTop = false;
					let touchesBottom = false;
					for (let y = 0; y < 8; y++) {
						for (let x = 0; x < 8; x++) {
							const px = (tileX * 8) + x;
							const py = (tileY * 8) + y;
							const index = (py * preview.width) + px;
							if (preview.road_pixels[index]) roadCount += 1;
							if (preview.start_marker_pixels && preview.start_marker_pixels[index]) markerCount += 1;
							if (rendered[index] !== 1) continue;
							blackCount += 1;
							cellBlackIndices.push(index);
							if (x === 0) touchesLeft = true;
							if (x === 7) touchesRight = true;
							if (y === 0) touchesTop = true;
							if (y === 7) touchesBottom = true;
						}
					}
				if (roadCount > 0 || markerCount > 0 || blackCount === 0) continue;
				const touchedEdges = Number(touchesLeft) + Number(touchesRight) + Number(touchesTop) + Number(touchesBottom);
				const splitsContour = removingPixelsSplitsBlackContour(rendered, cellBlackIndices, preview.start_marker_pixels, preview.width, preview.height);
				assert.ok(blackCount >= 4 || touchedEdges >= 2 || splitsContour, `${track.slug} has tiny non-bridging stub at cell (${tileX},${tileY})`);
			}
		}
		}
	});

test('buildAssetPreview removes roadless single-handoff bottom stubs and nearby orphan specks', () => {
	const rawPreview = bottomAttachedStubWithOrphansPreview();
	const rebuilt = buildAssetPreview({ slug: 'synthetic_bottom_stub_orphans' }, rawPreview);
	assert.strictEqual(
		countRoadlessSingleHandoffFragments(rawPreview.pixels, rawPreview.road_pixels, rawPreview.start_marker_pixels, rawPreview.width, rawPreview.height),
		3,
		'synthetic fixture should contain one attached stub and two detached orphans',
	);
	assert.strictEqual(
		countRoadlessSingleHandoffFragments(rebuilt.pixels, rebuilt.road_pixels, rebuilt.start_marker_pixels, rebuilt.width, rebuilt.height),
		0,
		'cleanup should remove the roadless attached stub along with the detached orphan specks',
	);
	assert.strictEqual(rebuilt.pixels[(39 * rebuilt.width) + 20], 1, 'main contour should remain');
	assert.strictEqual(rebuilt.road_pixels[(37 * rebuilt.width) + 20], 1, 'road-bearing contour should remain');
});

slowTest('final rendered minimaps contain no roadless single-handoff black fragments', () => {
	for (const track of getStockTrackList()) {
		const analysis = getRenderedAnalysis(track);
		assert.strictEqual(
			analysis.fragments,
			0,
			`${track.slug} rendered minimap still has roadless stub/orphan fragments`,
		);
	}
});

test('asset preview rebuild preserves preview road pixels while exposing start marker pixels separately', () => {
	for (const track of getStockTrackList()) {
		const preview = buildGeneratedMinimapPreview(track);
		const rebuilt = buildAssetPreview(track, preview);
		assert.ok(Array.isArray(rebuilt.start_marker_pixels), `${track.slug} missing explicit start marker pixels`);
		const markerCount = rebuilt.start_marker_pixels.reduce((sum, value) => sum + (value ? 1 : 0), 0);
		assert.ok(markerCount >= 3, `${track.slug} expected explicit start marker pixels`);
	}
});

slowTest('buildAssetPreview contour cleanup is independent from start-marker pixels on stock tracks', () => {
	for (const track of getStockTrackList()) {
		const previewWithMarker = buildGeneratedMinimapPreview(track);
		const { markerMask, preview: previewWithoutMarker } = withMarkerPromotedToRoad(previewWithMarker);
		const rebuiltWithMarker = buildAssetPreview(track, previewWithMarker);
		const rebuiltWithoutMarker = buildAssetPreview(track, previewWithoutMarker);
		for (let index = 0; index < rebuiltWithMarker.pixels.length; index++) {
			if (markerMask[index]) continue;
			assert.strictEqual(rebuiltWithMarker.pixels[index], rebuiltWithoutMarker.pixels[index], `${track.slug} contour changed outside marker pixels at ${index}`);
			assert.strictEqual(rebuiltWithMarker.road_pixels[index], rebuiltWithoutMarker.road_pixels[index], `${track.slug} road mask changed outside marker pixels at ${index}`);
		}
	}
});

slowTest('rendered generated assets stay marker-independent outside marker pixels on stock tracks', () => {
	for (const track of getStockTrackList()) {
		const previewWithMarker = buildGeneratedMinimapPreview(track);
		const { markerMask, preview: previewWithoutMarker } = withMarkerPromotedToRoad(previewWithMarker);
		const rebuiltWithMarker = buildAssetPreview(track, previewWithMarker);
		const rebuiltWithoutMarker = buildAssetPreview(track, previewWithoutMarker);
		const assetsWithMarker = buildGeneratedMinimapAssetsFromPreviews(rebuiltWithMarker, null, track.slug);
		const assetsWithoutMarker = buildGeneratedMinimapAssetsFromPreviews(rebuiltWithoutMarker, null, track.slug);
		const renderedWithMarker = Array.from(renderMinimapPixels(assetsWithMarker.tiles, assetsWithMarker.words, PREVIEW_TILE_COLUMNS, PREVIEW_TILE_ROWS));
		const renderedWithoutMarker = Array.from(renderMinimapPixels(assetsWithoutMarker.tiles, assetsWithoutMarker.words, PREVIEW_TILE_COLUMNS, PREVIEW_TILE_ROWS));
		for (let index = 0; index < renderedWithMarker.length; index++) {
			if (markerMask[index]) continue;
			assert.strictEqual(renderedWithMarker[index], renderedWithoutMarker[index], `${track.slug} rendered contour changed outside marker pixels at ${index}`);
		}
	}
});

test('applyStockOccupancyMask removes generated pixels from stock-blank cells', () => {
	const stockPreview = createPreview();
	const stockTile = createBlankTile();
	stockTile[0][0] = 1;
	stampTile(stockPreview, 0, 0, stockTile);
	stockPreview.words = new Array(PREVIEW_TILE_COUNT).fill(0);
	stockPreview.words[0] = 1;
	const generatedPreview = createPreview();
	const generatedTile = createBlankTile();
	generatedTile[0][0] = 1;
	stampTile(generatedPreview, 0, 0, generatedTile);
	stampTile(generatedPreview, 1, 0, generatedTile);
	generatedPreview.road_pixels = generatedPreview.pixels.slice();
	const masked = applyStockOccupancyMask(generatedPreview, stockPreview);
	let secondCellHasPixels = false;
	let firstCellHasPixels = false;
	for (let y = 0; y < 8; y++) {
		for (let x = 0; x < 8; x++) {
			if (masked.pixels[y * PREVIEW_WIDTH + x]) firstCellHasPixels = true;
		}
	}
	for (let y = 0; y < 8; y++) {
		for (let x = 8; x < 16; x++) {
			if (masked.pixels[y * PREVIEW_WIDTH + x]) secondCellHasPixels = true;
		}
	}
	assert.strictEqual(firstCellHasPixels, true);
	assert.strictEqual(secondCellHasPixels, true);
});

slowTest('generated preview start line stays on-road for stock tracks', () => {
	for (const track of getStockTrackList()) {
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

test('buildGeneratedMinimapAssets prefers transient preview projection when present', () => {
	const track = makeSyntheticTrackUsingStockPreview();
	const tile = createBlankTile();
	tile[0][0] = 1;
	const preview = createPreview();
	stampTile(preview, 0, 0, tile);
	preview.centerline_points = [];
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
	const track = makeSyntheticTrackUsingStockPreview();
	setGeneratedGeometryState(track, {
		resampled_centerline: [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]],
	});
	const preview = buildGeneratedMinimapPreview(track);
	assert.ok(/^geometry_/.test(preview.transform), `expected geometry-derived transform, got ${preview.transform}`);
	assert.ok(preview.centerline_points.length > 0);
	assert.ok(preview.road_pixels.some(Boolean));
	const assets = buildGeneratedMinimapAssets(track);
	assert.ok(assets.words.some(word => word !== 0));
});

slowTest('generated minimap assets preserve the asset-preview black contour exactly on stock tracks', () => {
	for (const track of getStockTrackList()) {
		const preview = getTrackAssetPreview(track);
		const rendered = getRenderedGeneratedAssets(track);
		for (let index = 0; index < rendered.length; index++) {
			assert.strictEqual(rendered[index], preview.pixels[index], `${track.slug} generated assets changed preview pixel at ${index} (${index % preview.width},${Math.floor(index / preview.width)})`);
		}
	}
});

test('buildGeneratedMinimapPreview marks underpass branch distinctly for crossing geometry', () => {
	const track = makeSyntheticTrackUsingStockPreview();
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
	assert.ok(preview.pixels.some(value => value === 0));
	const assets = buildGeneratedMinimapAssets(track);
	assert.ok(assets.words.some(word => word !== 0));
});

test('buildAssetPreview preserves preview dimensions for course-select asset preview', () => {
	const track = makeSyntheticTrackUsingStockPreview();
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
	const assetPreview = buildAssetPreview(track, preview);
	assert.ok(assetPreview.pixels.length === preview.pixels.length);
});

const total = passed + failed;
if (!RUN_SLOW && skippedSlowTests > 0) {
	console.log(`Skipped ${skippedSlowTests} slow test(s). Run with --slow for the full suite.`);
}
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
