'use strict';

const {
	XorShift32,
	MOD_TRACK_CURVES,
	MOD_TRACK_SLOPES,
	MOD_TRACK_SIGNS,
	deriveSubseed,
} = require('./randomizer_shared');
const { CHAMPIONSHIP_TRACK_NAMES, randomizeArtConfig } = require('./art_config');
const {
	TRACK_METADATA_FIELDS,
	ensureAssignedHorizonOverride,
	ensureOriginalMinimapPos,
	getAssignedArtName,
	getGeneratedMinimapPreview,
	setAssignedHorizonOverride,
	setAssignedArtName,
	setGeneratedSpecialRoadFeatures,
	setPreserveOriginalSignCadence,
	setRuntimeSafeRandomized,
} = require('./track_metadata');

const TRACK_LENGTH_MIN = 4000;
const TRACK_LENGTH_MAX = 7500;
const TRACK_LENGTH_STEP = 64;

function pickTrackLength(rng, isPrelim = false) {
	if (isPrelim) {
		const raw = rng.randInt(2000, 3500);
		return Math.floor(raw / TRACK_LENGTH_STEP) * TRACK_LENGTH_STEP || TRACK_LENGTH_STEP;
	}
	const raw = rng.randInt(
		Math.floor(TRACK_LENGTH_MIN / TRACK_LENGTH_STEP),
		Math.floor(TRACK_LENGTH_MAX / TRACK_LENGTH_STEP)
	);
	return raw * TRACK_LENGTH_STEP;
}

function makeTrackPipeline(deps) {
	const {
		generateCurveRle,
		normalizeCurveBgDisplacement,
		decompressCurveSegments,
		generateSlopeRle,
		generatePhysSlopeRle,
		buildSpecialRoadFeatures,
		generateSignTileset,
		enforceWrapSafeTilesetRecords,
		applySpecialRoadTilesetRecords,
		generateSignData,
		applySpecialRoadSignRecords,
		generateMinimap,
		evaluateGeneratedPreviewConstraints,
		compareGeneratedPreviewConstraints,
	} = deps;

	function randomizeOneTrack(track, masterSeed, verbose = false) {
		const slug = track.slug || '?';
		const originalLength = track.track_length;
		setPreserveOriginalSignCadence(track, false);
		setRuntimeSafeRandomized(track, true);
		ensureOriginalMinimapPos(track);

		if (verbose) process.stdout.write(`  Randomizing track: ${track.name} (${slug})\n`);

		const trackIdx = track.index || 0;
		ensureAssignedHorizonOverride(track);
		const perTrackSeed = ((masterSeed >>> 0) ^ ((trackIdx * 0x6B5B9C11) >>> 0)) >>> 0;
		const template = JSON.parse(JSON.stringify(track));

		function buildAttempt(attemptIndex) {
			const candidate = JSON.parse(JSON.stringify(template));
			const attemptSeed = (perTrackSeed ^ (((attemptIndex + 1) * 0x45D9F3B) >>> 0)) >>> 0;
			const rngCurves = new XorShift32(deriveSubseed(attemptSeed, MOD_TRACK_CURVES));
			const rngSlopes = new XorShift32(deriveSubseed(attemptSeed, MOD_TRACK_SLOPES));
			const rngSigns = new XorShift32(deriveSubseed(attemptSeed, MOD_TRACK_SIGNS));

			const newLength = originalLength;
			candidate.track_length = newLength;

			const curveSegs = generateCurveRle(rngCurves, newLength, candidate);
			const normalizedCurveSegs = normalizeCurveBgDisplacement(curveSegs, { protectStartupCurve: true, trackLength: newLength });
			candidate.curve_rle_segments = normalizedCurveSegs;
			candidate.curve_decompressed = decompressCurveSegments(normalizedCurveSegs);

			const [initBgDisp, slopeSegs] = generateSlopeRle(rngSlopes, newLength, normalizedCurveSegs);
			const physSegs = generatePhysSlopeRle(rngSlopes, newLength, slopeSegs);
			candidate.slope_initial_bg_disp = initBgDisp;
			candidate.slope_rle_segments = slopeSegs;
			candidate.phys_slope_rle_segments = physSegs;

			const slopeDecomp = [];
			for (const seg of slopeSegs) {
				if (seg.type === 'flat' || seg.type === 'slope') {
					for (let i = 0; i < seg.length; i++) slopeDecomp.push(seg.slope_byte);
				} else if (seg.type === 'terminator') {
					slopeDecomp.push(0xFF);
				}
			}
			candidate.slope_decompressed = slopeDecomp;

			const physDecomp = [];
			for (const seg of physSegs) {
				if (seg.type === 'segment') {
					for (let i = 0; i < seg.length; i++) physDecomp.push(seg.phys_byte);
				}
			}
			candidate.phys_slope_decompressed = physDecomp;

			const specialRoadFeatures = buildSpecialRoadFeatures(rngSigns, newLength, normalizedCurveSegs);
			const [baseTilesetRecords, tilesetTrailing] = generateSignTileset(rngSigns, newLength, normalizedCurveSegs, candidate);
			const tilesetRecords = enforceWrapSafeTilesetRecords(newLength, applySpecialRoadTilesetRecords(baseTilesetRecords, specialRoadFeatures));
			const baseSignRecords = generateSignData(rngSigns, newLength, normalizedCurveSegs, tilesetRecords);
			const signRecords = applySpecialRoadSignRecords(baseSignRecords, specialRoadFeatures);
			candidate.sign_data = signRecords;
			candidate.sign_tileset = tilesetRecords;
			candidate.sign_tileset_trailing = tilesetTrailing;
			setGeneratedSpecialRoadFeatures(candidate, specialRoadFeatures);

			const [minimapPairs, minimapTrailing] = generateMinimap(candidate);
			candidate.minimap_pos = minimapPairs;
			candidate.minimap_pos_trailing = minimapTrailing;

			return {
				candidate,
				constraints: evaluateGeneratedPreviewConstraints(candidate),
				curveCounts: {
					straight: curveSegs.filter(s => s.type === 'straight').length,
					curve: curveSegs.filter(s => s.type === 'curve').length,
					slopeFlat: slopeSegs.filter(s => s.type === 'flat').length,
					slope: slopeSegs.filter(s => s.type === 'slope').length,
					signs: signRecords.length,
					tilesets: tilesetRecords.length,
				},
			};
		}

		let bestAttempt = null;
		for (let attemptIndex = 0; attemptIndex < 2; attemptIndex++) {
			const attempt = buildAttempt(attemptIndex);
			if (!bestAttempt || compareGeneratedPreviewConstraints(attempt.constraints, bestAttempt.constraints) < 0) {
				bestAttempt = attempt;
			}
			if (attempt.constraints.passes) break;
		}

		for (const key of Object.keys(track)) delete track[key];
		Object.assign(track, bestAttempt.candidate);

		if (verbose) {
			process.stdout.write(`    track_length = ${track.track_length} (fixed original budget)\n`);
			process.stdout.write(`    curve: ${bestAttempt.curveCounts.straight} straight + ${bestAttempt.curveCounts.curve} curve segments\n`);
			process.stdout.write(`    slope: ${bestAttempt.curveCounts.slopeFlat} flat + ${bestAttempt.curveCounts.slope} slope segments\n`);
			process.stdout.write(`    signs: ${bestAttempt.curveCounts.signs} records, ${bestAttempt.curveCounts.tilesets} tileset entries\n`);
			const previewInfo = getGeneratedMinimapPreview(track);
			process.stdout.write(
				`    minimap: ${track.minimap_pos.length} pairs (need ${track.track_length >> 6}), ` +
				`canon ${previewInfo.match_percent || 0}% / preview ${previewInfo.preview_match_percent || 0}% / thick ${previewInfo.thickness_aware_match_percent || 0}%\n`
			);
		}

		return track;
	}

	function syncMonacoArcadeWetTrack(tracks, verbose = false) {
		const monacoArcadeMain = tracks.find(track => track.index === 17);
		const monacoArcadeWet = tracks.find(track => track.index === 18);
		if (!monacoArcadeMain || !monacoArcadeWet) return;
		const sharedFields = [
			'track_length', 'curve_rle_segments', 'curve_decompressed',
			'slope_initial_bg_disp', 'slope_rle_segments', 'slope_decompressed',
			'phys_slope_rle_segments', 'phys_slope_decompressed',
			'sign_data', 'sign_tileset', 'sign_tileset_trailing',
			'minimap_pos', 'minimap_pos_trailing', TRACK_METADATA_FIELDS.generatedMinimapPreview,
			TRACK_METADATA_FIELDS.preserveOriginalSignCadence,
		];
		for (const field of sharedFields) {
			const value = monacoArcadeMain[field];
			monacoArcadeWet[field] = (value && typeof value === 'object')
				? JSON.parse(JSON.stringify(value))
				: value;
		}
		if (verbose) process.stdout.write('  Synced Monaco (Arcade Wet) shared track data to Monaco (Arcade Main)\n');
	}

	function assignChampionshipArtMetadata(tracks, masterSeed) {
		const artAssignment = randomizeArtConfig(masterSeed, false);
		for (let slotIdx = 0; slotIdx < CHAMPIONSHIP_TRACK_NAMES.length && slotIdx < tracks.length; slotIdx++) {
			const track = tracks[slotIdx];
			if (!track) continue;
			setAssignedArtName(track, artAssignment[slotIdx]?.art_name || track.name);
			setAssignedHorizonOverride(
				track,
				Number.isInteger(artAssignment[slotIdx]?.horizon_override)
					? artAssignment[slotIdx].horizon_override
					: (Number.isInteger(track.horizon_override) ? track.horizon_override : 0)
			);
			if (!getAssignedArtName(track)) setAssignedArtName(track, track.name);
		}
		return artAssignment;
	}

	function randomizeTracks(tracksData, masterSeed, trackSlugs = null, verbose = false) {
		const tracks = tracksData.tracks;
		assignChampionshipArtMetadata(tracks, masterSeed);
		for (const track of tracks) {
			if (trackSlugs !== null && !trackSlugs.has(track.slug)) continue;
			randomizeOneTrack(track, masterSeed, verbose);
		}
		syncMonacoArcadeWetTrack(tracks, verbose);
		return tracksData;
	}

	return {
		pickTrackLength,
		randomizeOneTrack,
		randomizeTracks,
		assignChampionshipArtMetadata,
		syncMonacoArcadeWetTrack,
	};
}

module.exports = {
	pickTrackLength,
	makeTrackPipeline,
};
