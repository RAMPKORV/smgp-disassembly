'use strict';

const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('./rom');
const { getMinimapPreview } = require('./minimap_preview');
const { decompressCurveSegments } = require('../randomizer/track_randomizer');

const TRACKS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');

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
	const tracks = Array.isArray(data.tracks) ? data.tracks : [];
	const groups = new Map();

	for (const track of tracks) {
		const previewSlug = resolvePreviewSlug(track);
		const preview = getMinimapPreview(previewSlug);
		const signature = buildLocalTileUsageSignature(preview);
		const existing = groups.get(signature);
		const summary = {
			track_index: track.index,
			track_slug: track.slug,
			preview_slug: previewSlug,
			used_local_tile_count: preview.used_local_tile_count,
		};

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
	const tracks = Array.isArray(data.tracks) ? data.tracks : [];
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

			entry.occurrences.push({
				track_index: track.index,
				track_slug: track.slug,
				preview_slug: previewSlug,
				local_tile_index: tileIndex,
			});
			entry.preview_slugs.add(previewSlug);
			entry.track_indices.add(track.index);
		}

		perTrack.push({
			track_index: track.index,
			track_slug: track.slug,
			preview_slug: previewSlug,
			used_local_tile_count: preview.used_local_tile_count,
			unique_tile_signature_count: seenInTrack.size,
		});
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
  return JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
}

function findTrack(identifier, tracksData = null) {
  const data = tracksData || loadTracksData();
  const tracks = Array.isArray(data.tracks) ? data.tracks : [];

  if (typeof identifier === 'number') {
    return tracks.find(track => track.index === identifier) || null;
  }

  if (typeof identifier === 'string') {
    if (/^\d+$/.test(identifier)) {
      return tracks.find(track => track.index === parseInt(identifier, 10)) || null;
    }
    return tracks.find(track => track.slug === identifier || track.name === identifier) || null;
  }

  if (identifier && typeof identifier === 'object') {
    return identifier;
  }

  return null;
}

function resolvePreviewSlug(track) {
  if (!track || typeof track.index !== 'number') {
    throw new Error('resolvePreviewSlug requires a track object with an index');
  }
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
  const points = [];
  if (!preview || !Array.isArray(preview.pixels)) return points;

  for (let y = 0; y < preview.height; y++) {
    for (let x = 0; x < preview.width; x++) {
      if (preview.pixels[y * preview.width + x]) {
        points.push([x, y]);
      }
    }
  }

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
	if (!points || points.length < 2) return [];
	const segments = [];
	let totalLength = 0;

	for (let i = 0; i < points.length; i++) {
		const start = points[i];
		const end = points[(i + 1) % points.length];
		const dx = end[0] - start[0];
		const dy = end[1] - start[1];
		const length = Math.sqrt((dx * dx) + (dy * dy));
		if (length === 0) continue;
		segments.push({
			start,
			end,
			startDistance: totalLength,
			length,
		});
		totalLength += length;
	}

	return { segments, totalLength };
}

function sampleClosedPath(points, sampleCount) {
	if (!points || points.length === 0 || sampleCount <= 0) return [];
	if (points.length === 1) {
		return Array.from({ length: sampleCount }, () => [points[0][0], points[0][1]]);
	}

	const path = buildClosedPathSegments(points);
	if (!path.segments.length || path.totalLength <= 0) return [];

	const result = [];
	for (let i = 0; i < sampleCount; i++) {
		const targetDistance = (path.totalLength * i) / sampleCount;
		let segment = path.segments[path.segments.length - 1];
		for (const candidate of path.segments) {
			if (targetDistance < candidate.startDistance + candidate.length) {
				segment = candidate;
				break;
			}
		}
		const t = segment.length <= 0 ? 0 : (targetDistance - segment.startDistance) / segment.length;
		result.push([
			segment.start[0] + (segment.end[0] - segment.start[0]) * t,
			segment.start[1] + (segment.end[1] - segment.start[1]) * t,
		]);
	}

	return result;
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

  for (const sign of track.sign_data || []) {
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

function buildDerivedPath(track) {
  const segments = Array.isArray(track.curve_rle_segments) ? track.curve_rle_segments : [];
  const flat = [];
  for (const value of decompressCurveSegments(segments)) {
    if (value >= 0x80) break;
    flat.push(value);
  }

  const points = [];
  let angle = Math.PI / 2;
  let x = 0;
  let y = 0;
  const sampleEvery = 16;

  points.push([x, y]);
  for (let i = 0; i < flat.length; i++) {
    const value = flat[i];
    let angleDelta = 0;
    if (value >= 0x01 && value <= 0x2F) {
      angleDelta = -0.06 / Math.max(value & 0x3F, 1);
    } else if (value >= 0x41 && value <= 0x6F) {
      angleDelta = 0.06 / Math.max(value & 0x3F, 1);
    }

    angle += angleDelta;
    x += Math.cos(angle);
    y += Math.sin(angle);

    if (((i + 1) % sampleEvery) === 0) {
      points.push([x, y]);
    }
  }

  if (points.length < 2) {
    points.push([x, y]);
  }

  const closed = gentlyClosePath(points);
  const smoothed = smoothPath(closed, 2);
  return {
    sampleEvery,
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
  const rawMinimapPoints = Array.isArray(track.minimap_pos) ? track.minimap_pos : [];
  const canonicalPoints = dedupeAdjacentPairs(track.minimap_pos || []);
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

  return {
    track: {
      index: track.index,
      name: track.name,
      slug: track.slug,
      preview_slug: previewSlug,
      track_length: track.track_length,
      minimap_point_count: canonicalPoints.length,
      minimap_runtime_sample_count: runtimeSampleCount,
    },
    canonical: {
      points: canonicalPoints,
      polyline: canonicalPolyline,
      bounds: canonicalBounds,
      preview_space: {
        transform: canonicalToPreviewFit.name,
        match_percent: canonicalToPreviewFit.matchPercent,
        symmetric_mean_distance: canonicalToPreviewFit.symmetricMean,
        canonical_to_preview_mean: canonicalToPreviewFit.canonicalToPreviewMean,
        canonical_to_preview_max: canonicalToPreviewFit.canonicalToPreviewMax,
        preview_to_canonical_mean: canonicalToPreviewFit.previewToCanonicalMean,
        preview_to_canonical_max: canonicalToPreviewFit.previewToCanonicalMax,
        normalized_error: canonicalToPreviewFit.normalizedError,
        bounds: getBounds(canonicalToPreviewFit.transformedCanonicalPoints),
        sampled_points: canonicalPreviewSamples.map(point => [roundTo(point[0]), roundTo(point[1])]),
        thickness_aware: {
			match_percent: canonicalThicknessAware.matchPercent,
			symmetric_mean_distance: canonicalThicknessAware.symmetricMean,
			raster_to_preview_mean: canonicalThicknessAware.rasterToPreviewMean,
			raster_to_preview_max: canonicalThicknessAware.rasterToPreviewMax,
			preview_to_raster_mean: canonicalThicknessAware.previewToRasterMean,
			preview_to_raster_max: canonicalThicknessAware.previewToRasterMax,
			normalized_error: canonicalThicknessAware.normalizedError,
			tolerance: canonicalThicknessAware.tolerance,
		},
      },
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
    derived_path: derivedPath,
    derived_path_preview_space: {
      transform: derivedPreviewFit.name,
      match_percent: derivedPreviewFit.matchPercent,
      symmetric_mean_distance: derivedPreviewFit.symmetricMean,
      canonical_to_preview_mean: derivedPreviewFit.canonicalToPreviewMean,
      canonical_to_preview_max: derivedPreviewFit.canonicalToPreviewMax,
      preview_to_canonical_mean: derivedPreviewFit.previewToCanonicalMean,
      preview_to_canonical_max: derivedPreviewFit.previewToCanonicalMax,
      normalized_error: derivedPreviewFit.normalizedError,
      bounds: getBounds(derivedPreviewFit.transformedCanonicalPoints),
      sampled_points: derivedPreviewSamples.map(point => [roundTo(point[0]), roundTo(point[1])]),
      thickness_aware: {
		match_percent: derivedThicknessAware.matchPercent,
		symmetric_mean_distance: derivedThicknessAware.symmetricMean,
		raster_to_preview_mean: derivedThicknessAware.rasterToPreviewMean,
		raster_to_preview_max: derivedThicknessAware.rasterToPreviewMax,
		preview_to_raster_mean: derivedThicknessAware.previewToRasterMean,
		preview_to_raster_max: derivedThicknessAware.previewToRasterMax,
		normalized_error: derivedThicknessAware.normalizedError,
		tolerance: derivedThicknessAware.tolerance,
	  },
    },
    metrics: {
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
    },
  };
}

function generateMinimapPairsFromTrack(track) {
	if (!track) {
		throw new Error('generateMinimapPairsFromTrack requires a track object');
	}

	const { buildGeneratedMinimapPreview } = require('./minimap_render');
	const previewSlug = resolvePreviewSlug(track);
	const canonicalPoints = dedupeAdjacentPairs(track.minimap_pos || []);
	const sampleCount = Array.isArray(track.minimap_pos) && track.minimap_pos.length > 0
		? track.minimap_pos.length
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
	const aligned = alignClosedSampleSequence(track.minimap_pos || [], sampled);
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

	return {
		preview_slug: previewSlug,
		transform: generatedPreview.transform,
		match_percent: generatedPreview.match_percent,
		thickness_aware_match_percent: alignment.road.hit_percent,
		preview_match_percent: generatedPreview.match_percent,
		sample_count: sampleCount,
		road_alignment_mean_distance: alignment.road.mean_distance,
		road_alignment_max_distance: alignment.road.max_distance,
		road_alignment_hit_percent: alignment.road.hit_percent,
		centerline_alignment_mean_distance: alignment.centerline.mean_distance,
		centerline_alignment_max_distance: alignment.centerline.max_distance,
		pairs: rounded,
	};
}

function analyzeAllTracks(tracksData = null) {
  const data = tracksData || loadTracksData();
  const tracks = Array.isArray(data.tracks) ? data.tracks : [];
  const analyses = tracks.map(track => analyzeTrackMinimap(track));
  const matchPercents = analyses.map(entry => entry.metrics.match_percent);
  const averageMatch = matchPercents.length
    ? roundTo(matchPercents.reduce((sum, value) => sum + value, 0) / matchPercents.length, 2)
    : 0;

  return {
    generated_at: new Date().toISOString(),
    track_count: analyses.length,
    average_match_percent: averageMatch,
    significant_mismatch_count: analyses.filter(entry => entry.metrics.significant_mismatch).length,
    preview_tile_usage_groups: groupPreviewTileUsage(data),
    preview_tile_vocabulary: analyzePreviewTileVocabulary(data),
    tracks: analyses,
  };
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
