'use strict';

const { buildGeneratedMinimapPreview } = require('./minimap_render');
const { encodeTinyGraphics } = require('../minimap_graphics_codec');
const { encodeLiteralTilemap } = require('../minimap_map_codec');

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

function buildTilesAndWordsFromPreview(preview) {
	const tiles = [];
	const words = [];

	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
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

			const signature = rows.map(row => row.join(',')).join('/');
			if (/^0(?:,0){7}(?:\/0(?:,0){7}){7}$/.test(signature)) {
				words.push(0);
				continue;
			}

			tiles.push(rows);
			words.push(tiles.length);
		}
	}

	return { tiles, words };
}

function buildGeneratedMinimapAssets(track) {
	const preview = buildGeneratedMinimapPreview(track);
	const { tiles, words } = buildTilesAndWordsFromPreview(preview);
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
