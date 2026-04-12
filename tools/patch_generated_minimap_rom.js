#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { encodeTinyGraphics } = require('./minimap_graphics_codec');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { assertSafeRomPath } = require('./lib/workspace_guard');

const HUD_TILES_DATA_ADDR = 0x050C20;
const HUD_TILES_DATA_MAX = 0x0511B8 - 0x050C20;
const HUD_MAP_DATA_ADDR = 0x04D20E;
const HUD_MAP_DATA_MAX = 0x04D2AA - 0x04D20E;
const HUD_MAP_HELPER_ADDR = 0x050BEC;
const HUD_MAP_HELPER_MAX = 0x050C20 - 0x050BEC;
const HUD_MAP_JSR_ADDR = 0x000011EC;
const ORIGINAL_HUD_MAP_CALL_ADDR = 0x000007CE;
const WRITE_TILEMAP_ROWS_TO_VDP_ADDR = 0x000007DC;
const TRACK_DATA_ADDR = 0x0000F872;
const TRACK_ENTRY_SIZE = 0x48;
const SAN_MARINO_TRACK_INDEX = 0;

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

function parseWordTableBlock(filePath, label) {
	const text = fs.readFileSync(filePath, 'utf8');
	const lines = text.split(/\r?\n/);
	const start = lines.findIndex(line => line.trim() === `${label}:`);
	if (start < 0) throw new Error(`Label not found in ${filePath}: ${label}`);
	const words = [];
	for (let i = start + 1; i < lines.length; i++) {
		const trimmed = lines[i].trim();
		if (/^[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(trimmed)) break;
		const m = lines[i].split(';')[0].match(/\bdc\.w\b\s+(.*)$/i);
		if (!m) continue;
		for (const token of m[1].split(',')) {
			const value = token.trim();
			if (!value) continue;
			words.push(parseInt(value.slice(1), 16) & 0xFFFF);
		}
	}
	return words;
}

function parseLongTableBlock(filePath, label) {
	const text = fs.readFileSync(filePath, 'utf8');
	const lines = text.split(/\r?\n/);
	const start = lines.findIndex(line => line.trim() === `${label}:`);
	if (start < 0) throw new Error(`Label not found in ${filePath}: ${label}`);
	const longs = [];
	for (let i = start + 1; i < lines.length; i++) {
		const trimmed = lines[i].trim();
		if (/^[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(trimmed)) break;
		const m = lines[i].split(';')[0].match(/\bdc\.l\b\s+(.*)$/i);
		if (!m) continue;
		for (const token of m[1].split(',')) {
			const value = token.trim();
			if (!value) continue;
			longs.push(parseInt(value.slice(1), 16) >>> 0);
		}
	}
	return longs;
}

function buildTilesFromRuntimeLongwords(tileLongwords) {
	if ((tileLongwords.length & 7) !== 0) {
		throw new Error(`Runtime tile longword count is not divisible by 8: ${tileLongwords.length}`);
	}
	const tiles = [];
	for (let i = 0; i < tileLongwords.length; i += 8) {
		const tile = [];
		for (let row = 0; row < 8; row++) {
			const value = tileLongwords[i + row] >>> 0;
			const pixels = [];
			for (let shift = 28; shift >= 0; shift -= 4) pixels.push((value >>> shift) & 0x0F);
			tile.push(pixels);
		}
		tiles.push(tile);
	}
	return tiles;
}

function buildHudAssetsFromRuntimeAsm(runtimeAsmPath) {
	const tileLongwords = parseLongTableBlock(runtimeAsmPath, 'Generated_minimap_preview_San_Marino_tiles');
	const mapWords = parseWordTableBlock(runtimeAsmPath, 'Generated_minimap_preview_San_Marino_map');
	if (tileLongwords.length < 8) throw new Error('Runtime preview tile data are unexpectedly short');
	const tiles = buildTilesFromRuntimeLongwords(tileLongwords.slice(8));
	const hudMapWords = mapWords.map(word => {
		if (word === 0 || word === 1) return 0;
		return (0x8000 | ((word - 1) & 0x07FF)) & 0xFFFF;
	});
	const rawMap = Buffer.alloc(hudMapWords.length * 2);
	for (let i = 0; i < hudMapWords.length; i++) writeWordBE(rawMap, i * 2, hudMapWords[i]);
	return {
		tiles,
		hudTilesData: Buffer.from(encodeTinyGraphics(tiles)),
		hudMapWords,
		hudMapData: rawMap,
	};
}

function assembleHudMapHelper() {
	const words = [];
	const w = value => words.push(value & 0xFFFF);
	const l = value => {
		w((value >>> 16) & 0xFFFF);
		w(value & 0xFFFF);
	};

	w(0xB1FC); l(HUD_MAP_DATA_ADDR);
	w(0x6600); const branchIndex = words.length; w(0x0000);
	w(0x2C48);
	w(0x263C); l(0x00400000);
	w(0x4EB9); l(WRITE_TILEMAP_ROWS_TO_VDP_ADDR);
	w(0x4E75);
	const normalOffset = words.length;
	w(0x4EF9); l(ORIGINAL_HUD_MAP_CALL_ADDR);

	words[branchIndex] = ((normalOffset - (branchIndex + 1)) * 2) & 0xFFFF;

	const out = Buffer.alloc(words.length * 2);
	for (let i = 0; i < words.length; i++) writeWordBE(out, i * 2, words[i]);
	return out;
}

function assertFits(size, max, name) {
	if (size > max) throw new Error(`${name} overflow: ${size} > ${max}`);
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--allow-root-mutation'],
		options: ['--rom', '--runtime-asm'],
	});
	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	try {
		assertSafeRomPath(romPath, { allowRootMutation: args.flags['--allow-root-mutation'] });
	} catch (err) {
		die(err.message);
	}
	const runtimeAsmPath = path.resolve(args.options['--runtime-asm'] || path.join('src', 'generated_minimap_preview_data.asm'));
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);
	if (!fs.existsSync(runtimeAsmPath)) die(`Runtime preview ASM not found: ${runtimeAsmPath}`);

	const assets = buildHudAssetsFromRuntimeAsm(runtimeAsmPath);
	const hudMapHelper = assembleHudMapHelper();
	assertFits(assets.hudTilesData.length, HUD_TILES_DATA_MAX, 'HUD tiles data');
	assertFits(assets.hudMapData.length, HUD_MAP_DATA_MAX, 'HUD map data');
	assertFits(hudMapHelper.length, HUD_MAP_HELPER_MAX, 'HUD map helper');

	const rom = fs.readFileSync(romPath);
	rom.fill(0xFF, HUD_TILES_DATA_ADDR, HUD_TILES_DATA_ADDR + HUD_TILES_DATA_MAX);
	rom.fill(0xFF, HUD_MAP_DATA_ADDR, HUD_MAP_DATA_ADDR + HUD_MAP_DATA_MAX);
	rom.fill(0xFF, HUD_MAP_HELPER_ADDR, HUD_MAP_HELPER_ADDR + HUD_MAP_HELPER_MAX);

	assets.hudTilesData.copy(rom, HUD_TILES_DATA_ADDR);
	assets.hudMapData.copy(rom, HUD_MAP_DATA_ADDR);
	hudMapHelper.copy(rom, HUD_MAP_HELPER_ADDR);

	const trackEntryAddr = TRACK_DATA_ADDR + (SAN_MARINO_TRACK_INDEX * TRACK_ENTRY_SIZE);
	writeLongBE(rom, trackEntryAddr + 0x00, HUD_TILES_DATA_ADDR);
	writeLongBE(rom, trackEntryAddr + 0x0C, HUD_MAP_DATA_ADDR);
	encodeJsrAbsoluteLong(HUD_MAP_HELPER_ADDR).copy(rom, HUD_MAP_JSR_ADDR);

	fs.writeFileSync(romPath, rom);
	const checksum = patchRomChecksum(romPath);
	info(`Patched HUD minimap assets into ${path.relative(process.cwd(), romPath)}`);
	info(`Track: San Marino`);
	info(`HUD tiles addr: $${HUD_TILES_DATA_ADDR.toString(16).toUpperCase()}`);
	info(`HUD map addr: $${HUD_MAP_DATA_ADDR.toString(16).toUpperCase()}`);
	info(`HUD tile count: ${assets.tiles.length}`);
	info(`HUD tiles bytes: ${assets.hudTilesData.length}`);
	info(`HUD map bytes: ${assets.hudMapData.length}`);
	info(`ROM checksum ${checksum.changed ? 'updated' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
}

main();
