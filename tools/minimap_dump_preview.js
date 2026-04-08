#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { parseArgs, die, info } = require('./lib/cli');
const { loadTracksData, findTrack } = require('./lib/minimap_analysis');
const { getMinimapPreview } = require('./lib/minimap_preview');
const { buildGeneratedMinimapPreview } = require('./lib/minimap_render');

function crc32(buffer) {
	let crc = 0xFFFFFFFF;
	for (let i = 0; i < buffer.length; i++) {
		crc ^= buffer[i];
		for (let j = 0; j < 8; j++) {
			crc = (crc >>> 1) ^ ((crc & 1) ? 0xEDB88320 : 0);
		}
	}
	return (crc ^ 0xFFFFFFFF) >>> 0;
}

function makeChunk(type, data) {
	const typeBuf = Buffer.from(type, 'ascii');
	const lenBuf = Buffer.alloc(4);
	lenBuf.writeUInt32BE(data.length >>> 0, 0);
	const crcBuf = Buffer.alloc(4);
	crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])) >>> 0, 0);
	return Buffer.concat([lenBuf, typeBuf, data, crcBuf]);
}

function writePng(filePath, width, height, rgba) {
	const signature = Buffer.from([137,80,78,71,13,10,26,10]);
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(width, 0);
	ihdr.writeUInt32BE(height, 4);
	ihdr[8] = 8;
	ihdr[9] = 6;
	ihdr[10] = 0;
	ihdr[11] = 0;
	ihdr[12] = 0;

	const rows = [];
	for (let y = 0; y < height; y++) {
		const row = Buffer.alloc(1 + width * 4);
		row[0] = 0;
		rgba.copy(row, 1, y * width * 4, (y + 1) * width * 4);
		rows.push(row);
	}
	const idat = zlib.deflateSync(Buffer.concat(rows));
	const png = Buffer.concat([
		signature,
		makeChunk('IHDR', ihdr),
		makeChunk('IDAT', idat),
		makeChunk('IEND', Buffer.alloc(0)),
	]);
	fs.writeFileSync(filePath, png);
}

function renderPreviewToRgba(preview, color) {
	const rgba = Buffer.alloc(preview.width * preview.height * 4);
	for (let i = 0; i < preview.width * preview.height; i++) {
		const value = preview.pixels[i];
		const offset = i * 4;
		if (!value) {
			rgba[offset + 0] = 245;
			rgba[offset + 1] = 247;
			rgba[offset + 2] = 250;
			rgba[offset + 3] = 255;
			continue;
		}
		rgba[offset + 0] = color[0];
		rgba[offset + 1] = color[1];
		rgba[offset + 2] = color[2];
		rgba[offset + 3] = 255;
	}
	return rgba;
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		options: ['--track', '--input', '--out-dir'],
	});
	const trackArg = args.options['--track'];
	if (!trackArg) die('missing required option: --track');
	const input = args.options['--input'];
	const outDir = path.resolve(args.options['--out-dir'] || path.join('build', 'minimap_preview_dumps'));
	fs.mkdirSync(outDir, { recursive: true });

	const tracksData = loadTracksData(input);
	const track = findTrack(trackArg, tracksData);
	if (!track) die(`track not found: ${trackArg}`);

	const original = getMinimapPreview(track.slug);
	const generated = buildGeneratedMinimapPreview(track);
	const originalPath = path.join(outDir, `${track.slug}_original.png`);
	const generatedPath = path.join(outDir, `${track.slug}_generated.png`);
	writePng(originalPath, original.width, original.height, renderPreviewToRgba(original, [60, 70, 82]));
	writePng(generatedPath, generated.width, generated.height, renderPreviewToRgba(generated, [213, 51, 47]));
	info(`Wrote ${path.relative(process.cwd(), originalPath)}`);
	info(`Wrote ${path.relative(process.cwd(), generatedPath)}`);
}

main();
