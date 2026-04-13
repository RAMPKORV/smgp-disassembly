'use strict';

const path = require('path');

const { buildGeneratedMinimapPreview } = require('../lib/minimap_render');
const { readJson } = require('../lib/json');
const { REPO_ROOT } = require('../lib/rom');
const { validateAllTracks } = require('../minimap_validate');
const { getTrackMinimapPairs, getTrackSignData, getTrackSignTileset } = require('../randomizer/track_model');
const { getGeneratedGeometryState } = require('../randomizer/track_metadata');
const { parseSeed, randomizeTracks } = require('../randomizer/track_randomizer');

const DEFAULT_BASELINE_SEEDS = ['SMGP-1-01-42', 'SMGP-1-01-12345'];
const DEFAULT_BASELINE_TRACKS = ['san_marino', 'brazil', 'portugal', 'monaco'];
const TRACKS_JSON_PATH = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');

function deepCopy(value) {
	return JSON.parse(JSON.stringify(value));
}

function round(value, digits) {
	return Number(value.toFixed(digits));
}

function countCurveSegments(track, type) {
	return (track.curve_rle_segments || []).filter(segment => segment && segment.type === type).length;
}

function getLongestStraightLength(track) {
	return (track.curve_rle_segments || [])
		.filter(segment => segment && segment.type === 'straight')
		.reduce((max, segment) => Math.max(max, segment.length || 0), 0);
}

function getUltraSharpCurveCount(track) {
	return (track.curve_rle_segments || [])
		.filter(segment => segment && segment.type === 'curve' && ((segment.curve_byte || 0) & 0x3F) <= 4)
		.length;
}

function sampleAnchorPairs(pairs, count = 6) {
	if (!Array.isArray(pairs) || pairs.length === 0) return [];
	if (pairs.length <= count) return pairs.map(([a, b]) => [a, b]);
	const lastIndex = pairs.length - 1;
	const result = [];
	for (let i = 0; i < count; i++) {
		const index = Math.min(lastIndex, Math.round((i * lastIndex) / Math.max(1, count - 1)));
		const pair = pairs[index] || [0, 0];
		result.push([pair[0], pair[1]]);
	}
	return result;
}

function pickAggregateFields(report) {
	return {
		track_count: report.track_count,
		candidate_marker_mean_distance: report.candidate_marker_mean_distance,
		candidate_marker_hit_percent: report.candidate_marker_hit_percent,
		preview_self_intersections: report.preview_self_intersections,
		preview_branch_pixel_count: report.preview_branch_pixel_count,
		curve_map_sign_match_percent: report.curve_map_sign_match_percent,
		curve_map_strength_error: report.curve_map_strength_error,
		generated_marker_offroad_count: report.generated_marker_offroad_count,
		candidate_marker_offroad_count: report.candidate_marker_offroad_count,
		curve_map_left_right_mismatch_count: report.curve_map_left_right_mismatch_count,
		curve_map_phase_mismatch_count: report.curve_map_phase_mismatch_count,
		curve_map_strength_mismatch_count: report.curve_map_strength_mismatch_count,
	};
}

function summarizeTrack(track, reportBySlug) {
	const report = reportBySlug.get(track.slug);
	const preview = buildGeneratedMinimapPreview(track);
	const geometryState = getGeneratedGeometryState(track);
	const activeFlags = Object.entries(report.flags)
		.filter(([, enabled]) => enabled)
		.map(([flag]) => flag)
		.sort();
	return {
		track_length: track.track_length,
		curve_count: countCurveSegments(track, 'curve'),
		straight_count: countCurveSegments(track, 'straight'),
		longest_straight_length: getLongestStraightLength(track),
		ultra_sharp_curve_count: getUltraSharpCurveCount(track),
		sign_data_count: getTrackSignData(track).length,
		sign_tileset_count: getTrackSignTileset(track).length,
		minimap_pos_count: getTrackMinimapPairs(track).length,
		preview_transform: preview.transform,
		preview_tile_count: preview.tile_count,
		preview_self_intersections: preview.self_intersections,
		preview_branch_pixel_count: preview.branch_pixel_count,
		geometry_resampled_count: Array.isArray(geometryState?.resampled_centerline) ? geometryState.resampled_centerline.length : 0,
		geometry_crossing_count: geometryState?.topology?.crossing_count || 0,
		candidate_marker_mean_distance: round(report.metrics.candidate_marker_mean_distance, 3),
		candidate_marker_hit_percent: round(report.metrics.candidate_marker_hit_percent, 2),
		curve_map_sign_match_percent: round(report.metrics.curve_map_sign_match_percent, 2),
		active_flags: activeFlags,
		minimap_anchor_pairs: sampleAnchorPairs(track.minimap_pos, 6),
	};
}

function buildSeedSummary(seedString, trackSlugs = DEFAULT_BASELINE_TRACKS) {
	const tracksData = deepCopy(readJson(TRACKS_JSON_PATH));
	const [, , masterSeed] = parseSeed(seedString);
	randomizeTracks(tracksData, masterSeed, null, false);
	const report = validateAllTracks(tracksData);
	const reportBySlug = new Map(report.tracks.map(entry => [entry.track.slug, entry]));
	const selectedTracks = {};
	for (const slug of trackSlugs) {
		const track = tracksData.tracks.find(entry => entry.slug === slug);
		if (!track) throw new Error(`Unknown baseline track slug: ${slug}`);
		selectedTracks[slug] = summarizeTrack(track, reportBySlug);
	}
	return {
		aggregate: pickAggregateFields(report),
		tracks: selectedTracks,
	};
}

function buildBaselineSummary(seedStrings = DEFAULT_BASELINE_SEEDS, trackSlugs = DEFAULT_BASELINE_TRACKS) {
	const seeds = {};
	for (const seedString of seedStrings) {
		seeds[seedString] = buildSeedSummary(seedString, trackSlugs);
	}
	return {
		schema_version: 1,
		seeds,
	};
}

module.exports = {
	DEFAULT_BASELINE_SEEDS,
	DEFAULT_BASELINE_TRACKS,
	buildBaselineSummary,
	buildSeedSummary,
};
