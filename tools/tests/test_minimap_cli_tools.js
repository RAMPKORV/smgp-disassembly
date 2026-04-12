#!/usr/bin/env node
'use strict';

const assert = require('assert');
const path = require('path');
const { spawnSync } = require('child_process');

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

function runNodeTool(scriptName, args) {
	const scriptPath = path.join(REPO_ROOT, 'tools', scriptName);
	const result = spawnSync('node', [scriptPath, ...args], {
		cwd: REPO_ROOT,
		encoding: 'utf8',
		maxBuffer: 16 * 1024 * 1024,
	});
	if (result.status !== 0) {
		throw new Error(`${scriptName} failed (${result.status}): ${(result.stderr || result.stdout || '').trim()}`);
	}
	return (result.stdout || '').trim();
}

console.log('Section A: minimap CLI smoke tests');

test('minimap_validate --json --track outputs normalized per-track report', () => {
	const output = runNodeTool('minimap_validate.js', ['--json', '--track', 'san_marino']);
	const report = JSON.parse(output);
	assert.strictEqual(report.track.slug, 'san_marino');
	assert.ok(typeof report.metrics.preview_match_percent === 'number');
	assert.ok(Array.isArray(report.alignment.candidate_pairs));
	assert.ok(report.flags && typeof report.flags === 'object');
});

test('minimap_validate --json --all outputs aggregate validation report', () => {
	const output = runNodeTool('minimap_validate.js', ['--json', '--all']);
	const report = JSON.parse(output);
	assert.ok(report.track_count >= 19);
	assert.ok(Array.isArray(report.tracks));
	assert.strictEqual(report.tracks.length, report.track_count);
	assert.ok(typeof report.curve_map_sign_match_percent === 'number');
	assert.ok(typeof report.generated_marker_offroad_count === 'number');
});

test('minimap_generate --json outputs generated pair summary', () => {
	const output = runNodeTool('minimap_generate.js', ['--json', '--track', 'san_marino']);
	const report = JSON.parse(output);
	assert.strictEqual(report.track.slug, 'san_marino');
	assert.ok(report.generated && typeof report.generated.transform === 'string');
	assert.ok(Array.isArray(report.generated.pairs));
	assert.ok(typeof report.generated.sample_count === 'number');
});

test('minimap_preview_space --json outputs normalized summary shape', () => {
	const output = runNodeTool('minimap_preview_space.js', ['--json', '--track', 'san_marino']);
	const report = JSON.parse(output);
	assert.strictEqual(report.track.slug, 'san_marino');
	assert.ok(report.canonical_to_preview && typeof report.canonical_to_preview.transform === 'string');
	assert.ok(report.derived_to_preview && typeof report.derived_to_preview.match_percent === 'number');
	assert.ok(report.preview_metrics && typeof report.preview_metrics.match_percent === 'number');
});

test('minimap_diagnostics --json --track outputs normalized per-track summary', () => {
	const output = runNodeTool('minimap_diagnostics.js', ['--json', '--track', 'san_marino']);
	const report = JSON.parse(output);
	assert.strictEqual(report.track.slug, 'san_marino');
	assert.ok(report.canonical_to_preview && typeof report.canonical_to_preview.match_percent === 'number');
	assert.ok(report.preview_metrics && typeof report.preview_metrics.significant_mismatch === 'boolean');
});

test('minimap_diagnostics --json outputs aggregate report structure', () => {
	const output = runNodeTool('minimap_diagnostics.js', ['--json']);
	const report = JSON.parse(output);
	assert.ok(report.track_count >= 19);
	assert.ok(typeof report.average_match_percent === 'number');
	assert.ok(Array.isArray(report.preview_tile_usage_groups));
	assert.ok(Array.isArray(report.tracks));
	assert.strictEqual(report.tracks.length, report.track_count);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
