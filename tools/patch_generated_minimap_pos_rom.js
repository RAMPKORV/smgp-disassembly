#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const { assertSafeRomPath } = require('./lib/workspace_guard');
const {
	loadTracksData,
	findTrack,
} = require('./lib/minimap_analysis');
const { buildGeneratedMinimapPosPairs } = require('./lib/generated_minimap_pos');
const { encodeMinimapPos } = require('./inject_track_data');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { TRACK_DATA_ADDR, TRACK_ENTRY_SIZE } = require('./generated_minimap_runtime');
const { getTracks } = require('./randomizer/track_model');

const SIGN_DATA_PTR_OFFSET = 0x24;
const SIGN_TILESET_PTR_OFFSET = 0x28;
const MINIMAP_PTR_OFFSET = 0x2C;
const CURVE_PTR_OFFSET = 0x30;
const SLOPE_PTR_OFFSET = 0x34;
const PHYS_SLOPE_PTR_OFFSET = 0x38;

function readTrackBlobPointers(rom, trackEntryAddr) {
	return [
		rom.readUInt32BE(trackEntryAddr + SIGN_DATA_PTR_OFFSET),
		rom.readUInt32BE(trackEntryAddr + SIGN_TILESET_PTR_OFFSET),
		rom.readUInt32BE(trackEntryAddr + MINIMAP_PTR_OFFSET),
		rom.readUInt32BE(trackEntryAddr + CURVE_PTR_OFFSET),
		rom.readUInt32BE(trackEntryAddr + SLOPE_PTR_OFFSET),
		rom.readUInt32BE(trackEntryAddr + PHYS_SLOPE_PTR_OFFSET),
	];
}

function readTrackMinimapPosPointer(rom, trackIndex) {
	const entryAddr = TRACK_DATA_ADDR + (trackIndex * TRACK_ENTRY_SIZE);
	return {
		entryAddr,
		minimapPosAddr: rom.readUInt32BE(entryAddr + MINIMAP_PTR_OFFSET),
	};
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--all', '--allow-root-mutation'],
		options: ['--rom', '--track', '--input'],
	});

	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	try {
		assertSafeRomPath(romPath, { allowRootMutation: args.flags['--allow-root-mutation'] });
	} catch (err) {
		die(err.message);
	}
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

	const tracksData = loadTracksData(args.options['--input'] || undefined);
	const trackArg = args.options['--track'] || 'san_marino';
	const selectedTracks = args.flags['--all']
		? getTracks(tracksData)
		: [findTrack(trackArg, tracksData)];
	if (selectedTracks.some(track => !track)) die(`track not found: ${trackArg}`);

	const rom = fs.readFileSync(romPath);
	const summaries = [];
	const patchedMinimapPtrs = new Map();

	for (const track of selectedTracks) {
		const remappedPairs = buildGeneratedMinimapPosPairs(track);
		const trailing = Array.isArray(track.minimap_pos_trailing) ? track.minimap_pos_trailing : [];
		const encoded = encodeMinimapPos(remappedPairs, trailing);
		const trackInfo = readTrackMinimapPosPointer(rom, track.index);
		const minimapPtr = trackInfo.minimapPosAddr;
		const existing = patchedMinimapPtrs.get(minimapPtr);
		if (existing) {
			if (!existing.encoded.equals(encoded)) {
				die(`shared minimap_pos pointer conflict at $${minimapPtr.toString(16)} between ${existing.track.slug} and ${track.slug}`);
			}
			summaries.push({
				track,
				entryAddr: trackInfo.entryAddr,
				minimapPtr,
				nextPtr: existing.nextPtr,
				bytesWritten: 0,
				firstPair: remappedPairs[0],
				sharedWith: existing.track.slug,
			});
			continue;
		}
		const pointers = readTrackBlobPointers(rom, trackInfo.entryAddr);
		const nextPtr = pointers.filter(pointer => pointer > minimapPtr).sort((a, b) => a - b)[0] || rom.length;
		const available = nextPtr - minimapPtr;
		if (available <= 0) die(`invalid minimap_pos span for ${track.slug}: $${minimapPtr.toString(16)}..$${nextPtr.toString(16)}`);
		if (encoded.length > available) {
			die(`generated minimap_pos does not fit for ${track.slug}: ${encoded.length} > ${available}`);
		}

		encoded.copy(rom, minimapPtr);
		patchedMinimapPtrs.set(minimapPtr, { track, encoded, nextPtr });
		summaries.push({
			track,
			entryAddr: trackInfo.entryAddr,
			minimapPtr,
			nextPtr,
			bytesWritten: encoded.length,
			firstPair: remappedPairs[0],
		});
	}

	fs.writeFileSync(romPath, rom);
	const checksum = patchRomChecksum(romPath);

	info(`Patched generated minimap_pos into ${path.relative(process.cwd(), romPath)}`);
	for (const summary of summaries) {
		info(`Track: ${summary.track.name}`);
		info(`Track entry: $${summary.entryAddr.toString(16).toUpperCase()}`);
		info(`minimap_pos addr: $${summary.minimapPtr.toString(16).toUpperCase()}`);
		info(`next blob addr: $${summary.nextPtr.toString(16).toUpperCase()}`);
		info(`Bytes written: ${summary.bytesWritten}`);
		if (summary.sharedWith) info(`Shared with: ${summary.sharedWith}`);
		info(`First pair: (${summary.firstPair[0]}, ${summary.firstPair[1]})`);
	}
	info(`ROM checksum ${checksum.changed ? 'updated' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
}

main();
