// tools/randomizer/track_validator.js
//
// RAND-007: Track validation module.
//
// Validates that a track object (as produced by extract_track_data or the
// randomizer) is well-formed and should produce a playable track.
//
// Two entry points:
//   validateTrack(track)   -> ValidationError[]   (single track)
//   validateTracks(tracks) -> ValidationError[]   (array of track objects)
//
// A ValidationError has:
//   .trackName  string   human-readable track name
//   .field      string   which field/sub-section failed
//   .message    string   description of the failure
//
// Usage (standalone):
//   node tools/randomizer/track_validator.js [--input tools/data/tracks.json]
//                                            [--verbose]

'use strict';

const path = require('path');
const { decodeVisualSlopeBgDisplacement, visualSlopeOffsetsWithinSafeEnvelope } = require('./track_randomizer');

const CURVE_RAM_LIMIT = 0x800;
const VISUAL_SLOPE_RAM_LIMIT = 0x1000;
const PHYS_SLOPE_RAM_LIMIT = 0x1000;

// ---------------------------------------------------------------------------
// ValidationError
// ---------------------------------------------------------------------------
class ValidationError {
  constructor(trackName, field, message) {
    this.trackName = trackName;
    this.field     = field;
    this.message   = message;
  }

  toString() {
    return `[${this.trackName}] ${this.field}: ${this.message}`;
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function _err(errors, trackName, field, message) {
  errors.push(new ValidationError(trackName, field, message));
}

function _signedByteOk(v) {
  return Number.isInteger(v) && v >= -128 && v <= 127;
}

const TILESET_SIGN_ID_MAP = new Map([
	[0,  new Set([0, 1, 8, 10, 11, 28, 29, 30, 31])],
	[8,  new Set([0, 1, 8, 9, 10, 11, 28, 29, 30, 31])],
	[16, new Set([0, 1, 4, 5, 8, 9, 31, 48, 49])],
	[24, new Set([0, 1, 8, 9, 16, 17, 30])],
	[32, new Set([0, 1, 8, 9, 10, 11, 20, 21, 22, 30, 31])],
	[40, new Set([0, 1, 8, 9, 10, 24, 25, 26, 27, 30, 31])],
	[48, new Set([0, 1, 8, 11, 31, 32, 33])],
	[56, new Set([0, 1, 8, 9, 10, 11, 30, 31, 36, 37, 39, 49])],
	[64, new Set([0, 1, 8, 9, 31, 40, 41])],
	[72, new Set([0, 1, 8, 9, 10, 44, 45, 46])],
	[80, new Set([0, 1, 12, 13, 14, 15])],
	[88, new Set([2, 50])],
]);

// ---------------------------------------------------------------------------
// Per-field validators
// ---------------------------------------------------------------------------

function _validateTrackLength(track, errors) {
  const name = track.name || '?';
  const tl = track.track_length;

  if (!Number.isInteger(tl) || tl <= 0) {
    _err(errors, name, 'track_length', `must be a positive integer, got ${JSON.stringify(tl)}`);
    return false;
  }
  if (tl % 64 !== 0) {
    _err(errors, name, 'track_length', `${tl} is not a multiple of 64`);
    return false;
  }
  if (tl < 64) {
    _err(errors, name, 'track_length', `${tl} < minimum 64`);
    return false;
  }
  if (tl > 8192) {
    _err(errors, name, 'track_length', `${tl} > maximum 8192`);
    return false;
  }
  return true;
}

function _validateCurveRle(track, errors) {
  const name = track.name || '?';
  const tl   = track.track_length || 0;
  const segs = track.curve_rle_segments;

  if (!Array.isArray(segs)) {
    _err(errors, name, 'curve_rle_segments', 'missing or not an array');
    return;
  }
  if (segs.length === 0) {
    _err(errors, name, 'curve_rle_segments', 'empty segment list (need at least 1 segment + terminator)');
    return;
  }

  const expectedSteps = tl ? Math.floor(tl / 4) : 0;
  let totalLength = 0;
  let terminatorCount = 0;
  let terminatorNotLast = false;

  for (let i = 0; i < segs.length; i++) {
    const seg = segs[i];
    const segType = seg.type || '';

    if (segType === 'terminator') {
      terminatorCount++;
      if (i !== segs.length - 1) terminatorNotLast = true;
      const cb = seg.curve_byte !== undefined ? seg.curve_byte : 0xFF;
      if (cb !== 0xFF) {
        _err(errors, name, 'curve_rle_segments',
          `segment ${i}: terminator has curve_byte=0x${cb.toString(16).padStart(2,'0').toUpperCase()} (expected 0xFF)`);
      }
      continue;
    }

    const length = seg.length;
    if (!Number.isInteger(length) || length <= 0) {
      _err(errors, name, 'curve_rle_segments',
        `segment ${i} (${JSON.stringify(segType)}): length=${JSON.stringify(length)} must be a positive int`);
    }

    const curveByte = seg.curve_byte !== undefined ? seg.curve_byte : -1;
    if (segType === 'straight') {
      if (curveByte !== 0x00) {
        _err(errors, name, 'curve_rle_segments',
          `segment ${i} (straight): curve_byte=0x${curveByte.toString(16).padStart(2,'0').toUpperCase()} (expected 0x00)`);
      }
    } else if (segType === 'curve') {
      if (!((curveByte >= 0x01 && curveByte <= 0x2F) || (curveByte >= 0x41 && curveByte <= 0x6F))) {
        _err(errors, name, 'curve_rle_segments',
          `segment ${i} (curve): curve_byte=0x${curveByte.toString(16).padStart(2,'0').toUpperCase()} outside valid ranges [0x01-0x2F left] [0x41-0x6F right]`);
      }
      const bgDisp = seg.bg_disp;
      if (!Number.isInteger(bgDisp) || bgDisp < -32768 || bgDisp > 32767) {
        _err(errors, name, 'curve_rle_segments',
          `segment ${i} (curve): bg_disp=${JSON.stringify(bgDisp)} must be a signed 16-bit integer`);
      }
    } else {
      _err(errors, name, 'curve_rle_segments',
        `segment ${i}: unknown type ${JSON.stringify(segType)}`);
    }

    totalLength += Number.isInteger(length) ? length : 0;
  }

  if (terminatorCount === 0) {
    _err(errors, name, 'curve_rle_segments', 'missing terminator segment');
  } else if (terminatorCount > 1) {
    _err(errors, name, 'curve_rle_segments',
      `${terminatorCount} terminator segments found (expected exactly 1)`);
  }
  if (terminatorNotLast) {
    _err(errors, name, 'curve_rle_segments', 'terminator is not the last segment');
  }
  if (tl && totalLength !== expectedSteps) {
    _err(errors, name, 'curve_rle_segments',
      `total segment length ${totalLength} != track_length//4 = ${expectedSteps}`);
  }
  if (expectedSteps > CURVE_RAM_LIMIT) {
    _err(errors, name, 'curve_rle_segments',
      `decompressed curve stream ${expectedSteps} bytes exceeds RAM budget ${CURVE_RAM_LIMIT}`);
  }
}

function _validateSlopeRle(track, errors) {
  const name = track.name || '?';
  const tl   = track.track_length || 0;
  const segs = track.slope_rle_segments;
  const init = track.slope_initial_bg_disp !== undefined ? track.slope_initial_bg_disp : 0;

  if (!Array.isArray(segs)) {
    _err(errors, name, 'slope_rle_segments', 'missing or not an array');
    return;
  }
  if (!_signedByteOk(init)) {
    _err(errors, name, 'slope_initial_bg_disp',
      `${JSON.stringify(init)} must be a signed byte (-128 to 127)`);
  }

  const expectedSteps = tl ? Math.floor(tl / 4) : 0;
  let totalLength = 0;
  let terminatorCount = 0;
  let terminatorNotLast = false;

  for (let i = 0; i < segs.length; i++) {
    const seg = segs[i];
    const segType = seg.type || '';

    if (segType === 'terminator') {
      terminatorCount++;
      if (i !== segs.length - 1) terminatorNotLast = true;
      continue;
    }

    const length = seg.length;
    if (!Number.isInteger(length) || length <= 0) {
      _err(errors, name, 'slope_rle_segments',
        `segment ${i} (${JSON.stringify(segType)}): length=${JSON.stringify(length)} must be a positive int`);
    }

    const slopeByte = seg.slope_byte !== undefined ? seg.slope_byte : -1;
    if (segType === 'flat') {
      if (slopeByte !== 0x00) {
        _err(errors, name, 'slope_rle_segments',
          `segment ${i} (flat): slope_byte=0x${slopeByte.toString(16).padStart(2,'0').toUpperCase()} (expected 0x00)`);
      }
      const bvd = seg.bg_vert_disp !== undefined ? seg.bg_vert_disp : 0;
      if (bvd !== 0) {
        _err(errors, name, 'slope_rle_segments',
          `segment ${i} (flat): bg_vert_disp=${bvd} (expected 0 for flat segment)`);
      }
    } else if (segType === 'slope') {
      if (!((slopeByte >= 0x01 && slopeByte <= 0x2F) || (slopeByte >= 0x41 && slopeByte <= 0x6F))) {
        _err(errors, name, 'slope_rle_segments',
          `segment ${i} (slope): slope_byte=0x${slopeByte.toString(16).padStart(2,'0').toUpperCase()} outside valid ranges [0x01-0x2F down] [0x41-0x6F up]`);
      }
      const bvd = seg.bg_vert_disp !== undefined ? seg.bg_vert_disp : 0;
      if (!_signedByteOk(bvd)) {
        _err(errors, name, 'slope_rle_segments',
          `segment ${i} (slope): bg_vert_disp=${JSON.stringify(bvd)} must be a signed byte`);
      }
    } else {
      _err(errors, name, 'slope_rle_segments',
        `segment ${i}: unknown type ${JSON.stringify(segType)}`);
    }

    totalLength += Number.isInteger(length) ? length : 0;
  }

  if (terminatorCount === 0) {
    _err(errors, name, 'slope_rle_segments', 'missing terminator segment');
  } else if (terminatorCount > 1) {
    _err(errors, name, 'slope_rle_segments',
      `${terminatorCount} terminator segments found (expected exactly 1)`);
  }
  if (terminatorNotLast) {
    _err(errors, name, 'slope_rle_segments', 'terminator is not the last segment');
  }
  if (tl && totalLength !== expectedSteps) {
    _err(errors, name, 'slope_rle_segments',
      `total segment length ${totalLength} != track_length//4 = ${expectedSteps}`);
  }
  if (expectedSteps > VISUAL_SLOPE_RAM_LIMIT) {
    _err(errors, name, 'slope_rle_segments',
      `decompressed visual slope stream ${expectedSteps} bytes exceeds RAM budget ${VISUAL_SLOPE_RAM_LIMIT}`);
  }

	if (Array.isArray(segs) && segs.some(seg => seg.type === 'slope') && _signedByteOk(init)) {
		const decodedOffsets = decodeVisualSlopeBgDisplacement(init, segs);
		if (!visualSlopeOffsetsWithinSafeEnvelope(decodedOffsets)) {
			let globalMin = Infinity;
			let globalMax = -Infinity;
			let startMin = Infinity;
			let startMax = -Infinity;
			const startWindow = Math.min(decodedOffsets.length, 128);
			for (let i = 0; i < decodedOffsets.length; i++) {
				const value = decodedOffsets[i];
				if (value < globalMin) globalMin = value;
				if (value > globalMax) globalMax = value;
				if (i < startWindow) {
					if (value < startMin) startMin = value;
					if (value > startMax) startMax = value;
				}
			}
			_err(errors, name, 'slope_rle_segments',
				`decoded background vertical displacement is outside stock-safe envelope (global ${globalMin}..${globalMax}, first128 ${startMin}..${startMax})`);
		}
	}
}

function _validatePhysSlopeRle(track, errors) {
  const name = track.name || '?';
  const tl   = track.track_length || 0;
  const segs = track.phys_slope_rle_segments;

  if (!Array.isArray(segs)) {
    _err(errors, name, 'phys_slope_rle_segments', 'missing or not an array');
    return;
  }

  const expectedSteps = tl ? Math.floor(tl / 4) : 0;
  let totalLength = 0;
  let terminatorCount = 0;
  let terminatorNotLast = false;

  for (let i = 0; i < segs.length; i++) {
    const seg = segs[i];
    const segType = seg.type || '';

    if (segType === 'terminator') {
      terminatorCount++;
      if (i !== segs.length - 1) terminatorNotLast = true;
      const raw = seg._raw;
      if (raw && raw.length > 0 && (raw[0] & 0x80) === 0) {
        _err(errors, name, 'phys_slope_rle_segments',
          `terminator _raw[0]=0x${raw[0].toString(16).padStart(2,'0').toUpperCase()} does not have high bit set`);
      }
      continue;
    }

    if (segType !== 'segment') {
      _err(errors, name, 'phys_slope_rle_segments',
        `segment ${i}: unknown type ${JSON.stringify(segType)}`);
      continue;
    }

    const length = seg.length;
    if (!Number.isInteger(length) || length <= 0) {
      _err(errors, name, 'phys_slope_rle_segments',
        `segment ${i}: length=${JSON.stringify(length)} must be a positive int`);
    }

    const physByte = seg.phys_byte;
    if (physByte !== -1 && physByte !== 0 && physByte !== 1) {
      _err(errors, name, 'phys_slope_rle_segments',
        `segment ${i}: phys_byte=${JSON.stringify(physByte)} must be -1, 0, or +1 (ROM invariant)`);
    }

    totalLength += Number.isInteger(length) ? length : 0;
  }

  if (terminatorCount === 0) {
    _err(errors, name, 'phys_slope_rle_segments', 'missing terminator segment');
  } else if (terminatorCount > 1) {
    _err(errors, name, 'phys_slope_rle_segments',
      `${terminatorCount} terminator segments found (expected exactly 1)`);
  }
  if (terminatorNotLast) {
    _err(errors, name, 'phys_slope_rle_segments', 'terminator is not the last segment');
  }
  if (tl && totalLength !== expectedSteps) {
    _err(errors, name, 'phys_slope_rle_segments',
      `total segment length ${totalLength} != track_length//4 = ${expectedSteps}`);
  }
  if (expectedSteps > PHYS_SLOPE_RAM_LIMIT) {
    _err(errors, name, 'phys_slope_rle_segments',
      `decompressed physical slope stream ${expectedSteps} bytes exceeds RAM budget ${PHYS_SLOPE_RAM_LIMIT}`);
  }
}

function _validateSignData(track, errors) {
  const name = track.name || '?';
  const tl   = track.track_length || 0;
  const recs = track.sign_data;

  if (!Array.isArray(recs)) {
    _err(errors, name, 'sign_data', 'missing or not an array');
    return;
  }

  let prevDist = -1;
  for (let i = 0; i < recs.length; i++) {
    const rec    = recs[i];
    const dist   = rec.distance;
    const count  = rec.count;
    const signId = rec.sign_id;

    if (!Number.isInteger(dist) || dist < 0) {
      _err(errors, name, 'sign_data',
        `record ${i}: distance=${JSON.stringify(dist)} must be a non-negative integer`);
    } else if (tl && dist >= tl) {
      _err(errors, name, 'sign_data',
        `record ${i}: distance=${dist} >= track_length=${tl}`);
    } else if (dist <= prevDist) {
      _err(errors, name, 'sign_data',
        `record ${i}: distance=${dist} not strictly greater than previous ${prevDist} (must be ascending)`);
    }

    if (!Number.isInteger(count) || count <= 0) {
      _err(errors, name, 'sign_data',
        `record ${i}: count=${JSON.stringify(count)} must be a positive integer`);
    }
    if (!Number.isInteger(signId) || signId < 0 || signId > 255) {
      _err(errors, name, 'sign_data',
        `record ${i}: sign_id=${JSON.stringify(signId)} must be 0-255`);
    }
    if (Number.isInteger(dist) && dist > prevDist) prevDist = dist;
  }
}

function _validateSignTileset(track, errors) {
  const name = track.name || '?';
  const tl   = track.track_length || 0;
  const recs = track.sign_tileset;

  if (!Array.isArray(recs)) {
    _err(errors, name, 'sign_tileset', 'missing or not an array');
    return;
  }

  let prevDist = -1;
  for (let i = 0; i < recs.length; i++) {
    const rec    = recs[i];
    const dist   = rec.distance;
    const offset = rec.tileset_offset;

    if (!Number.isInteger(dist) || dist < 0) {
      _err(errors, name, 'sign_tileset',
        `record ${i}: distance=${JSON.stringify(dist)} must be a non-negative integer`);
    } else if (tl && dist >= tl) {
      _err(errors, name, 'sign_tileset',
        `record ${i}: distance=${dist} >= track_length=${tl}`);
    } else if (Number.isInteger(dist) && dist < prevDist) {
      _err(errors, name, 'sign_tileset',
        `record ${i}: distance=${dist} < previous ${prevDist} (must be non-decreasing)`);
    }

    if (!Number.isInteger(offset) || offset < 0 || offset > 88 || offset % 8 !== 0) {
      _err(errors, name, 'sign_tileset',
        `record ${i}: tileset_offset=${JSON.stringify(offset)} must be a multiple of 8 in range 0-88`);
    }
    if (Number.isInteger(dist)) prevDist = dist;
  }
}

function _validateSignCompatibility(track, errors) {
	const name = track.name || '?';
	const signData = track.sign_data;
	const signTileset = track.sign_tileset;
	const isArcadeWet = Number.isInteger(track.index) && track.index === 18;
	const preserveOriginalSignCadence = track._preserve_original_sign_cadence !== false;

	if (!Array.isArray(signData) || !Array.isArray(signTileset) || signTileset.length === 0) return;

	let tilesetIndex = 0;
	for (let i = 0; i < signData.length; i++) {
		const rec = signData[i];
		while (tilesetIndex + 1 < signTileset.length && signTileset[tilesetIndex + 1].distance <= rec.distance) {
			tilesetIndex++;
		}
		const activeTileset = signTileset[Math.min(tilesetIndex, signTileset.length - 1)].tileset_offset;
		const allowedIds = TILESET_SIGN_ID_MAP.get(activeTileset);
		if (isArcadeWet && activeTileset === 88) continue;
		const nextTileset = signTileset[Math.min(tilesetIndex + 1, signTileset.length - 1)];
		const nearTunnelEntry = nextTileset && nextTileset.tileset_offset === 88 && (nextTileset.distance - rec.distance) <= 96;
		if (nearTunnelEntry && (rec.sign_id === 49 || rec.sign_id === 50 || rec.sign_id === 2)) continue;
		if (allowedIds && !allowedIds.has(rec.sign_id)) {
			_err(errors, name, 'sign_data',
				`record ${i}: sign_id=${rec.sign_id} is not valid for active sign_tileset offset ${activeTileset}`);
		}
		if (Number.isInteger(rec.count) && rec.count > 4 && !(activeTileset === 88 && rec.sign_id === 2) && !preserveOriginalSignCadence) {
			_err(errors, name, 'sign_data',
				`record ${i}: count=${rec.count} is too dense for stable randomizer output (expected <= 4)`);
		}
	}

	if (preserveOriginalSignCadence) return;

	for (let i = 1; i < signTileset.length; i++) {
		const gap = signTileset[i].distance - signTileset[i - 1].distance;
		if (gap < 1500) {
			_err(errors, name, 'sign_tileset',
				`records ${i-1}/${i}: tileset changes only ${gap} units apart (< 1500 DMA safety target)`);
		}
	}
}

function _validateMinimap(track, errors) {
  const name  = track.name || '?';
  const tl    = track.track_length || 0;
  const pairs = track.minimap_pos;

  if (!Array.isArray(pairs)) {
    _err(errors, name, 'minimap_pos', 'missing or not an array');
    return;
  }

  const required = tl ? (tl >> 6) : 0;
  if (tl && pairs.length !== required) {
    _err(errors, name, 'minimap_pos',
      `${pairs.length} pairs found, expected track_length>>6 = ${required}`);
  }

  for (let i = 0; i < pairs.length; i++) {
    const pair = pairs[i];
    if (!Array.isArray(pair) || pair.length !== 2) {
      _err(errors, name, 'minimap_pos',
        `pair ${i}: expected [x, y], got ${JSON.stringify(pair)}`);
      continue;
    }
    const [x, y] = pair;
    if (!_signedByteOk(x)) {
      _err(errors, name, 'minimap_pos',
        `pair ${i}: x=${JSON.stringify(x)} out of signed-byte range [-128, 127]`);
    }
    if (!_signedByteOk(y)) {
      _err(errors, name, 'minimap_pos',
        `pair ${i}: y=${JSON.stringify(y)} out of signed-byte range [-128, 127]`);
    }
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Validate a single track object.
 * @param {object} track
 * @returns {ValidationError[]}  (empty array = valid)
 */
function validateTrack(track) {
  const errors = [];
  _validateTrackLength(track, errors);
  _validateCurveRle(track, errors);
  _validateSlopeRle(track, errors);
  _validatePhysSlopeRle(track, errors);
  _validateSignData(track, errors);
  _validateSignTileset(track, errors);
  _validateSignCompatibility(track, errors);
  _validateMinimap(track, errors);
  return errors;
}

/**
 * Validate an array of track objects.
 * @param {object[]} tracks
 * @returns {ValidationError[]}  (empty array = all valid)
 */
function validateTracks(tracks) {
  const allErrors = [];
  for (const track of tracks) {
    allErrors.push(...validateTrack(track));
  }
  return allErrors;
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

if (require.main === module) {
  const { parseArgs, die, info } = require('../lib/cli');
  const { readJson } = require('../lib/json');
  const { REPO_ROOT } = require('../lib/rom');

  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--verbose', '-v'],
    options: ['--input', '--tracks'],
  });

  const inputRel = args.options['--input'] || 'tools/data/tracks.json';
  const verbose  = args.flags['--verbose'] || args.flags['-v'];
  const inputPath = path.resolve(REPO_ROOT, inputRel);

  const fs = require('fs');
  if (!fs.existsSync(inputPath)) die(`input JSON not found: ${inputPath}`);

  const data = readJson(inputPath);
  let tracks = data.tracks;

  if (args.options['--tracks']) {
    const filterSlugs = new Set(args.options['--tracks'].split(',').map(s => s.trim()));
    tracks = tracks.filter(t => filterSlugs.has(t.slug));
    if (tracks.length === 0) die(`no tracks matched: ${args.options['--tracks']}`);
  }

  let totalErrors = 0;
  for (const track of tracks) {
    const errs = validateTrack(track);
    const name = track.name || track.slug || '?';
    if (errs.length > 0) {
      info(`FAIL  ${name}`);
      for (const e of errs) info(`      ${e.field}: ${e.message}`);
      totalErrors += errs.length;
    } else if (verbose) {
      info(`PASS  ${name}`);
    }
  }

  if (totalErrors > 0) {
    process.stderr.write(`\n${totalErrors} validation error(s) across ${tracks.length} track(s).\n`);
    process.exit(1);
  } else {
    info(`All ${tracks.length} track(s) valid.`);
  }
}

module.exports = {
  ValidationError,
  validateTrack,
  validateTracks,
};
