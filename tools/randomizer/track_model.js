'use strict';

const { TRACK_METADATA_FIELDS } = require('./track_metadata');

const TRANSIENT_TRACK_FIELDS = Object.freeze([
	TRACK_METADATA_FIELDS.assignedArtName,
	TRACK_METADATA_FIELDS.assignedHorizonOverride,
	TRACK_METADATA_FIELDS.generatedGeometryState,
	TRACK_METADATA_FIELDS.generatedMinimapPreview,
	TRACK_METADATA_FIELDS.generatedSpecialRoadFeatures,
	TRACK_METADATA_FIELDS.originalMinimapPos,
	TRACK_METADATA_FIELDS.preserveOriginalSignCadence,
	TRACK_METADATA_FIELDS.runtimeSafeRandomized,
	TRACK_METADATA_FIELDS.topologyReport,
]);

function requireObject(value, label) {
	if (!value || typeof value !== 'object' || Array.isArray(value)) {
		throw new Error(`${label} must be an object`);
	}
	return value;
}

function requireArray(value, label) {
	if (!Array.isArray(value)) {
		throw new Error(`${label} must be an array`);
	}
	return value;
}

function requireSegmentList(value, label) {
	const list = requireArray(value, label);
	for (let index = 0; index < list.length; index++) {
		const segment = requireObject(list[index], `${label}[${index}]`);
		if (typeof segment.type !== 'string' || segment.type.length === 0) {
			throw new Error(`${label}[${index}].type must be a non-empty string`);
		}
	}
	return list;
}

function requireRecordList(value, label) {
	const list = requireArray(value, label);
	for (let index = 0; index < list.length; index++) {
		requireObject(list[index], `${label}[${index}]`);
	}
	return list;
}

function requirePairList(value, label) {
	const list = requireArray(value, label);
	for (let index = 0; index < list.length; index++) {
		const pair = list[index];
		if (!Array.isArray(pair) || pair.length < 2) {
			throw new Error(`${label}[${index}] must be a pair array`);
		}
	}
	return list;
}

function getTrackCurveSegments(track, label = 'track') {
	requireObject(track, label);
	return requireSegmentList(track.curve_rle_segments, `${label}.curve_rle_segments`);
}

function getTrackMinimapPairs(track, label = 'track') {
	requireObject(track, label);
	return requirePairList(track.minimap_pos, `${label}.minimap_pos`);
}

function getTrackSignData(track, label = 'track') {
	requireObject(track, label);
	return requireRecordList(track.sign_data, `${label}.sign_data`);
}

function getTrackSignTileset(track, label = 'track') {
	requireObject(track, label);
	return requireRecordList(track.sign_tileset, `${label}.sign_tileset`);
}

function getOptionalByteArray(value, label) {
	if (value === undefined || value === null) return [];
	const bytes = requireArray(value, label);
	for (let index = 0; index < bytes.length; index++) {
		if (!Number.isInteger(bytes[index]) || bytes[index] < 0 || bytes[index] > 255) {
			throw new Error(`${label}[${index}] must be a byte value`);
		}
	}
	return bytes;
}

function getTrackSignTilesetTrailing(track, label = 'track') {
	requireObject(track, label);
	return getOptionalByteArray(track.sign_tileset_trailing, `${label}.sign_tileset_trailing`);
}

function getTrackMinimapTrailing(track, label = 'track') {
	requireObject(track, label);
	return getOptionalByteArray(track.minimap_pos_trailing, `${label}.minimap_pos_trailing`);
}

function requireTrackShape(track, label = 'track') {
	requireObject(track, label);
	if (typeof track.slug !== 'string' || track.slug.length === 0) {
		throw new Error(`${label}.slug must be a non-empty string`);
	}
	if (typeof track.name !== 'string' || track.name.length === 0) {
		throw new Error(`${label}.name must be a non-empty string`);
	}
	if (!Number.isInteger(track.index) || track.index < 0) {
		throw new Error(`${label}.index must be a non-negative integer`);
	}
	if (!Number.isInteger(track.track_length) || track.track_length <= 0) {
		throw new Error(`${label}.track_length must be a positive integer`);
	}
	return track;
}

function requireTracksDataShape(tracksData, label = 'tracksData') {
	const data = requireObject(tracksData, label);
	requireArray(data.tracks, `${label}.tracks`);
	for (let index = 0; index < data.tracks.length; index++) {
		requireTrackShape(data.tracks[index], `${label}.tracks[${index}]`);
	}
	return data;
}

function getTracks(tracksData, label = 'tracksData') {
	return requireTracksDataShape(tracksData, label).tracks;
}

function requireInjectableTrackShape(track, label = 'track') {
	requireTrackShape(track, label);
	requireSegmentList(track.curve_rle_segments, `${label}.curve_rle_segments`);
	requireSegmentList(track.slope_rle_segments, `${label}.slope_rle_segments`);
	requireSegmentList(track.phys_slope_rle_segments, `${label}.phys_slope_rle_segments`);
	getTrackSignData(track, label);
	getTrackSignTileset(track, label);
	getTrackMinimapPairs(track, label);
	getTrackSignTilesetTrailing(track, label);
	getTrackMinimapTrailing(track, label);
	return track;
}

function getTrackDisplayName(track) {
	if (track && typeof track.name === 'string' && track.name.length > 0) return track.name;
	if (track && typeof track.slug === 'string' && track.slug.length > 0) return track.slug;
	return '?';
}

function findTrackByIdentifier(tracksData, identifier, label = 'tracksData') {
	const tracks = getTracks(tracksData, label);
	if (typeof identifier === 'number') {
		return tracks.find(track => track.index === identifier) || null;
	}
	if (typeof identifier === 'string') {
		if (/^\d+$/.test(identifier)) {
			return tracks.find(track => track.index === parseInt(identifier, 10)) || null;
		}
		return tracks.find(track => track.slug === identifier || track.name === identifier) || null;
	}
	if (identifier && typeof identifier === 'object') {
		return requireTrackShape(identifier, 'track');
	}
	return null;
}

function getTransientTrackFieldNames() {
	return TRANSIENT_TRACK_FIELDS.slice();
}

function isTransientTrackField(fieldName) {
	return TRANSIENT_TRACK_FIELDS.includes(fieldName);
}

function cloneInjectableTrack(track, label = 'track') {
	requireObject(track, label);
	const clone = {};
	for (const [key, value] of Object.entries(track)) {
		if (isTransientTrackField(key)) continue;
		clone[key] = value === undefined ? undefined : JSON.parse(JSON.stringify(value));
	}
	return clone;
}

module.exports = {
	TRANSIENT_TRACK_FIELDS,
	requireObject,
	requireArray,
	requireSegmentList,
	requireRecordList,
	requirePairList,
	requireTrackShape,
	requireTracksDataShape,
	requireInjectableTrackShape,
	getTrackCurveSegments,
	getTrackSignData,
	getTrackSignTileset,
	getTrackSignTilesetTrailing,
	getTrackMinimapPairs,
	getTrackMinimapTrailing,
	getOptionalByteArray,
	getTracks,
	getTrackDisplayName,
	findTrackByIdentifier,
	getTransientTrackFieldNames,
	isTransientTrackField,
	cloneInjectableTrack,
};
