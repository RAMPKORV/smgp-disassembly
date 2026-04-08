#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT } = require('./lib/rom');
const { loadTracksData } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapAssetsAsm } = require('./lib/generated_minimap_assets');

const OUTPUT_REL = 'data/tracks/generated_minimap_data.asm';

function buildAsm(tracks) {
	return buildGeneratedMinimapAssetsAsm(tracks).content;
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		options: ['--input', '--output'],
	});
	const tracksData = loadTracksData(args.options['--input'] || undefined);
	const outputPath = path.resolve(REPO_ROOT, args.options['--output'] || OUTPUT_REL);
	if (!tracksData || !Array.isArray(tracksData.tracks)) die('missing tracks data');
	fs.mkdirSync(path.dirname(outputPath), { recursive: true });
	fs.writeFileSync(outputPath, buildAsm(tracksData.tracks), 'utf8');
	info(`Wrote ${path.relative(REPO_ROOT, outputPath)}`);
}

if (require.main === module) main();

module.exports = {
	buildAsm,
};
