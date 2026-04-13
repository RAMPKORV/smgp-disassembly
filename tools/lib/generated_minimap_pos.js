'use strict';

const { getGeneratedGeometryState } = require('../randomizer/track_metadata');

function clampSignedByte(value) {
	return Math.max(-128, Math.min(127, Math.round(value)));
}

function getRuntimeProjection(track) {
	return getGeneratedGeometryState(track)?.projections?.minimap_runtime || null;
}

function buildPairsFromCenterline(centerline, sampleCount, startIndex = 0) {
	const { sampleClosedPath } = require('./minimap_analysis');
	if (!Array.isArray(centerline) || centerline.length === 0) return [];
	const normalizedStartIndex = Number.isInteger(startIndex)
		? (((startIndex % centerline.length) + centerline.length) % centerline.length)
		: 0;
	const rotated = centerline.slice(normalizedStartIndex).concat(centerline.slice(0, normalizedStartIndex));
	const sampled = sampleClosedPath(rotated, sampleCount);
	return sampled.map(([x, y]) => [clampSignedByte(y), clampSignedByte(x)]);
}

function buildGeneratedMinimapPosPairs(track) {
	const { generateMinimapPairsFromTrack } = require('./minimap_analysis');
	const runtimeProjection = getRuntimeProjection(track);

	if (Array.isArray(runtimeProjection?.pairs) && runtimeProjection.pairs.length > 0) {
		return runtimeProjection.pairs.map(([x, y]) => [clampSignedByte(x), clampSignedByte(y)]);
	}

	if (runtimeProjection && Array.isArray(runtimeProjection.centerline_points) && runtimeProjection.centerline_points.length > 0) {
		const sampleCount = Array.isArray(track?.minimap_pos) && track.minimap_pos.length > 0
			? track.minimap_pos.length
			: Math.max(1, (track?.track_length || 0) >> 6);
		return buildPairsFromCenterline(runtimeProjection.centerline_points, sampleCount, runtimeProjection.start_index);
	}

	if (track && Array.isArray(track.minimap_pos)) {
		const preview = require('./minimap_render').buildGeneratedMinimapPreview(track);
		const previewCenterline = Array.isArray(preview?.centerline_points) ? preview.centerline_points : [];
		if (previewCenterline.length > 0) {
			return buildPairsFromCenterline(previewCenterline, track.minimap_pos.length || Math.max(1, (track?.track_length || 0) >> 6), preview.start_index);
		}
	}

	return generateMinimapPairsFromTrack(track).pairs;
}

module.exports = {
	buildGeneratedMinimapPosPairs,
	buildPairsFromCenterline,
	clampSignedByte,
};
