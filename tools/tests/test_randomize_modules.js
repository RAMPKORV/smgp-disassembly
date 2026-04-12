#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	runAiModule,
	runChampionshipModule,
	runConfigModule,
	runTeamsModule,
	runTracksModule,
} = require('../randomize_modules');

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

function withCapturedLogs(fn) {
	const logs = [];
	const original = console.log;
	console.log = (...args) => logs.push(args.join(' '));
	try {
		fn(logs);
	} finally {
		console.log = original;
	}
	return logs;
}

console.log('Section A: randomize module facades');

test('runTracksModule logs skip message when track flag is absent', () => {
	const logs = withCapturedLogs(() => {
		runTracksModule({
			flags: 0,
			inputPath: 'unused.json',
			trackSlugs: null,
			randomizedTrackCount: 0,
			seedInt: 1,
			verbose: false,
			dryRun: true,
		});
	});
	assert.ok(logs.some(line => line.includes('[RAND_TRACKS] flag not set')));
});

test('runConfigModule logs skip message when config flag is absent', () => {
	const logs = withCapturedLogs(() => {
		runConfigModule({ flags: 0, seedInt: 1, verbose: false, dryRun: true });
	});
	assert.ok(logs.some(line => line.includes('[RAND_CONFIG] flag not set')));
});

test('runTeamsModule logs skip message when teams flag is absent', () => {
	const logs = withCapturedLogs(() => {
		runTeamsModule({ flags: 0, seedInt: 1, verbose: false, dryRun: true });
	});
	assert.ok(logs.some(line => line.includes('[RAND_TEAMS] flag not set')));
});

test('runAiModule logs skip message when AI flag is absent', () => {
	const logs = withCapturedLogs(() => {
		runAiModule({ flags: 0, seedInt: 1, verbose: false, dryRun: true });
	});
	assert.ok(logs.some(line => line.includes('[RAND_AI] flag not set')));
});

test('runChampionshipModule logs skip message when championship flag is absent', () => {
	const logs = withCapturedLogs(() => {
		runChampionshipModule({ flags: 0, seedInt: 1, verbose: false, dryRun: true });
	});
	assert.ok(logs.some(line => line.includes('[RAND_CHAMPIONSHIP] flag not set')));
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
