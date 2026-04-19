'use strict';

const {
	PREVIEW_COLLAPSE_SEGMENT_MAX,
	PREVIEW_EDGE_LEFT_MIN,
	PREVIEW_EDGE_PENALTY,
	PREVIEW_EDGE_RIGHT_MARGIN,
	PREVIEW_HORIZONTAL_PENALTY_SCALE,
	PREVIEW_INFLECTION_PENALTY,
	PREVIEW_SPAN_SCORE_SCALE,
	PREVIEW_START_MAX_ABS_TURN_MAX,
	PREVIEW_START_MEAN_ABS_TURN_MAX,
	PREVIEW_START_VERTICALITY_MIN,
	PREVIEW_TOP_PENALTY_RATIO,
	PREVIEW_TOP_PENALTY_SCALE,
	PREVIEW_TURN_SCORE_SCALE,
} = require('./minimap_thresholds');
const { cyclicDistance } = require('./path_utils');
const { getBounds, rasterizePolyline, sampleClosedPath } = require('./minimap_analysis');

function rasterizeRoadMask(centerlinePoints, width, height, options = {}) {
	const halfWidth = Math.max(1.25, Number(options.halfWidth) || 2.75);
	const sampleCount = Math.max(64, Number(options.sampleCount) || 640);
	const pixels = new Uint8Array(width * height);
	const sampled = sampleClosedPath(centerlinePoints, sampleCount);

	function stamp(x, y, radius) {
		const minX = Math.max(0, Math.floor(x - radius));
		const maxX = Math.min(width - 1, Math.ceil(x + radius));
		const minY = Math.max(0, Math.floor(y - radius));
		const maxY = Math.min(height - 1, Math.ceil(y + radius));
		for (let py = minY; py <= maxY; py++) {
			for (let px = minX; px <= maxX; px++) {
				const dx = px - x;
				const dy = py - y;
				if ((dx * dx) + (dy * dy) > radius * radius) continue;
				pixels[(py * width) + px] = 1;
			}
		}
	}

	for (let i = 0; i < sampled.length; i++) {
		const prev = sampled[(i - 1 + sampled.length) % sampled.length];
		const point = sampled[i];
		const next = sampled[(i + 1) % sampled.length];
		const tx = next[0] - prev[0];
		const ty = next[1] - prev[1];
		const len = Math.hypot(tx, ty) || 1;
		const nx = -ty / len;
		const ny = tx / len;
		for (let offset = -halfWidth; offset <= halfWidth; offset += 0.5) {
			stamp(point[0] + nx * offset, point[1] + ny * offset, 0.9);
		}
	}

	return { width, height, pixels: Array.from(pixels) };
}

function shiftMask(mask, width, height, dx, dy) {
	const shifted = new Uint8Array(width * height);
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			if (!mask[(y * width) + x]) continue;
			const tx = x + dx;
			const ty = y + dy;
			if (tx < 0 || tx >= width || ty < 0 || ty >= height) continue;
			shifted[(ty * width) + tx] = 1;
		}
	}
	return shifted;
}

function dilateMask(mask, width, height, offsets) {
	const dilated = new Uint8Array(width * height);
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			if (!mask[(y * width) + x]) continue;
			for (const [dx, dy] of offsets) {
				const tx = x + dx;
				const ty = y + dy;
				if (tx < 0 || tx >= width || ty < 0 || ty >= height) continue;
				dilated[(ty * width) + tx] = 1;
			}
		}
	}
	return dilated;
}

function subtractMask(mask, subtract) {
	const out = new Uint8Array(mask.length);
	for (let i = 0; i < mask.length; i++) out[i] = mask[i] && !subtract[i] ? 1 : 0;
	return out;
}

function unionMasks(...masks) {
	const out = new Uint8Array(masks[0].length);
	for (let i = 0; i < out.length; i++) {
		for (const mask of masks) {
			if (mask[i]) {
				out[i] = 1;
				break;
			}
		}
	}
	return out;
}

function scaleClosedPoints(points, scaleX, scaleY) {
	const bounds = getBounds(points);
	const centerX = (bounds.minX + bounds.maxX) / 2;
	const centerY = (bounds.minY + bounds.maxY) / 2;
	return points.map(([x, y]) => [centerX + ((x - centerX) * scaleX), centerY + ((y - centerY) * scaleY)]);
}

function offsetClosedPoints(points, dx, dy) {
	return points.map(([x, y]) => [x + dx, y + dy]);
}

function fitStyledPathIntoFrame(points, width, height, margin = 1) {
	if (!Array.isArray(points) || points.length === 0) return [];
	const bounds = getBounds(points);
	const usableWidth = Math.max(1, width - (margin * 2));
	const usableHeight = Math.max(1, height - (margin * 2));
	const targetWidth = usableWidth * 0.82;
	const targetHeight = usableHeight * 0.82;
	const scale = Math.min(targetWidth / Math.max(bounds.width, 1), targetHeight / Math.max(bounds.height, 1), 1);
	const scaled = scaleClosedPoints(points, scale, scale);
	const scaledBounds = getBounds(scaled);
	return offsetClosedPoints(scaled, (margin + ((usableWidth - scaledBounds.width) / 2)) - scaledBounds.minX, (margin + ((usableHeight - scaledBounds.height) / 2)) - scaledBounds.minY);
}

function expandLowerTail(points, factor = 1.22, startRatio = 0.66) {
	if (!Array.isArray(points) || points.length === 0) return [];
	const bounds = getBounds(points);
	const thresholdY = bounds.minY + (bounds.height * startRatio);
	const centerX = bounds.centerX;
	return points.map(([x, y]) => {
		if (y <= thresholdY) return [x, y];
		const t = Math.min(1, (y - thresholdY) / Math.max(1, bounds.maxY - thresholdY));
		const scale = 1 + ((factor - 1) * t);
		return [centerX + ((x - centerX) * scale), y + (t * 0.35)];
	});
}

function computeLowerTailClearance(points, startRatio = 0.66, minIndexGap = 6) {
	if (!Array.isArray(points) || points.length < 8) return Infinity;
	const bounds = getBounds(points);
	const thresholdY = bounds.minY + (bounds.height * startRatio);
	let best = Infinity;
	for (let i = 0; i < points.length; i++) {
		if (points[i][1] <= thresholdY) continue;
		for (let j = i + 1; j < points.length; j++) {
			if (cyclicDistance(i, j, points.length) <= minIndexGap) continue;
			if (points[j][1] <= thresholdY) continue;
			const dist = Math.hypot(points[i][0] - points[j][0], points[i][1] - points[j][1]);
			if (dist < best) best = dist;
		}
	}
	return best;
}

function collapseShortestSegment(points) {
	if (!Array.isArray(points) || points.length < 4) return points ? points.slice() : [];
	let bestIndex = -1;
	let bestLength = Infinity;
	for (let i = 0; i < points.length; i++) {
		const a = points[i];
		const b = points[(i + 1) % points.length];
		const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
		if (length < bestLength) {
			bestLength = length;
			bestIndex = i;
		}
	}
	if (bestIndex < 0 || bestLength > PREVIEW_COLLAPSE_SEGMENT_MAX) return points.slice();
	const out = points.map(point => [point[0], point[1]]);
	const nextIndex = (bestIndex + 1) % out.length;
	const merged = [(out[bestIndex][0] + out[nextIndex][0]) / 2, (out[bestIndex][1] + out[nextIndex][1]) / 2];
	out[bestIndex] = merged;
	out[nextIndex] = merged;
	return out;
}

function drawThickLine(pixels, width, height, x0, y0, x1, y1, value, radius = 0.75) {
	const steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1) * 2;
	for (let step = 0; step <= steps; step++) {
		const t = step / steps;
		const x = x0 + ((x1 - x0) * t);
		const y = y0 + ((y1 - y0) * t);
		const minX = Math.max(0, Math.floor(x - radius));
		const maxX = Math.min(width - 1, Math.ceil(x + radius));
		const minY = Math.max(0, Math.floor(y - radius));
		const maxY = Math.min(height - 1, Math.ceil(y + radius));
		for (let py = minY; py <= maxY; py++) {
			for (let px = minX; px <= maxX; px++) {
				const ddx = px - x;
				const ddy = py - y;
				if ((ddx * ddx) + (ddy * ddy) > radius * radius) continue;
				pixels[(py * width) + px] = value;
			}
		}
	}
}

function erodeMask(mask, width, height) {
	const out = new Uint8Array(width * height);
	for (let y = 1; y < height - 1; y++) {
		for (let x = 1; x < width - 1; x++) {
			let solid = true;
			for (let dy = -1; dy <= 1 && solid; dy++) {
				for (let dx = -1; dx <= 1; dx++) {
					if (!mask[((y + dy) * width) + x + dx]) {
						solid = false;
						break;
					}
				}
			}
			if (solid) out[(y * width) + x] = 1;
		}
	}
	return out;
}

function floodReachable(mask, width, height, seeds) {
	const seen = new Uint8Array(width * height);
	const queue = [];
	for (const [x, y] of seeds) {
		const ix = Math.round(x);
		const iy = Math.round(y);
		if (ix < 0 || iy < 0 || ix >= width || iy >= height) continue;
		const index = (iy * width) + ix;
		if (!mask[index] || seen[index]) continue;
		seen[index] = 1;
		queue.push(index);
	}
	for (let qi = 0; qi < queue.length; qi++) {
		const index = queue[qi];
		const x = index % width;
		const y = (index / width) | 0;
		for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
			const nx = x + dx;
			const ny = y + dy;
			if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
			const nextIndex = (ny * width) + nx;
			if (!mask[nextIndex] || seen[nextIndex]) continue;
			seen[nextIndex] = 1;
			queue.push(nextIndex);
		}
	}
	return seen;
}

function buildDiskSeeds(point, radius = 1.5) {
	const seeds = [];
	for (let dy = -radius; dy <= radius; dy++) {
		for (let dx = -radius; dx <= radius; dx++) {
			if ((dx * dx) + (dy * dy) > radius * radius) continue;
			seeds.push([point[0] + dx, point[1] + dy]);
		}
	}
	return seeds;
}

function computeJoinClearance(mask, width, height, firstPoint, lastPoint) {
	let current = Uint8Array.from(mask);
	let clearance = -1;
	for (let pass = 0; pass <= 2; pass++) {
		const seen = floodReachable(current, width, height, buildDiskSeeds(firstPoint, 1.5));
		let connected = false;
		for (const [x, y] of buildDiskSeeds(lastPoint, 1.5)) {
			const ix = Math.round(x);
			const iy = Math.round(y);
			if (ix < 0 || iy < 0 || ix >= width || iy >= height) continue;
			if (seen[(iy * width) + ix]) {
				connected = true;
				break;
			}
		}
		if (!connected) break;
		clearance = pass;
		current = erodeMask(current, width, height);
	}
	return clearance;
}

function renderStyledPixelsFromRoadMask(fillMask, width, height, centerlinePoints = null, options = {}) {
	const dilated = dilateMask(fillMask, width, height, [[-1, 0], [0, 0], [1, 0], [0, -1], [0, 1]]);
	const outlineMask = subtractMask(dilated, fillMask);
	const rightWideMask = new Uint8Array(width * height);
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			const index = (y * width) + x;
			if (!fillMask[index]) continue;
			let runEnd = x;
			while (runEnd + 1 < width && fillMask[(y * width) + runEnd + 1]) runEnd += 1;
			if (runEnd + 2 < width
				&& outlineMask[(y * width) + runEnd + 1]
				&& !fillMask[(y * width) + runEnd + 2]) {
				rightWideMask[(y * width) + runEnd + 2] = 1;
			}
			x = runEnd;
		}
	}
	const blackMask = unionMasks(outlineMask, rightWideMask);
	const pixels = new Uint8Array(width * height);
	for (let i = 0; i < pixels.length; i++) {
		if (fillMask[i]) {
			pixels[i] = 3;
			continue;
		}
		if (blackMask[i]) pixels[i] = 1;
	}
	if (options.underpass_segment && Array.isArray(centerlinePoints) && centerlinePoints.length > 1) {
		drawUnderpassIndicator(pixels, width, height, centerlinePoints, options.underpass_segment);
	}
	return {
		pixels,
		blackMask,
	};
}

function findBranchPixels(mask, width, height) {
	const branches = [];
	for (let y = 1; y < height - 1; y++) {
		for (let x = 1; x < width - 1; x++) {
			if (!mask[(y * width) + x]) continue;
			let count = 0;
			for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
				if (mask[((y + dy) * width) + x + dx]) count += 1;
			}
			if (count >= 3) branches.push([x, y]);
		}
	}
	return branches;
}

function findHorizontalSpan(mask, width, height, startX, startY) {
	const candidates = [];
	for (let dy = -2; dy <= 2; dy++) {
		const y = startY + dy;
		if (y < 0 || y >= height) continue;
		let hit = -1;
		for (let radius = 0; radius < width; radius++) {
			const left = startX - radius;
			const right = startX + radius;
			if (left >= 0 && mask[(y * width) + left]) {
				hit = left;
				break;
			}
			if (right < width && mask[(y * width) + right]) {
				hit = right;
				break;
			}
		}
		if (hit < 0) continue;
		let left = hit;
		while (left > 0 && mask[(y * width) + left - 1]) left -= 1;
		let right = hit;
		while ((right + 1) < width && mask[(y * width) + right + 1]) right += 1;
		candidates.push({ y, left, right, width: right - left + 1, dy: Math.abs(dy) });
	}
	if (!candidates.length) return null;
	candidates.sort((a, b) => (b.width - a.width) || (a.dy - b.dy));
	return candidates[0];
}

function buildArcIndices(startIndex, endIndex, count) {
	if (!Number.isInteger(count) || count <= 0) return [];
	const result = [];
	let cursor = ((startIndex % count) + count) % count;
	const target = ((endIndex % count) + count) % count;
	for (let guard = 0; guard <= count; guard++) {
		result.push(cursor);
		if (cursor === target) break;
		cursor = (cursor + 1) % count;
	}
	return result;
}

function buildStartMarkerMask(fillMask, width, height, centerlinePoints, startIndex) {
	const markerMask = new Uint8Array(width * height);
	if (!Number.isInteger(startIndex) || !Array.isArray(centerlinePoints) || centerlinePoints.length <= 2) return markerMask;
	const normalizedIndex = (startIndex + centerlinePoints.length) % centerlinePoints.length;
	const point = centerlinePoints[normalizedIndex];
	const prev = centerlinePoints[(normalizedIndex - 1 + centerlinePoints.length) % centerlinePoints.length];
	const next = centerlinePoints[(normalizedIndex + 1) % centerlinePoints.length];
	const span = findHorizontalSpan(fillMask, width, height, Math.round(point[0]), Math.round(point[1]));
	if (span) {
		const lineWidth = Math.min(4, Math.max(1, span.width));
		const startX = span.left + Math.max(0, Math.floor((span.width - lineWidth) / 2));
		const endX = Math.min(span.right, startX + lineWidth - 1);
		for (let x = startX; x <= endX; x++) {
			if (fillMask[(span.y * width) + x]) markerMask[(span.y * width) + x] = 1;
		}
		return markerMask;
	}
	const tx = next[0] - prev[0];
	const ty = next[1] - prev[1];
	const len = Math.hypot(tx, ty) || 1;
	const nx = -ty / len;
	const ny = tx / len;
	drawThickLine(markerMask, width, height, point[0] - (nx * 1.5), point[1] - (ny * 1.5), point[0] + (nx * 1.5), point[1] + (ny * 1.5), 1, 0.1);
	return markerMask;
}

function drawUnderpassIndicator(pixels, width, height, centerlinePoints, underpassSegment) {
	if (!underpassSegment || !Array.isArray(centerlinePoints) || centerlinePoints.length < 2) return;
	const indices = buildArcIndices(underpassSegment.start_index, underpassSegment.end_index, centerlinePoints.length);
	if (indices.length < 2) return;
	for (let i = 0; i < indices.length - 1; i++) {
		const a = centerlinePoints[indices[i]];
		const b = centerlinePoints[indices[i + 1]];
		drawThickLine(pixels, width, height, a[0], a[1], b[0], b[1], 0, 0.22);
	}
}

function chooseStartIndex(points, width, height, fillMask = null) {
	if (!Array.isArray(points) || points.length < 3) return 0;
	const wrapIndex = index => ((index % points.length) + points.length) % points.length;
	const mask = fillMask || rasterizeRoadMask(points, width, height, { halfWidth: 1.22, sampleCount: 720 }).pixels;
	let best = null;
	const step = Math.max(1, Math.floor(points.length / 48));
	for (let index = 0; index < points.length; index += step) {
		const point = points[index];
		const span = findHorizontalSpan(mask, width, height, Math.round(point[0]), Math.round(point[1]));
		if (!span) continue;
		const prev = points[wrapIndex(index - 1)];
		const next = points[wrapIndex(index + 1)];
		const vx1 = point[0] - prev[0];
		const vy1 = point[1] - prev[1];
		const vx2 = next[0] - point[0];
		const vy2 = next[1] - point[1];
		const len1 = Math.hypot(vx1, vy1) || 1;
		const len2 = Math.hypot(vx2, vy2) || 1;
		const dot = ((vx1 * vx2) + (vy1 * vy2)) / (len1 * len2);
		const verticality = (Math.abs(vy1) / len1 + Math.abs(vy2) / len2) / 2;
		let meanAbsTurn = 0;
		let maxAbsTurn = 0;
		let inflectionCount = 0;
		let lastTurnSign = 0;
		let turnSamples = 0;
		for (let offset = -4; offset <= 4; offset++) {
			const prevPoint = points[wrapIndex(index + offset - 1)];
			const curPoint = points[wrapIndex(index + offset)];
			const nextPoint = points[wrapIndex(index + offset + 1)];
			const angle0 = Math.atan2(curPoint[1] - prevPoint[1], curPoint[0] - prevPoint[0]);
			const angle1 = Math.atan2(nextPoint[1] - curPoint[1], nextPoint[0] - curPoint[0]);
			let turn = angle1 - angle0;
			while (turn <= -Math.PI) turn += Math.PI * 2;
			while (turn > Math.PI) turn -= Math.PI * 2;
			const absTurn = Math.abs(turn);
			meanAbsTurn += absTurn;
			maxAbsTurn = Math.max(maxAbsTurn, absTurn);
			if (absTurn >= 0.03) {
				const turnSign = Math.sign(turn);
				if (lastTurnSign !== 0 && turnSign !== 0 && turnSign !== lastTurnSign) inflectionCount += 1;
				lastTurnSign = turnSign || lastTurnSign;
			}
			turnSamples += 1;
		}
		meanAbsTurn /= Math.max(1, turnSamples);
		if (verticality < PREVIEW_START_VERTICALITY_MIN || meanAbsTurn > PREVIEW_START_MEAN_ABS_TURN_MAX || maxAbsTurn > PREVIEW_START_MAX_ABS_TURN_MAX || inflectionCount > 0) continue;
		const curvaturePenalty = (1 - Math.max(-1, Math.min(1, dot))) * 8;
		const topPenalty = point[1] < (height * PREVIEW_TOP_PENALTY_RATIO) ? (height * PREVIEW_TOP_PENALTY_RATIO - point[1]) * PREVIEW_TOP_PENALTY_SCALE : 0;
		const edgePenalty = point[0] < PREVIEW_EDGE_LEFT_MIN || point[0] > (width - PREVIEW_EDGE_RIGHT_MARGIN) ? PREVIEW_EDGE_PENALTY : 0;
		const horizontalPenalty = (1 - verticality) * PREVIEW_HORIZONTAL_PENALTY_SCALE;
		const score = (span.width * PREVIEW_SPAN_SCORE_SCALE) + curvaturePenalty + topPenalty + edgePenalty + horizontalPenalty + (meanAbsTurn * PREVIEW_TURN_SCORE_SCALE) + inflectionCount * PREVIEW_INFLECTION_PENALTY;
		if (!best || score < best.score) best = { index, score };
	}
	return best ? best.index : 0;
}

function styleRoadPreview(centerlinePoints, width, height, startIndex = null, options = {}) {
	const fillMask = Uint8Array.from(rasterizePolyline(centerlinePoints, width, height, { closePath: true, radius: 1.46 }).pixels);
	const firstPoint = centerlinePoints[0];
	const lastPoint = centerlinePoints[centerlinePoints.length - 1];
	const styledPixels = renderStyledPixelsFromRoadMask(fillMask, width, height, centerlinePoints, options);
	const pixels = styledPixels.pixels;
	if (Number.isInteger(startIndex) && centerlinePoints.length > 2) {
		const markerMask = buildStartMarkerMask(fillMask, width, height, centerlinePoints, startIndex);
		for (let i = 0; i < markerMask.length; i++) {
			if (markerMask[i] && fillMask[i]) pixels[i] = 1;
		}
	}
	return {
		pixels: Array.from(pixels),
		road_pixels: Array.from(fillMask),
		start_marker_pixels: Array.from(buildStartMarkerMask(fillMask, width, height, centerlinePoints, startIndex)),
		join_clearance: computeJoinClearance(fillMask, width, height, firstPoint, lastPoint),
		branch_pixels: findBranchPixels(fillMask, width, height),
	};
}

module.exports = {
	rasterizeRoadMask,
	renderStyledPixelsFromRoadMask,
	fitStyledPathIntoFrame,
	expandLowerTail,
	computeLowerTailClearance,
	collapseShortestSegment,
	buildStartMarkerMask,
	chooseStartIndex,
	styleRoadPreview,
	buildArcIndices,
};
