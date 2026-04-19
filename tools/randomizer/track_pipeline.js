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
	getGeneratedGeometryState,
	getGeneratedMinimapPreview,
	getGeneratedSpecialRoadFeatures,
	setGeneratedGeometryState,
	setGeneratedSpecialRoadFeatures,
	setAssignedHorizonOverride,
	setAssignedArtName,
	setPreserveOriginalSignCadence,
	setRuntimeSafeRandomized,
} = require('./track_metadata');
const { getSignedArea } = require('./track_geometry');

const TRACK_LENGTH_MIN = 4000;
const TRACK_LENGTH_MAX = 7500;
const TRACK_LENGTH_STEP = 64;
const TRACK_GENERATION_ATTEMPTS = 6;

function comparePoints(a, b) {
	if (a[0] !== b[0]) return a[0] - b[0];
	return a[1] - b[1];
}

function cross(o, a, b) {
	return ((a[0] - o[0]) * (b[1] - o[1])) - ((a[1] - o[1]) * (b[0] - o[0]));
}

function buildConvexHull(points) {
	const sorted = (points || []).map(point => [Number(point[0]), Number(point[1])]).sort(comparePoints);
	if (sorted.length <= 1) return sorted;
	const lower = [];
	for (const point of sorted) {
		while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) lower.pop();
		lower.push(point);
	}
	const upper = [];
	for (let index = sorted.length - 1; index >= 0; index--) {
		const point = sorted[index];
		while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) upper.pop();
		upper.push(point);
	}
	return lower.slice(0, -1).concat(upper.slice(0, -1));
}

function loopPerimeter(points) {
	if (!Array.isArray(points) || points.length < 2) return 0;
	let total = 0;
	for (let index = 0; index < points.length; index++) {
		const a = points[index];
		const b = points[(index + 1) % points.length];
		total += Math.hypot(b[0] - a[0], b[1] - a[1]);
	}
	return total;
}

function countReflexVertices(points) {
	if (!Array.isArray(points) || points.length < 4) return 0;
	const orientation = Math.sign(getSignedArea(points));
	if (orientation === 0) return 0;
	let reflexCount = 0;
	for (let index = 0; index < points.length; index++) {
		const prev = points[(index - 1 + points.length) % points.length];
		const cur = points[index];
		const next = points[(index + 1) % points.length];
		const turn = cross(prev, cur, next);
		if (Math.sign(turn) !== 0 && Math.sign(turn) !== orientation) reflexCount += 1;
	}
	return reflexCount;
}

function countTurnRuns(points) {
	if (!Array.isArray(points) || points.length < 4) return 0;
	const signs = [];
	for (let index = 0; index < points.length; index++) {
		const prev = points[(index - 1 + points.length) % points.length];
		const cur = points[index];
		const next = points[(index + 1) % points.length];
		const sign = Math.sign(cross(prev, cur, next));
		if (sign !== 0) signs.push(sign);
	}
	if (signs.length === 0) return 0;
	let runs = 1;
	for (let index = 1; index < signs.length; index++) {
		if (signs[index] !== signs[index - 1]) runs += 1;
	}
	if (signs.length > 1 && signs[0] !== signs[signs.length - 1]) runs -= 1;
	return runs;
}

function buildLoopShapeMetrics(loopPoints) {
	if (!Array.isArray(loopPoints) || loopPoints.length < 3) {
		return {
			reflexVertexCount: 0,
			turnRunCount: 0,
			areaRatioToHull: 1,
			perimeterRatioToHull: 1,
		};
	}
	const hull = buildConvexHull(loopPoints);
	const loopArea = Math.abs(getSignedArea(loopPoints));
	const hullArea = Math.max(loopArea, Math.abs(getSignedArea(hull)));
	const loopPerimeterValue = loopPerimeter(loopPoints);
	const hullPerimeterValue = Math.max(loopPerimeterValue, loopPerimeter(hull));
	return {
		reflexVertexCount: countReflexVertices(loopPoints),
		turnRunCount: countTurnRuns(loopPoints),
		areaRatioToHull: Number((hullArea > 0 ? loopArea / hullArea : 1).toFixed(3)),
		perimeterRatioToHull: Number((hullPerimeterValue > 0 ? loopPerimeterValue / hullPerimeterValue : 1).toFixed(3)),
	};
}

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
		buildMapFirstGeometryState,
		projectCenterlineToCurveRle,
		projectCenterlineToSlopeRle,
		curveBgLoopAligns,
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

	function evaluateGeometryQuality(track) {
		const geometryState = getGeneratedGeometryState(track);
		const diagnostics = geometryState?.generation_diagnostics || {};
		const smoothing = diagnostics.smoothing || {};
		const resampling = diagnostics.resampling || {};
		const topology = geometryState?.topology || {};
		const singleCrossing = topology.single_grade_separated_crossing || null;
		const resampledCenterline = Array.isArray(geometryState?.resampled_centerline) ? geometryState.resampled_centerline : [];
		const loopPoints = Array.isArray(geometryState?.loop_points) ? geometryState.loop_points : [];
		const requestedPasses = smoothing.requested_passes || 0;
		const appliedPasses = smoothing.applied_passes || 0;
		const requestedSampleCount = resampling.requested_sample_count || Math.max(1, (track?.track_length || 0) >> 2);
		const producedSampleCount = resampling.produced_sample_count || resampledCenterline.length;
		const sampleCountError = Math.abs(requestedSampleCount - producedSampleCount);
		const startVerticality = Number.isFinite(resampling.start_verticality) ? resampling.start_verticality : 0;
		const seamAnglePenalty = Math.max(
			Number.isFinite(resampling.incoming_angle_delta) ? resampling.incoming_angle_delta : 180,
			Number.isFinite(resampling.outgoing_angle_delta) ? resampling.outgoing_angle_delta : 180,
		);
		const shapeMetrics = buildLoopShapeMetrics(loopPoints);
		const topologyPenalty = (topology.crossing_count || 0) > 1
			? (topology.crossing_count || 0) * 1000
			: ((topology.crossing_count || 0) === 1 && !singleCrossing ? 1000 : 0);
		const fallbackPenalty = smoothing.used_fallback ? ((requestedPasses - appliedPasses) * 10) : 0;
		const complexityPenalty = Math.max(0, 6 - shapeMetrics.reflexVertexCount) * 8
			+ Math.max(0, 8 - shapeMetrics.turnRunCount) * 4
			+ Math.max(0, shapeMetrics.areaRatioToHull - 0.6) * 40
			- Math.min(10, Math.max(0, shapeMetrics.perimeterRatioToHull - 1) * 30);
		const shapeComplexityPasses = shapeMetrics.reflexVertexCount >= 5
			&& shapeMetrics.turnRunCount >= 6
			&& shapeMetrics.areaRatioToHull <= 0.72;
		const geometryScore = topologyPenalty
			+ (sampleCountError * 20)
			+ seamAnglePenalty
			+ ((1 - Math.min(1, startVerticality)) * 40)
			+ fallbackPenalty
			+ Math.max(0, complexityPenalty);

		return {
			geometryScore: Number(geometryScore.toFixed(3)),
			topologyPenalty,
			crossingCount: topology.crossing_count || 0,
			requestedSampleCount,
			producedSampleCount,
			sampleCountError,
			startVerticality: Number(startVerticality.toFixed(3)),
			seamAnglePenalty: Number(seamAnglePenalty.toFixed(3)),
			usedSmoothingFallback: smoothing.used_fallback === true,
			appliedSmoothingPasses: appliedPasses,
			requestedSmoothingPasses: requestedPasses,
			loopPointCount: loopPoints.length,
			resampledPointCount: resampledCenterline.length,
			reflexVertexCount: shapeMetrics.reflexVertexCount,
			turnRunCount: shapeMetrics.turnRunCount,
			areaRatioToHull: shapeMetrics.areaRatioToHull,
			perimeterRatioToHull: shapeMetrics.perimeterRatioToHull,
			shapeComplexityPasses,
			passes: ((topology.crossing_count || 0) === 0 || ((topology.crossing_count || 0) === 1 && !!singleCrossing))
				&& producedSampleCount === requestedSampleCount
				&& startVerticality >= 0.5
				&& seamAnglePenalty <= 45,
		};
	}

	function compareGeneratedTrackCandidates(a, b) {
		const aFullyPasses = a.geometryQuality.passes && a.constraints.passes;
		const bFullyPasses = b.geometryQuality.passes && b.constraints.passes;
		if (aFullyPasses !== bFullyPasses) return aFullyPasses ? -1 : 1;
		if (a.constraints.passes !== b.constraints.passes) return a.constraints.passes ? -1 : 1;
		if (a.geometryQuality.passes !== b.geometryQuality.passes) return a.geometryQuality.passes ? -1 : 1;
		if (a.constraints.selfIntersections !== b.constraints.selfIntersections) return a.constraints.selfIntersections - b.constraints.selfIntersections;
		if (a.constraints.coverageMatchPercent !== b.constraints.coverageMatchPercent) return b.constraints.coverageMatchPercent - a.constraints.coverageMatchPercent;
		if (a.constraints.signMatchPercent !== b.constraints.signMatchPercent) return b.constraints.signMatchPercent - a.constraints.signMatchPercent;
		if (a.geometryQuality.shapeComplexityPasses !== b.geometryQuality.shapeComplexityPasses) {
			return a.geometryQuality.shapeComplexityPasses ? -1 : 1;
		}
		if (a.geometryQuality.reflexVertexCount !== b.geometryQuality.reflexVertexCount) {
			return b.geometryQuality.reflexVertexCount - a.geometryQuality.reflexVertexCount;
		}
		if (a.geometryQuality.turnRunCount !== b.geometryQuality.turnRunCount) {
			return b.geometryQuality.turnRunCount - a.geometryQuality.turnRunCount;
		}
		if (a.geometryQuality.areaRatioToHull !== b.geometryQuality.areaRatioToHull) {
			return a.geometryQuality.areaRatioToHull - b.geometryQuality.areaRatioToHull;
		}
		if (a.constraints.selfIntersections !== b.constraints.selfIntersections) return a.constraints.selfIntersections - b.constraints.selfIntersections;
		if (a.constraints.startVerticality !== b.constraints.startVerticality) return b.constraints.startVerticality - a.constraints.startVerticality;
		if (a.constraints.tileCount !== b.constraints.tileCount) return b.constraints.tileCount - a.constraints.tileCount;
		if (a.geometryQuality.geometryScore !== b.geometryQuality.geometryScore) return a.geometryQuality.geometryScore - b.geometryQuality.geometryScore;
		return 0;
	}

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
			const geometryState = buildMapFirstGeometryState(candidate, attemptSeed, { trackSlot: trackIdx });
			setGeneratedGeometryState(candidate, geometryState);
			const centerline = Array.isArray(geometryState?.resampled_centerline) ? geometryState.resampled_centerline : [];

			const legacyCurveSegs = generateCurveRle(rngCurves, newLength, candidate);
			const projectedCurve = centerline.length > 2
				? projectCenterlineToCurveRle(centerline, newLength)
				: null;
			const projectedCurveSegs = projectedCurve?.curve_rle_segments
				? normalizeCurveBgDisplacement(projectedCurve.curve_rle_segments, { protectStartupCurve: true, trackLength: newLength })
				: null;
			const curveSegs = projectedCurveSegs && curveBgLoopAligns(projectedCurveSegs, newLength)
				? projectedCurveSegs
				: legacyCurveSegs;
			const normalizedCurveSegs = normalizeCurveBgDisplacement(curveSegs, { protectStartupCurve: true, trackLength: newLength });
			candidate.curve_rle_segments = normalizedCurveSegs;
			candidate.curve_decompressed = decompressCurveSegments(normalizedCurveSegs);
			if (geometryState) {
				geometryState.projections.curve = projectedCurve && curveSegs === projectedCurveSegs ? projectedCurve : null;
				setGeneratedGeometryState(candidate, geometryState);
			}

			const projectedSlope = centerline.length > 2
				? projectCenterlineToSlopeRle(centerline, newLength, {
					crossingInfo: geometryState?.topology?.single_grade_separated_crossing || null,
				})
				: null;
			const legacySlope = projectedSlope ? null : generateSlopeRle(rngSlopes, newLength, normalizedCurveSegs);
			const initBgDisp = projectedSlope?.slope_initial_bg_disp ?? legacySlope[0];
			const slopeSegs = projectedSlope?.slope_rle_segments || legacySlope[1];
			const physSegs = projectedSlope?.phys_slope_rle_segments || generatePhysSlopeRle(rngSlopes, newLength, slopeSegs);
			candidate.slope_initial_bg_disp = initBgDisp;
			candidate.slope_rle_segments = slopeSegs;
			candidate.phys_slope_rle_segments = physSegs;
			if (geometryState) {
				geometryState.projections.slope = projectedSlope || null;
				setGeneratedGeometryState(candidate, geometryState);
			}

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

			const specialRoadFeatures = getGeneratedSpecialRoadFeatures(candidate).length
				? getGeneratedSpecialRoadFeatures(candidate)
				: buildSpecialRoadFeatures(rngSigns, newLength, normalizedCurveSegs);
			const [baseTilesetRecords, tilesetTrailing] = generateSignTileset(rngSigns, newLength, normalizedCurveSegs, candidate);
			const tilesetRecords = enforceWrapSafeTilesetRecords(newLength, applySpecialRoadTilesetRecords(baseTilesetRecords, specialRoadFeatures));
			const baseSignRecords = generateSignData(rngSigns, newLength, normalizedCurveSegs, tilesetRecords, candidate);
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
				geometryQuality: evaluateGeometryQuality(candidate),
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
		for (let attemptIndex = 0; attemptIndex < TRACK_GENERATION_ATTEMPTS; attemptIndex++) {
			const attempt = buildAttempt(attemptIndex);
			if (!bestAttempt || compareGeneratedTrackCandidates(attempt, bestAttempt) < 0) {
				bestAttempt = attempt;
			}
		}

		for (const key of Object.keys(track)) delete track[key];
		Object.assign(track, bestAttempt.candidate);

		if (verbose) {
			process.stdout.write(`    track_length = ${track.track_length} (fixed original budget)\n`);
			process.stdout.write(`    curve: ${bestAttempt.curveCounts.straight} straight + ${bestAttempt.curveCounts.curve} curve segments\n`);
			process.stdout.write(`    slope: ${bestAttempt.curveCounts.slopeFlat} flat + ${bestAttempt.curveCounts.slope} slope segments\n`);
			process.stdout.write(`    signs: ${bestAttempt.curveCounts.signs} records, ${bestAttempt.curveCounts.tilesets} tileset entries\n`);
			process.stdout.write(
				`    geometry: score ${bestAttempt.geometryQuality.geometryScore} / crossings ${bestAttempt.geometryQuality.crossingCount} / ` +
				`resampled ${bestAttempt.geometryQuality.producedSampleCount}/${bestAttempt.geometryQuality.requestedSampleCount} / ` +
				`start ${bestAttempt.geometryQuality.startVerticality} / reflex ${bestAttempt.geometryQuality.reflexVertexCount} / ` +
				`runs ${bestAttempt.geometryQuality.turnRunCount} / hull ${bestAttempt.geometryQuality.areaRatioToHull}\n`
			);
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
		evaluateGeometryQuality,
		compareGeneratedTrackCandidates,
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
