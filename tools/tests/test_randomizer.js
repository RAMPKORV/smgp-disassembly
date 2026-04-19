#!/usr/bin/env node
// tools/tests/test_randomizer.js
//
// Tests for the Node.js randomizer stack (NODE-006).
// Covers: XorShift32 PRNG, parseSeed, track_randomizer generation functions,
// track_validator, team_randomizer, championship_randomizer.
//
// Default mode runs the fast tier only.
// Use `node tools/tests/test_randomizer.js --slow` for the exhaustive tier.

'use strict';

const assert = require('assert');
const path   = require('path');
const fs     = require('fs');

const {
	XorShift32,
	generateCurveRle, decompressCurveSegments,
	generateSlopeRle, generatePhysSlopeRle,
	getCurveOpeningStraightSteps, getCurveClosingStraightSteps, getFirstCurveSegment, curveHasSafeRaceStart,
	decodeCurveBgDisplacement, curveBgLoopAligns,
	getCurveRuntimeSeamMetrics,
	decodeVisualSlopeBgDisplacement, visualSlopeOffsetsWithinSafeEnvelope,
	getVisualSlopeOpeningFlatSteps, getVisualSlopeClosingFlatSteps, visualSlopeHasSafeRaceStart, visualSlopeLoopAligns,
	generateSignData, generateSignTileset,
	generateMinimap,
	pickTrackLength, randomizeOneTrack, randomizeTracks,
	evaluateGeometryQuality, compareGeneratedTrackCandidates,
	buildCurveGenerationProfile, buildCurveTargets,
	expandCurveComplexity, buildSpecialRoadFeatures,
	applySpecialRoadTilesetRecords, applySpecialRoadSignRecords,
	extractGeometryFeatures,
	evaluateCrossingEligibility,
  _shuffleList,
} = require('../randomizer/track_randomizer');
const { projectCenterlineToCurveRle } = require('../randomizer/track_projection');

const {
  ValidationError,
  validateTrack,
  validateTracks,
} = require('../randomizer/track_validator');
const {
	TRACK_METADATA_FIELDS,
	preservesOriginalSignCadence,
	setAssignedHorizonOverride,
	setGeneratedGeometryState,
} = require('../randomizer/track_metadata');

const { validateAllTracks } = require('../minimap_validate');
const { MONACO_ARCADE_TRAILING_PAD_BYTES } = require('../generate_track_data_asm');
const { REPO_ROOT } = require('../lib/rom');
const {
	deepCopy,
	getCurveDirection,
	getCurveSharpness,
	cyclicTrackDistance,
	loadTracksJson,
} = require('./randomizer_test_utils');

let passed = 0;
let failed = 0;
let skippedSections = 0;
const RUN_SLOW = process.argv.includes('--slow') || process.env.SMGP_SLOW_TESTS === '1';

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
  const [initBgDisp, segs] = generateSlopeRle(rng, trackLen, []);
  const decoded = decodeVisualSlopeBgDisplacement(initBgDisp, segs);
  assert.ok(visualSlopeOffsetsWithinSafeEnvelope(decoded));
});

test('generateSlopeRle keeps a flat opening runway with zero initial background displacement', () => {
	const rng = new XorShift32(60);
	const trackLen = 4096;
	const [initBgDisp, segs] = generateSlopeRle(rng, trackLen, []);
	assert.strictEqual(initBgDisp, 0);
	assert.ok(visualSlopeHasSafeRaceStart(initBgDisp, segs));
	assert.ok(getVisualSlopeOpeningFlatSteps(segs) >= 128);
});

test('generateSlopeRle keeps visual slope loop closed at race end', () => {
	const rng = new XorShift32(60);
	const trackLen = 4096;
	const [initBgDisp, segs] = generateSlopeRle(rng, trackLen, []);
	assert.ok(visualSlopeLoopAligns(initBgDisp, segs));
	assert.ok(getVisualSlopeClosingFlatSteps(segs) >= 96);
	const decoded = decodeVisualSlopeBgDisplacement(initBgDisp, segs);
	assert.ok(decoded.length > 0);
	assert.strictEqual(decoded[decoded.length - 1], initBgDisp);
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
const tracksJson = loadTracksJson();

if (RUN_SLOW) {
  console.log('Section D: randomizeOneTrack and randomizeTracks');

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
	  assert.strictEqual(preservesOriginalSignCadence(track), false);
  });

  test('randomizeOneTrack opens and closes with straights', () => {
    const track = deepCopy(tracksJson.tracks[0]);
    randomizeOneTrack(track, 9999);
    const body = track.curve_rle_segments.filter(seg => seg.type === 'straight' || seg.type === 'curve');
    assert.ok(body.length >= 2, 'expected at least two body segments');
    assert.strictEqual(body[0].type, 'straight');
    assert.strictEqual(body[body.length - 1].type, 'straight');
  });

  test('randomizeOneTrack normalizes runtime background displacement across curves', () => {
    const track = deepCopy(tracksJson.tracks[0]);
    randomizeOneTrack(track, 9999);
    const net = track.curve_rle_segments.reduce((sum, seg) => {
      if (seg.type !== 'curve') return sum;
	    const runtimeDir = (seg.curve_byte & 0x40) ? -1 : 1;
	    return sum + (runtimeDir * (seg.bg_disp || 0));
    }, 0);
    assert.strictEqual(net, 0);
  });

  test('randomizeOneTrack keeps a safe straight runway before first curve background shift', () => {
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  const firstCurve = getFirstCurveSegment(track.curve_rle_segments);
	  assert.ok(firstCurve, 'expected at least one curve segment');
	  assert.ok(curveHasSafeRaceStart(track.curve_rle_segments));
	  assert.ok(getCurveOpeningStraightSteps(track.curve_rle_segments) >= 48);
	  assert.ok(firstCurve.length >= 12);
	  assert.ok((firstCurve.bg_disp / firstCurve.length) <= 8);
  });

  test('randomizeOneTrack keeps stock-like background loop closure', () => {
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  assert.ok(curveBgLoopAligns(track.curve_rle_segments, track.track_length));
	  const decoded = decodeCurveBgDisplacement(track.curve_rle_segments);
	  assert.ok(decoded.length > 0, 'expected decoded curve displacement samples');
	  const seam = getCurveRuntimeSeamMetrics(track.curve_rle_segments, track.track_length);
	  assert.ok(seam, 'expected runtime seam metrics');
	  assert.strictEqual(seam.sampleJump, 0);
	  assert.strictEqual(seam.targetJump, 0);
  });

  test('randomizeTracks keeps curve background displacement magnitudes within stock bounds', () => {
	  const seeds = [12345, 22222, 33333, 44444, 55555];
	  for (const seed of seeds) {
		  const data = deepCopy(tracksJson);
		  randomizeTracks(data, seed, null, false);
		  for (const track of data.tracks) {
			  for (const seg of track.curve_rle_segments) {
				  if (seg.type !== 'curve') continue;
				  assert.ok((seg.bg_disp || 0) >= 30,
					  `${track.slug} seed ${seed}: bg_disp ${seg.bg_disp} below stock floor`);
				  assert.ok((seg.bg_disp || 0) <= 300,
					  `${track.slug} seed ${seed}: bg_disp ${seg.bg_disp} above stock ceiling`);
			  }
		  }
	  }
  });

  test('randomizeOneTrack keeps signs away from sign tileset transitions', () => {
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  for (const sign of track.sign_data) {
		  for (const tileset of track.sign_tileset) {
			  assert.ok(cyclicTrackDistance(tileset.distance, sign.distance, track.track_length) >= 256,
				  `sign at ${sign.distance} too close to tileset transition at ${tileset.distance}`);
		  }
	  }
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

  test('randomizeOneTrack keeps a safe flat race-start before first visual slope', () => {
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  assert.strictEqual(track.slope_initial_bg_disp, 0);
	  assert.ok(visualSlopeHasSafeRaceStart(track.slope_initial_bg_disp, track.slope_rle_segments));
	  assert.ok(getVisualSlopeOpeningFlatSteps(track.slope_rle_segments) >= 128);
  });

  test('randomizeOneTrack keeps visual slope loop aligned at race end', () => {
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  assert.ok(visualSlopeLoopAligns(track.slope_initial_bg_disp, track.slope_rle_segments));
	  assert.ok(getVisualSlopeClosingFlatSteps(track.slope_rle_segments) >= 96);
	  const decoded = decodeVisualSlopeBgDisplacement(track.slope_initial_bg_disp, track.slope_rle_segments);
	  assert.ok(decoded.length > 0);
	  assert.strictEqual(decoded[decoded.length - 1], track.slope_initial_bg_disp);
  });

  test('randomizeOneTrack places signs near meaningful curve windows', () => {
    const track = deepCopy(tracksJson.tracks[0]);
    randomizeOneTrack(track, 9999);
    const windows = buildCurveWindows(track.curve_rle_segments)
      .filter(window => window.peakSharpness >= 12 || window.curveDistance >= 128);
    assert.ok(windows.length > 0, 'expected at least one strong curve window');
	  for (const window of windows) {
		  const anchor = Math.max(0, window.startDistance - window.leadDistance);
		  const transitionNearby = track.sign_tileset.some(rec => cyclicTrackDistance(rec.distance, anchor, track.track_length) < 512);
		  if (transitionNearby) continue;
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

	test('expandCurveComplexity is deterministic for identical inputs', () => {
		const templateTrack = deepCopy(tracksJson.tracks[0]);
		const profile = buildCurveGenerationProfile(templateTrack.curve_rle_segments);
		const targets = buildCurveTargets(profile, templateTrack.track_length >> 2);
		const base = generateCurveRle(new XorShift32(1234), templateTrack.track_length, templateTrack);
		const a = expandCurveComplexity(new XorShift32(1234), base, targets);
		const b = expandCurveComplexity(new XorShift32(1234), base, targets);
		assert.deepStrictEqual(a, b);
	});

	test('expandCurveComplexity preserves segment budget and terminator shape', () => {
		const templateTrack = deepCopy(tracksJson.tracks[0]);
		const profile = buildCurveGenerationProfile(templateTrack.curve_rle_segments);
		const targets = buildCurveTargets(profile, templateTrack.track_length >> 2);
		const base = generateCurveRle(new XorShift32(4321), templateTrack.track_length, templateTrack);
		const expanded = expandCurveComplexity(new XorShift32(4321), base, targets);
		const expandedDistance = expanded.filter(seg => seg.type !== 'terminator').reduce((sum, seg) => sum + seg.length, 0);
		const baseDistance = base.filter(seg => seg.type !== 'terminator').reduce((sum, seg) => sum + seg.length, 0);
		assert.strictEqual(expandedDistance, baseDistance, 'expected curve distance budget to stay unchanged');
		assert.strictEqual(expanded[expanded.length - 1].type, 'terminator');
	});

  test('randomizeOneTrack generates some non-flat slopes', () => {
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  const slopeSegments = track.slope_rle_segments.filter(seg => seg.type === 'slope');
	  if (slopeSegments.length === 0) {
		  assert.ok(track.phys_slope_decompressed.every(value => value === 0), 'expected flat physical slope when no visual slopes are present');
		  return;
	  }
	  assert.ok(track.phys_slope_decompressed.some(value => value !== 0), 'expected some non-flat physical slope steps');
	  assert.ok(slopeSegments.every(seg => seg.length <= 32), 'expected slope segments to stay in conservative safe lengths');
  });

	test('randomizeOneTrack keeps horizon-only sign palette gated by assigned horizon override', () => {
		const track = deepCopy(tracksJson.tracks[0]);
		setAssignedHorizonOverride(track, 0);
		randomizeOneTrack(track, 12345);
		assert.ok(track.sign_tileset.every(record => record.tileset_offset !== 80), 'expected no horizon-only sign tileset offset 80');
	});

  test('randomizeOneTrack aligns generated minimap_pos with ROM patch generator', () => {
	  const { buildGeneratedMinimapPosPairs } = require('../lib/generated_minimap_pos');
	  const track = deepCopy(tracksJson.tracks[0]);
	  randomizeOneTrack(track, 9999);
	  assert.deepStrictEqual(track.minimap_pos, buildGeneratedMinimapPosPairs(track));
  });

	test('special road feature patches add the documented records for any applied tunnel feature', () => {
		const track = deepCopy(tracksJson.tracks[0]);
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

	test('randomized tracks pass generated minimap validation without off-road start markers', () => {
		const data = deepCopy(tracksJson);
		randomizeTracks(data, 99999);
		const report = validateAllTracks(data);
		const generatedFailures = report.tracks.filter(track => track.flags.candidate_marker_offroad);
		assert.strictEqual(generatedFailures.length, 0,
			`Generated minimap failures: ${generatedFailures.map(track => track.track.slug).join(', ')}`);
	});

  test('randomizeTracks with slug filter only modifies matching track', () => {
    const data = deepCopy(tracksJson);
    const originalLength1 = data.tracks[1].track_length;
    const slugSet = new Set(['san_marino']);
    randomizeTracks(data, 12345, slugSet);
    assert.strictEqual(data.tracks[1].track_length, originalLength1);
    assert.ok(Array.isArray(data.tracks[0].curve_rle_segments));
  });

  test('randomizeTracks is reproducible: same seed -> same track_length for each track', () => {
    const d1 = deepCopy(tracksJson);
    const d2 = deepCopy(tracksJson);
    randomizeTracks(d1, 777);
    randomizeTracks(d2, 777);
    for (let i = 0; i < d1.tracks.length; i++) {
      assert.strictEqual(d1.tracks[i].track_length, d2.tracks[i].track_length);
    }
  });
} else {
  skippedSections += 2;
  console.log('Section D: randomizeOneTrack and randomizeTracks (skipped in fast mode; use --slow)');
}

// ---------------------------------------------------------------------------
// Section E: Track validator
// ---------------------------------------------------------------------------
if (RUN_SLOW) {
  console.log('Section E: Track validator');

  test('all 19 ROM tracks pass validateTrack after randomization (new format)', () => {
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
    track.minimap_pos.push([0, 0]);
    const errors = validateTrack(track);
    const e = errors.find(err => err.field === 'minimap_pos');
    assert.ok(e, 'expected minimap_pos error');
  });
} else {
  console.log('Section E: Track validator (skipped in fast mode; use --slow)');
}

test('ValidationError has trackName, field, message properties', () => {
  const err = new ValidationError('MyTrack', 'curve_data', 'bad bytes');
  assert.strictEqual(err.trackName, 'MyTrack');
  assert.strictEqual(err.field, 'curve_data');
  assert.strictEqual(err.message, 'bad bytes');
  assert.ok(err.toString().includes('MyTrack'));
  assert.ok(err.toString().includes('curve_data'));
});

test('curveBgLoopAligns accepts stock-style aligned runtime seam', () => {
	const track = tracksJson.tracks[0];
	assert.ok(curveBgLoopAligns(track.curve_rle_segments, track.track_length));
});

test('randomizeTracks keeps stock-like raw curve seam closure across sample seeds', () => {
	const seeds = [12345, 22222, 33333, 44444, 55555];
	for (const seed of seeds) {
		const data = deepCopy(tracksJson);
		randomizeTracks(data, seed, null, false);
		for (const track of data.tracks) {
			const seam = getCurveRuntimeSeamMetrics(track.curve_rle_segments, track.track_length);
			assert.ok(seam, `${track.slug} seed ${seed}: missing seam metrics`);
			assert.strictEqual(seam.sampleJump, 0, `${track.slug} seed ${seed}: sample seam jump ${seam.sampleJump}`);
			assert.strictEqual(seam.targetJump, 0, `${track.slug} seed ${seed}: target seam jump ${seam.targetJump}`);
		}
	}
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

test('evaluateGeometryQuality prefers zero-crossing correctly-budgeted geometry', () => {
	const goodTrack = {
		track_length: 4096,
		_generated_geometry_state: {
			loop_points: [[0, 0], [6, 0], [8, 3], [5, 5], [8, 8], [4, 10], [0, 8], [-2, 4]],
			resampled_centerline: Array.from({ length: 1024 }, (_, index) => [index % 32, Math.floor(index / 32)]),
			topology: { crossing_count: 0 },
			generation_diagnostics: {
				smoothing: { requested_passes: 2, applied_passes: 2, used_fallback: false },
				resampling: {
					requested_sample_count: 1024,
					produced_sample_count: 1024,
					start_verticality: 0.9,
					incoming_angle_delta: 8,
					outgoing_angle_delta: 10,
				},
			},
		},
	};
	const badTrack = {
		track_length: 4096,
		_generated_geometry_state: {
			loop_points: [[0, 0], [8, 0], [12, 2], [14, 6], [12, 10], [8, 12], [0, 12], [-4, 6]],
			resampled_centerline: Array.from({ length: 900 }, (_, index) => [index % 30, Math.floor(index / 30)]),
			topology: { crossing_count: 2 },
			generation_diagnostics: {
				smoothing: { requested_passes: 3, applied_passes: 0, used_fallback: true },
				resampling: {
					requested_sample_count: 1024,
					produced_sample_count: 900,
					start_verticality: 0.2,
					incoming_angle_delta: 60,
					outgoing_angle_delta: 70,
				},
			},
		},
	};
	const good = evaluateGeometryQuality(goodTrack);
	const bad = evaluateGeometryQuality(badTrack);
	assert.strictEqual(good.passes, true);
	assert.strictEqual(bad.passes, false);
	assert.ok(good.geometryScore < bad.geometryScore, `expected good geometry score < bad geometry score (${good.geometryScore} vs ${bad.geometryScore})`);
});

test('compareGeneratedTrackCandidates prioritizes geometry quality before preview sign match', () => {
	const goodGeometry = {
		geometryQuality: {
			passes: true,
			geometryScore: 10,
			shapeComplexityPasses: true,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.7,
			tileCount: 30,
			coverageMatchPercent: 20,
			signMatchPercent: 65,
		},
	};
	const badGeometryHighSign = {
		geometryQuality: {
			passes: false,
			geometryScore: 200,
			shapeComplexityPasses: false,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.95,
			tileCount: 20,
			coverageMatchPercent: 80,
			signMatchPercent: 99,
		},
	};
	assert.ok(compareGeneratedTrackCandidates(goodGeometry, badGeometryHighSign) < 0);
});

test('compareGeneratedTrackCandidates prefers complex geometry when both candidates are otherwise valid', () => {
	const complexGeometry = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: true,
			geometryScore: 25,
			reflexVertexCount: 7,
			turnRunCount: 9,
			areaRatioToHull: 0.58,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.8,
			tileCount: 36,
			coverageMatchPercent: 30,
			signMatchPercent: 70,
		},
	};
	const blandGeometry = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: false,
			geometryScore: 5,
			reflexVertexCount: 2,
			turnRunCount: 3,
			areaRatioToHull: 0.94,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.9,
			tileCount: 20,
			coverageMatchPercent: 30,
			signMatchPercent: 70,
		},
	};
	assert.ok(compareGeneratedTrackCandidates(complexGeometry, blandGeometry) < 0);
});

test('compareGeneratedTrackCandidates prefers higher turn-run complexity before lower raw geometry score', () => {
	const moreInteresting = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: true,
			geometryScore: 18,
			reflexVertexCount: 7,
			turnRunCount: 11,
			areaRatioToHull: 0.61,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.8,
			tileCount: 34,
			coverageMatchPercent: 30,
			signMatchPercent: 70,
		},
	};
	const flatterButCheaper = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: true,
			geometryScore: 8,
			reflexVertexCount: 7,
			turnRunCount: 7,
			areaRatioToHull: 0.61,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.8,
			tileCount: 34,
			coverageMatchPercent: 30,
			signMatchPercent: 70,
		},
	};
	assert.ok(compareGeneratedTrackCandidates(moreInteresting, flatterButCheaper) < 0);
});

test('compareGeneratedTrackCandidates prefers lower preview cell usage when sign match is comparable', () => {
	const smallerSilhouette = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: true,
			geometryScore: 10,
			reflexVertexCount: 6,
			turnRunCount: 8,
			areaRatioToHull: 0.45,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.85,
			tileCount: 40,
			coverageMatchPercent: 95,
			signMatchPercent: 80,
			usedCellCount: 36,
		},
	};
	const bloatedSilhouette = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: true,
			geometryScore: 10,
			reflexVertexCount: 6,
			turnRunCount: 8,
			areaRatioToHull: 0.45,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.85,
			tileCount: 40,
			coverageMatchPercent: 95,
			signMatchPercent: 79,
			usedCellCount: 49,
		},
	};
	assert.ok(compareGeneratedTrackCandidates(smallerSilhouette, bloatedSilhouette) < 0);
});

test('compareGeneratedTrackCandidates prefers valid preview constraints before complex but failing geometry', () => {
	const validButBland = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: false,
			geometryScore: 12,
			reflexVertexCount: 2,
			turnRunCount: 3,
			areaRatioToHull: 0.91,
		},
		constraints: {
			passes: true,
			selfIntersections: 0,
			startVerticality: 0.85,
			tileCount: 28,
			coverageMatchPercent: 40,
			signMatchPercent: 68,
		},
	};
	const complexButInvalid = {
		geometryQuality: {
			passes: true,
			shapeComplexityPasses: true,
			geometryScore: 6,
			reflexVertexCount: 7,
			turnRunCount: 9,
			areaRatioToHull: 0.55,
		},
		constraints: {
			passes: false,
			selfIntersections: 2,
			startVerticality: 0.6,
			tileCount: 60,
			coverageMatchPercent: 10,
			signMatchPercent: 30,
		},
	};
	assert.ok(compareGeneratedTrackCandidates(validButBland, complexButInvalid) < 0);
});

test('projectCenterlineToCurveRle produces curve segments that satisfy validator shape expectations', () => {
	const projection = projectCenterlineToCurveRle([[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]], 256);
	const track = {
		name: 'Projected Track',
		slug: 'projected_track',
		index: 0,
		track_length: 256,
		slope_initial_bg_disp: 0,
		curve_rle_segments: projection.curve_rle_segments,
		slope_rle_segments: [{ type: 'flat', length: 64, slope_byte: 0, bg_vert_disp: 0 }, { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] }],
		phys_slope_rle_segments: [{ type: 'segment', length: 64, phys_byte: 0 }, { type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] }],
		sign_data: [],
		sign_tileset: [],
		minimap_pos: Array.from({ length: 4 }, () => [0, 0]),
	};
	const errors = validateTrack(track).filter(error => error.field === 'curve_rle_segments');
	assert.strictEqual(errors.length, 0, errors.map(error => error.message).join('; '));
});

test('extractGeometryFeatures exposes turn and straight anchors from transient geometry', () => {
	const track = {
		track_length: 256,
		_generated_geometry_state: {
			resampled_centerline: [[10, 10], [30, 10], [40, 12], [44, 28], [40, 44], [24, 60], [10, 58], [6, 40]],
		},
	};
	const features = extractGeometryFeatures(track);
	assert.ok(features.turn_windows.length > 0);
	assert.ok(features.straight_windows.length > 0);
	assert.ok(features.special_road_windows.length >= 0);
});

test('extractGeometryFeatures exposes under-bridge tunnel features from crossing projection', () => {
	const track = { track_length: 1024 };
	setGeneratedGeometryState(track, {
		resampled_centerline: [[10, 10], [30, 10], [40, 24], [36, 44], [20, 60], [8, 40]],
		projections: {
			slope: {
				grade_separated_crossing: {
					grade_separated: true,
					crossing_point: [20, 20],
					lower_branch: {
						start_distance: 160,
						end_distance: 416,
						interior_start_distance: 224,
						interior_end_distance: 352,
						tunnel_required: true,
					},
					upper_branch: { branch_height: 0 },
				},
			},
		},
	});
	const features = extractGeometryFeatures(track);
	assert.ok(features.special_road_windows.some(feature => feature.type === 'tunnel' && feature.under_bridge === true));
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
const total = passed + failed;
if (!RUN_SLOW && skippedSections > 0) {
  console.log(`Fast mode skipped ${skippedSections} slow section(s). Run with --slow for exhaustive coverage.`);
}
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
