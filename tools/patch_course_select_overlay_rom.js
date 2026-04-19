#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const { assertSafeRomPath } = require('./lib/workspace_guard');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { loadTracksData } = require('./lib/minimap_analysis');
const { getTracks } = require('./randomizer/track_model');
const {
	TRACK_PREVIEW_TILEMAP_STRIDE,
	getTrackPreviewTilemapEntryBytes,
	patchPackedTilemapLocalRefsToBlank,
} = require('./lib/course_select_preview_tiles');

const TRACK_PREVIEW_TILEMAP_ROM_ADDR = 0x00032228;

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--allow-root-mutation'],
		options: ['--rom', '--input'],
	});

	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	try {
		assertSafeRomPath(romPath, { allowRootMutation: args.flags['--allow-root-mutation'] });
	} catch (err) {
		die(err.message);
	}
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

	const tracks = getTracks(loadTracksData(args.options['--input'] || undefined));
	if (tracks.length === 0) die('no tracks found');

	const rom = fs.readFileSync(romPath);
	for (const track of tracks) {
		if (!Number.isInteger(track.index) || track.index < 0 || track.index >= 16) continue;
		const entryBytes = getTrackPreviewTilemapEntryBytes(track.index);
		const patched = patchPackedTilemapLocalRefsToBlank(entryBytes);
		Buffer.from(patched).copy(rom, TRACK_PREVIEW_TILEMAP_ROM_ADDR + (track.index * TRACK_PREVIEW_TILEMAP_STRIDE));
	}

	fs.writeFileSync(romPath, rom);
	const checksum = patchRomChecksum(romPath);
	info(`Patched course-select overlay stream in ${path.relative(process.cwd(), romPath)}`);
	info(`Overlay table addr: $${TRACK_PREVIEW_TILEMAP_ROM_ADDR.toString(16).toUpperCase()}`);
	info(`ROM checksum ${checksum.changed ? 'updated' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
}

if (require.main === module) main();

module.exports = {
	TRACK_PREVIEW_TILEMAP_ROM_ADDR,
	main,
};
