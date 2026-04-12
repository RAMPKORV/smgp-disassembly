#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('../lib/rom');
const {
	parseLstSymbolMapFromText,
	validateGeneratedMinimaps,
} = require('../randomize_track_support');

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

console.log('Section A: randomize track support');

test('parseLstSymbolMapFromText extracts label addresses', () => {
	const text = [
		'00001234                San_Marino_curve_data:',
		'00005678                Monaco_arcade_post_sign_tileset_blob:',
	].join('\n');
	const map = parseLstSymbolMapFromText(text);
	assert.strictEqual(map.get('San_Marino_curve_data'), 0x1234);
	assert.strictEqual(map.get('Monaco_arcade_post_sign_tileset_blob'), 0x5678);
	assert.strictEqual(map.size, 2);
	});

test('validateGeneratedMinimaps reports matching offroad failure count', () => {
	const tracksPath = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');
	const tracksData = JSON.parse(fs.readFileSync(tracksPath, 'utf8'));
	const selectedTracks = tracksData.tracks.slice(0, 2);
	const result = validateGeneratedMinimaps(selectedTracks);
	assert.strictEqual(result.report.track_count, selectedTracks.length);
	assert.strictEqual(result.failures.length, result.report.candidate_marker_offroad_count);
	assert.ok(Array.isArray(result.report.tracks));
	});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
