'use strict';

const { getMinimapPreview } = require('./minimap_preview');
const {
	MINIMAP_PANEL_TILES_H,
	MINIMAP_PANEL_TILES_W,
	MINIMAP_TILE_SIZE_PX,
} = require('./minimap_layout');
const {
	PREVIEW_COLLAPSE_SEGMENT_MAX,
	PREVIEW_COVERAGE_TOLERANCE,
	PREVIEW_EDGE_LEFT_MIN,
	PREVIEW_EDGE_PENALTY,
	PREVIEW_EDGE_RIGHT_MARGIN,
	PREVIEW_HORIZONTAL_PENALTY_SCALE,
	PREVIEW_INFLECTION_PENALTY,
	PREVIEW_LOWER_TAIL_EXPAND_FACTOR,
	PREVIEW_LOWER_TAIL_EXPAND_START_RATIO,
	PREVIEW_LOWER_TAIL_MIN_INDEX_GAP,
	PREVIEW_LOWER_TAIL_START_RATIO,
	PREVIEW_SIGN_MATCH_MIN,
	PREVIEW_SIGN_MATCH_SLACK,
	PREVIEW_SPAN_SCORE_SCALE,
	PREVIEW_START_MAX_ABS_TURN_MAX,
	PREVIEW_START_MEAN_ABS_TURN_MAX,
	PREVIEW_START_VERTICALITY_MIN,
	PREVIEW_TOP_PENALTY_RATIO,
	PREVIEW_TOP_PENALTY_SCALE,
	PREVIEW_TURN_SCORE_SCALE,
} = require('./minimap_thresholds');
const {
	countSelfIntersections,
	cyclicDistance,
	rotateClosedPoints,
} = require('./path_utils');
const {
	chooseCurveFaithfulTransform,
	chooseSeamIndex,
	comparePreviewCandidates,
	countPreviewTilesFromPixels,
	countUniquePreviewTilesFromPixels,
	countUsedPreviewCells,
	scoreCurvePathAgreement,
	selectBestRotatedPathForAgreement,
} = require('./minimap_transform');
const {
	rasterizeRoadMask,
	fitStyledPathIntoFrame,
	expandLowerTail,
	computeLowerTailClearance,
	collapseShortestSegment,
	chooseStartIndex,
	styleRoadPreview,
} = require('./minimap_raster');
const { buildMinimapCandidates, chooseBestMinimapCandidate } = require('./minimap_pipeline');
const {
	resolvePreviewSlug,
	dedupeAdjacentPairs,
	getPreviewOccupiedPoints,
	fitCanonicalToPreview,
	densifyPolyline,
	buildDerivedPath,
	fitPathToTarget,
	getBounds,
	sampleClosedPath,
	rasterizePolyline,
	alignClosedSampleSequence,
	scoreRasterAgainstPreview,
} = require('./minimap_analysis');

const previewCache = new WeakMap();
const { smoothClosedPath } = require('../randomizer/track_geometry');
const { getGeneratedGeometryState } = require('../randomizer/track_metadata');

function buildPreviewCacheKey(track) {
	const geometryState = getGeneratedGeometryState(track);
	return JSON.stringify([
		resolvePreviewSlug(track),
		track?.track_length || 0,
		track?.curve_rle_segments || [],
		geometryState?.projections?.slope?.grade_separated_crossing || null,
	]);
}

function smoothClosedPoints(points, passes = 1) {
	return smoothClosedPath(points, passes);
}

function blendClosedPaths(primary, secondary, alpha = 0.35) {
	const count = Math.min(primary.length, secondary.length);
	const result = [];
	for (let i = 0; i < count; i++) {
		result.push([
			primary[i][0] * (1 - alpha) + secondary[i][0] * alpha,
			primary[i][1] * (1 - alpha) + secondary[i][1] * alpha,
		]);
	}
	return result;
}

function buildGeneratedMinimapPreview(track) {
	if (!track) throw new Error('buildGeneratedMinimapPreview requires a track object');
	const cacheKey = buildPreviewCacheKey(track);
	const cached = previewCache.get(track);
	if (cached && cached.key === cacheKey) return cached.value;
	const previewSlug = resolvePreviewSlug(track);
	const preview = getMinimapPreview(previewSlug);
	const stockTileBudget = Array.isArray(preview.tiles) && preview.tiles.length > 0 ? preview.tiles.length : 32;
	const previewPoints = getPreviewOccupiedPoints(preview);
	const previewBounds = getBounds(previewPoints);
	const stockUsedCells = countUsedPreviewCells(preview.pixels, preview.width, preview.height);
	const geometryState = getGeneratedGeometryState(track);
	const geometryCenterline = Array.isArray(geometryState?.resampled_centerline) ? geometryState.resampled_centerline : null;
	if (geometryCenterline && geometryCenterline.length > 0) {
		const crossingProjection = geometryState?.projections?.slope?.grade_separated_crossing || null;
		const underpassSegment = crossingProjection?.lower_branch
			? {
				start_index: crossingProjection.lower_branch.start_index,
				end_index: crossingProjection.lower_branch.end_index,
			}
			: null;
		const basePath = fitStyledPathIntoFrame(geometryCenterline, preview.width, preview.height, 2);
		const fastCandidates = [];

		function pushFastCandidate(path, tag) {
			if (!Array.isArray(path) || path.length < 3) return;
			const startIndex = chooseStartIndex(path, preview.width, preview.height);
			const styled = styleRoadPreview(path, preview.width, preview.height, startIndex, { underpass_segment: underpassSegment });
			const validationScore = scoreCurvePathAgreement(track, path, 0);
			const phasePenalty = Math.abs(validationScore.bestShift || 0);
			const zeroShiftCorr = Number.isFinite(validationScore.zeroShiftCorr) ? validationScore.zeroShiftCorr : -Infinity;
			const phaseGain = (validationScore.bestCorr || 0) - (validationScore.zeroShiftCorr || 0);
			const startVerticality = (() => {
				const prev = path[(startIndex - 1 + path.length) % path.length];
				const cur = path[startIndex];
				const next = path[(startIndex + 1) % path.length];
				const len1 = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]) || 1;
				const len2 = Math.hypot(next[0] - cur[0], next[1] - cur[1]) || 1;
				return (((Math.abs(cur[1] - prev[1]) / len1) + (Math.abs(next[1] - cur[1]) / len2)) / 2);
			})();
			const coverage = scoreRasterAgainstPreview(styled.road_pixels
				.map((value, index) => value ? [index % preview.width, Math.floor(index / preview.width)] : null)
				.filter(Boolean), previewPoints, previewBounds, PREVIEW_COVERAGE_TOLERANCE);
			const tileCount = countUniquePreviewTilesFromPixels(styled.pixels, preview.width, preview.height);
			const lowerTailClearance = computeLowerTailClearance(path, PREVIEW_LOWER_TAIL_START_RATIO, PREVIEW_LOWER_TAIL_MIN_INDEX_GAP);
			fastCandidates.push({
				track,
				factor: 1,
				tag,
				path,
				styled,
				transform: { name: `geometry_${tag}`, score: { signMatchPercent: validationScore.signMatchPercent } },
				start_index: startIndex,
				start_verticality: Number(startVerticality.toFixed(3)),
				validation_sign_match_percent: validationScore.signMatchPercent,
				validation_zero_shift_corr: zeroShiftCorr,
				validation_best_shift: validationScore.bestShift,
				validation_phase_gain: phaseGain,
				validation_phase_penalty: phasePenalty,
				self_intersections: countSelfIntersections(path),
				branch_pixel_count: styled.branch_pixels.length,
				tile_count: tileCount,
				tile_budget_ok: tileCount <= stockTileBudget,
				used_cell_count: countUsedPreviewCells(styled.pixels, preview.width, preview.height),
				coverage_match_percent: coverage.matchPercent,
				lower_tail_clearance: Number.isFinite(lowerTailClearance) ? lowerTailClearance : -Infinity,
			});
		}

		pushFastCandidate(basePath, 'base');
		pushFastCandidate(fitStyledPathIntoFrame(collapseShortestSegment(basePath), preview.width, preview.height, 2), 'collapse');
		pushFastCandidate(fitStyledPathIntoFrame(smoothClosedPoints(basePath, 1), preview.width, preview.height, 2), 'smooth');
		pushFastCandidate(fitStyledPathIntoFrame(expandLowerTail(basePath, PREVIEW_LOWER_TAIL_EXPAND_FACTOR, PREVIEW_LOWER_TAIL_EXPAND_START_RATIO), preview.width, preview.height, 2), 'tail');
		pushFastCandidate(fitStyledPathIntoFrame(expandLowerTail(smoothClosedPoints(basePath, 1), PREVIEW_LOWER_TAIL_EXPAND_FACTOR, PREVIEW_LOWER_TAIL_EXPAND_START_RATIO), preview.width, preview.height, 2), 'tail_smooth');

		const bestCandidate = chooseBestMinimapCandidate(fastCandidates, comparePreviewCandidates);
		const fittedPath = bestCandidate.path;
		const startIndex = bestCandidate.start_index;
		const styled = bestCandidate.styled;
		const bounds = getBounds(fittedPath);
		const result = {
			slug: previewSlug,
			width: preview.width,
			height: preview.height,
			pixels: styled.pixels,
			road_pixels: styled.road_pixels,
			start_marker_pixels: styled.start_marker_pixels,
			centerline_points: fittedPath.map(([x, y]) => [Number(x.toFixed(3)), Number(y.toFixed(3))]),
			start_index: startIndex,
			seam_index: 0,
			bounds,
			transform: bestCandidate.transform.name,
			curve_sign_match_percent: Number((bestCandidate.validation_sign_match_percent ?? 0).toFixed(2)),
			match_percent: 0,
			join_clearance: styled.join_clearance,
			branch_pixel_count: styled.branch_pixels.length,
			crossing_classification: crossingProjection?.classification || null,
			lower_tail_clearance: Number.isFinite(bestCandidate.lower_tail_clearance) ? bestCandidate.lower_tail_clearance : null,
			self_intersections: countSelfIntersections(fittedPath),
			tile_count: countUniquePreviewTilesFromPixels(styled.pixels, preview.width, preview.height),
			start_verticality: bestCandidate.start_verticality,
		};
		previewCache.set(track, { key: cacheKey, value: result });
		return result;
	}
	const candidates = buildMinimapCandidates({
		track,
		preview,
		previewPoints,
		previewBounds,
		stockTileBudget,
		stockUsedCells,
		buildDerivedPath,
		chooseCurveFaithfulTransform,
		styleRoadPreview,
		chooseStartIndex,
		computeLowerTailClearance,
		countUniquePreviewTilesFromPixels,
		countUsedPreviewCells,
		scoreCurvePathAgreement,
		scoreRasterAgainstPreview,
		fitStyledPathIntoFrame,
		expandLowerTail,
		collapseShortestSegment,
		smoothClosedPoints,
		sampleClosedPath,
		dedupeAdjacentPairs,
		selectBestRotatedPathForAgreement,
		blendClosedPaths,
	});
	const bestCandidate = chooseBestMinimapCandidate(candidates, comparePreviewCandidates);
	let styledPath = bestCandidate.path;
	const bestTransform = bestCandidate.transform;
	const bestStyled = bestCandidate.styled;
	const selfIntersections = bestCandidate.self_intersections;
	const lowerTailClearance = bestCandidate.lower_tail_clearance;
	const seamIndex = 0;
	const startIndex = Number.isInteger(bestCandidate.start_index)
		? bestCandidate.start_index
		: chooseStartIndex(styledPath, preview.width, preview.height, bestStyled.road_pixels);
	const bounds = getBounds(styledPath);
	const styled = bestStyled;

	const result = {
		slug: previewSlug,
		width: preview.width,
		height: preview.height,
		pixels: styled.pixels,
		road_pixels: styled.road_pixels,
		start_marker_pixels: styled.start_marker_pixels,
		centerline_points: styledPath.map(([x, y]) => [Number(x.toFixed(3)), Number(y.toFixed(3))]),
		start_index: startIndex,
		seam_index: seamIndex,
		bounds,
		transform: bestTransform.name,
		curve_sign_match_percent: Number((bestCandidate.validation_sign_match_percent ?? bestTransform.score.signMatchPercent).toFixed(2)),
		match_percent: 0,
		join_clearance: styled.join_clearance,
		branch_pixel_count: styled.branch_pixels.length,
		lower_tail_clearance: Number.isFinite(lowerTailClearance) ? lowerTailClearance : null,
		self_intersections: selfIntersections,
		tile_count: bestCandidate.tile_count,
		start_verticality: (() => {
			if (!styledPath.length) return 0;
			const prev = styledPath[(startIndex - 1 + styledPath.length) % styledPath.length];
			const cur = styledPath[startIndex];
			const next = styledPath[(startIndex + 1) % styledPath.length];
			const len1 = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]) || 1;
			const len2 = Math.hypot(next[0] - cur[0], next[1] - cur[1]) || 1;
			return Number((((Math.abs(cur[1] - prev[1]) / len1) + (Math.abs(next[1] - cur[1]) / len2)) / 2).toFixed(3));
		})(),
	};
	previewCache.set(track, { key: cacheKey, value: result });
	return result;
}

module.exports = {
	buildGeneratedMinimapPreview,
	rasterizeRoadMask,
};
