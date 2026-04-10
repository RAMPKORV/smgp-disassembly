'use strict';

const { buildGeneratedMinimapPreview } = require('./minimap_render');
const { resolvePreviewSlug } = require('./minimap_analysis');
const { getMinimapPreview } = require('./minimap_preview');
const { encodeTinyGraphics } = require('../minimap_graphics_codec');
const { encodeLiteralTilemap } = require('../minimap_map_codec');

const generatedAssetsCache = new WeakMap();

function buildAssetsCacheKey(track) {
	return JSON.stringify([
		track?.track_length || 0,
		track?.curve_rle_segments || [],
	]);
}

function sanitizeLabelFragment(value) {
	return String(value || '')
		.replace(/[^A-Za-z0-9]+/g, '_')
		.replace(/^_+|_+$/g, '')
		.replace(/_+/g, '_') || 'Track';
}

function formatHexByte(value) {
	return `$${(value & 0xFF).toString(16).toUpperCase().padStart(2, '0')}`;
}

function formatDcB(bytes) {
	const lines = [];
	for (let i = 0; i < bytes.length; i += 32) {
		const chunk = bytes.slice(i, i + 32);
		lines.push(`\tdc.b\t${Array.from(chunk).map(formatHexByte).join(', ')}`);
	}
	return lines;
}

function buildPreservedExternalCellIndexSet(previewSlug, stockWords, stockLocalTileCount) {
	return new Set();
}

function isBlankTileRows(rows) {
	return rows.every(row => row.every(value => value === 0));
}

function buildTilesAndWordsFromPreview(preview, stockPreview = null, previewSlug = '') {
	const tiles = [];
	const words = [];
	const tileIndexBySignature = new Map();
	const stockWords = Array.isArray(stockPreview?.words) ? stockPreview.words : null;
	const stockTiles = Array.isArray(stockPreview?.tiles) ? stockPreview.tiles : null;
	const stockLocalTileCount = Array.isArray(stockTiles) ? stockTiles.length : 0;
	const preservedExternalCellIndices = buildPreservedExternalCellIndexSet(previewSlug, stockWords, stockLocalTileCount);

	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			const cellIndex = (tileY * 7) + tileX;
			const stockWord = stockWords && cellIndex < stockWords.length ? (stockWords[cellIndex] & 0xFFFF) : null;

			const rows = [];
			for (let y = 0; y < 8; y++) {
				const row = [];
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
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

			const signature = rows.map(row => row.join(',')).join('/');
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
			const generatedWord = tiles.length & 0x07FF;
			words.push(generatedWord);
			tileIndexBySignature.set(signature, generatedWord);
		}
	}

	return { tiles, words };
}

function buildGeneratedMinimapAssets(track) {
	const cacheKey = buildAssetsCacheKey(track);
	const cached = generatedAssetsCache.get(track);
	if (cached && cached.key === cacheKey) return cached.value;
	const preview = buildGeneratedMinimapPreview(track);
	const previewSlug = resolvePreviewSlug(track);
	const stockPreview = getMinimapPreview(previewSlug);
	const generated = buildTilesAndWordsFromPreview(preview, stockPreview, previewSlug);
	let tiles = generated.tiles.slice();
	const words = generated.words.slice();
	if (tiles.length > stockPreview.tiles.length) {
		const trimmedWords = words.map(word => {
			const rawTileIndex = word & 0x07FF;
			if (rawTileIndex > stockPreview.tiles.length) return 0;
			return word;
		});
		while (tiles.length > stockPreview.tiles.length) tiles.pop();
		for (let i = 0; i < words.length; i++) words[i] = trimmedWords[i];
	}
	while (tiles.length < stockPreview.tiles.length) {
		tiles.push(stockPreview.tiles[tiles.length]);
	}
	const maxWord = words.reduce((max, word) => Math.max(max, word & 0xFFFF), 0);
	const bitWidth = Math.max(1, Math.ceil(Math.log2(Math.max(2, maxWord + 1))));
	const result = {
		preview,
		tiles,
		words,
		tile_bytes: Buffer.from(encodeTinyGraphics(tiles)),
		map_bytes: Buffer.from(encodeLiteralTilemap(words, bitWidth)),
	};
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
	buildGeneratedMinimapAssets,
	buildGeneratedMinimapLabelStem,
	buildGeneratedMinimapLabelMap,
	buildGeneratedMinimapAssetsAsm,
};
