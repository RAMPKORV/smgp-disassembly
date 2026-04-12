#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { formatDcB } = require('./lib/asm_patch_helpers');
const { loadTracksData, findTrack } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapPreview } = require('./lib/minimap_render');
const { encodeTinyGraphics } = require('./minimap_graphics_codec');

function buildTileAtlas(preview) {
	const tileMap = new Map();
	const tiles = [];
	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			const rows = [];
			for (let y = 0; y < 8; y++) {
				const row = [];
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
					row.push(preview.pixels[(py * preview.width) + px] ? 0x0E : 0x00);
				}
				rows.push(row);
			}
			const signature = rows.map(row => row.join('')).join('/');
			if (/^0(?:,0){7}(?:\/0(?:,0){7}){7}$/.test(signature)) continue;
			if (!tileMap.has(signature)) {
				tileMap.set(signature, tiles.length + 1);
				tiles.push(rows);
			}
		}
	}
	return tiles;
}

function replaceLabelBlock(asmText, label, replacementBlock) {
	const lines = asmText.split(/\r?\n/);
	const labelLine = `${label}:`;
	const start = lines.findIndex(line => line.trim() === labelLine);
	if (start < 0) throw new Error(`Label not found: ${label}`);
	let end = start + 1;
	while (end < lines.length && !/^[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(lines[end].trim())) end += 1;
	lines.splice(start, end - start, labelLine, ...replacementBlock.split(/\r?\n/));
	return lines.join('\n');
}

function main() {
	const args = parseArgs(process.argv.slice(2), { options: ['--track', '--input', '--asm', '--label'] });
	const trackArg = args.options['--track'] || 'san_marino';
	const asmPath = path.resolve(args.options['--asm'] || path.join('src', 'hud_and_minimap_data.asm'));
	const label = args.options['--label'] || 'Minimap_tiles_San_Marino';
	const tracksData = loadTracksData(args.options['--input']);
	const track = findTrack(trackArg, tracksData);
	if (!track) die(`track not found: ${trackArg}`);
	const preview = buildGeneratedMinimapPreview(track);
	const tiles = buildTileAtlas(preview);
	const encoded = encodeTinyGraphics(tiles);
	const asmText = fs.readFileSync(asmPath, 'utf8');
	const updated = replaceLabelBlock(asmText, label, formatDcB(encoded).join('\n'));
	fs.writeFileSync(asmPath, updated, 'utf8');
	info(`Patched ${label} in ${path.relative(process.cwd(), asmPath)}`);
	info(`Tile count: ${tiles.length}`);
	info(`Encoded bytes: ${encoded.length}`);
}

main();
