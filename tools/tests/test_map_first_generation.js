#!/usr/bin/env node
'use strict';

const assert = require('assert');

const { buildMapFirstCanvas } = require('../lib/minimap_layout');
const {
	buildConvexHull,
	buildMapFirstGeometryState,
	buildResampledCenterline,
	buildSimpleCycleFromPoints,
	buildSamplingBounds,
	injectSingleGradeSeparatedCrossing,
	summarizeLoopTopology,
	buildTrackSlotSeed,
	CROSSING_SELECTION_ODDS,
	clampSmoothLoop,
	evaluateCrossingEligibility,
	generateMapSamplePointsForTrack,
	measureStartVerticality,
	pathFitsCanvas,
	resolveResamplingConfig,
	resolvePointSamplingConfig,
} = require('../randomizer/map_first_generator');
const { countProperSelfIntersections } = require('../randomizer/track_geometry');

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

function minDistance(points) {
	let best = Infinity;
	for (let i = 0; i < points.length; i++) {
		for (let j = i + 1; j < points.length; j++) {
			const dx = points[i][0] - points[j][0];
			const dy = points[i][1] - points[j][1];
			best = Math.min(best, Math.hypot(dx, dy));
		}
	}
	return best;
}

console.log('Section A: map-first generation');

test('resolvePointSamplingConfig scales target density with canvas area', () => {
	const small = resolvePointSamplingConfig({ width: 40, height: 40, x_min: 0, y_min: 0, x_max: 39, y_max: 39 }, {});
	const large = resolvePointSamplingConfig({ width: 80, height: 80, x_min: 0, y_min: 0, x_max: 79, y_max: 79 }, {});
	assert.ok(large.targetPointCount > small.targetPointCount);
	assert.ok(large.minimumSpacingPx >= 4);
	assert.ok(large.edgeMarginPx >= 0);
});

test('buildSamplingBounds respects inner edge margins', () => {
	const canvas = buildMapFirstCanvas();
	const config = resolvePointSamplingConfig(canvas, { edgeMarginPx: 5 });
	const bounds = buildSamplingBounds(canvas, config);
	assert.strictEqual(bounds.xMin, canvas.x_min + 5);
	assert.strictEqual(bounds.yMin, canvas.y_min + 5);
	assert.strictEqual(bounds.xMax, canvas.x_max - 5);
	assert.strictEqual(bounds.yMax, canvas.y_max - 5);
});

test('generateMapSamplePointsForTrack is deterministic for same seed and track slot', () => {
	const track = { index: 3 };
	const options = { pointSampling: { targetPointCount: 9, minimumSpacingPx: 8, edgeMarginPx: 4 } };
	const a = generateMapSamplePointsForTrack(track, 12345, options);
	const b = generateMapSamplePointsForTrack(track, 12345, options);
	assert.deepStrictEqual(a, b);
});

test('generateMapSamplePointsForTrack changes with track slot under same master seed', () => {
	const options = { pointSampling: { targetPointCount: 9, minimumSpacingPx: 8, edgeMarginPx: 4 } };
	const a = generateMapSamplePointsForTrack({ index: 0 }, 12345, options);
	const b = generateMapSamplePointsForTrack({ index: 1 }, 12345, options);
	assert.notDeepStrictEqual(a, b);
	assert.notStrictEqual(buildTrackSlotSeed(12345, 0), buildTrackSlotSeed(12345, 1));
});

test('generateMapSamplePointsForTrack respects spacing and edge bounds', () => {
	const canvas = buildMapFirstCanvas();
	const track = { index: 0 };
	const points = generateMapSamplePointsForTrack(track, 22222, {
		canvas,
		pointSampling: {
			targetPointCount: 8,
			minimumSpacingPx: 8,
			edgeMarginPx: 4,
		},
	});
	const bounds = buildSamplingBounds(canvas, resolvePointSamplingConfig(canvas, {
			targetPointCount: 8,
			minimumSpacingPx: 8,
			edgeMarginPx: 4,
	}));
	assert.strictEqual(points.length, 8);
	assert.ok(points.every(([x, y]) => x >= bounds.xMin && x <= bounds.xMax && y >= bounds.yMin && y <= bounds.yMax));
	assert.ok(minDistance(points) >= 8, `expected minimum spacing >= 8, got ${minDistance(points)}`);
});

test('buildMapFirstGeometryState returns the documented scaffold with sampled points', () => {
	const state = buildMapFirstGeometryState({ index: 2, track_length: 40 }, 54321, {
		pointSampling: { targetPointCount: 10, minimumSpacingPx: 7 },
	});
	assert.ok(state.canvas && typeof state.canvas.width === 'number');
	assert.strictEqual(state.sampled_points.length, 10);
	assert.strictEqual(state.loop_points.length, 10);
	assert.strictEqual(state.smoothed_centerline.length, 10);
	assert.strictEqual(state.resampled_centerline.length, 16);
	assert.strictEqual(state.topology.crossing_count, 0);
	assert.strictEqual(state.generation_diagnostics.selected_strategy !== null, true);
	assert.ok(state.generation_diagnostics.smoothing);
	assert.ok(state.generation_diagnostics.resampling);
	assert.strictEqual(state.projections.minimap_runtime, null);
	assert.strictEqual(state.projections.minimap_preview, null);
});

test('buildConvexHull keeps extreme boundary points in order', () => {
	const hull = buildConvexHull([[2, 2], [8, 2], [8, 8], [2, 8], [5, 5], [4, 6]]);
	assert.deepStrictEqual(hull, [[2, 2], [8, 2], [8, 8], [2, 8]]);
});

test('buildSimpleCycleFromPoints visits every point exactly once without crossings', () => {
	const points = [[2, 2], [8, 2], [8, 8], [2, 8], [5, 3], [6, 5], [5, 7], [3, 5]];
	const result = buildSimpleCycleFromPoints(points);
	assert.strictEqual(result.success, true);
	assert.strictEqual(result.loop_points.length, points.length);
	assert.strictEqual(new Set(result.loop_points.map(([x, y]) => `${x},${y}`)).size, points.length);
	assert.strictEqual(countProperSelfIntersections(result.loop_points), 0);
	assert.ok(result.diagnostics.attempt_count >= 1);
	assert.ok(result.diagnostics.selected_strategy);
});

test('buildSimpleCycleFromPoints is deterministic for repeated calls', () => {
	const points = [[2, 2], [8, 2], [8, 8], [2, 8], [5, 3], [6, 5], [5, 7], [3, 5]];
	const a = buildSimpleCycleFromPoints(points);
	const b = buildSimpleCycleFromPoints(points);
	assert.deepStrictEqual(a, b);
});

test('buildSimpleCycleFromPoints reports deterministic diagnostics for degenerate input', () => {
	const result = buildSimpleCycleFromPoints([[1, 1], [2, 2], [3, 3]]);
	assert.strictEqual(result.success, false);
	assert.strictEqual(result.loop_points.length, 0);
	assert.strictEqual(result.diagnostics.failure_reason, 'degenerate_hull');
	assert.strictEqual(result.diagnostics.attempt_count, 0);
});

test('clampSmoothLoop applies smoothing when the candidate remains valid', () => {
	const canvas = buildMapFirstCanvas();
	const loop = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const result = clampSmoothLoop(loop, canvas, { passes: 2 });
	assert.strictEqual(result.success, true);
	assert.strictEqual(result.diagnostics.applied_passes, 2);
	assert.strictEqual(result.diagnostics.used_fallback, false);
	assert.strictEqual(result.smoothed_points.length, loop.length);
	assert.deepStrictEqual(result.smoothed_points[0], loop[0]);
	assert.strictEqual(countProperSelfIntersections(result.smoothed_points), 0);
	assert.strictEqual(pathFitsCanvas(result.smoothed_points, canvas), true);
});

test('clampSmoothLoop falls back to fewer passes when start orientation tolerance is too strict', () => {
	const canvas = buildMapFirstCanvas();
	const loop = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const result = clampSmoothLoop(loop, canvas, { passes: 3, maxStartAngleDeltaDegrees: 5 });
	assert.strictEqual(result.success, true);
	assert.ok(result.diagnostics.applied_passes < 3);
	assert.strictEqual(result.diagnostics.used_fallback, true);
	assert.strictEqual(countProperSelfIntersections(result.smoothed_points), 0);
});

test('clampSmoothLoop preserves the original loop when no smoothing pass is allowed', () => {
	const canvas = buildMapFirstCanvas();
	const loop = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const result = clampSmoothLoop(loop, canvas, { passes: 0 });
	assert.strictEqual(result.success, true);
	assert.strictEqual(result.diagnostics.applied_passes, 0);
	assert.deepStrictEqual(result.smoothed_points, loop);
	assert.strictEqual(result.diagnostics.used_fallback, false);
});

test('buildMapFirstGeometryState stores smoothing diagnostics and smoothed centerline', () => {
	const state = buildMapFirstGeometryState({ index: 4, track_length: 4096 }, 12345, {
		pointSampling: { targetPointCount: 9, minimumSpacingPx: 8 },
		smoothing: { passes: 2 },
	});
	assert.strictEqual(state.loop_points.length, 9);
	assert.strictEqual(state.smoothed_centerline.length, 9);
	assert.strictEqual(state.resampled_centerline.length, 1024);
	assert.ok(state.generation_diagnostics.smoothing);
	assert.ok(state.generation_diagnostics.resampling);
	assert.strictEqual(typeof state.generation_diagnostics.smoothing.applied_passes, 'number');
	assert.strictEqual(countProperSelfIntersections(state.smoothed_centerline), 0);
	assert.strictEqual(countProperSelfIntersections(state.resampled_centerline), 0);
	assert.strictEqual(pathFitsCanvas(state.smoothed_centerline, state.canvas), true);
	assert.strictEqual(pathFitsCanvas(state.resampled_centerline, state.canvas), true);
});

test('resolveResamplingConfig defaults to track_length>>2 sample budget', () => {
	const config = resolveResamplingConfig({ track_length: 4096 }, {});
	assert.strictEqual(config.sampleCount, 1024);
});

test('buildResampledCenterline produces deterministic requested sample count', () => {
	const canvas = buildMapFirstCanvas();
	const loop = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const result = buildResampledCenterline({ track_length: 256 }, loop, canvas, { sampleCount: 32 });
	assert.strictEqual(result.success, true);
	assert.strictEqual(result.resampled_points.length, 32);
	assert.strictEqual(result.diagnostics.produced_sample_count, 32);
	assert.strictEqual(countProperSelfIntersections(result.resampled_points), 0);
	assert.strictEqual(pathFitsCanvas(result.resampled_points, canvas), true);
});

test('buildResampledCenterline preserves readable start-line orientation', () => {
	const canvas = buildMapFirstCanvas();
	const loop = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const result = buildResampledCenterline({ track_length: 256 }, loop, canvas, { sampleCount: 32 });
	assert.strictEqual(result.success, true);
	assert.ok(measureStartVerticality(result.resampled_points) >= 0.1);
	assert.ok(result.diagnostics.incoming_angle_delta <= 35);
	assert.ok(result.diagnostics.outgoing_angle_delta <= 35);
});

test('evaluateCrossingEligibility is deterministic for same seed and track slot', () => {
	const a = evaluateCrossingEligibility(12345, 7);
	const b = evaluateCrossingEligibility(12345, 7);
	assert.deepStrictEqual(a, b);
});

test('evaluateCrossingEligibility changes across track slots under same master seed', () => {
	const a = evaluateCrossingEligibility(12345, 0);
	const b = evaluateCrossingEligibility(12345, 1);
	assert.notStrictEqual(a.seed, b.seed);
	assert.notDeepStrictEqual(a, b);
});

test('buildMapFirstGeometryState records deterministic crossing selection diagnostics', () => {
	const state = buildMapFirstGeometryState({ index: 5, track_length: 4096 }, 12345, {
		pointSampling: { targetPointCount: 9, minimumSpacingPx: 8 },
	});
	assert.ok(state.generation_diagnostics.crossing_selection);
	assert.strictEqual(state.generation_diagnostics.crossing_selection.odds, CROSSING_SELECTION_ODDS);
	assert.strictEqual(state.topology.eligible_for_grade_separated_crossing, state.generation_diagnostics.crossing_selection.eligible);
});

test('injectSingleGradeSeparatedCrossing converts a simple loop into exactly one crossing', () => {
	const loop = [[0, 0], [6, 0], [8, 4], [6, 8], [0, 8], [-2, 4]];
	const result = injectSingleGradeSeparatedCrossing(loop);
	assert.strictEqual(result.success, true);
	const topology = summarizeLoopTopology(result.loop_points, { allowedProperCrossings: 1 });
	assert.strictEqual(topology.properCrossingCount, 1);
	assert.ok(topology.singleGradeSeparatedCrossing);
	assert.ok(result.diagnostics.selected_pair);
});

test('buildMapFirstGeometryState emits one approved crossing when crossing selection hits', () => {
	let chosenSeed = null;
	for (let seed = 1; seed < 5000; seed++) {
		if (evaluateCrossingEligibility(seed, 0).eligible) {
			chosenSeed = seed;
			break;
		}
	}
	assert.ok(chosenSeed !== null, 'expected at least one crossing-eligible seed');
	const state = buildMapFirstGeometryState({ index: 0, track_length: 4096 }, chosenSeed, {
		pointSampling: { targetPointCount: 9, minimumSpacingPx: 8 },
	});
	assert.strictEqual(state.generation_diagnostics.crossing_selection.eligible, true);
	assert.strictEqual(state.topology.proper_crossing_count, 1);
	assert.ok(state.topology.single_grade_separated_crossing);
	assert.ok(state.generation_diagnostics.crossing_injection.selected_pair);
	assert.strictEqual(countProperSelfIntersections(state.resampled_centerline), 1);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
