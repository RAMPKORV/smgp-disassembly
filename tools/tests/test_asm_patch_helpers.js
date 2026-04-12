#!/usr/bin/env node
'use strict';

const assert = require('assert');
const {
	alignEven,
	encodeJsrAbsoluteLong,
	formatDcB,
	formatDcL,
	patchRomEnd,
	writeLongBE,
	writeWordBE,
} = require('../lib/asm_patch_helpers');

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

console.log('Section A: asm patch helpers');

test('writeWordBE and writeLongBE write big-endian values', () => {
	const buf = Buffer.alloc(6);
	writeWordBE(buf, 0, 0x1234);
	writeLongBE(buf, 2, 0x89ABCDEF);
	assert.strictEqual(buf.readUInt16BE(0), 0x1234);
	assert.strictEqual(buf.readUInt32BE(2), 0x89ABCDEF);
});

test('alignEven rounds odd values up to even', () => {
	assert.strictEqual(alignEven(5), 6);
	assert.strictEqual(alignEven(6), 6);
});

test('encodeJsrAbsoluteLong emits JSR absolute-long opcode', () => {
	const buf = encodeJsrAbsoluteLong(0x12345678);
	assert.strictEqual(buf.readUInt16BE(0), 0x4EB9);
	assert.strictEqual(buf.readUInt32BE(2), 0x12345678);
});

test('patchRomEnd updates ROM end header to buffer length minus one', () => {
	const buf = Buffer.alloc(0x300, 0);
	patchRomEnd(buf);
	assert.strictEqual(buf.readUInt32BE(0x01A4), buf.length - 1);
});

test('formatDcB and formatDcL produce asm-friendly output', () => {
	assert.deepStrictEqual(formatDcB(Uint8Array.from([0x12, 0x34])), ['\tdc.b\t$12, $34']);
	assert.deepStrictEqual(formatDcL([0x12345678, 0x9ABCDEF0]), ['\tdc.l\t$12345678, $9ABCDEF0']);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
