'use strict';

const {
	buildClosedPathSegments: buildTrackGeometryClosedPathSegments,
	sampleClosedPath: sampleTrackGeometryClosedPath,
} = require('../randomizer/track_geometry');

const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('./rom');
const { getMinimapPreview } = require('./minimap_preview');
const {
	buildAnalysisMetrics,
	buildGeneratedPairSummary,
	buildMinimapAnalysisAggregateReport,
	buildPreviewSpaceFitSummary,
	buildPreviewUsageTrackSummary,
	buildPreviewVocabularyOccurrence,
	buildPreviewVocabularyTrackSummary,
	buildTrackAnalysisEntry,
	buildTrackSummary,
} = require('./minimap_result_model');
const {
	findTrackByIdentifier,
	getTrackCurveSegments,
	getTrackMinimapPairs,
	getTrackSignData,
	getTracks,
	requireTrackShape,
	requireTracksDataShape,
} = require('../randomizer/track_model');
const TRACKS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');
const previewPointsCache = new Map();

const PREVIEW_SLUG_BY_TRACK_INDEX = {
  16: 'monaco_prelim',
  17: 'monaco_arcade',
  18: 'monaco_arcade_wet',
};

const PREVIEW_TRANSFORMS = [
	{
		name: 'identity',
		map(x, y) {
			return [x, y];
		},
	},
	{
		name: 'flipx',
		map(x, y, bounds) {
			return [bounds.maxX - (x - bounds.minX), y];
		},
	},
	{
		name: 'flipy',
		map(x, y, bounds) {
			return [x, bounds.maxY - (y - bounds.minY)];
		},
	},
	{
		name: 'flipxy',
		map(x, y, bounds) {
			return [
				bounds.maxX - (x - bounds.minX),
				bounds.maxY - (y - bounds.minY),
			];
		},
	},
];

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function roundTo(value, places = 3) {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function buildLocalTileUsageSignature(preview) {
	const indices = Array.isArray(preview?.used_local_tile_indices)
		? preview.used_local_tile_indices
		: [];
	return indices.join(',');
}

function buildTilePixelSignature(tile) {
	if (!Array.isArray(tile)) return '';
	return tile.map(row => Array.isArray(row) ? row.join('') : '').join('/');
}

function groupPreviewTileUsage(tracksData = null) {
	const data = tracksData || loadTracksData();
	const tracks = getTracks(data);
	const groups = new Map();

	for (const track of tracks) {
		const previewSlug = resolvePreviewSlug(track);
		const preview = getMinimapPreview(previewSlug);
		const signature = buildLocalTileUsageSignature(preview);
		const existing = groups.get(signature);
		const summary = buildPreviewUsageTrackSummary(track, previewSlug, preview);

		if (existing) {
			existing.tracks.push(summary);
			continue;
		}

		groups.set(signature, {
			used_local_tile_indices: preview.used_local_tile_indices,
			used_local_tile_count: preview.used_local_tile_count,
			tracks: [summary],
		});
	}

	return Array.from(groups.values())
		.sort((a, b) => {
			if (b.tracks.length !== a.tracks.length) return b.tracks.length - a.tracks.length;
			if (a.used_local_tile_count !== b.used_local_tile_count) {
				return a.used_local_tile_count - b.used_local_tile_count;
			}
			return a.tracks[0].track_index - b.tracks[0].track_index;
		});
}

function analyzePreviewTileVocabulary(tracksData = null) {
	const data = tracksData || loadTracksData();
	const tracks = getTracks(data);
	const signatureMap = new Map();
	const perTrack = [];

	for (const track of tracks) {
		const previewSlug = resolvePreviewSlug(track);
		const preview = getMinimapPreview(previewSlug);
		const seenInTrack = new Set();

		for (const tileIndex of preview.used_local_tile_indices || []) {
			const tile = preview.tiles?.[tileIndex];
			const signature = buildTilePixelSignature(tile);
			if (!signature) continue;
			seenInTrack.add(signature);

			let entry = signatureMap.get(signature);
			if (!entry) {
				entry = {
					signature,
					occurrences: [],
					preview_slugs: new Set(),
					track_indices: new Set(),
				};
				signatureMap.set(signature, entry);
			}

			entry.occurrences.push(buildPreviewVocabularyOccurrence(track, previewSlug, tileIndex));
			entry.preview_slugs.add(previewSlug);
			entry.track_indices.add(track.index);
		}

		perTrack.push(buildPreviewVocabularyTrackSummary(track, previewSlug, preview, seenInTrack.size));
	}

	const sharedGroups = Array.from(signatureMap.values())
		.map(entry => ({
			signature: entry.signature,
			occurrence_count: entry.occurrences.length,
			preview_slug_count: entry.preview_slugs.size,
			track_count: entry.track_indices.size,
			occurrences: entry.occurrences,
		}))
		.filter(entry => entry.preview_slug_count > 1)
		.sort((a, b) => {
			if (b.preview_slug_count !== a.preview_slug_count) return b.preview_slug_count - a.preview_slug_count;
			if (b.track_count !== a.track_count) return b.track_count - a.track_count;
			return b.occurrence_count - a.occurrence_count;
		});

	const sharedSignatureSet = new Set(sharedGroups.map(entry => entry.signature));
	for (const trackSummary of perTrack) {
		const preview = getMinimapPreview(trackSummary.preview_slug);
		let sharedCount = 0;
		for (const tileIndex of preview.used_local_tile_indices || []) {
			const signature = buildTilePixelSignature(preview.tiles?.[tileIndex]);
			if (sharedSignatureSet.has(signature)) sharedCount += 1;
		}
		trackSummary.shared_tile_signature_count = sharedCount;
		trackSummary.unique_to_preview_tile_signature_count =
			trackSummary.used_local_tile_count - sharedCount;
	}

	return {
		shared_group_count: sharedGroups.length,
		shared_groups: sharedGroups,
		tracks: perTrack,
	};
}

function loadTracksData(jsonPath = TRACKS_JSON) {
	const resolvedPath = jsonPath || TRACKS_JSON;
	return requireTracksDataShape(JSON.parse(fs.readFileSync(resolvedPath, 'utf8')));
}

function findTrack(identifier, tracksData = null) {
	const data = tracksData || loadTracksData();
	return findTrackByIdentifier(data, identifier);
}

function resolvePreviewSlug(track) {
	requireTrackShape(track, 'track');
	return PREVIEW_SLUG_BY_TRACK_INDEX[track.index] || track.slug;
}

function dedupeAdjacentPairs(pairs) {
  const result = [];
  for (const pair of pairs || []) {
    if (!Array.isArray(pair) || pair.length < 2) continue;
    const x = Number(pair[0]);
    const y = Number(pair[1]);
    const prev = result[result.length - 1];
    if (!prev || prev[0] !== x || prev[1] !== y) {
      result.push([x, y]);
    }
  }
  return result;
}

function getBounds(points) {
  if (!points || points.length === 0) {
    return {
      minX: 0,
      maxX: 0,
      minY: 0,
      maxY: 0,
      width: 0,
      height: 0,
      centerX: 0,
      centerY: 0,
    };
  }

  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;

  for (const point of points) {
    const x = point[0];
    const y = point[1];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  return {
    minX,
    maxX,
    minY,
    maxY,
    width: maxX - minX,
    height: maxY - minY,
    centerX: (minX + maxX) / 2,
    centerY: (minY + maxY) / 2,
  };
}

function transformPoints(points, variant, bounds = null) {
	if (!points || points.length === 0) return [];
	const sourceBounds = bounds || getBounds(points);
	return points.map(point => variant.map(point[0], point[1], sourceBounds));
}

function fitPointsToBounds(points, targetBounds) {
  if (!points || points.length === 0) return [];

  const sourceBounds = getBounds(points);
  const sourceWidth = Math.max(1, sourceBounds.width);
  const sourceHeight = Math.max(1, sourceBounds.height);
  const targetWidth = Math.max(1, targetBounds.width);
  const targetHeight = Math.max(1, targetBounds.height);
  const scaleX = targetWidth / sourceWidth;
  const scaleY = targetHeight / sourceHeight;

  return points.map(point => [
    ((point[0] - sourceBounds.minX) * scaleX) + targetBounds.minX,
    ((point[1] - sourceBounds.minY) * scaleY) + targetBounds.minY,
  ]);
}

function densifyPolyline(points) {
  if (!points || points.length === 0) return [];
  if (points.length === 1) return [[points[0][0], points[0][1]]];

  const result = [];
  for (let i = 0; i < points.length - 1; i++) {
    const start = points[i];
    const end = points[i + 1];
    const dx = end[0] - start[0];
    const dy = end[1] - start[1];
    const steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dy))));

    for (let step = 0; step < steps; step++) {
      const t = step / steps;
      const x = start[0] + dx * t;
      const y = start[1] + dy * t;
      const prev = result[result.length - 1];
      if (!prev || prev[0] !== x || prev[1] !== y) {
        result.push([x, y]);
      }
    }
  }

  const last = points[points.length - 1];
  const prev = result[result.length - 1];
  if (!prev || prev[0] !== last[0] || prev[1] !== last[1]) {
    result.push([last[0], last[1]]);
  }

  return result;
}

function getPreviewOccupiedPoints(preview) {
	const cacheKey = preview ? `${preview.width}x${preview.height}:${preview.slug || 'preview'}` : 'none';
	if (previewPointsCache.has(cacheKey)) return previewPointsCache.get(cacheKey);
  const points = [];
  if (!preview || !Array.isArray(preview.pixels)) return points;

  for (let y = 0; y < preview.height; y++) {
    for (let x = 0; x < preview.width; x++) {
      if (preview.pixels[y * preview.width + x]) {
        points.push([x, y]);
      }
    }
	}

	previewPointsCache.set(cacheKey, points);
  return points;
}

function getOccupiedPointsFromPixels(pixels, width, height, predicate = value => !!value) {
	const points = [];
	if (!Array.isArray(pixels)) return points;

	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			if (predicate(pixels[(y * width) + x], x, y)) points.push([x, y]);
		}
	}

	return points;
}

function computeNearestDistanceStats(fromPoints, toPoints, tolerance = 0, hitThreshold = tolerance) {
	if (!fromPoints.length || !toPoints.length) {
		return {
			mean: 0,
			max: 0,
			hit_count: 0,
			miss_count: fromPoints.length,
			hit_percent: fromPoints.length ? 0 : 100,
			distances: [],
		};
	}

	let total = 0;
	let maxDistance = 0;
	let hitCount = 0;
	const distances = [];

	for (const point of fromPoints) {
		let nearest = Infinity;
		for (const candidate of toPoints) {
			const dx = point[0] - candidate[0];
			const dy = point[1] - candidate[1];
			const distance = Math.sqrt((dx * dx) + (dy * dy));
			if (distance < nearest) nearest = distance;
		}
		if (nearest <= hitThreshold) hitCount += 1;
		const adjusted = Math.max(0, nearest - tolerance);
		distances.push(roundTo(adjusted));
		total += adjusted;
		if (adjusted > maxDistance) maxDistance = adjusted;
	}

	return {
		mean: total / fromPoints.length,
		max: maxDistance,
		hit_count: hitCount,
		miss_count: fromPoints.length - hitCount,
		hit_percent: (hitCount / fromPoints.length) * 100,
		distances,
	};
}

function evaluateMarkerAlignment(samplePoints, roadPoints, centerlinePoints, options = {}) {
	const roadTolerance = Number.isFinite(options.roadTolerance) ? options.roadTolerance : 0.75;
	const roadHitThreshold = Number.isFinite(options.roadHitThreshold) ? options.roadHitThreshold : roadTolerance;
	const centerlineTolerance = Number.isFinite(options.centerlineTolerance) ? options.centerlineTolerance : 0;
	const centerlineHitThreshold = Number.isFinite(options.centerlineHitThreshold)
		? options.centerlineHitThreshold
		: Math.max(1.5, centerlineTolerance);
	const road = computeNearestDistanceStats(samplePoints, roadPoints, roadTolerance, roadHitThreshold);
	const centerline = computeNearestDistanceStats(samplePoints, centerlinePoints, centerlineTolerance, centerlineHitThreshold);

	return {
		sample_count: samplePoints.length,
		road: {
			mean_distance: roundTo(road.mean),
			max_distance: roundTo(road.max),
			hit_count: road.hit_count,
			miss_count: road.miss_count,
			hit_percent: roundTo(road.hit_percent, 2),
			tolerance: roadTolerance,
			hit_threshold: roadHitThreshold,
			distances: road.distances,
		},
		centerline: {
			mean_distance: roundTo(centerline.mean),
			max_distance: roundTo(centerline.max),
			hit_count: centerline.hit_count,
			miss_count: centerline.miss_count,
			hit_percent: roundTo(centerline.hit_percent, 2),
			tolerance: centerlineTolerance,
			hit_threshold: centerlineHitThreshold,
			distances: centerline.distances,
		},
	};
}

function averageNearestDistance(fromPoints, toPoints) {
  if (!fromPoints.length || !toPoints.length) return 0;

  let total = 0;
  let maxDistance = 0;

  for (const point of fromPoints) {
    let nearest = Infinity;
    for (const candidate of toPoints) {
      const dx = point[0] - candidate[0];
      const dy = point[1] - candidate[1];
      const distance = Math.sqrt((dx * dx) + (dy * dy));
      if (distance < nearest) nearest = distance;
    }
    total += nearest;
    if (nearest > maxDistance) maxDistance = nearest;
  }

  return {
    mean: total / fromPoints.length,
    max: maxDistance,
  };
}

function averageNearestDistanceWithTolerance(fromPoints, toPoints, tolerance = 0) {
	if (!fromPoints.length || !toPoints.length) {
		return { mean: 0, max: 0 };
	}

	let total = 0;
	let maxDistance = 0;

	for (const point of fromPoints) {
		let nearest = Infinity;
		for (const candidate of toPoints) {
			const dx = point[0] - candidate[0];
			const dy = point[1] - candidate[1];
			const distance = Math.sqrt((dx * dx) + (dy * dy));
			if (distance < nearest) nearest = distance;
		}
		const adjusted = Math.max(0, nearest - tolerance);
		total += adjusted;
		if (adjusted > maxDistance) maxDistance = adjusted;
	}

	return {
		mean: total / fromPoints.length,
		max: maxDistance,
	};
}

function buildClosedPathSegments(points) {
	return buildTrackGeometryClosedPathSegments(points);
}

function sampleClosedPath(points, sampleCount) {
	return sampleTrackGeometryClosedPath(points, sampleCount);
}

function alignClosedSampleSequence(referencePairs, candidatePairs) {
	if (!Array.isArray(referencePairs) || !Array.isArray(candidatePairs)) return candidatePairs || [];
	const count = Math.min(referencePairs.length, candidatePairs.length);
	if (count <= 1) return candidatePairs.slice(0, count);

	const compareCount = Math.min(count, 16);
	let best = null;

	function scoreSequence(sequence) {
		for (let shift = 0; shift < count; shift++) {
			let score = 0;
			for (let i = 0; i < compareCount; i++) {
				const ref = referencePairs[i];
				const cand = sequence[(shift + i) % count];
				const dx = ref[0] - cand[0];
				const dy = ref[1] - cand[1];
				const weight = compareCount - i;
				score += ((dx * dx) + (dy * dy)) * weight;
			}
			if (!best || score < best.score) {
				best = { score, shift, sequence };
			}
		}
	}

	const forward = candidatePairs.slice(0, count);
	const reversed = candidatePairs.slice(0, count).reverse();
	scoreSequence(forward);
	scoreSequence(reversed);

	if (!best) return candidatePairs.slice(0, count);
	const aligned = [];
	for (let i = 0; i < count; i++) {
		aligned.push(best.sequence[(best.shift + i) % count]);
	}
	return aligned;
}

function rasterizePolyline(points, width, height, options = {}) {
	const closePath = options.closePath !== false;
	const radius = Math.max(0.5, Number(options.radius) || 0.75);
	const pixels = new Uint8Array(width * height);

	function stamp(x, y) {
		const minX = Math.max(0, Math.floor(x - radius));
		const maxX = Math.min(width - 1, Math.ceil(x + radius));
		const minY = Math.max(0, Math.floor(y - radius));
		const maxY = Math.min(height - 1, Math.ceil(y + radius));
		for (let py = minY; py <= maxY; py++) {
			for (let px = minX; px <= maxX; px++) {
				const dx = px - x;
				const dy = py - y;
				if ((dx * dx) + (dy * dy) > radius * radius) continue;
				pixels[(py * width) + px] = 1;
			}
		}
	}

	if (!points || points.length === 0) {
		return { width, height, pixels: Array.from(pixels), occupied_points: [] };
	}

	const segmentCount = closePath ? points.length : Math.max(0, points.length - 1);
	for (let i = 0; i < segmentCount; i++) {
		const start = points[i];
		const end = points[(i + 1) % points.length];
		const dx = end[0] - start[0];
		const dy = end[1] - start[1];
		const steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) * 2));
		for (let step = 0; step <= steps; step++) {
			const t = step / steps;
			stamp(start[0] + dx * t, start[1] + dy * t);
		}
	}

	const occupiedPoints = [];
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			if (pixels[(y * width) + x]) occupiedPoints.push([x, y]);
		}
	}

	return {
		width,
		height,
		pixels: Array.from(pixels),
		occupied_points: occupiedPoints,
	};
}

function scoreRasterAgainstPreview(rasterPoints, previewPoints, previewBounds, tolerance = 0) {
	const rasterToPreview = averageNearestDistanceWithTolerance(rasterPoints, previewPoints, tolerance);
	const previewToRaster = averageNearestDistanceWithTolerance(previewPoints, rasterPoints, tolerance);
	const symmetricMean = (rasterToPreview.mean + previewToRaster.mean) / 2;
	const scaleDenominator = Math.max(previewBounds.width, previewBounds.height, 1);
	const normalizedError = symmetricMean / scaleDenominator;
	const matchPercent = clamp(100 - (normalizedError * 100), 0, 100);
	return {
		tolerance,
		rasterToPreviewMean: roundTo(rasterToPreview.mean),
		rasterToPreviewMax: roundTo(rasterToPreview.max),
		previewToRasterMean: roundTo(previewToRaster.mean),
		previewToRasterMax: roundTo(previewToRaster.max),
		symmetricMean: roundTo(symmetricMean),
		normalizedError: roundTo(normalizedError, 4),
		matchPercent: roundTo(matchPercent, 2),
	};
}

function fitPathToTarget(sourcePoints, targetPoints) {
	const sourceBounds = getBounds(sourcePoints);
	const targetBounds = getBounds(targetPoints);
	let best = null;

	for (const variant of PREVIEW_TRANSFORMS) {
		const transformed = transformPoints(sourcePoints, variant, sourceBounds);
		const fitted = fitPointsToBounds(transformed, targetBounds);
		const sourceToTarget = averageNearestDistance(fitted, targetPoints);
		const targetToSource = averageNearestDistance(targetPoints, fitted);
		const symmetricMean = (sourceToTarget.mean + targetToSource.mean) / 2;
		const scaleDenominator = Math.max(targetBounds.width, targetBounds.height, 1);
		const normalizedError = symmetricMean / scaleDenominator;
		const matchPercent = clamp(100 - (normalizedError * 100), 0, 100);
		const candidate = {
			name: variant.name,
			transformedSourcePoints: fitted,
			sourceToTargetMean: roundTo(sourceToTarget.mean),
			sourceToTargetMax: roundTo(sourceToTarget.max),
			targetToSourceMean: roundTo(targetToSource.mean),
			targetToSourceMax: roundTo(targetToSource.max),
			symmetricMean: roundTo(symmetricMean),
			normalizedError: roundTo(normalizedError, 4),
			matchPercent: roundTo(matchPercent, 2),
		};

		if (!best || candidate.symmetricMean < best.symmetricMean) {
			best = candidate;
		}
	}

	return best;
}

function fitPreviewToCanonical(previewPoints, canonicalPolyline) {
	const best = fitPathToTarget(previewPoints, canonicalPolyline);
	return {
		name: best.name,
		transformedPreviewPoints: best.transformedSourcePoints,
		previewToCanonicalMean: best.sourceToTargetMean,
		previewToCanonicalMax: best.sourceToTargetMax,
		canonicalToPreviewMean: best.targetToSourceMean,
		canonicalToPreviewMax: best.targetToSourceMax,
		symmetricMean: best.symmetricMean,
		normalizedError: best.normalizedError,
		matchPercent: best.matchPercent,
	};
}

function fitCanonicalToPreview(canonicalPolyline, previewPoints) {
	const best = fitPathToTarget(canonicalPolyline, previewPoints);
	return {
		name: best.name,
		transformedCanonicalPoints: best.transformedSourcePoints,
		canonicalToPreviewMean: best.sourceToTargetMean,
		canonicalToPreviewMax: best.sourceToTargetMax,
		previewToCanonicalMean: best.targetToSourceMean,
		previewToCanonicalMax: best.targetToSourceMax,
		symmetricMean: best.symmetricMean,
		normalizedError: best.normalizedError,
		matchPercent: best.matchPercent,
	};
}

function projectSignsToMinimap(track, canonicalPoints) {
  const result = [];
  const points = canonicalPoints || [];
  if (points.length === 0) return result;

	for (const sign of getTrackSignData(track)) {
		const sampleIndex = clamp(sign.distance >> 6, 0, points.length - 1);
		const point = points[sampleIndex];
		result.push({
      distance: sign.distance,
      sign_id: sign.sign_id,
      count: sign.count,
      sample_index: sampleIndex,
      point: [point[0], point[1]],
    });
  }

  return result;
}

function gentlyClosePath(points) {
  if (!points || points.length < 2) return points || [];

  const first = points[0];
  const last = points[points.length - 1];
  const dx = last[0] - first[0];
  const dy = last[1] - first[1];

  return points.map((point, index) => {
	const t = index / (points.length - 1);
	return [
	  point[0] - (dx * t),
	  point[1] - (dy * t),
	];
  });
}

function smoothPath(points, passes = 1) {
  let current = points.slice();
  for (let pass = 0; pass < passes; pass++) {
    current = current.map((point, index, array) => {
      if (index === 0 || index === array.length - 1) return point;
      const prev = array[index - 1];
      const next = array[index + 1];
      return [
        (prev[0] + point[0] + next[0]) / 3,
        (prev[1] + point[1] + next[1]) / 3,
      ];
    });
  }
  return current;
}

function buildDerivedPath(track, options = {}) {
	const segments = getTrackCurveSegments(track);
	const points = [];
	let angle = Math.PI / 2;
	let x = 0;
	let y = 0;
	const sampleEvery = Math.max(1, Number.isInteger(options.sampleEvery) ? options.sampleEvery : 4);
	let totalTurnWeight = 0;
	let totalAbsTurnWeight = 0;
	for (const seg of segments) {
		if (!seg || seg.type === 'terminator') break;
		if (seg.type !== 'curve') continue;
		const sharpness = Math.max(seg.curve_byte & 0x3F, 1);
		const direction = seg.curve_byte >= 0x41 && seg.curve_byte <= 0x6F ? 1 : -1;
		const bgRate = (seg.bg_disp || 0) / Math.max(seg.length || 1, 1);
		const turnWeight = (1 / (sharpness ** 1.4)) + (4 * (bgRate / 300));
		totalTurnWeight += direction * turnWeight * seg.length;
		totalAbsTurnWeight += turnWeight * seg.length;
	}
	const effectiveTurnWeight = Math.max(Math.abs(totalTurnWeight), totalAbsTurnWeight * 0.2);
	const angleScale = typeof options.angleScale === 'number'
		? options.angleScale
		: (effectiveTurnWeight > 0.000001 ? (Math.PI * 2) / effectiveTurnWeight : 0.06);
	const smoothingPasses = Number.isInteger(options.smoothingPasses) ? options.smoothingPasses : 0;
	const closePath = options.closePath !== false;

	points.push([x, y]);
	let stepIndex = 0;
	for (const seg of segments) {
		if (!seg || seg.type === 'terminator') break;
		let angleDelta = 0;
		if (seg.type === 'curve') {
			const sharpness = Math.max(seg.curve_byte & 0x3F, 1);
			const direction = seg.curve_byte >= 0x41 && seg.curve_byte <= 0x6F ? 1 : -1;
			const bgRate = (seg.bg_disp || 0) / Math.max(seg.length || 1, 1);
			const turnWeight = (1 / (sharpness ** 1.4)) + (4 * (bgRate / 300));
			angleDelta = direction * turnWeight * angleScale;
		}
		for (let i = 0; i < seg.length; i++) {
			angle += angleDelta;
			x += Math.cos(angle);
			y += Math.sin(angle);
			stepIndex += 1;
			if ((stepIndex % sampleEvery) === 0) {
				points.push([x, y]);
			}
		}
	}

	if (points.length < 2) {
		points.push([x, y]);
	}

	const closed = closePath ? gentlyClosePath(points) : points;
	const smoothed = smoothingPasses > 0 ? smoothPath(closed, smoothingPasses) : closed;
	return {
		sampleEvery,
		angleScale,
		points: smoothed.map(point => [roundTo(point[0]), roundTo(point[1])]),
		bounds: getBounds(smoothed),
	};
}

function analyzeTrackMinimap(track) {
  if (!track) {
    throw new Error('analyzeTrackMinimap requires a track object');
  }

	const previewSlug = resolvePreviewSlug(track);
	const preview = getMinimapPreview(previewSlug);
	const rawMinimapPoints = getTrackMinimapPairs(track);
	const canonicalPoints = dedupeAdjacentPairs(rawMinimapPoints);
  const canonicalPolyline = densifyPolyline(canonicalPoints);
  const previewPoints = getPreviewOccupiedPoints(preview);
  const previewBounds = getBounds(previewPoints);
  const bestFit = fitPreviewToCanonical(previewPoints, canonicalPolyline);
  const signPoints = projectSignsToMinimap(track, canonicalPoints);
  const derivedPath = buildDerivedPath(track);
  const canonicalToPreviewFit = fitCanonicalToPreview(canonicalPolyline, previewPoints);
  const derivedPreviewFit = fitCanonicalToPreview(
    densifyPolyline(derivedPath.points || []),
    previewPoints
  );
  const runtimeSampleCount = rawMinimapPoints.length || Math.max(1, track.track_length >> 6);
  const canonicalPreviewSamples = sampleClosedPath(canonicalToPreviewFit.transformedCanonicalPoints, runtimeSampleCount);
  const derivedPreviewSamples = sampleClosedPath(derivedPreviewFit.transformedCanonicalPoints, runtimeSampleCount);
  const canonicalRaster = rasterizePolyline(canonicalToPreviewFit.transformedCanonicalPoints, preview.width, preview.height, {
		closePath: true,
		radius: 0.75,
	});
  const derivedRaster = rasterizePolyline(derivedPreviewFit.transformedCanonicalPoints, preview.width, preview.height, {
		closePath: true,
		radius: 0.75,
	});
  const previewThicknessTolerance = 3.5;
  const canonicalThicknessAware = scoreRasterAgainstPreview(
		canonicalRaster.occupied_points,
		previewPoints,
		previewBounds,
		previewThicknessTolerance
	);
  const derivedThicknessAware = scoreRasterAgainstPreview(
		derivedRaster.occupied_points,
		previewPoints,
		previewBounds,
		previewThicknessTolerance
	);
  const canonicalBounds = getBounds(canonicalPoints);
  const warningThreshold = 90;

	const canonicalPreviewSpace = buildPreviewSpaceFitSummary(
		canonicalToPreviewFit,
		canonicalPreviewSamples.map(point => [roundTo(point[0]), roundTo(point[1])]),
		canonicalThicknessAware
	);
	canonicalPreviewSpace.bounds = getBounds(canonicalToPreviewFit.transformedCanonicalPoints);

	const derivedPathPreviewSpace = buildPreviewSpaceFitSummary(
		derivedPreviewFit,
		derivedPreviewSamples.map(point => [roundTo(point[0]), roundTo(point[1])]),
		derivedThicknessAware
	);
	derivedPathPreviewSpace.bounds = getBounds(derivedPreviewFit.transformedCanonicalPoints);

	return buildTrackAnalysisEntry({
		track: buildTrackSummary(track, {
			includeTrackIndex: true,
			includeTrackLength: true,
			previewSlug,
			minimapPointCount: canonicalPoints.length,
			minimapRuntimeSampleCount: runtimeSampleCount,
		}),
		canonical: {
			points: canonicalPoints,
			polyline: canonicalPolyline,
			bounds: canonicalBounds,
			preview_space: canonicalPreviewSpace,
		},
		preview: {
			width: preview.width,
			height: preview.height,
			pixels: preview.pixels,
			occupied_points: previewPoints,
			transformed_points: bestFit.transformedPreviewPoints,
			bounds: getBounds(bestFit.transformedPreviewPoints),
		},
		signs: signPoints,
		derivedPath,
		derivedPathPreviewSpace,
		metrics: buildAnalysisMetrics(bestFit, warningThreshold),
	});
}

function generateMinimapPairsFromTrack(track) {
	if (!track) {
		throw new Error('generateMinimapPairsFromTrack requires a track object');
	}

	const { buildGeneratedMinimapPreview } = require('./minimap_render');
	const previewSlug = resolvePreviewSlug(track);
	const minimapPairs = getTrackMinimapPairs(track);
	const canonicalPoints = dedupeAdjacentPairs(minimapPairs);
	const sampleCount = minimapPairs.length > 0
		? minimapPairs.length
		: Math.max(1, track.track_length >> 6);
	const generatedPreview = buildGeneratedMinimapPreview(track);
	let generatedCenterline = Array.isArray(generatedPreview.centerline_points)
		? generatedPreview.centerline_points.map(point => [point[0], point[1]])
		: [];
	if (generatedCenterline.length && Number.isInteger(generatedPreview.start_index)) {
		const startIndex = ((generatedPreview.start_index % generatedCenterline.length) + generatedCenterline.length) % generatedCenterline.length;
		generatedCenterline = generatedCenterline.slice(startIndex).concat(generatedCenterline.slice(0, startIndex));
	}
	if (!generatedCenterline.length) {
		const derivedPath = buildDerivedPath(track);
		const canonicalPolyline = densifyPolyline(canonicalPoints);
		const derivedCanonicalFit = fitPathToTarget(
			densifyPolyline(derivedPath.points || []),
			canonicalPolyline
		);
		generatedCenterline = derivedCanonicalFit.transformedSourcePoints;
	}
	const sampled = sampleClosedPath(generatedCenterline, sampleCount);
	const aligned = alignClosedSampleSequence(minimapPairs, sampled);
	const rounded = aligned.map(point => [
		clamp(Math.round(point[0]), -128, 127),
		clamp(Math.round(point[1]), -128, 127),
	]);
	const roadPoints = getOccupiedPointsFromPixels(
		generatedPreview.road_pixels || generatedPreview.pixels,
		generatedPreview.width,
		generatedPreview.height
	);
	const alignment = evaluateMarkerAlignment(
		rounded,
		roadPoints,
		generatedCenterline,
		{ roadTolerance: 1.5, roadHitThreshold: 1.5, centerlineHitThreshold: 1.75 }
	);

	return buildGeneratedPairSummary({
		preview_slug: previewSlug,
		transform: generatedPreview.transform,
		match_percent: generatedPreview.match_percent,
		thickness_aware_match_percent: alignment.road.hit_percent,
		preview_match_percent: generatedPreview.match_percent,
		road_alignment_mean_distance: alignment.road.mean_distance,
		road_alignment_max_distance: alignment.road.max_distance,
		road_alignment_hit_percent: alignment.road.hit_percent,
		centerline_alignment_mean_distance: alignment.centerline.mean_distance,
		centerline_alignment_max_distance: alignment.centerline.max_distance,
		pairs: rounded,
	}, rounded);
}

function analyzeAllTracks(tracksData = null) {
	const data = tracksData || loadTracksData();
	const tracks = getTracks(data);
	const analyses = tracks.map(track => analyzeTrackMinimap(track));
	const matchPercents = analyses.map(entry => entry.metrics.match_percent);
	const averageMatch = matchPercents.length
		? roundTo(matchPercents.reduce((sum, value) => sum + value, 0) / matchPercents.length, 2)
		: 0;

	return buildMinimapAnalysisAggregateReport(analyses, {
		generatedAt: new Date().toISOString(),
		averageMatchPercent: averageMatch,
		significantMismatchCount: analyses.filter(entry => entry.metrics.significant_mismatch).length,
		previewTileUsageGroups: groupPreviewTileUsage(data),
		previewTileVocabulary: analyzePreviewTileVocabulary(data),
	});
}

module.exports = {
  TRACKS_JSON,
  PREVIEW_SLUG_BY_TRACK_INDEX,
  PREVIEW_TRANSFORMS,
  loadTracksData,
  findTrack,
  resolvePreviewSlug,
  dedupeAdjacentPairs,
  getBounds,
  fitPointsToBounds,
  densifyPolyline,
  getPreviewOccupiedPoints,
  getOccupiedPointsFromPixels,
  transformPoints,
  fitPathToTarget,
  fitPreviewToCanonical,
  fitCanonicalToPreview,
  averageNearestDistanceWithTolerance,
  computeNearestDistanceStats,
  evaluateMarkerAlignment,
  sampleClosedPath,
  alignClosedSampleSequence,
  rasterizePolyline,
  scoreRasterAgainstPreview,
  buildLocalTileUsageSignature,
  buildTilePixelSignature,
  groupPreviewTileUsage,
  analyzePreviewTileVocabulary,
  projectSignsToMinimap,
  gentlyClosePath,
  smoothPath,
  buildDerivedPath,
  generateMinimapPairsFromTrack,
  analyzeTrackMinimap,
  analyzeAllTracks,
};
