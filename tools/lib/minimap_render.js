'use strict';

const { getMinimapPreview } = require('./minimap_preview');
const {
	resolvePreviewSlug,
	dedupeAdjacentPairs,
	getPreviewOccupiedPoints,
	fitCanonicalToPreview,
	densifyPolyline,
	buildDerivedPath,
	fitPathToTarget,
	getBounds,
	sampleClosedPath,
	rasterizePolyline,
	alignClosedSampleSequence,
	scoreRasterAgainstPreview,
} = require('./minimap_analysis');

const previewCache = new WeakMap();

function buildPreviewCacheKey(track) {
	return JSON.stringify([
		resolvePreviewSlug(track),
		track?.track_length || 0,
		track?.curve_rle_segments || [],
	]);
}

function smoothClosedPoints(points, passes = 1) {
	let current = points.slice();
	for (let pass = 0; pass < passes; pass++) {
		current = current.map((point, index, array) => {
			const prev = array[(index - 1 + array.length) % array.length];
			const next = array[(index + 1) % array.length];
			return [
				(prev[0] + point[0] * 2 + next[0]) / 4,
				(prev[1] + point[1] * 2 + next[1]) / 4,
			];
		});
	}
	return current;
}

function blendClosedPaths(primary, secondary, alpha = 0.35) {
	const count = Math.min(primary.length, secondary.length);
	const result = [];
	for (let i = 0; i < count; i++) {
		result.push([
			primary[i][0] * (1 - alpha) + secondary[i][0] * alpha,
			primary[i][1] * (1 - alpha) + secondary[i][1] * alpha,
		]);
	}
	return result;
}

function normalizeAngleDelta(angle) {
	let value = angle;
	while (value <= -Math.PI) value += Math.PI * 2;
	while (value > Math.PI) value -= Math.PI * 2;
	return value;
}

function buildCurveTurnProfile(track, sampleCount = 128) {
	const bins = Array.from({ length: sampleCount }, () => ({ sum: 0, count: 0 }));
	let step = 0;
	const totalSteps = Math.max(1, (track.track_length || 0) >> 2);
	for (const seg of track.curve_rle_segments || []) {
		if (!seg || seg.type === 'terminator') break;
		const turn = seg.type === 'curve'
			? (((seg.curve_byte >= 0x41 && seg.curve_byte <= 0x6F) ? 1 : -1) * ((1 / ((seg.curve_byte & 0x3F) ** 1.4)) + (4 * (((seg.bg_disp || 0) / Math.max(seg.length || 1, 1)) / 300))))
			: 0;
		for (let i = 0; i < seg.length; i++, step++) {
			const bin = Math.min(sampleCount - 1, Math.floor((step * sampleCount) / totalSteps));
			bins[bin].sum += turn;
			bins[bin].count += 1;
		}
	}
	return bins.map(bin => bin.count > 0 ? bin.sum / bin.count : 0);
}

function buildPathTurnProfile(points, sampleCount = 128) {
	const sampled = sampleClosedPath(points, sampleCount + 2);
	const profile = [];
	for (let i = 1; i <= sampleCount; i++) {
		const prev = sampled[i - 1];
		const cur = sampled[i];
		const next = sampled[i + 1];
		const a0 = Math.atan2(cur[1] - prev[1], cur[0] - prev[0]);
		const a1 = Math.atan2(next[1] - cur[1], next[0] - cur[0]);
		profile.push(normalizeAngleDelta(a1 - a0));
	}
	return profile;
}

function rotateArray(values, shift) {
	if (!Array.isArray(values) || values.length === 0) return [];
	const length = values.length;
	const offset = ((shift % length) + length) % length;
	return values.slice(offset).concat(values.slice(0, offset));
}

function pearsonCorrelation(a, b) {
	const count = Math.min(a.length, b.length);
	if (count <= 1) return 0;
	let sumA = 0;
	let sumB = 0;
	for (let i = 0; i < count; i++) {
		sumA += a[i];
		sumB += b[i];
	}
	const meanA = sumA / count;
	const meanB = sumB / count;
	let num = 0;
	let denA = 0;
	let denB = 0;
	for (let i = 0; i < count; i++) {
		const da = a[i] - meanA;
		const db = b[i] - meanB;
		num += da * db;
		denA += da * da;
		denB += db * db;
	}
	if (denA <= 0 || denB <= 0) return 0;
	return num / Math.sqrt(denA * denB);
}

function scoreCurveAgreement(track, points) {
	const expected = buildCurveTurnProfile(track, 64);
	const observed = buildPathTurnProfile(points, 64);
	const expectedAbs = expected.map(value => Math.abs(value));
	const observedAbs = observed.map(value => Math.abs(value));
	let bestShift = 0;
	let bestCorr = -Infinity;
	for (let shift = 0; shift < expected.length; shift++) {
		const corr = pearsonCorrelation(expectedAbs, rotateArray(observedAbs, shift));
		if (corr > bestCorr) {
			bestCorr = corr;
			bestShift = shift;
		}
	}
	const shiftedObserved = rotateArray(observed, bestShift);
	let activeCount = 0;
	let signMatches = 0;
	for (let i = 0; i < expected.length; i++) {
		if (Math.abs(expected[i]) < 0.02) continue;
		activeCount += 1;
		if (Math.sign(expected[i]) === Math.sign(shiftedObserved[i])) signMatches += 1;
	}
	const signMatchPercent = activeCount > 0 ? (signMatches * 100) / activeCount : 100;
	let absDiff = 0;
	for (let i = 0; i < expected.length; i++) {
		absDiff += Math.abs(expectedAbs[i] - Math.abs(shiftedObserved[i]));
	}
	return {
		signMatchPercent,
		bestCorr,
		absDiff,
	};
}

function chooseCurveFaithfulTransform(track, points) {
	const bounds = getBounds(points);
	const transforms = [
		{ name: 'identity', map(x, y) { return [x, y]; } },
		{ name: 'flipx', map(x, y) { return [bounds.maxX - (x - bounds.minX), y]; } },
		{ name: 'flipy', map(x, y) { return [x, bounds.maxY - (y - bounds.minY)]; } },
		{ name: 'flipxy', map(x, y) { return [bounds.maxX - (x - bounds.minX), bounds.maxY - (y - bounds.minY)]; } },
	];
	let best = null;
	for (const variant of transforms) {
		const transformed = points.map(([x, y]) => variant.map(x, y));
		const score = scoreCurveAgreement(track, transformed);
		const candidate = { points: transformed, score, name: variant.name };
		if (!best
			|| candidate.score.signMatchPercent > best.score.signMatchPercent
			|| (candidate.score.signMatchPercent === best.score.signMatchPercent && candidate.score.absDiff < best.score.absDiff)) {
			best = candidate;
		}
	}
	return best || { points, score: scoreCurveAgreement(track, points), name: 'identity' };
}

function comparePreviewCandidates(a, b) {
	if (a.tile_budget_ok !== b.tile_budget_ok) return a.tile_budget_ok ? -1 : 1;
	const aGoal = a.self_intersections <= 1;
	const bGoal = b.self_intersections <= 1;
	if (aGoal !== bGoal) return aGoal ? -1 : 1;
	if (a.self_intersections !== b.self_intersections) return a.self_intersections - b.self_intersections;
	if (a.transform.score.signMatchPercent !== b.transform.score.signMatchPercent) {
		return b.transform.score.signMatchPercent - a.transform.score.signMatchPercent;
	}
	if (a.branch_pixel_count !== b.branch_pixel_count) return a.branch_pixel_count - b.branch_pixel_count;
	if (a.lower_tail_clearance !== b.lower_tail_clearance) return b.lower_tail_clearance - a.lower_tail_clearance;
	return 0;
}

function countUsedPreviewCells(previewPixels, width, height) {
	let used = 0;
	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			let hit = false;
			for (let y = 0; y < 8 && !hit; y++) {
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
					if ((previewPixels[(py * width) + px] || 0) !== 0) {
						hit = true;
						break;
					}
				}
			}
			if (hit) used += 1;
		}
	}
	return used;
}

function selectBestRotatedPathForAgreement(track, points, sampleCount = 12) {
	if (!Array.isArray(points) || points.length === 0) return points || [];
	let bestPoints = points;
	let bestScore = null;
	const step = Math.max(1, Math.floor(points.length / Math.max(1, sampleCount)));
	for (let index = 0; index < points.length; index += step) {
		const rotated = rotateClosedPoints(points, index);
		const transformed = chooseCurveFaithfulTransform(track, rotated);
		const score = transformed.score;
		if (!bestScore
			|| score.signMatchPercent > bestScore.signMatchPercent
			|| (score.signMatchPercent === bestScore.signMatchPercent && score.absDiff < bestScore.absDiff)) {
			bestPoints = rotated;
			bestScore = score;
		}
	}
	return bestPoints;
}

function countPreviewTilesFromPixels(preview, width, height) {
	let count = 0;
	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			let used = false;
			for (let y = 0; y < 8 && !used; y++) {
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
					if ((preview[(py * width) + px] || 0) !== 0) {
						used = true;
						break;
					}
				}
			}
			if (used) count += 1;
		}
	}
	return count;
}

function countUniquePreviewTilesFromPixels(preview, width, height) {
	const seen = new Set();
	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			const rows = [];
			let used = false;
			for (let y = 0; y < 8; y++) {
				const row = [];
				for (let x = 0; x < 8; x++) {
					const px = tileX * 8 + x;
					const py = tileY * 8 + y;
					const value = preview[(py * width) + px] || 0;
					if (value) used = true;
					row.push(value);
				}
				rows.push(row.join(','));
			}
			if (!used) continue;
			seen.add(rows.join('/'));
		}
	}
	return seen.size;
}

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

	return {
		width,
		height,
		pixels: Array.from(pixels),
	};
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
	for (let i = 0; i < mask.length; i++) {
		out[i] = mask[i] && !subtract[i] ? 1 : 0;
	}
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
	return points.map(([x, y]) => [
		centerX + ((x - centerX) * scaleX),
		centerY + ((y - centerY) * scaleY),
	]);
}

function rotateClosedPoints(points, startIndex) {
	if (!Array.isArray(points) || points.length === 0) return [];
	const offset = ((startIndex % points.length) + points.length) % points.length;
	return points.slice(offset).concat(points.slice(0, offset));
}

function offsetClosedPoints(points, dx, dy) {
	return points.map(([x, y]) => [x + dx, y + dy]);
}

function fitStyledPathIntoFrame(points, width, height, margin = 1) {
	if (!Array.isArray(points) || points.length === 0) return [];
	const bounds = getBounds(points);
	const usableWidth = Math.max(1, width - (margin * 2));
	const usableHeight = Math.max(1, height - (margin * 2));
	const scale = Math.min(
		usableWidth / Math.max(bounds.width, 1),
		usableHeight / Math.max(bounds.height, 1),
		1
	);
	const scaled = scaleClosedPoints(points, scale, scale);
	const scaledBounds = getBounds(scaled);
	return offsetClosedPoints(
		scaled,
		(margin + ((usableWidth - scaledBounds.width) / 2)) - scaledBounds.minX,
		(margin + ((usableHeight - scaledBounds.height) / 2)) - scaledBounds.minY,
	);
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
	if (bestIndex < 0 || bestLength > 2.6) return points.slice();
	const out = points.map(point => [point[0], point[1]]);
	const nextIndex = (bestIndex + 1) % out.length;
	const merged = [
		(out[bestIndex][0] + out[nextIndex][0]) / 2,
		(out[bestIndex][1] + out[nextIndex][1]) / 2,
	];
	out[bestIndex] = merged;
	out[nextIndex] = merged;
	return out;
}

function countSelfIntersections(points) {
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
			if (j === i) continue;
			if (((i + 1) % points.length) === j) continue;
			if (((j + 1) % points.length) === i) continue;
			const c = points[j];
			const d = points[(j + 1) % points.length];
			if (intersects(a, b, c, d)) count += 1;
		}
	}
	return count;
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

function drawMaskLine(mask, width, height, x0, y0, x1, y1, radius = 0.6) {
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
				mask[(py * width) + px] = 1;
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

function findBranchPixels(mask, width, height) {
	const branches = [];
	for (let y = 1; y < height - 1; y++) {
		for (let x = 1; x < width - 1; x++) {
			if (!mask[(y * width) + x]) continue;
			let count = 0;
			for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
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

function chooseStartIndex(points, width, height, fillMask = null) {
	if (!Array.isArray(points) || points.length < 3) return 0;
	const mask = fillMask || rasterizeRoadMask(points, width, height, {
		halfWidth: 1.22,
		sampleCount: 720,
	}).pixels;
	let best = null;
	const step = Math.max(1, Math.floor(points.length / 48));
	for (let index = 0; index < points.length; index += step) {
		const point = points[index];
		const span = findHorizontalSpan(mask, width, height, Math.round(point[0]), Math.round(point[1]));
		if (!span) continue;
		const prev = points[(index - 1 + points.length) % points.length];
		const next = points[(index + 1) % points.length];
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
			const prevPoint = points[(index + offset - 1 + points.length) % points.length];
			const curPoint = points[(index + offset + points.length) % points.length];
			const nextPoint = points[(index + offset + 1 + points.length) % points.length];
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
		if (verticality < 0.72 || meanAbsTurn > 0.14 || maxAbsTurn > 0.24 || inflectionCount > 0) continue;
		const curvaturePenalty = (1 - Math.max(-1, Math.min(1, dot))) * 8;
		const topPenalty = point[1] < (height * 0.28) ? (height * 0.28 - point[1]) * 2.5 : 0;
		const edgePenalty = point[0] < 6 || point[0] > (width - 7) ? 12 : 0;
		const horizontalPenalty = (1 - verticality) * 18;
		const score = (span.width * 2.5) + curvaturePenalty + topPenalty + edgePenalty + horizontalPenalty + (meanAbsTurn * 24) + inflectionCount * 18;
		if (!best || score < best.score) best = { index, score };
	}
	return best ? best.index : 0;
}

function cyclicDistance(a, b, count) {
	const diff = Math.abs(a - b);
	return Math.min(diff, count - diff);
}

function chooseSeamIndex(points) {
	if (!Array.isArray(points) || points.length < 8) return 0;
	let best = null;
	for (let i = 0; i < points.length; i++) {
		const a = points[i];
		const b = points[(i + 1) % points.length];
		const segLen = Math.hypot(b[0] - a[0], b[1] - a[1]);
		const mx = (a[0] + b[0]) / 2;
		const my = (a[1] + b[1]) / 2;
		let clearance = Infinity;
		for (let j = 0; j < points.length; j++) {
			if (cyclicDistance(i, j, points.length) <= 3) continue;
			const p = points[j];
			const dist = Math.hypot(p[0] - mx, p[1] - my);
			if (dist < clearance) clearance = dist;
		}
		const score = (clearance * 5) - (segLen * 3);
		if (!best || score > best.score) best = { index: i, score };
	}
	return best ? best.index : 0;
}

function styleRoadPreview(centerlinePoints, width, height, startIndex = null) {
	const fillMask = Uint8Array.from(rasterizePolyline(centerlinePoints, width, height, {
		closePath: true,
		radius: 1.46,
	}).pixels);
	const firstPoint = centerlinePoints[0];
	const lastPoint = centerlinePoints[centerlinePoints.length - 1];
	const dilated = dilateMask(fillMask, width, height, [
		[-1, 0], [0, 0], [1, 0],
		[0, -1], [0, 1],
	]);
	const outlineMask = subtractMask(dilated, fillMask);
	const rightWideMask = subtractMask(
		unionMasks(
			shiftMask(fillMask, width, height, 1, 0),
			shiftMask(fillMask, width, height, 2, 0)
		),
		dilated
	);
	const blackMask = unionMasks(outlineMask, rightWideMask);
	const pixels = new Uint8Array(width * height);

	for (let i = 0; i < pixels.length; i++) {
		if (fillMask[i]) {
			pixels[i] = 3;
			continue;
		}
		if (blackMask[i]) pixels[i] = 1;
	}

	if (Number.isInteger(startIndex) && centerlinePoints.length > 2) {
		const point = centerlinePoints[(startIndex + centerlinePoints.length) % centerlinePoints.length];
		const prev = centerlinePoints[(startIndex - 1 + centerlinePoints.length) % centerlinePoints.length];
		const next = centerlinePoints[(startIndex + 1 + centerlinePoints.length) % centerlinePoints.length];
		const tx = next[0] - prev[0];
		const ty = next[1] - prev[1];
		const len = Math.hypot(tx, ty) || 1;
		const nx = -ty / len;
		const ny = tx / len;
		const halfLength = 5.5;
		drawThickLine(
			pixels,
			width,
			height,
			point[0] - (nx * halfLength),
			point[1] - (ny * halfLength),
			point[0] + (nx * halfLength),
			point[1] + (ny * halfLength),
			1,
			0.1
		);
	}

	return {
		pixels: Array.from(pixels),
		road_pixels: Array.from(fillMask),
		join_clearance: computeJoinClearance(fillMask, width, height, firstPoint, lastPoint),
		branch_pixels: findBranchPixels(fillMask, width, height),
	};
}

function buildGeneratedMinimapPreview(track) {
	if (!track) throw new Error('buildGeneratedMinimapPreview requires a track object');
	const cacheKey = buildPreviewCacheKey(track);
	const cached = previewCache.get(track);
	if (cached && cached.key === cacheKey) return cached.value;
	const previewSlug = resolvePreviewSlug(track);
	const preview = getMinimapPreview(previewSlug);
	const stockTileBudget = Array.isArray(preview.tiles) && preview.tiles.length > 0 ? preview.tiles.length : 32;
	const previewPoints = getPreviewOccupiedPoints(preview);
	const previewBounds = getBounds(previewPoints);
	const stockUsedCells = countUsedPreviewCells(preview.pixels, preview.width, preview.height);
	const underdrawnUsedCellFloor = Math.max(18, Math.floor(stockUsedCells * 0.72));
	const derivedPath = buildDerivedPath(track, { sampleEvery: 1, smoothingPasses: 0, closePath: true });
	const candidateFactors = [1, 0.68];
	const candidates = [];

	function pushCandidate(path, factor, tag) {
		const transform = chooseCurveFaithfulTransform(track, path);
		const candidatePath = transform.points;
		const styled = styleRoadPreview(candidatePath, preview.width, preview.height, 0);
		const lowerTailClearance = computeLowerTailClearance(candidatePath, 0.66, 6);
		const tileCount = countUniquePreviewTilesFromPixels(styled.pixels, preview.width, preview.height);
		const usedCellCount = countUsedPreviewCells(styled.pixels, preview.width, preview.height);
		const coverage = scoreRasterAgainstPreview(styled.road_pixels
			.map((value, index) => value ? [index % preview.width, Math.floor(index / preview.width)] : null)
			.filter(Boolean), previewPoints, previewBounds, 2.5);
		candidates.push({
			factor,
			tag,
			path: candidatePath,
			startIndex: 0,
			styled,
			transform,
			self_intersections: countSelfIntersections(candidatePath),
			branch_pixel_count: styled.branch_pixels.length,
			tile_count: tileCount,
			tile_budget_ok: tileCount <= stockTileBudget,
			used_cell_count: usedCellCount,
			coverage_match_percent: coverage.matchPercent,
			lower_tail_clearance: Number.isFinite(lowerTailClearance) ? lowerTailClearance : -Infinity,
		});
	}

	for (const factor of candidateFactors) {
		const candidateDerived = factor === 1
			? derivedPath
			: buildDerivedPath(track, {
				sampleEvery: 1,
				smoothingPasses: 0,
				closePath: true,
				angleScale: derivedPath.angleScale * factor,
			});
		const fittedPath = fitStyledPathIntoFrame(candidateDerived.points || [], preview.width, preview.height, 2);
		pushCandidate(fittedPath, factor, 'base');
		if (candidates.some(candidate => candidate.self_intersections <= 1)) {
			break;
		}
	}

	if (candidates.length > 0 && candidates.every(candidate => candidate.self_intersections > 1)) {
		const fallbackSource = candidates.slice();
		for (const candidate of fallbackSource) {
			const path = candidate.path;
			const tailExpanded = fitStyledPathIntoFrame(expandLowerTail(path, 1.18, 0.60), preview.width, preview.height, 2);
			pushCandidate(tailExpanded, candidate.factor, 'tail');
			const collapsed = fitStyledPathIntoFrame(collapseShortestSegment(path), preview.width, preview.height, 2);
			pushCandidate(collapsed, candidate.factor, 'collapse');
			const smoothed = fitStyledPathIntoFrame(smoothClosedPoints(path, 1), preview.width, preview.height, 2);
			pushCandidate(smoothed, candidate.factor, 'smooth');
			if (candidates.some(entry => entry.self_intersections <= 1 && entry.transform.score.signMatchPercent >= 60)) break;
		}

		const worstIntersection = Math.min(...candidates.map(entry => entry.self_intersections));
		const hasUnderdrawnCandidate = candidates.some(entry => entry.used_cell_count < underdrawnUsedCellFloor);
		const guideSource = Array.isArray(track._original_minimap_pos) && track._original_minimap_pos.length > 0
			? track._original_minimap_pos
			: (Array.isArray(track.minimap_pos) && track.minimap_pos.length > 0 ? track.minimap_pos : null);
		if ((worstIntersection > 2 || hasUnderdrawnCandidate) && guideSource && guideSource.length >= 8) {
			const sampledGuide = sampleClosedPath(dedupeAdjacentPairs(guideSource), Math.max(96, fallbackSource[0]?.path?.length || 96));
			let guidePath = fitStyledPathIntoFrame(sampledGuide, preview.width, preview.height, 2);
			guidePath = selectBestRotatedPathForAgreement(track, guidePath);
			const basePath = fallbackSource[0]?.path || guidePath;
			for (const alpha of hasUnderdrawnCandidate ? [0.25, 0.4] : [0.12, 0.2]) {
				const blended = fitStyledPathIntoFrame(blendClosedPaths(basePath, guidePath, alpha), preview.width, preview.height, 2);
				pushCandidate(blended, 1, `guide_blend_${alpha}`);
			}
		}
	}
	const baselineCandidate = candidates[0];
	const baselineSignMatch = baselineCandidate ? baselineCandidate.transform.score.signMatchPercent : 0;
	const budgetCandidates = candidates.filter(candidate => candidate.tile_budget_ok && candidate.transform.score.signMatchPercent >= 60);
	const eligibleCandidates = budgetCandidates.length > 0
		? budgetCandidates
		: candidates.filter(candidate => candidate.transform.score.signMatchPercent >= (baselineSignMatch - 6));
	eligibleCandidates.sort(comparePreviewCandidates);
	const bestCandidate = eligibleCandidates[0] || candidates.sort(comparePreviewCandidates)[0];
	let styledPath = bestCandidate.path;
	const bestTransform = bestCandidate.transform;
	const bestStyled = bestCandidate.styled;
	const selfIntersections = bestCandidate.self_intersections;
	const lowerTailClearance = bestCandidate.lower_tail_clearance;
	const seamIndex = 0;
	const startIndex = chooseStartIndex(styledPath, preview.width, preview.height, bestStyled.road_pixels);
	const bounds = getBounds(styledPath);
	const styled = styleRoadPreview(styledPath, preview.width, preview.height, startIndex);

	const result = {
		slug: previewSlug,
		width: preview.width,
		height: preview.height,
		pixels: styled.pixels,
		road_pixels: styled.road_pixels,
		centerline_points: styledPath.map(([x, y]) => [Number(x.toFixed(3)), Number(y.toFixed(3))]),
		start_index: startIndex,
		seam_index: seamIndex,
		bounds,
		transform: bestTransform.name,
		curve_sign_match_percent: Number(bestTransform.score.signMatchPercent.toFixed(2)),
		match_percent: 0,
		join_clearance: styled.join_clearance,
		branch_pixel_count: styled.branch_pixels.length,
		lower_tail_clearance: Number.isFinite(lowerTailClearance) ? lowerTailClearance : null,
		self_intersections: selfIntersections,
		tile_count: bestCandidate.tile_count,
		start_verticality: (() => {
			if (!styledPath.length) return 0;
			const prev = styledPath[(startIndex - 1 + styledPath.length) % styledPath.length];
			const cur = styledPath[startIndex];
			const next = styledPath[(startIndex + 1) % styledPath.length];
			const len1 = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]) || 1;
			const len2 = Math.hypot(next[0] - cur[0], next[1] - cur[1]) || 1;
			return Number((((Math.abs(cur[1] - prev[1]) / len1) + (Math.abs(next[1] - cur[1]) / len2)) / 2).toFixed(3));
		})(),
	};
	previewCache.set(track, { key: cacheKey, value: result });
	return result;
}

module.exports = {
	buildGeneratedMinimapPreview,
	rasterizeRoadMask,
};
