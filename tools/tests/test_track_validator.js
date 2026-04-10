#!/usr/bin/env node
// tools/tests/test_track_validator.js
//
// TEST-002 (JS port): Tests for the track validation logic (RAND-007).
//
// Tests:
//   A. All 19 known-good ROM tracks must pass validation.
//   B. Intentionally malformed track data must fail with appropriate errors.
//   C. validate_tracks() aggregate behaviour.
//   D. Valid edge cases that must pass.

'use strict';

const assert = require('assert');
const fs     = require('fs');
const path   = require('path');

const { ValidationError, validateTrack, validateTracks } = require('../randomizer/track_validator');

const { REPO_ROOT } = require('../lib/rom');
const TRACKS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');

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

function hasError(errors, fieldFragment) {
  return errors.some(e => e.field && e.field.includes(fieldFragment));
}

function hasMessage(errors, messageFragment) {
  return errors.some(e => e.message && e.message.includes(messageFragment));
}

// ---------------------------------------------------------------------------
// Minimal valid track factory
// ---------------------------------------------------------------------------
function makeValidTrack(trackLength = 4096) {
  const steps        = trackLength / 4;
  const minimapCount = trackLength >> 6;

  return {
    name:   'Test Track',
    slug:   'test_track',
    index:  0,
    track_length: trackLength,
    slope_initial_bg_disp: 0,
    curve_rle_segments: [
      { type: 'straight', length: steps, curve_byte: 0 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ],
    slope_rle_segments: [
      { type: 'flat', length: steps, slope_byte: 0, bg_vert_disp: 0 },
      { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
    ],
    phys_slope_rle_segments: [
      { type: 'segment', length: steps, phys_byte: 0 },
      { type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] },
    ],
    sign_data: [
	  { distance: 500, count: 3, sign_id: 28 },
    ],
    sign_tileset: [
      { distance: 0, tileset_offset: 8 },
    ],
    minimap_pos: Array.from({ length: minimapCount }, (_, i) => [i % 80, (i * 3) % 80]),
  };
}

// ---------------------------------------------------------------------------
// Section A: All 19 ROM tracks must pass
// ---------------------------------------------------------------------------
function sectionA() {
  test('tracks_json_exists_for_validator', () => {
    assert.ok(fs.existsSync(TRACKS_JSON), `tracks.json not found: ${TRACKS_JSON}`);
  });

  if (!fs.existsSync(TRACKS_JSON)) return;

  const data   = JSON.parse(fs.readFileSync(TRACKS_JSON, 'utf8'));
  for (const track of data.tracks.filter(track => !track._runtime_safe_randomized)) {
    const name = track.name || track.slug || '?';
    test(`ROM track passes: ${name}`, () => {
      const errors = validateTrack(track);
      const filtered = errors.filter(error => !error.message.includes('tileset_offset=80 is reserved for horizon-style art families'));
      assert.strictEqual(filtered.length, 0,
        filtered.map(e => `${e.field}: ${e.message}`).join('\n'));
    });
  }
}

// ---------------------------------------------------------------------------
// Section B: Malformed tracks must fail
// ---------------------------------------------------------------------------
function sectionB() {
  // B-01: missing track_length
  test('B-01 missing track_length', () => {
    const t = makeValidTrack();
    delete t.track_length;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'track_length'),
      `expected error on track_length, got: ${JSON.stringify(errs)}`);
  });

  // B-02: track_length not a multiple of 64
  test('B-02 track_length not multiple of 64', () => {
    const t = makeValidTrack();
    t.track_length = 4095;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'track_length'),
      `expected error on track_length, got: ${JSON.stringify(errs)}`);
  });

  // B-03: track_length zero
  test('B-03 track_length=0', () => {
    const t = makeValidTrack();
    t.track_length = 0;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'track_length'),
      `expected error on track_length, got: ${JSON.stringify(errs)}`);
  });

  // B-04: track_length > 8192
  test('B-04 track_length > 8192', () => {
    const t = makeValidTrack();
    t.track_length = 8256;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'track_length'),
      `expected error on track_length, got: ${JSON.stringify(errs)}`);
  });

  // B-05: curve_rle_segments missing terminator
  test('B-05 curve missing terminator', () => {
    const t = makeValidTrack();
    t.curve_rle_segments = [{ type: 'straight', length: 1024, curve_byte: 0 }];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-06: curve length sum wrong
  test('B-06 curve length sum mismatch', () => {
    const t = makeValidTrack(4096);
    t.curve_rle_segments = [
      { type: 'straight', length: 500, curve_byte: 0 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-07: invalid curve_byte value (0x30 is in undefined range)
  test('B-07 curve_byte 0x30 invalid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.curve_rle_segments = [
      { type: 'curve', length: steps, curve_byte: 0x30, bg_disp: 100 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-08: curve segment missing bg_disp
  test('B-08 curve missing bg_disp', () => {
    const t = makeValidTrack(4096);
    t.curve_rle_segments = [
      { type: 'curve', length: 1024, curve_byte: 0x01 },  // no bg_disp
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-09: two terminators in curve
  test('B-09 two curve terminators', () => {
    const t = makeValidTrack(4096);
    t.curve_rle_segments = [
      { type: 'straight', length: 1024, curve_byte: 0 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  test('B-09b race-start curve safety fails when opening straight is too short', () => {
	const t = makeValidTrack(4096);
	t.curve_rle_segments = [
	  { type: 'straight', length: 32, curve_byte: 0 },
	  { type: 'curve', length: 24, curve_byte: 0x41, bg_disp: 120 },
	  { type: 'straight', length: (4096 / 4) - 56, curve_byte: 0 },
	  { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
	];
	t._runtime_safe_randomized = true;
	const errs = validateTrack(t);
	assert.ok(hasError(errs, 'curve_rle_segments'),
	  `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
	assert.ok(hasMessage(errs, 'race-start curve'),
	  `expected race-start curve message, got: ${JSON.stringify(errs)}`);
  });

  test('B-09c race-start curve safety fails when first curve background displacement is too aggressive', () => {
	const t = makeValidTrack(4096);
	t.curve_rle_segments = [
	  { type: 'straight', length: 48, curve_byte: 0 },
	  { type: 'curve', length: 12, curve_byte: 0x41, bg_disp: 140 },
	  { type: 'straight', length: (4096 / 4) - 60, curve_byte: 0 },
	  { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
	];
	t._runtime_safe_randomized = true;
	const errs = validateTrack(t);
	assert.ok(hasError(errs, 'curve_rle_segments'),
	  `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
	assert.ok(hasMessage(errs, 'race-start curve'),
	  `expected race-start curve message, got: ${JSON.stringify(errs)}`);
  });

  test('B-09d sign near tileset transition fails', () => {
	const t = makeValidTrack(4096);
	t.sign_tileset = [
	  { distance: 0, tileset_offset: 8 },
	  { distance: 1000, tileset_offset: 16 },
	];
	t.sign_data = [
	  { distance: 980, count: 1, sign_id: 0 },
	];
	t._assigned_horizon_override = 0;
	t._runtime_safe_randomized = true;
	t._preserve_original_sign_cadence = false;
	const errs = validateTrack(t);
	assert.ok(hasError(errs, 'sign_data'),
	  `expected error on sign_data, got: ${JSON.stringify(errs)}`);
	assert.ok(hasMessage(errs, 'too close to tileset transition'),
	  `expected tileset-transition message, got: ${JSON.stringify(errs)}`);
  });

  test('B-09e wraparound sign tileset gap fails when last transition is too close to start', () => {
	const t = makeValidTrack(4096);
	t.sign_tileset = [
	  { distance: 0, tileset_offset: 8 },
	  { distance: 3900, tileset_offset: 16 },
	];
	t._runtime_safe_randomized = true;
	t._preserve_original_sign_cadence = false;
	const errs = validateTrack(t);
	assert.ok(hasError(errs, 'sign_tileset'),
	  `expected error on sign_tileset, got: ${JSON.stringify(errs)}`);
	assert.ok(hasMessage(errs, 'wraparound tileset gap'),
	  `expected wraparound tileset gap message, got: ${JSON.stringify(errs)}`);
  });

  // B-10: slope length sum wrong
  test('B-10 slope length sum mismatch', () => {
    const t = makeValidTrack(4096);
    t.slope_rle_segments = [
      { type: 'flat', length: 200, slope_byte: 0, bg_vert_disp: 0 },
      { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'slope_rle_segments'),
      `expected error on slope_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-11: slope_byte invalid (0x35 in undefined range)
  test('B-11 slope_byte 0x35 invalid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.slope_rle_segments = [
      { type: 'slope', length: steps, slope_byte: 0x35, bg_vert_disp: -32 },
      { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'slope_rle_segments'),
      `expected error on slope_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  test('B-11b decoded visual slope displacement outside stock-safe envelope fails', () => {
    const t = makeValidTrack(4096);
    t.slope_initial_bg_disp = 0;
    t.slope_rle_segments = [
      { type: 'slope', length: 80, slope_byte: 0x60, bg_vert_disp: 112 },
      { type: 'flat', length: (4096 / 4) - 80, slope_byte: 0, bg_vert_disp: 0 },
      { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'slope_rle_segments'),
      `expected error on slope_rle_segments, got: ${JSON.stringify(errs)}`);
    assert.ok(hasMessage(errs, 'stock-safe envelope'),
      `expected stock-safe envelope message, got: ${JSON.stringify(errs)}`);
  });

  test('B-11c race-start visual slope safety fails when opening runway is too short', () => {
	const t = makeValidTrack(4096);
	t.slope_initial_bg_disp = 0;
	t.slope_rle_segments = [
	  { type: 'flat', length: 96, slope_byte: 0, bg_vert_disp: 0 },
	  { type: 'slope', length: 16, slope_byte: 0x48, bg_vert_disp: 30 },
	  { type: 'flat', length: (4096 / 4) - 112, slope_byte: 0, bg_vert_disp: 0 },
	  { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
	];
	const errs = validateTrack(t);
	assert.ok(hasError(errs, 'slope_rle_segments'),
	  `expected error on slope_rle_segments, got: ${JSON.stringify(errs)}`);
	assert.ok(hasMessage(errs, 'race-start visual slope'),
	  `expected race-start visual slope message, got: ${JSON.stringify(errs)}`);
  });

  test('B-11d race-start visual slope safety fails when initial background displacement is non-zero', () => {
	const t = makeValidTrack(4096);
	t.slope_initial_bg_disp = 1;
	t.slope_rle_segments = [
	  { type: 'flat', length: 128, slope_byte: 0, bg_vert_disp: 0 },
	  { type: 'slope', length: 16, slope_byte: 0x48, bg_vert_disp: 30 },
	  { type: 'flat', length: (4096 / 4) - 144, slope_byte: 0, bg_vert_disp: 0 },
	  { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
	];
	const errs = validateTrack(t);
	assert.ok(hasError(errs, 'slope_rle_segments'),
	  `expected error on slope_rle_segments, got: ${JSON.stringify(errs)}`);
	assert.ok(hasMessage(errs, 'race-start visual slope'),
	  `expected race-start visual slope message, got: ${JSON.stringify(errs)}`);
  });

  // B-12: slope initial_bg_disp out of signed byte range
  test('B-12 initial_bg_disp out of range', () => {
    const t = makeValidTrack(4096);
    t.slope_initial_bg_disp = 200;  // > 127
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'slope_initial_bg_disp'),
      `expected error on slope_initial_bg_disp, got: ${JSON.stringify(errs)}`);
  });

  // B-13: phys_byte invalid (value 2)
  test('B-13 phys_byte=2 invalid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.phys_slope_rle_segments = [
      { type: 'segment', length: steps, phys_byte: 2 },
      { type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'phys_slope_rle_segments'),
      `expected error on phys_slope_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-14: phys terminator _raw missing high bit
  test('B-14 phys terminator missing high bit', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.phys_slope_rle_segments = [
      { type: 'segment', length: steps, phys_byte: 0 },
      { type: 'terminator', length: 0, phys_byte: 0, _raw: [0x00, 0x00, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'phys_slope_rle_segments'),
      `expected error on phys_slope_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-15: sign_data distance out of bounds
  test('B-15 sign distance >= track_length', () => {
    const t = makeValidTrack(4096);
	  t.sign_data = [{ distance: 10000, count: 1, sign_id: 28 }];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'sign_data'),
      `expected error on sign_data, got: ${JSON.stringify(errs)}`);
  });

  // B-16: sign_data distances not ascending
  test('B-16 sign distances not ascending', () => {
    const t = makeValidTrack(4096);
    t.sign_data = [
	  { distance: 500, count: 1, sign_id: 28 },
	  { distance: 300, count: 1, sign_id: 29 },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'sign_data'),
      `expected error on sign_data, got: ${JSON.stringify(errs)}`);
  });

  // B-17: sign_data count zero
  test('B-17 sign count=0', () => {
    const t = makeValidTrack(4096);
	  t.sign_data = [{ distance: 500, count: 0, sign_id: 28 }];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'sign_data'),
      `expected error on sign_data, got: ${JSON.stringify(errs)}`);
  });

  // B-18: sign_tileset tileset_offset not multiple of 8
  test('B-18 tileset_offset not multiple of 8', () => {
    const t = makeValidTrack(4096);
    t.sign_tileset = [{ distance: 0, tileset_offset: 10 }];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'sign_tileset'),
      `expected error on sign_tileset, got: ${JSON.stringify(errs)}`);
  });

  // B-19: sign_tileset tileset_offset out of range
  test('B-19 tileset_offset > 88', () => {
    const t = makeValidTrack(4096);
    t.sign_tileset = [{ distance: 0, tileset_offset: 96 }];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'sign_tileset'),
      `expected error on sign_tileset, got: ${JSON.stringify(errs)}`);
  });

  // B-20: minimap pair count wrong
  test('B-20 minimap pair count wrong', () => {
    const t = makeValidTrack(4096);
    t.minimap_pos = [[10, 20], [30, 40]];  // only 2, should be 64
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'minimap_pos'),
      `expected error on minimap_pos, got: ${JSON.stringify(errs)}`);
  });

  // B-21: minimap value out of signed byte range
  test('B-21 minimap x out of signed-byte range', () => {
    const t     = makeValidTrack(4096);
    const count = 4096 >> 6;
    const pairs = Array.from({ length: count }, (_, i) => [i % 80, (i * 3) % 80]);
    pairs[0] = [200, 50];  // 200 > 127
    t.minimap_pos = pairs;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'minimap_pos'),
      `expected error on minimap_pos, got: ${JSON.stringify(errs)}`);
  });

  // B-22: minimap pair not length 2
  test('B-22 minimap pair wrong shape', () => {
    const t     = makeValidTrack(4096);
    const count = 4096 >> 6;
    const pairs = Array.from({ length: count }, (_, i) => [i % 80, (i * 3) % 80]);
    pairs[5] = [10];  // missing y
    t.minimap_pos = pairs;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'minimap_pos'),
      `expected error on minimap_pos, got: ${JSON.stringify(errs)}`);
  });

  // B-23: curve_rle_segments is null
  test('B-23 curve_rle_segments=null', () => {
    const t = makeValidTrack();
    t.curve_rle_segments = null;
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });

  // B-24: segment with length=0 (non-terminator)
  test('B-24 segment length=0', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.curve_rle_segments = [
      { type: 'straight', length: 0, curve_byte: 0 },
      { type: 'straight', length: steps, curve_byte: 0 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.ok(hasError(errs, 'curve_rle_segments'),
      `expected error on curve_rle_segments, got: ${JSON.stringify(errs)}`);
  });
}

// ---------------------------------------------------------------------------
// Section C: validate_tracks() aggregate behaviour
// ---------------------------------------------------------------------------
function sectionC() {
  // C-01: two valid tracks => no errors
  test('C-01 two valid tracks => no errors', () => {
    const t1 = makeValidTrack(4096);
    const t2 = makeValidTrack(4160);
    t2.name = 'Test Track 2';
    const errs = validateTracks([t1, t2]);
    assert.strictEqual(errs.length, 0,
      `got ${errs.length} error(s): ${JSON.stringify(errs)}`);
  });

  // C-02: one valid, one invalid => errors only from invalid track
  test('C-02 one invalid track contributes errors', () => {
    const t1 = makeValidTrack(4096);
    const t2 = makeValidTrack(4096);
    t2.name = 'Bad Track';
    t2.track_length = 9999;
    const errs = validateTracks([t1, t2]);
    assert.ok(errs.length > 0, 'expected errors from bad track');
  });

  test('C-02b errors reference the bad track', () => {
    const t1 = makeValidTrack(4096);
    const t2 = makeValidTrack(4096);
    t2.name = 'Bad Track';
    t2.track_length = 9999;
    const errs = validateTracks([t1, t2]);
    assert.ok(errs.some(e => e.trackName === 'Bad Track'),
      `expected error from Bad Track, got: ${JSON.stringify(errs.map(e => e.trackName))}`);
  });

  test('C-02c no errors from valid track', () => {
    const t1 = makeValidTrack(4096);
    const t2 = makeValidTrack(4096);
    t2.name = 'Bad Track';
    t2.track_length = 9999;
    const errs = validateTracks([t1, t2]);
    assert.ok(!errs.some(e => e.trackName === 'Test Track'),
      `unexpected error from valid track: ${JSON.stringify(errs)}`);
  });
}

// ---------------------------------------------------------------------------
// Section D: Valid edge cases that must pass
// ---------------------------------------------------------------------------
function sectionD() {
  // D-01: minimum valid track_length = 64
  test('D-01 track_length=64 valid', () => {
    const t = makeValidTrack(64);
    t.sign_data    = [];
    t.sign_tileset = [];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-02: maximum valid track_length = 8192
  test('D-02 track_length=8192 valid', () => {
    const t    = makeValidTrack(8192);
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-03: empty sign_data is valid
  test('D-03 empty sign_data valid', () => {
    const t    = makeValidTrack(4096);
    t.sign_data = [];
    const errs  = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-04: empty sign_tileset is valid
  test('D-04 empty sign_tileset valid', () => {
    const t       = makeValidTrack(4096);
    t.sign_tileset = [];
    const errs     = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-05: left curve bytes 0x01 and 0x2F valid
  test('D-05 left curve bytes 0x01 and 0x2F valid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    const half  = Math.floor(steps / 2);
    t.curve_rle_segments = [
      { type: 'curve', length: half,         curve_byte: 0x01, bg_disp: 50 },
      { type: 'curve', length: steps - half, curve_byte: 0x2F, bg_disp: 50 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-06: right curve bytes 0x41 and 0x6F valid
  test('D-06 right curve bytes 0x41 and 0x6F valid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    const half  = Math.floor(steps / 2);
    t.curve_rle_segments = [
      { type: 'curve', length: half,         curve_byte: 0x41, bg_disp: 50 },
      { type: 'curve', length: steps - half, curve_byte: 0x6F, bg_disp: 50 },
      { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-07: phys_byte = -1 valid
  test('D-07 phys_byte=-1 valid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.phys_slope_rle_segments = [
      { type: 'segment', length: steps, phys_byte: -1 },
      { type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-08: phys_byte = +1 valid
  test('D-08 phys_byte=+1 valid', () => {
    const t     = makeValidTrack(4096);
    const steps = 4096 / 4;
    t.phys_slope_rle_segments = [
      { type: 'segment', length: steps, phys_byte: 1 },
      { type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] },
    ];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-09: initial_bg_disp extremes valid
  test('D-09 initial_bg_disp=-128 valid', () => {
    const t = makeValidTrack(4096);
    t.slope_initial_bg_disp = -128;
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  test('D-09 initial_bg_disp=+127 valid', () => {
    const t = makeValidTrack(4096);
    t.slope_initial_bg_disp = 127;
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  // D-10: tileset_offset = 0 and 88 valid
  test('D-10 tileset_offset=0 valid', () => {
    const t = makeValidTrack(4096);
    t.sign_tileset = [{ distance: 0, tileset_offset: 0 }];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });

  test('D-10 tileset_offset=88 valid', () => {
    const t = makeValidTrack(4096);
    t.sign_data = [{ distance: 500, count: 1, sign_id: 2 }];
    t.sign_tileset = [{ distance: 0, tileset_offset: 88 }];
    const errs = validateTrack(t);
    assert.strictEqual(errs.length, 0,
      errs.map(e => `${e.field}: ${e.message}`).join('\n'));
  });
}

// ---------------------------------------------------------------------------
// Run all sections
// ---------------------------------------------------------------------------
sectionA();
sectionB();
sectionC();
sectionD();

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
if (require.main === module) {
  console.log(`Results: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

module.exports = { passed, failed };
