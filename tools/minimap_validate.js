#!/usr/bin/env node
'use strict';

const { parseArgs, die, info } = require('./lib/cli');
const {
	loadTracksData,
	findTrack,
	resolvePreviewSlug,
	buildDerivedPath,
	fitPathToTarget,
	densifyPolyline,
	dedupeAdjacentPairs,
	getBounds,
	sampleClosedPath,
	averageNearestDistanceWithTolerance,
	getPreviewOccupiedPoints,
	getOccupiedPointsFromPixels,
	evaluateMarkerAlignment,
	generateMinimapPairsFromTrack,
} = require('./lib/minimap_analysis');
const { getMinimapPreview } = require('./lib/minimap_preview');
const { buildGeneratedMinimapPreview } = require('./lib/minimap_render');

function getOccupiedPoints(preview) {
	const points = [];
	for (let y = 0; y < preview.height; y++) {
		for (let x = 0; x < preview.width; x++) {
			if (preview.pixels[(y * preview.width) + x]) points.push([x, y]);
		}
	}
	return points;
}

function polygonArea(points) {
	if (!Array.isArray(points) || points.length < 3) return 0;
	let area = 0;
	for (let i = 0; i < points.length; i++) {
		const a = points[i];
		const b = points[(i + 1) % points.length];
		area += (a[0] * b[1]) - (b[0] * a[1]);
	}
	return Math.abs(area) / 2;
}

function countTightTurns(points) {
	if (!Array.isArray(points) || points.length < 3) return 0;
	let count = 0;
	for (let i = 0; i < points.length; i++) {
		const prev = points[(i - 1 + points.length) % points.length];
		const cur = points[i];
		const next = points[(i + 1) % points.length];
		const ax = cur[0] - prev[0];
		const ay = cur[1] - prev[1];
		const bx = next[0] - cur[0];
		const by = next[1] - cur[1];
		const aLen = Math.hypot(ax, ay);
		const bLen = Math.hypot(bx, by);
		if (aLen < 0.001 || bLen < 0.001) continue;
		const dot = ((ax * bx) + (ay * by)) / (aLen * bLen);
		if (dot < -0.25) count += 1;
	}
	return count;
}

function roundPair(point) {
	return [Math.round(point[0]), Math.round(point[1])];
}

function buildPreviewSpaceSamples(track, previewPoints, sampleCount) {
	const canonicalPairs = dedupeAdjacentPairs(track.minimap_pos || []);
	const canonicalPolyline = densifyPolyline(canonicalPairs);
	const fit = fitPathToTarget(canonicalPolyline, previewPoints);
	const sampled = sampleClosedPath(fit.transformedSourcePoints, sampleCount);
	return sampled.map(roundPair);
}

function buildPreviewSpaceSamplesFromPairs(pairs, previewPoints, sampleCount) {
	const canonicalPairs = dedupeAdjacentPairs(pairs || []);
	const canonicalPolyline = densifyPolyline(canonicalPairs);
	const fit = fitPathToTarget(canonicalPolyline, previewPoints);
	const sampled = sampleClosedPath(fit.transformedSourcePoints, sampleCount);
	return sampled.map(roundPair);
}

function collectAlignmentMetrics(track, mode = 'stock') {
	const previewSlug = resolvePreviewSlug(track);
	const preview = mode === 'generated'
		? buildGeneratedMinimapPreview(track)
		: getMinimapPreview(previewSlug);
	const previewPoints = mode === 'generated'
		? getOccupiedPointsFromPixels(preview.road_pixels || preview.pixels, preview.width, preview.height)
		: getPreviewOccupiedPoints(preview);
	const sampleCount = Array.isArray(track.minimap_pos) && track.minimap_pos.length > 0
		? track.minimap_pos.length
		: Math.max(1, track.track_length >> 6);
	const samplePoints = buildPreviewSpaceSamples(track, previewPoints, sampleCount);
	const centerlinePoints = mode === 'generated'
		? preview.centerline_points || []
		: samplePoints;
	const alignment = evaluateMarkerAlignment(samplePoints, previewPoints, centerlinePoints, mode === 'generated'
		? { roadTolerance: 0.6, roadHitThreshold: 0.6, centerlineHitThreshold: 1.75 }
		: { roadTolerance: 0.6, roadHitThreshold: 0.6, centerlineHitThreshold: 0.75 });

	return {
		preview_slug: previewSlug,
		preview,
		sample_points: samplePoints,
		alignment,
	};
}

function collectCandidateAlignmentMetrics(track) {
	const preview = buildGeneratedMinimapPreview(track);
	const roadPoints = getOccupiedPointsFromPixels(preview.road_pixels || preview.pixels, preview.width, preview.height);
	const generated = generateMinimapPairsFromTrack(track);
	const samplePoints = generated.pairs.map(roundPair);
	const alignment = evaluateMarkerAlignment(samplePoints, roadPoints, preview.centerline_points || [], {
		roadTolerance: 1.5,
		roadHitThreshold: 1.5,
		centerlineHitThreshold: 1.75,
	});

	return {
		preview,
		generated,
		sample_points: samplePoints,
		alignment,
	};
}

function validateTrack(track, tracksData) {
	const preview = buildGeneratedMinimapPreview(track);
	const occupied = getOccupiedPoints(preview);
	const generatedPairs = Array.isArray(track.minimap_pos) ? track.minimap_pos : [];
	const derivedPath = buildDerivedPath(track);
	const canonicalFit = fitPathToTarget(densifyPolyline(derivedPath.points || []), densifyPolyline(dedupeAdjacentPairs(generatedPairs)));
	const sampled = sampleClosedPath(canonicalFit.transformedSourcePoints, generatedPairs.length || Math.max(1, (track.track_length || 0) >> 6));
	const pairFit = averageNearestDistanceWithTolerance(sampled, generatedPairs, 1.5);
	const bounds = getBounds(occupied);
	const occupiedRatio = occupied.length / Math.max(1, preview.width * preview.height);
	const area = polygonArea(dedupeAdjacentPairs(generatedPairs));
	const tightTurns = countTightTurns(dedupeAdjacentPairs(generatedPairs));
	const aspect = bounds.height / Math.max(1, bounds.width);
	const widthProxy = occupied.length / Math.max(1, generatedPairs.length);
	const stockAlignment = collectAlignmentMetrics(track, 'stock');
	const generatedAlignment = collectAlignmentMetrics(track, 'generated');
	const candidateAlignment = collectCandidateAlignmentMetrics(track);

	return {
		track: { slug: track.slug, name: track.name, track_length: track.track_length },
		metrics: {
			preview_match_percent: preview.match_percent,
			occupied_ratio: Number(occupiedRatio.toFixed(4)),
			preview_bounds: bounds,
			preview_aspect_ratio: Number(aspect.toFixed(3)),
			width_proxy: Number(widthProxy.toFixed(3)),
			generated_pair_area: Number(area.toFixed(2)),
			pair_follow_mean: Number(pairFit.mean.toFixed(3)),
			pair_follow_max: Number(pairFit.max.toFixed(3)),
			tight_turn_count: tightTurns,
			stock_marker_mean_distance: stockAlignment.alignment.road.mean_distance,
			stock_marker_max_distance: stockAlignment.alignment.road.max_distance,
			stock_marker_hit_percent: stockAlignment.alignment.road.hit_percent,
			generated_marker_mean_distance: generatedAlignment.alignment.road.mean_distance,
			generated_marker_max_distance: generatedAlignment.alignment.road.max_distance,
			generated_marker_hit_percent: generatedAlignment.alignment.road.hit_percent,
			candidate_marker_mean_distance: candidateAlignment.alignment.road.mean_distance,
			candidate_marker_max_distance: candidateAlignment.alignment.road.max_distance,
			candidate_marker_hit_percent: candidateAlignment.alignment.road.hit_percent,
		},
		alignment: {
			stock: stockAlignment.alignment,
			generated: generatedAlignment.alignment,
			candidate: candidateAlignment.alignment,
			candidate_pairs: candidateAlignment.generated.pairs,
		},
		flags: {
			too_sparse: occupiedRatio < 0.08,
			too_dense: occupiedRatio > 0.55,
			too_tall: aspect > 3.2,
			too_wide: aspect < 0.32,
			too_thin: widthProxy < 3.6,
			too_fat: widthProxy > 9.5,
			pair_desync: pairFit.mean > 4,
			generated_marker_offroad: generatedAlignment.alignment.road.mean_distance > 1.25 || generatedAlignment.alignment.road.hit_percent < 90,
			candidate_marker_offroad: candidateAlignment.alignment.road.mean_distance > 1.25 || candidateAlignment.alignment.road.hit_percent < 90,
			many_tight_turns: tightTurns > Math.max(6, Math.floor(generatedPairs.length / 12)),
		},
	};
}

function average(entries, select) {
	if (!entries.length) return 0;
	return entries.reduce((sum, entry) => sum + select(entry), 0) / entries.length;
}

function validateAllTracks(tracksData) {
	const tracks = Array.isArray(tracksData?.tracks) ? tracksData.tracks : [];
	const reports = tracks.map(track => validateTrack(track, tracksData));
	return {
		track_count: reports.length,
		stock_marker_mean_distance: Number(average(reports, report => report.metrics.stock_marker_mean_distance).toFixed(3)),
		stock_marker_hit_percent: Number(average(reports, report => report.metrics.stock_marker_hit_percent).toFixed(2)),
		generated_marker_mean_distance: Number(average(reports, report => report.metrics.generated_marker_mean_distance).toFixed(3)),
		generated_marker_hit_percent: Number(average(reports, report => report.metrics.generated_marker_hit_percent).toFixed(2)),
		candidate_marker_mean_distance: Number(average(reports, report => report.metrics.candidate_marker_mean_distance).toFixed(3)),
		candidate_marker_hit_percent: Number(average(reports, report => report.metrics.candidate_marker_hit_percent).toFixed(2)),
		generated_marker_offroad_count: reports.filter(report => report.flags.generated_marker_offroad).length,
		candidate_marker_offroad_count: reports.filter(report => report.flags.candidate_marker_offroad).length,
		tracks: reports,
	};
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--json', '--all'],
		options: ['--track', '--input'],
	});
	const input = args.options['--input'];
	const trackArg = args.options['--track'];
	const tracksData = loadTracksData(input);
	const report = args.flags['--all']
		? validateAllTracks(tracksData)
		: (() => {
			if (!trackArg) die('missing required option: --track');
			const track = findTrack(trackArg, tracksData);
			if (!track) die(`track not found: ${trackArg}`);
			return validateTrack(track, tracksData);
		})();

	if (args.flags['--json']) {
		process.stdout.write(JSON.stringify(report, null, 2) + '\n');
		return;
	}

	if (args.flags['--all']) {
		info(`tracks: ${report.track_count}`);
		info(`stock marker mean distance: ${report.stock_marker_mean_distance}`);
		info(`stock marker hit percent: ${report.stock_marker_hit_percent}`);
		info(`generated marker mean distance: ${report.generated_marker_mean_distance}`);
		info(`generated marker hit percent: ${report.generated_marker_hit_percent}`);
		info(`candidate marker mean distance: ${report.candidate_marker_mean_distance}`);
		info(`candidate marker hit percent: ${report.candidate_marker_hit_percent}`);
		info(`generated offroad tracks: ${report.generated_marker_offroad_count}`);
		info(`candidate offroad tracks: ${report.candidate_marker_offroad_count}`);
		return;
	}

	info(`${report.track.name} (${report.track.slug})`);
	for (const [key, value] of Object.entries(report.metrics)) {
		info(`${key}: ${typeof value === 'object' ? JSON.stringify(value) : value}`);
	}
	const activeFlags = Object.entries(report.flags).filter(([, value]) => value).map(([key]) => key);
	info(`flags: ${activeFlags.length ? activeFlags.join(', ') : 'none'}`);
}

if (require.main === module) {
	main();
}

module.exports = {
	validateTrack,
	validateAllTracks,
};
