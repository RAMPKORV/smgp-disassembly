#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	XorShift32,
	deriveSubseed,
	parseSeed,
	MOD_TRACK_CURVES,
	MOD_TRACK_SLOPES,
	MOD_TEAMS,
	MOD_AI,
	MOD_CHAMPIONSHIP,
	FLAG_TRACKS,
	FLAG_TRACK_CONFIG,
	FLAG_TEAMS,
	FLAG_AI,
	FLAG_CHAMPIONSHIP,
	FLAG_SIGNS,
	FLAG_ALL,
} = require('../randomizer/track_randomizer');

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

console.log('Section A: XorShift32 PRNG');

test('XorShift32 produces non-zero output for seed 1', () => {
	const rng = new XorShift32(1);
	const v = rng.next();
	assert.ok(v !== 0, 'expected non-zero');
});

test('XorShift32 is reproducible with same seed', () => {
	const a = new XorShift32(42);
	const b = new XorShift32(42);
	for (let i = 0; i < 20; i++) assert.strictEqual(a.next(), b.next());
});

test('XorShift32 produces different sequences for different seeds', () => {
	const a = new XorShift32(1);
	const b = new XorShift32(2);
	const seqA = Array.from({ length: 10 }, () => a.next());
	const seqB = Array.from({ length: 10 }, () => b.next());
	assert.notDeepStrictEqual(seqA, seqB);
});

test('XorShift32.randInt returns value in [lo, hi]', () => {
	const rng = new XorShift32(999);
	for (let i = 0; i < 100; i++) {
		const v = rng.randInt(5, 10);
		assert.ok(v >= 5 && v <= 10, `${v} out of [5,10]`);
	}
});

test('XorShift32.randFloat returns value in [0, 1)', () => {
	const rng = new XorShift32(7);
	for (let i = 0; i < 50; i++) {
		const v = rng.randFloat();
		assert.ok(v >= 0 && v < 1, `${v} out of [0,1)`);
	}
});

test('XorShift32.choice returns an element from the array', () => {
	const rng = new XorShift32(3);
	const items = ['a', 'b', 'c'];
	for (let i = 0; i < 30; i++) assert.ok(items.includes(rng.choice(items)));
});

test('XorShift32.weightedChoice respects weights (sanity test)', () => {
	const rng = new XorShift32(12345);
	const counts = { a: 0, b: 0 };
	for (let i = 0; i < 1000; i++) counts[rng.weightedChoice(['a', 'b'], [1, 9])]++;
	assert.ok(counts.b > counts.a * 3, `expected b >> a, got a=${counts.a} b=${counts.b}`);
});

test('XorShift32 seed 0 is treated as seed 1 (same state)', () => {
	const rng0 = new XorShift32(0);
	const rng1 = new XorShift32(1);
	assert.strictEqual(rng0.next(), rng1.next());
});

console.log('Section B: parseSeed and deriveSubseed');

test('parseSeed parses valid seed SMGP-1-01-12345', () => {
	const [version, flags, seed] = parseSeed('SMGP-1-01-12345');
	assert.strictEqual(version, 1);
	assert.strictEqual(flags, 0x01);
	assert.strictEqual(seed, 12345);
});

test('parseSeed parses uppercase hex flags SMGP-1-3F-99999', () => {
	const [, flags, seed] = parseSeed('SMGP-1-3F-99999');
	assert.strictEqual(flags, 0x3F);
	assert.strictEqual(seed, 99999);
});

test('parseSeed parses lowercase hex flags SMGP-1-0c-1', () => {
	const [, flags, seed] = parseSeed('SMGP-1-0c-1');
	assert.strictEqual(flags, 0x0C);
	assert.strictEqual(seed, 1);
});

test('parseSeed parses FLAG_ALL seed SMGP-1-3F-1', () => {
	const [, flags] = parseSeed('SMGP-1-3F-1');
	assert.strictEqual(flags, FLAG_ALL);
});

test('parseSeed throws on invalid format', () => {
	assert.throws(() => parseSeed('INVALID'), /Invalid seed format/);
	assert.throws(() => parseSeed('SMGP-1-01'), /Invalid seed format/);
	assert.throws(() => parseSeed('smgp-1-01-123'), /Invalid seed format/);
});

test('deriveSubseed returns different values for different module IDs', () => {
	const sub1 = deriveSubseed(12345, MOD_TRACK_CURVES);
	const sub2 = deriveSubseed(12345, MOD_TRACK_SLOPES);
	const sub3 = deriveSubseed(12345, MOD_TEAMS);
	assert.notStrictEqual(sub1, sub2);
	assert.notStrictEqual(sub1, sub3);
	assert.notStrictEqual(sub2, sub3);
});

test('deriveSubseed is reproducible with same inputs', () => {
	assert.strictEqual(deriveSubseed(9999, MOD_AI), deriveSubseed(9999, MOD_AI));
});

test('deriveSubseed returns non-zero', () => {
	for (const mod of [MOD_TRACK_CURVES, MOD_TRACK_SLOPES, MOD_TEAMS, MOD_CHAMPIONSHIP]) {
		assert.ok(deriveSubseed(1, mod) !== 0, `subseed 0 for mod ${mod}`);
	}
});

test('flag constants have expected values', () => {
	assert.strictEqual(FLAG_TRACKS, 0x01);
	assert.strictEqual(FLAG_TRACK_CONFIG, 0x02);
	assert.strictEqual(FLAG_TEAMS, 0x04);
	assert.strictEqual(FLAG_AI, 0x08);
	assert.strictEqual(FLAG_CHAMPIONSHIP, 0x10);
	assert.strictEqual(FLAG_SIGNS, 0x20);
	assert.strictEqual(FLAG_ALL, 0x3F);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
