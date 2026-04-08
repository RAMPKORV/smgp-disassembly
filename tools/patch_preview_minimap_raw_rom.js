#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');

const PREVIEW_JSR_TILES_ADDR = 0x058C4;
const PREVIEW_JSR_MAP_ADDR = 0x058DC;
const LOAD_TRACK_DATA_POINTER_ADDR = 0x0000F848;
const WRITE_TILEMAP_ROWS_ADDR = 0x000007DC;
const TILES_HELPER_ADDR = 0x076322;
const MAP_HELPER_ADDR = 0x076370;
const RAW_MAP_DATA_ADDR = 0x013DE6;
const TILES_CONTINUE_ADDR = 0x000058DC;
const MAP_CONTINUE_ADDR = 0x00005900;
const VDP_DATA_PORT_ADDR = 0x00C00000;
const VDP_CONTROL_PORT_ADDR = 0x00C00004;

function writeWordBE(buffer, offset, value) {
	buffer.writeUInt16BE(value & 0xFFFF, offset);
}

function writeLongBE(buffer, offset, value) {
	buffer.writeUInt32BE(value >>> 0, offset);
}

function readWorkspaceLabelAddress(lstPath, label) {
	const text = fs.readFileSync(lstPath, 'utf8');
	for (const line of text.split(/\r?\n/)) {
		const m = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (m && m[2] === label) return parseInt(m[1], 16);
	}
	throw new Error(`Label not found in listing: ${label}`);
}

function encodeJsrAbsoluteLong(address) {
	const buf = Buffer.alloc(6);
	writeWordBE(buf, 0, 0x4EB9);
	writeLongBE(buf, 2, address);
	return buf;
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
		const m = lines[i].split(';')[0].match(/dc\.w\s+(.*)$/i);
		if (!m) continue;
		for (const token of m[1].split(',')) {
			const value = token.trim();
			if (!value) continue;
			if (!value.startsWith('$')) throw new Error(`Expected hex dc.w token, got: ${value}`);
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
	const values = [];
	for (let i = start + 1; i < lines.length; i++) {
		const trimmed = lines[i].trim();
		if (/^[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(trimmed)) break;
		const m = lines[i].split(';')[0].match(/dc\.l\s+(.*)$/i);
		if (!m) continue;
		for (const token of m[1].split(',')) {
			const value = token.trim();
			if (!value) continue;
			if (!value.startsWith('$')) throw new Error(`Expected hex dc.l token, got: ${value}`);
			values.push(parseInt(value.slice(1), 16) >>> 0);
		}
	}
	return values;
}

function buildRawPreviewData(runtimeAsmPath) {
	const text = fs.readFileSync(runtimeAsmPath, 'utf8');
	const countMatch = text.match(/Generated_minimap_preview_San_Marino_tile_longword_count:\s*[\r\n]+\s*dc\.w\s+(\d+)/i);
	if (!countMatch) throw new Error('Could not parse generated tile longword count');
	const tileLongwordCount = parseInt(countMatch[1], 10);
	const tileLongwords = parseLongTableBlock(runtimeAsmPath, 'Generated_minimap_preview_San_Marino_tiles');
	if (tileLongwords.length !== tileLongwordCount) {
		throw new Error(`Generated tile count mismatch: header=${tileLongwordCount}, parsed=${tileLongwords.length}`);
	}
	const mapWords = parseWordTableBlock(runtimeAsmPath, 'Generated_minimap_preview_San_Marino_map');
	const out = Buffer.alloc(2 + (tileLongwords.length * 4) + (mapWords.length * 2));
	writeWordBE(out, 0, tileLongwords.length);
	for (let i = 0; i < tileLongwords.length; i++) writeLongBE(out, 2 + (i * 4), tileLongwords[i]);
	for (let i = 0; i < mapWords.length; i++) writeWordBE(out, 2 + (tileLongwords.length * 4) + (i * 2), mapWords[i]);
	return {
		buffer: out,
		tileLongwordCount: tileLongwords.length,
		mapWordCount: mapWords.length,
		rawTilesAddr: RAW_MAP_DATA_ADDR + 2,
		rawMapAddr: RAW_MAP_DATA_ADDR + 2 + (tileLongwords.length * 4),
	};
}

function assembleTilesHelper(rawTilesAddr, trackDataAddr) {
	const words = [];
	const w = value => words.push(value & 0xFFFF);
	const l = value => {
		w((value >>> 16) & 0xFFFF);
		w(value & 0xFFFF);
	};

	w(0x4EB9); l(LOAD_TRACK_DATA_POINTER_ADDR);
	w(0xB3FC); l(trackDataAddr);
	w(0x6600); const branchIndex = words.length; w(0x0000);
	w(0x23FC); l(0x40400000); l(VDP_CONTROL_PORT_ADDR);
	w(0x41F9); l(rawTilesAddr - 2);
	w(0x3018);
	w(0x5340);
	w(0x6B00); const skipLoopIndex = words.length; w(0x0000);
	const loopOffset = words.length;
	w(0x23D8); l(VDP_DATA_PORT_ADDR);
	w(0x51C8); const dbfIndex = words.length; w(0x0000);
	const tilesDoneOffset = words.length;
	w(0x4FEF); w(0x0004);
	w(0x4EF9); l(TILES_CONTINUE_ADDR);

	const normalPathWordOffset = words.length;
	w(0x4E75);

	const branchDisp = (normalPathWordOffset - branchIndex) * 2;
	words[branchIndex] = branchDisp & 0xFFFF;
	const skipLoopDisp = (tilesDoneOffset - skipLoopIndex) * 2;
	words[skipLoopIndex] = skipLoopDisp & 0xFFFF;
	const dbfDisp = ((loopOffset - dbfIndex) * 2) & 0xFFFF;
	words[dbfIndex] = dbfDisp;

	const out = Buffer.alloc(words.length * 2);
	for (let i = 0; i < words.length; i++) writeWordBE(out, i * 2, words[i]);
	return out;
}

function assembleMapHelper(rawMapAddr, trackDataAddr) {
	const words = [];
	const w = value => words.push(value & 0xFFFF);
	const l = value => {
		w((value >>> 16) & 0xFFFF);
		w(value & 0xFFFF);
	};

	w(0x4EB9); l(LOAD_TRACK_DATA_POINTER_ADDR);
	w(0xB3FC); l(trackDataAddr);
	w(0x6600); const branchIndex = words.length; w(0x0000);
	w(0x4DF9); l(rawMapAddr);
	w(0x2E3C); l(0x46060003);
	w(0x323C); w(0x0001);
	w(0x7C06);
	w(0x7A0A);
	w(0x263C); l(0x01000000);
	w(0x4EB9); l(WRITE_TILEMAP_ROWS_ADDR);
	w(0x4FEF); w(0x0004);
	w(0x4EF9); l(MAP_CONTINUE_ADDR);

	const normalPathWordOffset = words.length;
	w(0x4E75);

	const branchDisp = (normalPathWordOffset - branchIndex) * 2;
	words[branchIndex] = branchDisp & 0xFFFF;

	const out = Buffer.alloc(words.length * 2);
	for (let i = 0; i < words.length; i++) writeWordBE(out, i * 2, words[i]);
	return out;
}

function main() {
	const args = parseArgs(process.argv.slice(2), { options: ['--rom', '--lst', '--runtime-asm'] });
	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	const lstPath = path.resolve(args.options['--lst'] || 'smgp.lst');
	const runtimeAsmPath = path.resolve(args.options['--runtime-asm'] || path.join('src', 'generated_minimap_preview_data.asm'));
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);
	if (!fs.existsSync(lstPath)) die(`Listing not found: ${lstPath}`);
	if (!fs.existsSync(runtimeAsmPath)) die(`Runtime preview ASM not found: ${runtimeAsmPath}`);

	const previewData = buildRawPreviewData(runtimeAsmPath);
	const trackDataAddr = readWorkspaceLabelAddress(lstPath, 'Track_data');
	const rom = fs.readFileSync(romPath);

	previewData.buffer.copy(rom, RAW_MAP_DATA_ADDR);
	assembleTilesHelper(previewData.rawTilesAddr, trackDataAddr).copy(rom, TILES_HELPER_ADDR);
	assembleMapHelper(previewData.rawMapAddr, trackDataAddr).copy(rom, MAP_HELPER_ADDR);
	encodeJsrAbsoluteLong(TILES_HELPER_ADDR).copy(rom, PREVIEW_JSR_TILES_ADDR);
	encodeJsrAbsoluteLong(MAP_HELPER_ADDR).copy(rom, PREVIEW_JSR_MAP_ADDR);

	fs.writeFileSync(romPath, rom);
	info(`Patched split raw preview minimap hook into ${path.relative(process.cwd(), romPath)}`);
	info(`Raw tile longwords: ${previewData.tileLongwordCount}`);
	info(`Raw map words: ${previewData.mapWordCount}`);
}

main();
