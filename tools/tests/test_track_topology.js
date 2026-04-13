#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	countProperSelfIntersections,
	listSelfIntersections,
} = require('../randomizer/track_geometry');
const { buildMapFirstCanvas } = require('../lib/minimap_layout');
const { buildSimpleCycleFromPoints, clampSmoothLoop, injectSingleGradeSeparatedCrossing } = require('../randomizer/map_first_generator');
const {
	getTrackGeometryFixture,
	listTrackGeometryFixtureNames,
} = require('./track_geometry_fixtures');

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

console.log('Section A: track topology fixtures');

test('fixture catalog is stable and explicit', () => {
	assert.deepStrictEqual(listTrackGeometryFixtureNames(), [
		'square_loop',
		'rectangle_loop',
		'single_crossing_bow_tie',
		'shared_endpoint_touch',
		'near_miss_loop',
		'multiple_crossing_star',
	]);
});

test('no-crossing loop fixture reports zero true crossings', () => {
	const fixture = getTrackGeometryFixture('rectangle_loop');
	assert.strictEqual(countProperSelfIntersections(fixture.points), fixture.expectedProperCrossings);
});

test('single-crossing bow-tie fixture reports one true crossing', () => {
	const fixture = getTrackGeometryFixture('single_crossing_bow_tie');
	const intersections = listSelfIntersections(fixture.points, { includeEndpointTouches: false });
	assert.strictEqual(intersections.length, fixture.expectedProperCrossings);
	assert.ok(Math.abs(intersections[0].point[0] - 3) < 1e-6);
	assert.ok(Math.abs(intersections[0].point[1] - 3) < 1e-6);
});

test('multiple-crossing star fixture reports several true crossings', () => {
	const fixture = getTrackGeometryFixture('multiple_crossing_star');
	const properCrossings = countProperSelfIntersections(fixture.points);
	assert.ok(properCrossings >= fixture.minProperCrossings,
		`expected at least ${fixture.minProperCrossings} crossings, got ${properCrossings}`);
});

test('shared-endpoint fixture records a touch without counting a true crossing', () => {
	const fixture = getTrackGeometryFixture('shared_endpoint_touch');
	const allIntersections = listSelfIntersections(fixture.points);
	const properIntersections = listSelfIntersections(fixture.points, { includeEndpointTouches: false });
	assert.strictEqual(properIntersections.length, fixture.expectedProperCrossings);
	assert.ok(allIntersections.some(intersection => intersection.sharedEndpoint), 'expected at least one shared-endpoint touch');
});

test('near-miss fixture stays intersection-free', () => {
	const fixture = getTrackGeometryFixture('near_miss_loop');
	assert.strictEqual(listSelfIntersections(fixture.points).length, 0);
	assert.strictEqual(countProperSelfIntersections(fixture.points), fixture.expectedProperCrossings);
});

test('topology helpers are deterministic on repeated replay', () => {
	const fixture = getTrackGeometryFixture('multiple_crossing_star');
	const a = listSelfIntersections(fixture.points, { includeEndpointTouches: false });
	const b = listSelfIntersections(fixture.points, { includeEndpointTouches: false });
	assert.deepStrictEqual(a, b);
});

test('map-first simple cycle builder produces a zero-crossing loop for spaced samples', () => {
	const points = [[2, 2], [8, 2], [8, 8], [2, 8], [5, 3], [6, 5], [5, 7], [3, 5]];
	const result = buildSimpleCycleFromPoints(points);
	assert.strictEqual(result.success, true);
	assert.strictEqual(countProperSelfIntersections(result.loop_points), 0);
});

test('map-first clamp smoothing preserves zero-crossing topology', () => {
	const canvas = buildMapFirstCanvas();
	const loop = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const result = clampSmoothLoop(loop, canvas, { passes: 3 });
	assert.strictEqual(result.success, true);
	assert.strictEqual(countProperSelfIntersections(result.smoothed_points), 0);
});

test('map-first clamp smoothing preserves a single approved crossing when allowed', () => {
	const canvas = buildMapFirstCanvas();
	const baseLoop = [[10, 10], [30, 10], [40, 24], [30, 38], [10, 38], [0, 24]];
	const crossed = injectSingleGradeSeparatedCrossing(baseLoop);
	assert.strictEqual(crossed.success, true);
	const result = clampSmoothLoop(crossed.loop_points, canvas, { passes: 2, allowedProperCrossings: 1 });
	assert.strictEqual(result.success, true);
	assert.ok(countProperSelfIntersections(result.smoothed_points) <= 1);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
