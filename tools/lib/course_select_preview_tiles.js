'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const GAMEPLAY_ASM = path.join(REPO_ROOT, 'src', 'gameplay.asm');

const TRACK_PREVIEW_TILEMAP_LABEL = 'Track_preview_tilemap_data';
const TRACK_PREVIEW_TILEMAP_STRIDE = 0x3B;
const TRACK_PREVIEW_WORD_BASE = 0x2032;
const MINIMAP_VRAM_TILE_BASE = 64;

let trackPreviewTilemapBytesCache = null;

function parseNumber(token) {
	const trimmed = token.trim();
	if (!trimmed) return null;
	if (trimmed.startsWith('$')) return parseInt(trimmed.slice(1), 16);
	if (/^-?\d+$/.test(trimmed)) return parseInt(trimmed, 10);
	return null;
}

function parseLabelBytes(label) {
	const text = fs.readFileSync(GAMEPLAY_ASM, 'utf8');
	const lines = text.split(/\r?\n/);
	const labelRegex = new RegExp(`^${label}:`);
	const nextLabelRegex = /^[A-Za-z_][A-Za-z0-9_]*:\s*$/;
	const bytes = [];
	let inBlock = false;

	for (const line of lines) {
		const trimmed = line.trim();
		if (!inBlock) {
			if (labelRegex.test(trimmed)) inBlock = true;
			continue;
		}
		if (nextLabelRegex.test(trimmed)) break;
		const commentFree = line.split(';')[0];
		const marker = commentFree.indexOf('dc.b');
		if (marker === -1) continue;
		for (const token of commentFree.slice(marker + 4).split(',')) {
			const value = parseNumber(token);
			if (value !== null) bytes.push(value & 0xFF);
		}
	}

	if (bytes.length === 0) throw new Error(`Could not parse bytes for label ${label}`);
	return Uint8Array.from(bytes);
}

function getTrackPreviewTilemapBytes() {
	if (trackPreviewTilemapBytesCache !== null) return trackPreviewTilemapBytesCache;
	trackPreviewTilemapBytesCache = parseLabelBytes(TRACK_PREVIEW_TILEMAP_LABEL);
	return trackPreviewTilemapBytesCache;
}

function decodePackedTilemapWords(bytes, initialBaseWord = TRACK_PREVIEW_WORD_BASE) {
	const words = [];
	let baseWord = initialBaseWord & 0xFFFF;
	for (let index = 0; index < bytes.length; index++) {
		const value = bytes[index] & 0xFF;
		if (value < 0xFA) {
			words.push((baseWord + value) & 0xFFFF);
			continue;
		}
		if (value === 0xFA) {
			baseWord = (((bytes[index + 1] || 0) << 8) | (bytes[index + 2] || 0)) & 0xFFFF;
			index += 2;
			continue;
		}
		if (value === 0xFE) break;
	}
	return words;
}

function getTrackPreviewTilemapWords(trackIndex) {
	const start = trackIndex * TRACK_PREVIEW_TILEMAP_STRIDE;
	const bytes = getTrackPreviewTilemapBytes().subarray(start, start + TRACK_PREVIEW_TILEMAP_STRIDE);
	return decodePackedTilemapWords(bytes, TRACK_PREVIEW_WORD_BASE);
}

function getCourseSelectReservedLocalTileIndices(trackIndex, stockTileCount, minimapVramTileBase = MINIMAP_VRAM_TILE_BASE) {
	const reserved = new Set();
	if (!Number.isInteger(trackIndex) || trackIndex < 0 || !Number.isInteger(stockTileCount) || stockTileCount <= 0) return reserved;
	for (const word of getTrackPreviewTilemapWords(trackIndex)) {
		const tileIndex = word & 0x07FF;
		const localIndex = tileIndex - minimapVramTileBase;
		if (localIndex >= 0 && localIndex < stockTileCount) reserved.add(localIndex);
	}
	return reserved;
}

module.exports = {
	MINIMAP_VRAM_TILE_BASE,
	TRACK_PREVIEW_TILEMAP_STRIDE,
	TRACK_PREVIEW_WORD_BASE,
	decodePackedTilemapWords,
	getTrackPreviewTilemapWords,
	getCourseSelectReservedLocalTileIndices,
};
