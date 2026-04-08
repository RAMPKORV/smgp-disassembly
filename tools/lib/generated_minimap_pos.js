'use strict';

const {
	generateMinimapPairsFromTrack,
	loadTracksData,
	TRACKS_JSON,
	sampleClosedPath,
	alignClosedSampleSequence,
} = require('./minimap_analysis');
const { buildGeneratedMinimapPreview } = require('./minimap_render');

let stockTracksBySlugCache = null;

function clampSignedByte(value) {
	return Math.max(-128, Math.min(127, Math.round(value)));
}

function getStockTracksBySlug() {
	if (stockTracksBySlugCache) return stockTracksBySlugCache;
	const tracks = loadTracksData(TRACKS_JSON).tracks || [];
	stockTracksBySlugCache = new Map(tracks.map(track => [track.slug, track]));
	return stockTracksBySlugCache;
}

function getStockTrackFor(track) {
	if (!track) return null;
	const bySlug = getStockTracksBySlug();
	if (bySlug.has(track.slug)) return bySlug.get(track.slug);
	for (const stockTrack of bySlug.values()) {
		if (stockTrack.index === track.index) return stockTrack;
	}
	return null;
}

function reversePreserveFirst(points) {
	if (!Array.isArray(points) || points.length <= 1) return Array.isArray(points) ? points.slice() : [];
	return [points[0]].concat(points.slice(1).reverse());
}

function meanDistance(a, b) {
	const count = Math.min(a.length, b.length);
	if (count <= 0) return Infinity;
	let total = 0;
	for (let i = 0; i < count; i++) {
		const dx = a[i][0] - b[i][0];
		const dy = a[i][1] - b[i][1];
		total += Math.hypot(dx, dy);
	}
	return total / count;
}

function chooseBestFamily(sampled, referencePairs) {
	const families = [
		{ name: 'yx', points: sampled.map(([x, y]) => [y, x]) },
		{ name: 'rev_yx', points: reversePreserveFirst(sampled).map(([x, y]) => [y, x]) },
	];
	let best = families[0];
	let bestScore = Infinity;
	for (const family of families) {
		const aligned = alignClosedSampleSequence(referencePairs, family.points);
		const score = meanDistance(referencePairs, aligned);
		if (score < bestScore) {
			best = family;
			bestScore = score;
		}
	}
	return best.points;
}

function buildGeneratedMinimapPosPairs(track) {
	const preview = buildGeneratedMinimapPreview(track);
	let centerline = Array.isArray(preview.centerline_points)
		? preview.centerline_points.map(([x, y]) => [x, y])
		: [];

	if (!centerline.length) {
		return generateMinimapPairsFromTrack(track).pairs;
	}

	const sampleCount = Array.isArray(track?.minimap_pos) && track.minimap_pos.length > 0
		? track.minimap_pos.length
		: Math.max(1, (track?.track_length || 0) >> 6);

	if (centerline.length) {
		const startIndex = Number.isInteger(preview.start_index)
			? ((preview.start_index % centerline.length) + centerline.length) % centerline.length
			: 0;
		centerline = centerline.slice(startIndex).concat(centerline.slice(0, startIndex));
	}

	const sampled = sampleClosedPath(centerline, sampleCount);
	const stockTrack = getStockTrackFor(track);
	const referencePairs = Array.isArray(stockTrack?.minimap_pos) && stockTrack.minimap_pos.length > 0
		? stockTrack.minimap_pos
		: null;
	const chosen = referencePairs ? chooseBestFamily(sampled, referencePairs) : sampled;
	return chosen.map(([x, y]) => [clampSignedByte(x), clampSignedByte(y)]);
}

module.exports = {
	buildGeneratedMinimapPosPairs,
	clampSignedByte,
};
