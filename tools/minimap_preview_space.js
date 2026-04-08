#!/usr/bin/env node
'use strict';

const {
	findTrack,
	loadTracksData,
	analyzeTrackMinimap,
	TRACKS_JSON,
} = require('./lib/minimap_analysis');
const { parseArgs, die, info } = require('./lib/cli');

function formatFit(label, fit) {
	return [
		`${label}: transform=${fit.transform} match=${fit.match_percent.toFixed(2)}% mean=${fit.symmetric_mean_distance.toFixed(3)}`,
		`  src->preview mean=${fit.canonical_to_preview_mean.toFixed(3)} max=${fit.canonical_to_preview_max.toFixed(3)}`,
		`  preview->src mean=${fit.preview_to_canonical_mean.toFixed(3)} max=${fit.preview_to_canonical_max.toFixed(3)}`,
		`  thickness-aware match=${fit.thickness_aware.match_percent.toFixed(2)}% mean=${fit.thickness_aware.symmetric_mean_distance.toFixed(3)} tol=${fit.thickness_aware.tolerance}`,
		`  bounds=${fit.bounds.minX},${fit.bounds.minY} -> ${fit.bounds.maxX},${fit.bounds.maxY}`,
	];
}

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

	const analysis = analyzeTrackMinimap(track);
	const result = {
		track: analysis.track,
		canonical_to_preview: analysis.canonical.preview_space,
		derived_to_preview: analysis.derived_path_preview_space,
		preview_metrics: analysis.metrics,
	};

	if (args.flags['--json']) {
		process.stdout.write(JSON.stringify(result, null, 2) + '\n');
		return;
	}

	info(`${analysis.track.name} (${analysis.track.slug})`);
	for (const line of formatFit('canonical->preview', analysis.canonical.preview_space)) info(line);
	for (const line of formatFit('derived->preview', analysis.derived_path_preview_space)) info(line);
	info(`preview occupancy fit: transform=${analysis.metrics.transform} match=${analysis.metrics.match_percent.toFixed(2)}% mean=${analysis.metrics.symmetric_mean_distance.toFixed(3)}`);
}

main();
