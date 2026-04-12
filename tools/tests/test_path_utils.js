#!/usr/bin/env node
'use strict';

const assert = require('assert');
const { countSelfIntersections, cyclicDistance, rotateClosedPoints } = require('../lib/path_utils');

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

console.log('Section A: path utils');

test('rotateClosedPoints rotates from requested start index', () => {
	assert.deepStrictEqual(rotateClosedPoints([[1], [2], [3], [4]], 2), [[3], [4], [1], [2]]);
});

test('cyclicDistance wraps around closed sequences', () => {
	assert.strictEqual(cyclicDistance(0, 7, 8), 1);
	assert.strictEqual(cyclicDistance(2, 5, 8), 3);
});

test('countSelfIntersections detects a bow-tie path', () => {
	const points = [[0, 0], [4, 4], [0, 4], [4, 0]];
	assert.ok(countSelfIntersections(points) > 0);
});

test('countSelfIntersections ignores a simple rectangle', () => {
	const points = [[0, 0], [4, 0], [4, 4], [0, 4]];
	assert.strictEqual(countSelfIntersections(points), 0);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
