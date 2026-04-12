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
const {
	XorShift32,
	MOD_TRACK_CURVES,
	MOD_TRACK_SLOPES,
	MOD_TRACK_SIGNS,
	MOD_TRACK_MINIMAP,
	MOD_TRACK_CONFIG,
	MOD_TEAMS,
	MOD_AI,
	MOD_CHAMPIONSHIP,
	deriveSubseed,
	FLAG_TRACKS,
	FLAG_TRACK_CONFIG,
	FLAG_TEAMS,
	FLAG_AI,
	FLAG_CHAMPIONSHIP,
	FLAG_SIGNS,
	FLAG_ALL,
	parseSeed,
} = require('./randomizer_shared');
const {
	CHAMPIONSHIP_ART_SETS,
	CHAMPIONSHIP_TRACK_NAMES,
	_shuffleList,
	randomizeArtConfig,
	buildTrackConfigAsm,
	injectArtConfig,
} = require('./art_config');
const { makeTrackPipeline, pickTrackLength } = require('./track_pipeline');
const {
	cyclicTrackDistance,
	getActiveTilesetOffset,
	getActiveTilesetRecord,
	getSignRuntimeRowSpan,
	pickSignIdForTileset,
	SIGN_ID_POOL,
	SIGN_TILESET_OFFSETS,
	STANDARD_SIGN_TILESET_OFFSETS,
	HORIZON_SIGN_TILESET_OFFSETS,
	SIGN_TILESET_MIN_SPACING,
	SAFE_SIGN_TILESET_GUARD_DISTANCE,
	LEFT_SIGN_IDS,
	RIGHT_SIGN_IDS,
	SPECIAL_SIGN_IDS,
	TILESET_SIGN_ID_MAP,
	TUNNEL_TILESET_OFFSET,
	TUNNEL_ENTRY_SIGN_ID,
	TUNNEL_INTERIOR_SIGN_ID,
	TUNNEL_EXIT_SIGN_ID,
} = require('./sign_utils');
const {
	buildGeneratedPreviewSummary,
} = require('../lib/minimap_result_model');
const {
	getAssignedHorizonOverride,
	setGeneratedMinimapPreview,
} = require('./track_metadata');

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

const SIGN_COUNT_VALUES = [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 24];

const SAFE_SIGN_COUNT_VALUES = [1, 2, 3, 4];
const SAFE_SIGN_SPACING_MIN = 160;
const SAFE_SIGN_SPACING_MAX = 420;

const SIGN_SPACING_MIN  = 100;
const SIGN_SPACING_MAX  = 500;
const SIGN_FINISH_ZONE  = 120;

const CHICANE_MIN_STRAIGHT = 112;
const SHARP_COMPLEX_MIN_STRAIGHT = 128;
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
	const minBgDisp = BG_DISP_MIN;
	let maxBgDisp = BG_DISP_MAX;
	if (options.startupCurve === true) {
		maxBgDisp = Math.min(maxBgDisp, Math.max(BG_DISP_MIN, clampedLength * CURVE_SAFE_FIRST_CURVE_MAX_RATE));
	}
	const minRate = minBgDisp / clampedLength;
	const maxRate = maxBgDisp / clampedLength;
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
	let base = Math.round(35 + (1.6 * clampedLength) + (3.5 * clampedSharpness) - (0.027 * clampedLength * clampedSharpness));
	base += rng.randInt(-18, 18);
	if (base <= 42) return bounds.minBgDisp;
	if (base >= 286) return bounds.maxBgDisp;
	return clamp(base, bounds.minBgDisp, bounds.maxBgDisp);
}

function buildCurveBgContext(curveSegments) {
	const body = buildCurveBodySegments(curveSegments);
	const curveEntries = [];
	let step = 0;
	let previousCurve = null;
	for (let index = 0; index < body.length; index++) {
		const seg = body[index];
		if (seg.type === 'curve') {
			const entry = {
				index,
				seg,
				length: seg.length,
				sharpness: getCurveSharpness(seg.curve_byte),
				direction: getCurveDirection(seg.curve_byte),
				startStep: step,
				endStep: step + seg.length,
				prev: previousCurve,
				prevGap: previousCurve ? Math.max(0, step - previousCurve.endStep) : Infinity,
				next: null,
				nextGap: Infinity,
			};
			if (previousCurve) {
				previousCurve.next = entry;
				previousCurve.nextGap = entry.startStep - previousCurve.endStep;
			}
			curveEntries.push(entry);
			previousCurve = entry;
		}
		step += seg.length;
	}
	return curveEntries;
}

function estimateStockLikeCurveBgDisp(entry, options = {}) {
	const length = Math.max(4, entry?.length | 0);
	const sharpness = clamp(entry?.sharpness || SHARPNESS_MIN, SHARPNESS_MIN, SHARPNESS_MAX);
	const startupCurve = options.startupCurve === true;
	const bounds = computeCurveBgDispBounds(length, sharpness, { startupCurve });
	let base = 35 + (1.6 * length) + (3.5 * sharpness) - (0.027 * length * sharpness);
	const prev = entry?.prev || null;
	const next = entry?.next || null;
	const prevGap = Number.isFinite(entry?.prevGap) ? entry.prevGap : Infinity;
	const nextGap = Number.isFinite(entry?.nextGap) ? entry.nextGap : Infinity;
	const prevOpposite = !!prev && prev.direction !== entry.direction && prevGap <= 24;
	const nextOpposite = !!next && next.direction !== entry.direction && nextGap <= 24;
	const prevSame = !!prev && prev.direction === entry.direction && prevGap <= 12;
	const nextSame = !!next && next.direction === entry.direction && nextGap <= 12;

	if (!prev) base += 12;
	if (prevOpposite) base += 16;
	if (nextOpposite) base += 16;
	if (prevSame) base -= prevGap <= 8 ? 45 : 30;
	if (nextSame) base -= nextGap <= 8 ? 22 : 12;

	let bgDisp = clamp(Math.round(base), bounds.minBgDisp, bounds.maxBgDisp);
	if (prevSame && prevGap <= 8) {
		bgDisp = bounds.minBgDisp;
	} else if (bgDisp <= 42) {
		bgDisp = bounds.minBgDisp;
	} else if ((prevOpposite || nextOpposite) && bgDisp >= 250) {
		bgDisp = bounds.maxBgDisp;
	} else if (bgDisp >= 286) {
		bgDisp = bounds.maxBgDisp;
	}
	return bgDisp;
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
	return [];
}

function isNearTilesetTransition(trackLength, tilesetRecords, distance, guardDistance = SAFE_SIGN_TILESET_GUARD_DISTANCE) {
	if (!Array.isArray(tilesetRecords) || tilesetRecords.length === 0) return false;
	return tilesetRecords.some(record => cyclicTrackDistance(record.distance, distance, trackLength) < guardDistance);
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
	const openingRecord = working[0] && working[0].distance === 0 ? { ...working[0] } : null;
	while (working.length > 1 && getWrapTilesetGap(trackLength, working) < SIGN_TILESET_MIN_SPACING) {
		if (working.length <= 2) {
			if (openingRecord) working[0].tileset_offset = openingRecord.tileset_offset;
			else working[0].tileset_offset = working[working.length - 1].tileset_offset;
			working.splice(1);
			break;
		}
		if (openingRecord && working[0].distance === 0) working.pop();
		else if (working[working.length - 1].distance >= (trackLength >> 1)) working.pop();
		else working.shift();
	}
	if (openingRecord && (working.length === 0 || working[0].distance !== 0)) {
		working.unshift(openingRecord);
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
		working = working.filter(record => transitionDistances.every(distance => {
			const trackLength = feature.trackLength || 0;
			return cyclicTrackDistance(record.distance, distance, trackLength) >= SAFE_SIGN_TILESET_GUARD_DISTANCE;
		}));
		for (const record of [
			{ distance: feature.entrySignDistance, count: 1, sign_id: TUNNEL_ENTRY_SIGN_ID },
			{ distance: feature.interiorDistance, count: 4, sign_id: TUNNEL_INTERIOR_SIGN_ID },
			{ distance: feature.exitSignDistance, count: 1, sign_id: TUNNEL_EXIT_SIGN_ID },
		]) {
			const trackLength = feature.trackLength || 0;
			if (transitionDistances.some(distance => cyclicTrackDistance(distance, record.distance, trackLength) < SAFE_SIGN_TILESET_GUARD_DISTANCE)) continue;
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
	const decoded = decodeCurveBgDisplacement(body);
	if (decoded.length === 0) return true;
	return computeNetBgDisp(body) === 0
		&& decoded[0] === decoded[decoded.length - 1];
}

function normalizeCurveBgDisplacement(curveSegments, options = {}) {
	const adjusted = cloneSegments(curveSegments);
	const protectStartupCurve = options.protectStartupCurve === true;
	const protectedCurve = protectStartupCurve ? getFirstCurveSegment(adjusted) : null;
	const context = buildCurveBgContext(adjusted);
	for (const entry of context) {
		const seg = entry.seg;
		const startupCurve = protectedCurve && seg === protectedCurve;
		seg.bg_disp = estimateStockLikeCurveBgDisp(entry, { startupCurve });
	}
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
	const track = arguments.length > 4 ? arguments[4] : null;
	const stockOpeningOffset = Number.isInteger(track?.sign_tileset?.[0]?.tileset_offset)
		&& allowedOffsets.includes(track.sign_tileset[0].tileset_offset)
		? track.sign_tileset[0].tileset_offset
		: null;

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
	records.push({ distance: 0, tileset_offset: stockOpeningOffset !== null ? stockOpeningOffset : pickOffset(openingDirection) });
	if (stockOpeningOffset !== null) lastOffset = stockOpeningOffset;
	lastDistance = 0;

	for (const window of strongWindows) {
		if (records.length >= 2) break;
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
		if (records.length >= 2) break;
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

	if (records.length < 2 && (trackLength - lastDistance) > 1700) {
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
	const transitionDistances = Array.isArray(tilesetRecords) ? tilesetRecords.map(record => record.distance) : [];

	function tryAddSign(distance, direction, sharpness, preferredCount) {
		const clampedDistance = clamp(Math.round(distance), 0, finishCutoff - 1);
		if (clampedDistance <= lastDistance) return;
		if ((clampedDistance - lastDistance) < SAFE_SIGN_SPACING_MIN) return;
		const count = clamp(preferredCount, 1, 4);
		const activeTileset = getActiveTilesetRecord(tilesetRecords, clampedDistance);
		const tilesetOffset = activeTileset ? activeTileset.tileset_offset : 8;
		const signId = pickSignIdForTileset(rng, tilesetOffset, direction);
		const runtimeSpanSlots = getSignRuntimeRowSpan(signId, count);
		const rowEndDistance = Math.min(finishCutoff - 1, clampedDistance + ((runtimeSpanSlots - 1) * 0x10));
		const transitionUnsafe = transitionDistances.some(transitionDistance => {
			return cyclicTrackDistance(transitionDistance, clampedDistance, trackLength) < (SAFE_SIGN_TILESET_GUARD_DISTANCE * 2)
				|| cyclicTrackDistance(transitionDistance, rowEndDistance, trackLength) < (SAFE_SIGN_TILESET_GUARD_DISTANCE * 2);
		});
		if (transitionUnsafe) return;
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
	return buildFlatSlopeRle(trackLength);
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


function generateSignData(rng, trackLength, curveSegments, tilesetRecords) {
  return buildCurveDrivenSignPlan(rng, trackLength, curveSegments, tilesetRecords);
}

function getAllowedSignTilesetOffsets(track) {
	const horizonOverride = getAssignedHorizonOverride(track);
	return horizonOverride ? HORIZON_SIGN_TILESET_OFFSETS : STANDARD_SIGN_TILESET_OFFSETS;
}

function generateSignTileset(rng, trackLength, curveSegments = [], track = null) {
	return [buildCurveAwareTilesetPlan(rng, trackLength, curveSegments, getAllowedSignTilesetOffsets(track), track), []];
}

// ---------------------------------------------------------------------------
// RAND-005: Minimap generation
// ---------------------------------------------------------------------------

function generateMinimap(track) {
	const { buildGeneratedMinimapPosPairs } = require('../lib/generated_minimap_pos');
	const preview = require('../lib/minimap_render').buildGeneratedMinimapPreview(track);
	const pairs = buildGeneratedMinimapPosPairs(track);
	const previewSummary = buildGeneratedPreviewSummary(preview);
	previewSummary.sample_count = pairs.length;
	setGeneratedMinimapPreview(track, previewSummary);
	return [pairs, track.minimap_pos_trailing || []];
}

function evaluateGeneratedPreviewConstraints(track) {
	const { buildGeneratedMinimapPreview } = require('../lib/minimap_render');
	const preview = buildGeneratedMinimapPreview(track);
	const startVerticality = preview.start_verticality || 0;
	const tileCount = preview.tile_count || 0;
	return {
		preview,
		selfIntersections: preview.self_intersections || 0,
		startVerticality,
		tileCount,
		signMatchPercent: preview.curve_sign_match_percent || 0,
		passes: (preview.self_intersections || 0) <= 1
			&& startVerticality >= 0.68
			&& tileCount <= 48
			&& (preview.curve_sign_match_percent || 0) >= 60,
	};
}

function compareGeneratedPreviewConstraints(a, b) {
	if (a.passes !== b.passes) return a.passes ? -1 : 1;
	if (a.selfIntersections !== b.selfIntersections) return a.selfIntersections - b.selfIntersections;
	if (a.tileCount !== b.tileCount) return a.tileCount - b.tileCount;
	if (a.signMatchPercent !== b.signMatchPercent) return b.signMatchPercent - a.signMatchPercent;
	if (a.startVerticality !== b.startVerticality) return b.startVerticality - a.startVerticality;
	return 0;
}

const trackPipeline = makeTrackPipeline({
	generateCurveRle,
	normalizeCurveBgDisplacement,
	decompressCurveSegments,
	generateSlopeRle,
	generatePhysSlopeRle,
	buildSpecialRoadFeatures,
	generateSignTileset,
	enforceWrapSafeTilesetRecords,
	applySpecialRoadTilesetRecords,
	generateSignData,
	applySpecialRoadSignRecords,
	generateMinimap,
	evaluateGeneratedPreviewConstraints,
	compareGeneratedPreviewConstraints,
});

const randomizeOneTrack = trackPipeline.randomizeOneTrack;
const randomizeTracks = trackPipeline.randomizeTracks;

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
