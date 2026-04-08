#!/usr/bin/env node
'use strict';

const { parseArgs, die, info } = require('./lib/cli');
const { loadTracksData, findTrack, generateMinimapPairsFromTrack, TRACKS_JSON } = require('./lib/minimap_analysis');

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--json'],
		options: ['--track', '--input'],
	});

	const inputPath = args.options['--input'] || TRACKS_JSON;
	const trackArg = args.options['--track'];
	if (!trackArg) die('missing required option: --track');

	const tracksData = loadTracksData(inputPath);
	const track = findTrack(trackArg, tracksData);
	if (!track) die(`track not found: ${trackArg}`);

	const generated = generateMinimapPairsFromTrack(track);
	if (args.flags['--json']) {
		process.stdout.write(JSON.stringify({
			track: {
				index: track.index,
				name: track.name,
				slug: track.slug,
			},
			generated,
		}, null, 2) + '\n');
		return;
	}

	info(`${track.name} (${track.slug})`);
	info(`transform=${generated.transform} match=${generated.match_percent.toFixed(2)}% thick=${generated.thickness_aware_match_percent.toFixed(2)}% samples=${generated.sample_count}`);
	info(`first 8 pairs: ${generated.pairs.slice(0, 8).map(pair => `(${pair[0]},${pair[1]})`).join(' ')}`);
}

main();
