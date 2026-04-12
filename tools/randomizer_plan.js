'use strict';

const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('./lib/rom');
const { getTracks, requireTracksDataShape } = require('./randomizer/track_model');
const {
	parseSeed,
	FLAG_TRACKS,
	FLAG_TRACK_CONFIG,
	FLAG_TEAMS,
	FLAG_AI,
	FLAG_CHAMPIONSHIP,
	FLAG_SIGNS,
} = require('./randomizer/track_randomizer');

const TRACKS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');

function flagSummary(flags) {
	const names = [];
	if (flags & FLAG_TRACKS) names.push('TRACKS');
	if (flags & FLAG_TRACK_CONFIG) names.push('CONFIG');
	if (flags & FLAG_TEAMS) names.push('TEAMS');
	if (flags & FLAG_AI) names.push('AI');
	if (flags & FLAG_CHAMPIONSHIP) names.push('CHAMPIONSHIP');
	if (flags & FLAG_SIGNS) names.push('SIGNS');
	return names.length > 0 ? names.join(', ') : '(none)';
}

function parseTrackSlugSet(tracksArg) {
	if (!tracksArg) return null;
	return new Set(String(tracksArg).split(/\s+/).filter(Boolean));
}

function buildRandomizePlan(options = {}) {
	const seedStr = options.seedStr || 'SMGP-1-01-12345';
	const [version, flags, seedInt] = parseSeed(seedStr);
	const inputArg = options.inputArg || null;
	const inputPath = inputArg ? path.resolve(REPO_ROOT, inputArg) : TRACKS_JSON;
	const trackSlugs = parseTrackSlugSet(options.tracksArg || null);
	let randomizedTrackCount = null;
	if ((flags & FLAG_TRACKS) && fs.existsSync(inputPath)) {
		try {
			const tracksData = requireTracksDataShape(JSON.parse(fs.readFileSync(inputPath, 'utf8')));
			randomizedTrackCount = getTracks(tracksData)
				.filter(track => trackSlugs === null || trackSlugs.has(track.slug)).length;
		} catch (_) {
			randomizedTrackCount = null;
		}
	}
	return {
		seedStr,
		version,
		flags,
		seedInt,
		flagSummary: flagSummary(flags),
		inputPath,
		trackSlugs,
		randomizedTrackCount,
	};
}

module.exports = {
	TRACKS_JSON,
	flagSummary,
	parseTrackSlugSet,
	buildRandomizePlan,
};
