#!/usr/bin/env node
// tools/tests/test_randomizer.js
//
// Tests for the Node.js randomizer stack (NODE-006).
// Covers: XorShift32 PRNG, parseSeed, track_randomizer generation functions,
// track_validator, team_randomizer, championship_randomizer.

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');

const {
  XorShift32,
  deriveSubseed,
  parseSeed,
  MOD_TRACK_CURVES, MOD_TRACK_SLOPES, MOD_TRACK_SIGNS, MOD_TRACK_MINIMAP,
  MOD_TRACK_CONFIG, MOD_TEAMS, MOD_AI, MOD_CHAMPIONSHIP,
  FLAG_TRACKS, FLAG_TRACK_CONFIG, FLAG_TEAMS, FLAG_AI,
  FLAG_CHAMPIONSHIP, FLAG_SIGNS, FLAG_ALL,
  CHAMPIONSHIP_ART_SETS, CHAMPIONSHIP_TRACK_NAMES,
  generateCurveRle, decompressCurveSegments,
  generateSlopeRle, generatePhysSlopeRle,
  decodeVisualSlopeBgDisplacement, visualSlopeOffsetsWithinSafeEnvelope,
  generateSignData, generateSignTileset,
  generateMinimap,
  randomizeArtConfig, buildTrackConfigAsm,
  pickTrackLength, randomizeOneTrack, randomizeTracks,
  buildCurveGenerationProfile, buildCurveTargets,
  expandCurveComplexity, buildSpecialRoadFeatures,
  applySpecialRoadTilesetRecords, applySpecialRoadSignRecords,
  _shuffleList,
} = require('../randomizer/track_randomizer');

const {
  ValidationError,
  validateTrack,
  validateTracks,
} = require('../randomizer/track_validator');

const {
  randomizeTeams,
  randomizeAi,
  validateTeams,
  ACCEL_INDEX_POOL,
  ENGINE_INDEX_POOL,
  TIRE_WEAR_POOL,
  STEERING_IDX_RANGE,
  BRAKING_IDX_RANGE,
  AI_FACTOR_MIN,
  AI_FACTOR_MAX,
  AI_SCORE_MIN,
  AI_SCORE_MAX,
  TIRE_DELTA_MIN,
  TIRE_DELTA_MAX,
} = require('../randomizer/team_randomizer');

const {
  randomizeChampionship,
  validateChampionship,
  NUM_CHAMPIONSHIP_TRACKS,
  FIXED_FINAL_SLOT,
  RIVAL_BASE_MIN,
  RIVAL_BASE_MAX,
  RIVAL_DELTA_MIN,
  RIVAL_DELTA_MAX,
  LAP_TIME_TABLE_BYTES,
} = require('../randomizer/championship_randomizer');

const { buildGeneratedMinimapAssetsAsm } = require('../lib/generated_minimap_assets');
const { validateAllTracks } = require('../minimap_validate');
const { buildGeneratedTrackBlock, GENERATED_MINIMAP_DATA_FILE } = require('../generate_track_data_asm');
const { writeAlignedBlock } = require('../patch_all_track_minimap_assets_rom');
const { readJson } = require('../lib/json');
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

function deepCopy(obj) {
  return JSON.parse(JSON.stringify(obj));
}

function getCurveDirection(curveByte) {
  if (curveByte >= 0x41 && curveByte <= 0x6F) return 1;
  if (curveByte >= 0x01 && curveByte <= 0x2F) return -1;
  return 0;
}

function getCurveSharpness(curveByte) {
  return curveByte & 0x3F;
}

function buildCurveWindows(curveSegments) {
  const windows = [];
  const MAX_BRIDGE_STEPS = 12;
  let step = 0;
  let bridgeSteps = 0;
  let current = null;

  function finishCurrent() {
    if (!current) return;
    current.startDistance = current.startStep << 2;
    current.endDistance = current.endStep << 2;
    current.curveDistance = current.totalCurveSteps << 2;
    current.leadDistance = Math.max(96, Math.min(256,
      Math.round(72 + (current.peakSharpness * 4) + (current.curveDistance * 0.18))
    ));
    windows.push(current);
    current = null;
    bridgeSteps = 0;
  }

  for (const seg of curveSegments || []) {
    if (seg.type !== 'straight' && seg.type !== 'curve') continue;

    if (seg.type === 'curve') {
      const direction = getCurveDirection(seg.curve_byte);
      const sharpness = getCurveSharpness(seg.curve_byte);
      if (!current || current.direction !== direction || bridgeSteps > MAX_BRIDGE_STEPS) {
        finishCurrent();
        current = {
          direction,
          startStep: step,
          endStep: step + seg.length,
          totalCurveSteps: 0,
          peakSharpness: 0,
        };
      }
      current.endStep = step + seg.length;
      current.totalCurveSteps += seg.length;
      current.peakSharpness = Math.max(current.peakSharpness, sharpness);
      bridgeSteps = 0;
    } else if (current) {
      bridgeSteps += seg.length;
      if (bridgeSteps <= MAX_BRIDGE_STEPS) current.endStep = step + seg.length;
      else finishCurrent();
    }

    step += seg.length;
  }

  finishCurrent();
  return windows.filter(window => window.totalCurveSteps >= 6 && window.peakSharpness >= 3);
}

function hasSignNearDistance(signs, distance, radius) {
  return signs.some(sign => Math.abs(sign.distance - distance) <= radius);
}

function countTightDirectionChanges(curveSegments) {
	const curves = (curveSegments || []).filter(seg => seg.type === 'curve');
	let count = 0;
	for (let i = 1; i < curves.length; i++) {
		if (getCurveDirection(curves[i].curve_byte) !== getCurveDirection(curves[i - 1].curve_byte)) count += 1;
	}
	return count;
}

function countUltraSharpCurves(curveSegments) {
	return (curveSegments || [])
		.filter(seg => seg.type === 'curve' && getCurveSharpness(seg.curve_byte) <= 4)
		.length;
}

// ---------------------------------------------------------------------------
// Section A: XorShift32 PRNG
// ---------------------------------------------------------------------------
console.log('Section A: XorShift32 PRNG');

test('XorShift32 produces non-zero output for seed 1', () => {
  const rng = new XorShift32(1);
  const v = rng.next();
  assert.ok(v !== 0, 'expected non-zero');
});

test('XorShift32 is reproducible with same seed', () => {
  const a = new XorShift32(42);
  const b = new XorShift32(42);
  for (let i = 0; i < 20; i++) {
    assert.strictEqual(a.next(), b.next());
  }
});

test('XorShift32 produces different sequences for different seeds', () => {
  const a = new XorShift32(1);
  const b = new XorShift32(2);
  const seqA = Array.from({ length: 10 }, () => a.next());
  const seqB = Array.from({ length: 10 }, () => b.next());
  assert.notDeepStrictEqual(seqA, seqB);
});

test('XorShift32.randInt returns value in [lo, hi]', () => {
  const rng = new XorShift32(999);
  for (let i = 0; i < 100; i++) {
    const v = rng.randInt(5, 10);
    assert.ok(v >= 5 && v <= 10, `${v} out of [5,10]`);
  }
});

test('XorShift32.randFloat returns value in [0, 1)', () => {
  const rng = new XorShift32(7);
  for (let i = 0; i < 50; i++) {
    const v = rng.randFloat();
    assert.ok(v >= 0 && v < 1, `${v} out of [0,1)`);
  }
});

test('XorShift32.choice returns an element from the array', () => {
  const rng = new XorShift32(3);
  const items = ['a', 'b', 'c'];
  for (let i = 0; i < 30; i++) {
    const v = rng.choice(items);
    assert.ok(items.includes(v));
  }
});

test('XorShift32.weightedChoice respects weights (sanity test)', () => {
  const rng = new XorShift32(12345);
  const counts = { a: 0, b: 0 };
  for (let i = 0; i < 1000; i++) {
    const v = rng.weightedChoice(['a', 'b'], [1, 9]);
    counts[v]++;
  }
  // b should appear roughly 9x more than a
  assert.ok(counts.b > counts.a * 3, `expected b >> a, got a=${counts.a} b=${counts.b}`);
});

test('XorShift32 seed 0 is treated as seed 1 (same state)', () => {
  const rng0 = new XorShift32(0);
  const rng1 = new XorShift32(1);
  assert.strictEqual(rng0.next(), rng1.next());
});

// ---------------------------------------------------------------------------
// Section B: parseSeed and deriveSubseed
// ---------------------------------------------------------------------------
console.log('Section B: parseSeed and deriveSubseed');

test('parseSeed parses valid seed SMGP-1-01-12345', () => {
  const [version, flags, seed] = parseSeed('SMGP-1-01-12345');
  assert.strictEqual(version, 1);
  assert.strictEqual(flags, 0x01);
  assert.strictEqual(seed, 12345);
});

test('parseSeed parses uppercase hex flags SMGP-1-3F-99999', () => {
  const [version, flags, seed] = parseSeed('SMGP-1-3F-99999');
  assert.strictEqual(flags, 0x3F);
  assert.strictEqual(seed, 99999);
});

test('parseSeed parses lowercase hex flags SMGP-1-0c-1', () => {
  const [, flags, seed] = parseSeed('SMGP-1-0c-1');
  assert.strictEqual(flags, 0x0C);
  assert.strictEqual(seed, 1);
});

test('parseSeed parses FLAG_ALL seed SMGP-1-3F-1', () => {
  const [, flags] = parseSeed('SMGP-1-3F-1');
  assert.strictEqual(flags, FLAG_ALL);
});

test('parseSeed throws on invalid format', () => {
  assert.throws(() => parseSeed('INVALID'), /Invalid seed format/);
  assert.throws(() => parseSeed('SMGP-1-01'), /Invalid seed format/);
  assert.throws(() => parseSeed('smgp-1-01-123'), /Invalid seed format/);
});

test('deriveSubseed returns different values for different module IDs', () => {
  const sub1 = deriveSubseed(12345, MOD_TRACK_CURVES);
  const sub2 = deriveSubseed(12345, MOD_TRACK_SLOPES);
  const sub3 = deriveSubseed(12345, MOD_TEAMS);
  assert.notStrictEqual(sub1, sub2);
  assert.notStrictEqual(sub1, sub3);
  assert.notStrictEqual(sub2, sub3);
});

test('deriveSubseed is reproducible with same inputs', () => {
  const a = deriveSubseed(9999, MOD_AI);
  const b = deriveSubseed(9999, MOD_AI);
  assert.strictEqual(a, b);
});

test('deriveSubseed returns non-zero', () => {
  for (const mod of [MOD_TRACK_CURVES, MOD_TRACK_SLOPES, MOD_TEAMS, MOD_CHAMPIONSHIP]) {
    const v = deriveSubseed(1, mod);
    assert.ok(v !== 0, `subseed 0 for mod ${mod}`);
  }
});

test('flag constants have expected values', () => {
  assert.strictEqual(FLAG_TRACKS,       0x01);
  assert.strictEqual(FLAG_TRACK_CONFIG, 0x02);
  assert.strictEqual(FLAG_TEAMS,        0x04);
  assert.strictEqual(FLAG_AI,           0x08);
  assert.strictEqual(FLAG_CHAMPIONSHIP, 0x10);
  assert.strictEqual(FLAG_SIGNS,        0x20);
  assert.strictEqual(FLAG_ALL,          0x3F);
});

// ---------------------------------------------------------------------------
// Section C: Track randomizer — generation primitives
// ---------------------------------------------------------------------------
console.log('Section C: Track randomizer — generation');

test('pickTrackLength returns multiple of 64', () => {
  const rng = new XorShift32(42);
  for (let i = 0; i < 20; i++) {
    const len = pickTrackLength(rng);
    assert.strictEqual(len % 64, 0, `${len} not multiple of 64`);
  }
});

test('pickTrackLength(rng, false) returns value in a reasonable range [64, 8192]', () => {
  const rng = new XorShift32(1);
  for (let i = 0; i < 20; i++) {
    const len = pickTrackLength(rng, false);
    assert.ok(len >= 64 && len <= 8192, `${len} out of plausible range`);
    assert.strictEqual(len % 64, 0);
  }
});

test('pickTrackLength(rng, true) returns smaller preliminary length', () => {
  const rng = new XorShift32(1);
  for (let i = 0; i < 20; i++) {
    const len = pickTrackLength(rng, true);
    assert.ok(len >= 64 && len <= 4000, `prelim ${len} out of expected range`);
    assert.strictEqual(len % 64, 0);
  }
});

test('generateCurveRle returns array ending with terminator (type=terminator, curve_byte=0xFF)', () => {
  const rng = new XorShift32(100);
  const segs = generateCurveRle(rng, 1024);
  assert.ok(Array.isArray(segs));
  assert.ok(segs.length > 0);
  const last = segs[segs.length - 1];
  assert.strictEqual(last.type, 'terminator');
  assert.strictEqual(last.curve_byte, 0xFF);
});

test('generateCurveRle decompressed length equals trackLength/4 (excluding sentinel)', () => {
  const rng = new XorShift32(200);
  const trackLen = 1024;
  const segs = generateCurveRle(rng, trackLen);
  let total = 0;
  for (const seg of segs) {
    if (seg.type === 'straight' || seg.type === 'curve') total += seg.length;
  }
  assert.strictEqual(total, trackLen / 4);
});

test('generateCurveRle segments use valid curve_byte values', () => {
  const rng = new XorShift32(300);
  const segs = generateCurveRle(rng, 640);
  for (const seg of segs) {
    const cb = seg.curve_byte;
    const ok = cb === 0x00 ||
               (cb >= 0x01 && cb <= 0x2F) ||
               (cb >= 0x41 && cb <= 0x6F) ||
               cb === 0xFF;
    assert.ok(ok, `invalid curve_byte 0x${cb.toString(16)}`);
  }
});

test('decompressCurveSegments produces array of length steps+1 (steps + sentinel)', () => {
  const rng = new XorShift32(50);
  const trackLen = 512;
  const segs = generateCurveRle(rng, trackLen);
  const decompressed = decompressCurveSegments(segs);
  // decompressCurveSegments pushes CURVE_SENTINEL for the terminator
  assert.strictEqual(decompressed.length, trackLen / 4 + 1);
});

test('generateSlopeRle returns [initialBgDisp, segments]', () => {
  const rng = new XorShift32(50);
  const result = generateSlopeRle(rng, 1024, []);
  assert.ok(Array.isArray(result) && result.length === 2);
  const [initBgDisp, segs] = result;
  assert.ok(typeof initBgDisp === 'number');
  assert.ok(Array.isArray(segs));
});

test('generateSlopeRle segments end with terminator (type=terminator, slope_byte=0xFF)', () => {
  const rng = new XorShift32(60);
  const [, segs] = generateSlopeRle(rng, 512, []);
  assert.ok(segs.length > 0);
  const last = segs[segs.length - 1];
  assert.strictEqual(last.type, 'terminator');
  assert.strictEqual(last.slope_byte, 0xFF);
});

test('generateSlopeRle total decompressed length equals trackLength/4', () => {
  const rng = new XorShift32(60);
  const trackLen = 512;
  const [, segs] = generateSlopeRle(rng, trackLen, []);
  let total = 0;
  for (const seg of segs) {
    if (seg.type !== 'terminator') total += seg.length;
  }
  assert.strictEqual(total, trackLen / 4);
});

test('generateSlopeRle keeps decoded visual slope offsets within stock-safe envelope', () => {
  const rng = new XorShift32(60);
  const trackLen = 4096;
  const [, segs] = generateSlopeRle(rng, trackLen, []);
  const decoded = decodeVisualSlopeBgDisplacement(0, segs);
  assert.ok(visualSlopeOffsetsWithinSafeEnvelope(decoded));
});

test('generatePhysSlopeRle returns array ending with terminator (_raw[0] has high bit)', () => {
  const rng = new XorShift32(77);
  // Need slope segments (without terminator) to pass in
  const [, slopeSegs] = generateSlopeRle(rng, 512, []);
  const segs = generatePhysSlopeRle(rng, 512, slopeSegs);
  assert.ok(Array.isArray(segs));
  const last = segs[segs.length - 1];
  assert.strictEqual(last.type, 'terminator');
  assert.ok((last._raw[0] & 0x80) !== 0, 'phys slope terminator must have high bit');
});

test('generateSignData returns array of records (no 0xFFFF sentinel)', () => {
  const rng = new XorShift32(88);
  const [tilesets] = generateSignTileset(rng, 2048, []);
  const signs = generateSignData(rng, 2048, [], tilesets);
  assert.ok(Array.isArray(signs));
  // No sentinel — the sign_data validator expects plain records
  for (const rec of signs) {
    assert.ok(rec.distance !== 0xFFFF, 'unexpected 0xFFFF sentinel in sign_data');
    assert.ok(typeof rec.count === 'number');
    assert.ok(typeof rec.sign_id === 'number');
  }
});

test('generateSignData distances are ascending', () => {
  const rng = new XorShift32(99);
  const [tilesets] = generateSignTileset(rng, 2048, []);
  const signs = generateSignData(rng, 2048, [], tilesets);
  for (let i = 1; i < signs.length; i++) {
    assert.ok(signs[i].distance > signs[i - 1].distance,
      `sign[${i}].distance=${signs[i].distance} not > sign[${i-1}].distance=${signs[i-1].distance}`);
  }
});

test('generateSignTileset returns [records, trailing] where records have tileset_offset key', () => {
  const rng = new XorShift32(11);
  const result = generateSignTileset(rng, 1024, []);
  assert.ok(Array.isArray(result) && result.length === 2);
  const [records] = result;
  assert.ok(Array.isArray(records) && records.length > 0);
  for (const rec of records) {
    assert.ok('tileset_offset' in rec, 'expected tileset_offset key');
    assert.ok('distance' in rec, 'expected distance key');
  }
});

test('generateSignTileset tileset_offset values are multiples of 8 in [0, 88]', () => {
  const rng = new XorShift32(22);
  const [records] = generateSignTileset(rng, 2048, []);
  for (const rec of records) {
    assert.strictEqual(rec.tileset_offset % 8, 0, `tileset_offset ${rec.tileset_offset} not multiple of 8`);
    assert.ok(rec.tileset_offset >= 0 && rec.tileset_offset <= 88,
      `tileset_offset ${rec.tileset_offset} out of [0,88]`);
  }
});

// ---------------------------------------------------------------------------
// Section D: randomizeOneTrack and randomizeTracks
// ---------------------------------------------------------------------------
console.log('Section D: randomizeOneTrack and randomizeTracks');

const tracksJson = readJson(path.join(REPO_ROOT, 'tools/data/tracks.json'));

test('generateMinimap returns [intPairs, trailing] with count == trackLength >> 6', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 33);
  const [pairs] = generateMinimap(track);
  assert.strictEqual(pairs.length, track.track_length >> 6);
});

test('generateMinimap coordinates are [x, y] integer pairs', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 44);
  const [pairs] = generateMinimap(track);
  for (const pt of pairs) {
    assert.ok(Array.isArray(pt) && pt.length === 2, 'expected [x,y] pair');
    assert.ok(typeof pt[0] === 'number' && typeof pt[1] === 'number');
  }
});

test('randomizeOneTrack produces a track that passes validateTrack', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 12345);
  const errors = validateTrack(track);
  assert.strictEqual(errors.length, 0,
    `Validation errors: ${errors.map(e => e.toString()).join('; ')}`);
});

test('randomizeOneTrack is reproducible with same seed', () => {
  const t1 = deepCopy(tracksJson.tracks[0]);
  const t2 = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(t1, 42);
  randomizeOneTrack(t2, 42);
  assert.deepStrictEqual(t1.curve_rle_segments, t2.curve_rle_segments);
  assert.deepStrictEqual(t1.slope_rle_segments, t2.slope_rle_segments);
  assert.deepStrictEqual(t1.minimap_pos, t2.minimap_pos);
});

test('randomizeOneTrack produces different output for different seeds', () => {
  const t1 = deepCopy(tracksJson.tracks[0]);
  const t2 = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(t1, 1);
  randomizeOneTrack(t2, 2);
  assert.notDeepStrictEqual(t1.curve_rle_segments, t2.curve_rle_segments);
});

test('randomizeOneTrack sets track_length, curve_rle_segments, slope_rle_segments, minimap_pos', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  assert.ok(typeof track.track_length === 'number');
  assert.ok(Array.isArray(track.curve_rle_segments));
  assert.ok(Array.isArray(track.slope_rle_segments));
  assert.ok(Array.isArray(track.minimap_pos));
});

test('randomizeOneTrack keeps generated sign cadence mode enabled for validator safety', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  assert.strictEqual(track._preserve_original_sign_cadence, false);
});

test('randomizeOneTrack opens and closes with straights', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  const body = track.curve_rle_segments.filter(seg => seg.type === 'straight' || seg.type === 'curve');
  assert.ok(body.length >= 2, 'expected at least two body segments');
  assert.strictEqual(body[0].type, 'straight');
  assert.strictEqual(body[body.length - 1].type, 'straight');
});

test('randomizeOneTrack normalizes net background displacement across curves', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  const net = track.curve_rle_segments.reduce((sum, seg) => {
    if (seg.type !== 'curve') return sum;
    return sum + (getCurveDirection(seg.curve_byte) * (seg.bg_disp || 0));
  }, 0);
  assert.strictEqual(net, 0);
});

test('randomizeOneTrack uses physical slopes only for interior of visual slopes', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  let slopeStep = 0;
  for (const seg of track.slope_rle_segments) {
    if (seg.type === 'terminator') break;
    if (seg.type === 'flat') {
      for (let i = 0; i < seg.length; i++) {
        assert.strictEqual(track.phys_slope_decompressed[slopeStep + i], 0);
      }
    } else if (seg.type === 'slope') {
      const direction = getCurveDirection(seg.slope_byte);
      const shoulder = Math.min(8, Math.floor(seg.length / 4));
      const coreStart = slopeStep + shoulder;
      const coreEnd = slopeStep + seg.length - shoulder;
      for (let i = slopeStep; i < slopeStep + seg.length; i++) {
        const expected = (i >= coreStart && i < coreEnd) ? direction : 0;
        assert.strictEqual(track.phys_slope_decompressed[i], expected);
      }
    }
    slopeStep += seg.length;
  }
});

test('randomizeOneTrack keeps decoded visual slope offsets within stock-safe envelope', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  const decoded = decodeVisualSlopeBgDisplacement(track.slope_initial_bg_disp, track.slope_rle_segments);
  assert.ok(visualSlopeOffsetsWithinSafeEnvelope(decoded));
});

test('randomizeOneTrack places signs near meaningful curve windows', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  const windows = buildCurveWindows(track.curve_rle_segments)
    .filter(window => window.peakSharpness >= 12 || window.curveDistance >= 128);
  assert.ok(windows.length > 0, 'expected at least one strong curve window');
  for (const window of windows) {
    const anchor = Math.max(0, window.startDistance - window.leadDistance);
    assert.ok(
      hasSignNearDistance(track.sign_data, anchor, 160),
      `expected sign near curve window at ${anchor}`
    );
  }
});

test('randomizeOneTrack changes sign tilesets before strong curve windows with safe spacing', () => {
  const track = deepCopy(tracksJson.tracks[0]);
  randomizeOneTrack(track, 9999);
  for (let i = 1; i < track.sign_tileset.length; i++) {
    const gap = track.sign_tileset[i].distance - track.sign_tileset[i - 1].distance;
    assert.ok(gap >= 1500, `tileset gap ${gap} must be >= 1500`);
  }

  const strongWindows = buildCurveWindows(track.curve_rle_segments)
    .filter(window => window.peakSharpness >= 12 || window.curveDistance >= 128);
  assert.ok(strongWindows.length > 0, 'expected at least one strong curve window');
  const plannedWindows = strongWindows.filter(window =>
    track.sign_tileset.some(rec => rec.distance <= window.startDistance && (window.startDistance - rec.distance) <= 320)
  );
  assert.ok(plannedWindows.length > 0, 'expected at least one nearby tileset change before a strong curve window');
});

test('expandCurveComplexity adds chicanes and sharp turns for technical templates', () => {
	const templateTrack = deepCopy(tracksJson.tracks.find(track => track.slug === 'usa'));
	const profile = buildCurveGenerationProfile(templateTrack.curve_rle_segments);
	const targets = buildCurveTargets(profile, templateTrack.track_length >> 2);
	const rng = new XorShift32(1234);
	const base = generateCurveRle(rng, templateTrack.track_length, templateTrack);
	const expanded = expandCurveComplexity(new XorShift32(1234), base, targets);
	assert.ok(countTightDirectionChanges(expanded) >= countTightDirectionChanges(base), 'expected at least as many direction changes');
	assert.ok(countUltraSharpCurves(expanded) >= 2, 'expected at least two ultra-sharp curves');
});

test('randomizeOneTrack adds a few ultra-sharp turns', () => {
	const track = deepCopy(tracksJson.tracks.find(track => track.slug === 'portugal'));
	randomizeOneTrack(track, 24680);
	assert.ok(countUltraSharpCurves(track.curve_rle_segments) >= 2, 'expected at least two ultra-sharp turns');
});

test('special road features add tunnel-style sign and tileset records when present', () => {
	const track = deepCopy(tracksJson.tracks.find(track => track.slug === 'monaco'));
	const features = buildSpecialRoadFeatures(new XorShift32(5), track.track_length, track.curve_rle_segments);
	const [tileset] = generateSignTileset(new XorShift32(5), track.track_length, track.curve_rle_segments);
	const signData = generateSignData(new XorShift32(5), track.track_length, track.curve_rle_segments, tileset);
	const patchedTileset = applySpecialRoadTilesetRecords(tileset, features);
	const patchedSigns = applySpecialRoadSignRecords(signData, features);
	for (const feature of features) {
		if (!feature._applied) continue;
		assert.ok(patchedTileset.some(rec => rec.tileset_offset === 88 && rec.distance === feature.tilesetDistance));
		assert.ok(patchedSigns.some(rec => rec.sign_id === 49 && rec.distance === feature.entrySignDistance));
		assert.ok(patchedSigns.some(rec => rec.sign_id === 2 && rec.distance === feature.interiorDistance));
		assert.ok(patchedSigns.some(rec => rec.sign_id === 50 && rec.distance === feature.exitSignDistance));
	}
});

test('randomizeTracks on all 19 tracks produces all passing validation', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 99999);
  const errors = validateTracks(data.tracks);
  assert.strictEqual(errors.length, 0,
    `Validation errors: ${errors.map(e => e.toString()).join('; ')}`);
});

test('randomized tracks pass generated minimap validation', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 99999);
  const report = validateAllTracks(data);
  const generatedFailures = report.tracks.filter(track => track.flags.candidate_marker_offroad);
  assert.strictEqual(generatedFailures.length, 0,
    `Generated minimap failures: ${generatedFailures.map(track => track.track.slug).join(', ')}`);
});

test('randomizeTracks with slug filter only modifies matching track', () => {
  const data = deepCopy(tracksJson);
  // Record original curve_rle_segments for an unfiltered track
  // (they won't have curve_rle_segments yet, so check track_length)
  const originalLength1 = data.tracks[1].track_length;
  const slugSet = new Set(['san_marino']);
  randomizeTracks(data, 12345, slugSet);
  // Non-filtered track should still have its original track_length (unchanged)
  assert.strictEqual(data.tracks[1].track_length, originalLength1);
  // Filtered track should have new curve_rle_segments
  assert.ok(Array.isArray(data.tracks[0].curve_rle_segments));
});

test('randomizeTracks is reproducible: same seed → same track_length for each track', () => {
  const d1 = deepCopy(tracksJson);
  const d2 = deepCopy(tracksJson);
  randomizeTracks(d1, 777);
  randomizeTracks(d2, 777);
  for (let i = 0; i < d1.tracks.length; i++) {
    assert.strictEqual(d1.tracks[i].track_length, d2.tracks[i].track_length);
  }
});

// ---------------------------------------------------------------------------
// Section E: Track validator
// ---------------------------------------------------------------------------
console.log('Section E: Track validator');

test('all 19 ROM tracks pass validateTrack after randomization (new format)', () => {
  // The validator uses the new _rle_segments format written by randomizeOneTrack
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 54321);
  for (const track of data.tracks) {
    const errors = validateTrack(track);
    assert.strictEqual(errors.length, 0,
      `[${track.name}] errors: ${errors.map(e => e.toString()).join('; ')}`);
  }
});

test('validateTracks on all randomized tracks returns empty array', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 11111);
  const errors = validateTracks(data.tracks);
  assert.strictEqual(errors.length, 0);
});

test('validateTrack catches missing curve_rle_segments', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  delete track.curve_rle_segments;
  const errors = validateTrack(track);
  const e = errors.find(err => err.field === 'curve_rle_segments');
  assert.ok(e, 'expected curve_rle_segments error');
});

test('validateTrack catches negative track_length', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  track.track_length = -64;
  const errors = validateTrack(track);
  assert.ok(errors.length > 0);
});

test('validateTrack catches track_length > 8192', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  track.track_length = 8256;
  const errors = validateTrack(track);
  const e = errors.find(err => err.field === 'track_length');
  assert.ok(e, 'expected track_length error');
});

test('validateTrack catches track_length not multiple of 64', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  track.track_length = 1000;
  const errors = validateTrack(track);
  const e = errors.find(err => err.field === 'track_length');
  assert.ok(e, 'expected track_length error');
});

test('validateTrack catches wrong curve segment total length', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  // Add an extra step to first non-terminator segment
  const firstSeg = track.curve_rle_segments.find(s => s.type !== 'terminator');
  firstSeg.length += 1;
  const errors = validateTrack(track);
  assert.ok(errors.length > 0);
});

test('validateTrack catches missing curve terminator', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  track.curve_rle_segments = track.curve_rle_segments.filter(s => s.type !== 'terminator');
  const errors = validateTrack(track);
  assert.ok(errors.length > 0);
});

test('validateTrack catches wrong minimap count', () => {
  const data = deepCopy(tracksJson);
  randomizeTracks(data, 1);
  const track = deepCopy(data.tracks[0]);
  track.minimap_pos.push([0, 0]);  // one too many
  const errors = validateTrack(track);
  const e = errors.find(err => err.field === 'minimap_pos');
  assert.ok(e, 'expected minimap_pos error');
});

test('ValidationError has trackName, field, message properties', () => {
  const err = new ValidationError('MyTrack', 'curve_data', 'bad bytes');
  assert.strictEqual(err.trackName, 'MyTrack');
  assert.strictEqual(err.field, 'curve_data');
  assert.strictEqual(err.message, 'bad bytes');
  assert.ok(err.toString().includes('MyTrack'));
  assert.ok(err.toString().includes('curve_data'));
});

// ---------------------------------------------------------------------------
// Section F: Team randomizer
// ---------------------------------------------------------------------------
console.log('Section F: Team randomizer');

const teamsJson = readJson(path.join(REPO_ROOT, 'tools/data/teams.json'));

test('ROM teams JSON validates clean before randomization', () => {
  const errors = validateTeams(teamsJson);
  assert.strictEqual(errors.length, 0,
    `ROM teams validation errors: ${errors.join('; ')}`);
});

test('randomizeTeams produces valid team data', () => {
  const data = deepCopy(teamsJson);
  randomizeTeams(data, 12345);
  const errors = validateTeams(data);
  assert.strictEqual(errors.length, 0,
    `Post-randomize team errors: ${errors.join('; ')}`);
});

test('randomizeAi produces valid team data', () => {
  const data = deepCopy(teamsJson);
  randomizeAi(data, 54321);
  const errors = validateTeams(data);
  assert.strictEqual(errors.length, 0,
    `Post-AI-randomize errors: ${errors.join('; ')}`);
});

test('randomizeTeams + randomizeAi combined produce valid data', () => {
  const data = deepCopy(teamsJson);
  randomizeTeams(data, 11111);
  randomizeAi(data, 11111);
  const errors = validateTeams(data);
  assert.strictEqual(errors.length, 0,
    `Combined randomize errors: ${errors.join('; ')}`);
});

test('randomizeTeams is reproducible with same seed', () => {
  const d1 = deepCopy(teamsJson);
  const d2 = deepCopy(teamsJson);
  randomizeTeams(d1, 7777);
  randomizeTeams(d2, 7777);
  assert.deepStrictEqual(
    d1.team_car_characteristics.map(c => c.accel_index),
    d2.team_car_characteristics.map(c => c.accel_index)
  );
});

test('randomizeTeams produces different result for different seeds', () => {
  const d1 = deepCopy(teamsJson);
  const d2 = deepCopy(teamsJson);
  randomizeTeams(d1, 1);
  randomizeTeams(d2, 2);
  const seq1 = d1.team_car_characteristics.map(c => c.accel_index).join(',');
  const seq2 = d2.team_car_characteristics.map(c => c.accel_index).join(',');
  assert.notStrictEqual(seq1, seq2);
});

test('randomizeTeams preserves accel_index pool as exact multiset', () => {
  const data = deepCopy(teamsJson);
  const originalPool = data.team_car_characteristics.map(c => c.accel_index).sort((a,b) => a-b);
  randomizeTeams(data, 42);
  const newPool = data.team_car_characteristics.map(c => c.accel_index).sort((a,b) => a-b);
  assert.deepStrictEqual(newPool, originalPool);
});

test('randomizeTeams preserves engine_index pool as exact multiset', () => {
  const data = deepCopy(teamsJson);
  const originalPool = data.team_car_characteristics.map(c => c.engine_index).sort((a,b) => a-b);
  randomizeTeams(data, 42);
  const newPool = data.team_car_characteristics.map(c => c.engine_index).sort((a,b) => a-b);
  assert.deepStrictEqual(newPool, originalPool);
});

test('randomizeTeams all accel_index values are in ACCEL_INDEX_POOL', () => {
  const data = deepCopy(teamsJson);
  randomizeTeams(data, 999);
  const pool = new Set(ACCEL_INDEX_POOL);
  for (const car of data.team_car_characteristics) {
    assert.ok(pool.has(car.accel_index), `accel_index ${car.accel_index} not in pool`);
  }
});

test('randomizeTeams all engine_index values are in ENGINE_INDEX_POOL', () => {
  const data = deepCopy(teamsJson);
  randomizeTeams(data, 888);
  const pool = new Set(ENGINE_INDEX_POOL);
  for (const car of data.team_car_characteristics) {
    assert.ok(pool.has(car.engine_index), `engine_index ${car.engine_index} not in pool`);
  }
});

test('randomizeAi preserves ai_performance_factor pool as multiset', () => {
  const data = deepCopy(teamsJson);
  const originalPool = data.ai_performance_factor.map(f => f.factor).sort((a,b) => a-b);
  randomizeAi(data, 555);
  const newPool = data.ai_performance_factor.map(f => f.factor).sort((a,b) => a-b);
  assert.deepStrictEqual(newPool, originalPool);
});

test('randomizeAi partner_threshold >= promote_threshold + 2 for all teams', () => {
  const data = deepCopy(teamsJson);
  randomizeAi(data, 321);
  for (const t of data.post_race_driver_target_points) {
    assert.ok(t.partner_threshold >= t.promote_threshold + 2,
      `${t.name}: partner=${t.partner_threshold} must be >= promote=${t.promote_threshold}+2`);
  }
});

// ---------------------------------------------------------------------------
// Section G: Championship randomizer
// ---------------------------------------------------------------------------
console.log('Section G: Championship randomizer');

const champJson = readJson(path.join(REPO_ROOT, 'tools/data/championship.json'));

test('ROM championship JSON validates clean before randomization', () => {
  const errors = validateChampionship(champJson);
  assert.strictEqual(errors.length, 0,
    `ROM championship validation errors: ${errors.join('; ')}`);
});

test('randomizeChampionship produces valid data', () => {
  const data = deepCopy(champJson);
  randomizeChampionship(data, 12345);
  const errors = validateChampionship(data);
  assert.strictEqual(errors.length, 0,
    `Post-randomize championship errors: ${errors.join('; ')}`);
});

test('randomizeChampionship Monaco stays in final slot', () => {
  const data = deepCopy(champJson);
  randomizeChampionship(data, 99999);
  const order = data._meta.championship_track_order;
  assert.strictEqual(order[FIXED_FINAL_SLOT], 'Monaco');
});

test('randomizeChampionship track order is a valid permutation (no duplicates)', () => {
  const data = deepCopy(champJson);
  randomizeChampionship(data, 77777);
  const order = data._meta.championship_track_order;
  assert.strictEqual(order.length, NUM_CHAMPIONSHIP_TRACKS);
  assert.strictEqual(new Set(order).size, NUM_CHAMPIONSHIP_TRACKS,
    'duplicate track in championship order');
});

test('randomizeChampionship contains the same set of tracks as original', () => {
  const data = deepCopy(champJson);
  const originalSet = new Set(champJson._meta.championship_track_order);
  randomizeChampionship(data, 11111);
  const newSet = new Set(data._meta.championship_track_order);
  for (const track of originalSet) {
    assert.ok(newSet.has(track), `track ${track} missing after randomization`);
  }
});

test('randomizeChampionship is reproducible with same seed', () => {
  const d1 = deepCopy(champJson);
  const d2 = deepCopy(champJson);
  randomizeChampionship(d1, 5555);
  randomizeChampionship(d2, 5555);
  assert.deepStrictEqual(d1._meta.championship_track_order, d2._meta.championship_track_order);
  assert.deepStrictEqual(d1.rival_grid_base_table, d2.rival_grid_base_table);
});

test('randomizeChampionship rival_grid_base values are in [0, 15]', () => {
  const data = deepCopy(champJson);
  randomizeChampionship(data, 33333);
  for (let i = 0; i < data.rival_grid_base_table.length; i++) {
    const v = data.rival_grid_base_table[i];
    assert.ok(v >= RIVAL_BASE_MIN && v <= RIVAL_BASE_MAX,
      `rival_base[${i}]=${v} out of [${RIVAL_BASE_MIN},${RIVAL_BASE_MAX}]`);
  }
});

test('randomizeChampionship rival_grid_delta values are in [-3, 2]', () => {
  const data = deepCopy(champJson);
  randomizeChampionship(data, 22222);
  for (let i = 0; i < data.rival_grid_delta_table.length; i++) {
    const v = data.rival_grid_delta_table[i];
    assert.ok(v >= RIVAL_DELTA_MIN && v <= RIVAL_DELTA_MAX,
      `rival_delta[${i}]=${v} out of [${RIVAL_DELTA_MIN},${RIVAL_DELTA_MAX}]`);
  }
});

test('randomizeChampionship pre_race_lap_time_offset_table has correct length', () => {
  const data = deepCopy(champJson);
  randomizeChampionship(data, 44444);
  assert.strictEqual(data.pre_race_lap_time_offset_table.length, LAP_TIME_TABLE_BYTES);
});

test('validateChampionship rejects non-Monaco final slot', () => {
  const data = deepCopy(champJson);
  // Swap Monaco out of final slot
  const monacoIdx = data._meta.championship_track_order.indexOf('Monaco');
  data._meta.championship_track_order[monacoIdx] = data._meta.championship_track_order[0];
  data._meta.championship_track_order[0] = 'Monaco';
  const errors = validateChampionship(data);
  assert.ok(errors.length > 0, 'expected validation error for Monaco not in final slot');
});

test('validateChampionship rejects duplicate track', () => {
  const data = deepCopy(champJson);
  data._meta.championship_track_order[0] = data._meta.championship_track_order[1];
  const errors = validateChampionship(data);
  assert.ok(errors.length > 0, 'expected validation error for duplicate track');
});

// ---------------------------------------------------------------------------
// Section H: Art config (RAND-006)
// ---------------------------------------------------------------------------
console.log('Section H: Art config');

test('CHAMPIONSHIP_ART_SETS has 16 entries', () => {
  assert.strictEqual(CHAMPIONSHIP_ART_SETS.length, 16);
});

test('CHAMPIONSHIP_TRACK_NAMES has 16 entries', () => {
  assert.strictEqual(CHAMPIONSHIP_TRACK_NAMES.length, 16);
});

test('randomizeArtConfig returns 16 entries', () => {
  const assignment = randomizeArtConfig(12345);
  assert.strictEqual(assignment.length, 16);
});

test('randomizeArtConfig is a permutation of CHAMPIONSHIP_ART_SETS', () => {
  const assignment = randomizeArtConfig(99);
  const originalNames = new Set(CHAMPIONSHIP_ART_SETS.map(s => JSON.stringify(s)));
  for (const artSet of assignment) {
    assert.ok(originalNames.has(JSON.stringify(artSet)),
      `art set not from original pool: ${JSON.stringify(artSet)}`);
  }
  // All distinct (no duplicates)
  const assignedNames = assignment.map(s => JSON.stringify(s));
  assert.strictEqual(new Set(assignedNames).size, 16, 'duplicate art sets in assignment');
});

test('randomizeArtConfig is reproducible with same seed', () => {
  const a = randomizeArtConfig(777);
  const b = randomizeArtConfig(777);
  assert.deepStrictEqual(a, b);
});

test('randomizeArtConfig produces different result for different seeds', () => {
  const a = randomizeArtConfig(1);
  const b = randomizeArtConfig(2);
  assert.notDeepStrictEqual(a, b);
});

test('buildTrackConfigAsm runs without throwing', () => {
  const assignment = randomizeArtConfig(42);
  const asmPath = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
  assert.doesNotThrow(() => {
    buildTrackConfigAsm(assignment, asmPath);
  });
});

test('buildTrackConfigAsm output contains 16 track comment headers', () => {
  const assignment = randomizeArtConfig(42);
  const asmPath = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
  const result = buildTrackConfigAsm(assignment, asmPath);
  let count = 0;
  for (const name of CHAMPIONSHIP_TRACK_NAMES) {
    if (result.includes(`; ${name}`)) count++;
  }
  assert.strictEqual(count, 16, `expected 16 track headers, found ${count}`);
});

test('buildGeneratedMinimapAssetsAsm emits labels for all tracks', () => {
  const result = buildGeneratedMinimapAssetsAsm(tracksJson.tracks);
  assert.ok(result.content.includes('Generated_Minimap_Track_00_San_Marino_tiles:'));
  assert.ok(result.content.includes('Generated_Minimap_Track_17_Monaco_Arcade_Main_tiles:'));
  assert.ok(result.content.includes('Generated_Minimap_Track_18_Monaco_Arcade_Wet_map:'));
});

test('buildGeneratedTrackBlock excludes generated minimap include by default', () => {
  const asm = buildGeneratedTrackBlock();
  assert.ok(!asm.includes(`\tinclude\t"${GENERATED_MINIMAP_DATA_FILE}"`));
});

test('buildGeneratedTrackBlock can include generated minimap include when requested', () => {
  const asm = buildGeneratedTrackBlock({ includeGeneratedMinimapData: true });
  assert.ok(asm.includes(`\tinclude\t"${GENERATED_MINIMAP_DATA_FILE}"`));
});

test('writeAlignedBlock appends after current ROM length without truncating larger ROMs', () => {
  const rom = Buffer.alloc(0x90010, 0xFF);
  const bytes = Buffer.from([0x12, 0x34, 0x56]);
  const cursor = 0x90000;
  const block = writeAlignedBlock(rom, cursor, bytes);
  assert.strictEqual(block.start, 0x90000);
  assert.strictEqual(block.end, 0x90003);
  assert.strictEqual(rom[0x90000], 0x12);
  assert.strictEqual(rom[0x90001], 0x34);
  assert.strictEqual(rom[0x90002], 0x56);
});

test('generated track block preserves canonical track block size using fallback symbol map', () => {
  const symbolMap = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json'), 'utf8')).symbols;
  const start = parseInt(symbolMap.San_Marino_curve_data, 16);
  const blob = parseInt(symbolMap.Monaco_arcade_post_sign_tileset_blob, 16);
  const blobSize = fs.statSync(path.join(REPO_ROOT, 'data', 'tracks', 'monaco_arcade', 'post_sign_tileset_blob.bin')).size;
  const baselineFullSize = (blob - start) + blobSize;
  const asm = buildGeneratedTrackBlock({
    includeGeneratedMinimapData: false,
    preBlobPadBytes: 2399,
    padBytes: 0,
  });
  let total = 0;
  for (const line of asm.split(/\r?\n/)) {
    const incbin = line.match(/^\s*incbin\s+\"([^\"]+)\"/i);
    if (incbin) {
      const filePath = path.join(REPO_ROOT, incbin[1]);
      if (fs.existsSync(filePath)) total += fs.statSync(filePath).size;
      continue;
    }
    const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
    if (dcb) total += parseInt(dcb[1], 10);
  }
  assert.strictEqual(total, baselineFullSize);
});

test('_shuffleList returns array of same length with same elements', () => {
  const rng = new XorShift32(42);
  const arr = [1, 2, 3, 4, 5];
  const shuffled = _shuffleList(arr, rng);
  assert.strictEqual(shuffled.length, arr.length);
  assert.deepStrictEqual(shuffled.slice().sort((a,b) => a-b), arr.slice().sort((a,b) => a-b));
});

test('_shuffleList does not mutate original array', () => {
  const rng = new XorShift32(42);
  const original = [1, 2, 3, 4, 5];
  const copy = original.slice();
  _shuffleList(original, rng);
  assert.deepStrictEqual(original, copy);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
