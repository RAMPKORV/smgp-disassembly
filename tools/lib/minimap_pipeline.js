'use strict';

const { getMinimapGuideSource } = require('../randomizer/track_metadata');

const {
	PREVIEW_COVERAGE_TOLERANCE,
	PREVIEW_GUIDE_BLEND_NORMAL,
	PREVIEW_GUIDE_BLEND_UNDERDRAWN,
	PREVIEW_GUIDE_SAMPLE_MIN,
	PREVIEW_LOWER_TAIL_EXPAND_FACTOR,
	PREVIEW_LOWER_TAIL_EXPAND_START_RATIO,
	PREVIEW_LOWER_TAIL_MIN_INDEX_GAP,
	PREVIEW_LOWER_TAIL_START_RATIO,
	PREVIEW_SIGN_MATCH_MIN,
	PREVIEW_SIGN_MATCH_SLACK,
	PREVIEW_UNDERDRAWN_USED_CELL_MIN,
	PREVIEW_UNDERDRAWN_USED_CELL_RATIO,
} = require('./minimap_thresholds');
const { countSelfIntersections } = require('./path_utils');

function buildMinimapCandidates(context) {
	const {
		track,
		preview,
		previewPoints,
		previewBounds,
		stockTileBudget,
		stockUsedCells,
		buildDerivedPath,
		chooseCurveFaithfulTransform,
		styleRoadPreview,
		computeLowerTailClearance,
		countUniquePreviewTilesFromPixels,
		countUsedPreviewCells,
		scoreRasterAgainstPreview,
		fitStyledPathIntoFrame,
		expandLowerTail,
		collapseShortestSegment,
		smoothClosedPoints,
		sampleClosedPath,
		dedupeAdjacentPairs,
		selectBestRotatedPathForAgreement,
		blendClosedPaths,
	} = context;

	const underdrawnUsedCellFloor = Math.max(PREVIEW_UNDERDRAWN_USED_CELL_MIN, Math.floor(stockUsedCells * PREVIEW_UNDERDRAWN_USED_CELL_RATIO));
	const derivedPath = buildDerivedPath(track, { sampleEvery: 1, smoothingPasses: 0, closePath: true });
	const candidateFactors = [1, 0.68];
	const candidates = [];

	function pushCandidate(path, factor, tag) {
		const transform = chooseCurveFaithfulTransform(track, path);
		const candidatePath = transform.points;
		const styled = styleRoadPreview(candidatePath, preview.width, preview.height, 0);
		const lowerTailClearance = computeLowerTailClearance(candidatePath, PREVIEW_LOWER_TAIL_START_RATIO, PREVIEW_LOWER_TAIL_MIN_INDEX_GAP);
		const tileCount = countUniquePreviewTilesFromPixels(styled.pixels, preview.width, preview.height);
		const usedCellCount = countUsedPreviewCells(styled.pixels, preview.width, preview.height);
		const coverage = scoreRasterAgainstPreview(styled.road_pixels
			.map((value, index) => value ? [index % preview.width, Math.floor(index / preview.width)] : null)
			.filter(Boolean), previewPoints, previewBounds, PREVIEW_COVERAGE_TOLERANCE);
		candidates.push({
			factor,
			tag,
			path: candidatePath,
			startIndex: 0,
			styled,
			transform,
			self_intersections: countSelfIntersections(candidatePath),
			branch_pixel_count: styled.branch_pixels.length,
			tile_count: tileCount,
			tile_budget_ok: tileCount <= stockTileBudget,
			used_cell_count: usedCellCount,
			coverage_match_percent: coverage.matchPercent,
			lower_tail_clearance: Number.isFinite(lowerTailClearance) ? lowerTailClearance : -Infinity,
		});
	}

	for (const factor of candidateFactors) {
		const candidateDerived = factor === 1
			? derivedPath
			: buildDerivedPath(track, {
				sampleEvery: 1,
				smoothingPasses: 0,
				closePath: true,
				angleScale: derivedPath.angleScale * factor,
			});
		const fittedPath = fitStyledPathIntoFrame(candidateDerived.points || [], preview.width, preview.height, 2);
		pushCandidate(fittedPath, factor, 'base');
		if (candidates.some(candidate => candidate.self_intersections <= 1)) break;
	}

	if (candidates.length > 0 && candidates.every(candidate => candidate.self_intersections > 1)) {
		const fallbackSource = candidates.slice();
		for (const candidate of fallbackSource) {
			const path = candidate.path;
			const tailExpanded = fitStyledPathIntoFrame(expandLowerTail(path, PREVIEW_LOWER_TAIL_EXPAND_FACTOR, PREVIEW_LOWER_TAIL_EXPAND_START_RATIO), preview.width, preview.height, 2);
			pushCandidate(tailExpanded, candidate.factor, 'tail');
			const collapsed = fitStyledPathIntoFrame(collapseShortestSegment(path), preview.width, preview.height, 2);
			pushCandidate(collapsed, candidate.factor, 'collapse');
			const smoothed = fitStyledPathIntoFrame(smoothClosedPoints(path, 1), preview.width, preview.height, 2);
			pushCandidate(smoothed, candidate.factor, 'smooth');
			if (candidates.some(entry => entry.self_intersections <= 1 && entry.transform.score.signMatchPercent >= PREVIEW_SIGN_MATCH_MIN)) break;
		}

		const worstIntersection = Math.min(...candidates.map(entry => entry.self_intersections));
		const hasUnderdrawnCandidate = candidates.some(entry => entry.used_cell_count < underdrawnUsedCellFloor);
		const guideSource = getMinimapGuideSource(track);
		if ((worstIntersection > 2 || hasUnderdrawnCandidate) && guideSource && guideSource.length >= 8) {
			const sampledGuide = sampleClosedPath(dedupeAdjacentPairs(guideSource), Math.max(PREVIEW_GUIDE_SAMPLE_MIN, fallbackSource[0]?.path?.length || PREVIEW_GUIDE_SAMPLE_MIN));
			let guidePath = fitStyledPathIntoFrame(sampledGuide, preview.width, preview.height, 2);
			guidePath = selectBestRotatedPathForAgreement(track, guidePath);
			const basePath = fallbackSource[0]?.path || guidePath;
			for (const alpha of hasUnderdrawnCandidate ? PREVIEW_GUIDE_BLEND_UNDERDRAWN : PREVIEW_GUIDE_BLEND_NORMAL) {
				const blended = fitStyledPathIntoFrame(blendClosedPaths(basePath, guidePath, alpha), preview.width, preview.height, 2);
				pushCandidate(blended, 1, `guide_blend_${alpha}`);
			}
		}
	}

	return candidates;
}

function chooseBestMinimapCandidate(candidates, comparePreviewCandidates) {
	const baselineCandidate = candidates[0];
	const baselineSignMatch = baselineCandidate ? baselineCandidate.transform.score.signMatchPercent : 0;
	const budgetCandidates = candidates.filter(candidate => candidate.tile_budget_ok && candidate.transform.score.signMatchPercent >= PREVIEW_SIGN_MATCH_MIN);
	const eligibleCandidates = budgetCandidates.length > 0
		? budgetCandidates
		: candidates.filter(candidate => candidate.transform.score.signMatchPercent >= (baselineSignMatch - PREVIEW_SIGN_MATCH_SLACK));
	eligibleCandidates.sort(comparePreviewCandidates);
	return eligibleCandidates[0] || candidates.sort(comparePreviewCandidates)[0];
}

module.exports = {
	buildMinimapCandidates,
	chooseBestMinimapCandidate,
};
