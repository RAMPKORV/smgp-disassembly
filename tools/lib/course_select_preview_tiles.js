'use strict';

const fs = require('fs');
const path = require('path');
const { MINIMAP_PANEL_CELL_COUNT } = require('./minimap_layout');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const GAMEPLAY_ASM = path.join(REPO_ROOT, 'src', 'gameplay.asm');

const TRACK_PREVIEW_TILEMAP_LABEL = 'Track_preview_tilemap_data';
const TRACK_PREVIEW_TILEMAP_STRIDE = 0x3B;
const TRACK_PREVIEW_WORD_BASE = 0x2032;
const COURSE_SELECT_PREVIEW_TILE_VRAM_BASE = 2;

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
	const nextLabelRegex = /^[A-Za-z_][A-Za-z0-9_]*:\s*(?:;.*)?$/;
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

function getTrackPreviewTilemapEntryBytes(trackIndex) {
	if (!Number.isInteger(trackIndex) || trackIndex < 0) return Uint8Array.of();
	const start = trackIndex * TRACK_PREVIEW_TILEMAP_STRIDE;
	return getTrackPreviewTilemapBytes().subarray(start, start + TRACK_PREVIEW_TILEMAP_STRIDE);
}

function decodePackedTilemapWordRefs(bytes, initialBaseWord = TRACK_PREVIEW_WORD_BASE) {
	const refs = [];
	let baseWord = initialBaseWord & 0xFFFF;
	for (let index = 0; index < bytes.length; index++) {
		const value = bytes[index] & 0xFF;
		if (value < 0xFA) {
			refs.push({ relativeOffset: index, byteValue: value, word: (baseWord + value) & 0xFFFF });
			continue;
		}
		if (value === 0xFA) {
			refs.push({ relativeOffset: index, byteValue: value, word: baseWord & 0xFFFF });
			continue;
		}
		if (value === 0xFB) {
			baseWord = (((bytes[index + 1] || 0) << 8) | (bytes[index + 2] || 0)) & 0xFFFF;
			index += 2;
			continue;
		}
		if (value === 0xFC || value === 0xFD || value === 0xFE) continue;
		if (value === 0xFF) break;
	}
	return refs;
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
			words.push(baseWord & 0xFFFF);
			continue;
		}
		if (value === 0xFB) {
			baseWord = (((bytes[index + 1] || 0) << 8) | (bytes[index + 2] || 0)) & 0xFFFF;
			index += 2;
			continue;
		}
		if (value === 0xFC || value === 0xFD || value === 0xFE) continue;
		if (value === 0xFF) break;
	}
	return words;
}

function getTrackPreviewTilemapWords(trackIndex) {
	const bytes = getTrackPreviewTilemapEntryBytes(trackIndex);
	return decodePackedTilemapWords(bytes, TRACK_PREVIEW_WORD_BASE);
}

function derivePackedTilemapLocalRefOffsets(bytes, options = {}) {
	const localRefOffsets = [];
	const minimapVramTileBase = Number.isInteger(options.minimapVramTileBase)
		? options.minimapVramTileBase
		: COURSE_SELECT_PREVIEW_TILE_VRAM_BASE;
	const localTileLimit = Number.isInteger(options.localTileCount) && options.localTileCount > 0
		? options.localTileCount
		: MINIMAP_PANEL_CELL_COUNT;
	for (const ref of decodePackedTilemapWordRefs(bytes, options.initialBaseWord || TRACK_PREVIEW_WORD_BASE)) {
		const localIndex = (ref.word & 0x07FF) - minimapVramTileBase;
		if (localIndex >= 0 && localIndex < localTileLimit) localRefOffsets.push(ref.relativeOffset);
	}
	return localRefOffsets;
}

function getTrackPreviewLocalRefOffsets(trackIndex, options = {}) {
	return derivePackedTilemapLocalRefOffsets(getTrackPreviewTilemapEntryBytes(trackIndex), options);
}

function patchPackedTilemapLocalRefsToBlank(bytes, options = {}) {
	const patched = Uint8Array.from(bytes || []);
	for (const offset of derivePackedTilemapLocalRefOffsets(patched, options)) {
		patched[offset] = 0xFA;
	}
	return patched;
}

function getCourseSelectReservedLocalTileIndices(trackIndex, stockTileCount, minimapVramTileBase = COURSE_SELECT_PREVIEW_TILE_VRAM_BASE) {
	const reserved = new Set();
	if (!Number.isInteger(trackIndex) || trackIndex < 0) return reserved;
	const localTileLimit = Number.isInteger(stockTileCount) && stockTileCount > 0
		? stockTileCount
		: MINIMAP_PANEL_CELL_COUNT;
	for (const word of getTrackPreviewTilemapWords(trackIndex)) {
		const tileIndex = word & 0x07FF;
		const localIndex = tileIndex - minimapVramTileBase;
		if (localIndex >= 0 && localIndex < localTileLimit) reserved.add(localIndex);
	}
	return reserved;
}

module.exports = {
	COURSE_SELECT_PREVIEW_TILE_VRAM_BASE,
	TRACK_PREVIEW_TILEMAP_STRIDE,
	TRACK_PREVIEW_WORD_BASE,
	decodePackedTilemapWordRefs,
	decodePackedTilemapWords,
	derivePackedTilemapLocalRefOffsets,
	getTrackPreviewTilemapWords,
	getTrackPreviewTilemapEntryBytes,
	getTrackPreviewLocalRefOffsets,
	patchPackedTilemapLocalRefsToBlank,
	getCourseSelectReservedLocalTileIndices,
};
