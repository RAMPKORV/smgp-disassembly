#!/usr/bin/env node
'use strict';

const assert = require('assert');
const {
	cyclicTrackDistance,
	getActiveTilesetOffset,
	getActiveTilesetRecord,
	getSignRuntimeRowSpan,
	isAllowedSignIdForTileset,
	TUNNEL_TILESET_OFFSET,
} = require('../randomizer/sign_utils');

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

console.log('Section A: sign utils');

test('cyclicTrackDistance wraps around track length', () => {
	assert.strictEqual(cyclicTrackDistance(10, 790, 800), 20);
});

test('getSignRuntimeRowSpan scales with count and sign sequence slots', () => {
	assert.strictEqual(getSignRuntimeRowSpan(2, 4), 8);
	assert.strictEqual(getSignRuntimeRowSpan(28, 3), 3);
});

test('getActiveTilesetOffset and record choose latest active transition', () => {
	const records = [
		{ distance: 0, tileset_offset: 8 },
		{ distance: 300, tileset_offset: 24 },
		{ distance: 700, tileset_offset: 40 },
	];
	assert.strictEqual(getActiveTilesetOffset(records, 350), 24);
	assert.deepStrictEqual(getActiveTilesetRecord(records, 750), records[2]);
});

test('isAllowedSignIdForTileset enforces family compatibility', () => {
	assert.strictEqual(isAllowedSignIdForTileset(24, 16), true);
	assert.strictEqual(isAllowedSignIdForTileset(24, 28), false);
	assert.strictEqual(isAllowedSignIdForTileset(TUNNEL_TILESET_OFFSET, 49, { isArcadeWet: true }), true);
	assert.strictEqual(isAllowedSignIdForTileset(TUNNEL_TILESET_OFFSET, 49, { isArcadeWet: false }), false);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
