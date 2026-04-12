'use strict';

const path = require('path');

const { readJson } = require('../lib/json');
const { REPO_ROOT } = require('../lib/rom');
const { validateAllTracks } = require('../minimap_validate');
const { getTracks } = require('../randomizer/track_model');
const { parseSeed, randomizeTracks } = require('../randomizer/track_randomizer');

const DEFAULT_VALIDATION_SNAPSHOT_SEEDS = ['SMGP-1-01-42', 'SMGP-1-01-12345', 'SMGP-1-01-99999'];
const DEFAULT_VALIDATION_SNAPSHOT_TRACKS = ['san_marino', 'brazil', 'monaco'];
const TRACKS_JSON_PATH = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');

function deepCopy(value) {
	return JSON.parse(JSON.stringify(value));
}

function round(value, digits) {
	return Number(Number(value || 0).toFixed(digits));
}

function pickAggregateSnapshot(report) {
	return {
		track_count: report.track_count,
		stock_marker_mean_distance: round(report.stock_marker_mean_distance, 3),
		stock_marker_hit_percent: round(report.stock_marker_hit_percent, 2),
		generated_marker_mean_distance: round(report.generated_marker_mean_distance, 3),
		generated_marker_hit_percent: round(report.generated_marker_hit_percent, 2),
		candidate_marker_mean_distance: round(report.candidate_marker_mean_distance, 3),
		candidate_marker_hit_percent: round(report.candidate_marker_hit_percent, 2),
		preview_self_intersections: round(report.preview_self_intersections, 2),
		preview_branch_pixel_count: round(report.preview_branch_pixel_count, 2),
		curve_map_sign_match_percent: round(report.curve_map_sign_match_percent, 2),
		curve_map_strength_error: round(report.curve_map_strength_error, 4),
		generated_marker_offroad_count: report.generated_marker_offroad_count,
		candidate_marker_offroad_count: report.candidate_marker_offroad_count,
		curve_map_left_right_mismatch_count: report.curve_map_left_right_mismatch_count,
		curve_map_phase_mismatch_count: report.curve_map_phase_mismatch_count,
		curve_map_strength_mismatch_count: report.curve_map_strength_mismatch_count,
	};
}

function summarizeTrackValidation(report) {
	const activeFlags = Object.entries(report.flags)
		.filter(([, enabled]) => enabled)
		.map(([flag]) => flag)
		.sort();
	return {
		preview_match_percent: round(report.metrics.preview_match_percent, 2),
		generated_marker_mean_distance: round(report.metrics.generated_marker_mean_distance, 3),
		generated_marker_hit_percent: round(report.metrics.generated_marker_hit_percent, 2),
		candidate_marker_mean_distance: round(report.metrics.candidate_marker_mean_distance, 3),
		candidate_marker_hit_percent: round(report.metrics.candidate_marker_hit_percent, 2),
		curve_map_sign_match_percent: round(report.metrics.curve_map_sign_match_percent, 2),
		curve_map_best_shift_ratio: round(report.metrics.curve_map_best_shift_ratio, 4),
		preview_self_intersections: report.metrics.preview_self_intersections,
		preview_branch_pixel_count: report.metrics.preview_branch_pixel_count,
		active_flags: activeFlags,
	};
}

function buildValidationSnapshot(seedString, trackSlugs = DEFAULT_VALIDATION_SNAPSHOT_TRACKS) {
	const tracksData = deepCopy(readJson(TRACKS_JSON_PATH));
	const [, , masterSeed] = parseSeed(seedString);
	randomizeTracks(tracksData, masterSeed, null, false);
	const report = validateAllTracks(tracksData);
	const reportBySlug = new Map(report.tracks.map(entry => [entry.track.slug, entry]));
	const tracks = {};
	for (const slug of trackSlugs) {
		const trackReport = reportBySlug.get(slug);
		if (!trackReport) throw new Error(`Unknown validation snapshot track slug: ${slug}`);
		tracks[slug] = summarizeTrackValidation(trackReport);
	}
	return {
		aggregate: pickAggregateSnapshot(report),
		tracks,
	};
}

function buildValidationSnapshotFixture(seedStrings = DEFAULT_VALIDATION_SNAPSHOT_SEEDS, trackSlugs = DEFAULT_VALIDATION_SNAPSHOT_TRACKS) {
	const seeds = {};
	for (const seedString of seedStrings) {
		seeds[seedString] = buildValidationSnapshot(seedString, trackSlugs);
	}
	return {
		schema_version: 1,
		tracks: trackSlugs.slice(),
		seeds,
	};
}

module.exports = {
	DEFAULT_VALIDATION_SNAPSHOT_SEEDS,
	DEFAULT_VALIDATION_SNAPSHOT_TRACKS,
	buildValidationSnapshot,
	buildValidationSnapshotFixture,
};
