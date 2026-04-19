'use strict';

const path = require('path');

const { readJson } = require('../lib/json');
const { REPO_ROOT } = require('../lib/rom');
const { requireTracksDataShape, getTracks } = require('../randomizer/track_model');
const { randomizeTracks } = require('../randomizer/track_randomizer');

const TRACKS_JSON_PATH = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');
const TEAMS_JSON_PATH = path.join(REPO_ROOT, 'tools', 'data', 'teams.json');
const CHAMPIONSHIP_JSON_PATH = path.join(REPO_ROOT, 'tools', 'data', 'championship.json');

let cachedTracksJson = null;
let cachedTeamsJson = null;
let cachedChampionshipJson = null;
const randomizedTracksDataCache = new Map();

function deepCopy(value) {
	return JSON.parse(JSON.stringify(value));
}

function clonePointPath(points) {
	if (!Array.isArray(points)) return [];
	return points.map(point => [Number(point[0]), Number(point[1])]);
}

function makeGeometryState(points, topology = {}) {
	return {
		resampled_centerline: clonePointPath(points),
		topology: deepCopy(topology),
	};
}

function getCurveDirection(curveByte) {
	if (curveByte >= 0x41 && curveByte <= 0x6F) return 1;
	if (curveByte >= 0x01 && curveByte <= 0x2F) return -1;
	return 0;
}

function getCurveSharpness(curveByte) {
	return curveByte & 0x3F;
}

function cyclicTrackDistance(a, b, trackLength) {
	const diff = Math.abs(a - b);
	if (!Number.isInteger(trackLength) || trackLength <= 0) return diff;
	return Math.min(diff, trackLength - diff);
}

function hasError(errors, fieldFragment) {
	return errors.some(error => error.field && error.field.includes(fieldFragment));
}

function hasMessage(errors, messageFragment) {
	return errors.some(error => error.message && error.message.includes(messageFragment));
}

function makeValidTrack(trackLength = 4096) {
	const steps = trackLength / 4;
	const minimapCount = trackLength >> 6;

	return {
		name: 'Test Track',
		slug: 'test_track',
		index: 0,
		track_length: trackLength,
		slope_initial_bg_disp: 0,
		curve_rle_segments: [
			{ type: 'straight', length: steps, curve_byte: 0 },
			{ type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
		],
		slope_rle_segments: [
			{ type: 'flat', length: steps, slope_byte: 0, bg_vert_disp: 0 },
			{ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
		],
		phys_slope_rle_segments: [
			{ type: 'segment', length: steps, phys_byte: 0 },
			{ type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] },
		],
		sign_data: [
			{ distance: 500, count: 3, sign_id: 28 },
		],
		sign_tileset: [
			{ distance: 0, tileset_offset: 8 },
		],
		minimap_pos: Array.from({ length: minimapCount }, (_, index) => [index % 80, (index * 3) % 80]),
	};
}

function loadTracksJson() {
	if (cachedTracksJson === null) cachedTracksJson = readJson(TRACKS_JSON_PATH);
	return deepCopy(cachedTracksJson);
}

function loadTeamsJson() {
	if (cachedTeamsJson === null) cachedTeamsJson = readJson(TEAMS_JSON_PATH);
	return deepCopy(cachedTeamsJson);
}

function loadChampionshipJson() {
	if (cachedChampionshipJson === null) cachedChampionshipJson = readJson(CHAMPIONSHIP_JSON_PATH);
	return deepCopy(cachedChampionshipJson);
}

function buildTrackSlugsCacheKey(trackSlugs) {
	if (trackSlugs === null) return '*';
	return Array.from(trackSlugs).sort().join(',');
}

function getRandomizedTracksData(masterSeed, trackSlugs = null, verbose = false) {
	const cacheKey = `${masterSeed}::${buildTrackSlugsCacheKey(trackSlugs)}`;
	if (randomizedTracksDataCache.has(cacheKey)) return randomizedTracksDataCache.get(cacheKey);
	const tracksData = requireTracksDataShape(loadTracksJson());
	randomizeTracks(tracksData, masterSeed, trackSlugs, verbose);
	randomizedTracksDataCache.set(cacheKey, tracksData);
	return tracksData;
}

module.exports = {
	TRACKS_JSON_PATH,
	TEAMS_JSON_PATH,
	CHAMPIONSHIP_JSON_PATH,
	deepCopy,
	clonePointPath,
	makeGeometryState,
	getCurveDirection,
	getCurveSharpness,
	cyclicTrackDistance,
	hasError,
	hasMessage,
	makeValidTrack,
	loadTracksJson,
	loadTeamsJson,
	loadChampionshipJson,
	getRandomizedTracksData,
};
