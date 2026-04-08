#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');

const CODE_CAVE_ADDR = 0x13DE6;
const DATA_CAVE_ADDR = 0x13E10;
const LOAD_TRACK_DATA_POINTER_ADDR = 0x0F848;
const PREVIEW_JSR_TILES_ADDR = 0x058C4;
const PREVIEW_JSR_MAP_ADDR = 0x058DC;
const TRACK_PREVIEW_INDEX_ADDR = 0x00FFEFCA;
const TRACK_CONFIG_SAN_MARINO_ADDR = 0x05372;

function readWorkspaceLabelAddress(lstPath, label) {
	const text = fs.readFileSync(lstPath, 'utf8');
	for (const line of text.split(/\r?\n/)) {
		const m = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (m && m[2] === label) return parseInt(m[1], 16);
	}
	throw new Error(`Label not found in listing: ${label}`);
}

function writeWordBE(buffer, offset, value) {
	buffer.writeUInt16BE(value & 0xFFFF, offset);
}

function writeLongBE(buffer, offset, value) {
	buffer.writeUInt32BE(value >>> 0, offset);
}

function encodeJsrAbsoluteLong(address) {
	const buf = Buffer.alloc(6);
	writeWordBE(buf, 0, 0x4EB9);
	writeLongBE(buf, 2, address);
	return buf;
}

function assembleHelper(dataTableAddr) {
	const words = [];
	function w(v) { words.push(v & 0xFFFF); }

	// JSR Load_track_data_pointer
	w(0x4EB9); w((LOAD_TRACK_DATA_POINTER_ADDR >>> 16) & 0xFFFF); w(LOAD_TRACK_DATA_POINTER_ADDR & 0xFFFF);
	// TST.w Track_preview_index.w
	w(0x4A78); w(TRACK_PREVIEW_INDEX_ADDR & 0xFFFF);
	// BNE.s +8 (skip override movea)
	w(0x6608);
	// MOVEA.l #dataTableAddr, A1
	w(0x227C); w((dataTableAddr >>> 16) & 0xFFFF); w(dataTableAddr & 0xFFFF);
	// RTS
	w(0x4E75);

	const buf = Buffer.alloc(words.length * 2);
	for (let i = 0; i < words.length; i++) writeWordBE(buf, i * 2, words[i]);
	return buf;
}

function buildPreviewDataBlock(buffer, lstPath) {
	const previewTiles = readWorkspaceLabelAddress(lstPath, 'Preview_tiles_San_Marino');
	const previewMap = readWorkspaceLabelAddress(lstPath, 'Preview_map_San_Marino');
	const bgTiles = readWorkspaceLabelAddress(lstPath, 'Track_bg_tiles_San_Marino');
	const bgMap = readWorkspaceLabelAddress(lstPath, 'Track_bg_tilemap_San_Marino');
	const bgPalette = readWorkspaceLabelAddress(lstPath, 'San_Marino_bg_palette');

	const data = Buffer.alloc(5 * 4);
	writeLongBE(data, 0x00, previewTiles);
	writeLongBE(data, 0x04, bgTiles);
	writeLongBE(data, 0x08, bgMap);
	writeLongBE(data, 0x0C, previewMap);
	writeLongBE(data, 0x10, bgPalette);
	return data;
}

function main() {
	const args = parseArgs(process.argv.slice(2), { options: ['--rom', '--lst'] });
	const romPath = path.resolve(args.options['--rom'] || 'out.bin');
	const lstPath = path.resolve(args.options['--lst'] || 'smgp.lst');
	if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);
	if (!fs.existsSync(lstPath)) die(`Listing not found: ${lstPath}`);

	const rom = fs.readFileSync(romPath);
	const previewData = buildPreviewDataBlock(rom, lstPath);
	const helper = assembleHelper(DATA_CAVE_ADDR);

	previewData.copy(rom, DATA_CAVE_ADDR);
	helper.copy(rom, CODE_CAVE_ADDR);
	encodeJsrAbsoluteLong(CODE_CAVE_ADDR).copy(rom, PREVIEW_JSR_TILES_ADDR);
	encodeJsrAbsoluteLong(CODE_CAVE_ADDR).copy(rom, PREVIEW_JSR_MAP_ADDR);

	fs.writeFileSync(romPath, rom);
	info(`Patched preview-only minimap hook into ${path.relative(process.cwd(), romPath)}`);
}

main();
