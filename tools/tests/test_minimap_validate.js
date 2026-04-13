#!/usr/bin/env node
'use strict';

const assert = require('assert');
const { loadTracksData, findTrack } = require('../lib/minimap_analysis');
const {
	anticlockwiseRectangleLoop,
	previewSpaceRectangle,
	rectangleLoop,
	repeatedRightCurveTrack,
	simpleLeftCurveTrack,
	simpleRightCurveTrack,
	zigzagLoop,
} = require('./minimap_synthetic_fixtures');

const {
	buildCenterlineTurnProfile,
	buildCurveTurnProfile,
	buildFlagsFromMetrics,
	buildPreviewSpaceSamplesFromPairs,
	countTightTurns,
	evaluateCurveMapAgreement,
	findBestCircularShift,
	normalizeAngleDelta,
	pearsonCorrelation,
	polygonArea,
	rotateArray,
	validateTrack,
} = require('../minimap_validate');

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed++;
	} catch (err) {
		failed++;
		console.error(`FAIL: ${name}`);
		console.error(`  ${err.message}`);
	}
}

console.log('Section A: minimap validation helpers');

test('polygonArea returns square area', () => {
	assert.strictEqual(polygonArea(rectangleLoop()), 16);
});

test('countTightTurns detects sharper loop than rectangle', () => {
	const rectangle = rectangleLoop();
	const zigzag = zigzagLoop();
	assert.ok(countTightTurns(zigzag) > countTightTurns(rectangle));
});

test('normalizeAngleDelta wraps angles into signed PI range', () => {
	const value = normalizeAngleDelta((Math.PI * 3) / 2);
	assert.ok(value >= -Math.PI && value <= Math.PI);
	assert.ok(value < 0);
});

test('rotateArray and circular shift preserve strongest correlation', () => {
	const expected = [1, 0, -1, 0];
	const observed = [0, -1, 0, 1];
	const best = findBestCircularShift(expected, observed);
	assert.strictEqual(best.shift, 3);
	assert.ok(pearsonCorrelation(expected, rotateArray(observed, best.shift)) > 0.99);
});

test('buildPreviewSpaceSamplesFromPairs returns requested sample count', () => {
	const pairs = rectangleLoop().map(([x, y]) => [x * 1.5, y * 1.5]);
	const previewPoints = previewSpaceRectangle();
	const samples = buildPreviewSpaceSamplesFromPairs(pairs, previewPoints, 8);
	assert.strictEqual(samples.length, 8);
	assert.ok(samples.every(point => Number.isInteger(point[0]) && Number.isInteger(point[1])));
});

test('buildCurveTurnProfile distinguishes left and right turns', () => {
	const leftTrack = simpleLeftCurveTrack();
	const rightTrack = simpleRightCurveTrack();
	const left = buildCurveTurnProfile(leftTrack, 8);
	const right = buildCurveTurnProfile(rightTrack, 8);
	assert.ok(left.some(value => value < 0));
	assert.ok(right.some(value => value > 0));
});

test('buildCenterlineTurnProfile distinguishes path direction', () => {
	const clockwise = rectangleLoop();
	const anticlockwise = anticlockwiseRectangleLoop();
	const a = buildCenterlineTurnProfile(clockwise, 8);
	const b = buildCenterlineTurnProfile(anticlockwise, 8);
	assert.notDeepStrictEqual(a, b);
	assert.ok(a.some(value => value < 0 || value > 0));
});

test('evaluateCurveMapAgreement distinguishes turn direction', () => {
	const track = repeatedRightCurveTrack();
	const clockwise = { centerline_points: rectangleLoop() };
	const anticlockwise = { centerline_points: anticlockwiseRectangleLoop() };
	const good = evaluateCurveMapAgreement(track, clockwise);
	const bad = evaluateCurveMapAgreement(track, anticlockwise);
	assert.ok(good.sign_match_percent > bad.sign_match_percent);
});

test('buildFlagsFromMetrics covers major threshold branches', () => {
	const flags = buildFlagsFromMetrics({
		occupied_ratio: 0.03,
		preview_aspect_ratio: 4,
		width_proxy: 10,
		pair_follow_mean: 5,
		generated_marker_mean_distance: 2,
		generated_marker_hit_percent: 80,
		candidate_marker_mean_distance: 2,
		candidate_marker_hit_percent: 80,
		curve_map_sign_match_percent: 40,
		curve_map_best_shift_ratio: 0.2,
		curve_map_phase_gain: 0.2,
		curve_map_strength_error: 0.02,
		tight_turn_count: 10,
	}, 24);
	assert.strictEqual(flags.too_sparse, true);
	assert.strictEqual(flags.too_tall, true);
	assert.strictEqual(flags.too_fat, true);
	assert.strictEqual(flags.pair_desync, true);
	assert.strictEqual(flags.generated_marker_offroad, true);
	assert.strictEqual(flags.candidate_marker_offroad, true);
	assert.strictEqual(flags.curve_map_left_right_mismatch, true);
	assert.strictEqual(flags.curve_map_phase_mismatch, true);
	assert.strictEqual(flags.curve_map_strength_mismatch, true);
	assert.strictEqual(flags.many_tight_turns, true);
});

test('validateTrack returns normalized report entry shape', () => {
	const tracksData = loadTracksData();
	const track = findTrack('san_marino', tracksData);
	const report = validateTrack(track, tracksData);
	assert.strictEqual(report.track.slug, 'san_marino');
	assert.ok(typeof report.track.track_length === 'number');
	assert.ok(typeof report.metrics.preview_match_percent === 'number');
	assert.ok(Array.isArray(report.alignment.candidate_pairs));
	assert.ok(Object.prototype.hasOwnProperty.call(report.alignment, 'stock'));
	assert.ok(Object.prototype.hasOwnProperty.call(report.alignment, 'generated'));
	assert.ok(Object.prototype.hasOwnProperty.call(report.alignment, 'candidate'));
	assert.ok(Object.prototype.hasOwnProperty.call(report.alignment.generated.road, 'hit_percent'));
	assert.ok(report.topology && typeof report.topology.crossing_count === 'number');
	assert.ok(report.flags && typeof report.flags === 'object');
});

test('validateTrack surfaces topology summary from transient geometry state', () => {
	const track = repeatedRightCurveTrack();
	track.name = 'San Marino';
	track.slug = 'san_marino';
	track.index = 0;
	track.minimap_pos = [[0, 0], [0, 0], [0, 0], [0, 0]];
	track._generated_geometry_state = {
		resampled_centerline: [[0, 0], [6, 6], [0, 6], [6, 0]],
	};
	const report = validateTrack(track, { tracks: [track] });
	assert.strictEqual(report.topology.proper_crossing_count, 1);
	assert.strictEqual(report.topology.eligible_for_single_crossing_rule, true);
});

test('validateTrack surfaces crossing classification fields when a crossing is approved', () => {
	const track = repeatedRightCurveTrack();
	track.name = 'San Marino';
	track.slug = 'san_marino';
	track.index = 0;
	track.minimap_pos = [[0, 0], [0, 0], [0, 0], [0, 0]];
	track._generated_geometry_state = {
		resampled_centerline: [[0, 0], [6, 6], [0, 6], [6, 0]],
		topology: {
			single_grade_separated_crossing: {
				grade_separated: true,
				lower_branch: { start_index: 1, end_index: 2 },
				upper_branch: { start_index: 3, end_index: 0 },
			},
		},
		projections: {
			slope: {
				grade_separated_crossing: {
					separation_ok: true,
					lower_branch: { tunnel_required: true, branch_height: -1 },
					upper_branch: { branch_height: 0 },
				},
			},
		},
	};
	const report = validateTrack(track, { tracks: [track] });
	assert.strictEqual(report.topology.crossing_approved, true);
	assert.strictEqual(report.topology.crossing_classification, 'single_grade_separated_crossing');
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
