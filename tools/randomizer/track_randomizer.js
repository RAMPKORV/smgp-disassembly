// tools/randomizer/track_randomizer.js
//
// RAND-002 through RAND-006: Track randomizer module.
//
// Generates randomized track data for Super Monaco GP:
//   RAND-002  Curve generation
//   RAND-003  Slope generation (visual + physical)
//   RAND-004  Sign placement
//   RAND-005  Minimap generation
//   RAND-006  Art and config assignment
//
// Each sub-task uses its own XorShift32 PRNG derived from the master seed.
//
// Usage (standalone):
//   node tools/randomizer/track_randomizer.js [--seed SMGP-1-01-12345]
//                                              [--tracks SLUG ...]
//                                              [--verbose]

'use strict';

const fs   = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// PRNG (xorshift32)
// ---------------------------------------------------------------------------
class XorShift32 {
  constructor(seed) {
    this.state = (seed !== 0) ? (seed >>> 0) : 1;
  }

  next() {
    let x = this.state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >>> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    this.state = x >>> 0;
    return this.state;
  }

  randInt(lo, hi) {
    const span = hi - lo + 1;
    return lo + (this.next() % span);
  }

  randFloat() {
    return (this.next() & 0xFFFFFF) / 0x1000000;
  }

  choice(items) {
    return items[this.next() % items.length];
  }

  weightedChoice(items, weights) {
    const total = weights.reduce((a, b) => a + b, 0);
    let r = this.next() % total;
    for (let i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r < 0) return items[i];
    }
    return items[items.length - 1];
  }
}

// ---------------------------------------------------------------------------
// Module ID constants
// ---------------------------------------------------------------------------
const MOD_TRACK_CURVES  = 1;
const MOD_TRACK_SLOPES  = 2;
const MOD_TRACK_SIGNS   = 3;
const MOD_TRACK_MINIMAP = 4;
const MOD_TRACK_CONFIG  = 5;
const MOD_TEAMS         = 6;
const MOD_AI            = 7;
const MOD_CHAMPIONSHIP  = 8;

function deriveSubseed(masterSeed, moduleId) {
  let x = ((masterSeed >>> 0) ^ ((moduleId * 0x9E3779B9) >>> 0)) >>> 0;
  x ^= (x << 13) & 0xFFFFFFFF;
  x ^= (x >>> 17);
  x ^= (x << 5) & 0xFFFFFFFF;
  x = x >>> 0;
  return x !== 0 ? x : 1;
}

// ---------------------------------------------------------------------------
// Flag constants
// ---------------------------------------------------------------------------
const FLAG_TRACKS       = 0x01;
const FLAG_TRACK_CONFIG = 0x02;
const FLAG_TEAMS        = 0x04;
const FLAG_AI           = 0x08;
const FLAG_CHAMPIONSHIP = 0x10;
const FLAG_SIGNS        = 0x20;
const FLAG_ALL          = 0x3F;

// ---------------------------------------------------------------------------
// Statistical constants
// ---------------------------------------------------------------------------
const CURVE_STRAIGHT   = 0x00;
const CURVE_LEFT_MIN   = 0x01;
const CURVE_LEFT_MAX   = 0x2F;
const CURVE_RIGHT_MIN  = 0x41;
const CURVE_RIGHT_MAX  = 0x6F;
const CURVE_SENTINEL   = 0xFF;

const SHARPNESS_MIN = 1;
const SHARPNESS_MAX = 47;

const CURVE_SHARPNESS_BUCKETS = [[1, 10], [11, 25], [26, 35], [36, 47]];
const CURVE_SHARPNESS_WEIGHTS = [10, 30, 35, 25];

const SLOPE_SHARPNESS_BUCKETS = [[31, 40], [41, 46], [47, 47]];
const SLOPE_SHARPNESS_WEIGHTS = [30, 50, 20];

const TRACK_LENGTH_MIN  = 4000;
const TRACK_LENGTH_MAX  = 7500;
const TRACK_LENGTH_STEP = 64;

const STRAIGHT_LEN_MIN = 10;
const STRAIGHT_LEN_MAX = 300;
const CURVE_LEN_MIN    = 4;
const CURVE_LEN_MAX    = 120;

const BG_DISP_MIN = 30;
const BG_DISP_MAX = 300;
const CURVE_SAFE_OPENING_STRAIGHT_STEPS = 48;
const CURVE_SAFE_CLOSING_STRAIGHT_STEPS = 16;
const CURVE_SAFE_FIRST_CURVE_MIN_LENGTH = 12;
const CURVE_SAFE_FIRST_CURVE_MAX_BG_DISP = 192;
const CURVE_SAFE_FIRST_CURVE_MAX_RATE = 8;
const CURVE_RUNTIME_START_OFFSET = 6;

const BG_VERT_DISP_SOFT = 30;
const BG_VERT_DISP_STRONG = 112;
const BG_VERT_DISP_VALUES = [BG_VERT_DISP_SOFT, BG_VERT_DISP_STRONG];

const VISUAL_SLOPE_SAFE_GLOBAL_MIN = -30;
const VISUAL_SLOPE_SAFE_GLOBAL_MAX = 23;
const VISUAL_SLOPE_SAFE_START_WINDOW_STEPS = 128;
const VISUAL_SLOPE_SAFE_START_MIN = -24;
const VISUAL_SLOPE_SAFE_START_MAX = 5;
const VISUAL_SLOPE_SAFE_OPENING_FLAT_STEPS = 128;
const VISUAL_SLOPE_SAFE_CLOSING_FLAT_STEPS = 96;
const VISUAL_SLOPE_MAX_EVENTS = 1;

const PHYS_FLAT =  0;
const PHYS_DOWN = -1;
const PHYS_UP   =  1;

const SIGN_ID_POOL = [
  0, 1, 2, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20,
  21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 36, 37,
  39, 40, 41, 44, 45, 46, 48, 49, 50,
];

const SIGN_TILESET_OFFSETS = Array.from({ length: 12 }, (_, i) => i * 8);  // 0,8,...,88
const STANDARD_SIGN_TILESET_OFFSETS = SIGN_TILESET_OFFSETS.filter(offset => offset !== 80 && offset !== 88);
const HORIZON_SIGN_TILESET_OFFSETS = SIGN_TILESET_OFFSETS.filter(offset => offset !== 88);
const SIGN_TILESET_MIN_SPACING = 1500;

const SIGN_COUNT_VALUES = [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 24];

const TILESET_SIGN_ID_MAP = new Map([
	[0,  [0, 1, 8, 10, 11, 28, 29, 30, 31]],
	[8,  [0, 1, 8, 9, 10, 11, 28, 29, 30, 31]],
	[16, [0, 1, 4, 5, 8, 9, 31, 48, 49]],
	[24, [0, 1, 8, 9, 16, 17, 30]],
	[32, [0, 1, 8, 9, 10, 11, 20, 21, 22, 30, 31]],
	[40, [0, 1, 8, 9, 10, 24, 25, 26, 27, 30, 31]],
	[48, [0, 1, 8, 11, 31, 32, 33]],
	[56, [0, 1, 8, 9, 10, 11, 30, 31, 36, 37, 39, 49]],
	[64, [0, 1, 8, 9, 31, 40, 41]],
	[72, [0, 1, 8, 9, 10, 44, 45, 46]],
	[80, [0, 1, 12, 13, 14, 15]],
	[88, [2, 50]],
]);

const SAFE_SIGN_COUNT_VALUES = [1, 2, 3, 4];
const SAFE_SIGN_SPACING_MIN = 160;
const SAFE_SIGN_SPACING_MAX = 420;
const SAFE_SIGN_TILESET_GUARD_DISTANCE = 256;

const LEFT_SIGN_IDS = new Set([4, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48]);
const RIGHT_SIGN_IDS = new Set([5, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49]);
const SPECIAL_SIGN_IDS = new Set([48, 49, 50]);

const SIGN_SPACING_MIN  = 100;
const SIGN_SPACING_MAX  = 500;
const SIGN_FINISH_ZONE  = 120;

const CHICANE_MIN_STRAIGHT = 112;
const SHARP_COMPLEX_MIN_STRAIGHT = 128;
const TUNNEL_TILESET_OFFSET = 88;
const TUNNEL_ENTRY_SIGN_ID = 49;
const TUNNEL_INTERIOR_SIGN_ID = 2;
const TUNNEL_EXIT_SIGN_ID = 50;
const TUNNEL_SECTION_MIN = 1500;
const TUNNEL_SECTION_MAX = 2200;

// ---------------------------------------------------------------------------
// RAND-002: Curve generation
// ---------------------------------------------------------------------------

function _pickSharpness(rng) {
  const [lo, hi] = rng.weightedChoice(CURVE_SHARPNESS_BUCKETS, CURVE_SHARPNESS_WEIGHTS);
  return rng.randInt(lo, hi);
}

function _pickSlopeSharpness(rng) {
  const [lo, hi] = rng.weightedChoice(SLOPE_SHARPNESS_BUCKETS, SLOPE_SHARPNESS_WEIGHTS);
  return rng.randInt(lo, hi);
}

function clamp(value, lo, hi) {
	return Math.max(lo, Math.min(hi, value));
}

function computeCurveBgDispBounds(segLen = 0, sharpness = SHARPNESS_MIN, options = {}) {
	const clampedLength = Math.max(4, segLen | 0);
	const clampedSharpness = clamp(sharpness, SHARPNESS_MIN, SHARPNESS_MAX);
	let minRate;
	if (clampedSharpness <= 8) minRate = 0.45;
	else if (clampedSharpness <= 16) minRate = 0.5;
	else if (clampedSharpness <= 24) minRate = 0.55;
	else if (clampedSharpness <= 32) minRate = 0.65;
	else minRate = 0.8;
	if (clampedLength >= 96) minRate -= 0.45;
	else if (clampedLength >= 64) minRate -= 0.3;
	else if (clampedLength >= 40) minRate -= 0.15;
	else if (clampedLength <= 12) minRate += 0.05;

	let maxRate;
	if (clampedSharpness <= 8) maxRate = 3.4;
	else if (clampedSharpness <= 16) maxRate = 4.2;
	else if (clampedSharpness <= 24) maxRate = 5.0;
	else if (clampedSharpness <= 32) maxRate = 5.8;
	else maxRate = 6.6;
	if (clampedLength <= 8) maxRate += 1.0;
	else if (clampedLength <= 12) maxRate += 0.8;
	else if (clampedLength <= 16) maxRate += 0.6;
	else if (clampedLength <= 24) maxRate += 0.4;
	else if (clampedLength <= 40) maxRate += 0.2;
	else if (clampedLength >= 112) maxRate -= 1.8;
	else if (clampedLength >= 80) maxRate -= 1.4;
	else if (clampedLength >= 64) maxRate -= 1.0;
	else if (clampedLength >= 48) maxRate -= 0.4;
	if (options.startupCurve === true) {
		maxRate = Math.min(maxRate, CURVE_SAFE_FIRST_CURVE_MAX_RATE);
	}
	minRate = clamp(minRate, 0.25, 7.0);
	maxRate = clamp(maxRate, 1.6, 7.5);
	if (minRate > maxRate) minRate = maxRate;
	const minBgDisp = clamp(Math.ceil(clampedLength * minRate), BG_DISP_MIN, BG_DISP_MAX);
	const maxBgDisp = clamp(Math.floor(clampedLength * maxRate), minBgDisp, BG_DISP_MAX);
	return {
		minRate,
		maxRate,
		minBgDisp,
		maxBgDisp,
	};
}

function _pickBgDisp(rng, direction, segLen = 0, sharpness = SHARPNESS_MIN) {
	const clampedLength = Math.max(4, segLen | 0);
	const clampedSharpness = clamp(sharpness, SHARPNESS_MIN, SHARPNESS_MAX);
	const bounds = computeCurveBgDispBounds(clampedLength, clampedSharpness);
	let targetRate;
	if (clampedSharpness <= 8) targetRate = 2.2;
	else if (clampedSharpness <= 16) targetRate = 2.8;
	else if (clampedSharpness <= 24) targetRate = 3.4;
	else if (clampedSharpness <= 32) targetRate = 4.2;
	else targetRate = 5.1;
	if (clampedLength <= 12) targetRate += clampedSharpness >= 25 ? 0.2 : -0.2;
	else if (clampedLength >= 80) targetRate -= 0.6;
	else if (clampedLength >= 48) targetRate -= 0.2;
	const jitter = rng.randInt(-8, 8) / 10;
	const rate = clamp(targetRate + jitter, bounds.minRate, bounds.maxRate);
	const base = Math.round(clampedLength * rate);
	return clamp(base, bounds.minBgDisp, bounds.maxBgDisp);
}

function encodeDirectedByte(direction, sharpness) {
	const clampedSharpness = clamp(sharpness, SHARPNESS_MIN, SHARPNESS_MAX);
	if (direction < 0) return clamp(clampedSharpness, CURVE_LEFT_MIN, CURVE_LEFT_MAX);
	return clamp(0x40 | clampedSharpness, CURVE_RIGHT_MIN, CURVE_RIGHT_MAX);
}

function getCurveDirection(curveByte) {
	if (curveByte >= CURVE_RIGHT_MIN && curveByte <= CURVE_RIGHT_MAX) return 1;
	if (curveByte >= CURVE_LEFT_MIN && curveByte <= CURVE_LEFT_MAX) return -1;
	return 0;
}

function getCurveSharpness(curveByte) {
	return curveByte & 0x3F;
}

function getCurveBgRuntimeDirection(curveByte) {
	if (curveByte >= CURVE_LEFT_MIN && curveByte <= CURVE_LEFT_MAX) return 1;
	if (curveByte >= CURVE_RIGHT_MIN && curveByte <= CURVE_RIGHT_MAX) return -1;
	return 0;
}


function cloneSegments(segments) {
	return JSON.parse(JSON.stringify(segments || []));
}

function pushCurveSegment(segments, segment) {
	if (!segment || !Number.isInteger(segment.length) || segment.length <= 0) return;
	const prev = segments[segments.length - 1];
	if (prev && prev.type === segment.type) {
		if (segment.type === 'straight' && prev.curve_byte === 0) {
			prev.length += segment.length;
			return;
		}
		if (segment.type === 'curve' && prev.curve_byte === segment.curve_byte && prev.bg_disp === segment.bg_disp) {
			prev.length += segment.length;
			return;
		}
	}
	segments.push({ ...segment });
}

function buildCurveBodySegments(segments) {
	return Array.isArray(segments)
		? segments.filter(seg => seg.type === 'straight' || seg.type === 'curve').map(seg => ({ ...seg }))
		: [];
}

function finalizeCurveSegments(bodySegments, targetSteps) {
	const body = [];
	for (const segment of bodySegments || []) pushCurveSegment(body, segment);
	let total = body.reduce((sum, segment) => sum + segment.length, 0);
	if (total > targetSteps) {
		let excess = total - targetSteps;
		for (let i = body.length - 1; i >= 0 && excess > 0; i--) {
			const seg = body[i];
			const minLength = seg.type === 'curve' ? CURVE_LEN_MIN : 1;
			const removable = Math.max(0, seg.length - minLength);
			if (removable <= 0) continue;
			const cut = Math.min(removable, excess);
			seg.length -= cut;
			excess -= cut;
		}
		total = body.reduce((sum, segment) => sum + segment.length, 0);
	}
	if (total < targetSteps) {
		pushCurveSegment(body, { type: 'straight', length: targetSteps - total, curve_byte: 0 });
	}
	const finalized = [];
	for (const segment of body) {
		if (segment.length <= 0) continue;
		pushCurveSegment(finalized, segment);
	}
	finalized.push({ type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] });
	return finalized;
}

function buildCurveGenerationProfile(templateSegments) {
	const sequence = Array.isArray(templateSegments) ? templateSegments.filter(seg => seg.type === 'straight' || seg.type === 'curve') : [];
	const curveSegments = sequence.filter(seg => seg.type === 'curve');
	const straightSegments = sequence.filter(seg => seg.type === 'straight');
	let directionChanges = 0;
	let chicaneCount = 0;
	let ultraSharpCount = 0;
	let sharpTurnCount = 0;
	let strongCurveCount = 0;
	let longCurveCount = 0;

	for (const seg of curveSegments) {
		const curveSharpness = getCurveSharpness(seg.curve_byte);
		if (curveSharpness <= 4) ultraSharpCount += 1;
		if (curveSharpness <= 8) sharpTurnCount += 1;
		if (curveSharpness <= 14) strongCurveCount += 1;
		if (seg.length >= 72) longCurveCount += 1;
	}

	for (let i = 1; i < curveSegments.length; i++) {
		if (getCurveDirection(curveSegments[i].curve_byte) !== getCurveDirection(curveSegments[i - 1].curve_byte)) {
			directionChanges += 1;
		}
	}

	for (let i = 0; i < sequence.length - 2; i++) {
		const a = sequence[i];
		const b = sequence[i + 1];
		const c = sequence[i + 2];
		if (a.type !== 'curve' || c.type !== 'curve') continue;
		if (b.type !== 'straight' || b.length > 24) continue;
		if (a.length > 48 || c.length > 48) continue;
		if (getCurveDirection(a.curve_byte) === getCurveDirection(c.curve_byte)) continue;
		chicaneCount += 1;
	}

	const averageStraightLength = straightSegments.length
		? straightSegments.reduce((sum, seg) => sum + seg.length, 0) / straightSegments.length
		: 96;
	const averageCurveLength = curveSegments.length
		? curveSegments.reduce((sum, seg) => sum + seg.length, 0) / curveSegments.length
		: 40;

	return {
		curveCount: curveSegments.length,
		straightCount: straightSegments.length,
		directionChanges,
		chicaneCount,
		ultraSharpCount,
		sharpTurnCount,
		strongCurveCount,
		longCurveCount,
		averageStraightLength,
		averageCurveLength,
	};
}

function buildCurveTargets(profile, targetSteps) {
	const curveCount = profile.curveCount || 12;
	const directionChanges = profile.directionChanges || 4;
	const chicaneCount = profile.chicaneCount || 0;
	const ultraSharpCount = profile.ultraSharpCount || 0;
	const sharpTurnCount = profile.sharpTurnCount || 0;
	const strongCurveCount = profile.strongCurveCount || 0;
	return {
		maxStraightLength: clamp(Math.round((profile.averageStraightLength || 96) * 0.58), 40, 120),
		minChicanes: clamp(Math.max(1, chicaneCount > 0 ? 2 : (directionChanges >= 4 ? 2 : 1)), 1, 3),
		minSharpTurns: clamp(Math.max(1, sharpTurnCount > 0 ? 2 : (strongCurveCount >= 4 || ultraSharpCount > 0 ? 2 : 1)), 1, 3),
		minCurveSegments: clamp(Math.max(16, Math.round(curveCount * 1.5)), 16, Math.max(22, Math.floor(targetSteps / 12))),
		preferTechnicalRuns: true,
	};
}

function getNeighborCurveDirection(sequence, index, fallbackDirection) {
	for (let i = index - 1; i >= 0; i--) {
		if (sequence[i].type === 'curve') return getCurveDirection(sequence[i].curve_byte);
	}
	for (let i = index + 1; i < sequence.length; i++) {
		if (sequence[i].type === 'curve') return getCurveDirection(sequence[i].curve_byte);
	}
	return fallbackDirection;
}

function buildChicaneReplacement(rng, straightLength, fallbackDirection) {
	if (straightLength < CHICANE_MIN_STRAIGHT) return null;
	const direction = fallbackDirection || rng.choice([-1, 1]);
	const entry = clamp(rng.randInt(20, 40), 16, Math.max(16, straightLength - 72));
	const exit = clamp(rng.randInt(20, 40), 16, Math.max(16, straightLength - entry - 52));
	const usable = straightLength - entry - exit;
	if (usable < 40) return null;
	const bridge = clamp(rng.randInt(12, 28), 10, Math.max(10, usable - 24));
	const curveBudget = usable - bridge;
	if (curveBudget < 24) return null;
	const firstLen = clamp(Math.round(curveBudget * 0.5) + rng.randInt(-4, 4), 10, curveBudget - 10);
	const secondLen = curveBudget - firstLen;
	return [
		{ type: 'straight', length: entry, curve_byte: 0 },
		{ type: 'curve', length: firstLen, curve_byte: encodeDirectedByte(direction, rng.randInt(6, 12)), bg_disp: _pickBgDisp(rng, direction, firstLen, 7) },
		{ type: 'straight', length: bridge, curve_byte: 0 },
		{ type: 'curve', length: secondLen, curve_byte: encodeDirectedByte(-direction, rng.randInt(6, 12)), bg_disp: _pickBgDisp(rng, -direction, secondLen, 7) },
		{ type: 'straight', length: exit, curve_byte: 0 },
	];
}

function buildSharpTurnReplacement(rng, straightLength, fallbackDirection) {
	if (straightLength < SHARP_COMPLEX_MIN_STRAIGHT) return null;
	const direction = fallbackDirection || rng.choice([-1, 1]);
	const entry = clamp(rng.randInt(24, 48), 18, Math.max(18, straightLength - 72));
	const exit = clamp(rng.randInt(24, 52), 18, Math.max(18, straightLength - entry - 44));
	const curveBudget = straightLength - entry - exit;
	if (curveBudget < 36) return null;
	const firstLen = clamp(Math.round(curveBudget * 0.38) + rng.randInt(-3, 3), 12, curveBudget - 18);
	const secondLen = curveBudget - firstLen;
	return [
		{ type: 'straight', length: entry, curve_byte: 0 },
		{ type: 'curve', length: firstLen, curve_byte: encodeDirectedByte(direction, rng.randInt(16, 28)), bg_disp: _pickBgDisp(rng, direction, firstLen, 16) },
		{ type: 'curve', length: secondLen, curve_byte: encodeDirectedByte(direction, rng.randInt(6, 12)), bg_disp: _pickBgDisp(rng, direction, secondLen, 8) },
		{ type: 'straight', length: exit, curve_byte: 0 },
	];
}

function buildEssesReplacement(rng, straightLength, fallbackDirection) {
	if (straightLength < 88) return null;
	const direction = fallbackDirection || rng.choice([-1, 1]);
	const entry = clamp(rng.randInt(16, 30), 12, Math.max(12, straightLength - 64));
	const exit = clamp(rng.randInt(14, 28), 12, Math.max(12, straightLength - entry - 40));
	const usable = straightLength - entry - exit;
	if (usable < 40) return null;
	const bridge = clamp(rng.randInt(8, 16), 6, Math.max(6, usable - 24));
	const curveBudget = usable - bridge;
	if (curveBudget < 24) return null;
	const firstLen = clamp(Math.round(curveBudget * 0.52) + rng.randInt(-3, 3), 10, curveBudget - 10);
	const secondLen = curveBudget - firstLen;
	return [
		{ type: 'straight', length: entry, curve_byte: 0 },
		{ type: 'curve', length: firstLen, curve_byte: encodeDirectedByte(direction, rng.randInt(10, 18)), bg_disp: _pickBgDisp(rng, direction, firstLen, 12) },
		{ type: 'straight', length: bridge, curve_byte: 0 },
		{ type: 'curve', length: secondLen, curve_byte: encodeDirectedByte(-direction, rng.randInt(9, 16)), bg_disp: _pickBgDisp(rng, -direction, secondLen, 11) },
		{ type: 'straight', length: exit, curve_byte: 0 },
	];
}

function buildMediumBendReplacement(rng, straightLength, fallbackDirection) {
	if (straightLength < 72) return null;
	const direction = fallbackDirection || rng.choice([-1, 1]);
	const entry = clamp(rng.randInt(14, 28), 10, Math.max(10, straightLength - 52));
	const exit = clamp(rng.randInt(14, 28), 10, Math.max(10, straightLength - entry - 28));
	const curveBudget = straightLength - entry - exit;
	if (curveBudget < 20) return null;
	const firstLen = clamp(Math.round(curveBudget * 0.42) + rng.randInt(-3, 3), 8, curveBudget - 8);
	const secondLen = curveBudget - firstLen;
	return [
		{ type: 'straight', length: entry, curve_byte: 0 },
		{ type: 'curve', length: firstLen, curve_byte: encodeDirectedByte(direction, rng.randInt(12, 22)), bg_disp: _pickBgDisp(rng, direction, firstLen, 14) },
		{ type: 'curve', length: secondLen, curve_byte: encodeDirectedByte(direction, rng.randInt(7, 13)), bg_disp: _pickBgDisp(rng, direction, secondLen, 9) },
		{ type: 'straight', length: exit, curve_byte: 0 },
	];
}

function softenUndrivableTransitions(segments) {
	const adjusted = buildCurveBodySegments(segments);

	function softenCurveAt(index, minimumSharpness) {
		const seg = adjusted[index];
		if (!seg || seg.type !== 'curve') return;
		const direction = getCurveDirection(seg.curve_byte);
		const sharpness = getCurveSharpness(seg.curve_byte);
		if (sharpness >= minimumSharpness) return;
		const nextSharpness = clamp(minimumSharpness, SHARPNESS_MIN, SHARPNESS_MAX);
		seg.curve_byte = encodeDirectedByte(direction, nextSharpness);
		const maxBgDisp = clamp(24 + (seg.length * 2) + (nextSharpness * 3) + 12, BG_DISP_MIN, BG_DISP_MAX);
		seg.bg_disp = clamp(seg.bg_disp || BG_DISP_MIN, BG_DISP_MIN, maxBgDisp);
	}

	let ultraSharpCount = 0;
	for (let i = 0; i < adjusted.length; i++) {
		const seg = adjusted[i];
		if (!seg || seg.type !== 'curve') continue;
		const prev = adjusted[i - 1];
		const next = adjusted[i + 1];
		const sharpness = getCurveSharpness(seg.curve_byte);
		const leadStraight = prev && prev.type === 'straight' ? prev.length : 0;
		if (sharpness <= 4) {
			ultraSharpCount += 1;
			if (leadStraight < 24) softenCurveAt(i, 8);
		}
		if (sharpness <= 8 && leadStraight < 12) softenCurveAt(i, 10);
		if (next && next.type === 'curve' && getCurveDirection(next.curve_byte) === getCurveDirection(seg.curve_byte) && sharpness <= 4) {
			softenCurveAt(i, 12);
		}
		if (prev && prev.type === 'curve' && getCurveDirection(prev.curve_byte) === getCurveDirection(seg.curve_byte) && getCurveSharpness(prev.curve_byte) <= 4) {
			softenCurveAt(i, 8);
		}
	}

	for (let i = 0; i < adjusted.length - 2; i++) {
		const a = adjusted[i];
		const bridge = adjusted[i + 1];
		const b = adjusted[i + 2];
		if (!a || !b || a.type !== 'curve' || b.type !== 'curve' || !bridge || bridge.type !== 'straight') continue;
		if (getCurveDirection(a.curve_byte) === getCurveDirection(b.curve_byte)) continue;
		if (bridge.length < 20) {
			softenCurveAt(i, bridge.length < 12 ? 10 : 8);
			softenCurveAt(i + 2, bridge.length < 12 ? 10 : 8);
		}
	}

	if (ultraSharpCount > 2) {
		let remaining = ultraSharpCount - 2;
		for (let i = adjusted.length - 1; i >= 0 && remaining > 0; i--) {
			const seg = adjusted[i];
			if (!seg || seg.type !== 'curve') continue;
			if (getCurveSharpness(seg.curve_byte) <= 4) {
				softenCurveAt(i, 8);
				remaining -= 1;
			}
		}
	}

	return adjusted;
}

function expandCurveComplexity(rng, segments, targets) {
	const base = buildCurveBodySegments(segments);
	if (!base.length) return segments;

	let working = base;
	let chicanesAdded = 0;
	let sharpTurnsAdded = 0;

	function countCurveSegments(sequence) {
		return sequence.filter(seg => seg.type === 'curve').length;
	}

	function getLongestStraight(sequence) {
		return sequence
			.map((seg, index) => ({ seg, index }))
			.filter(({ seg }) => seg.type === 'straight')
			.sort((a, b) => b.seg.length - a.seg.length)[0] || null;
	}

	function replaceStraightAt(index, replacement) {
		working.splice(index, 1, ...replacement);
	}

	function candidateStraights(minLength) {
		return working
			.map((seg, index) => ({ seg, index }))
			.filter(({ seg }) => seg.type === 'straight' && seg.length >= minLength)
			.sort((a, b) => b.seg.length - a.seg.length);
	}

	for (const candidate of candidateStraights(CHICANE_MIN_STRAIGHT)) {
		if (chicanesAdded >= targets.minChicanes) break;
		const fallbackDirection = getNeighborCurveDirection(working, candidate.index, rng.choice([-1, 1]));
		const replacement = buildChicaneReplacement(rng, candidate.seg.length, fallbackDirection);
		if (!replacement) continue;
		replaceStraightAt(candidate.index, replacement);
		chicanesAdded += 1;
	}

	for (const candidate of candidateStraights(SHARP_COMPLEX_MIN_STRAIGHT)) {
		if (sharpTurnsAdded >= targets.minSharpTurns) break;
		const fallbackDirection = getNeighborCurveDirection(working, candidate.index, rng.choice([-1, 1]));
		const replacement = buildSharpTurnReplacement(rng, candidate.seg.length, fallbackDirection);
		if (!replacement) continue;
		replaceStraightAt(candidate.index, replacement);
		sharpTurnsAdded += 1;
	}

	for (let guard = 0; guard < 32; guard++) {
		const curveCount = countCurveSegments(working);
		const longestStraight = getLongestStraight(working);
		const needsMoreCurves = curveCount < targets.minCurveSegments;
		const hasLongStraight = !!(longestStraight && longestStraight.seg.length > targets.maxStraightLength);
		if (!needsMoreCurves && !hasLongStraight) break;

		const minCandidateLength = hasLongStraight ? Math.max(72, targets.maxStraightLength + 8) : 72;
		const candidates = candidateStraights(minCandidateLength);
		let replaced = false;
		for (const candidate of candidates) {
			const fallbackDirection = getNeighborCurveDirection(working, candidate.index, rng.choice([-1, 1]));
			let replacement = null;
			if (candidate.seg.length >= 88 && (needsMoreCurves || targets.preferTechnicalRuns)) {
				replacement = buildEssesReplacement(rng, candidate.seg.length, fallbackDirection);
			}
			if (!replacement) {
				replacement = buildMediumBendReplacement(rng, candidate.seg.length, fallbackDirection);
			}
			if (!replacement) continue;
			replaceStraightAt(candidate.index, replacement);
			replaced = true;
			break;
		}
		if (!replaced) break;
	}

	return working;
}

function buildPathIntersections(points, minIndexGap = 6) {
	if (!Array.isArray(points) || points.length < 4) return [];
	function orient(a, b, c) {
		return ((b[0] - a[0]) * (c[1] - a[1])) - ((b[1] - a[1]) * (c[0] - a[0]));
	}
	function onSegment(a, b, p) {
		return p[0] >= Math.min(a[0], b[0]) - 1e-6 && p[0] <= Math.max(a[0], b[0]) + 1e-6
			&& p[1] >= Math.min(a[1], b[1]) - 1e-6 && p[1] <= Math.max(a[1], b[1]) + 1e-6;
	}
	function intersects(a, b, c, d) {
		const o1 = orient(a, b, c);
		const o2 = orient(a, b, d);
		const o3 = orient(c, d, a);
		const o4 = orient(c, d, b);
		if (((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) && ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))) return true;
		if (Math.abs(o1) < 1e-6 && onSegment(a, b, c)) return true;
		if (Math.abs(o2) < 1e-6 && onSegment(a, b, d)) return true;
		if (Math.abs(o3) < 1e-6 && onSegment(c, d, a)) return true;
		if (Math.abs(o4) < 1e-6 && onSegment(c, d, b)) return true;
		return false;
	}
	function lineIntersection(a, b, c, d) {
		const denom = ((a[0] - b[0]) * (c[1] - d[1])) - ((a[1] - b[1]) * (c[0] - d[0]));
		if (Math.abs(denom) < 1e-6) {
			return [
				(a[0] + b[0] + c[0] + d[0]) / 4,
				(a[1] + b[1] + c[1] + d[1]) / 4,
			];
		}
		const detAB = (a[0] * b[1]) - (a[1] * b[0]);
		const detCD = (c[0] * d[1]) - (c[1] * d[0]);
		return [
			((detAB * (c[0] - d[0])) - ((a[0] - b[0]) * detCD)) / denom,
			((detAB * (c[1] - d[1])) - ((a[1] - b[1]) * detCD)) / denom,
		];
	}

	const intersections = [];
	for (let i = 0; i < points.length; i++) {
		const a = points[i];
		const b = points[(i + 1) % points.length];
		for (let j = i + 1; j < points.length; j++) {
			if (Math.abs(i - j) <= minIndexGap) continue;
			if (Math.abs((i + 1) - j) <= minIndexGap) continue;
			if (((j + 1) % points.length) === i) continue;
			const c = points[j];
			const d = points[(j + 1) % points.length];
			if (!intersects(a, b, c, d)) continue;
			intersections.push({
				segmentA: i,
				segmentB: j,
				point: lineIntersection(a, b, c, d),
			});
		}
	}
	return intersections;
}

function buildSpecialRoadFeatures(rng, trackLength, curveSegments) {
	const { buildDerivedPath } = require('../lib/minimap_analysis');
	const derived = buildDerivedPath({ curve_rle_segments: curveSegments });
	const points = Array.isArray(derived?.points) ? derived.points : [];
	const intersections = buildPathIntersections(points, 6);
	if (!intersections.length) return [];

	const features = [];
	for (const intersection of intersections) {
		const distA = Math.round((intersection.segmentA + 0.5) * (derived.sampleEvery || 16) * 4);
		const distB = Math.round((intersection.segmentB + 0.5) * (derived.sampleEvery || 16) * 4);
		const branchDistance = Math.max(distA, distB);
		const sectionLength = clamp(rng.randInt(TUNNEL_SECTION_MIN, TUNNEL_SECTION_MAX), TUNNEL_SECTION_MIN, TUNNEL_SECTION_MAX);
		let tilesetDistance = clamp(branchDistance - rng.randInt(48, 112), 160, Math.max(160, trackLength - SIGN_FINISH_ZONE - sectionLength - 120));
		let restoreDistance = clamp(tilesetDistance + sectionLength, tilesetDistance + SIGN_TILESET_MIN_SPACING, trackLength - SIGN_FINISH_ZONE - 32);
		if ((restoreDistance - tilesetDistance) < SIGN_TILESET_MIN_SPACING) continue;
		const entrySignDistance = clamp(tilesetDistance - 6, 0, trackLength - SIGN_FINISH_ZONE - 1);
		const interiorDistance = clamp(tilesetDistance + 30, 0, trackLength - SIGN_FINISH_ZONE - 1);
		const exitSignDistance = clamp(restoreDistance - rng.randInt(96, 160), 0, trackLength - SIGN_FINISH_ZONE - 1);
		if (features.some(feature => Math.abs(feature.tilesetDistance - tilesetDistance) < 384)) continue;
		features.push({
			type: 'tunnel',
			entrySignDistance,
			tilesetDistance,
			interiorDistance,
			exitSignDistance,
			restoreDistance,
			interiorCount: rng.choice([15, 24]),
		});
	}

	return features.sort((a, b) => a.tilesetDistance - b.tilesetDistance).slice(0, 2);
}

function getActiveTilesetOffset(records, distance) {
	if (!Array.isArray(records) || records.length === 0) return 8;
	let active = records[0].tileset_offset;
	for (const record of records) {
		if (record.distance > distance) break;
		active = record.tileset_offset;
	}
	return active;
}

function isNearTilesetTransition(tilesetRecords, distance, guardDistance = SAFE_SIGN_TILESET_GUARD_DISTANCE) {
	if (!Array.isArray(tilesetRecords) || tilesetRecords.length === 0) return false;
	return tilesetRecords.some(record => Math.abs(record.distance - distance) < guardDistance);
}

function getWrapTilesetGap(trackLength, records) {
	if (!Number.isInteger(trackLength) || trackLength <= 0) return Infinity;
	if (!Array.isArray(records) || records.length < 2) return Infinity;
	return records[0].distance + trackLength - records[records.length - 1].distance;
}

function applySpecialRoadTilesetRecords(records, features) {
	if (!Array.isArray(features) || features.length === 0) return records.slice();
	let working = records.slice();
	for (const feature of features) {
		if (feature.type !== 'tunnel') continue;
		const activeBefore = getActiveTilesetOffset(working, feature.tilesetDistance - 1);
		if (activeBefore === TUNNEL_TILESET_OFFSET) continue;
		const prev = working.filter(record => record.distance < feature.tilesetDistance).slice(-1)[0] || null;
		const next = working.find(record => record.distance > feature.tilesetDistance) || null;
		if (prev && (feature.tilesetDistance - prev.distance) < SIGN_TILESET_MIN_SPACING) continue;
		if (next && (next.distance - feature.tilesetDistance) < SIGN_TILESET_MIN_SPACING) continue;
		const restoreOffset = getActiveTilesetOffset(working, feature.restoreDistance);
		working = working.filter(record => record.distance < feature.tilesetDistance || record.distance >= feature.restoreDistance);
		const afterRestore = working.find(record => record.distance > feature.restoreDistance) || null;
		if (afterRestore && (afterRestore.distance - feature.restoreDistance) < SIGN_TILESET_MIN_SPACING) continue;
		feature._applied = true;
		working.push({ distance: feature.tilesetDistance, tileset_offset: TUNNEL_TILESET_OFFSET });
		working.push({ distance: feature.restoreDistance, tileset_offset: restoreOffset === TUNNEL_TILESET_OFFSET ? 8 : restoreOffset });
		working.sort((a, b) => a.distance - b.distance);
	}
	return working;
}

function enforceWrapSafeTilesetRecords(trackLength, records) {
	if (!Array.isArray(records)) return [];
	const working = records
		.filter(record => record && Number.isInteger(record.distance) && Number.isInteger(record.tileset_offset))
		.sort((a, b) => a.distance - b.distance)
		.map(record => ({ ...record }));
	while (working.length > 1 && getWrapTilesetGap(trackLength, working) < SIGN_TILESET_MIN_SPACING) {
		if (working.length <= 2) {
			working[0].tileset_offset = working[working.length - 1].tileset_offset;
			working.splice(1);
			break;
		}
		if (working[working.length - 1].distance >= (trackLength >> 1)) working.pop();
		else working.shift();
	}
	return working;
}

function applySpecialRoadSignRecords(records, features) {
	if (!Array.isArray(features) || features.length === 0) return records.slice();
	let working = records.slice();
	for (const feature of features) {
		if (feature.type !== 'tunnel') continue;
		if (!feature._applied) continue;
		const transitionDistances = [feature.tilesetDistance, feature.restoreDistance];
		working = working.filter(record => transitionDistances.every(distance => Math.abs(record.distance - distance) >= SAFE_SIGN_TILESET_GUARD_DISTANCE));
		for (const record of [
			{ distance: feature.entrySignDistance, count: 1, sign_id: TUNNEL_ENTRY_SIGN_ID },
			{ distance: feature.interiorDistance, count: 4, sign_id: TUNNEL_INTERIOR_SIGN_ID },
			{ distance: feature.exitSignDistance, count: 1, sign_id: TUNNEL_EXIT_SIGN_ID },
		]) {
			if (transitionDistances.some(distance => Math.abs(distance - record.distance) < SAFE_SIGN_TILESET_GUARD_DISTANCE)) continue;
			working.push(record);
		}
	}
	return working.sort((a, b) => a.distance - b.distance);
}

function computeNetBgDisp(segments) {
	let sum = 0;
	for (const seg of segments) {
		if (seg.type !== 'curve') continue;
		const dir = getCurveBgRuntimeDirection(seg.curve_byte);
		sum += dir * (seg.bg_disp || 0);
	}
	return sum;
}

function getCurveRuntimeSampleIndex(playerDistance, trackLength, decodedLength) {
	if (!Number.isInteger(decodedLength) || decodedLength <= 0) return 0;
	if (!Number.isInteger(trackLength) || trackLength <= 0) return 0;
	let wrappedDistance = playerDistance % trackLength;
	if (wrappedDistance < 0) wrappedDistance += trackLength;
	return Math.min(decodedLength - 1, Math.floor(wrappedDistance / 4));
}

function getCurveRuntimeTargetAtDistance(decoded, playerDistance, trackLength) {
	if (!Array.isArray(decoded) || decoded.length === 0) return 0;
	return decoded[getCurveRuntimeSampleIndex(playerDistance, trackLength, decoded.length)] & 0x03FF;
}

function simulateCurveRuntimeParallax(decoded, trackLength, startDistance = trackLength - CURVE_RUNTIME_START_OFFSET, frameCount = CURVE_RUNTIME_START_OFFSET + 8) {
	if (!Array.isArray(decoded) || decoded.length === 0 || !Number.isInteger(trackLength) || trackLength <= 0) return [];
	let accumulator = (getCurveRuntimeTargetAtDistance(decoded, startDistance, trackLength) << 16) | 0;
	const states = [];
	for (let frame = 0; frame <= frameCount; frame++) {
		const distance = startDistance + frame;
		const target = getCurveRuntimeTargetAtDistance(decoded, distance, trackLength);
		const targetFixed = (target << 16) | 0;
		accumulator = (accumulator + ((targetFixed - accumulator) >> 2)) | 0;
		states.push({
			playerDistance: ((distance % trackLength) + trackLength) % trackLength,
			target,
			display: accumulator >> 16,
			accumulator,
		});
	}
	return states;
}

function getCurveRuntimeSeamMetrics(curveSegments, trackLength) {
	const body = buildCurveBodySegments(curveSegments);
	if (body.length === 0 || !Number.isInteger(trackLength) || trackLength <= 0) return null;
	const decoded = decodeCurveBgDisplacement(body);
	if (decoded.length === 0) return null;
	const states = simulateCurveRuntimeParallax(decoded, trackLength);
	const preLineDistance = Math.max(0, trackLength - 1);
	const preLineState = states.find(state => state.playerDistance === preLineDistance) || states[states.length - 1] || null;
	const postLineState = states.find(state => state.playerDistance === 0) || null;
	if (!preLineState || !postLineState) return null;
	return {
		decoded,
		states,
		seedState: states[0] || null,
		preLineState,
		postLineState,
		targetJump: postLineState.target - preLineState.target,
		displayJump: postLineState.display - preLineState.display,
		sampleJump: decoded[0] - decoded[decoded.length - 1],
		netBgDisp: computeNetBgDisp(body),
	};
}

function compareCurveRuntimeSeamScores(a, b) {
	const keys = ['displayJumpAbs', 'targetJumpAbs', 'sampleJumpAbs', 'netBgDispAbs', 'adjustCost'];
	for (const key of keys) {
		if (a[key] !== b[key]) return a[key] - b[key];
	}
	return 0;
}

function buildCurveRuntimeSeamScore(curveSegments, trackLength, adjustCost = 0) {
	const metrics = getCurveRuntimeSeamMetrics(curveSegments, trackLength);
	if (!metrics) {
		return {
			metrics,
			displayJumpAbs: 0,
			targetJumpAbs: 0,
			sampleJumpAbs: 0,
			netBgDispAbs: 0,
			adjustCost,
		};
	}
	return {
		metrics,
		displayJumpAbs: Math.abs(metrics.displayJump),
		targetJumpAbs: Math.abs(metrics.targetJump),
		sampleJumpAbs: Math.abs(metrics.sampleJump),
		netBgDispAbs: Math.abs(metrics.netBgDisp),
		adjustCost,
	};
}

function getCurveRuntimeStartIndex(trackLength, decodedLength) {
	if (!Number.isInteger(decodedLength) || decodedLength <= 0) return 0;
	if (!Number.isInteger(trackLength) || trackLength <= 0) return 0;
	const playerDistance = Math.max(0, trackLength - CURVE_RUNTIME_START_OFFSET);
	return getCurveRuntimeSampleIndex(playerDistance, trackLength, decodedLength);
}

function getCurveClosingStraightSteps(curveSegments) {
	let closing = 0;
	for (let i = (curveSegments || []).length - 1; i >= 0; i--) {
		const seg = curveSegments[i];
		if (!seg || seg.type === 'terminator') continue;
		if (seg.type === 'straight') {
			closing += seg.length;
			continue;
		}
		if (seg.type === 'curve') break;
	}
	return closing;
}

function getCurveOpeningStraightSteps(curveSegments) {
	let opening = 0;
	for (const seg of curveSegments || []) {
		if (!seg || seg.type === 'terminator') break;
		if (seg.type === 'straight') {
			opening += seg.length;
			continue;
		}
		if (seg.type === 'curve') break;
	}
	return opening;
}

function getFirstCurveSegment(curveSegments) {
	for (const seg of curveSegments || []) {
		if (!seg || seg.type === 'terminator') break;
		if (seg.type === 'curve') return seg;
	}
	return null;
}

function computeSafeStartupCurveBgDisp(length) {
	const bounds = computeCurveBgDispBounds(length, SHARPNESS_MIN, { startupCurve: true });
	return clamp(
		Math.min(CURVE_SAFE_FIRST_CURVE_MAX_BG_DISP, bounds.maxBgDisp, Math.max(BG_DISP_MIN, length * CURVE_SAFE_FIRST_CURVE_MAX_RATE)),
		BG_DISP_MIN,
		BG_DISP_MAX
	);
}

function curveHasSafeRaceStart(curveSegments) {
	const firstCurve = getFirstCurveSegment(curveSegments);
	if (!firstCurve) return true;
	return getCurveOpeningStraightSteps(curveSegments) >= CURVE_SAFE_OPENING_STRAIGHT_STEPS
		&& firstCurve.length >= CURVE_SAFE_FIRST_CURVE_MIN_LENGTH
		&& (firstCurve.bg_disp || BG_DISP_MIN) <= computeSafeStartupCurveBgDisp(firstCurve.length);
}

function enforceSafeCurveRaceStart(curveSegments, targetSteps) {
	const working = buildCurveBodySegments(curveSegments);

	for (let guard = 0; guard < 16; guard++) {
		let opening = 0;
		let firstCurveIndex = -1;
		for (let i = 0; i < working.length; i++) {
			const seg = working[i];
			if (seg.type === 'straight') {
				opening += seg.length;
				continue;
			}
			if (seg.type === 'curve') {
				firstCurveIndex = i;
				break;
			}
		}

		if (firstCurveIndex < 0) break;

		const firstCurve = working[firstCurveIndex];
		if (opening < CURVE_SAFE_OPENING_STRAIGHT_STEPS) {
			const needed = CURVE_SAFE_OPENING_STRAIGHT_STEPS - opening;
			const spare = Math.max(0, firstCurve.length - CURVE_SAFE_FIRST_CURVE_MIN_LENGTH);
			const transfer = Math.min(needed, spare);
			if (transfer > 0) {
				if (firstCurveIndex > 0 && working[firstCurveIndex - 1].type === 'straight') {
					working[firstCurveIndex - 1].length += transfer;
				} else {
					working.splice(firstCurveIndex, 0, { type: 'straight', length: transfer, curve_byte: 0 });
					firstCurveIndex += 1;
				}
				firstCurve.length -= transfer;
				opening += transfer;
			}
		}

		if (opening < CURVE_SAFE_OPENING_STRAIGHT_STEPS || firstCurve.length < CURVE_SAFE_FIRST_CURVE_MIN_LENGTH) {
			firstCurve.type = 'straight';
			firstCurve.curve_byte = 0;
			delete firstCurve.bg_disp;
			continue;
		}

		firstCurve.bg_disp = Math.min(firstCurve.bg_disp || BG_DISP_MIN, computeSafeStartupCurveBgDisp(firstCurve.length));
		break;
	}

	return finalizeCurveSegments(working, targetSteps);
}

function enforceSafeCurveLoopClosure(curveSegments, targetSteps) {
	const working = buildCurveBodySegments(curveSegments);

	for (let guard = 0; guard < 16; guard++) {
		let closing = 0;
		let lastCurveIndex = -1;
		for (let i = working.length - 1; i >= 0; i--) {
			const seg = working[i];
			if (seg.type === 'straight') {
				closing += seg.length;
				continue;
			}
			if (seg.type === 'curve') {
				lastCurveIndex = i;
				break;
			}
		}

		if (lastCurveIndex < 0) break;
		if (closing >= CURVE_SAFE_CLOSING_STRAIGHT_STEPS) break;

		const lastCurve = working[lastCurveIndex];
		const needed = CURVE_SAFE_CLOSING_STRAIGHT_STEPS - closing;
		const spare = Math.max(0, lastCurve.length - CURVE_LEN_MIN);
		const transfer = Math.min(needed, spare);
		if (transfer > 0) {
			if (lastCurveIndex + 1 < working.length && working[lastCurveIndex + 1].type === 'straight') {
				working[lastCurveIndex + 1].length += transfer;
			} else {
				working.splice(lastCurveIndex + 1, 0, { type: 'straight', length: transfer, curve_byte: 0 });
			}
			lastCurve.length -= transfer;
			continue;
		}

		lastCurve.type = 'straight';
		lastCurve.curve_byte = 0;
		delete lastCurve.bg_disp;
	}

	return finalizeCurveSegments(working, targetSteps);
}

function decodeCurveBgDisplacement(curveSegments) {
	let accumulator = 0;
	const decoded = [];

	for (const seg of curveSegments || []) {
		if (!seg || seg.type === 'terminator') break;
		if (seg.type === 'straight') {
			for (let i = 0; i < seg.length; i++) decoded.push(accumulator & 0x03FF);
			continue;
		}

		const length = Math.max(1, seg.length | 0);
		const start = accumulator;
		accumulator += getCurveBgRuntimeDirection(seg.curve_byte) * (seg.bg_disp || 0);
		const stepDelta = Math.trunc(((seg.bg_disp || 0) * 0x10000) / length) * getCurveBgRuntimeDirection(seg.curve_byte);
		for (let step = 1; step <= length; step++) {
			decoded.push(((start * 0x10000) + (step * stepDelta)) >> 16 & 0x03FF);
		}
	}

	return decoded;
}

function curveBgLoopAligns(curveSegments, trackLength = 0) {
	const body = buildCurveBodySegments(curveSegments);
	if (body.length === 0) return true;
	const first = body[0];
	const last = body[body.length - 1];
	if (!first || !last || first.type !== 'straight' || last.type !== 'straight') return false;
	const decoded = decodeCurveBgDisplacement(body);
	if (decoded.length === 0) return true;
	if (!(Number.isInteger(trackLength) && trackLength > 0)) {
		return decoded[0] === decoded[decoded.length - 1];
	}
	const metrics = getCurveRuntimeSeamMetrics(body, trackLength);
	if (!metrics) return true;
	return metrics.displayJump === 0
		&& metrics.targetJump === 0
		&& metrics.sampleJump === 0;
}

function normalizeCurveBgDisplacement(curveSegments, options = {}) {
	const adjusted = cloneSegments(curveSegments);
	const protectStartupCurve = options.protectStartupCurve === true;
	const trackLength = Number.isInteger(options.trackLength) ? options.trackLength : 0;
	const protectedCurve = protectStartupCurve ? getFirstCurveSegment(adjusted) : null;
	for (const seg of adjusted) {
		if (seg.type !== 'curve') continue;
		const bounds = computeCurveBgDispBounds(seg.length, getCurveSharpness(seg.curve_byte));
		let maxBgDisp = bounds.maxBgDisp;
		if (protectedCurve && seg === protectedCurve) {
			maxBgDisp = Math.min(maxBgDisp, computeSafeStartupCurveBgDisp(seg.length));
		}
		seg.bg_disp = clamp(seg.bg_disp || BG_DISP_MIN, BG_DISP_MIN, maxBgDisp);
	}

	let delta = -computeNetBgDisp(adjusted);
	if (delta === 0) return adjusted;

	for (let i = adjusted.length - 1; i >= 0 && delta !== 0; i--) {
		const seg = adjusted[i];
		if (seg.type !== 'curve') continue;
		if (protectedCurve && seg === protectedCurve) continue;
		const runtimeDir = getCurveBgRuntimeDirection(seg.curve_byte);
		const sharpness = getCurveSharpness(seg.curve_byte);
		const bounds = computeCurveBgDispBounds(seg.length, sharpness);
		const current = clamp(seg.bg_disp || BG_DISP_MIN, bounds.minBgDisp, bounds.maxBgDisp);
		const next = Math.max(bounds.minBgDisp, Math.min(bounds.maxBgDisp, current + (delta * runtimeDir)));
		delta -= (next - current) * runtimeDir;
		seg.bg_disp = next;
	}

	if (delta !== 0 && protectedCurve) {
		const sharpness = getCurveSharpness(protectedCurve.curve_byte);
		const bounds = computeCurveBgDispBounds(protectedCurve.length, sharpness);
		const current = clamp(protectedCurve.bg_disp || BG_DISP_MIN, bounds.minBgDisp, Math.min(bounds.maxBgDisp, computeSafeStartupCurveBgDisp(protectedCurve.length)));
		const next = Math.max(bounds.minBgDisp, Math.min(Math.min(bounds.maxBgDisp, computeSafeStartupCurveBgDisp(protectedCurve.length)), current + (delta * getCurveBgRuntimeDirection(protectedCurve.curve_byte))));
		delta -= (next - current) * getCurveBgRuntimeDirection(protectedCurve.curve_byte);
		protectedCurve.bg_disp = next;
	}

	if (trackLength > 0) {
		let bestSegments = adjusted;
		let bestScore = buildCurveRuntimeSeamScore(adjusted, trackLength, 0);
		for (let pass = 0; pass < 4; pass++) {
			let improved = false;
			for (let i = bestSegments.length - 1; i >= 0; i--) {
				const seg = bestSegments[i];
				if (seg.type !== 'curve') continue;
				if (protectedCurve && seg === protectedCurve) continue;
				const sharpness = getCurveSharpness(seg.curve_byte);
				const bounds = computeCurveBgDispBounds(seg.length, sharpness);
				const current = clamp(seg.bg_disp || BG_DISP_MIN, bounds.minBgDisp, bounds.maxBgDisp);
				for (let deltaAdjust = -12; deltaAdjust <= 12; deltaAdjust++) {
					if (deltaAdjust === 0) continue;
					const next = clamp(current + deltaAdjust, bounds.minBgDisp, bounds.maxBgDisp);
					if (next === current) continue;
					const trial = cloneSegments(bestSegments);
					trial[i].bg_disp = next;
					const score = buildCurveRuntimeSeamScore(trial, trackLength, Math.abs(next - current));
					if (compareCurveRuntimeSeamScores(score, bestScore) < 0) {
						bestSegments = trial;
						bestScore = score;
						improved = true;
					}
				}
			}
			if (!improved) break;
		}
		return bestSegments;
	}

	return adjusted;
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
		current.totalDistance = Math.max(current.curveDistance, (current.endStep - current.startStep) << 2);
		current.meanSharpness = current.totalCurveSteps > 0
			? current.weightedSharpness / current.totalCurveSteps
			: current.peakSharpness;
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
					weightedSharpness: 0,
					peakSharpness: 0,
					segmentCount: 0,
				};
			}
			current.endStep = step + seg.length;
			current.totalCurveSteps += seg.length;
			current.weightedSharpness += sharpness * seg.length;
			current.peakSharpness = Math.max(current.peakSharpness, sharpness);
			current.segmentCount += 1;
			bridgeSteps = 0;
		} else if (current) {
			bridgeSteps += seg.length;
			if (bridgeSteps <= MAX_BRIDGE_STEPS) {
				current.endStep = step + seg.length;
			} else {
				finishCurrent();
			}
		}

		step += seg.length;
	}

	finishCurrent();
	return windows.filter(window => window.totalCurveSteps >= 6 && window.peakSharpness >= 3);
}

function buildCurveAwareTilesetPlan(rng, trackLength, curveSegments) {
	const windows = buildCurveWindows(curveSegments);
	const records = [];
	let lastOffset = null;
	let lastDistance = -SIGN_TILESET_MIN_SPACING;
	const strongWindows = windows.filter(window => window.peakSharpness >= 8 || window.curveDistance >= 80);
	const allowedOffsets = arguments.length > 3 && Array.isArray(arguments[3]) && arguments[3].length > 0
		? arguments[3].slice()
		: STANDARD_SIGN_TILESET_OFFSETS;

	function pickOffset(direction) {
		let choices = allowedOffsets.filter(offset => offset !== lastOffset);
		if (direction < 0) {
			const leftChoices = choices.filter(offset => (TILESET_SIGN_ID_MAP.get(offset) || []).some(id => LEFT_SIGN_IDS.has(id)));
			if (leftChoices.length > 0) choices = leftChoices;
		} else if (direction > 0) {
			const rightChoices = choices.filter(offset => (TILESET_SIGN_ID_MAP.get(offset) || []).some(id => RIGHT_SIGN_IDS.has(id)));
			if (rightChoices.length > 0) choices = rightChoices;
		}
		const selected = rng.choice(choices.length > 0 ? choices : allowedOffsets);
		lastOffset = selected;
		return selected;
	}

	const openingDirection = strongWindows[0] ? strongWindows[0].direction : (windows[0] ? windows[0].direction : 0);
	records.push({ distance: 0, tileset_offset: pickOffset(openingDirection) });
	lastDistance = 0;

	for (const window of strongWindows) {
		const desiredDistance = clamp(
			window.startDistance - window.leadDistance - rng.randInt(32, 96),
			0,
			Math.max(0, trackLength - 1)
		);
		if ((desiredDistance - lastDistance) < SIGN_TILESET_MIN_SPACING) continue;
		records.push({ distance: desiredDistance, tileset_offset: pickOffset(window.direction) });
		lastDistance = desiredDistance;
	}

	for (let i = 0; i + 1 < strongWindows.length; i++) {
		const gap = strongWindows[i + 1].startDistance - strongWindows[i].endDistance;
		if (gap < 1800) continue;
		const midpoint = clamp(
			Math.round((strongWindows[i].endDistance + strongWindows[i + 1].startDistance) / 2),
			0,
			Math.max(0, trackLength - 1)
		);
		if ((midpoint - lastDistance) < SIGN_TILESET_MIN_SPACING) continue;
		records.push({ distance: midpoint, tileset_offset: pickOffset(strongWindows[i + 1].direction) });
		lastDistance = midpoint;
	}

	if ((trackLength - lastDistance) > 1700) {
		const tailDistance = clamp(lastDistance + rng.randInt(900, 1300), 0, Math.max(0, trackLength - 1));
		if ((tailDistance - lastDistance) >= SIGN_TILESET_MIN_SPACING && tailDistance < trackLength) {
			const tailDirection = strongWindows.length > 0 ? strongWindows[strongWindows.length - 1].direction : 0;
			records.push({ distance: tailDistance, tileset_offset: pickOffset(tailDirection) });
		}
	}

	const sorted = records.sort((a, b) => a.distance - b.distance);
	const filtered = [];
	for (const record of sorted) {
		const prev = filtered[filtered.length - 1];
		if (prev && (record.distance - prev.distance) < SIGN_TILESET_MIN_SPACING) continue;
		filtered.push(record);
	}
	return enforceWrapSafeTilesetRecords(trackLength, filtered);
}

function buildCurveDrivenSignPlan(rng, trackLength, curveSegments, tilesetRecords) {
	const windows = buildCurveWindows(curveSegments);
	const records = [];
	const finishCutoff = trackLength - SIGN_FINISH_ZONE;
	let lastDistance = -SAFE_SIGN_SPACING_MIN;
	const transitionDistances = Array.isArray(tilesetRecords) ? tilesetRecords.slice(1).map(record => record.distance) : [];

	function tryAddSign(distance, direction, sharpness, preferredCount) {
		const clampedDistance = clamp(Math.round(distance), 0, finishCutoff - 1);
		if (clampedDistance <= lastDistance) return;
		if ((clampedDistance - lastDistance) < SAFE_SIGN_SPACING_MIN) return;
		if (transitionDistances.some(transitionDistance => Math.abs(transitionDistance - clampedDistance) < SAFE_SIGN_TILESET_GUARD_DISTANCE)) return;
		const activeTileset = getActiveTilesetRecord(tilesetRecords, clampedDistance);
		const tilesetOffset = activeTileset ? activeTileset.tileset_offset : 8;
		const count = clamp(preferredCount, 1, 4);
		const signId = pickSignIdForTileset(rng, tilesetOffset, direction);
		records.push({ distance: clampedDistance, count, sign_id: signId });
		lastDistance = clampedDistance;
	}

	for (const window of windows) {
		const strongWindow = window.peakSharpness >= 8 || window.curveDistance >= 80;
		const severeWindow = window.peakSharpness >= 18 || window.curveDistance >= 160;
		if (strongWindow) {
			const farApproachDistance = window.startDistance - window.leadDistance - rng.randInt(40, 96);
			const farApproachCount = clamp(Math.round(window.peakSharpness / 12) + 1, 1, 3);
			tryAddSign(farApproachDistance, window.direction, window.peakSharpness, farApproachCount);
			const nearLeadDistance = clamp(Math.round(window.leadDistance * 0.45), 88, 176);
			const nearApproachCount = clamp(Math.round(window.peakSharpness / 9) + 1, 2, 4);
			tryAddSign(window.startDistance - nearLeadDistance, window.direction, window.peakSharpness, nearApproachCount);
		} else {
			const approachDistance = window.startDistance - window.leadDistance;
			const approachCount = clamp(Math.round(window.peakSharpness / 10) + 1, 1, 4);
			tryAddSign(approachDistance, window.direction, window.peakSharpness, approachCount);
		}

		if (window.curveDistance >= 96 || window.peakSharpness >= 16) {
			const apexDistance = window.startDistance + Math.round(window.curveDistance * 0.45);
			const apexCount = clamp(Math.round(window.peakSharpness / 12) + 1, 1, 4);
			tryAddSign(apexDistance, window.direction, window.peakSharpness, apexCount);
		}

		if (severeWindow) {
			const exitDistance = window.endDistance - 96;
			tryAddSign(exitDistance, window.direction, window.peakSharpness, 2);
		}
	}

	let previousAnchor = 0;
	for (const window of windows) {
		const gap = window.startDistance - previousAnchor;
		if (gap >= 1400) {
			const midpoint = previousAnchor + Math.round(gap / 2);
			tryAddSign(midpoint, 0, 0, rng.choice([1, 1, 2]));
		}
		previousAnchor = window.endDistance;
	}
	if ((finishCutoff - previousAnchor) >= 1500) {
		const tailMidpoint = previousAnchor + Math.round((finishCutoff - previousAnchor) / 2);
		tryAddSign(tailMidpoint, 0, 0, rng.choice([1, 2]));
	}

	if (records.length === 0) {
		let pos = rng.randInt(220, 420);
		while (pos < finishCutoff) {
			tryAddSign(pos, 0, 0, rng.choice([1, 2]));
			pos += rng.randInt(320, 560);
		}
	}

	return records.sort((a, b) => a.distance - b.distance);
}

function buildCurveDrivenSlopeEvents(rng, trackLength, curveSegments) {
	const targetSteps = Math.floor(trackLength / 4);
	const minOpeningFlat = Math.min(VISUAL_SLOPE_SAFE_OPENING_FLAT_STEPS, Math.max(0, targetSteps - 8));
	const windows = buildCurveWindows(curveSegments);
	const events = [];
	let lastEndStep = 0;
	let elevationBias = 0;

	for (const window of windows) {
		const shouldSlope = window.peakSharpness >= 6 || window.curveDistance >= 56 || rng.randInt(0, 9) < 4;
		if (!shouldSlope) continue;

		const startStep = clamp(
			window.startStep - rng.randInt(8, 28),
			Math.max(lastEndStep + 24, minOpeningFlat),
			Math.max(Math.max(lastEndStep + 24, minOpeningFlat), targetSteps - 12)
		);
		if (startStep >= targetSteps - 4) continue;

		const maxLength = Math.max(8, Math.min(80, targetSteps - startStep));
		const desiredLength = clamp(
			Math.round((window.totalCurveSteps * 0.8) + (window.peakSharpness * 1.4) + rng.randInt(-6, 12)),
			16,
			32
		);
		const length = Math.min(desiredLength, maxLength);
		if (length < 8) continue;

		let direction;
		if (elevationBias >= 96) direction = -1;
		else if (elevationBias <= -96) direction = 1;
		else direction = rng.weightedChoice([-1, 1], [50 + Math.max(0, elevationBias), 50 + Math.max(0, -elevationBias)]);

		const sharpness = clamp(14 + Math.round(window.peakSharpness * 0.4) + rng.randInt(-2, 4), 10, 24);
		const bgVertDisp = (sharpness >= 18 || length >= 28) ? BG_VERT_DISP_STRONG : BG_VERT_DISP_SOFT;
		events.push({
			startStep,
			length,
			direction,
			sharpness,
			bgVertDisp,
		});
		lastEndStep = startStep + length;
		elevationBias += direction * Math.round(length * (sharpness / 12));
	}

	if (events.length === 0 && targetSteps >= 160 && rng.randInt(0, 9) < 7) {
		const startStep = clamp(rng.randInt(minOpeningFlat, Math.max(minOpeningFlat, targetSteps - 80)), minOpeningFlat, Math.max(minOpeningFlat, targetSteps - 32));
		events.push({
			startStep,
			length: Math.min(40, targetSteps - startStep),
			direction: rng.choice([-1, 1]),
			sharpness: 10,
			bgVertDisp: BG_VERT_DISP_SOFT,
		});
	}

	return events
		.sort((a, b) => ((b.length * b.sharpness) - (a.length * a.sharpness)) || (a.startStep - b.startStep))
		.slice(0, VISUAL_SLOPE_MAX_EVENTS)
		.sort((a, b) => a.startStep - b.startStep);
}

function buildFallbackSlopeEvents(rng, trackLength) {
	const targetSteps = Math.floor(trackLength / 4);
	if (targetSteps < 80) return [];
	const minOpeningFlat = Math.min(VISUAL_SLOPE_SAFE_OPENING_FLAT_STEPS, Math.max(8, targetSteps - 40));
	const startStep = clamp(rng.randInt(minOpeningFlat, Math.max(minOpeningFlat, targetSteps - 56)), minOpeningFlat, Math.max(minOpeningFlat, targetSteps - 40));
	const length = clamp(rng.randInt(24, 40), 16, Math.max(16, targetSteps - startStep - 8));
	return [{
		startStep,
		length: Math.min(length, 24),
		direction: rng.choice([-1, 1]),
		sharpness: 8,
		bgVertDisp: BG_VERT_DISP_SOFT,
	}];
}

function buildSlopeSegmentsFromEvents(targetSteps, events) {
	const segments = [];
	let cursor = 0;
	for (const event of events || []) {
		const startStep = clamp(event.startStep, cursor, targetSteps);
		if (startStep > cursor) {
			segments.push({ type: 'flat', length: startStep - cursor, slope_byte: 0, bg_vert_disp: 0 });
			cursor = startStep;
		}
		const length = Math.min(event.length, targetSteps - cursor);
		if (length <= 0) continue;
		segments.push({
			type: 'slope',
			length,
			slope_byte: encodeDirectedByte(event.direction, clamp(event.sharpness, 1, 47)),
			bg_vert_disp: event.bgVertDisp,
		});
		cursor += length;
	}
	if (cursor < targetSteps) {
		segments.push({ type: 'flat', length: targetSteps - cursor, slope_byte: 0, bg_vert_disp: 0 });
	}
	const merged = [];
	for (const seg of segments) {
		if (seg.length <= 0) continue;
		const prev = merged[merged.length - 1];
		if (prev && prev.type === seg.type && prev.slope_byte === seg.slope_byte && prev.bg_vert_disp === seg.bg_vert_disp) {
			prev.length += seg.length;
		} else {
			merged.push(seg);
		}
	}
	merged.push({ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] });
	return merged;
}

function normalizeSlopeEventsToEnvelope(trackLength, initialBgDisp, events) {
	const targetSteps = Math.floor(trackLength / 4);
	const adjusted = (events || []).map(event => ({ ...event }));
	for (let attempt = 0; attempt < 48; attempt++) {
		const merged = buildSlopeSegmentsFromEvents(targetSteps, adjusted);
		const decodedOffsets = decodeVisualSlopeBgDisplacement(initialBgDisp, merged);
		if (visualSlopeOffsetsWithinSafeEnvelope(decodedOffsets)) {
			return merged;
		}
		if (adjusted.length === 0) break;
		adjusted.sort((a, b) => ((b.length * b.sharpness) - (a.length * a.sharpness)) || (b.length - a.length));
		const event = adjusted[0];
		if (event.sharpness > 12) {
			event.sharpness = Math.max(10, event.sharpness - 4);
			continue;
		}
		if (event.length > 16) {
			event.length = Math.max(8, event.length - 4);
			continue;
		}
		adjusted.shift();
	}
	return null;
}

function ensureSlopeEvents(trackLength, initialBgDisp, events, rng) {
	let normalized = normalizeSlopeEventsToEnvelope(trackLength, initialBgDisp, events);
	if (normalized && normalized.some(seg => seg.type === 'slope') && visualSlopeLoopAligns(initialBgDisp, normalized)) return normalized;
	const closure = buildSlopeClosureEvents(trackLength, rng);
	if (closure.length > 0) {
		normalized = normalizeSlopeEventsToEnvelope(trackLength, initialBgDisp, closure);
		if (normalized && normalized.some(seg => seg.type === 'slope') && visualSlopeLoopAligns(initialBgDisp, normalized)) return normalized;
	}
	const fallback = buildFallbackSlopeEvents(rng, trackLength);
	if (fallback.length === 0) return normalized;
	normalized = normalizeSlopeEventsToEnvelope(trackLength, initialBgDisp, fallback);
	if (normalized && normalized.some(seg => seg.type === 'slope') && visualSlopeLoopAligns(initialBgDisp, normalized)) return normalized;
	const softerFallback = fallback.map(event => ({ ...event, sharpness: 6, length: Math.min(event.length, 16), bgVertDisp: BG_VERT_DISP_SOFT }));
	normalized = normalizeSlopeEventsToEnvelope(trackLength, initialBgDisp, softerFallback);
	if (normalized && normalized.some(seg => seg.type === 'slope') && visualSlopeLoopAligns(initialBgDisp, normalized)) return normalized;
	return buildFlatSlopeRle(trackLength)[1];
}

function generateCurveRle(rng, trackLength, templateTrack = null) {
  const targetSteps = Math.floor(trackLength / 4);
  let segments = [];
  let remaining = targetSteps;
  let lastWasCurve = false;
  let netCurveBias = 0;

	if (remaining > 0) {
		const openingStraight = Math.min(rng.randInt(20, 64), remaining);
		segments.push({ type: 'straight', length: openingStraight, curve_byte: 0 });
		remaining -= openingStraight;
	}

	const closingStraight = remaining > 0 ? Math.min(rng.randInt(24, 72), remaining) : 0;

  while (remaining > 0) {
		if (remaining <= closingStraight) {
			segments.push({ type: 'straight', length: remaining, curve_byte: 0 });
			remaining = 0;
			break;
		}

    if (lastWasCurve) {
      const segLen = Math.min(rng.randInt(STRAIGHT_LEN_MIN, 40), remaining);
      if (segLen > 0) {
        segments.push({ type: 'straight', length: segLen, curve_byte: 0 });
        remaining -= segLen;
        lastWasCurve = false;
      }
      continue;
    }

    if (remaining <= 0) break;

    const segType = rng.weightedChoice(['straight', 'curve'], [42, 58]);

    if (segType === 'straight') {
      const rawLen = rng.randInt(STRAIGHT_LEN_MIN, STRAIGHT_LEN_MAX);
      const segLen = Math.min(rawLen, remaining);
      segments.push({ type: 'straight', length: segLen, curve_byte: 0 });
      remaining -= segLen;
      lastWasCurve = false;
    } else {
      const rawLen = rng.randInt(CURVE_LEN_MIN, CURVE_LEN_MAX);
      let segLen = Math.min(rawLen, remaining);
      if (segLen < CURVE_LEN_MIN && remaining >= CURVE_LEN_MIN) {
        segments.push({ type: 'straight', length: remaining, curve_byte: 0 });
        remaining = 0;
        break;
      }

      const directionWeights = netCurveBias > 400
			? [70, 30]
			: netCurveBias < -400
				? [30, 70]
				: [48, 52];
		const direction = rng.weightedChoice([-1, 1], directionWeights);
      const sharpness = _pickSharpness(rng);
		const curveByte = encodeDirectedByte(direction, sharpness);
		const bgDisp = _pickBgDisp(rng, direction, segLen, sharpness);
		pushCurveSegment(segments, { type: 'curve', length: segLen, curve_byte: curveByte, bg_disp: bgDisp });
      remaining -= segLen;
      lastWasCurve = true;
		netCurveBias += direction * sharpness * segLen;
    }
  }

	const profile = buildCurveGenerationProfile(templateTrack?.curve_rle_segments || []);
	const targets = buildCurveTargets(profile, targetSteps);
	const expandedBody = expandCurveComplexity(rng, segments, targets);
	const softenedBody = softenUndrivableTransitions(expandedBody);
	const finalized = finalizeCurveSegments(softenedBody, targetSteps);
	const startupSafe = enforceSafeCurveRaceStart(finalized, targetSteps);
	return enforceSafeCurveLoopClosure(startupSafe, targetSteps);
}

function decompressCurveSegments(segments) {
  const result = [];
  for (const seg of segments) {
    if (seg.type === 'straight' || seg.type === 'curve') {
      for (let i = 0; i < seg.length; i++) result.push(seg.curve_byte);
    } else if (seg.type === 'terminator') {
      result.push(CURVE_SENTINEL);
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// RAND-003: Slope generation
// ---------------------------------------------------------------------------

function generateSlopeRle(rng, trackLength, curveSegments) {
  const targetSteps = Math.floor(trackLength / 4);
  const initialBgDisp = 0;
  const events = buildCurveDrivenSlopeEvents(rng, trackLength, curveSegments);
	const normalized = ensureSlopeEvents(trackLength, initialBgDisp, events, rng);
	if (!normalized) {
		return buildFlatSlopeRle(trackLength);
	}

	return [initialBgDisp, normalized];
}

function decodeVisualSlopeBgDisplacement(initialBgDisp, slopeSegments) {
	let accumulator = (initialBgDisp << 24) >> 24;
	const decoded = [];

	for (const seg of slopeSegments || []) {
		if (seg.type === 'terminator') break;

		let stepDelta = 0;
		if (seg.type === 'slope') {
			stepDelta = ((seg.bg_vert_disp & 0xFF) << 8) >>> 0;
			if ((seg.slope_byte & 0x40) !== 0) stepDelta = (-stepDelta) >>> 0;
		}

		for (let i = 0; i < seg.length; i++) {
			accumulator = (((accumulator & 0xFFFF) << 16) | ((accumulator >>> 16) & 0xFFFF)) >>> 0;
			accumulator = (accumulator + stepDelta) >>> 0;
			accumulator = (((accumulator & 0xFFFF) << 16) | ((accumulator >>> 16) & 0xFFFF)) >>> 0;
			decoded.push((accumulator << 24) >> 24);
		}
	}

	return decoded;
}

function visualSlopeOffsetsWithinSafeEnvelope(decodedOffsets) {
	if (!Array.isArray(decodedOffsets) || decodedOffsets.length === 0) return true;

	let globalMin = Infinity;
	let globalMax = -Infinity;
	let startMin = Infinity;
	let startMax = -Infinity;
	const startWindow = Math.min(decodedOffsets.length, VISUAL_SLOPE_SAFE_START_WINDOW_STEPS);

	for (let i = 0; i < decodedOffsets.length; i++) {
		const value = decodedOffsets[i];
		if (value < globalMin) globalMin = value;
		if (value > globalMax) globalMax = value;
		if (i < startWindow) {
			if (value < startMin) startMin = value;
			if (value > startMax) startMax = value;
		}
	}

	return globalMin >= VISUAL_SLOPE_SAFE_GLOBAL_MIN
		&& globalMax <= VISUAL_SLOPE_SAFE_GLOBAL_MAX
		&& startMin >= VISUAL_SLOPE_SAFE_START_MIN
		&& startMax <= VISUAL_SLOPE_SAFE_START_MAX;
}

function getVisualSlopeOpeningFlatSteps(slopeSegments) {
	for (const seg of slopeSegments || []) {
		if (!seg || seg.type === 'terminator') break;
		if (seg.type === 'flat') return seg.length;
		if (seg.type === 'slope') return 0;
	}
	return 0;
}

function getVisualSlopeClosingFlatSteps(slopeSegments) {
	for (let i = (slopeSegments || []).length - 1; i >= 0; i--) {
		const seg = slopeSegments[i];
		if (!seg || seg.type === 'terminator') continue;
		if (seg.type === 'flat') return seg.length;
		if (seg.type === 'slope') return 0;
	}
	return 0;
}

function visualSlopeLoopAligns(initialBgDisp, slopeSegments) {
	if (!Array.isArray(slopeSegments) || slopeSegments.length === 0) return true;
	const decoded = decodeVisualSlopeBgDisplacement(initialBgDisp, slopeSegments);
	if (decoded.length === 0) return true;
	return decoded[decoded.length - 1] === (initialBgDisp | 0)
		&& getVisualSlopeClosingFlatSteps(slopeSegments) >= VISUAL_SLOPE_SAFE_CLOSING_FLAT_STEPS;
}

function buildSlopeClosureEvents(trackLength, rng) {
	const targetSteps = Math.floor(trackLength / 4);
	const openingFlat = Math.min(VISUAL_SLOPE_SAFE_OPENING_FLAT_STEPS, Math.max(0, targetSteps - 8));
	const closingFlat = Math.min(VISUAL_SLOPE_SAFE_CLOSING_FLAT_STEPS, Math.max(0, targetSteps - openingFlat - 8));
	const usableSteps = targetSteps - openingFlat - closingFlat;
	if (usableSteps < 64) return [];
	const firstLength = clamp(rng.randInt(20, 32), 16, Math.max(16, Math.floor((usableSteps - 16) / 2)));
	const secondLength = clamp(firstLength + rng.randInt(-4, 4), 16, Math.max(16, usableSteps - firstLength - 16));
	const gap = usableSteps - firstLength - secondLength;
	if (gap < 16) return [];
	const direction = rng.choice([-1, 1]);
	const sharpness = rng.randInt(12, 20);
	const bgVertDisp = rng.choice(BG_VERT_DISP_VALUES);
	return [
		{
			startStep: openingFlat,
			length: firstLength,
			direction,
			sharpness,
			bgVertDisp,
		},
		{
			startStep: openingFlat + firstLength + gap,
			length: secondLength,
			direction: -direction,
			sharpness,
			bgVertDisp,
		},
	];
}

function visualSlopeHasSafeRaceStart(initialBgDisp, slopeSegments) {
	if (initialBgDisp !== 0) return false;
	const hasSlope = Array.isArray(slopeSegments) && slopeSegments.some(seg => seg && seg.type === 'slope');
	if (!hasSlope) return true;
	return getVisualSlopeOpeningFlatSteps(slopeSegments) >= VISUAL_SLOPE_SAFE_OPENING_FLAT_STEPS;
}

function buildFlatSlopeRle(trackLength) {
	const targetSteps = Math.floor(trackLength / 4);
	return [
		0,
		[
			{ type: 'flat', length: targetSteps, slope_byte: 0, bg_vert_disp: 0 },
			{ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
		],
	];
}

function generatePhysSlopeRle(rng, trackLength, slopeSegments) {
  const targetSteps = Math.floor(trackLength / 4);
  const physSegments = [];

  for (const seg of slopeSegments) {
    if (seg.type === 'terminator') break;
    const { length, slope_byte } = seg;
		if (slope_byte === 0) {
			physSegments.push({ type: 'segment', length, phys_byte: PHYS_FLAT });
			continue;
		}

		const direction = getCurveDirection(slope_byte);
		const shoulder = Math.min(8, Math.floor(length / 4));
		const core = length - (shoulder * 2);
		if (core < 4) {
			physSegments.push({ type: 'segment', length, phys_byte: PHYS_FLAT });
			continue;
		}
		if (shoulder > 0) physSegments.push({ type: 'segment', length: shoulder, phys_byte: PHYS_FLAT });
		physSegments.push({ type: 'segment', length: core, phys_byte: direction < 0 ? PHYS_DOWN : PHYS_UP });
		if (shoulder > 0) physSegments.push({ type: 'segment', length: shoulder, phys_byte: PHYS_FLAT });
  }

	for (let i = physSegments.length - 1; i > 0; i--) {
		const prev = physSegments[i - 1];
		const seg = physSegments[i];
		if (prev.type === 'segment' && seg.type === 'segment' && prev.phys_byte === seg.phys_byte) {
			prev.length += seg.length;
			physSegments.splice(i, 1);
		}
	}

  // Pad or trim to exact targetSteps
  let total = physSegments.reduce((s, seg) => s + seg.length, 0);
  if (total < targetSteps) {
    physSegments.push({ type: 'segment', length: targetSteps - total, phys_byte: PHYS_FLAT });
  } else if (total > targetSteps) {
    let excess = total - targetSteps;
    for (let i = physSegments.length - 1; i >= 0; i--) {
      if (physSegments[i].type === 'segment') {
        if (physSegments[i].length > excess) {
          physSegments[i].length -= excess;
          break;
        } else {
          excess -= physSegments[i].length;
          physSegments.splice(i, 1);
        }
      }
    }
  }

  physSegments.push({ type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] });
  return physSegments;
}

// ---------------------------------------------------------------------------
// RAND-004: Sign placement
// ---------------------------------------------------------------------------


function getActiveTilesetRecord(signTileset, distance) {
	if (!Array.isArray(signTileset) || signTileset.length === 0) return null;
	let index = 0;
	while (index + 1 < signTileset.length && signTileset[index + 1].distance <= distance) {
		index++;
	}
	return signTileset[index] || null;
}
function pickSignIdForTileset(rng, tilesetOffset, directionalHint = 0) {
	const allowedBase = TILESET_SIGN_ID_MAP.get(tilesetOffset) || SIGN_ID_POOL;
	const allowed = allowedBase.filter(id => !SPECIAL_SIGN_IDS.has(id));
	if (directionalHint < 0) {
		const left = allowed.filter(id => LEFT_SIGN_IDS.has(id));
		if (left.length > 0) return rng.choice(left);
	}
	if (directionalHint > 0) {
		const right = allowed.filter(id => RIGHT_SIGN_IDS.has(id));
		if (right.length > 0) return rng.choice(right);
	}
	const neutral = allowed.filter(id => !LEFT_SIGN_IDS.has(id) && !RIGHT_SIGN_IDS.has(id));
	return rng.choice(neutral.length > 0 ? neutral : allowed);
}

function generateSignData(rng, trackLength, curveSegments, tilesetRecords) {
  return buildCurveDrivenSignPlan(rng, trackLength, curveSegments, tilesetRecords);
}

function getAllowedSignTilesetOffsets(track) {
	const horizonOverride = Number.isInteger(track?._assigned_horizon_override)
		? track._assigned_horizon_override
		: (Number.isInteger(track?.horizon_override) ? track.horizon_override : 0);
	return horizonOverride ? HORIZON_SIGN_TILESET_OFFSETS : STANDARD_SIGN_TILESET_OFFSETS;
}

function generateSignTileset(rng, trackLength, curveSegments = [], track = null) {
	return [buildCurveAwareTilesetPlan(rng, trackLength, curveSegments, getAllowedSignTilesetOffsets(track)), []];
}

// ---------------------------------------------------------------------------
// RAND-005: Minimap generation
// ---------------------------------------------------------------------------

function generateMinimap(track) {
	const { buildGeneratedMinimapPosPairs } = require('../lib/generated_minimap_pos');
	const preview = require('../lib/minimap_render').buildGeneratedMinimapPreview(track);
	const pairs = buildGeneratedMinimapPosPairs(track);
	track._generated_minimap_preview = {
		preview_slug: preview.slug,
		transform: preview.transform,
		match_percent: preview.match_percent,
		preview_match_percent: preview.match_percent,
		thickness_aware_match_percent: preview.match_percent,
		sample_count: pairs.length,
	};
	return [pairs, track.minimap_pos_trailing || []];
}

// ---------------------------------------------------------------------------
// RAND-006: Art and config assignment
// ---------------------------------------------------------------------------

const CHAMPIONSHIP_ART_SETS = [
  { art_name: 'San_Marino',    horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'San_Marino_bg_palette',       sideline_label: 'San_Marino_sideline_style',
    road_label: 'San_Marino_road_style',             finish_label: 'San_Marino_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_San_Marino',     bg_tilemap_label: 'Track_bg_tilemap_San_Marino',
    minimap_tiles_label: 'Minimap_tiles_San_Marino', minimap_map_label: 'Minimap_map_San_Marino' },
  { art_name: 'Brazil',        horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Brazil_bg_palette',           sideline_label: 'Brazil_sideline_style',
    road_label: 'Brazil_road_style',                 finish_label: 'Brazil_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Brazil',         bg_tilemap_label: 'Track_bg_tilemap_Brazil',
    minimap_tiles_label: 'Minimap_tiles_Brazil',     minimap_map_label: 'Minimap_map_Brazil' },
  { art_name: 'France',        horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'France_bg_palette',           sideline_label: 'France_sideline_style',
    road_label: 'France_road_style',                 finish_label: 'France_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_France',         bg_tilemap_label: 'Track_bg_tilemap_France',
    minimap_tiles_label: 'Minimap_tiles_France',     minimap_map_label: 'Minimap_map_France' },
  { art_name: 'Hungary',       horizon_override: 0, steering: '$002c002e',
    bg_palette_label: 'Hungary_bg_palette',          sideline_label: 'Hungary_sideline_style',
    road_label: 'Hungary_road_style',                finish_label: 'Hungary_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Hungary',        bg_tilemap_label: 'Track_bg_tilemap_Hungary',
    minimap_tiles_label: 'Minimap_tiles_Hungary',    minimap_map_label: 'Minimap_map_Hungary' },
  { art_name: 'West_Germany',  horizon_override: 1, steering: '$002B002B',
    bg_palette_label: 'West_Germany_bg_palette',     sideline_label: 'West_Germany_sideline_style',
    road_label: 'West_Germany_road_style',           finish_label: 'West_Germany_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_West_Germany',   bg_tilemap_label: 'Track_bg_tilemap_West_Germany',
    minimap_tiles_label: 'Minimap_tiles_West_Germany', minimap_map_label: 'Minimap_map_West_Germany' },
  { art_name: 'Usa',           horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Usa_bg_palette',              sideline_label: 'Usa_sideline_style',
    road_label: 'Usa_road_style',                    finish_label: 'Usa_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Usa',            bg_tilemap_label: 'Track_bg_tilemap_Usa',
    minimap_tiles_label: 'Minimap_tiles_USA',        minimap_map_label: 'Minimap_map_USA' },
  { art_name: 'Canada',        horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Canada_bg_palette',           sideline_label: 'Canada_sideline_style',
    road_label: 'Canada_road_style',                 finish_label: 'Canada_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Canada',         bg_tilemap_label: 'Track_bg_tilemap_Canada',
    minimap_tiles_label: 'Minimap_tiles_Canada',     minimap_map_label: 'Minimap_map_Canada' },
  { art_name: 'Great_Britain', horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Great_Britain_bg_palette',    sideline_label: 'Great_Britain_sideline_style',
    road_label: 'Great_Britain_road_style',          finish_label: 'Great_Britain_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Great_Britain',  bg_tilemap_label: 'Track_bg_tilemap_Great_Britain',
    minimap_tiles_label: 'Minimap_tiles_Great_Britain', minimap_map_label: 'Minimap_map_Great_Britain' },
  { art_name: 'Italy',         horizon_override: 1, steering: '$002B002B',
    bg_palette_label: 'Italy_bg_palette-2',          sideline_label: 'Italy_sideline_style',
    road_label: 'Italy_road_style',                  finish_label: 'Italy_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Italy',          bg_tilemap_label: 'Track_bg_tilemap_Italy',
    minimap_tiles_label: 'Minimap_tiles_Italy',      minimap_map_label: 'Minimap_map_Italy' },
  { art_name: 'Portugal',      horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Portugal_bg_palette',         sideline_label: 'Portugal_sideline_style',
    road_label: 'Portugal_road_style',               finish_label: 'Portugal_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Portugal',       bg_tilemap_label: 'Track_bg_tilemap_Portugal',
    minimap_tiles_label: 'Minimap_tiles_Portugal',   minimap_map_label: 'Minimap_map_Portugal' },
  { art_name: 'Spain',         horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Spain_bg_palette',            sideline_label: 'Spain_sideline_style',
    road_label: 'Spain_road_style',                  finish_label: 'Spain_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Spain',          bg_tilemap_label: 'Track_bg_tilemap_Spain',
    minimap_tiles_label: 'Minimap_tiles_Spain',      minimap_map_label: 'Minimap_map_Spain' },
  { art_name: 'Mexico',        horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Mexico_bg_palette',           sideline_label: 'Mexico_sideline_style',
    road_label: 'Mexico_road_style',                 finish_label: 'Mexico_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Mexico',         bg_tilemap_label: 'Track_bg_tilemap_Mexico',
    minimap_tiles_label: 'Minimap_tiles_Mexico',     minimap_map_label: 'Minimap_map_Mexico' },
  { art_name: 'Japan',         horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Japan_bg_palette',            sideline_label: 'Japan_sideline_style',
    road_label: 'Japan_road_style',                  finish_label: 'Japan_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Japan',          bg_tilemap_label: 'Track_bg_tilemap_Japan',
    minimap_tiles_label: 'Minimap_tiles_Japan',      minimap_map_label: 'Minimap_map_Japan' },
  { art_name: 'Belgium',       horizon_override: 1, steering: '$002B002B',
    bg_palette_label: 'Belgium_bg_palette',          sideline_label: 'Belgium_sideline_style',
    road_label: 'Belgium_road_style',                finish_label: 'Belgium_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Belgium',        bg_tilemap_label: 'Track_bg_tilemap_Belgium',
    minimap_tiles_label: 'Minimap_tiles_Belgium',    minimap_map_label: 'Minimap_map_Belgium' },
  { art_name: 'Australia',     horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Australia_bg_palette',        sideline_label: 'Australia_sideline_style',
    road_label: 'Australia_road_style',              finish_label: 'Australia_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Australia',      bg_tilemap_label: 'Track_bg_tilemap_Australia',
    minimap_tiles_label: 'Minimap_tiles_Australia',  minimap_map_label: 'Minimap_map_Australia' },
  { art_name: 'Monaco',        horizon_override: 0, steering: '$002B002B',
    bg_palette_label: 'Monaco_bg_palette',           sideline_label: 'Monaco_sideline_style',
    road_label: 'Monaco_road_style',                 finish_label: 'Monaco_finish_line_style',
    bg_tiles_label: 'Track_bg_tiles_Monaco',         bg_tilemap_label: 'Track_bg_tilemap_Monaco',
    minimap_tiles_label: 'Minimap_tiles_Monaco',     minimap_map_label: 'Minimap_map_Monaco' },
];

const CHAMPIONSHIP_TRACK_NAMES = [
  'San Marino', 'Brazil', 'France', 'Hungary', 'West Germany',
  'USA', 'Canada', 'Great Britain', 'Italy', 'Portugal',
  'Spain', 'Mexico', 'Japan', 'Belgium', 'Australia', 'Monaco',
];

function _shuffleList(items, rng) {
  const lst = items.slice();
  for (let i = lst.length - 1; i > 0; i--) {
    const j = rng.next() % (i + 1);
    [lst[i], lst[j]] = [lst[j], lst[i]];
  }
  return lst;
}

function randomizeArtConfig(masterSeed, verbose = false) {
  const rng = new XorShift32(deriveSubseed(masterSeed, MOD_TRACK_CONFIG));
  const shuffled = _shuffleList(CHAMPIONSHIP_ART_SETS, rng);
  if (verbose) {
    for (let i = 0; i < shuffled.length; i++) {
      const origName = CHAMPIONSHIP_TRACK_NAMES[i];
      process.stdout.write(`  Slot ${String(i).padStart(2)} (${origName.padEnd(15)}) <- art set: ${shuffled[i].art_name}\n`);
    }
  }
  return shuffled;
}

function _steeringComment(steeringVal) {
  const s = steeringVal.toLowerCase().replace(/\$/g, '');
  if (s.length === 8) {
    try {
      const straight = parseInt(s.slice(0, 4), 16);
      const curve    = parseInt(s.slice(4), 16);
      return `straight=$${s.slice(0,4).toUpperCase()} (${straight}), curve=$${s.slice(4).toUpperCase()} (${curve})`;
    } catch (e) { /* fall through */ }
  }
  return steeringVal;
}

function buildTrackConfigAsm(artAssignment, originalAsmPath) {
  const content = fs.readFileSync(originalAsmPath, 'utf8');
  const lines = content.split('\n').map(l => l + '\n');
  // Last element may be empty if file ended with newline
  // We'll work with lines-with-newlines for position tracking

  // Locate Track_data: label
  let trackDataStart = null;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === 'Track_data:') {
      trackDataStart = i;
      break;
    }
  }
  if (trackDataStart === null) {
    throw new Error(`Could not find "Track_data:" label in ${originalAsmPath}`);
  }

  const LINES_PER_BLOCK = 20;

  // Find block starts by "; <Track Name>" comment lines
  const blockStarts = {};
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    if (stripped.startsWith(';') && !stripped.startsWith(';;')) {
      const candidate = stripped.slice(1).trim();
      if (CHAMPIONSHIP_TRACK_NAMES.includes(candidate)) {
        blockStarts[candidate] = i;
      }
    }
  }

  const missing = CHAMPIONSHIP_TRACK_NAMES.filter(n => !(n in blockStarts));
  if (missing.length > 0) {
    throw new Error(`Only found ${Object.keys(blockStarts).length}/16 championship track blocks. Missing: ${missing.join(', ')}`);
  }

  function extractDcLabel(line) {
    const parts = line.split('\t');
    if (parts.length >= 3) {
      return parts[2].split(';')[0].trim();
    }
    return '';
  }

  const newLines = lines.slice();

  for (let slotIdx = 0; slotIdx < CHAMPIONSHIP_TRACK_NAMES.length; slotIdx++) {
    const trackName = CHAMPIONSHIP_TRACK_NAMES[slotIdx];
    const art = artAssignment[slotIdx];
    const blockStart = blockStarts[trackName];

    const blockLines = [];
    for (let j = 0; j < LINES_PER_BLOCK; j++) {
      blockLines.push((newLines[blockStart + j] || '\n').replace(/\r?\n$/, ''));
    }

		const signDataLabel    = extractDcLabel(blockLines[11]);
		const signTilesetLabel = extractDcLabel(blockLines[12]);
		const minimapPosLabel  = extractDcLabel(blockLines[13]);
		const minimapTilesLabel = extractDcLabel(blockLines[1]);
		const minimapMapLabel = extractDcLabel(blockLines[4]);
		const curveDataLabel   = extractDcLabel(blockLines[14]);
    const slopeDataLabel   = extractDcLabel(blockLines[15]);
    const physSlopeLabel   = extractDcLabel(blockLines[16]);
    const lapTimePtrVal    = extractDcLabel(blockLines[17]);
    const lapTargetsLabel  = extractDcLabel(blockLines[18]);
    const trackLengthVal   = extractDcLabel(blockLines[10]);
    const steeringLabel    = blockLines.length > 19 ? extractDcLabel(blockLines[19]) : art.steering;

    let lapTimeComment;
    if (lapTimePtrVal === 'Track_lap_time_records') {
      lapTimeComment = 'base = $FFFFFD00, +$08 per track';
    } else {
      const offset = lapTimePtrVal.replace('$FFFFFD', '');
      lapTimeComment = `Track_lap_time_records + $${offset}`;
    }

    const h = art.horizon_override;
    const horizonFlagStr  = h ? '$0001' : '$0000';
    const horizonComment  = h ? '1 = special sky colour patch applied each frame' : '0 = default sky';

		const useExistingMinimapLabels = false;
		const newBlock = [
		  `; ${trackName}\n`,
		  `\tdc.l\t${useExistingMinimapLabels ? minimapTilesLabel : art.minimap_tiles_label} ; ${trackName} tiles used for minimap\n`,
		  `\tdc.l\t${art.bg_tiles_label} ; ${trackName} tiles used for background\n`,
		  `\tdc.l\t${art.bg_tilemap_label} ; ${trackName} background tile mapping\n`,
		  `\tdc.l\t${useExistingMinimapLabels ? minimapMapLabel : art.minimap_map_label} ; ${trackName} tile mapping for minimap\n`,
      `\tdc.l\t${art.bg_palette_label} ; ${trackName} background palette\n`,
      `\tdc.l\t${art.sideline_label} ; ${trackName} sideline style\n`,
      `\tdc.l\t${art.road_label} ; ${trackName} road style data\n`,
      `\tdc.l\t${art.finish_label} ; ${trackName} finish line style\n`,
      `\tdc.w\t${horizonFlagStr} ; horizon override flag (${horizonComment})\n`,
      `\tdc.w\t${trackLengthVal} ; track length\n`,
      `\tdc.l\t${signDataLabel} ; ${trackName} signs data\n`,
      `\tdc.l\t${signTilesetLabel} ; ${trackName} tileset for signs\n`,
      `\tdc.l\t${minimapPosLabel} ; ${trackName} map for minimap position\n`,
      `\tdc.l\t${curveDataLabel} ; ${trackName} curve data\n`,
      `\tdc.l\t${slopeDataLabel} ; ${trackName} slope data (visual; decoded to Visual_slope_data)\n`,
      `\tdc.l\t${physSlopeLabel} ; ${trackName} physical slope data (decoded to Physical_slope_data; hill RPM modifier)\n`,
      `\tdc.l\t${lapTimePtrVal} ; ${trackName} BCD lap-time record pointer (${lapTimeComment})\n`,
      `\tdc.l\t${lapTargetsLabel} ; ${trackName} per-lap target time table (15 \u00d7 3-byte BCD entries)\n`,
      `\tdc.l\t${art.steering} ; steering divisors: ${_steeringComment(art.steering)}\n`,
    ];

    newLines.splice(blockStart, LINES_PER_BLOCK, ...newBlock);
  }

  return newLines.join('');
}

function injectArtConfig(artAssignment, repoRoot, dryRun = false, verbose = false) {
  const asmPath = path.join(repoRoot, 'src', 'track_config_data.asm');
  if (!fs.existsSync(asmPath)) {
    throw new Error(`track_config_data.asm not found: ${asmPath}`);
  }

  const newContent = buildTrackConfigAsm(artAssignment, asmPath);

  if (dryRun) {
    if (verbose) process.stdout.write('  [dry-run] Would rewrite src/track_config_data.asm with new art assignment.\n');
    return true;
  }

  fs.writeFileSync(asmPath, newContent, 'utf8');
  if (verbose) process.stdout.write(`  Rewrote ${asmPath} with shuffled art assignment.\n`);
  return true;
}

// ---------------------------------------------------------------------------
// Track length picker
// ---------------------------------------------------------------------------

function pickTrackLength(rng, isPrelim = false) {
  if (isPrelim) {
    const raw = rng.randInt(2000, 3500);
    return Math.floor(raw / TRACK_LENGTH_STEP) * TRACK_LENGTH_STEP || TRACK_LENGTH_STEP;
  }
  const raw = rng.randInt(
    Math.floor(TRACK_LENGTH_MIN / TRACK_LENGTH_STEP),
    Math.floor(TRACK_LENGTH_MAX / TRACK_LENGTH_STEP)
  );
  return raw * TRACK_LENGTH_STEP;
}

// ---------------------------------------------------------------------------
// Public entry point: randomize a single track
// ---------------------------------------------------------------------------

function randomizeOneTrack(track, masterSeed, verbose = false) {
	const slug = track.slug || '?';
	const isPrelim = slug.includes('prelim');
	const originalLength = track.track_length;
	track._preserve_original_sign_cadence = false;
	track._runtime_safe_randomized = true;
	if (!Array.isArray(track._original_minimap_pos)) {
		track._original_minimap_pos = JSON.parse(JSON.stringify(track.minimap_pos || []));
	}

  if (verbose) process.stdout.write(`  Randomizing track: ${track.name} (${slug})\n`);

	const trackIdx = track.index || 0;
	if (!Number.isInteger(track._assigned_horizon_override)) {
		track._assigned_horizon_override = Number.isInteger(track.horizon_override) ? track.horizon_override : 0;
	}
	const perTrackSeed = ((masterSeed >>> 0) ^ ((trackIdx * 0x6B5B9C11) >>> 0)) >>> 0;

  const rngCurves  = new XorShift32(deriveSubseed(perTrackSeed, MOD_TRACK_CURVES));
  const rngSlopes  = new XorShift32(deriveSubseed(perTrackSeed, MOD_TRACK_SLOPES));
  const rngSigns   = new XorShift32(deriveSubseed(perTrackSeed, MOD_TRACK_SIGNS));
  const rngMinimap = new XorShift32(deriveSubseed(perTrackSeed, MOD_TRACK_MINIMAP));

  // Step 1: track length
  const newLength = originalLength;
  track.track_length = newLength;
  if (verbose) process.stdout.write(`    track_length = ${newLength} (fixed original budget)\n`);

	// Step 2: curves
	const curveSegs = generateCurveRle(rngCurves, newLength, track);
	const normalizedCurveSegs = normalizeCurveBgDisplacement(curveSegs, { protectStartupCurve: true, trackLength: newLength });
	track.curve_rle_segments   = normalizedCurveSegs;
	track.curve_decompressed   = decompressCurveSegments(normalizedCurveSegs);
	if (verbose) {
	  const nS = curveSegs.filter(s => s.type === 'straight').length;
	  const nC = curveSegs.filter(s => s.type === 'curve').length;
	  process.stdout.write(`    curve: ${nS} straight + ${nC} curve segments\n`);
	}

	// Step 3: slopes
	const [initBgDisp, slopeSegs] = generateSlopeRle(rngSlopes, newLength, normalizedCurveSegs);
	const physSegs = generatePhysSlopeRle(rngSlopes, newLength, slopeSegs);

	track.curve_rle_segments      = normalizedCurveSegs;
	track.curve_decompressed      = decompressCurveSegments(normalizedCurveSegs);
	track.slope_initial_bg_disp   = initBgDisp;
	track.slope_rle_segments      = slopeSegs;
	track.phys_slope_rle_segments = physSegs;

	const slopeDecomp = [];
	for (const seg of slopeSegs) {
    if (seg.type === 'flat' || seg.type === 'slope') {
      for (let i = 0; i < seg.length; i++) slopeDecomp.push(seg.slope_byte);
    } else if (seg.type === 'terminator') {
      slopeDecomp.push(0xFF);
    }
  }
  track.slope_decompressed = slopeDecomp;

  const physDecomp = [];
  for (const seg of physSegs) {
    if (seg.type === 'segment') {
      for (let i = 0; i < seg.length; i++) physDecomp.push(seg.phys_byte);
    }
  }
	track.phys_slope_decompressed = physDecomp;

	if (verbose) {
		const nF  = slopeSegs.filter(s => s.type === 'flat').length;
		const nSl = slopeSegs.filter(s => s.type === 'slope').length;
		process.stdout.write(`    slope: ${nF} flat + ${nSl} slope segments\n`);
	}

  // Step 4: signs
	const specialRoadFeatures = buildSpecialRoadFeatures(rngSigns, newLength, normalizedCurveSegs);
	const [baseTilesetRecords, tilesetTrailing] = generateSignTileset(rngSigns, newLength, normalizedCurveSegs, track);
	const tilesetRecords = enforceWrapSafeTilesetRecords(newLength, applySpecialRoadTilesetRecords(baseTilesetRecords, specialRoadFeatures));
	const baseSignRecords = generateSignData(rngSigns, newLength, normalizedCurveSegs, tilesetRecords);
	const signRecords = applySpecialRoadSignRecords(baseSignRecords, specialRoadFeatures);
	track.sign_data             = signRecords;
	track.sign_tileset          = tilesetRecords;
	track.sign_tileset_trailing = tilesetTrailing;
	track._generated_special_road_features = specialRoadFeatures;
	if (verbose) process.stdout.write(`    signs: ${signRecords.length} records, ${tilesetRecords.length} tileset entries\n`);

	// Step 5: minimap
	const [minimapPairs, minimapTrailing] = generateMinimap(track);
	track.minimap_pos          = minimapPairs;
	track.minimap_pos_trailing = minimapTrailing;
	if (verbose) {
		const previewInfo = track._generated_minimap_preview || {};
		process.stdout.write(
			`    minimap: ${minimapPairs.length} pairs (need ${newLength >> 6}), ` +
			`canon ${previewInfo.match_percent || 0}% / preview ${previewInfo.preview_match_percent || 0}% / thick ${previewInfo.thickness_aware_match_percent || 0}%\n`
		);
	}

  return track;
}

// ---------------------------------------------------------------------------
// Public entry point: randomize all tracks
// ---------------------------------------------------------------------------

function randomizeTracks(tracksData, masterSeed, trackSlugs = null, verbose = false) {
  const tracks = tracksData.tracks;
	const artAssignment = randomizeArtConfig(masterSeed, false);
	for (let slotIdx = 0; slotIdx < CHAMPIONSHIP_TRACK_NAMES.length && slotIdx < tracks.length; slotIdx++) {
		const track = tracks[slotIdx];
		if (!track) continue;
		track._assigned_art_name = artAssignment[slotIdx]?.art_name || track.name;
		track._assigned_horizon_override = Number.isInteger(artAssignment[slotIdx]?.horizon_override)
			? artAssignment[slotIdx].horizon_override
			: (Number.isInteger(track.horizon_override) ? track.horizon_override : 0);
	}
  for (const track of tracks) {
    if (trackSlugs !== null && !trackSlugs.has(track.slug)) continue;
    randomizeOneTrack(track, masterSeed, verbose);
  }

	const monacoArcadeMain = tracks.find(track => track.index === 17);
	const monacoArcadeWet = tracks.find(track => track.index === 18);
	if (monacoArcadeMain && monacoArcadeWet) {
		const sharedFields = [
			'track_length',
			'curve_rle_segments',
			'curve_decompressed',
			'slope_initial_bg_disp',
			'slope_rle_segments',
			'slope_decompressed',
			'phys_slope_rle_segments',
			'phys_slope_decompressed',
			'sign_data',
			'sign_tileset',
			'sign_tileset_trailing',
			'minimap_pos',
			'minimap_pos_trailing',
			'_generated_minimap_preview',
			'_preserve_original_sign_cadence',
		];
		for (const field of sharedFields) {
			const value = monacoArcadeMain[field];
			monacoArcadeWet[field] = (value && typeof value === 'object')
				? JSON.parse(JSON.stringify(value))
				: value;
		}
		if (verbose) {
			process.stdout.write('  Synced Monaco (Arcade Wet) shared track data to Monaco (Arcade Main)\n');
		}
	}

  return tracksData;
}

// ---------------------------------------------------------------------------
// Seed parsing
// ---------------------------------------------------------------------------

const SEED_RE = /^SMGP-(\d+)-([0-9A-Fa-f]+)-(\d+)$/;

function parseSeed(seedStr) {
  const m = SEED_RE.exec(seedStr.trim());
  if (!m) {
    throw new Error(
      `Invalid seed format: ${JSON.stringify(seedStr)}  (expected SMGP-<v>-<flags_hex>-<decimal>)`
    );
  }
  const version = parseInt(m[1], 10);
  const flags   = parseInt(m[2], 16);
  const seed    = parseInt(m[3], 10);
  return [version, flags, seed];
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

if (require.main === module) {
  const { parseArgs, die, info } = require('../lib/cli');
  const { readJson, writeJson } = require('../lib/json');
  const { REPO_ROOT } = require('../lib/rom');
  const trackValidator = require('./track_validator');

  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--dry-run', '--no-validate', '--verbose', '-v'],
    options: ['--seed', '--tracks', '--input', '--output'],
  });

  const seedStr   = args.options['--seed'] || 'SMGP-1-01-12345';
  const inputRel  = args.options['--input'] || 'tools/data/tracks.json';
  const outputRel = args.options['--output'];
  const verbose   = args.flags['--verbose'] || args.flags['-v'];
  const dryRun    = args.flags['--dry-run'];
  const doValidate = !args.flags['--no-validate'];

  let version, flags, seedInt;
  try {
    [version, flags, seedInt] = parseSeed(seedStr);
  } catch (e) {
    die(e.message);
  }

  if (!(flags & FLAG_TRACKS)) {
    info('Seed has RAND_TRACKS flag (0x01) clear — no tracks to randomize.');
    process.exit(0);
  }

  info(`Seed: ${seedStr}  (version=${version} flags=0x${flags.toString(16).toUpperCase().padStart(2,'0')} seed=${seedInt})`);

  const inputPath  = path.resolve(REPO_ROOT, inputRel);
  const outputPath = outputRel ? path.resolve(REPO_ROOT, outputRel) : inputPath;

  if (!fs.existsSync(inputPath)) die(`input JSON not found: ${inputPath}`);
  const tracksData = readJson(inputPath);

  const slugSet = args.options['--tracks']
    ? new Set(args.options['--tracks'].split(',').map(s => s.trim()))
    : null;

  info('Randomizing tracks ...');
  randomizeTracks(tracksData, seedInt, slugSet, verbose);

  if (doValidate) {
    const errors = trackValidator.validateTracks(tracksData.tracks);
    if (errors.length > 0) {
      process.stderr.write(`\nValidation FAILED: ${errors.length} error(s):\n`);
      for (const e of errors) process.stderr.write(`  [${e.trackName}] ${e.field}: ${e.message}\n`);
      process.exit(1);
    }
    info('Validation passed.');
  }

  const randomized = tracksData.tracks.filter(t => slugSet === null || slugSet.has(t.slug));
  info(`Randomized ${randomized.length} track(s).`);

  if (dryRun) {
    info('DRY RUN — not writing output.');
  } else {
    writeJson(outputPath, tracksData);
    info(`Written: ${outputPath}`);
    info('Run node tools/inject_track_data.js then verify.bat to build.');
  }
}

module.exports = {
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
  getCurveOpeningStraightSteps, getCurveClosingStraightSteps, getFirstCurveSegment, curveHasSafeRaceStart,
	decodeCurveBgDisplacement, curveBgLoopAligns,
	getCurveRuntimeSeamMetrics,
	decodeVisualSlopeBgDisplacement, visualSlopeOffsetsWithinSafeEnvelope,
	getVisualSlopeOpeningFlatSteps, getVisualSlopeClosingFlatSteps, visualSlopeHasSafeRaceStart, visualSlopeLoopAligns,
	generateSignData, generateSignTileset,
  generateMinimap,
  randomizeArtConfig, buildTrackConfigAsm, injectArtConfig,
  pickTrackLength, randomizeOneTrack, randomizeTracks,
	buildCurveGenerationProfile,
	buildCurveTargets,
	expandCurveComplexity,
	buildSpecialRoadFeatures,
	applySpecialRoadTilesetRecords,
	applySpecialRoadSignRecords,
  _shuffleList,
};
