#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	buildClosedPathSegments,
	countProperSelfIntersections,
	getPathLength,
	isClosedLoop,
	resampleClosedPath,
	sampleClosedPath,
	segmentIntersection,
	smoothClosedPath,
} = require('../randomizer/track_geometry');
const { getTrackGeometryFixture } = require('./track_geometry_fixtures');

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

console.log('Section A: track geometry primitives');

test('segmentIntersection reports a proper crossing for diagonal segments', () => {
	const result = segmentIntersection([0, 0], [6, 6], [0, 6], [6, 0]);
	assert.strictEqual(result.kind, 'point');
	assert.strictEqual(result.proper, true);
	assert.ok(Math.abs(result.point[0] - 3) < 1e-6);
	assert.ok(Math.abs(result.point[1] - 3) < 1e-6);
});

test('segmentIntersection reports shared endpoints without marking a proper crossing', () => {
	const result = segmentIntersection([0, 0], [4, 0], [4, 0], [4, 4]);
	assert.strictEqual(result.kind, 'point');
	assert.strictEqual(result.proper, false);
	assert.strictEqual(result.sharedEndpoint, true);
});

test('segmentIntersection ignores near-miss segments', () => {
	const result = segmentIntersection([0, 0], [4, 0], [2, 0.1], [2, 4]);
	assert.strictEqual(result.kind, 'none');
});

test('isClosedLoop accepts a simple rectangle and rejects a line', () => {
	assert.strictEqual(isClosedLoop(getTrackGeometryFixture('rectangle_loop').points), true);
	assert.strictEqual(isClosedLoop([[0, 0], [1, 0], [2, 0]]), false);
});

test('buildClosedPathSegments returns deterministic perimeter totals', () => {
	const fixture = getTrackGeometryFixture('rectangle_loop');
	const path = buildClosedPathSegments(fixture.points);
	assert.strictEqual(path.segments.length, fixture.points.length);
	assert.ok(Math.abs(path.totalLength - 28) < 1e-6, `expected perimeter 28, got ${path.totalLength}`);
	assert.ok(Math.abs(getPathLength(fixture.points) - 28) < 1e-6);
});

test('sampleClosedPath produces evenly spaced samples on a square loop', () => {
	const fixture = getTrackGeometryFixture('square_loop');
	const sampled = sampleClosedPath(fixture.points, 4);
	assert.deepStrictEqual(sampled, [[0, 0], [4, 0], [4, 4], [0, 4]]);
});

test('resampleClosedPath returns the requested point count and keeps zero-crossing topology', () => {
	const fixture = getTrackGeometryFixture('rectangle_loop');
	const resampled = resampleClosedPath(fixture.points, 12);
	assert.strictEqual(resampled.length, 12);
	assert.strictEqual(countProperSelfIntersections(resampled), 0);
});

test('smoothClosedPath is deterministic and preserves point count', () => {
	const fixture = getTrackGeometryFixture('square_loop');
	const a = smoothClosedPath(fixture.points, 1);
	const b = smoothClosedPath(fixture.points, 1);
	assert.deepStrictEqual(a, b);
	assert.strictEqual(a.length, fixture.points.length);
	assert.deepStrictEqual(a[0], [1, 1]);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
