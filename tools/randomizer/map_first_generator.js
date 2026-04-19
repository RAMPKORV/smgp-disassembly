'use strict';

const { buildMapFirstCanvas } = require('../lib/minimap_layout');
const { setGeneratedGeometryState } = require('./track_metadata');
const { XorShift32, deriveSubseed, MOD_TRACK_MINIMAP } = require('./randomizer_shared');
const {
	clonePointPath,
	countProperSelfIntersections,
	getSignedArea,
	isClosedLoop,
	listSelfIntersections,
	resampleClosedPath,
	segmentLength,
	smoothClosedPath,
} = require('./track_geometry');

const DEFAULT_POINT_SAMPLING_OPTIONS = Object.freeze({
	densityDivisor: 320,
	minPointCount: 8,
	maxPointCount: 24,
	edgeMarginPx: 4,
	minimumSpacingPx: 8,
	spacingDecay: 0.85,
	maxPlacementAttemptsMultiplier: 24,
	maxSpacingRelaxationPasses: 4,
});

const CYCLE_BUILD_STRATEGIES = Object.freeze([
	'nearest_neighbor_2opt',
	'farthest_neighbor_2opt',
	'input_order_2opt',
	'centroid_distance_desc_2opt',
	'lexicographic_2opt',
	'centroid_distance_desc_hull',
	'centroid_angle_hull',
	'lexicographic_hull',
]);

const DEFAULT_SMOOTHING_OPTIONS = Object.freeze({
	passes: 0,
	maxStartAngleDeltaDegrees: 60,
	preserveStartPoint: true,
	clampToCanvas: true,
});

const DEFAULT_RESAMPLING_OPTIONS = Object.freeze({
	minimumSampleCount: 16,
	maximumSampleCount: 2048,
	preserveStartPoint: true,
	clampToCanvas: true,
	maxStartAngleDeltaDegrees: 35,
});

const CROSSING_SELECTION_ODDS = 16;

function clamp(value, min, max) {
	return Math.max(min, Math.min(max, value));
}

function roundPoint(point) {
	return [Number(point[0].toFixed(3)), Number(point[1].toFixed(3))];
}

function distanceSquared(a, b) {
	const dx = a[0] - b[0];
	const dy = a[1] - b[1];
	return (dx * dx) + (dy * dy);
}

function normalizeVector(vector) {
	const length = Math.hypot(vector[0], vector[1]);
	if (length <= 1e-9) return null;
	return [vector[0] / length, vector[1] / length];
}

function vectorAngleDegrees(a, b) {
	const normalizedA = normalizeVector(a);
	const normalizedB = normalizeVector(b);
	if (!normalizedA || !normalizedB) return Infinity;
	const dot = clamp((normalizedA[0] * normalizedB[0]) + (normalizedA[1] * normalizedB[1]), -1, 1);
	return (Math.acos(dot) * 180) / Math.PI;
}

function translatePoints(points, dx, dy) {
	return (points || []).map(point => [point[0] + dx, point[1] + dy]);
}

function reanchorLoopToStartPoint(points, anchorPoint) {
	if (!Array.isArray(points) || points.length === 0 || !Array.isArray(anchorPoint)) return clonePointPath(points);
	const dx = anchorPoint[0] - points[0][0];
	const dy = anchorPoint[1] - points[0][1];
	return translatePoints(points, dx, dy).map(roundPoint);
}

function pathFitsCanvas(points, canvas, epsilon = 1e-6) {
	if (!Array.isArray(points) || !points.length || !canvas) return false;
	return points.every(([x, y]) => x >= (canvas.x_min - epsilon)
		&& x <= (canvas.x_max + epsilon)
		&& y >= (canvas.y_min - epsilon)
		&& y <= (canvas.y_max + epsilon));
}

function computeSeamOrientation(points) {
	if (!Array.isArray(points) || points.length < 3) return null;
	const normalized = clonePointPath(points);
	const first = normalized[0];
	const prev = normalized[normalized.length - 1];
	const next = normalized[1];
	return {
		incoming: [first[0] - prev[0], first[1] - prev[1]],
		outgoing: [next[0] - first[0], next[1] - first[1]],
	};
}

function resolveSmoothingConfig(options = {}) {
	const requestedPasses = Number.isInteger(options.passes) ? options.passes : DEFAULT_SMOOTHING_OPTIONS.passes;
	return {
		passes: Math.max(0, requestedPasses),
		maxStartAngleDeltaDegrees: Number.isFinite(options.maxStartAngleDeltaDegrees)
			? Math.max(0, options.maxStartAngleDeltaDegrees)
			: DEFAULT_SMOOTHING_OPTIONS.maxStartAngleDeltaDegrees,
		preserveStartPoint: options.preserveStartPoint !== false,
		clampToCanvas: options.clampToCanvas !== false,
		allowedProperCrossings: Number.isInteger(options.allowedProperCrossings)
			? Math.max(0, options.allowedProperCrossings)
			: 0,
	};
}

function resolveResamplingConfig(track, options = {}) {
	const preferredCount = Number.isInteger(options.sampleCount)
		? options.sampleCount
		: Math.max(1, (track?.track_length || 0) >> 2);
	return {
		sampleCount: clamp(preferredCount, options.minimumSampleCount || DEFAULT_RESAMPLING_OPTIONS.minimumSampleCount, options.maximumSampleCount || DEFAULT_RESAMPLING_OPTIONS.maximumSampleCount),
		preserveStartPoint: options.preserveStartPoint !== false,
		clampToCanvas: options.clampToCanvas !== false,
		allowedProperCrossings: Number.isInteger(options.allowedProperCrossings)
			? Math.max(0, options.allowedProperCrossings)
			: 0,
		maxStartAngleDeltaDegrees: Number.isFinite(options.maxStartAngleDeltaDegrees)
			? Math.max(0, options.maxStartAngleDeltaDegrees)
			: DEFAULT_RESAMPLING_OPTIONS.maxStartAngleDeltaDegrees,
	};
}

function countArcLength(startIndex, endIndex, count) {
	if (!Number.isInteger(count) || count <= 0) return 0;
	let length = 0;
	let cursor = ((startIndex % count) + count) % count;
	const target = ((endIndex % count) + count) % count;
	while (cursor !== target) {
		cursor = (cursor + 1) % count;
		length += 1;
		if (length > count) break;
	}
	return length;
}

function indexFallsOnArc(index, startIndex, endIndex, count) {
	if (!Number.isInteger(count) || count <= 0) return false;
	const normalized = ((index % count) + count) % count;
	let cursor = ((startIndex % count) + count) % count;
	const target = ((endIndex % count) + count) % count;
	for (let guard = 0; guard <= count; guard++) {
		if (cursor === normalized) return true;
		if (cursor === target) break;
		cursor = (cursor + 1) % count;
	}
	return false;
}

function buildGradeSeparatedCrossingMetadata(points, crossings) {
	const properCrossings = (crossings || []).filter(crossing => crossing && crossing.proper);
	if (properCrossings.length !== 1 || !Array.isArray(points) || points.length < 4) return null;
	const crossing = properCrossings[0];
	const count = points.length;
	const branchAStart = (crossing.segmentA + 1) % count;
	const branchAEnd = crossing.segmentB % count;
	const branchBStart = (crossing.segmentB + 1) % count;
	const branchBEnd = crossing.segmentA % count;
	const branchALength = countArcLength(branchAStart, branchAEnd, count);
	const branchBLength = countArcLength(branchBStart, branchBEnd, count);
	const lowerBranch = branchALength <= branchBLength
		? { start_index: branchAStart, end_index: branchAEnd, point_count: branchALength + 1 }
		: { start_index: branchBStart, end_index: branchBEnd, point_count: branchBLength + 1 };
	const upperBranch = branchALength <= branchBLength
		? { start_index: branchBStart, end_index: branchBEnd, point_count: branchBLength + 1 }
		: { start_index: branchAStart, end_index: branchAEnd, point_count: branchALength + 1 };
	const lowerCrossingSegment = indexFallsOnArc(crossing.segmentA, lowerBranch.start_index, lowerBranch.end_index, count)
		? crossing.segmentA
		: crossing.segmentB;
	const upperCrossingSegment = lowerCrossingSegment === crossing.segmentA ? crossing.segmentB : crossing.segmentA;
	return {
		grade_separated: true,
		crossing_point: crossing.point ? [Number(crossing.point[0].toFixed(3)), Number(crossing.point[1].toFixed(3))] : null,
		segment_a: crossing.segmentA,
		segment_b: crossing.segmentB,
		lower_branch: lowerBranch,
		upper_branch: upperBranch,
		lower_crossing_segment: lowerCrossingSegment,
		upper_crossing_segment: upperCrossingSegment,
	};
}

function summarizeLoopTopology(points, options = {}) {
	const allowedProperCrossings = Number.isInteger(options.allowedProperCrossings)
		? Math.max(0, options.allowedProperCrossings)
		: 0;
	const crossings = Array.isArray(points) && points.length
		? listSelfIntersections(points, { includeEndpointTouches: false })
		: [];
	const properCrossings = crossings.filter(crossing => crossing.proper);
	const singleGradeSeparatedCrossing = properCrossings.length === 1
		? buildGradeSeparatedCrossingMetadata(points, properCrossings)
		: null;
	return {
		crossings,
		properCrossings,
		properCrossingCount: properCrossings.length,
		crossingCount: crossings.length,
		passes: properCrossings.length <= allowedProperCrossings,
		singleGradeSeparatedCrossing,
	};
}

function validateSmoothedLoop(originalLoopPoints, candidateLoopPoints, canvas, config) {
	const requireSamePointCount = config.requireSamePointCount !== false;
	if (!Array.isArray(candidateLoopPoints) || (requireSamePointCount && candidateLoopPoints.length !== originalLoopPoints.length)) {
		return { valid: false, reason: 'point_count_changed' };
	}
	if (!isClosedLoop(candidateLoopPoints)) return { valid: false, reason: 'not_closed_loop' };
	const topology = summarizeLoopTopology(candidateLoopPoints, { allowedProperCrossings: config.allowedProperCrossings || 0 });
	if (!topology.passes) {
		return {
			valid: false,
			reason: 'self_intersection',
			properCrossingCount: topology.properCrossingCount,
		};
	}
	if (config.clampToCanvas && !pathFitsCanvas(candidateLoopPoints, canvas)) return { valid: false, reason: 'out_of_bounds' };

	const originalArea = getSignedArea(originalLoopPoints);
	const candidateArea = getSignedArea(candidateLoopPoints);
	if (Math.sign(originalArea) !== 0 && Math.sign(candidateArea) !== 0 && Math.sign(originalArea) !== Math.sign(candidateArea)) {
		return { valid: false, reason: 'orientation_flipped' };
	}

	const originalShape = buildLoopShapeMetrics(originalLoopPoints);
	const candidateShape = buildLoopShapeMetrics(candidateLoopPoints);
	if ((config.allowedProperCrossings || 0) > 0) {
		return {
			valid: true,
			properCrossingCount: topology.properCrossingCount,
			singleGradeSeparatedCrossing: topology.singleGradeSeparatedCrossing,
			reflexVertexCount: candidateShape.reflexVertexCount,
			turnRunCount: candidateShape.turnRunCount,
			areaRatioToHull: candidateShape.areaRatioToHull,
			incomingAngleDelta: 0,
			outgoingAngleDelta: 0,
		};
	}
	const minimumReflexVertexCount = originalShape.reflexVertexCount <= 2
		? 0
		: Math.min(originalShape.reflexVertexCount, Math.max(1, Math.ceil(originalShape.reflexVertexCount * 0.6)));
	const minimumTurnRunCount = originalShape.turnRunCount <= 2
		? 0
		: Math.min(originalShape.turnRunCount, Math.max(2, Math.ceil(originalShape.turnRunCount * 0.7)));
	const enforceAreaRatio = requireSamePointCount && (originalShape.reflexVertexCount >= 4 || originalShape.turnRunCount >= 6);
	if (candidateShape.reflexVertexCount < minimumReflexVertexCount
		|| candidateShape.turnRunCount < minimumTurnRunCount
		|| (enforceAreaRatio && candidateShape.areaRatioToHull > (originalShape.areaRatioToHull + 0.12))) {
		return {
			valid: false,
			reason: 'shape_flattened',
			reflexVertexCount: candidateShape.reflexVertexCount,
			turnRunCount: candidateShape.turnRunCount,
			areaRatioToHull: candidateShape.areaRatioToHull,
		};
	}

	const originalSeam = computeSeamOrientation(originalLoopPoints);
	const candidateSeam = computeSeamOrientation(candidateLoopPoints);
	if (!originalSeam || !candidateSeam) return { valid: false, reason: 'degenerate_seam' };
	const incomingAngleDelta = vectorAngleDegrees(originalSeam.incoming, candidateSeam.incoming);
	const outgoingAngleDelta = vectorAngleDegrees(originalSeam.outgoing, candidateSeam.outgoing);
	if (incomingAngleDelta > config.maxStartAngleDeltaDegrees || outgoingAngleDelta > config.maxStartAngleDeltaDegrees) {
		return {
			valid: false,
			reason: 'start_orientation_changed',
			incomingAngleDelta: Number(incomingAngleDelta.toFixed(3)),
			outgoingAngleDelta: Number(outgoingAngleDelta.toFixed(3)),
		};
	}

	return {
		valid: true,
		properCrossingCount: topology.properCrossingCount,
		singleGradeSeparatedCrossing: topology.singleGradeSeparatedCrossing,
		reflexVertexCount: candidateShape.reflexVertexCount,
		turnRunCount: candidateShape.turnRunCount,
		areaRatioToHull: candidateShape.areaRatioToHull,
		incomingAngleDelta: Number(incomingAngleDelta.toFixed(3)),
		outgoingAngleDelta: Number(outgoingAngleDelta.toFixed(3)),
	};
}

function measureStartVerticality(points) {
	if (!Array.isArray(points) || points.length < 3) return 0;
	const prev = points[points.length - 1];
	const cur = points[0];
	const next = points[1];
	const len1 = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]) || 1;
	const len2 = Math.hypot(next[0] - cur[0], next[1] - cur[1]) || 1;
	return Number((((Math.abs(cur[1] - prev[1]) / len1) + (Math.abs(next[1] - cur[1]) / len2)) / 2).toFixed(3));
}

function pointKey(point) {
	return `${point[0]},${point[1]}`;
}

function comparePoints(a, b) {
	if (a[0] !== b[0]) return a[0] - b[0];
	return a[1] - b[1];
}

function cross(o, a, b) {
	return ((a[0] - o[0]) * (b[1] - o[1])) - ((a[1] - o[1]) * (b[0] - o[0]));
}

function uniquePoints(points) {
	const seen = new Set();
	const unique = [];
	for (const point of points || []) {
		const normalized = roundPoint(point);
		const key = pointKey(normalized);
		if (seen.has(key)) continue;
		seen.add(key);
		unique.push(normalized);
	}
	return unique;
}

function computeCentroid(points) {
	if (!Array.isArray(points) || points.length === 0) return [0, 0];
	let sumX = 0;
	let sumY = 0;
	for (const point of points) {
		sumX += point[0];
		sumY += point[1];
	}
	return [sumX / points.length, sumY / points.length];
}

function buildConvexHull(points) {
	const sorted = uniquePoints(points).sort(comparePoints);
	if (sorted.length <= 1) return sorted;

	const lower = [];
	for (const point of sorted) {
		while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) lower.pop();
		lower.push(point);
	}

	const upper = [];
	for (let index = sorted.length - 1; index >= 0; index--) {
		const point = sorted[index];
		while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) upper.pop();
		upper.push(point);
	}

	return lower.slice(0, -1).concat(upper.slice(0, -1));
}

function sortRemainingPoints(points, strategyName) {
	const normalizedStrategyName = String(strategyName || '').replace(/_(?:2opt|hull)$/, '');
	if (normalizedStrategyName === 'nearest_neighbor' || normalizedStrategyName === 'farthest_neighbor') {
		const unique = uniquePoints(points);
		if (unique.length <= 1) return unique;
		let startIndex = 0;
		for (let index = 1; index < unique.length; index++) {
			if (unique[index][1] < unique[startIndex][1]
				|| (unique[index][1] === unique[startIndex][1] && unique[index][0] < unique[startIndex][0])) {
				startIndex = index;
			}
		}
		const ordered = [unique[startIndex]];
		const remaining = unique.slice(0, startIndex).concat(unique.slice(startIndex + 1));
		while (remaining.length > 0) {
			const current = ordered[ordered.length - 1];
			let bestIndex = 0;
			let bestDistance = distanceSquared(current, remaining[0]);
			for (let index = 1; index < remaining.length; index++) {
				const candidateDistance = distanceSquared(current, remaining[index]);
				const better = normalizedStrategyName === 'nearest_neighbor'
					? candidateDistance < bestDistance - 1e-9
					: candidateDistance > bestDistance + 1e-9;
				if (better || (Math.abs(candidateDistance - bestDistance) <= 1e-9 && comparePoints(remaining[index], remaining[bestIndex]) < 0)) {
					bestIndex = index;
					bestDistance = candidateDistance;
				}
			}
			ordered.push(remaining.splice(bestIndex, 1)[0]);
		}
		return ordered;
	}
	const centroid = computeCentroid(points);
	const withMetrics = (points || []).map(point => {
		const dx = point[0] - centroid[0];
		const dy = point[1] - centroid[1];
		return {
			point,
			angle: Math.atan2(dy, dx),
			distanceSquared: (dx * dx) + (dy * dy),
		};
	});

	withMetrics.sort((a, b) => {
		if (normalizedStrategyName === 'centroid_distance_desc') {
			if (b.distanceSquared !== a.distanceSquared) return b.distanceSquared - a.distanceSquared;
			if (a.angle !== b.angle) return a.angle - b.angle;
			return comparePoints(a.point, b.point);
		}
		if (normalizedStrategyName === 'centroid_angle') {
			if (a.angle !== b.angle) return a.angle - b.angle;
			if (b.distanceSquared !== a.distanceSquared) return b.distanceSquared - a.distanceSquared;
			return comparePoints(a.point, b.point);
		}
		return comparePoints(a.point, b.point);
	});

	return withMetrics.map(entry => entry.point);
}

function loopPerimeter(loopPoints) {
	if (!Array.isArray(loopPoints) || loopPoints.length < 2) return 0;
	let total = 0;
	for (let index = 0; index < loopPoints.length; index++) {
		total += segmentLength(loopPoints[index], loopPoints[(index + 1) % loopPoints.length]);
	}
	return total;
}

function countReflexVertices(loopPoints) {
	if (!Array.isArray(loopPoints) || loopPoints.length < 4) return 0;
	const orientation = Math.sign(getSignedArea(loopPoints));
	if (orientation === 0) return 0;
	let reflexCount = 0;
	for (let index = 0; index < loopPoints.length; index++) {
		const prev = loopPoints[(index - 1 + loopPoints.length) % loopPoints.length];
		const cur = loopPoints[index];
		const next = loopPoints[(index + 1) % loopPoints.length];
		const turn = cross(prev, cur, next);
		if (Math.sign(turn) !== 0 && Math.sign(turn) !== orientation) reflexCount += 1;
	}
	return reflexCount;
}

function countTurnRuns(loopPoints) {
	if (!Array.isArray(loopPoints) || loopPoints.length < 4) return 0;
	const signs = [];
	for (let index = 0; index < loopPoints.length; index++) {
		const prev = loopPoints[(index - 1 + loopPoints.length) % loopPoints.length];
		const cur = loopPoints[index];
		const next = loopPoints[(index + 1) % loopPoints.length];
		const sign = Math.sign(cross(prev, cur, next));
		if (sign !== 0) signs.push(sign);
	}
	if (signs.length === 0) return 0;
	let runs = 1;
	for (let index = 1; index < signs.length; index++) {
		if (signs[index] !== signs[index - 1]) runs += 1;
	}
	if (signs.length > 1 && signs[0] !== signs[signs.length - 1]) runs -= 1;
	return runs;
}

function buildLoopShapeMetrics(loopPoints) {
	if (!Array.isArray(loopPoints) || loopPoints.length < 3) {
		return {
			reflexVertexCount: 0,
			turnRunCount: 0,
			areaRatioToHull: 1,
			perimeterRatioToHull: 1,
		};
	}
	const hull = buildConvexHull(loopPoints);
	const loopArea = Math.abs(getSignedArea(loopPoints));
	const hullArea = Math.max(loopArea, Math.abs(getSignedArea(hull)));
	const loopPerimeterValue = loopPerimeter(loopPoints);
	const hullPerimeterValue = Math.max(loopPerimeterValue, loopPerimeter(hull));
	return {
		reflexVertexCount: countReflexVertices(loopPoints),
		turnRunCount: countTurnRuns(loopPoints),
		areaRatioToHull: Number((hullArea > 0 ? loopArea / hullArea : 1).toFixed(6)),
		perimeterRatioToHull: Number((hullPerimeterValue > 0 ? loopPerimeterValue / hullPerimeterValue : 1).toFixed(6)),
	};
}

function rotateLoopToBestStartPoint(loopPoints) {
	if (!Array.isArray(loopPoints) || loopPoints.length < 3) return clonePointPath(loopPoints);
	let bestIndex = 0;
	let bestVerticality = -Infinity;
	let bestTurnPenalty = Infinity;
	for (let index = 0; index < loopPoints.length; index++) {
		const prev = loopPoints[(index - 1 + loopPoints.length) % loopPoints.length];
		const cur = loopPoints[index];
		const next = loopPoints[(index + 1) % loopPoints.length];
		const incoming = [cur[0] - prev[0], cur[1] - prev[1]];
		const outgoing = [next[0] - cur[0], next[1] - cur[1]];
		const inLen = Math.hypot(incoming[0], incoming[1]) || 1;
		const outLen = Math.hypot(outgoing[0], outgoing[1]) || 1;
		const verticality = ((Math.abs(incoming[1]) / inLen) + (Math.abs(outgoing[1]) / outLen)) / 2;
		const turnPenalty = vectorAngleDegrees(incoming, outgoing);
		if (verticality > bestVerticality + 1e-9
			|| (Math.abs(verticality - bestVerticality) <= 1e-9 && turnPenalty < bestTurnPenalty - 1e-9)
			|| (Math.abs(verticality - bestVerticality) <= 1e-9 && Math.abs(turnPenalty - bestTurnPenalty) <= 1e-9 && index < bestIndex)) {
			bestIndex = index;
			bestVerticality = verticality;
			bestTurnPenalty = turnPenalty;
		}
	}
	return loopPoints.slice(bestIndex).concat(loopPoints.slice(0, bestIndex)).map(roundPoint);
}

function untangleLoopWithTwoOpt(loopPoints) {
	let loop = clonePointPath(loopPoints);
	const diagnostics = {
		iterations: 0,
		failure_reason: null,
	};
	if (!isClosedLoop(loop)) {
		diagnostics.failure_reason = 'not_closed_loop';
		return { success: false, loop_points: [], diagnostics };
	}
	const maxIterations = Math.max(1, loop.length * loop.length);
	for (let iteration = 0; iteration < maxIterations; iteration++) {
		const intersections = listSelfIntersections(loop, { includeEndpointTouches: false }).filter(intersection => intersection.proper);
		if (intersections.length === 0) {
			diagnostics.iterations = iteration;
			return {
				success: true,
				loop_points: rotateLoopToBestStartPoint(loop),
				diagnostics,
			};
		}
		intersections.sort((a, b) => {
			if (a.segmentA !== b.segmentA) return a.segmentA - b.segmentA;
			if (a.segmentB !== b.segmentB) return a.segmentB - b.segmentB;
			return 0;
		});
		const crossing = intersections[0];
		loop = applyTwoOptCrossing(loop, crossing.segmentA, crossing.segmentB);
		diagnostics.iterations = iteration + 1;
	}
	diagnostics.failure_reason = 'crossings_persist';
	return { success: false, loop_points: [], diagnostics };
}

function evaluateCycleCandidate(loopPoints, hullArea) {
	const shapeMetrics = buildLoopShapeMetrics(loopPoints);
	return {
		loop_points: rotateLoopToBestStartPoint(loopPoints),
		reflex_vertex_count: shapeMetrics.reflexVertexCount,
		turn_run_count: shapeMetrics.turnRunCount,
		area_ratio_to_hull: hullArea > 0 ? shapeMetrics.areaRatioToHull : 1,
		perimeter_ratio_to_hull: shapeMetrics.perimeterRatioToHull,
		visual_complexity_passes: shapeMetrics.reflexVertexCount >= 4 && shapeMetrics.areaRatioToHull <= 0.68,
		perimeter: Number(loopPerimeter(loopPoints).toFixed(6)),
	};
}

function compareCycleCandidates(a, b) {
	if (a.visual_complexity_passes !== b.visual_complexity_passes) return a.visual_complexity_passes ? -1 : 1;
	if (a.area_ratio_to_hull !== b.area_ratio_to_hull) return a.area_ratio_to_hull - b.area_ratio_to_hull;
	if (a.perimeter_ratio_to_hull !== b.perimeter_ratio_to_hull) return b.perimeter_ratio_to_hull - a.perimeter_ratio_to_hull;
	if (a.reflex_vertex_count !== b.reflex_vertex_count) return b.reflex_vertex_count - a.reflex_vertex_count;
	if (a.turn_run_count !== b.turn_run_count) return b.turn_run_count - a.turn_run_count;
	const aTwoOpt = String(a.strategy || '').endsWith('_2opt');
	const bTwoOpt = String(b.strategy || '').endsWith('_2opt');
	if (aTwoOpt !== bTwoOpt) return aTwoOpt ? -1 : 1;
	if (a.perimeter !== b.perimeter) return b.perimeter - a.perimeter;
	return 0;
}

function moveLoopVertex(loopPoints, fromIndex, insertAfterIndex) {
	const count = loopPoints.length;
	if (count < 4) return clonePointPath(loopPoints);
	if (fromIndex === insertAfterIndex || ((fromIndex - 1 + count) % count) === insertAfterIndex) return clonePointPath(loopPoints);
	const point = loopPoints[fromIndex];
	const withoutPoint = loopPoints.slice(0, fromIndex).concat(loopPoints.slice(fromIndex + 1));
	let adjustedInsertAfter = insertAfterIndex;
	if (insertAfterIndex > fromIndex) adjustedInsertAfter -= 1;
	return withoutPoint
		.slice(0, adjustedInsertAfter + 1)
		.concat([point], withoutPoint.slice(adjustedInsertAfter + 1))
		.map(roundPoint);
}

function optimizeLoopComplexity(loopPoints, hullArea) {
	let current = clonePointPath(loopPoints);
	let currentMetrics = evaluateCycleCandidate(current, hullArea);
	const maxIterations = Math.max(1, current.length * 4);
	for (let iteration = 0; iteration < maxIterations; iteration++) {
		let bestLoop = null;
		let bestMetrics = currentMetrics;
		for (let fromIndex = 0; fromIndex < current.length; fromIndex++) {
			for (let insertAfterIndex = 0; insertAfterIndex < current.length; insertAfterIndex++) {
				const candidate = moveLoopVertex(current, fromIndex, insertAfterIndex);
				if (candidate.length !== current.length) continue;
				if (!isClosedLoop(candidate)) continue;
				if (countProperSelfIntersections(candidate) > 0) continue;
				const candidateMetrics = evaluateCycleCandidate(candidate, hullArea);
				if (compareCycleCandidates(candidateMetrics, bestMetrics) < 0) {
					bestLoop = candidate;
					bestMetrics = candidateMetrics;
				}
			}
		}
		if (!bestLoop) break;
		current = bestLoop;
		currentMetrics = bestMetrics;
	}
	return currentMetrics;
}

function chooseInsertion(loopPoints, point) {
	let best = null;
	for (let index = 0; index < loopPoints.length; index++) {
		const nextIndex = (index + 1) % loopPoints.length;
		const candidate = loopPoints.slice(0, index + 1).concat([point], loopPoints.slice(index + 1));
		if (!isClosedLoop(candidate)) continue;
		if (countProperSelfIntersections(candidate) > 0) continue;
		const cost = segmentLength(loopPoints[index], point)
			+ segmentLength(point, loopPoints[nextIndex])
			- segmentLength(loopPoints[index], loopPoints[nextIndex]);
		if (!best || cost < best.cost - 1e-9 || (Math.abs(cost - best.cost) <= 1e-9 && index < best.index)) {
			best = {
				cost,
				index,
				loop: candidate,
			};
		}
	}
	return best;
}

function buildSimpleCycleFromPoints(points, options = {}) {
	const unique = uniquePoints(points);
	const diagnostics = {
		point_count: unique.length,
		strategy_names: CYCLE_BUILD_STRATEGIES.slice(),
		attempt_count: 0,
		attempts: [],
		selected_strategy: null,
		final_point_count: 0,
		failure_reason: null,
	};

	if (unique.length < 3) {
		diagnostics.failure_reason = 'too_few_points';
		return { success: false, loop_points: [], diagnostics };
	}

	const hull = buildConvexHull(unique);
	if (hull.length < 3 || !isClosedLoop(hull)) {
		diagnostics.failure_reason = 'degenerate_hull';
		return { success: false, loop_points: [], diagnostics };
	}
	const hullArea = Math.abs(getSignedArea(hull));

	const hullKeys = new Set(hull.map(pointKey));
	const remaining = unique.filter(point => !hullKeys.has(pointKey(point)));
	let bestCandidate = null;

	for (const strategyName of CYCLE_BUILD_STRATEGIES) {
		let loopPoints = [];
		const attempt = {
			strategy: strategyName,
			inserted_point_count: 0,
			remaining_point_count: 0,
			success: false,
			failure_reason: null,
			failed_point: null,
			reflex_vertex_count: 0,
			turn_run_count: 0,
			area_ratio_to_hull: null,
		};

		if (strategyName.endsWith('_2opt')) {
			const ordered = sortRemainingPoints(unique, strategyName);
			attempt.inserted_point_count = ordered.length;
			attempt.remaining_point_count = 0;
			const untangled = untangleLoopWithTwoOpt(ordered);
			if (!untangled.success) {
				attempt.failure_reason = untangled.diagnostics.failure_reason || 'two_opt_failed';
			} else {
				loopPoints = untangled.loop_points;
			}
		} else {
			loopPoints = hull.map(roundPoint);
			const ordered = sortRemainingPoints(remaining, strategyName);
			attempt.inserted_point_count = loopPoints.length;
			attempt.remaining_point_count = ordered.length;
			for (const point of ordered) {
				const choice = chooseInsertion(loopPoints, point);
				if (!choice) {
					attempt.failure_reason = 'no_simple_insertion';
					attempt.failed_point = point.slice();
					loopPoints = [];
					break;
				}
				loopPoints = choice.loop.map(roundPoint);
				attempt.inserted_point_count += 1;
			}
		}

		if (loopPoints.length === unique.length && countProperSelfIntersections(loopPoints) === 0 && isClosedLoop(loopPoints)) {
			const candidate = Object.assign({ strategy: strategyName }, optimizeLoopComplexity(loopPoints, hullArea));
			attempt.success = true;
			attempt.reflex_vertex_count = candidate.reflex_vertex_count;
			attempt.turn_run_count = candidate.turn_run_count;
			attempt.area_ratio_to_hull = candidate.area_ratio_to_hull;
			if (!bestCandidate || compareCycleCandidates(candidate, bestCandidate) < 0) {
				bestCandidate = candidate;
			}
		} else if (!attempt.failure_reason) {
			attempt.failure_reason = 'invalid_final_loop';
		}

		diagnostics.attempts.push(attempt);
	}

	if (bestCandidate) {
		diagnostics.attempt_count = diagnostics.attempts.length;
		diagnostics.selected_strategy = bestCandidate.strategy;
		diagnostics.final_point_count = bestCandidate.loop_points.length;
		return {
			success: true,
			loop_points: bestCandidate.loop_points,
			diagnostics,
		};
	}

	diagnostics.attempt_count = diagnostics.attempts.length;
	diagnostics.failure_reason = diagnostics.attempts[diagnostics.attempts.length - 1]?.failure_reason || 'no_strategy_succeeded';
	return { success: false, loop_points: [], diagnostics };
}

function applyTwoOptCrossing(loopPoints, startEdgeIndex, endEdgeIndex) {
	return loopPoints
		.slice(0, startEdgeIndex + 1)
		.concat(loopPoints.slice(startEdgeIndex + 1, endEdgeIndex + 1).reverse())
		.concat(loopPoints.slice(endEdgeIndex + 1))
		.map(roundPoint);
}

function injectSingleGradeSeparatedCrossing(loopPoints) {
	const baseLoop = clonePointPath(loopPoints);
	const diagnostics = {
		attempted_pairs: 0,
		selected_pair: null,
		failure_reason: null,
	};
	if (!Array.isArray(baseLoop) || baseLoop.length < 6) {
		diagnostics.failure_reason = 'loop_too_short';
		return { success: false, loop_points: baseLoop, diagnostics, crossing: null };
	}
	for (let startEdgeIndex = 0; startEdgeIndex < baseLoop.length; startEdgeIndex++) {
		for (let endEdgeIndex = startEdgeIndex + 2; endEdgeIndex < baseLoop.length; endEdgeIndex++) {
			if (startEdgeIndex === 0 && endEdgeIndex === baseLoop.length - 1) continue;
			diagnostics.attempted_pairs += 1;
			const candidate = applyTwoOptCrossing(baseLoop, startEdgeIndex, endEdgeIndex);
			const topology = summarizeLoopTopology(candidate, { allowedProperCrossings: 1 });
			if (!topology.passes || topology.properCrossingCount !== 1 || !topology.singleGradeSeparatedCrossing) continue;
			diagnostics.selected_pair = [startEdgeIndex, endEdgeIndex];
			return {
				success: true,
				loop_points: candidate,
				diagnostics,
				crossing: topology.singleGradeSeparatedCrossing,
			};
		}
	}
	diagnostics.failure_reason = 'no_single_crossing_candidate';
	return { success: false, loop_points: baseLoop, diagnostics, crossing: null };
}

function clampSmoothLoop(loopPoints, canvas, options = {}) {
	const baseLoop = clonePointPath(loopPoints);
	const config = resolveSmoothingConfig(options);
	const diagnostics = {
		requested_passes: config.passes,
		applied_passes: 0,
		used_fallback: false,
		attempts: [],
	};

	if (!baseLoop.length) {
		diagnostics.failure_reason = 'empty_loop';
		return { success: false, smoothed_points: [], diagnostics };
	}

	for (let passes = config.passes; passes >= 0; passes--) {
		let candidate = passes > 0 ? smoothClosedPath(baseLoop, passes) : clonePointPath(baseLoop);
		if (config.preserveStartPoint) candidate = reanchorLoopToStartPoint(candidate, baseLoop[0]);
		candidate = candidate.map(roundPoint);
	const validation = validateSmoothedLoop(baseLoop, candidate, canvas, config);
		diagnostics.attempts.push({
			passes,
			valid: validation.valid,
			reason: validation.reason || null,
			incoming_angle_delta: validation.incomingAngleDelta ?? null,
			outgoing_angle_delta: validation.outgoingAngleDelta ?? null,
		});
		if (!validation.valid) continue;
		diagnostics.applied_passes = passes;
		diagnostics.used_fallback = passes !== config.passes;
		return {
			success: true,
			smoothed_points: candidate,
			diagnostics,
		};
	}

	diagnostics.failure_reason = diagnostics.attempts[diagnostics.attempts.length - 1]?.reason || 'no_valid_smoothing';
	return {
		success: false,
		smoothed_points: clonePointPath(baseLoop),
		diagnostics,
	};
}

function buildResampledCenterline(track, sourcePoints, canvas, options = {}) {
	const baseLoop = clonePointPath(sourcePoints);
	const config = resolveResamplingConfig(track, options);
	const diagnostics = {
		requested_sample_count: config.sampleCount,
		produced_sample_count: 0,
		start_verticality: 0,
		incoming_angle_delta: null,
		outgoing_angle_delta: null,
		failure_reason: null,
	};

	if (!baseLoop.length) {
		diagnostics.failure_reason = 'empty_loop';
		return { success: false, resampled_points: [], diagnostics };
	}

	let candidate = resampleClosedPath(baseLoop, config.sampleCount).map(roundPoint);
	if (config.preserveStartPoint) candidate = reanchorLoopToStartPoint(candidate, baseLoop[0]);
	const validation = validateSmoothedLoop(baseLoop, candidate, canvas, {
		clampToCanvas: config.clampToCanvas,
		allowedProperCrossings: config.allowedProperCrossings,
		maxStartAngleDeltaDegrees: config.maxStartAngleDeltaDegrees,
		requireSamePointCount: false,
	});
	diagnostics.produced_sample_count = candidate.length;
	diagnostics.start_verticality = measureStartVerticality(candidate);
	diagnostics.incoming_angle_delta = validation.incomingAngleDelta ?? null;
	diagnostics.outgoing_angle_delta = validation.outgoingAngleDelta ?? null;

	if (!validation.valid) {
		diagnostics.failure_reason = validation.reason || 'invalid_resample';
		return { success: false, resampled_points: [], diagnostics };
	}

	return {
		success: true,
		resampled_points: candidate,
		diagnostics,
	};
}

function resolvePointSamplingConfig(canvas, options = {}) {
	const area = Math.max(1, (canvas?.width || 0) * (canvas?.height || 0));
	const densityDivisor = Math.max(1, Number(options.densityDivisor) || DEFAULT_POINT_SAMPLING_OPTIONS.densityDivisor);
	const minPointCount = Math.max(3, options.minPointCount | 0 || DEFAULT_POINT_SAMPLING_OPTIONS.minPointCount);
	const maxPointCount = Math.max(minPointCount, options.maxPointCount | 0 || DEFAULT_POINT_SAMPLING_OPTIONS.maxPointCount);
	const explicitTargetPointCount = Number.isInteger(options.targetPointCount) ? options.targetPointCount : null;
	const targetPointCount = explicitTargetPointCount !== null
		? clamp(explicitTargetPointCount, minPointCount, maxPointCount)
		: clamp(Math.round(area / densityDivisor), minPointCount, maxPointCount);
	const edgeMarginPx = Math.max(0, options.edgeMarginPx | 0 || DEFAULT_POINT_SAMPLING_OPTIONS.edgeMarginPx);
	const derivedSpacing = Math.max(4, Math.round(Math.sqrt(area / targetPointCount) * 0.65));
	const minimumSpacingPx = Math.max(1, Number(options.minimumSpacingPx) || derivedSpacing || DEFAULT_POINT_SAMPLING_OPTIONS.minimumSpacingPx);
	const maxPlacementAttemptsMultiplier = Math.max(1, options.maxPlacementAttemptsMultiplier | 0 || DEFAULT_POINT_SAMPLING_OPTIONS.maxPlacementAttemptsMultiplier);
	const maxSpacingRelaxationPasses = Math.max(0, options.maxSpacingRelaxationPasses | 0 || DEFAULT_POINT_SAMPLING_OPTIONS.maxSpacingRelaxationPasses);
	const spacingDecay = clamp(Number(options.spacingDecay) || DEFAULT_POINT_SAMPLING_OPTIONS.spacingDecay, 0.25, 1);
	return {
		area,
		densityDivisor,
		minPointCount,
		maxPointCount,
		targetPointCount,
		edgeMarginPx,
		minimumSpacingPx,
		maxPlacementAttemptsMultiplier,
		maxSpacingRelaxationPasses,
		spacingDecay,
	};
}

function buildSamplingBounds(canvas, config) {
	const xMin = Math.ceil((canvas?.x_min || 0) + config.edgeMarginPx);
	const yMin = Math.ceil((canvas?.y_min || 0) + config.edgeMarginPx);
	const xMax = Math.floor((canvas?.x_max || 0) - config.edgeMarginPx);
	const yMax = Math.floor((canvas?.y_max || 0) - config.edgeMarginPx);
	if (xMax < xMin || yMax < yMin) {
		throw new Error('Point sampling bounds collapsed; reduce edge margin or increase canvas size');
	}
	return { xMin, yMin, xMax, yMax };
}

function isFarEnough(points, candidate, minimumSpacing) {
	const minDistanceSquared = minimumSpacing * minimumSpacing;
	return points.every(point => distanceSquared(point, candidate) >= minDistanceSquared);
}

function sampleMapPoints(rng, canvas, options = {}) {
	const config = resolvePointSamplingConfig(canvas, options);
	const bounds = buildSamplingBounds(canvas, config);
	const points = [];
	let spacing = config.minimumSpacingPx;

	for (let pass = 0; pass <= config.maxSpacingRelaxationPasses && points.length < config.targetPointCount; pass++) {
		const maxAttempts = config.targetPointCount * config.maxPlacementAttemptsMultiplier;
		for (let attempt = 0; attempt < maxAttempts && points.length < config.targetPointCount; attempt++) {
			const candidate = [
				rng.randInt(bounds.xMin, bounds.xMax),
				rng.randInt(bounds.yMin, bounds.yMax),
			];
			if (!isFarEnough(points, candidate, spacing)) continue;
			points.push(candidate);
		}
		spacing = Math.max(1, spacing * config.spacingDecay);
	}

	if (points.length < config.targetPointCount) {
		const gridStep = Math.max(1, Math.floor(config.minimumSpacingPx * 0.75));
		for (let y = bounds.yMin; y <= bounds.yMax && points.length < config.targetPointCount; y += gridStep) {
			for (let x = bounds.xMin; x <= bounds.xMax && points.length < config.targetPointCount; x += gridStep) {
				const candidate = [x, y];
				if (!isFarEnough(points, candidate, Math.max(1, spacing))) continue;
				points.push(candidate);
			}
		}
	}

	return points.map(roundPoint);
}

function buildTrackSlotSeed(masterSeed, trackSlot = 0) {
	const base = deriveSubseed(masterSeed >>> 0, MOD_TRACK_MINIMAP);
	const slotSalt = (((trackSlot + 1) * 0x9E3779B9) >>> 0);
	return (base ^ slotSalt) >>> 0 || 1;
}

function evaluateCrossingEligibility(masterSeed, trackSlot = 0) {
	const seed = buildTrackSlotSeed(masterSeed >>> 0, trackSlot);
	const rng = new XorShift32(seed);
	const roll = rng.randInt(0, CROSSING_SELECTION_ODDS - 1);
	return {
		seed,
		roll,
		odds: CROSSING_SELECTION_ODDS,
		eligible: roll === 0,
	};
}

function generateMapSamplePointsForTrack(track, masterSeed, options = {}) {
	const trackSlot = Number.isInteger(options.trackSlot)
		? options.trackSlot
		: (Number.isInteger(track?.index) ? track.index : 0);
	const canvas = options.canvas || buildMapFirstCanvas(options.canvasMarginPx);
	const rng = new XorShift32(buildTrackSlotSeed(masterSeed >>> 0, trackSlot));
	return sampleMapPoints(rng, canvas, options.pointSampling);
}

function buildMapFirstGeometryState(track, masterSeed, options = {}) {
	const canvas = options.canvas || buildMapFirstCanvas(options.canvasMarginPx);
	const trackSlot = Number.isInteger(options.trackSlot)
		? options.trackSlot
		: (Number.isInteger(track?.index) ? track.index : 0);
	const crossingEligibility = evaluateCrossingEligibility(masterSeed >>> 0, trackSlot);
	const sampledPoints = generateMapSamplePointsForTrack(track, masterSeed, Object.assign({}, options, { canvas }));
	const cycle = buildSimpleCycleFromPoints(sampledPoints, options.cycle);
	const crossingLoop = cycle.success && crossingEligibility.eligible
		? injectSingleGradeSeparatedCrossing(cycle.loop_points)
		: { success: false, loop_points: cycle.loop_points, diagnostics: { attempted_pairs: 0, selected_pair: null, failure_reason: 'crossing_not_requested' }, crossing: null };
	const loopPoints = crossingLoop.success ? crossingLoop.loop_points : cycle.loop_points;
	const allowedProperCrossings = crossingLoop.success ? 1 : 0;
	const smoothing = cycle.success
		? clampSmoothLoop(loopPoints, canvas, Object.assign({}, options.smoothing, { allowedProperCrossings }))
		: { success: false, smoothed_points: [], diagnostics: { requested_passes: 0, applied_passes: 0, used_fallback: false, attempts: [], failure_reason: 'cycle_failed' } };
	const resampling = smoothing.success
		? buildResampledCenterline(track, smoothing.smoothed_points, canvas, Object.assign({}, options.resampling, { allowedProperCrossings }))
		: { success: false, resampled_points: [], diagnostics: { requested_sample_count: 0, produced_sample_count: 0, start_verticality: 0, incoming_angle_delta: null, outgoing_angle_delta: null, failure_reason: 'smoothing_failed' } };
	const topologyPath = resampling.success && resampling.resampled_points.length
		? resampling.resampled_points
		: (smoothing.success && smoothing.smoothed_points.length ? smoothing.smoothed_points : loopPoints);
	const topologySummary = summarizeLoopTopology(topologyPath, { allowedProperCrossings });
	return {
		canvas,
		sampled_points: sampledPoints,
		loop_points: loopPoints,
		smoothed_centerline: smoothing.smoothed_points,
		resampled_centerline: resampling.resampled_points,
		generation_diagnostics: Object.assign({}, cycle.diagnostics, {
			crossing_selection: crossingEligibility,
			crossing_injection: crossingLoop.diagnostics,
			smoothing: smoothing.diagnostics,
			resampling: resampling.diagnostics,
		}),
		topology: {
			crossing_count: topologySummary.crossingCount,
			proper_crossing_count: topologySummary.properCrossingCount,
			crossing_candidates: topologySummary.crossings,
			eligible_for_grade_separated_crossing: crossingEligibility.eligible,
			single_grade_separated_crossing: topologySummary.singleGradeSeparatedCrossing,
		},
		projections: {
			curve: null,
			slope: null,
			minimap_runtime: null,
			minimap_preview: null,
			sign_features: null,
		},
	};
}

function attachMapFirstGeometryState(track, masterSeed, options = {}) {
	return setGeneratedGeometryState(track, buildMapFirstGeometryState(track, masterSeed, options));
}

module.exports = {
	DEFAULT_POINT_SAMPLING_OPTIONS,
	resolvePointSamplingConfig,
	buildSamplingBounds,
	sampleMapPoints,
	buildConvexHull,
	buildSimpleCycleFromPoints,
	injectSingleGradeSeparatedCrossing,
	buildGradeSeparatedCrossingMetadata,
	summarizeLoopTopology,
	resolveSmoothingConfig,
	resolveResamplingConfig,
	clampSmoothLoop,
	buildResampledCenterline,
	measureStartVerticality,
	pathFitsCanvas,
	buildTrackSlotSeed,
	evaluateCrossingEligibility,
	CROSSING_SELECTION_ODDS,
	generateMapSamplePointsForTrack,
	buildMapFirstGeometryState,
	attachMapFirstGeometryState,
};
