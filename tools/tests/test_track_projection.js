#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	CURVE_STRAIGHT,
	buildHeadingProfile,
	buildGradeSeparatedProjectionData,
	buildPhysicalSlopeRleFromVisual,
	buildVisualSlopeEvents,
	compressCurveBytesToRle,
	normalizeAngleDelta,
	projectCenterlineToCurveBytes,
	projectCenterlineToCurveRle,
	projectCenterlineToSlopeRle,
	quantizeTurnToCurveByte,
} = require('../randomizer/track_projection');

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

console.log('Section A: track projection');

test('normalizeAngleDelta wraps values into +/-pi', () => {
	assert.ok(normalizeAngleDelta(Math.PI * 1.5) < Math.PI);
	assert.ok(normalizeAngleDelta(-Math.PI * 1.5) > -Math.PI);
});

test('quantizeTurnToCurveByte emits straight for tiny turns', () => {
	assert.strictEqual(quantizeTurnToCurveByte(0.00001, 1), CURVE_STRAIGHT);
});

test('projectCenterlineToCurveBytes returns track_length>>2 bytes', () => {
	const points = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const bytes = projectCenterlineToCurveBytes(points, 64);
	assert.strictEqual(bytes.length, 64);
	assert.ok(bytes.every(value => value === 0 || (value >= 0x01 && value <= 0x2F) || (value >= 0x41 && value <= 0x6F)));
});

test('compressCurveBytesToRle round-trips decompressed length and terminator', () => {
	const bytes = [0, 0, 0x45, 0x45, 0x45, 0, 0x09];
	const rle = compressCurveBytesToRle(bytes);
	const content = rle.filter(seg => seg.type !== 'terminator').reduce((sum, seg) => sum + seg.length, 0);
	assert.strictEqual(content, bytes.length);
	assert.strictEqual(rle[rle.length - 1].type, 'terminator');
	assert.strictEqual(rle[rle.length - 1].curve_byte, 0xFF);
});

test('projectCenterlineToCurveRle builds deterministic valid curve projection', () => {
	const points = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const a = projectCenterlineToCurveRle(points, 256);
	const b = projectCenterlineToCurveRle(points, 256);
	assert.deepStrictEqual(a, b);
	assert.strictEqual(a.curve_bytes.length, 64);
	assert.strictEqual(a.curve_rle_segments[a.curve_rle_segments.length - 1].type, 'terminator');
	assert.ok(a.curve_rle_segments.some(seg => seg.type === 'curve'));
});

test('buildHeadingProfile emits one heading entry per point', () => {
	const points = [[0, 0], [4, 0], [4, 4], [0, 4]];
	const profile = buildHeadingProfile(points);
	assert.strictEqual(profile.length, points.length);
	assert.ok(profile.some(entry => Math.abs(entry.turn) > 0));
});

test('buildVisualSlopeEvents stays flat by default for non-crossing map-first projection', () => {
	const points = [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]];
	const events = buildVisualSlopeEvents(2048, points);
	assert.strictEqual(events.length, 0);
});

test('buildPhysicalSlopeRleFromVisual keeps shoulders flat and emits terminator', () => {
	const phys = buildPhysicalSlopeRleFromVisual([
		{ type: 'flat', length: 128, slope_byte: 0, bg_vert_disp: 0 },
		{ type: 'slope', length: 32, slope_byte: 0x4E, bg_vert_disp: 30 },
		{ type: 'flat', length: 96, slope_byte: 0, bg_vert_disp: 0 },
		{ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
	], 1024);
	assert.strictEqual(phys[phys.length - 1].type, 'terminator');
	assert.ok(phys.some(seg => seg.type === 'segment' && seg.phys_byte === 1));
	assert.ok(phys.some(seg => seg.type === 'segment' && seg.phys_byte === 0));
});

test('buildGradeSeparatedProjectionData marks lower branch as tunnel-ready underpass', () => {
	const projection = buildGradeSeparatedProjectionData(1024, 256, {
		grade_separated: true,
		lower_branch: { start_index: 40, end_index: 120 },
		upper_branch: { start_index: 121, end_index: 39 },
		crossing_point: [10, 10],
	});
	assert.ok(projection);
	assert.strictEqual(projection.lower_branch.branch_height, -1);
	assert.strictEqual(projection.lower_branch.tunnel_required, true);
	assert.strictEqual(projection.upper_branch.branch_height, 0);
	assert.strictEqual(projection.separation_ok, true);
});

test('projectCenterlineToSlopeRle produces valid-length visual and physical slope streams', () => {
	const projection = projectCenterlineToSlopeRle([[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]], 1024);
	const visualSteps = projection.slope_rle_segments.filter(seg => seg.type !== 'terminator').reduce((sum, seg) => sum + seg.length, 0);
	const physSteps = projection.phys_slope_rle_segments.filter(seg => seg.type !== 'terminator').reduce((sum, seg) => sum + seg.length, 0);
	assert.strictEqual(projection.slope_initial_bg_disp, 0);
	assert.strictEqual(visualSteps, 256);
	assert.strictEqual(physSteps, 256);
	assert.strictEqual(projection.slope_rle_segments[projection.slope_rle_segments.length - 1].type, 'terminator');
	assert.strictEqual(projection.phys_slope_rle_segments[projection.phys_slope_rle_segments.length - 1].type, 'terminator');
});

test('projectCenterlineToSlopeRle carries grade-separated crossing classification when provided', () => {
	const projection = projectCenterlineToSlopeRle([[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]], 1024, {
		crossingInfo: {
			grade_separated: true,
			lower_branch: { start_index: 64, end_index: 160 },
			upper_branch: { start_index: 161, end_index: 63 },
			crossing_point: [20, 20],
		},
	});
	assert.ok(projection.grade_separated_crossing);
	assert.strictEqual(projection.grade_separated_crossing.classification, 'grade_separated_crossing');
	assert.strictEqual(projection.grade_separated_crossing.lower_branch.tunnel_required, true);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
