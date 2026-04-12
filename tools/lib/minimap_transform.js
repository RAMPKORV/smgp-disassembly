'use strict';

const { MINIMAP_PANEL_TILES_H, MINIMAP_PANEL_TILES_W, MINIMAP_TILE_SIZE_PX } = require('./minimap_layout');
const { cyclicDistance, rotateClosedPoints } = require('./path_utils');
const { getBounds, sampleClosedPath } = require('./minimap_analysis');

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
	for (let i = 0; i < expected.length; i++) absDiff += Math.abs(expectedAbs[i] - Math.abs(shiftedObserved[i]));
	return { signMatchPercent, bestCorr, absDiff };
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
		if (!best || candidate.score.signMatchPercent > best.score.signMatchPercent || (candidate.score.signMatchPercent === best.score.signMatchPercent && candidate.score.absDiff < best.score.absDiff)) best = candidate;
	}
	return best || { points, score: scoreCurveAgreement(track, points), name: 'identity' };
}

function comparePreviewCandidates(a, b) {
	if (a.tile_budget_ok !== b.tile_budget_ok) return a.tile_budget_ok ? -1 : 1;
	const aGoal = a.self_intersections <= 1;
	const bGoal = b.self_intersections <= 1;
	if (aGoal !== bGoal) return aGoal ? -1 : 1;
	if (a.self_intersections !== b.self_intersections) return a.self_intersections - b.self_intersections;
	if (a.transform.score.signMatchPercent !== b.transform.score.signMatchPercent) return b.transform.score.signMatchPercent - a.transform.score.signMatchPercent;
	if (a.branch_pixel_count !== b.branch_pixel_count) return a.branch_pixel_count - b.branch_pixel_count;
	if (a.lower_tail_clearance !== b.lower_tail_clearance) return b.lower_tail_clearance - a.lower_tail_clearance;
	return 0;
}

function countUsedPreviewCells(previewPixels, width, height) {
	let used = 0;
	for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
		for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
			let hit = false;
			for (let y = 0; y < MINIMAP_TILE_SIZE_PX && !hit; y++) {
				for (let x = 0; x < MINIMAP_TILE_SIZE_PX; x++) {
					const px = tileX * MINIMAP_TILE_SIZE_PX + x;
					const py = tileY * MINIMAP_TILE_SIZE_PX + y;
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
		if (!bestScore || score.signMatchPercent > bestScore.signMatchPercent || (score.signMatchPercent === bestScore.signMatchPercent && score.absDiff < bestScore.absDiff)) {
			bestPoints = rotated;
			bestScore = score;
		}
	}
	return bestPoints;
}

function countPreviewTilesFromPixels(preview, width, height) {
	let count = 0;
	for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
		for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
			let used = false;
			for (let y = 0; y < MINIMAP_TILE_SIZE_PX && !used; y++) {
				for (let x = 0; x < MINIMAP_TILE_SIZE_PX; x++) {
					const px = tileX * MINIMAP_TILE_SIZE_PX + x;
					const py = tileY * MINIMAP_TILE_SIZE_PX + y;
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
	for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
		for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
			const rows = [];
			let used = false;
			for (let y = 0; y < MINIMAP_TILE_SIZE_PX; y++) {
				const row = [];
				for (let x = 0; x < MINIMAP_TILE_SIZE_PX; x++) {
					const px = tileX * MINIMAP_TILE_SIZE_PX + x;
					const py = tileY * MINIMAP_TILE_SIZE_PX + y;
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

module.exports = {
	normalizeAngleDelta,
	buildCurveTurnProfile,
	buildPathTurnProfile,
	rotateArray,
	pearsonCorrelation,
	scoreCurveAgreement,
	chooseCurveFaithfulTransform,
	comparePreviewCandidates,
	countUsedPreviewCells,
	selectBestRotatedPathForAgreement,
	countPreviewTilesFromPixels,
	countUniquePreviewTilesFromPixels,
	chooseSeamIndex,
};
