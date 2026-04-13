#!/usr/bin/env node
'use strict';

const assert = require('assert');

const generatedMinimapPos = require('../lib/generated_minimap_pos');
const minimapRender = require('../lib/minimap_render');
const minimapAnalysis = require('../lib/minimap_analysis');
const { setGeneratedGeometryState } = require('../randomizer/track_metadata');

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

function withPatched(object, key, replacement, fn) {
	const original = object[key];
	object[key] = replacement;
	try {
		fn();
	} finally {
		object[key] = original;
	}
}

console.log('Section A: generated minimap position helpers');

test('clampSignedByte clamps and rounds to signed byte range', () => {
	assert.strictEqual(generatedMinimapPos.clampSignedByte(-200), -128);
	assert.strictEqual(generatedMinimapPos.clampSignedByte(200), 127);
	assert.strictEqual(generatedMinimapPos.clampSignedByte(12.6), 13);
});

test('buildGeneratedMinimapPosPairs falls back to generated pairs when preview centerline is empty', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 128, minimap_pos: [[0, 0], [0, 0]] };
	withPatched(minimapRender, 'buildGeneratedMinimapPreview', () => ({ centerline_points: [] }), () => {
		withPatched(minimapAnalysis, 'generateMinimapPairsFromTrack', () => ({ pairs: [[7, 8], [9, 10]] }), () => {
			const pairs = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
			assert.deepStrictEqual(pairs, [[7, 8], [9, 10]]);
		});
	});
});

test('buildGeneratedMinimapPosPairs respects preview start_index rotation', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 256, minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]] };
	withPatched(minimapRender, 'buildGeneratedMinimapPreview', () => ({
		centerline_points: [[1, 10], [2, 20], [3, 30], [4, 40]],
		start_index: 2,
	}), () => {
		withPatched(minimapAnalysis, 'sampleClosedPath', (points, count) => points.slice(0, count), () => {
			const pairs = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
			assert.deepStrictEqual(pairs, [[30, 3], [40, 4], [10, 1], [20, 2]]);
		});
	});
});

test('buildGeneratedMinimapPosPairs swaps x/y into encoded y/x orientation', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 128, minimap_pos: [[0, 0], [0, 0]] };
	withPatched(minimapRender, 'buildGeneratedMinimapPreview', () => ({
		centerline_points: [[11, 22], [33, 44]],
		start_index: 0,
	}), () => {
		withPatched(minimapAnalysis, 'sampleClosedPath', (points, count) => points.slice(0, count), () => {
			const pairs = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
			assert.deepStrictEqual(pairs, [[22, 11], [44, 33]]);
		});
	});
});

test('buildGeneratedMinimapPosPairs clamps sampled coordinates to signed byte range', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 128, minimap_pos: [[0, 0], [0, 0]] };
	withPatched(minimapRender, 'buildGeneratedMinimapPreview', () => ({
		centerline_points: [[300, -300], [-400, 400]],
		start_index: 0,
	}), () => {
		withPatched(minimapAnalysis, 'sampleClosedPath', (points, count) => points.slice(0, count), () => {
			const pairs = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
			assert.deepStrictEqual(pairs, [[-128, 127], [127, -128]]);
		});
	});
});

test('buildGeneratedMinimapPosPairs is reproducible for same preview and sampler outputs', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 192, minimap_pos: [[0, 0], [0, 0], [0, 0]] };
	const preview = { centerline_points: [[1, 2], [3, 4], [5, 6]], start_index: 1 };
	withPatched(minimapRender, 'buildGeneratedMinimapPreview', () => preview, () => {
		withPatched(minimapAnalysis, 'sampleClosedPath', (points, count) => points.slice(0, count), () => {
			const a = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
			const b = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
			assert.deepStrictEqual(a, b);
		});
	});
});

test('buildGeneratedMinimapPosPairs falls back to track_length>>6 sample count when minimap_pos is missing', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 320 };
	let recordedCount = null;
	withPatched(minimapAnalysis, 'generateMinimapPairsFromTrack', () => {
		recordedCount = track.track_length >> 6;
		return { pairs: [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]] };
	}, () => {
		const pairs = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
		assert.strictEqual(recordedCount, 5);
		assert.strictEqual(pairs.length, 5);
	});
});

test('buildGeneratedMinimapPosPairs prefers transient runtime pair projection when present', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 256, minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]] };
	setGeneratedGeometryState(track, {
		projections: {
			minimap_runtime: {
				pairs: [[1, 2], [3, 4], [5, 6], [7, 8]],
			},
		},
	});
	assert.deepStrictEqual(generatedMinimapPos.buildGeneratedMinimapPosPairs(track), [[1, 2], [3, 4], [5, 6], [7, 8]]);
});

test('buildGeneratedMinimapPosPairs falls back through analysis-generated runtime pairs when no runtime projection exists', () => {
	const track = { slug: 'synthetic', name: 'Synthetic', index: 0, track_length: 256, minimap_pos: [[0, 0], [0, 0], [0, 0], [0, 0]] };
	withPatched(minimapRender, 'buildGeneratedMinimapPreview', () => ({ centerline_points: [] }), () => {
	withPatched(minimapAnalysis, 'generateMinimapPairsFromTrack', () => ({ pairs: [[10, 1], [20, 2], [30, 3], [40, 4]] }), () => {
		const pairs = generatedMinimapPos.buildGeneratedMinimapPosPairs(track);
		assert.deepStrictEqual(pairs, [[10, 1], [20, 2], [30, 3], [40, 4]]);
	});
	});
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
