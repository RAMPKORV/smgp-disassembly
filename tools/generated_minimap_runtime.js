'use strict';

const fs = require('fs');

const TRACK_DATA_ADDR = 0x0000F872;
const TRACK_ENTRY_SIZE = 0x48;
const MINIMAP_TILES_PTR_OFFSET = 0x00;
const MINIMAP_MAP_PTR_OFFSET = 0x0C;

function writeLongBE(buffer, offset, value) {
	buffer.writeUInt32BE(value >>> 0, offset);
}

function parseLstSymbolMapFromText(text) {
	const map = new Map();
	for (const line of text.split(/\r?\n/)) {
		const match = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (match) map.set(match[2], parseInt(match[1], 16));
	}
	return map;
}

function parseLstSymbolMap(lstPath) {
	return parseLstSymbolMapFromText(fs.readFileSync(lstPath, 'utf8'));
}

function readTrackEntryAddresses(rom, trackIndex) {
	const entryAddr = TRACK_DATA_ADDR + (trackIndex * TRACK_ENTRY_SIZE);
	return {
		entryAddr,
		minimapTilesAddr: rom.readUInt32BE(entryAddr + MINIMAP_TILES_PTR_OFFSET),
		minimapMapAddr: rom.readUInt32BE(entryAddr + MINIMAP_MAP_PTR_OFFSET),
	};
}

function patchTrackMinimapPointers(rom, trackIndex, tilesAddr, mapAddr) {
	const entryAddr = TRACK_DATA_ADDR + (trackIndex * TRACK_ENTRY_SIZE);
	writeLongBE(rom, entryAddr + MINIMAP_TILES_PTR_OFFSET, tilesAddr);
	writeLongBE(rom, entryAddr + MINIMAP_MAP_PTR_OFFSET, mapAddr);
	return entryAddr;
}

function patchTrackMinimapTilesPointer(rom, trackIndex, tilesAddr) {
	const entryAddr = TRACK_DATA_ADDR + (trackIndex * TRACK_ENTRY_SIZE);
	writeLongBE(rom, entryAddr + MINIMAP_TILES_PTR_OFFSET, tilesAddr);
	return entryAddr;
}

module.exports = {
	TRACK_DATA_ADDR,
	TRACK_ENTRY_SIZE,
	MINIMAP_TILES_PTR_OFFSET,
	MINIMAP_MAP_PTR_OFFSET,
	parseLstSymbolMapFromText,
	parseLstSymbolMap,
	readTrackEntryAddresses,
	patchTrackMinimapPointers,
	patchTrackMinimapTilesPointer,
	writeLongBE,
};
