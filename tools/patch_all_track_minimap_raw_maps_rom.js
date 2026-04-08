#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const { parseArgs, die, info } = require('./lib/cli');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { loadTracksData } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapAssets } = require('./lib/generated_minimap_assets');
const {
	TRACK_DATA_ADDR,
	TRACK_ENTRY_SIZE,
	MINIMAP_MAP_PTR_OFFSET,
} = require('./generated_minimap_runtime');

const PREVIEW_MAP_JSR_ADDR = 0x000058FA;
const HUD_MAP_JSR_ADDR = 0x000011EC;
const FINISH_MAP_JSR_ADDR = 0x0000BD08;
const WRITE_TILEMAP_ROWS_TO_VDP_ADDR = 0x000007DC;
const DECOMPRESS_PREVIEW_MAP_ADDR = 0x000007BE;
const DECOMPRESS_HUD_MAP_ADDR = 0x000007CE;
const DECOMPRESS_TILEMAP_TO_BUFFER_ADDR = 0x00000AB0;
const TILEMAP_WORK_BUF_ADDR = 0x00FFEA00;

const MAP_WIDTH = 7;
const MAP_HEIGHT = 11;
const MAP_WORD_COUNT = MAP_WIDTH * MAP_HEIGHT;

function writeWordBE(buffer, offset, value) {
	buffer.writeUInt16BE(value & 0xFFFF, offset);
}

function writeLongBE(buffer, offset, value) {
	buffer.writeUInt32BE(value >>> 0, offset);
}

function encodeJsrAbsoluteLong(address) {
	const out = Buffer.alloc(6);
	writeWordBE(out, 0, 0x4EB9);
	writeLongBE(out, 2, address);
	return out;
}

function encodeRts() {
	const out = Buffer.alloc(2);
	writeWordBE(out, 0, 0x4E75);
	return out;
}

function alignEven(value) {
	return (value + 1) & ~1;
}

function appendBlock(chunks, cursor, bytes) {
	const start = alignEven(cursor);
	if (start > cursor) chunks.push(Buffer.alloc(start - cursor, 0x00));
	const buffer = Buffer.from(bytes);
	chunks.push(buffer);
	return {
		start,
		end: start + buffer.length,
	};
}

function buildPreviewRawMap(track) {
	const assets = buildGeneratedMinimapAssets(track);
	if (!Array.isArray(assets.words) || assets.words.length !== MAP_WORD_COUNT) {
		throw new Error(`unexpected minimap word count for ${track.slug}: ${assets.words ? assets.words.length : 'null'}`);
	}
	const out = Buffer.alloc(MAP_WORD_COUNT * 2);
	for (let i = 0; i < assets.words.length; i++) writeWordBE(out, i * 2, assets.words[i] & 0x07FF);
	return out;
}

function buildHudRawMap(track) {
	const assets = buildGeneratedMinimapAssets(track);
	if (!Array.isArray(assets.words) || assets.words.length !== MAP_WORD_COUNT) {
		throw new Error(`unexpected minimap word count for ${track.slug}: ${assets.words ? assets.words.length : 'null'}`);
	}
	const out = Buffer.alloc(MAP_WORD_COUNT * 2);
	for (let i = 0; i < assets.words.length; i++) {
		const word = assets.words[i] & 0x07FF;
		writeWordBE(out, i * 2, word === 0 ? 0 : (0x8000 | word));
	}
	return out;
}

function formatHexLong(value) {
	return `$${(value >>> 0).toString(16).toUpperCase().padStart(8, '0')}`;
}

function formatDcL(values) {
	const lines = [];
	for (let i = 0; i < values.length; i += 4) {
		lines.push(`\tdc.l\t${values.slice(i, i + 4).map(formatHexLong).join(', ')}`);
	}
	return lines;
}

function buildHelperAsm(compressedMapPtrs, previewRawMapPtrs, hudRawMapPtrs) {
	const trackCountMinusOne = compressedMapPtrs.length - 1;
	const lines = [
		`Write_tilemap_rows_to_vdp = ${formatHexLong(WRITE_TILEMAP_ROWS_TO_VDP_ADDR)}`,
		`Decompress_preview_map = ${formatHexLong(DECOMPRESS_PREVIEW_MAP_ADDR)}`,
		`Decompress_hud_map = ${formatHexLong(DECOMPRESS_HUD_MAP_ADDR)}`,
		`Decompress_tilemap_to_buffer = ${formatHexLong(DECOMPRESS_TILEMAP_TO_BUFFER_ADDR)}`,
		`Tilemap_work_buf = ${formatHexLong(TILEMAP_WORK_BUF_ADDR)}`,
		'',
		'Preview_map_helper:',
		'\tLEA\tCompressed_map_ptr_table(PC), A2',
		'\tLEA\tPreview_raw_map_ptr_table(PC), A3',
		`\tMOVEQ\t#${trackCountMinusOne}, D0`,
		'Preview_map_find:',
		'\tCMPA.l\t(A2)+, A0',
		'\tBEQ.b\tPreview_map_found',
		'\tADDQ.w\t#4, A3',
		'\tDBF\tD0, Preview_map_find',
		'\tJMP\tDecompress_preview_map',
		'Preview_map_found:',
		'\tMOVEA.l\t(A3), A6',
		'\tMOVE.l\t#$01000000, D3',
		'\tJSR\tWrite_tilemap_rows_to_vdp',
		'\tRTS',
		'',
		'Hud_map_helper:',
		'\tLEA\tCompressed_map_ptr_table(PC), A2',
		'\tLEA\tHud_raw_map_ptr_table(PC), A3',
		`\tMOVEQ\t#${trackCountMinusOne}, D0`,
		'Hud_map_find:',
		'\tCMPA.l\t(A2)+, A0',
		'\tBEQ.b\tHud_map_found',
		'\tADDQ.w\t#4, A3',
		'\tDBF\tD0, Hud_map_find',
		'\tJMP\tDecompress_hud_map',
		'Hud_map_found:',
		'\tMOVEA.l\t(A3), A6',
		'\tMOVE.l\t#$00400000, D3',
		'\tJSR\tWrite_tilemap_rows_to_vdp',
		'\tRTS',
		'',
		'Finish_map_helper:',
		'\tLEA\tCompressed_map_ptr_table(PC), A2',
		'\tLEA\tHud_raw_map_ptr_table(PC), A3',
		`\tMOVEQ\t#${trackCountMinusOne}, D0`,
		'Finish_map_find:',
		'\tCMPA.l\t(A2)+, A0',
		'\tBEQ.b\tFinish_map_found',
		'\tADDQ.w\t#4, A3',
		'\tDBF\tD0, Finish_map_find',
		'\tJMP\tDecompress_tilemap_to_buffer',
		'Finish_map_found:',
		'\tMOVEA.l\t(A3), A0',
		'\tMOVEA.l\t#Tilemap_work_buf, A1',
		`\tMOVEQ\t#${MAP_WORD_COUNT - 1}, D0`,
		'Finish_map_copy:',
		'\tMOVE.w\t(A0)+, (A1)+',
		'\tDBF\tD0, Finish_map_copy',
		'\tRTS',
		'',
		'\tEVEN',
		'Compressed_map_ptr_table:',
		...formatDcL(compressedMapPtrs),
		'Preview_raw_map_ptr_table:',
		...formatDcL(previewRawMapPtrs),
		'Hud_raw_map_ptr_table:',
		...formatDcL(hudRawMapPtrs),
		'\tEND',
	];
	return lines.join('\n') + '\n';
}

function parseLstSymbolMapFromText(text) {
	const map = new Map();
	for (const line of text.split(/\r?\n/)) {
		const match = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (match) map.set(match[2], parseInt(match[1], 16));
	}
	return map;
}

function assembleHelperBlock(asmText, asm68kPath) {
	const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-minimap-raw-'));
	const asmPath = path.join(tempDir, 'helper.asm');
	const binPath = path.join(tempDir, 'helper.bin');
	const lstPath = path.join(tempDir, 'helper.lst');
	fs.writeFileSync(asmPath, asmText, 'utf8');
	try {
		execFileSync(asm68kPath, ['/p', '/o', 'ae-', `${asmPath},${binPath},,${lstPath}`], {
			stdio: 'pipe',
		});
	} catch (error) {
		const stdout = error.stdout ? String(error.stdout) : '';
		const stderr = error.stderr ? String(error.stderr) : '';
		throw new Error(`failed to assemble minimap raw-map helper\n${stdout}${stderr}`.trim());
	}
	const codeBytes = fs.readFileSync(binPath);
	const symbolMap = parseLstSymbolMapFromText(fs.readFileSync(lstPath, 'utf8'));
	return {
		codeBytes,
		helperOffsets: {
			preview: symbolMap.get('Preview_map_helper'),
			hud: symbolMap.get('Hud_map_helper'),
			finish: symbolMap.get('Finish_map_helper'),
		},
	};
}

function readTrackCompressedMapPointer(rom, trackIndex) {
	const entryAddr = TRACK_DATA_ADDR + (trackIndex * TRACK_ENTRY_SIZE);
	return rom.readUInt32BE(entryAddr + MINIMAP_MAP_PTR_OFFSET);
}

function patchRomEnd(buffer) {
	buffer.writeUInt32BE(buffer.length - 1, 0x01A4);
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		options: ['--rom', '--input'],
	});

	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

	const asm68kPath = path.resolve('asm68k.exe');
	if (!fs.existsSync(asm68kPath)) die(`assembler not found: ${asm68kPath}`);

	const tracksData = loadTracksData(args.options['--input'] || undefined);
	const tracks = Array.isArray(tracksData?.tracks) ? tracksData.tracks.slice().sort((a, b) => a.index - b.index) : [];
	if (tracks.length === 0) die('no tracks found');

	const sourceRom = fs.readFileSync(romPath);
	let cursor = sourceRom.length;
	const chunks = [sourceRom];
	const previewRawMapPtrs = [];
	const hudRawMapPtrs = [];

	for (const track of tracks) {
		const block = appendBlock(chunks, cursor, buildPreviewRawMap(track));
		cursor = block.end;
		previewRawMapPtrs[track.index] = block.start;
	}

	for (const track of tracks) {
		const block = appendBlock(chunks, cursor, buildHudRawMap(track));
		cursor = block.end;
		hudRawMapPtrs[track.index] = block.start;
	}

	const compressedMapPtrs = tracks.map(track => readTrackCompressedMapPointer(sourceRom, track.index));
	const helperAsm = buildHelperAsm(compressedMapPtrs, previewRawMapPtrs, hudRawMapPtrs);
	const { codeBytes, helperOffsets } = assembleHelperBlock(helperAsm, asm68kPath);
	if (helperOffsets.preview === undefined || helperOffsets.hud === undefined || helperOffsets.finish === undefined) {
		throw new Error('failed to resolve helper labels from assembled minimap raw-map block');
	}

	const codeBlock = appendBlock(chunks, cursor, codeBytes);
	const previewHelperAddr = codeBlock.start + helperOffsets.preview;
	const hudHelperAddr = codeBlock.start + helperOffsets.hud;
	const finishHelperAddr = codeBlock.start + helperOffsets.finish;
	cursor = codeBlock.end;

	const rom = Buffer.concat(chunks, cursor);
	encodeJsrAbsoluteLong(previewHelperAddr).copy(rom, PREVIEW_MAP_JSR_ADDR);
	encodeJsrAbsoluteLong(hudHelperAddr).copy(rom, HUD_MAP_JSR_ADDR);
	encodeJsrAbsoluteLong(finishHelperAddr).copy(rom, FINISH_MAP_JSR_ADDR);
	patchRomEnd(rom);

	fs.writeFileSync(romPath, rom);
	const checksum = patchRomChecksum(romPath);

	info(`Patched raw minimap map helpers into ${path.relative(process.cwd(), romPath)}`);
	info(`Preview helper: $${previewHelperAddr.toString(16).toUpperCase()}`);
	info(`HUD helper: $${hudHelperAddr.toString(16).toUpperCase()}`);
	info(`Finish helper: $${finishHelperAddr.toString(16).toUpperCase()}`);
	info(`Raw preview map range: $${previewRawMapPtrs[0].toString(16).toUpperCase()}-$${(hudRawMapPtrs[0] - 1).toString(16).toUpperCase()}`);
	info(`Raw HUD map range: $${hudRawMapPtrs[0].toString(16).toUpperCase()}-$${(codeBlock.start - 1).toString(16).toUpperCase()}`);
	info(`ROM checksum ${checksum.changed ? 'updated' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
}

if (require.main === module) main();
