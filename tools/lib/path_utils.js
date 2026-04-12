'use strict';

function rotateClosedPoints(points, startIndex) {
	if (!Array.isArray(points) || points.length === 0) return [];
	const offset = ((startIndex % points.length) + points.length) % points.length;
	return points.slice(offset).concat(points.slice(0, offset));
}

function cyclicDistance(a, b, count) {
	const diff = Math.abs(a - b);
	if (!Number.isInteger(count) || count <= 0) return diff;
	return Math.min(diff, count - diff);
}

function countSelfIntersections(points, minIndexGap = 0) {
	if (!Array.isArray(points) || points.length < 4) return 0;
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

	let count = 0;
	for (let i = 0; i < points.length; i++) {
		const a = points[i];
		const b = points[(i + 1) % points.length];
		for (let j = i + 1; j < points.length; j++) {
			if (cyclicDistance(i, j, points.length) <= minIndexGap) continue;
			if (((i + 1) % points.length) === j) continue;
			if (((j + 1) % points.length) === i) continue;
			const c = points[j];
			const d = points[(j + 1) % points.length];
			if (intersects(a, b, c, d)) count += 1;
		}
	}
	return count;
}

module.exports = {
	rotateClosedPoints,
	cyclicDistance,
	countSelfIntersections,
};
