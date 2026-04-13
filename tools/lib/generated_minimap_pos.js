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

	const geometryCenterline = getGeneratedGeometryState(track)?.resampled_centerline;
	if (Array.isArray(geometryCenterline) && geometryCenterline.length > 0) {
		const sampleCount = Array.isArray(track?.minimap_pos) && track.minimap_pos.length > 0
			? track.minimap_pos.length
			: Math.max(1, (track?.track_length || 0) >> 6);
		return buildPairsFromCenterline(geometryCenterline, sampleCount, 0);
	}

	const projectionPreview = runtimeProjection && Array.isArray(runtimeProjection.centerline_points)
		? runtimeProjection
		: null;
	const preview = projectionPreview
		? projectionPreview
		: require('./minimap_render').buildGeneratedMinimapPreview(track);
	let centerline = Array.isArray((projectionPreview || preview).centerline_points)
		? (projectionPreview || preview).centerline_points.map(([x, y]) => [x, y])
		: [];

	if (!centerline.length) {
		return generateMinimapPairsFromTrack(track).pairs;
	}

	const sampleCount = Array.isArray(track?.minimap_pos) && track.minimap_pos.length > 0
		? track.minimap_pos.length
		: Math.max(1, (track?.track_length || 0) >> 6);

	return buildPairsFromCenterline(centerline, sampleCount, (projectionPreview || preview).start_index);
}

module.exports = {
	buildGeneratedMinimapPosPairs,
	buildPairsFromCenterline,
	clampSignedByte,
};
