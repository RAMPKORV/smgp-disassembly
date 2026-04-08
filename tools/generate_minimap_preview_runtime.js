#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { loadTracksData, findTrack } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapPreview } = require('./lib/minimap_render');

function buildTilesFromPreview(preview) {
	const tileMap = new Map();
	const tiles = [];
	const words = [];

	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			const rows = [];
			for (let y = 0; y < 8; y++) {
				const row = [];
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
					row.push(preview.pixels[(py * preview.width) + px] || 0);
				}
				rows.push(row);
			}
			const signature = rows.map(row => row.join('')).join('/');
			if (/^0(?:,0){7}(?:\/0(?:,0){7}){7}$/.test(signature)) {
				words.push(0);
				continue;
			}
			let tileIndex = tileMap.get(signature);
			if (tileIndex === undefined) {
				tileIndex = tiles.length;
				tileMap.set(signature, tileIndex);
				tiles.push(rows);
			}
			words.push(tileIndex + 1);
		}
	}

	return { tiles, words };
}

function tileToLongwords(tile) {
	const longs = [];
	for (let row = 0; row < 8; row++) {
		let value = 0;
		for (let col = 0; col < 8; col++) {
			value = ((value << 4) | (tile[row][col] & 0x0F)) >>> 0;
		}
		longs.push(value >>> 0);
	}
	return longs;
}

function formatLong(value) {
	return `$${value.toString(16).toUpperCase().padStart(8, '0')}`;
}

function formatWord(value) {
	return `$${value.toString(16).toUpperCase().padStart(4, '0')}`;
}

function generateAsm(track) {
	const preview = buildGeneratedMinimapPreview(track);
	const { tiles, words } = buildTilesFromPreview(preview);
	const tileLongwords = tiles.flatMap(tileToLongwords);
	const lines = [];
	lines.push('Generated_minimap_preview_San_Marino_tile_longword_count:');
	lines.push(`\tdc.w\t${tileLongwords.length}`);
	lines.push('Generated_minimap_preview_San_Marino_tiles:');
	for (let i = 0; i < tileLongwords.length; i += 4) {
		lines.push(`\tdc.l\t${tileLongwords.slice(i, i + 4).map(formatLong).join(', ')}`);
	}
	lines.push('Generated_minimap_preview_San_Marino_map:');
	for (let i = 0; i < words.length; i += 7) {
		lines.push(`\tdc.w\t${words.slice(i, i + 7).map(formatWord).join(', ')}`);
	}
	return lines.join('\n') + '\n';
}

function main() {
	const args = parseArgs(process.argv.slice(2), { options: ['--track', '--input', '--output'] });
	const output = path.resolve(args.options['--output'] || path.join('src', 'generated_minimap_preview_data.asm'));
	const tracksData = loadTracksData(args.options['--input']);
	const trackArg = args.options['--track'] || 'san_marino';
	const track = findTrack(trackArg, tracksData);
	if (!track) die(`track not found: ${trackArg}`);
	fs.writeFileSync(output, generateAsm(track), 'utf8');
	info(`Wrote ${path.relative(process.cwd(), output)}`);
}

main();
