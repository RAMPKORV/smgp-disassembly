#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const { loadTracksData, findTrack, TRACKS_JSON } = require('./lib/minimap_analysis');
const { buildGeneratedMinimapPosPairs } = require('./lib/generated_minimap_pos');
const { encodeMinimapPos } = require('./inject_track_data');
const { buildGeneratedMinimapOutput } = require('./lib/minimap_result_model');
const { getTrackMinimapTrailing } = require('./randomizer/track_model');

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--json'],
		options: ['--track', '--input', '--out', '--bin-out'],
	});

	const inputPath = args.options['--input'] || TRACKS_JSON;
	const trackArg = args.options['--track'] || 'san_marino';
	const tracksData = loadTracksData(inputPath);
	const track = findTrack(trackArg, tracksData);
	if (!track) die(`track not found: ${trackArg}`);

	const generated = { pairs: buildGeneratedMinimapPosPairs(track) };
	const trailing = getTrackMinimapTrailing(track);
	const jsonOut = args.options['--out'] ? path.resolve(args.options['--out']) : null;
	const binOut = args.options['--bin-out'] ? path.resolve(args.options['--bin-out']) : null;

	if (jsonOut) {
		fs.mkdirSync(path.dirname(jsonOut), { recursive: true });
		fs.writeFileSync(jsonOut, JSON.stringify(buildGeneratedMinimapOutput(track, generated, { includeTrackLength: true }), null, 2) + '\n', 'utf8');
		info(`Wrote ${path.relative(process.cwd(), jsonOut)}`);
	}

	if (binOut) {
		fs.mkdirSync(path.dirname(binOut), { recursive: true });
		fs.writeFileSync(binOut, encodeMinimapPos(generated.pairs, trailing));
		info(`Wrote ${path.relative(process.cwd(), binOut)}`);
	}

	if (!jsonOut && !binOut || args.flags['--json']) {
		process.stdout.write(JSON.stringify(buildGeneratedMinimapOutput(track, generated, { includeTrackLength: false }), null, 2) + '\n');
	}
}

main();
