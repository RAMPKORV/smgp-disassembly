#!/usr/bin/env node
'use strict';

const assert = require('assert');
const path = require('path');

const { readJson } = require('../lib/json');
const { REPO_ROOT } = require('../lib/rom');
const {
	DEFAULT_VALIDATION_SNAPSHOT_SEEDS,
	DEFAULT_VALIDATION_SNAPSHOT_TRACKS,
	buildValidationSnapshot,
	buildValidationSnapshotFixture,
} = require('./minimap_validation_snapshot_helpers');

const FIXTURE_PATH = path.join(REPO_ROOT, 'tools', 'data', 'minimap_validation_snapshots.json');

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

console.log('Section A: minimap validation snapshots');

const fixture = readJson(FIXTURE_PATH);

test('validation snapshot fixture matches current compact summaries', () => {
	const actual = buildValidationSnapshotFixture(DEFAULT_VALIDATION_SNAPSHOT_SEEDS, DEFAULT_VALIDATION_SNAPSHOT_TRACKS);
	assert.deepStrictEqual(actual, fixture);
});

test('same seed produces identical validation snapshots', () => {
	const seed = DEFAULT_VALIDATION_SNAPSHOT_SEEDS[0];
	const a = buildValidationSnapshot(seed, DEFAULT_VALIDATION_SNAPSHOT_TRACKS);
	const b = buildValidationSnapshot(seed, DEFAULT_VALIDATION_SNAPSHOT_TRACKS);
	assert.deepStrictEqual(a, b);
});

test('different seeds produce different validation snapshots', () => {
	const a = buildValidationSnapshot(DEFAULT_VALIDATION_SNAPSHOT_SEEDS[0], DEFAULT_VALIDATION_SNAPSHOT_TRACKS);
	const b = buildValidationSnapshot(DEFAULT_VALIDATION_SNAPSHOT_SEEDS[1], DEFAULT_VALIDATION_SNAPSHOT_TRACKS);
	assert.notDeepStrictEqual(a, b);
});

test('validation snapshot fixture stays compact and excludes topology detail blobs', () => {
	const actual = buildValidationSnapshotFixture(DEFAULT_VALIDATION_SNAPSHOT_SEEDS, DEFAULT_VALIDATION_SNAPSHOT_TRACKS);
	for (const seed of Object.values(actual.seeds)) {
		for (const track of Object.values(seed.tracks)) {
			assert.ok(!Object.prototype.hasOwnProperty.call(track, 'topology'));
			assert.ok(!Object.prototype.hasOwnProperty.call(track, 'candidate_pairs'));
		}
	}
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
