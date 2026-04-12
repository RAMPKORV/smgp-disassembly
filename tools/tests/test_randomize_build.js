#!/usr/bin/env node
'use strict';

const assert = require('assert');

const { buildSucceededFromResult } = require('../randomize_build');

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

console.log('Section A: randomize build helpers');

test('buildSucceededFromResult requires zero status', () => {
	assert.strictEqual(buildSucceededFromResult(1, '0 error(s)'), false);
});

test('buildSucceededFromResult requires assembler success marker', () => {
	assert.strictEqual(buildSucceededFromResult(0, 'Assembly completed.'), false);
});

test('buildSucceededFromResult accepts successful assembler output', () => {
	assert.strictEqual(buildSucceededFromResult(0, 'Assembly completed.\n0 error(s) from 10 lines'), true);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
