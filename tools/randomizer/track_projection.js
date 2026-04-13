'use strict';

const {
	clonePointPath,
	resampleClosedPath,
	segmentLength,
} = require('./track_geometry');

const CURVE_STRAIGHT = 0x00;
const CURVE_LEFT_MIN = 0x01;
const CURVE_LEFT_MAX = 0x2F;
const CURVE_RIGHT_MIN = 0x41;
const CURVE_RIGHT_MAX = 0x6F;
const BG_VERT_DISP_SOFT = 30;
const BG_VERT_DISP_STRONG = 112;
const VISUAL_SLOPE_SAFE_OPENING_FLAT_STEPS = 128;
const VISUAL_SLOPE_SAFE_CLOSING_FLAT_STEPS = 96;
const PHYS_FLAT = 0;
const PHYS_DOWN = -1;
const PHYS_UP = 1;

function normalizeSampleIndex(index, count) {
	if (!Number.isInteger(count) || count <= 0) return 0;
	return ((index % count) + count) % count;
}

function countArcSteps(startIndex, endIndex, count) {
	if (!Number.isInteger(count) || count <= 0) return 0;
	let steps = 0;
	let cursor = normalizeSampleIndex(startIndex, count);
	const target = normalizeSampleIndex(endIndex, count);
	while (cursor !== target) {
		cursor = (cursor + 1) % count;
		steps += 1;
		if (steps > count) break;
	}
	return steps;
}

function toTrackDistance(index, trackLength, sampleCount) {
	if (!Number.isInteger(trackLength) || trackLength <= 0 || !Number.isInteger(sampleCount) || sampleCount <= 0) return 0;
	return Math.max(0, Math.min(trackLength - 1, Math.round((normalizeSampleIndex(index, sampleCount) / sampleCount) * trackLength)));
}

function buildGradeSeparatedProjectionData(trackLength, sampleCount, crossingInfo) {
	if (!crossingInfo || !crossingInfo.grade_separated || !Number.isInteger(sampleCount) || sampleCount <= 0) return null;
	const lowerBranch = crossingInfo.lower_branch || null;
	const upperBranch = crossingInfo.upper_branch || null;
	if (!lowerBranch || !upperBranch) return null;
	const lowerStart = normalizeSampleIndex(lowerBranch.start_index, sampleCount);
	const lowerEnd = normalizeSampleIndex(lowerBranch.end_index, sampleCount);
	const lowerSpan = countArcSteps(lowerStart, lowerEnd, sampleCount);
	if (lowerSpan < 24) return null;
	const rampLength = Math.max(8, Math.min(32, Math.floor(lowerSpan / 6)));
	const interiorStart = normalizeSampleIndex(lowerStart + rampLength, sampleCount);
	const interiorEnd = normalizeSampleIndex(lowerEnd - rampLength, sampleCount);
	return {
		grade_separated: true,
		crossing_point: crossingInfo.crossing_point || null,
		lower_branch: {
			start_index: lowerStart,
			end_index: lowerEnd,
			span_steps: lowerSpan,
			start_distance: toTrackDistance(lowerStart, trackLength, sampleCount),
			end_distance: toTrackDistance(lowerEnd, trackLength, sampleCount),
			interior_start_index: interiorStart,
			interior_end_index: interiorEnd,
			interior_start_distance: toTrackDistance(interiorStart, trackLength, sampleCount),
			interior_end_distance: toTrackDistance(interiorEnd, trackLength, sampleCount),
			ramp_length: rampLength,
			branch_height: -1,
			tunnel_required: true,
		},
		upper_branch: {
			start_index: normalizeSampleIndex(upperBranch.start_index, sampleCount),
			end_index: normalizeSampleIndex(upperBranch.end_index, sampleCount),
			span_steps: countArcSteps(upperBranch.start_index, upperBranch.end_index, sampleCount),
			branch_height: 0,
			tunnel_required: false,
		},
		separation_ok: true,
		classification: 'grade_separated_crossing',
	};
}

function clamp(value, min, max) {
	return Math.max(min, Math.min(max, value));
}

function normalizeAngleDelta(delta) {
	let value = delta;
	while (value <= -Math.PI) value += Math.PI * 2;
	while (value > Math.PI) value -= Math.PI * 2;
	return value;
}

function buildHeadingProfile(points) {
	const profile = [];
	for (let index = 0; index < points.length; index++) {
		const prev = points[(index - 1 + points.length) % points.length];
		const cur = points[index];
		const next = points[(index + 1) % points.length];
		const incoming = Math.atan2(cur[1] - prev[1], cur[0] - prev[0]);
		const outgoing = Math.atan2(next[1] - cur[1], next[0] - cur[0]);
		const turn = normalizeAngleDelta(outgoing - incoming);
		const segmentScale = Math.max(1e-6, (segmentLength(prev, cur) + segmentLength(cur, next)) / 2);
		profile.push({ incoming, outgoing, turn, segmentScale });
	}
	return profile;
}

function quantizeTurnToCurveByte(turn, segmentScale) {
	const scaledMagnitude = Math.abs(turn) * Math.max(1, segmentScale);
	const sharpness = clamp(Math.round(scaledMagnitude * 10), 0, 0x2F);
	if (sharpness <= 0) return CURVE_STRAIGHT;
	if (turn > 0) return clamp(sharpness, CURVE_LEFT_MIN, CURVE_LEFT_MAX);
	return clamp(0x40 | sharpness, CURVE_RIGHT_MIN, CURVE_RIGHT_MAX);
}

function estimateBgDispFromCurveByte(curveByte) {
	if (curveByte === CURVE_STRAIGHT) return 0;
	const sharpness = curveByte & 0x3F;
	return clamp(Math.round(20 + (sharpness * 6)), 20, 300);
}

function projectCenterlineToCurveBytes(centerlinePoints, sampleCount) {
	const resampled = resampleClosedPath(clonePointPath(centerlinePoints), sampleCount);
	const headingProfile = buildHeadingProfile(resampled);
	return headingProfile.map(entry => quantizeTurnToCurveByte(entry.turn, entry.segmentScale));
}

function compressCurveBytesToRle(curveBytes) {
	const segments = [];
	for (const curveByte of curveBytes || []) {
		const type = curveByte === CURVE_STRAIGHT ? 'straight' : 'curve';
		const bgDisp = type === 'curve' ? estimateBgDispFromCurveByte(curveByte) : undefined;
		const prev = segments[segments.length - 1];
		if (prev && prev.type === type && prev.curve_byte === curveByte && (type === 'straight' || prev.bg_disp === bgDisp)) {
			prev.length += 1;
			continue;
		}
		segments.push(type === 'curve'
			? { type, length: 1, curve_byte: curveByte, bg_disp: bgDisp }
			: { type, length: 1, curve_byte: curveByte });
	}
	segments.push({ type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] });
	return segments;
}

function projectCenterlineToCurveRle(centerlinePoints, trackLength) {
	const sampleCount = Math.max(1, (trackLength || 0) >> 2);
	const curveBytes = projectCenterlineToCurveBytes(centerlinePoints, sampleCount);
	return {
		curve_bytes: curveBytes,
		curve_rle_segments: compressCurveBytesToRle(curveBytes),
	};
}

function buildFlatSlopeRleFromSampleCount(sampleCount) {
	return [
		0,
		[
			{ type: 'flat', length: sampleCount, slope_byte: 0, bg_vert_disp: 0 },
			{ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
		],
	];
}

function buildVisualSlopeEvents(trackLength, centerlinePoints, options = {}) {
	const sampleCount = Math.max(1, (trackLength || 0) >> 2);
	const crossingProjection = buildGradeSeparatedProjectionData(trackLength, sampleCount, options.crossingInfo || null);
	if (crossingProjection) {
		const lower = crossingProjection.lower_branch;
		return [
			{
				startStep: lower.start_index,
				length: lower.ramp_length,
				direction: -1,
				sharpness: 12,
				bgVertDisp: BG_VERT_DISP_SOFT,
			},
			{
				startStep: lower.end_index - lower.ramp_length,
				length: lower.ramp_length,
				direction: 1,
				sharpness: 12,
				bgVertDisp: BG_VERT_DISP_SOFT,
			},
		];
	}
	return [];
}

function buildSlopeRleFromEvents(trackLength, events) {
	const targetSteps = Math.max(1, (trackLength || 0) >> 2);
	if (!Array.isArray(events) || events.length === 0) return buildFlatSlopeRleFromSampleCount(targetSteps);
	const segments = [];
	let cursor = 0;
	for (const event of events.slice().sort((a, b) => a.startStep - b.startStep)) {
		if (event.startStep > cursor) {
			segments.push({ type: 'flat', length: event.startStep - cursor, slope_byte: 0, bg_vert_disp: 0 });
		}
		segments.push({
			type: 'slope',
			length: event.length,
			slope_byte: event.direction < 0 ? clamp(event.sharpness, CURVE_LEFT_MIN, CURVE_LEFT_MAX) : clamp(0x40 | event.sharpness, CURVE_RIGHT_MIN, CURVE_RIGHT_MAX),
			bg_vert_disp: event.bgVertDisp,
		});
		cursor = event.startStep + event.length;
	}
	if (cursor < targetSteps) {
		segments.push({ type: 'flat', length: targetSteps - cursor, slope_byte: 0, bg_vert_disp: 0 });
	}
	segments.push({ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] });
	return [0, segments];
}

function buildPhysicalSlopeRleFromVisual(slopeSegments, trackLength) {
	const targetSteps = Math.max(1, (trackLength || 0) >> 2);
	const physSegments = [];
	for (const seg of slopeSegments || []) {
		if (seg.type === 'terminator') break;
		if (seg.type === 'flat') {
			physSegments.push({ type: 'segment', length: seg.length, phys_byte: PHYS_FLAT });
			continue;
		}
		const shoulder = Math.min(8, Math.floor(seg.length / 4));
		const core = seg.length - (shoulder * 2);
		if (shoulder > 0) physSegments.push({ type: 'segment', length: shoulder, phys_byte: PHYS_FLAT });
		physSegments.push({ type: 'segment', length: core, phys_byte: (seg.slope_byte & 0x40) ? PHYS_UP : PHYS_DOWN });
		if (shoulder > 0) physSegments.push({ type: 'segment', length: shoulder, phys_byte: PHYS_FLAT });
	}
	const merged = [];
	for (const seg of physSegments) {
		const prev = merged[merged.length - 1];
		if (prev && prev.phys_byte === seg.phys_byte) {
			prev.length += seg.length;
		} else {
			merged.push({ ...seg });
		}
	}
	const total = merged.reduce((sum, seg) => sum + seg.length, 0);
	if (total < targetSteps) merged.push({ type: 'segment', length: targetSteps - total, phys_byte: PHYS_FLAT });
	merged.push({ type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] });
	return merged;
}

function projectCenterlineToSlopeRle(centerlinePoints, trackLength, options = {}) {
	const sampleCount = Math.max(1, (trackLength || 0) >> 2);
	const crossingProjection = buildGradeSeparatedProjectionData(trackLength, sampleCount, options.crossingInfo || null);
	const events = buildVisualSlopeEvents(trackLength, centerlinePoints, options);
	const [initialBgDisp, slope_rle_segments] = buildSlopeRleFromEvents(trackLength, events);
	return {
		slope_initial_bg_disp: initialBgDisp,
		slope_rle_segments,
		phys_slope_rle_segments: buildPhysicalSlopeRleFromVisual(slope_rle_segments, trackLength),
		grade_separated_crossing: crossingProjection,
	};
}

module.exports = {
	CURVE_STRAIGHT,
	CURVE_LEFT_MIN,
	CURVE_LEFT_MAX,
	CURVE_RIGHT_MIN,
	CURVE_RIGHT_MAX,
	normalizeAngleDelta,
	buildHeadingProfile,
	quantizeTurnToCurveByte,
	estimateBgDispFromCurveByte,
	projectCenterlineToCurveBytes,
	compressCurveBytesToRle,
	projectCenterlineToCurveRle,
	buildFlatSlopeRleFromSampleCount,
	buildVisualSlopeEvents,
	buildSlopeRleFromEvents,
	buildPhysicalSlopeRleFromVisual,
	buildGradeSeparatedProjectionData,
	projectCenterlineToSlopeRle,
};
