'use strict';

const { buildGeneratedMinimapPreview } = require('./minimap_render');
const { formatDcB } = require('./asm_patch_helpers');
const { getGeneratedGeometryState } = require('../randomizer/track_metadata');
const {
	MINIMAP_PANEL_TILES_H,
	MINIMAP_PANEL_TILES_W,
	MINIMAP_TILE_INDEX_MASK,
	MINIMAP_TILE_SIZE_PX,
} = require('./minimap_layout');
const { resolvePreviewSlug } = require('./minimap_analysis');
const { getMinimapPreview } = require('./minimap_preview');
const { encodeTinyGraphics } = require('../minimap_graphics_codec');
const { encodeLiteralTilemap } = require('../minimap_map_codec');

const generatedAssetsCache = new WeakMap();
const PRESERVED_EXTERNAL_CELL_INDEX_CONFIG = Object.freeze({});

function getPreviewProjection(track) {
	return getGeneratedGeometryState(track)?.projections?.minimap_preview || null;
}

function buildAssetsCacheKey(track) {
	const previewProjection = getPreviewProjection(track);
	const geometryState = getGeneratedGeometryState(track);
	return JSON.stringify([
		track?.track_length || 0,
		track?.curve_rle_segments || [],
		previewProjection || null,
		geometryState?.projections?.slope?.grade_separated_crossing || null,
	]);
}

function sanitizeLabelFragment(value) {
	return String(value || '')
		.replace(/[^A-Za-z0-9]+/g, '_')
		.replace(/^_+|_+$/g, '')
		.replace(/_+/g, '_') || 'Track';
}

function resolvePreservedExternalCellIndexSet(previewSlug, config = PRESERVED_EXTERNAL_CELL_INDEX_CONFIG) {
	if (!previewSlug || !config || typeof config !== 'object') return new Set();
	const values = config[previewSlug];
	return Array.isArray(values) ? new Set(values) : new Set();
}

function isBlankTileRows(rows) {
	return rows.every(row => row.every(value => value === 0));
}

function buildTileSignature(rows) {
	return rows.map(row => row.join(',')).join('/');
}

function flipTileRows(rows, hFlip, vFlip) {
	const sourceRows = vFlip ? rows.slice().reverse() : rows;
	return sourceRows.map(row => hFlip ? row.slice().reverse() : row.slice());
}

function registerTileVariants(tileIndexBySignature, rows, word) {
	const variants = [
		{ rows, flags: 0 },
		{ rows: flipTileRows(rows, true, false), flags: 0x1000 },
		{ rows: flipTileRows(rows, false, true), flags: 0x0800 },
		{ rows: flipTileRows(rows, true, true), flags: 0x1800 },
	];
	for (const variant of variants) {
		const signature = buildTileSignature(variant.rows);
		if (!tileIndexBySignature.has(signature)) {
			tileIndexBySignature.set(signature, word | variant.flags);
		}
	}
}

function buildTilesAndWordsFromPreview(preview, stockPreview = null, previewSlug = '', options = {}) {
	const tiles = [];
	const words = [];
	const tileIndexBySignature = new Map();
	const stockWords = Array.isArray(stockPreview?.words) ? stockPreview.words : null;
	const stockTiles = Array.isArray(stockPreview?.tiles) ? stockPreview.tiles : null;
	const preservedExternalCellIndices = options.preservedExternalCellIndices instanceof Set
		? options.preservedExternalCellIndices
		: resolvePreservedExternalCellIndexSet(previewSlug, options.preservedExternalCellIndexConfig);

	for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
		for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
			const cellIndex = (tileY * MINIMAP_PANEL_TILES_W) + tileX;
			const stockWord = stockWords && cellIndex < stockWords.length ? (stockWords[cellIndex] & 0xFFFF) : null;

			const rows = [];
			for (let y = 0; y < MINIMAP_TILE_SIZE_PX; y++) {
				const row = [];
				for (let x = 0; x < MINIMAP_TILE_SIZE_PX; x++) {
					const px = tileX * MINIMAP_TILE_SIZE_PX + x;
					const py = tileY * MINIMAP_TILE_SIZE_PX + y;
					row.push(preview.pixels[(py * preview.width) + px] || 0);
				}
				rows.push(row);
			}

			const preserveExternalStockCell = stockWord !== null
				&& preservedExternalCellIndices.has(cellIndex)
				&& isBlankTileRows(rows);
			if (preserveExternalStockCell) {
				words.push(stockWord);
				continue;
			}

			const signature = buildTileSignature(rows);
			const isBlankTile = isBlankTileRows(rows);

			if (isBlankTile) {
				words.push(0);
				continue;
			}
			if (tileIndexBySignature.has(signature)) {
				words.push(tileIndexBySignature.get(signature));
				continue;
			}

			tiles.push(rows);
			const generatedWord = tiles.length & MINIMAP_TILE_INDEX_MASK;
			words.push(generatedWord);
			registerTileVariants(tileIndexBySignature, rows, generatedWord);
		}
	}

	return { tiles, words };
}

function buildGeneratedMinimapAssetsFromPreviews(preview, stockPreview, previewSlug = '', options = {}) {
	const generated = buildTilesAndWordsFromPreview(preview, stockPreview, previewSlug, options);
	const tiles = generated.tiles.slice();
	const words = generated.words.slice();
	const maxWord = words.reduce((max, word) => Math.max(max, word & 0xFFFF), 0);
	const bitWidth = Math.max(1, Math.ceil(Math.log2(Math.max(2, maxWord + 1))));
	return {
		preview,
		tiles,
		words,
		tile_bytes: Buffer.from(encodeTinyGraphics(tiles)),
		map_bytes: Buffer.from(encodeLiteralTilemap(words, bitWidth)),
	};
}

function buildGeneratedMinimapAssets(track) {
	const cacheKey = buildAssetsCacheKey(track);
	const cached = generatedAssetsCache.get(track);
	if (cached && cached.key === cacheKey) return cached.value;
	const preview = getPreviewProjection(track) || buildGeneratedMinimapPreview(track);
	const previewSlug = resolvePreviewSlug(track);
	const stockPreview = getMinimapPreview(previewSlug);
	const result = buildGeneratedMinimapAssetsFromPreviews(preview, stockPreview, previewSlug);
	generatedAssetsCache.set(track, { key: cacheKey, value: result });
	return result;
}

function buildGeneratedMinimapLabelStem(track) {
	const index = String(track.index).padStart(2, '0');
	const name = sanitizeLabelFragment(track.name || track.slug || `Track_${index}`);
	return `Generated_Minimap_Track_${index}_${name}`;
}

function buildGeneratedMinimapLabelMap(tracks) {
	const map = new Map();
	for (const track of tracks || []) {
		const stem = buildGeneratedMinimapLabelStem(track);
		map.set(track.index, {
			tiles: `${stem}_tiles`,
			map: `${stem}_map`,
		});
	}
	return map;
}

function buildGeneratedMinimapAssetsAsm(tracks) {
	const lines = [];
	const labelsByTrackIndex = buildGeneratedMinimapLabelMap(tracks);

	for (const track of tracks || []) {
		const labels = labelsByTrackIndex.get(track.index);
		const assets = buildGeneratedMinimapAssets(track);
		lines.push(`; ${track.name}`);
		lines.push(`${labels.tiles}:`);
		lines.push(...formatDcB(assets.tile_bytes));
		lines.push(`${labels.map}:`);
		lines.push(...formatDcB(assets.map_bytes));
	}

	return {
		content: lines.join('\n') + (lines.length ? '\n' : ''),
		labelsByTrackIndex,
	};
}

module.exports = {
	sanitizeLabelFragment,
	formatDcB,
	buildTilesAndWordsFromPreview,
	resolvePreservedExternalCellIndexSet,
	buildGeneratedMinimapAssetsFromPreviews,
	buildGeneratedMinimapAssets,
	buildGeneratedMinimapLabelStem,
	buildGeneratedMinimapLabelMap,
	buildGeneratedMinimapAssetsAsm,
};
