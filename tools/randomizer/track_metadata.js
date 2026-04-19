'use strict';

const TRACK_METADATA_FIELDS = Object.freeze({
	assignedArtName: '_assigned_art_name',
	assignedHorizonOverride: '_assigned_horizon_override',
	generatedGeometryState: '_generated_geometry_state',
	generatedMinimapPreview: '_generated_minimap_preview',
	generatedSpecialRoadFeatures: '_generated_special_road_features',
	originalMinimapPos: '_original_minimap_pos',
	preserveOriginalSignCadence: '_preserve_original_sign_cadence',
	topologyReport: '_track_topology_report',
	runtimeSafeRandomized: '_runtime_safe_randomized',
});

function cloneJsonValue(value) {
	if (value === undefined) return undefined;
	return JSON.parse(JSON.stringify(value));
}

function isRuntimeSafeRandomized(track) {
	return track?.[TRACK_METADATA_FIELDS.runtimeSafeRandomized] === true;
}

function setRuntimeSafeRandomized(track, value = true) {
	if (track) track[TRACK_METADATA_FIELDS.runtimeSafeRandomized] = value === true;
	return track;
}

function preservesOriginalSignCadence(track) {
	return track?.[TRACK_METADATA_FIELDS.preserveOriginalSignCadence] !== false;
}

function setPreserveOriginalSignCadence(track, value) {
	if (track) track[TRACK_METADATA_FIELDS.preserveOriginalSignCadence] = value !== false;
	return track;
}

function getAssignedHorizonOverride(track) {
	if (Number.isInteger(track?.[TRACK_METADATA_FIELDS.assignedHorizonOverride])) {
		return track[TRACK_METADATA_FIELDS.assignedHorizonOverride];
	}
	return Number.isInteger(track?.horizon_override) ? track.horizon_override : 0;
}

function setAssignedHorizonOverride(track, value) {
	if (track) track[TRACK_METADATA_FIELDS.assignedHorizonOverride] = Number.isInteger(value) ? value : 0;
	return track;
}

function ensureAssignedHorizonOverride(track) {
	if (!track) return 0;
	if (!Number.isInteger(track[TRACK_METADATA_FIELDS.assignedHorizonOverride])) {
		track[TRACK_METADATA_FIELDS.assignedHorizonOverride] = getAssignedHorizonOverride(track);
	}
	return track[TRACK_METADATA_FIELDS.assignedHorizonOverride];
}

function getOriginalMinimapPos(track) {
	return Array.isArray(track?.[TRACK_METADATA_FIELDS.originalMinimapPos])
		? track[TRACK_METADATA_FIELDS.originalMinimapPos]
		: null;
}

function ensureOriginalMinimapPos(track) {
	if (!track) return null;
	if (!Array.isArray(track[TRACK_METADATA_FIELDS.originalMinimapPos])) {
		track[TRACK_METADATA_FIELDS.originalMinimapPos] = cloneJsonValue(track.minimap_pos || []);
	}
	return track[TRACK_METADATA_FIELDS.originalMinimapPos];
}

function getGeneratedMinimapPreview(track) {
	const preview = track?.[TRACK_METADATA_FIELDS.generatedMinimapPreview];
	return preview && typeof preview === 'object' ? preview : {};
}

function setGeneratedMinimapPreview(track, preview) {
	if (track) track[TRACK_METADATA_FIELDS.generatedMinimapPreview] = preview || {};
	return track ? track[TRACK_METADATA_FIELDS.generatedMinimapPreview] : {};
}

function getGeneratedGeometryState(track) {
	const geometryState = track?.[TRACK_METADATA_FIELDS.generatedGeometryState];
	return geometryState && typeof geometryState === 'object' ? geometryState : null;
}

function setGeneratedGeometryState(track, geometryState) {
	if (track) track[TRACK_METADATA_FIELDS.generatedGeometryState] = geometryState && typeof geometryState === 'object'
		? cloneJsonValue(geometryState)
		: null;
	return getGeneratedGeometryState(track);
}

function getTrackTopologyReport(track) {
	const report = track?.[TRACK_METADATA_FIELDS.topologyReport];
	return report && typeof report === 'object' ? report : null;
}

function setTrackTopologyReport(track, report) {
	if (track) track[TRACK_METADATA_FIELDS.topologyReport] = report && typeof report === 'object'
		? cloneJsonValue(report)
		: null;
	return getTrackTopologyReport(track);
}

function getAssignedArtName(track) {
	if (typeof track?.[TRACK_METADATA_FIELDS.assignedArtName] === 'string' && track[TRACK_METADATA_FIELDS.assignedArtName].length > 0) {
		return track[TRACK_METADATA_FIELDS.assignedArtName];
	}
	return typeof track?.name === 'string' ? track.name : '';
}

function setAssignedArtName(track, value) {
	if (track) track[TRACK_METADATA_FIELDS.assignedArtName] = typeof value === 'string' && value.length > 0
		? value
		: (typeof track.name === 'string' ? track.name : '');
	return track ? track[TRACK_METADATA_FIELDS.assignedArtName] : '';
}

function getGeneratedSpecialRoadFeatures(track) {
	return Array.isArray(track?.[TRACK_METADATA_FIELDS.generatedSpecialRoadFeatures])
		? track[TRACK_METADATA_FIELDS.generatedSpecialRoadFeatures]
		: [];
}

function setGeneratedSpecialRoadFeatures(track, features) {
	if (track) track[TRACK_METADATA_FIELDS.generatedSpecialRoadFeatures] = Array.isArray(features) ? features : [];
	return getGeneratedSpecialRoadFeatures(track);
}

module.exports = {
	TRACK_METADATA_FIELDS,
	cloneJsonValue,
	isRuntimeSafeRandomized,
	setRuntimeSafeRandomized,
	preservesOriginalSignCadence,
	setPreserveOriginalSignCadence,
	getAssignedHorizonOverride,
	setAssignedHorizonOverride,
	ensureAssignedHorizonOverride,
	getOriginalMinimapPos,
	ensureOriginalMinimapPos,
	getGeneratedMinimapPreview,
	setGeneratedMinimapPreview,
	getGeneratedGeometryState,
	setGeneratedGeometryState,
	getTrackTopologyReport,
	setTrackTopologyReport,
	getAssignedArtName,
	setAssignedArtName,
	getGeneratedSpecialRoadFeatures,
	setGeneratedSpecialRoadFeatures,
};
