#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const {
	TRACKS_JSON,
	buildRandomizePlan,
	flagSummary,
	parseTrackSlugSet,
} = require('../randomizer_plan');
const { REPO_ROOT } = require('../lib/rom');

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

console.log('Section A: randomizer plan helpers');

test('flagSummary names enabled modules', () => {
	assert.strictEqual(flagSummary(0x01), 'TRACKS');
	assert.ok(flagSummary(0x03).includes('TRACKS'));
	assert.ok(flagSummary(0x03).includes('CONFIG'));
});

test('parseTrackSlugSet returns null without input', () => {
	assert.strictEqual(parseTrackSlugSet(null), null);
});

test('parseTrackSlugSet splits whitespace separated slugs', () => {
	const slugs = parseTrackSlugSet('san_marino portugal');
	assert.ok(slugs.has('san_marino'));
	assert.ok(slugs.has('portugal'));
	assert.strictEqual(slugs.size, 2);
});

test('buildRandomizePlan parses seed and resolves default input path', () => {
	const plan = buildRandomizePlan({ seedStr: 'SMGP-1-01-12345' });
	assert.strictEqual(plan.version, 1);
	assert.strictEqual(plan.flags, 0x01);
	assert.strictEqual(plan.seedInt, 12345);
	assert.strictEqual(plan.inputPath, TRACKS_JSON);
	assert.ok(plan.randomizedTrackCount > 0);
});

test('buildRandomizePlan respects track filters when counting tracks', () => {
	const plan = buildRandomizePlan({ seedStr: 'SMGP-1-01-12345', tracksArg: 'san_marino portugal' });
	assert.strictEqual(plan.randomizedTrackCount, 2);
	assert.ok(plan.trackSlugs.has('san_marino'));
	assert.ok(plan.trackSlugs.has('portugal'));
});

test('buildRandomizePlan leaves randomizedTrackCount unknown on invalid track JSON shape', () => {
	const badPath = path.join(REPO_ROOT, 'build', 'tests', 'invalid_tracks_for_plan.json');
	fs.mkdirSync(path.dirname(badPath), { recursive: true });
	fs.writeFileSync(badPath, JSON.stringify({ tracks: [{ slug: '', name: 'Bad', index: 0, track_length: 0 }] }), 'utf8');
	try {
		const plan = buildRandomizePlan({
			seedStr: 'SMGP-1-01-12345',
			inputArg: path.relative(REPO_ROOT, badPath),
		});
		assert.strictEqual(plan.randomizedTrackCount, null);
	} finally {
		if (fs.existsSync(badPath)) fs.unlinkSync(badPath);
	}
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
