#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { loadTracksData } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapAssets } = require('./lib/generated_minimap_assets');
const { patchTrackMinimapTilesPointer } = require('./generated_minimap_runtime');

const ROM_END_OFFSET = 0x01A4;

function writeAlignedBlock(rom, cursor, bytes) {
	const start = (cursor + 1) & ~1;
	bytes.copy(rom, start);
	return { start, end: start + bytes.length };
}

function buildTrackAssetBytes(track) {
	const assets = buildGeneratedMinimapAssets(track);
	return {
		tileBytes: Buffer.from(assets.tile_bytes),
	};
}

function patchRomEnd(buffer) {
	buffer.writeUInt32BE(buffer.length - 1, ROM_END_OFFSET);
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		options: ['--rom', '--input'],
	});

	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

	const tracksData = loadTracksData(args.options['--input'] || undefined);
	const baseRom = fs.readFileSync(romPath);

	const trackAssets = [];
	let totalBytes = 0;
	for (const track of tracksData.tracks || []) {
		const { tileBytes } = buildTrackAssetBytes(track);
		trackAssets.push({ track, tileBytes });
		totalBytes += ((tileBytes.length + 1) & ~1);
	}

	const rom = Buffer.alloc(baseRom.length + totalBytes);
	baseRom.copy(rom, 0);

	let cursor = baseRom.length;
	const summaries = [];
	for (const asset of trackAssets) {
		const tileBlock = writeAlignedBlock(rom, cursor, asset.tileBytes);
		cursor = tileBlock.end;
		patchTrackMinimapTilesPointer(rom, asset.track.index, tileBlock.start);
		summaries.push({
			track: asset.track,
			tilesAddr: tileBlock.start,
			tilesBytes: asset.tileBytes.length,
		});
	}

	const finalRom = cursor === rom.length ? rom : rom.subarray(0, cursor);
	patchRomEnd(finalRom);
	fs.writeFileSync(romPath, finalRom);
	const checksum = patchRomChecksum(romPath);

	info(`Patched generated minimap tiles into ${path.relative(process.cwd(), romPath)}`);
	info(`Appended asset range: $${baseRom.length.toString(16).toUpperCase()}-$${(finalRom.length - 1).toString(16).toUpperCase()}`);
	info(`ROM size: ${baseRom.length} -> ${finalRom.length} bytes`);
	for (const summary of summaries) {
		info(`Track: ${summary.track.name}`);
		info(`Tiles addr: $${summary.tilesAddr.toString(16).toUpperCase()} (${summary.tilesBytes} bytes)`);
	}
	info('Compressed minimap map pointers left unchanged; raw-map helper patch supplies generated maps at runtime.');
	info(`ROM checksum ${checksum.changed ? 'updated' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
}

if (require.main === module) main();

module.exports = {
	buildTrackAssetBytes,
	patchRomEnd,
	writeAlignedBlock,
	main,
};
