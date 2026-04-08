#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { loadTracksData, findTrack } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapPreview } = require('./lib/minimap_render');
const { encodeCompactTilemap } = require('./minimap_map_codec');

function buildTileWordsFromPreview(preview) {
	const tileMap = new Map();
	const words = [];
	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			const rows = [];
			for (let y = 0; y < 8; y++) {
				const row = [];
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
					row.push(preview.pixels[(py * preview.width) + px] ? 1 : 0);
				}
				rows.push(row);
			}
			const signature = rows.map(row => row.join('')).join('/');
			if (/^00000000(?:\/00000000){7}$/.test(signature)) {
				words.push(0);
				continue;
			}
			let tileIndex = tileMap.get(signature);
			if (tileIndex === undefined) {
				tileIndex = tileMap.size + 1;
				tileMap.set(signature, tileIndex);
			}
			words.push(tileIndex);
		}
	}
	return words;
}

function formatDcB(bytes) {
	const lines = [];
	for (let i = 0; i < bytes.length; i += 32) {
		const chunk = bytes.slice(i, i + 32);
		lines.push(`\tdc.b\t${Array.from(chunk).map(v => `$${v.toString(16).toUpperCase().padStart(2, '0')}`).join(', ')}`);
	}
	return lines.join('\n');
}

function replaceLabelBlock(asmText, label, replacementBlock) {
	const lines = asmText.split(/\r?\n/);
	const labelLine = `${label}:`;
	const start = lines.findIndex(line => line.trim() === labelLine);
	if (start < 0) throw new Error(`Label not found: ${label}`);
	let end = start + 1;
	while (end < lines.length && !/^[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(lines[end].trim())) end += 1;
	const replacementLines = [labelLine, ...replacementBlock.split(/\r?\n/)];
	lines.splice(start, end - start, ...replacementLines);
	return lines.join('\n');
}

function main() {
	const args = parseArgs(process.argv.slice(2), { options: ['--track', '--input', '--asm', '--label'] });
	const trackArg = args.options['--track'] || 'san_marino';
	const asmPath = path.resolve(args.options['--asm'] || path.join('src', 'hud_and_minimap_data.asm'));
	const label = args.options['--label'] || 'Minimap_map_San_Marino';
	const tracksData = loadTracksData(args.options['--input']);
	const track = findTrack(trackArg, tracksData);
	if (!track) die(`track not found: ${trackArg}`);
	const preview = buildGeneratedMinimapPreview(track);
	const words = buildTileWordsFromPreview(preview);
	const encoded = encodeCompactTilemap(words, 6);
	const asmText = fs.readFileSync(asmPath, 'utf8');
	const updated = replaceLabelBlock(asmText, label, formatDcB(encoded));
	fs.writeFileSync(asmPath, updated, 'utf8');
	info(`Patched ${label} in ${path.relative(process.cwd(), asmPath)}`);
	info(`Encoded bytes: ${encoded.length}`);
}

main();
