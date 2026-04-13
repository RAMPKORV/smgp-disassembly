#!/usr/bin/env node
// tools/generate_track_data_asm.js
//
// Generate src/road_and_track_data_generated.asm from the current data/tracks/ tree.
// This replaces the fixed in-source incbin layout with a generated file so track
// stream blobs can grow/shrink while the assembler relocates all labels.

'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT } = require('./lib/rom');

const SOURCE_ASM = path.join(REPO_ROOT, 'src', 'road_and_track_data.asm');
const OUTPUT_ASM = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');

const TRACK_BLOCK_START = 'San_Marino_curve_data:';
const TRACK_BLOCK_END = 'Monaco_arcade_post_sign_tileset_blob:';
const MONACO_ARCADE_TRAILING_PAD_BYTES = 2399;

const TRACK_LAYOUT = [
  { slug: 'san_marino', prefix: 'San_Marino' },
  { slug: 'monaco', prefix: 'Monaco' },
  { slug: 'mexico', prefix: 'Mexico' },
  { slug: 'france', prefix: 'France' },
  { slug: 'great_britain', prefix: 'Great_Britain' },
  { slug: 'west_germany', prefix: 'West_Germany' },
  { slug: 'hungary', prefix: 'Hungary' },
  { slug: 'belgium', prefix: 'Belgium' },
  { slug: 'portugal', prefix: 'Portugal' },
  { slug: 'spain', prefix: 'Spain' },
  { slug: 'australia', prefix: 'Australia' },
  { slug: 'usa', prefix: 'Usa' },
  { slug: 'japan', prefix: 'Japan' },
  { slug: 'canada', prefix: 'Canada' },
  { slug: 'italy', prefix: 'Italy' },
  { slug: 'brazil', prefix: 'Brazil' },
  { slug: 'monaco_arcade_prelim', prefix: 'Monaco_arcade_prelim' },
  { slug: 'monaco_arcade', prefix: 'Monaco_arcade' },
];

const GENERATED_MINIMAP_DATA_FILE = 'data/tracks/generated_minimap_data.asm';

function countDcBBytes(line) {
	const match = line.split(';')[0].match(/^\s*dc\.b\s+(.*)$/i);
	if (!match) return null;
	return match[1]
		.split(',')
		.map(token => token.trim())
		.filter(Boolean)
		.length;
}

function scanAsmDataLayout(text, baseDir, state) {
	for (const line of text.split(/\r?\n/)) {
		if (/^\s*Monaco_arcade_post_sign_tileset_blob:/i.test(line) && state.blobStart === null) {
			state.blobStart = state.total;
			continue;
		}

		const include = line.match(/^\s*include\s+"([^"]+)"/i);
		if (include) {
			const includePath = path.resolve(baseDir, include[1]);
			if (fs.existsSync(includePath)) {
				scanAsmDataLayout(fs.readFileSync(includePath, 'utf8'), path.dirname(includePath), state);
			}
			continue;
		}

		const incbin = line.match(/^\s*incbin\s+"([^"]+)"/i);
		if (incbin) {
			const filePath = path.resolve(baseDir, incbin[1]);
			if (fs.existsSync(filePath)) state.total += fs.statSync(filePath).size;
			continue;
		}

		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) {
			state.total += parseInt(dcb[1], 10);
			continue;
		}

		const dcBCount = countDcBBytes(line);
		if (dcBCount !== null) {
			state.total += dcBCount;
		}
	}
	return state;
}

function measureAsmDataLayout(text, baseDir) {
	return scanAsmDataLayout(text, baseDir, { total: 0, blobStart: null });
}

function buildGeneratedMinimapIncludeBlock() {
	return [
		'Generated_minimap_preview_data:',
		`\tinclude\t"${GENERATED_MINIMAP_DATA_FILE}"`,
	];
}

const FILE_SPECS = [
	{ suffix: 'curve_data', file: 'curve_data.bin', comments: [] },
	{ suffix: 'slope_data', file: 'slope_data.bin', comments: [] },
	{ suffix: 'phys_slope_data', file: 'phys_slope_data.bin', comments: [] },
	{ suffix: 'minimap_pos', file: 'minimap_pos.bin', comments: [] },
	{ suffix: 'sign_data', file: 'sign_data.bin', comments: [] },
	{ suffix: 'sign_tileset', file: 'sign_tileset.bin', comments: [] },
];

function buildGeneratedTrackBlock(options = {}) {
	const padBytes = options.padBytes || 0;
	const preBlobPadBytes = options.preBlobPadBytes || 0;
	const includeGeneratedMinimapData = options.includeGeneratedMinimapData === true;
	const inlineBlobPadBytes = options.keepInlineBlobPadding === false
		? 0
		: Math.max(0, options.inlineBlobPadBytes ?? MONACO_ARCADE_TRAILING_PAD_BYTES);
  const lines = [];

	for (const track of TRACK_LAYOUT) {
    for (const spec of FILE_SPECS) {
      lines.push(`${track.prefix}_${spec.suffix}:`);
      for (const comment of spec.comments) lines.push(comment);
      lines.push(`\tincbin\t"data/tracks/${track.slug}/${spec.file}"`);
    }
  }

	if (includeGeneratedMinimapData) {
		lines.push(...buildGeneratedMinimapIncludeBlock());
	}

	if (preBlobPadBytes > 0) {
		lines.push(`\tdcb.b\t${preBlobPadBytes}, $00`);
	}
	lines.push('Monaco_arcade_post_sign_tileset_blob:');
	lines.push('\tincbin\t"data/tracks/monaco_arcade/post_sign_tileset_blob.bin"');
	if (inlineBlobPadBytes > 0) {
		lines.push(`\tdcb.b\t${inlineBlobPadBytes}, $00`);
	}
	if (padBytes > 0) {
		lines.push(`\tdcb.b\t${padBytes}, $00`);
	}
  return lines.join('\n') + '\n';
}

function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['--dry-run', '--verbose', '-v'],
    options: ['--out'],
  });

  const dryRun = args.flags['--dry-run'];
  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const outPath = path.resolve(REPO_ROOT, args.options['--out'] || 'src/road_and_track_data_generated.asm');

  const content = buildGeneratedTrackBlock();
  if (dryRun) {
    info(`[dry-run] Would write ${path.relative(REPO_ROOT, outPath)} (${content.split(/\r?\n/).length - 1} lines)`);
    return;
  }

  fs.writeFileSync(outPath, content, 'utf8');
  if (verbose) {
    info(`Wrote ${path.relative(REPO_ROOT, outPath)}`);
  }
}

if (require.main === module) main();

module.exports = {
  TRACK_LAYOUT,
  FILE_SPECS,
  GENERATED_MINIMAP_DATA_FILE,
  MONACO_ARCADE_TRAILING_PAD_BYTES,
  buildGeneratedMinimapIncludeBlock,
  buildGeneratedTrackBlock,
  measureAsmDataLayout,
};
