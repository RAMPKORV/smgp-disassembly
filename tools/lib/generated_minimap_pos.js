'use strict';

const {
	generateMinimapPairsFromTrack,
	sampleClosedPath,
} = require('./minimap_analysis');
const { buildGeneratedMinimapPreview } = require('./minimap_render');

function clampSignedByte(value) {
	return Math.max(-128, Math.min(127, Math.round(value)));
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
	return sampled.map(([x, y]) => [clampSignedByte(y), clampSignedByte(x)]);
}

module.exports = {
	buildGeneratedMinimapPosPairs,
	clampSignedByte,
};
