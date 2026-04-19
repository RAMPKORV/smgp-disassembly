'use strict';

const {
	PREVIEW_COVERAGE_TOLERANCE,
	PREVIEW_LOWER_TAIL_EXPAND_FACTOR,
	PREVIEW_LOWER_TAIL_EXPAND_START_RATIO,
	PREVIEW_LOWER_TAIL_MIN_INDEX_GAP,
	PREVIEW_LOWER_TAIL_START_RATIO,
	PREVIEW_SIGN_MATCH_MIN,
	PREVIEW_SIGN_MATCH_SLACK,
} = require('./minimap_thresholds');
const { countSelfIntersections } = require('./path_utils');

function buildMinimapCandidates(context) {
	const {
		track,
		preview,
		previewPoints,
		previewBounds,
		stockTileBudget,
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
	} = context;

	const derivedPath = buildDerivedPath(track, { sampleEvery: 1, smoothingPasses: 0, closePath: true });
	const candidateFactors = [1, 0.8, 0.68, 0.55, 0.45, 0.35];
	const candidates = [];

	function pushCandidate(path, factor, tag) {
		const transform = chooseCurveFaithfulTransform(track, path);
		const candidatePath = transform.points;
		const startIndex = chooseStartIndex(candidatePath, preview.width, preview.height);
		const styled = styleRoadPreview(candidatePath, preview.width, preview.height, startIndex);
		const lowerTailClearance = computeLowerTailClearance(candidatePath, PREVIEW_LOWER_TAIL_START_RATIO, PREVIEW_LOWER_TAIL_MIN_INDEX_GAP);
		const tileCount = countUniquePreviewTilesFromPixels(styled.pixels, preview.width, preview.height);
		const usedCellCount = countUsedPreviewCells(styled.pixels, preview.width, preview.height);
		const validationScore = scoreCurvePathAgreement(track, candidatePath, 0);
		const phasePenalty = Math.abs(validationScore.bestShift || 0);
		const zeroShiftCorr = Number.isFinite(validationScore.zeroShiftCorr) ? validationScore.zeroShiftCorr : -Infinity;
		const phaseGain = (validationScore.bestCorr || 0) - (validationScore.zeroShiftCorr || 0);
		const startVerticality = (() => {
			if (!candidatePath.length) return 0;
			const prev = candidatePath[(startIndex - 1 + candidatePath.length) % candidatePath.length];
			const cur = candidatePath[startIndex];
			const next = candidatePath[(startIndex + 1) % candidatePath.length];
			const len1 = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]) || 1;
			const len2 = Math.hypot(next[0] - cur[0], next[1] - cur[1]) || 1;
			return (((Math.abs(cur[1] - prev[1]) / len1) + (Math.abs(next[1] - cur[1]) / len2)) / 2);
		})();
		const coverage = scoreRasterAgainstPreview(styled.road_pixels
			.map((value, index) => value ? [index % preview.width, Math.floor(index / preview.width)] : null)
			.filter(Boolean), previewPoints, previewBounds, PREVIEW_COVERAGE_TOLERANCE);
		candidates.push({
			track,
			factor,
			tag,
			path: candidatePath,
			startIndex: 0,
			styled,
			transform,
			start_index: startIndex,
			start_verticality: Number(startVerticality.toFixed(3)),
			validation_sign_match_percent: validationScore.signMatchPercent,
			validation_zero_shift_corr: zeroShiftCorr,
			validation_best_shift: validationScore.bestShift,
			validation_phase_gain: phaseGain,
			validation_phase_penalty: phasePenalty,
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
	}

	const bestBaseSign = candidates.reduce((best, candidate) => Math.max(best, getCandidateSignScore(candidate)), 0);
	if (candidates.length > 0 && (candidates.every(candidate => candidate.self_intersections > 1) || bestBaseSign < PREVIEW_SIGN_MATCH_MIN)) {
		const fallbackSource = candidates.slice().sort((a, b) => {
			const signDiff = getCandidateSignScore(b) - getCandidateSignScore(a);
			if (signDiff !== 0) return signDiff;
			if (a.self_intersections !== b.self_intersections) return a.self_intersections - b.self_intersections;
			return b.coverage_match_percent - a.coverage_match_percent;
		});
		for (const candidate of fallbackSource) {
			const path = candidate.path;
			const tailExpanded = fitStyledPathIntoFrame(expandLowerTail(path, PREVIEW_LOWER_TAIL_EXPAND_FACTOR, PREVIEW_LOWER_TAIL_EXPAND_START_RATIO), preview.width, preview.height, 2);
			pushCandidate(tailExpanded, candidate.factor, 'tail');
			const collapsed = fitStyledPathIntoFrame(collapseShortestSegment(path), preview.width, preview.height, 2);
			pushCandidate(collapsed, candidate.factor, 'collapse');
			const smoothed = fitStyledPathIntoFrame(smoothClosedPoints(path, 1), preview.width, preview.height, 2);
			pushCandidate(smoothed, candidate.factor, 'smooth');
			if (candidates.some(entry => entry.self_intersections <= 1 && getCandidateSignScore(entry) >= PREVIEW_SIGN_MATCH_MIN)) break;
		}

	}

	return candidates;
}

function getCandidateSignScore(candidate) {
	if (!candidate) return 0;
	return Number.isFinite(candidate.validation_sign_match_percent)
		? candidate.validation_sign_match_percent
		: candidate.transform.score.signMatchPercent;
}

function chooseBestMinimapCandidate(candidates, comparePreviewCandidates) {
	const baselineCandidate = candidates[0];
	const baselineSignMatch = getCandidateSignScore(baselineCandidate);
	const budgetCandidates = candidates.filter(candidate => candidate.tile_budget_ok && getCandidateSignScore(candidate) >= PREVIEW_SIGN_MATCH_MIN);
	const eligibleCandidates = budgetCandidates.length > 0
		? budgetCandidates
		: candidates.filter(candidate => getCandidateSignScore(candidate) >= (baselineSignMatch - PREVIEW_SIGN_MATCH_SLACK));
	const selfLimitedCandidates = eligibleCandidates.filter(candidate => candidate.self_intersections <= 1);
	let finalCandidates = selfLimitedCandidates.length > 0 ? selfLimitedCandidates : eligibleCandidates;
	finalCandidates.sort(comparePreviewCandidates);
	return finalCandidates[0] || candidates.sort(comparePreviewCandidates)[0];
}

module.exports = {
	buildMinimapCandidates,
	chooseBestMinimapCandidate,
};
