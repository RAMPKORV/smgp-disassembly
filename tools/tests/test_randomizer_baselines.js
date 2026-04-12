#!/usr/bin/env node
'use strict';

const assert = require('assert');
const path = require('path');

const { readJson } = require('../lib/json');
const { REPO_ROOT } = require('../lib/rom');
const {
	DEFAULT_BASELINE_SEEDS,
	DEFAULT_BASELINE_TRACKS,
	buildBaselineSummary,
	buildSeedSummary,
} = require('./randomizer_baseline_helpers');

const FIXTURE_PATH = path.join(REPO_ROOT, 'tools', 'data', 'randomizer_baselines.json');

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

console.log('Section A: fixed-seed baseline summaries');

const fixture = readJson(FIXTURE_PATH);

test('baseline fixture matches current compact summaries', () => {
	const actual = buildBaselineSummary(DEFAULT_BASELINE_SEEDS, DEFAULT_BASELINE_TRACKS);
	assert.deepStrictEqual(actual, fixture);
});

test('same seed produces identical compact summaries', () => {
	const seed = DEFAULT_BASELINE_SEEDS[0];
	const a = buildSeedSummary(seed, DEFAULT_BASELINE_TRACKS);
	const b = buildSeedSummary(seed, DEFAULT_BASELINE_TRACKS);
	assert.deepStrictEqual(a, b);
});

test('different seeds produce different compact summaries', () => {
	const a = buildSeedSummary(DEFAULT_BASELINE_SEEDS[0], DEFAULT_BASELINE_TRACKS);
	const b = buildSeedSummary(DEFAULT_BASELINE_SEEDS[1], DEFAULT_BASELINE_TRACKS);
	assert.notDeepStrictEqual(a, b);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
