#!/usr/bin/env node
'use strict';

const assert = require('assert');
const os = require('os');
const path = require('path');

const { injectTrack } = require('../inject_track_data');

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

function makeTrack() {
	return {
		index: 0,
		slug: 'san_marino',
		name: 'San Marino',
		track_length: 4096,
		slope_initial_bg_disp: 0,
		curve_rle_segments: [{ type: 'straight', length: 4, curve_byte: 0 }, { type: 'terminator', _raw: [0xFF, 0x00] }],
		slope_rle_segments: [{ type: 'flat', length: 4, slope_byte: 0, bg_vert_disp: 0 }, { type: 'terminator', _raw: [0xFF] }],
		phys_slope_rle_segments: [{ type: 'segment', length: 4, phys_byte: 0 }, { type: 'terminator', _raw: [0x80, 0x00, 0x00] }],
		sign_data: [],
		sign_tileset: [],
		minimap_pos: [[0, 0]],
	};
}

console.log('Section A: inject track data guards');

test('injectTrack rejects missing curve segment arrays', () => {
	const track = makeTrack();
	delete track.curve_rle_segments;
	assert.throws(() => injectTrack(track, path.join(os.tmpdir(), 'unused'), true, false), /curve_rle_segments/);
});

test('injectTrack rejects malformed minimap pair lists', () => {
	const track = makeTrack();
	track.minimap_pos = [[0]];
	assert.throws(() => injectTrack(track, path.join(os.tmpdir(), 'unused'), true, false), /minimap_pos/);
});

test('injectTrack rejects malformed trailing byte arrays', () => {
	const track = makeTrack();
	track.sign_tileset_trailing = [256];
	assert.throws(() => injectTrack(track, path.join(os.tmpdir(), 'unused'), true, false), /sign_tileset_trailing/);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
