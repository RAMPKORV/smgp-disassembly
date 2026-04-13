'use strict';

function buildTrackSummary(track, options = {}) {
	const includeTrackLength = options.includeTrackLength !== false;
	const includeTrackIndex = options.includeTrackIndex === true;
	const includePreviewSlug = options.previewSlug !== undefined;
	const includeMinimapPointCount = options.minimapPointCount !== undefined;
	const includeRuntimeSampleCount = options.minimapRuntimeSampleCount !== undefined;
	const summary = {
		slug: track.slug,
		name: track.name,
	};
	if (includeTrackIndex) summary.index = track.index;
	if (includeTrackLength) summary.track_length = track.track_length;
	if (includePreviewSlug) summary.preview_slug = options.previewSlug;
	if (includeMinimapPointCount) summary.minimap_point_count = options.minimapPointCount;
	if (includeRuntimeSampleCount) summary.minimap_runtime_sample_count = options.minimapRuntimeSampleCount;
	return summary;
}

function buildPreviewSummary(previewSlug, preview) {
	return {
		preview_slug: previewSlug,
		preview_match_percent: preview.match_percent,
		curve_sign_match_percent: preview.curve_sign_match_percent,
	};
}

function buildGeneratedPairSummary(generated, samplePoints) {
	return {
		transform: generated.transform,
		match_percent: generated.match_percent,
		thickness_aware_match_percent: generated.thickness_aware_match_percent,
		preview_slug: generated.preview_slug,
		preview_match_percent: generated.preview_match_percent,
		road_alignment_mean_distance: generated.road_alignment_mean_distance,
		road_alignment_max_distance: generated.road_alignment_max_distance,
		road_alignment_hit_percent: generated.road_alignment_hit_percent,
		centerline_alignment_mean_distance: generated.centerline_alignment_mean_distance,
		centerline_alignment_max_distance: generated.centerline_alignment_max_distance,
		pairs: generated.pairs,
		sample_count: samplePoints.length,
	};
}

function buildValidationReportEntry(track, metrics, alignment, flags) {
	return {
		track: buildTrackSummary(track),
		metrics,
		alignment,
		topology: metrics.topology,
		flags,
	};
}

function buildTopologySummary(report) {
	if (!report || typeof report !== 'object') return null;
	return {
		crossing_count: report.crossing_count,
		proper_crossing_count: report.proper_crossing_count,
		shared_endpoint_touch_count: report.shared_endpoint_touch_count,
		multiple_crossings: report.multiple_crossings,
		eligible_for_single_crossing_rule: report.eligible_for_single_crossing_rule,
		crossing_approved: report.crossing_approved === true,
		crossing_classification: report.crossing_classification || null,
		crossings: Array.isArray(report.crossings)
			? report.crossings.map(crossing => ({
				segmentA: crossing.segmentA,
				segmentB: crossing.segmentB,
				kind: crossing.kind,
				point: crossing.point,
				proper: crossing.proper,
				sharedEndpoint: crossing.sharedEndpoint,
			}))
			: [],
	};
}


function buildGeneratedMinimapOutput(track, generated, options = {}) {
	return {
		track: buildTrackSummary(track, { includeTrackLength: options.includeTrackLength !== false }),
		generated,
	};
}

function buildMinimapAnalysisSummary(analysis) {
	return {
		track: analysis.track,
		canonical_to_preview: analysis.canonical.preview_space,
		derived_to_preview: analysis.derived_path_preview_space,
		preview_metrics: analysis.metrics,
	};
}

function buildPreviewSpaceFitSummary(fit, sampledPoints, thicknessAware) {
	return {
		transform: fit.name,
		match_percent: fit.matchPercent,
		symmetric_mean_distance: fit.symmetricMean,
		canonical_to_preview_mean: fit.canonicalToPreviewMean,
		canonical_to_preview_max: fit.canonicalToPreviewMax,
		preview_to_canonical_mean: fit.previewToCanonicalMean,
		preview_to_canonical_max: fit.previewToCanonicalMax,
		normalized_error: fit.normalizedError,
		bounds: fit.transformedCanonicalPoints ? undefined : undefined,
		sampled_points: sampledPoints,
		thickness_aware: {
			match_percent: thicknessAware.matchPercent,
			symmetric_mean_distance: thicknessAware.symmetricMean,
			raster_to_preview_mean: thicknessAware.rasterToPreviewMean,
			raster_to_preview_max: thicknessAware.rasterToPreviewMax,
			preview_to_raster_mean: thicknessAware.previewToRasterMean,
			preview_to_raster_max: thicknessAware.previewToRasterMax,
			normalized_error: thicknessAware.normalizedError,
			tolerance: thicknessAware.tolerance,
		},
	};
}

function buildAnalysisMetrics(bestFit, warningThreshold) {
	return {
		transform: bestFit.name,
		match_percent: bestFit.matchPercent,
		warning_threshold: warningThreshold,
		significant_mismatch: bestFit.matchPercent < warningThreshold,
		symmetric_mean_distance: bestFit.symmetricMean,
		preview_to_canonical_mean: bestFit.previewToCanonicalMean,
		preview_to_canonical_max: bestFit.previewToCanonicalMax,
		canonical_to_preview_mean: bestFit.canonicalToPreviewMean,
		canonical_to_preview_max: bestFit.canonicalToPreviewMax,
		normalized_error: bestFit.normalizedError,
	};
}

function buildTrackAnalysisEntry(options) {
	return {
		track: options.track,
		canonical: options.canonical,
		preview: options.preview,
		signs: options.signs,
		derived_path: options.derivedPath,
		derived_path_preview_space: options.derivedPathPreviewSpace,
		metrics: options.metrics,
	};
}

function buildMinimapAnalysisAggregateReport(analyses, options = {}) {
	return {
		generated_at: options.generatedAt,
		track_count: analyses.length,
		average_match_percent: options.averageMatchPercent,
		significant_mismatch_count: options.significantMismatchCount,
		preview_tile_usage_groups: options.previewTileUsageGroups,
		preview_tile_vocabulary: options.previewTileVocabulary,
		tracks: analyses,
	};
}

function buildPreviewUsageTrackSummary(track, previewSlug, preview) {
	return {
		track_index: track.index,
		track_slug: track.slug,
		preview_slug: previewSlug,
		used_local_tile_count: preview.used_local_tile_count,
	};
}

function buildPreviewVocabularyOccurrence(track, previewSlug, tileIndex) {
	return {
		track_index: track.index,
		track_slug: track.slug,
		preview_slug: previewSlug,
		local_tile_index: tileIndex,
	};
}

function buildPreviewVocabularyTrackSummary(track, previewSlug, preview, uniqueTileSignatureCount) {
	return {
		track_index: track.index,
		track_slug: track.slug,
		preview_slug: previewSlug,
		used_local_tile_count: preview.used_local_tile_count,
		unique_tile_signature_count: uniqueTileSignatureCount,
	};
}

function buildGeneratedPreviewSummary(preview) {
	return {
		preview_slug: preview.slug,
		transform: preview.transform,
		match_percent: preview.match_percent,
		preview_match_percent: preview.match_percent,
		thickness_aware_match_percent: preview.match_percent,
		sample_count: 0,
	};
}

module.exports = {
	buildTrackSummary,
	buildPreviewSummary,
	buildGeneratedPairSummary,
	buildValidationReportEntry,
	buildTopologySummary,
	buildGeneratedMinimapOutput,
	buildMinimapAnalysisSummary,
	buildPreviewSpaceFitSummary,
	buildAnalysisMetrics,
	buildTrackAnalysisEntry,
	buildMinimapAnalysisAggregateReport,
	buildPreviewUsageTrackSummary,
	buildPreviewVocabularyOccurrence,
	buildPreviewVocabularyTrackSummary,
	buildGeneratedPreviewSummary,
};
