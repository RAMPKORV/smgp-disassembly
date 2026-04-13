'use strict';

const DEFAULT_EPSILON = 1e-6;

function nearlyEqual(a, b, epsilon = DEFAULT_EPSILON) {
	return Math.abs(a - b) <= epsilon;
}

function clonePointPath(points) {
	if (!Array.isArray(points)) return [];
	return points.map(point => [Number(point[0]), Number(point[1])]);
}

function pointsEqual(a, b, epsilon = DEFAULT_EPSILON) {
	return Array.isArray(a)
		&& Array.isArray(b)
		&& nearlyEqual(a[0], b[0], epsilon)
		&& nearlyEqual(a[1], b[1], epsilon);
}

function normalizeClosedPoints(points, epsilon = DEFAULT_EPSILON) {
	const cloned = clonePointPath(points);
	if (cloned.length > 1 && pointsEqual(cloned[0], cloned[cloned.length - 1], epsilon)) {
		cloned.pop();
	}
	return cloned;
}

function orient(a, b, c) {
	return ((b[0] - a[0]) * (c[1] - a[1])) - ((b[1] - a[1]) * (c[0] - a[0]));
}

function pointOnSegment(a, b, p, epsilon = DEFAULT_EPSILON) {
	if (Math.abs(orient(a, b, p)) > epsilon) return false;
	return p[0] >= Math.min(a[0], b[0]) - epsilon
		&& p[0] <= Math.max(a[0], b[0]) + epsilon
		&& p[1] >= Math.min(a[1], b[1]) - epsilon
		&& p[1] <= Math.max(a[1], b[1]) + epsilon;
}

function pointIsSegmentEndpoint(point, a, b, epsilon = DEFAULT_EPSILON) {
	return pointsEqual(point, a, epsilon) || pointsEqual(point, b, epsilon);
}

function segmentLength(a, b) {
	const dx = b[0] - a[0];
	const dy = b[1] - a[1];
	return Math.sqrt((dx * dx) + (dy * dy));
}

function buildClosedPathSegments(points) {
	const normalized = normalizeClosedPoints(points);
	if (normalized.length < 2) return { segments: [], totalLength: 0 };

	const segments = [];
	let totalLength = 0;
	for (let index = 0; index < normalized.length; index++) {
		const start = normalized[index];
		const end = normalized[(index + 1) % normalized.length];
		const length = segmentLength(start, end);
		if (length <= 0) continue;
		segments.push({
			index,
			start,
			end,
			length,
			startDistance: totalLength,
		});
		totalLength += length;
	}

	return { segments, totalLength };
}

function getPathLength(points) {
	return buildClosedPathSegments(points).totalLength;
}

function getSignedArea(points) {
	const normalized = normalizeClosedPoints(points);
	if (normalized.length < 3) return 0;
	let area = 0;
	for (let index = 0; index < normalized.length; index++) {
		const a = normalized[index];
		const b = normalized[(index + 1) % normalized.length];
		area += (a[0] * b[1]) - (b[0] * a[1]);
	}
	return area / 2;
}

function isClosedLoop(points, epsilon = DEFAULT_EPSILON) {
	const normalized = normalizeClosedPoints(points, epsilon);
	if (normalized.length < 3) return false;
	if (getPathLength(normalized) <= epsilon) return false;
	return Math.abs(getSignedArea(normalized)) > epsilon;
}

function lineIntersectionPoint(a, b, c, d, epsilon = DEFAULT_EPSILON) {
	const denom = ((a[0] - b[0]) * (c[1] - d[1])) - ((a[1] - b[1]) * (c[0] - d[0]));
	if (Math.abs(denom) <= epsilon) {
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

function dedupePoints(points, epsilon = DEFAULT_EPSILON) {
	const unique = [];
	for (const point of points) {
		if (!unique.some(candidate => pointsEqual(candidate, point, epsilon))) {
			unique.push([point[0], point[1]]);
		}
	}
	return unique;
}

function segmentIntersection(a, b, c, d, options = {}) {
	const epsilon = Number.isFinite(options.epsilon) ? options.epsilon : DEFAULT_EPSILON;
	const o1 = orient(a, b, c);
	const o2 = orient(a, b, d);
	const o3 = orient(c, d, a);
	const o4 = orient(c, d, b);

	const straddlesAB = ((o1 > epsilon && o2 < -epsilon) || (o1 < -epsilon && o2 > epsilon));
	const straddlesCD = ((o3 > epsilon && o4 < -epsilon) || (o3 < -epsilon && o4 > epsilon));
 
	if (straddlesAB && straddlesCD) {
		const point = lineIntersectionPoint(a, b, c, d, epsilon);
		return {
			kind: 'point',
			point,
			proper: true,
			touchesEndpoint: false,
			sharedEndpoint: false,
		};
	}

	const touches = [];
	if (pointOnSegment(a, b, c, epsilon)) touches.push(c);
	if (pointOnSegment(a, b, d, epsilon)) touches.push(d);
	if (pointOnSegment(c, d, a, epsilon)) touches.push(a);
	if (pointOnSegment(c, d, b, epsilon)) touches.push(b);

	const uniqueTouches = dedupePoints(touches, epsilon);
	if (uniqueTouches.length === 0) {
		return {
			kind: 'none',
			point: null,
			proper: false,
			touchesEndpoint: false,
			sharedEndpoint: false,
		};
	}

	const sharedEndpoint = uniqueTouches.some(point => pointIsSegmentEndpoint(point, a, b, epsilon)
		&& pointIsSegmentEndpoint(point, c, d, epsilon));
	if (uniqueTouches.length === 1) {
		return {
			kind: 'point',
			point: uniqueTouches[0],
			proper: false,
			touchesEndpoint: true,
			sharedEndpoint,
		};
	}

	return {
		kind: 'overlap',
		point: uniqueTouches[0],
		proper: false,
		touchesEndpoint: true,
		sharedEndpoint,
	};
}

function cyclicIndexGap(a, b, count) {
	const diff = Math.abs(a - b);
	if (!Number.isInteger(count) || count <= 0) return diff;
	return Math.min(diff, count - diff);
}

function listSelfIntersections(points, options = {}) {
	const normalized = normalizeClosedPoints(points);
	if (normalized.length < 4) return [];

	const minIndexGap = Number.isInteger(options.minIndexGap) ? options.minIndexGap : 0;
	const includeEndpointTouches = options.includeEndpointTouches !== false;
	const epsilon = Number.isFinite(options.epsilon) ? options.epsilon : DEFAULT_EPSILON;
	const intersections = [];

	for (let i = 0; i < normalized.length; i++) {
		const a = normalized[i];
		const b = normalized[(i + 1) % normalized.length];
		for (let j = i + 1; j < normalized.length; j++) {
			if (cyclicIndexGap(i, j, normalized.length) <= minIndexGap) continue;
			if (((i + 1) % normalized.length) === j) continue;
			if (((j + 1) % normalized.length) === i) continue;
			const c = normalized[j];
			const d = normalized[(j + 1) % normalized.length];
			const intersection = segmentIntersection(a, b, c, d, { epsilon });
			if (intersection.kind === 'none') continue;
			if (!includeEndpointTouches && !intersection.proper) continue;
			intersections.push({
				segmentA: i,
				segmentB: j,
				kind: intersection.kind,
				point: intersection.point ? [intersection.point[0], intersection.point[1]] : null,
				proper: intersection.proper,
				touchesEndpoint: intersection.touchesEndpoint,
				sharedEndpoint: intersection.sharedEndpoint,
			});
		}
	}

	return intersections;
}

function countSelfIntersections(points, options = {}) {
	return listSelfIntersections(points, options).length;
}

function countProperSelfIntersections(points, options = {}) {
	return listSelfIntersections(points, Object.assign({}, options, {
		includeEndpointTouches: false,
	})).length;
}

function sampleClosedPath(points, sampleCount) {
	if (!Array.isArray(points) || points.length === 0 || sampleCount <= 0) return [];
	const normalized = normalizeClosedPoints(points);
	if (normalized.length === 0) return [];
	if (normalized.length === 1) {
		return Array.from({ length: sampleCount }, () => [normalized[0][0], normalized[0][1]]);
	}

	const { segments, totalLength } = buildClosedPathSegments(normalized);
	if (!segments.length || totalLength <= 0) return [];

	const result = [];
	for (let index = 0; index < sampleCount; index++) {
		const targetDistance = (totalLength * index) / sampleCount;
		let segment = segments[segments.length - 1];
		for (const candidate of segments) {
			if (targetDistance < candidate.startDistance + candidate.length) {
				segment = candidate;
				break;
			}
		}
		const t = segment.length <= 0 ? 0 : (targetDistance - segment.startDistance) / segment.length;
		result.push([
			segment.start[0] + ((segment.end[0] - segment.start[0]) * t),
			segment.start[1] + ((segment.end[1] - segment.start[1]) * t),
		]);
	}

	return result;
}

function resampleClosedPath(points, sampleCount) {
	return sampleClosedPath(points, sampleCount);
}

function smoothClosedPath(points, passes = 1) {
	let current = normalizeClosedPoints(points);
	for (let pass = 0; pass < passes; pass++) {
		current = current.map((point, index, array) => {
			const prev = array[(index - 1 + array.length) % array.length];
			const next = array[(index + 1) % array.length];
			return [
				(prev[0] + (point[0] * 2) + next[0]) / 4,
				(prev[1] + (point[1] * 2) + next[1]) / 4,
			];
		});
	}
	return current;
}

module.exports = {
	DEFAULT_EPSILON,
	clonePointPath,
	normalizeClosedPoints,
	segmentLength,
	buildClosedPathSegments,
	getPathLength,
	getSignedArea,
	isClosedLoop,
	pointOnSegment,
	segmentIntersection,
	listSelfIntersections,
	countSelfIntersections,
	countProperSelfIntersections,
	sampleClosedPath,
	resampleClosedPath,
	smoothClosedPath,
};
