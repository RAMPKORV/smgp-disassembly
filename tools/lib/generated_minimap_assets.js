'use strict';

const { buildGeneratedMinimapPreview } = require('./minimap_render');
const { formatDcB } = require('./asm_patch_helpers');
const { getGeneratedGeometryState } = require('../randomizer/track_metadata');
const { isRuntimeSafeRandomized } = require('../randomizer/track_metadata');
const { styleRoadPreview } = require('./minimap_raster');
const { getMinimapPreview } = require('./minimap_preview');
const {
	MINIMAP_PANEL_TILES_H,
	MINIMAP_PANEL_TILES_W,
	MINIMAP_TILE_INDEX_MASK,
	MINIMAP_TILE_SIZE_PX,
} = require('./minimap_layout');
const { resolvePreviewSlug } = require('./minimap_analysis');
const { encodeTinyGraphics } = require('../minimap_graphics_codec');
const { encodeLiteralTilemap } = require('../minimap_map_codec');
const { getCourseSelectReservedLocalTileIndices } = require('./course_select_preview_tiles');

const generatedAssetsCache = new WeakMap();
const PRESERVED_EXTERNAL_CELL_INDEX_CONFIG = Object.freeze({});
const COURSE_SELECT_PREVIEW_TILE_BUDGET = 48;

function getPreviewProjection(track) {
	const projection = getGeneratedGeometryState(track)?.projections?.minimap_preview || null;
	if (projection && Array.isArray(projection.centerline_points) && Array.isArray(projection.pixels)) return projection;
	return null;
}

function buildAssetPreview(track, preview) {
	if (!preview || !Array.isArray(preview.centerline_points) || preview.centerline_points.length === 0) {
		return preview;
	}
	const geometryState = getGeneratedGeometryState(track);
	const crossingProjection = geometryState?.projections?.slope?.grade_separated_crossing || null;
	const underpassSegment = crossingProjection?.lower_branch
		? {
			start_index: crossingProjection.lower_branch.start_index,
			end_index: crossingProjection.lower_branch.end_index,
		}
		: null;
	const sourcePreview = Array.isArray(preview.pixels) && preview.pixels.length === (preview.width * preview.height)
		? Object.assign({}, preview, {
			pixels: preview.pixels.slice(),
			road_pixels: Array.isArray(preview.road_pixels) ? preview.road_pixels.slice() : preview.pixels.slice(),
			start_marker_pixels: Array.isArray(preview.start_marker_pixels) ? preview.start_marker_pixels.slice() : null,
		})
		: Object.assign({}, preview, (() => {
			const styled = styleRoadPreview(preview.centerline_points, preview.width, preview.height, null, { underpass_segment: underpassSegment });
			return {
				pixels: styled.pixels,
				road_pixels: styled.road_pixels,
				start_marker_pixels: styled.start_marker_pixels,
			};
		})());
	return emitLegalContourPreview(sourcePreview);
}

function removeMixedCellOutlineSpurs(preview) {
	if (!preview || !Array.isArray(preview.pixels) || !Array.isArray(preview.road_pixels)) return preview;
	// Remove detached outline islands from cells that already contain supported road pixels.
	const cleaned = clonePreviewPixels(preview);
	const startMask = Array.isArray(cleaned.start_marker_pixels) ? cleaned.start_marker_pixels : Array(cleaned.width * cleaned.height).fill(0);
	const outlineMask = new Uint8Array(cleaned.width * cleaned.height);
	for (let i = 0; i < outlineMask.length; i++) outlineMask[i] = cleaned.pixels[i] && !cleaned.road_pixels[i] && !startMask[i] ? 1 : 0;

	function inBounds(x, y) {
		return x >= 0 && y >= 0 && x < cleaned.width && y < cleaned.height;
	}

	for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
		for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
			const cellPixels = [];
			let hasRoadOrMarker = false;
			for (let y = tileY * MINIMAP_TILE_SIZE_PX; y < (tileY + 1) * MINIMAP_TILE_SIZE_PX; y++) {
				for (let x = tileX * MINIMAP_TILE_SIZE_PX; x < (tileX + 1) * MINIMAP_TILE_SIZE_PX; x++) {
					const index = (y * cleaned.width) + x;
					if (cleaned.road_pixels[index] || startMask[index]) hasRoadOrMarker = true;
					if (outlineMask[index]) cellPixels.push(index);
				}
			}
			if (!hasRoadOrMarker || cellPixels.length === 0) continue;

			const localSeen = new Set();
			for (const startIndex of cellPixels) {
				if (localSeen.has(startIndex)) continue;
				const queue = [startIndex];
				localSeen.add(startIndex);
				const localComponent = [];
				let touchesOutside = false;
				let touchesRoad = false;
				while (queue.length > 0) {
					const current = queue.pop();
					localComponent.push(current);
					const x = current % cleaned.width;
					const y = Math.floor(current / cleaned.width);
					for (let dy = -1; dy <= 1; dy++) {
						for (let dx = -1; dx <= 1; dx++) {
							if (dx === 0 && dy === 0) continue;
							const nx = x + dx;
							const ny = y + dy;
							if (!inBounds(nx, ny)) continue;
							const next = (ny * cleaned.width) + nx;
							if (cleaned.road_pixels[next]) touchesRoad = true;
							if (!outlineMask[next]) continue;
							if (Math.floor(nx / MINIMAP_TILE_SIZE_PX) !== tileX || Math.floor(ny / MINIMAP_TILE_SIZE_PX) !== tileY) {
								touchesOutside = true;
								continue;
							}
							if (localSeen.has(next)) continue;
							localSeen.add(next);
							queue.push(next);
						}
					}
				}
				if (!touchesRoad || touchesOutside || localComponent.length > 4) continue;
				for (const pixelIndex of localComponent) cleaned.pixels[pixelIndex] = 0;
			}
		}
	}

	return cleaned;
}

function pruneRoadlessSingleHandoffFragments(preview) {
	if (!preview || !Array.isArray(preview.pixels) || !Array.isArray(preview.road_pixels)) return preview;
	// Remove empty-cell contour fragments that do not carry a legal bridge/handoff role.
	const cleaned = clonePreviewPixels(preview);
	const startMask = Array.isArray(cleaned.start_marker_pixels) ? cleaned.start_marker_pixels : Array(cleaned.width * cleaned.height).fill(0);

	function inBounds(x, y) {
		return x >= 0 && y >= 0 && x < cleaned.width && y < cleaned.height;
	}

	function blackMask() {
		const mask = new Uint8Array(cleaned.width * cleaned.height);
		for (let i = 0; i < mask.length; i++) {
			mask[i] = cleaned.pixels[i] === 1 && !startMask[i] ? 1 : 0;
		}
		return mask;
	}

	function countBlackComponents(mask) {
		const seen = new Uint8Array(mask.length);
		let count = 0;
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index] || seen[index]) continue;
			count += 1;
			const queue = [index];
			seen[index] = 1;
			while (queue.length > 0) {
				const current = queue.pop();
				const x = current % cleaned.width;
				const y = Math.floor(current / cleaned.width);
				for (let dy = -1; dy <= 1; dy++) {
					for (let dx = -1; dx <= 1; dx++) {
						if (dx === 0 && dy === 0) continue;
						const nx = x + dx;
						const ny = y + dy;
						if (!inBounds(nx, ny)) continue;
						const next = (ny * cleaned.width) + nx;
						if (!mask[next] || seen[next]) continue;
						seen[next] = 1;
						queue.push(next);
					}
				}
			}
		}
		return count;
	}

	function collectInvalidFragments(mask) {
		const fragments = [];
		for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
			for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
				let hasRoadOrMarker = false;
				const cellMask = new Uint8Array(mask.length);
				for (let y = tileY * MINIMAP_TILE_SIZE_PX; y < tileY * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX; y++) {
					for (let x = tileX * MINIMAP_TILE_SIZE_PX; x < tileX * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX; x++) {
						const index = (y * cleaned.width) + x;
						if (cleaned.road_pixels[index] || startMask[index]) hasRoadOrMarker = true;
						if (mask[index]) cellMask[index] = 1;
					}
				}
				if (hasRoadOrMarker) continue;

				const seen = new Uint8Array(mask.length);
				for (let index = 0; index < cellMask.length; index++) {
					if (!cellMask[index] || seen[index]) continue;
					const queue = [index];
					seen[index] = 1;
					const cells = [];
					while (queue.length > 0) {
						const current = queue.pop();
						cells.push(current);
						const x = current % cleaned.width;
						const y = Math.floor(current / cleaned.width);
						for (let dy = -1; dy <= 1; dy++) {
							for (let dx = -1; dx <= 1; dx++) {
								if (dx === 0 && dy === 0) continue;
								const nx = x + dx;
								const ny = y + dy;
								if (!inBounds(nx, ny)) continue;
								if (Math.floor(nx / MINIMAP_TILE_SIZE_PX) !== tileX || Math.floor(ny / MINIMAP_TILE_SIZE_PX) !== tileY) continue;
								const next = (ny * cleaned.width) + nx;
								if (!cellMask[next] || seen[next]) continue;
								seen[next] = 1;
								queue.push(next);
							}
						}
					}

					let outsideHandoffs = 0;
					for (const cell of cells) {
						const x = cell % cleaned.width;
						const y = Math.floor(cell / cleaned.width);
						let hasOutsideNeighbor = false;
						for (let dy = -1; dy <= 1 && !hasOutsideNeighbor; dy++) {
							for (let dx = -1; dx <= 1; dx++) {
								if (dx === 0 && dy === 0) continue;
								const nx = x + dx;
								const ny = y + dy;
								if (!inBounds(nx, ny)) continue;
								if (Math.floor(nx / MINIMAP_TILE_SIZE_PX) === tileX && Math.floor(ny / MINIMAP_TILE_SIZE_PX) === tileY) continue;
								const next = (ny * cleaned.width) + nx;
								if (mask[next]) hasOutsideNeighbor = true;
							}
						}
						if (hasOutsideNeighbor) outsideHandoffs += 1;
					}
					if (outsideHandoffs <= 1) fragments.push({ cells, outsideHandoffs });
				}
			}
		}
		fragments.sort((a, b) => a.cells.length - b.cells.length);
		return fragments;
	}

	let mask = blackMask();
	let currentComponentCount = countBlackComponents(mask);
	let changed = true;
	while (changed) {
		changed = false;
		for (const fragment of collectInvalidFragments(mask)) {
			const nextMask = Uint8Array.from(mask);
			for (const cell of fragment.cells) nextMask[cell] = 0;
			const nextComponentCount = countBlackComponents(nextMask);
			if (nextComponentCount > currentComponentCount) continue;
			for (const cell of fragment.cells) cleaned.pixels[cell] = 0;
			mask = nextMask;
			currentComponentCount = nextComponentCount;
			changed = true;
			break;
		}
	}

	return cleaned;
}

function removeRoadAdjacentLowerResidue(preview) {
	if (!preview || !Array.isArray(preview.pixels) || !Array.isArray(preview.road_pixels)) return preview;
	const cleaned = clonePreviewPixels(preview);
	const startMask = Array.isArray(cleaned.start_marker_pixels) ? cleaned.start_marker_pixels : Array(cleaned.width * cleaned.height).fill(0);
	const mask = new Uint8Array(cleaned.width * cleaned.height);
	for (let i = 0; i < mask.length; i++) mask[i] = cleaned.pixels[i] === 1 && !cleaned.road_pixels[i] && !startMask[i] ? 1 : 0;

	function inBounds(x, y) {
		return x >= 0 && y >= 0 && x < cleaned.width && y < cleaned.height;
	}

	function touchesRoad(index) {
		const x = index % cleaned.width;
		const y = (index / cleaned.width) | 0;
		for (let dy = -1; dy <= 1; dy++) {
			for (let dx = -1; dx <= 1; dx++) {
				if (dx === 0 && dy === 0) continue;
				const nx = x + dx;
				const ny = y + dy;
				if (!inBounds(nx, ny)) continue;
				if (cleaned.road_pixels[(ny * cleaned.width) + nx]) return true;
			}
		}
		return false;
	}

	function nearestRoadDistance(index) {
		const x = index % cleaned.width;
		const y = (index / cleaned.width) | 0;
		for (let distance = 1; distance <= 3; distance++) {
			for (let dy = -distance; dy <= distance; dy++) {
				for (let dx = -distance; dx <= distance; dx++) {
					if (Math.max(Math.abs(dx), Math.abs(dy)) !== distance) continue;
					const nx = x + dx;
					const ny = y + dy;
					if (!inBounds(nx, ny)) continue;
					if (cleaned.road_pixels[(ny * cleaned.width) + nx]) return distance;
				}
			}
		}
		return Infinity;
	}

	const seen = new Uint8Array(mask.length);
	for (let index = 0; index < mask.length; index++) {
		if (!mask[index] || seen[index]) continue;
		const queue = [index];
		seen[index] = 1;
		const cells = [];
		let minX = cleaned.width;
		let maxX = -1;
		let minY = cleaned.height;
		let maxY = -1;
		let bestRoadDistance = Infinity;
		while (queue.length > 0) {
			const current = queue.pop();
			cells.push(current);
			const x = current % cleaned.width;
			const y = (current / cleaned.width) | 0;
			if (x < minX) minX = x;
			if (x > maxX) maxX = x;
			if (y < minY) minY = y;
			if (y > maxY) maxY = y;
			bestRoadDistance = Math.min(bestRoadDistance, nearestRoadDistance(current));
			for (let dy = -1; dy <= 1; dy++) {
				for (let dx = -1; dx <= 1; dx++) {
					if (dx === 0 && dy === 0) continue;
					const nx = x + dx;
					const ny = y + dy;
					if (!inBounds(nx, ny)) continue;
					const next = (ny * cleaned.width) + nx;
					if (!mask[next] || seen[next]) continue;
					seen[next] = 1;
					queue.push(next);
				}
			}
		}
		if (cells.length > 2) continue;
		if (bestRoadDistance > 3) continue;
		if ((maxX - minX) > 0) continue;
		if (minY >= (cleaned.height - 8)) {
			for (const cell of cells) cleaned.pixels[cell] = 0;
			continue;
		}
		if (maxY < (cleaned.height - 8)) continue;
		for (const cell of cells) cleaned.pixels[cell] = 0;
	}

	for (let index = 0; index < mask.length; index++) {
		if (!mask[index]) continue;
		const x = index % cleaned.width;
		const y = (index / cleaned.width) | 0;
		if (y < (cleaned.height - 8)) continue;
		if (cleaned.road_pixels[index]) continue;
		if (inBounds(x, y - 1) && mask[((y - 1) * cleaned.width) + x]) continue;
		let aboveRoad = false;
		for (let dy = -4; dy <= -2 && !aboveRoad; dy++) {
			for (let dx = -2; dx <= 2; dx++) {
				const nx = x + dx;
				const ny = y + dy;
				if (!inBounds(nx, ny)) continue;
				if (cleaned.road_pixels[(ny * cleaned.width) + nx]) {
					aboveRoad = true;
					break;
				}
			}
		}
		if (!aboveRoad) continue;
		cleaned.pixels[index] = 0;
	}

	return cleaned;
}

function pruneRoadAdjacentSplitTailComponents(preview) {
	if (!preview || !Array.isArray(preview.pixels) || !Array.isArray(preview.road_pixels)) return preview;
	const cleaned = clonePreviewPixels(preview);
	const startMask = Array.isArray(cleaned.start_marker_pixels) ? cleaned.start_marker_pixels : Array(cleaned.width * cleaned.height).fill(0);
	const mask = new Uint8Array(cleaned.width * cleaned.height);
	for (let i = 0; i < mask.length; i++) mask[i] = cleaned.pixels[i] === 1 && !startMask[i] ? 1 : 0;

	function inBounds(x, y) {
		return x >= 0 && y >= 0 && x < cleaned.width && y < cleaned.height;
	}

	const seen = new Uint8Array(mask.length);
	for (let index = 0; index < mask.length; index++) {
		if (!mask[index] || seen[index]) continue;
		const queue = [index];
		seen[index] = 1;
		const cells = [];
		let minX = cleaned.width;
		let maxX = -1;
		let minY = cleaned.height;
		let maxY = -1;
		let roadTouchCount = 0;
		let endpoints = 0;
		let branches = 0;
		let twoByTwoAnchors = 0;
		while (queue.length > 0) {
			const current = queue.pop();
			cells.push(current);
			const x = current % cleaned.width;
			const y = (current / cleaned.width) | 0;
			if (x < minX) minX = x;
			if (x > maxX) maxX = x;
			if (y < minY) minY = y;
			if (y > maxY) maxY = y;
			let degree = 0;
			let touchesRoad = false;
			for (let dy = -1; dy <= 1; dy++) {
				for (let dx = -1; dx <= 1; dx++) {
					if (dx === 0 && dy === 0) continue;
					const nx = x + dx;
					const ny = y + dy;
					if (!inBounds(nx, ny)) continue;
					const next = (ny * cleaned.width) + nx;
					if (cleaned.road_pixels[next]) touchesRoad = true;
					if (!mask[next]) continue;
					degree += 1;
					if (!seen[next]) {
						seen[next] = 1;
						queue.push(next);
					}
				}
			}
			if (touchesRoad) roadTouchCount += 1;
			if (degree <= 1) endpoints += 1;
			if (degree > 2) branches += 1;
			for (let oy = -1; oy <= 0; oy++) {
				for (let ox = -1; ox <= 0; ox++) {
					let count = 0;
					for (let dy = 0; dy <= 1; dy++) {
						for (let dx = 0; dx <= 1; dx++) {
							const nx = x + ox + dx;
							const ny = y + oy + dy;
							if (!inBounds(nx, ny)) continue;
							if (mask[(ny * cleaned.width) + nx]) count += 1;
						}
					}
					if (count >= 3) twoByTwoAnchors += 1;
				}
			}
		}

		const simplePath = branches === 0 && endpoints === 2;
		const diagonalRun = simplePath && minX !== maxX && minY !== maxY;
		const fullyRoadAdjacent = roadTouchCount === cells.length;
		const lowerTailSplitRun = diagonalRun
			&& fullyRoadAdjacent
			&& cells.length >= 8
			&& cells.length <= 40
			&& minY >= (cleaned.height - 24)
			&& maxY >= (cleaned.height - 8)
			&& twoByTwoAnchors === 0;
		if (!lowerTailSplitRun) continue;
		for (const cell of cells) cleaned.pixels[cell] = 0;
	}

	return cleaned;
}

function removeRoadAdjacentDuplicateStrips(preview) {
	if (!preview || !Array.isArray(preview.pixels) || !Array.isArray(preview.road_pixels)) return preview;
	const cleaned = clonePreviewPixels(preview);
	const startMask = Array.isArray(cleaned.start_marker_pixels) ? cleaned.start_marker_pixels : Array(cleaned.width * cleaned.height).fill(0);

	function inBounds(x, y) {
		return x >= 0 && y >= 0 && x < cleaned.width && y < cleaned.height;
	}

	function buildBlackMask() {
		const mask = new Uint8Array(cleaned.width * cleaned.height);
		for (let i = 0; i < mask.length; i++) mask[i] = cleaned.pixels[i] === 1 && !startMask[i] ? 1 : 0;
		return mask;
	}

	function countComponents(mask) {
		const seen = new Uint8Array(mask.length);
		let count = 0;
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index] || seen[index]) continue;
			count += 1;
			const queue = [index];
			seen[index] = 1;
			while (queue.length > 0) {
				const current = queue.pop();
				const x = current % cleaned.width;
				const y = (current / cleaned.width) | 0;
				for (let dy = -1; dy <= 1; dy++) {
					for (let dx = -1; dx <= 1; dx++) {
						if (dx === 0 && dy === 0) continue;
						const nx = x + dx;
						const ny = y + dy;
						if (!inBounds(nx, ny)) continue;
						const next = (ny * cleaned.width) + nx;
						if (!mask[next] || seen[next]) continue;
						seen[next] = 1;
						queue.push(next);
					}
				}
			}
		}
		return count;
	}

	function countOrphans(mask) {
		const seen = new Uint8Array(mask.length);
		let count = 0;
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index] || seen[index]) continue;
			const queue = [index];
			seen[index] = 1;
			let touchesRoad = false;
			while (queue.length > 0) {
				const current = queue.pop();
				const x = current % cleaned.width;
				const y = (current / cleaned.width) | 0;
				for (let dy = -1; dy <= 1; dy++) {
					for (let dx = -1; dx <= 1; dx++) {
						if (dx === 0 && dy === 0) continue;
						const nx = x + dx;
						const ny = y + dy;
						if (!inBounds(nx, ny)) continue;
						const next = (ny * cleaned.width) + nx;
						if (cleaned.road_pixels[next]) touchesRoad = true;
						if (!mask[next] || seen[next]) continue;
						seen[next] = 1;
						queue.push(next);
					}
				}
			}
			if (!touchesRoad) count += 1;
		}
		return count;
	}

	function cellHasRoadOrMarker(tileX, tileY) {
		for (let y = tileY * MINIMAP_TILE_SIZE_PX; y < tileY * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX; y++) {
			for (let x = tileX * MINIMAP_TILE_SIZE_PX; x < tileX * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX; x++) {
				const index = (y * cleaned.width) + x;
				if (cleaned.road_pixels[index] || startMask[index]) return true;
			}
		}
		return false;
	}

	let changed = true;
	while (changed) {
		changed = false;
		const mask = buildBlackMask();
		const componentCount = countComponents(mask);
		const orphanCount = countOrphans(mask);
		for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H && !changed; tileY++) {
			for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W && !changed; tileX++) {
				if (cellHasRoadOrMarker(tileX, tileY)) continue;
				const localSeen = new Set();
				for (let y = tileY * MINIMAP_TILE_SIZE_PX; y < tileY * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX && !changed; y++) {
					for (let x = tileX * MINIMAP_TILE_SIZE_PX; x < tileX * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX && !changed; x++) {
						const startIndex = (y * cleaned.width) + x;
						if (!mask[startIndex] || localSeen.has(startIndex)) continue;
						const queue = [startIndex];
						localSeen.add(startIndex);
						const cells = [];
						let minX = cleaned.width;
						let maxX = -1;
						let minY = cleaned.height;
						let maxY = -1;
						let touchesRoad = false;
						while (queue.length > 0) {
							const current = queue.pop();
							cells.push(current);
							const cx = current % cleaned.width;
							const cy = (current / cleaned.width) | 0;
							if (cx < minX) minX = cx;
							if (cx > maxX) maxX = cx;
							if (cy < minY) minY = cy;
							if (cy > maxY) maxY = cy;
							for (let dy = -1; dy <= 1; dy++) {
								for (let dx = -1; dx <= 1; dx++) {
									if (dx === 0 && dy === 0) continue;
									const nx = cx + dx;
									const ny = cy + dy;
									if (!inBounds(nx, ny)) continue;
									const next = (ny * cleaned.width) + nx;
									if (cleaned.road_pixels[next]) touchesRoad = true;
									if (!mask[next]) continue;
									if (Math.floor(nx / MINIMAP_TILE_SIZE_PX) !== tileX || Math.floor(ny / MINIMAP_TILE_SIZE_PX) !== tileY) continue;
									if (localSeen.has(next)) continue;
									localSeen.add(next);
									queue.push(next);
								}
							}
						}

						const spansOppositeEdges = (minX === tileX * MINIMAP_TILE_SIZE_PX && maxX === (tileX * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX - 1))
							|| (minY === tileY * MINIMAP_TILE_SIZE_PX && maxY === (tileY * MINIMAP_TILE_SIZE_PX + MINIMAP_TILE_SIZE_PX - 1));
						const narrowStrip = (maxX - minX) <= 1 || (maxY - minY) <= 1;
						if (!touchesRoad || !narrowStrip || !spansOppositeEdges || cells.length < 8) continue;

						const nextMask = Uint8Array.from(mask);
						for (const cell of cells) nextMask[cell] = 0;
						if (countComponents(nextMask) > componentCount || countOrphans(nextMask) > orphanCount) continue;

						for (const cell of cells) cleaned.pixels[cell] = 0;
						changed = true;
					}
				}
			}
		}
	}

	return cleaned;
}

function finalizeContourCleanup(preview) {
	return removeRoadAdjacentDuplicateStrips(
		pruneRoadAdjacentSplitTailComponents(
			removeRoadAdjacentLowerResidue(
				pruneRoadlessSingleHandoffFragments(removeMixedCellOutlineSpurs(preview))
			)
		)
	);
}

function emitLegalContourPreview(preview) {
	if (!preview || !Array.isArray(preview.pixels) || !Array.isArray(preview.road_pixels)) return preview;
	// Emit the legal course-select contour directly from the styled preview layers.
	// Road pixels remain authoritative. Outline-only pixels are kept only when they
	// match a tested structural role: seam continuation, anchored continuation, or
	// the stock-style right-wall/edge vocabulary already produced by the rasterizer.
	// Everything else is limited to explicitly tested illegal fragment classes.
	const cleaned = clonePreviewPixels(preview);
	const startMask = Array.isArray(cleaned.start_marker_pixels) ? cleaned.start_marker_pixels : Array(cleaned.width * cleaned.height).fill(0);
	const outlineMask = new Uint8Array(cleaned.width * cleaned.height);
	for (let i = 0; i < outlineMask.length; i++) outlineMask[i] = cleaned.pixels[i] && !cleaned.road_pixels[i] && !startMask[i] ? 1 : 0;
	const neighborOffsets = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
	const initialMask = Uint8Array.from(outlineMask);

	function inBounds(x, y) {
		return x >= 0 && y >= 0 && x < cleaned.width && y < cleaned.height;
	}

	function cellKeyForIndex(pixelIndex) {
		const x = pixelIndex % cleaned.width;
		const y = Math.floor(pixelIndex / cleaned.width);
		return `${Math.floor(x / MINIMAP_TILE_SIZE_PX)},${Math.floor(y / MINIMAP_TILE_SIZE_PX)}`;
	}

	function cellRect(cellX, cellY) {
		const x0 = cellX * MINIMAP_TILE_SIZE_PX;
		const y0 = cellY * MINIMAP_TILE_SIZE_PX;
		return { x0, y0, x1: x0 + MINIMAP_TILE_SIZE_PX - 1, y1: y0 + MINIMAP_TILE_SIZE_PX - 1 };
	}

	function cellHasRoadOrMarker(cellX, cellY) {
		const { x0, y0, x1, y1 } = cellRect(cellX, cellY);
		for (let y = y0; y <= y1; y++) {
			for (let x = x0; x <= x1; x++) {
				const index = (y * cleaned.width) + x;
				if (cleaned.road_pixels[index] || startMask[index]) return true;
			}
		}
		return false;
	}

	function popcount4(mask) {
		let count = 0;
		for (let bit = 0; bit < 4; bit++) if ((mask >> bit) & 1) count += 1;
		return count;
	}

	function crossesTileSeam(ax, ay, bx, by) {
		return Math.floor(ax / MINIMAP_TILE_SIZE_PX) !== Math.floor(bx / MINIMAP_TILE_SIZE_PX)
			|| Math.floor(ay / MINIMAP_TILE_SIZE_PX) !== Math.floor(by / MINIMAP_TILE_SIZE_PX);
	}

	function hasRoadAttachment(x, y) {
		for (const [dx, dy] of neighborOffsets) {
			const nx = x + dx;
			const ny = y + dy;
			if (!inBounds(nx, ny)) continue;
			if (cleaned.road_pixels[(ny * cleaned.width) + nx]) return true;
		}
		return false;
	}

	function hasTwoByTwoBlock(mask, x, y) {
		for (let oy = -1; oy <= 0; oy++) {
			for (let ox = -1; ox <= 0; ox++) {
				let count = 0;
				for (let dy = 0; dy <= 1; dy++) {
					for (let dx = 0; dx <= 1; dx++) {
						const nx = x + ox + dx;
						const ny = y + oy + dy;
						if (!inBounds(nx, ny)) continue;
						if (mask[(ny * cleaned.width) + nx]) count += 1;
					}
				}
				if (count >= 3) return true;
			}
		}
		return false;
	}

	function externalGroupCount(outsideNeighborIndices, blockedSet, nodeByIndex) {
		const seen = new Set();
		let groups = 0;
		for (const startIndex of outsideNeighborIndices) {
			if (seen.has(startIndex)) continue;
			groups += 1;
			const queue = [startIndex];
			seen.add(startIndex);
			while (queue.length > 0) {
				const current = queue.pop();
				for (const neighbor of nodeByIndex.get(current)?.neighbors || []) {
					if (blockedSet.has(neighbor.index)) continue;
					if (seen.has(neighbor.index)) continue;
					seen.add(neighbor.index);
					queue.push(neighbor.index);
				}
			}
		}
		return groups;
	}

	function buildNodeGraph(mask) {
		const nodeByIndex = new Map();
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index]) continue;
			const x = index % cleaned.width;
			const y = Math.floor(index / cleaned.width);
			const neighbors = [];
			let seam = false;
			for (const [dx, dy] of neighborOffsets) {
				const nx = x + dx;
				const ny = y + dy;
				if (!inBounds(nx, ny)) continue;
				const next = (ny * cleaned.width) + nx;
				if (!mask[next]) continue;
				neighbors.push({ index: next, dx, dy });
				if (crossesTileSeam(x, y, nx, ny)) seam = true;
			}
			let isTurn = false;
			if (neighbors.length === 2) {
				const a = neighbors[0];
				const b = neighbors[1];
				isTurn = !((a.dx === -b.dx) && (a.dy === -b.dy));
			}
			nodeByIndex.set(index, {
				index,
				x,
				y,
				neighbors,
				degree: neighbors.length,
				touchesRoad: hasRoadAttachment(x, y),
				isTurn,
				crossesTileSeam: seam,
				inTwoByTwoBlock: hasTwoByTwoBlock(mask, x, y),
			});
		}
		return nodeByIndex;
	}

	function countMaskComponents(mask) {
		const seen = new Uint8Array(mask.length);
		let groups = 0;
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index] || seen[index]) continue;
			groups += 1;
			const queue = [index];
			seen[index] = 1;
			while (queue.length > 0) {
				const current = queue.pop();
				for (const neighbor of buildNodeGraph(mask).get(current)?.neighbors || []) {
					if (seen[neighbor.index]) continue;
					seen[neighbor.index] = 1;
					queue.push(neighbor.index);
				}
			}
		}
		return groups;
	}

	function countOrphanMaskComponents(mask) {
		const nodeByIndex = buildNodeGraph(mask);
		const seen = new Uint8Array(mask.length);
		let groups = 0;
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index] || seen[index]) continue;
			const queue = [index];
			seen[index] = 1;
			let touchesRoad = false;
			while (queue.length > 0) {
				const current = queue.pop();
				if (nodeByIndex.get(current)?.touchesRoad) touchesRoad = true;
				for (const neighbor of nodeByIndex.get(current)?.neighbors || []) {
					if (seen[neighbor.index]) continue;
					seen[neighbor.index] = 1;
					queue.push(neighbor.index);
				}
			}
			if (!touchesRoad) groups += 1;
		}
		return groups;
	}

	function classifyCandidates(mask) {
		const nodeByIndex = buildNodeGraph(mask);
		const pixelsByCell = new Map();
		for (let index = 0; index < mask.length; index++) {
			if (!mask[index]) continue;
			const key = cellKeyForIndex(index);
			if (!pixelsByCell.has(key)) pixelsByCell.set(key, []);
			pixelsByCell.get(key).push(index);
		}

		const candidates = [];
		for (const [key, cellPixels] of pixelsByCell) {
			const [cellX, cellY] = key.split(',').map(Number);
			const cellContainsRoadOrMarker = cellHasRoadOrMarker(cellX, cellY);
			const { x0, y0, x1, y1 } = cellRect(cellX, cellY);
			const localSeen = new Set();
			for (const startIndex of cellPixels) {
				if (localSeen.has(startIndex)) continue;
				const queue = [startIndex];
				localSeen.add(startIndex);
				const localComponent = [];
				while (queue.length > 0) {
					const current = queue.pop();
					localComponent.push(current);
					for (const neighbor of nodeByIndex.get(current)?.neighbors || []) {
						if (cellKeyForIndex(neighbor.index) !== key) continue;
						if (localSeen.has(neighbor.index)) continue;
						localSeen.add(neighbor.index);
						queue.push(neighbor.index);
					}
				}

				const outsideNeighborIndices = new Set();
				let originalOutsideNeighborCount = 0;
				let minX = cleaned.width;
				let maxX = -1;
				let minY = cleaned.height;
				let maxY = -1;
				let hasBranch = false;
				let endpointCount = 0;
				const boundaryContacts = [];
				let boundaryEdgeMask = 0;
				let roadTouchCount = 0;
				for (const pixelIndex of localComponent) {
					const node = nodeByIndex.get(pixelIndex);
					const x = pixelIndex % cleaned.width;
					const y = Math.floor(pixelIndex / cleaned.width);
					if (x < minX) minX = x;
					if (x > maxX) maxX = x;
					if (y < minY) minY = y;
					if (y > maxY) maxY = y;
					if (node.touchesRoad) roadTouchCount += 1;
					let localDegree = 0;
					let touchesOutside = false;
					for (const neighbor of node.neighbors) {
						if (cellKeyForIndex(neighbor.index) === key) {
							localDegree += 1;
						} else {
							originalOutsideNeighborCount += 1;
							outsideNeighborIndices.add(neighbor.index);
							touchesOutside = true;
						}
					}
					if (localDegree > 2) hasBranch = true;
					if (localDegree <= 1) endpointCount += 1;
					if (!touchesOutside) continue;
					boundaryContacts.push(pixelIndex);
					if (x === x0) boundaryEdgeMask |= 1;
					if (x === x1) boundaryEdgeMask |= 2;
					if (y === y0) boundaryEdgeMask |= 4;
					if (y === y1) boundaryEdgeMask |= 8;
				}

				const blockedSet = new Set(localComponent);
				const groups = outsideNeighborIndices.size > 0 ? externalGroupCount(outsideNeighborIndices, blockedSet, nodeByIndex) : 0;
				const simplePath = !hasBranch && endpointCount === 2;
				const monotoneRun = simplePath && ((minX === maxX) || (minY === maxY));
				const diagonalRun = simplePath && !monotoneRun;
				const hasCornerAnchor = boundaryContacts.some(pixelIndex => {
					const node = nodeByIndex.get(pixelIndex);
					if (node.isTurn || node.crossesTileSeam || node.inTwoByTwoBlock) return true;
					return node.neighbors.some(neighbor => {
						if (cellKeyForIndex(neighbor.index) === key) return false;
						const outside = nodeByIndex.get(neighbor.index);
						return outside && (outside.isTurn || outside.crossesTileSeam || outside.inTwoByTwoBlock || outside.degree >= 3);
					});
				});
				const anchoredContinuation = groups === 1
					&& monotoneRun
					&& popcount4(boundaryEdgeMask) === 1
					&& hasCornerAnchor
					&& localComponent.length <= 5;
				const strictAnchoredContinuation = anchoredContinuation && roadTouchCount === 0;
				const componentTouchesRoad = roadTouchCount > 0;
				const narrowStrip = (maxX - minX) <= 1 || (maxY - minY) <= 1;
				const spansOppositeEdges = ((boundaryEdgeMask & 0x5) === 0x5) || ((boundaryEdgeMask & 0xA) === 0xA);
				const roadAdjacentStrip = componentTouchesRoad
					&& !cellContainsRoadOrMarker
					&& narrowStrip
					&& spansOppositeEdges
					&& localComponent.length >= 8
					&& groups === 1;
				const lowerTailSplitRun = componentTouchesRoad
					&& diagonalRun
					&& localComponent.length >= 8
					&& minY >= (cleaned.height - 24)
					&& maxY >= (cleaned.height - 8)
					&& groups < 2
					&& !hasCornerAnchor;
				const tinyNonBridgingStub = localComponent.length === 1
					|| (localComponent.length < 4 && popcount4(boundaryEdgeMask) < 2);

				let type = null;
				if (cellContainsRoadOrMarker) {
					// Mixed-cell spur: detached outline-only residue inside a road-bearing cell.
					if (outsideNeighborIndices.size === 0 && originalOutsideNeighborCount === 0 && roadTouchCount > 0 && localComponent.length <= 4) type = 'mixed_cell_spur';
				} else if (lowerTailSplitRun) {
					// Road-adjacent split tail border: removable when it forms an extra contour run
					// along the lower tail instead of contributing to the main outer/inner loops.
					type = 'road_adjacent_split_tail';
				} else if (roadAdjacentStrip) {
					// Road-adjacent narrow strip in an otherwise empty cell: removable when it
					// creates a duplicate contour lane that the remaining contour already supports.
					type = 'road_adjacent_strip';
				} else if (componentTouchesRoad && anchoredContinuation) {
					// Legal seam continuation: keep road-touching empty-cell bridges/tapers.
					type = null;
				} else if (!strictAnchoredContinuation && tinyNonBridgingStub) {
					// Tiny empty-cell stub: removable if it does not improve contour connectivity.
					type = 'roadless_tiny_stub';
				} else if (outsideNeighborIndices.size === 0) {
					// Orphan outline island in a roadless cell.
					type = 'roadless_orphan';
				} else if (outsideNeighborIndices.size === 1) {
					// Single-handoff roadless tail.
					if (!strictAnchoredContinuation) type = 'roadless_tail';
				} else if (groups < 2 && !strictAnchoredContinuation) {
					// Multi-pixel roadless fragment that still collapses to a single external group.
					type = 'roadless_illegal';
				}

				if (!type) continue;
				candidates.push({ type, pixels: localComponent, size: localComponent.length });
			}
		}

		candidates.sort((a, b) => {
			const priority = type => {
				if (type === 'roadless_orphan') return 0;
				if (type === 'roadless_tiny_stub') return 1;
				if (type === 'roadless_tail') return 2;
				if (type === 'roadless_illegal') return 3;
				if (type === 'road_adjacent_split_tail') return 4;
				if (type === 'road_adjacent_strip') return 5;
				return 6;
			};
			return priority(a.type) - priority(b.type) || a.size - b.size;
		});
		return candidates;
	}

	function buildMetrics(mask) {
		const candidates = classifyCandidates(mask);
		return {
			components: countMaskComponents(mask),
			orphans: countOrphanMaskComponents(mask),
			issues: candidates.filter(candidate => candidate.type !== 'mixed_cell_spur').length,
			candidates,
		};
	}

	let currentMask = Uint8Array.from(initialMask);
	let currentMetrics = buildMetrics(currentMask);
	if (currentMetrics.issues === 0 && currentMetrics.orphans === 0 && currentMetrics.components <= 2) return finalizeContourCleanup(cleaned);

	let changed = true;
	while (changed) {
		changed = false;
		for (const candidate of currentMetrics.candidates) {
			const nextMask = Uint8Array.from(currentMask);
			for (const pixelIndex of candidate.pixels) nextMask[pixelIndex] = 0;
			const nextMetrics = buildMetrics(nextMask);
			if (nextMetrics.issues > currentMetrics.issues) continue;
			if (nextMetrics.orphans > currentMetrics.orphans) continue;
			const improvesTopology = nextMetrics.issues < currentMetrics.issues || nextMetrics.orphans < currentMetrics.orphans;
			if (nextMetrics.components > currentMetrics.components) continue;
			const safeMixedCellCleanup = candidate.type === 'mixed_cell_spur'
				&& nextMetrics.issues === currentMetrics.issues
				&& nextMetrics.orphans === currentMetrics.orphans
				&& nextMetrics.components === currentMetrics.components;
			const safeRoadAdjacentStripCleanup = candidate.type === 'road_adjacent_strip'
				&& nextMetrics.orphans === currentMetrics.orphans
				&& nextMetrics.components <= currentMetrics.components;
			if (!improvesTopology && !safeMixedCellCleanup && !safeRoadAdjacentStripCleanup) continue;
			currentMask = nextMask;
			currentMetrics = nextMetrics;
			changed = true;
			break;
		}
	}

	for (let index = 0; index < initialMask.length; index++) {
		if (initialMask[index] && !currentMask[index]) cleaned.pixels[index] = 0;
	}
	// Final bounded safety check: only prune proven-illegal roadless single-handoff
	// fragments that survive direct emission, while refusing any removal that would
	// increase black contour component count.
	return finalizeContourCleanup(cleaned);
}

function applyStockOccupancyMask(preview, stockPreview) {
	return preview;
}

function buildAssetsCacheKey(track) {
	const previewProjection = getPreviewProjection(track);
	const geometryState = getGeneratedGeometryState(track);
	return JSON.stringify([
		track?.track_length || 0,
		track?.curve_rle_segments || [],
		previewProjection || null,
		geometryState?.projections?.slope?.grade_separated_crossing || null,
	]);
}

function sanitizeLabelFragment(value) {
	return String(value || '')
		.replace(/[^A-Za-z0-9]+/g, '_')
		.replace(/^_+|_+$/g, '')
		.replace(/_+/g, '_') || 'Track';
}

function resolvePreservedExternalCellIndexSet(previewSlug, config = PRESERVED_EXTERNAL_CELL_INDEX_CONFIG) {
	if (!previewSlug || !config || typeof config !== 'object') return new Set();
	const values = config[previewSlug];
	return Array.isArray(values) ? new Set(values) : new Set();
}

function isBlankTileRows(rows) {
	return rows.every(row => row.every(value => value === 0));
}

function cloneTileRows(rows) {
	return rows.map(row => row.slice());
}

function createBlankTileRows() {
	return Array.from({ length: 8 }, () => Array(8).fill(0));
}

function clonePreviewPixels(preview) {
	return Object.assign({}, preview, {
		pixels: Array.isArray(preview?.pixels) ? preview.pixels.slice() : [],
		road_pixels: Array.isArray(preview?.road_pixels) ? preview.road_pixels.slice() : null,
		start_marker_pixels: Array.isArray(preview?.start_marker_pixels) ? preview.start_marker_pixels.slice() : null,
	});
}

function buildTileSignature(rows) {
	return rows.map(row => row.join(',')).join('/');
}

function flipTileRows(rows, hFlip, vFlip) {
	const sourceRows = vFlip ? rows.slice().reverse() : rows;
	return sourceRows.map(row => hFlip ? row.slice().reverse() : row.slice());
}

function registerTileVariants(tileIndexBySignature, rows, word) {
	const variants = [
		{ rows, flags: 0 },
		{ rows: flipTileRows(rows, true, false), flags: 0x0800 },
		{ rows: flipTileRows(rows, false, true), flags: 0x1000 },
		{ rows: flipTileRows(rows, true, true), flags: 0x1800 },
	];
	for (const variant of variants) {
		const signature = buildTileSignature(variant.rows);
		if (!tileIndexBySignature.has(signature)) {
			tileIndexBySignature.set(signature, word | variant.flags);
		}
	}
}

function registerTileVariantCandidates(candidates, rows, word) {
	const variants = [
		{ rows, flags: 0 },
		{ rows: flipTileRows(rows, true, false), flags: 0x0800 },
		{ rows: flipTileRows(rows, false, true), flags: 0x1000 },
		{ rows: flipTileRows(rows, true, true), flags: 0x1800 },
	];
	for (const variant of variants) {
		candidates.push({
			rows: variant.rows,
			word: word | variant.flags,
		});
	}
}

function countTilePixelDifferences(rowsA, rowsB) {
	let diff = 0;
	for (let y = 0; y < 8; y++) {
		for (let x = 0; x < 8; x++) {
			if ((rowsA[y]?.[x] || 0) !== (rowsB[y]?.[x] || 0)) diff += 1;
		}
	}
	return diff;
}

function findClosestTileWord(rows, candidates) {
	let bestWord = 0;
	let bestDiff = Infinity;
	for (const candidate of candidates) {
		const diff = countTilePixelDifferences(rows, candidate.rows);
		if (diff >= bestDiff) continue;
		bestDiff = diff;
		bestWord = candidate.word;
		if (diff === 0) break;
	}
	return bestWord;
}

function buildWordRows(word, tiles) {
	const tileIndex = word & MINIMAP_TILE_INDEX_MASK;
	if (tileIndex <= 0) return createBlankTileRows();
	const rows = cloneTileRows(tiles[tileIndex - 1] || createBlankTileRows());
	return flipTileRows(rows, !!(word & 0x0800), !!(word & 0x1000));
}

function reduceCourseSelectTileBudget(tiles, words, maxTileCount, reservedLocalTileIndices) {
	if (!Number.isInteger(maxTileCount) || maxTileCount <= 0 || tiles.length <= maxTileCount) {
		return { tiles, words };
	}

	const reservedTileIds = new Set(Array.from(reservedLocalTileIndices || []).map(index => index + 1));
	const availableSlots = [];
	for (let tileId = 1; tileId <= maxTileCount; tileId++) {
		if (!reservedTileIds.has(tileId)) availableSlots.push(tileId);
	}

	const sourceWordCounts = new Map();
	const representativeIds = new Set();
	for (const word of words) {
		const sourceWord = word & 0xFFFF;
		const tileId = sourceWord & MINIMAP_TILE_INDEX_MASK;
		if (tileId === 0 || reservedTileIds.has(tileId)) continue;
		sourceWordCounts.set(sourceWord, (sourceWordCounts.get(sourceWord) || 0) + 1);
		representativeIds.add(tileId);
	}

	const sourceWords = Array.from(sourceWordCounts.keys());
	if (representativeIds.size === 0) {
		return {
			tiles: tiles.slice(0, maxTileCount),
			words,
		};
	}

	const sourceWordRows = new Map(sourceWords.map(word => [word, buildWordRows(word, tiles)]));
	const relationCache = new Map();
	const bestRelation = (sourceWord, representativeId) => {
		const key = `${sourceWord}:${representativeId}`;
		if (relationCache.has(key)) return relationCache.get(key);
		const sourceRows = sourceWordRows.get(sourceWord) || createBlankTileRows();
		const targetRows = tiles[representativeId - 1] || createBlankTileRows();
		let best = { representativeId, flags: 0, cost: Infinity };
			for (const flags of [0, 0x0800, 0x1000, 0x1800]) {
				const candidateRows = flipTileRows(targetRows, !!(flags & 0x0800), !!(flags & 0x1000));
			const cost = countTilePixelDifferences(sourceRows, candidateRows);
			if (cost >= best.cost) continue;
			best = { representativeId, flags, cost };
			if (cost === 0) break;
		}
		relationCache.set(key, best);
		return best;
	};

	let activeRepresentatives = new Set(representativeIds);
	const assignments = new Map();
	const recomputeAssignments = (excludedRepresentativeId = null) => {
		const next = new Map();
		for (const sourceWord of sourceWords) {
			let best = null;
			for (const representativeId of activeRepresentatives) {
				if (representativeId === excludedRepresentativeId) continue;
				const relation = bestRelation(sourceWord, representativeId);
				if (best && relation.cost >= best.cost) continue;
				best = relation;
			}
			if (best) next.set(sourceWord, best);
		}
		return next;
	};

	for (const [sourceWord, relation] of recomputeAssignments()) assignments.set(sourceWord, relation);

	while (activeRepresentatives.size > availableSlots.length) {
		let bestRemovalId = null;
		let bestRemovalCost = Infinity;
		for (const representativeId of activeRepresentatives) {
			let removalCost = 0;
			let impossible = false;
			const alternativeAssignments = recomputeAssignments(representativeId);
			for (const sourceWord of sourceWords) {
				const current = assignments.get(sourceWord);
				if (!current || current.representativeId !== representativeId) continue;
				const alternative = alternativeAssignments.get(sourceWord);
				if (!alternative) {
					impossible = true;
					break;
				}
				removalCost += (alternative.cost - current.cost) * (sourceWordCounts.get(sourceWord) || 1);
			}
			if (impossible || removalCost > bestRemovalCost) continue;
			if (removalCost === bestRemovalCost && bestRemovalId !== null && representativeId < bestRemovalId) continue;
			bestRemovalId = representativeId;
			bestRemovalCost = removalCost;
		}
		if (bestRemovalId === null) break;
		activeRepresentatives.delete(bestRemovalId);
		assignments.clear();
		for (const [sourceWord, relation] of recomputeAssignments()) assignments.set(sourceWord, relation);
	}

	const slotByRepresentative = new Map();
	const freeSlots = new Set(availableSlots);
	for (const representativeId of Array.from(activeRepresentatives).sort((a, b) => a - b)) {
		if (!freeSlots.has(representativeId)) continue;
		slotByRepresentative.set(representativeId, representativeId);
		freeSlots.delete(representativeId);
	}
	for (const representativeId of Array.from(activeRepresentatives).sort((a, b) => a - b)) {
		if (slotByRepresentative.has(representativeId)) continue;
		const [slot] = freeSlots;
		if (slot === undefined) break;
		slotByRepresentative.set(representativeId, slot);
		freeSlots.delete(slot);
	}

	const reducedTiles = Array.from({ length: maxTileCount }, () => createBlankTileRows());
	for (const reservedTileId of reservedTileIds) {
		if (reservedTileId <= 0 || reservedTileId > maxTileCount) continue;
		reducedTiles[reservedTileId - 1] = cloneTileRows(tiles[reservedTileId - 1] || createBlankTileRows());
	}
	for (const representativeId of activeRepresentatives) {
		const slot = slotByRepresentative.get(representativeId);
		if (!slot) continue;
		reducedTiles[slot - 1] = cloneTileRows(tiles[representativeId - 1] || createBlankTileRows());
	}

	const replacementWords = new Map();
	for (const sourceWord of sourceWords) {
		const assignment = assignments.get(sourceWord);
		if (!assignment) continue;
		const slot = slotByRepresentative.get(assignment.representativeId);
		if (!slot) continue;
		replacementWords.set(sourceWord, (slot & MINIMAP_TILE_INDEX_MASK) | assignment.flags);
	}

	const reducedWords = words.map(word => {
		const sourceWord = word & 0xFFFF;
		const tileId = sourceWord & MINIMAP_TILE_INDEX_MASK;
		if (tileId === 0 || reservedTileIds.has(tileId)) return word;
		return replacementWords.get(sourceWord) || word;
	});

	return {
		tiles: reducedTiles,
		words: reducedWords,
	};
}

function buildTilesAndWordsFromPreview(preview, stockPreview = null, previewSlug = '', options = {}) {
	const tiles = [];
	const words = [];
	const tileIndexBySignature = new Map();
	const stockWords = Array.isArray(stockPreview?.words) ? stockPreview.words : null;
	const stockTiles = Array.isArray(stockPreview?.tiles) ? stockPreview.tiles : null;
	const stockTileCount = Number.isInteger(stockPreview?.tile_count) ? stockPreview.tile_count : (stockTiles ? stockTiles.length : 0);
	const restrictToStockOccupiedCells = options.restrictToStockOccupiedCells === true;
	const preservedExternalCellIndices = options.preservedExternalCellIndices instanceof Set
		? options.preservedExternalCellIndices
		: resolvePreservedExternalCellIndexSet(previewSlug, options.preservedExternalCellIndexConfig);
	const reservedLocalTileIndices = options.reservedLocalTileIndices instanceof Set
		? options.reservedLocalTileIndices
		: new Set();
	const maxTileCount = Number.isInteger(options.maxTileCount) && options.maxTileCount > 0
		? options.maxTileCount
		: Infinity;

	function ensureTileIndex(localIndex, rows) {
		while (tiles.length < localIndex) tiles.push(createBlankTileRows());
		tiles[localIndex - 1] = cloneTileRows(rows);
		registerTileVariants(tileIndexBySignature, rows, localIndex & MINIMAP_TILE_INDEX_MASK);
	}

	const availableGeneratedLocalIndices = [];
	if (stockTiles && reservedLocalTileIndices.size > 0) {
		for (const reservedLocalIndex of reservedLocalTileIndices) {
			if (reservedLocalIndex < 0 || reservedLocalIndex >= stockTiles.length) continue;
			ensureTileIndex(reservedLocalIndex + 1, stockTiles[reservedLocalIndex]);
		}
	}
	if (stockPreview && stockTileCount > 0) {
		for (let localIndex = 0; localIndex < stockTileCount; localIndex++) {
			if (reservedLocalTileIndices.has(localIndex)) continue;
			availableGeneratedLocalIndices.push(localIndex + 1);
		}
	}
	let nextGeneratedLocalIndex = stockTileCount > 0 ? (stockTileCount + 1) : 1;
	function allocateGeneratedLocalIndex() {
		if (availableGeneratedLocalIndices.length > 0) return availableGeneratedLocalIndices.shift();
		while (reservedLocalTileIndices.has(nextGeneratedLocalIndex - 1)) nextGeneratedLocalIndex += 1;
		const localIndex = nextGeneratedLocalIndex;
		nextGeneratedLocalIndex += 1;
		return localIndex;
	}

	for (let tileY = 0; tileY < MINIMAP_PANEL_TILES_H; tileY++) {
		for (let tileX = 0; tileX < MINIMAP_PANEL_TILES_W; tileX++) {
			const cellIndex = (tileY * MINIMAP_PANEL_TILES_W) + tileX;
			const stockWord = stockWords && cellIndex < stockWords.length ? (stockWords[cellIndex] & 0xFFFF) : null;
			if (restrictToStockOccupiedCells && stockWord === 0) {
				words.push(0);
				continue;
			}

			const rows = [];
			for (let y = 0; y < MINIMAP_TILE_SIZE_PX; y++) {
				const row = [];
				for (let x = 0; x < MINIMAP_TILE_SIZE_PX; x++) {
					const px = tileX * MINIMAP_TILE_SIZE_PX + x;
					const py = tileY * MINIMAP_TILE_SIZE_PX + y;
					row.push(preview.pixels[(py * preview.width) + px] || 0);
				}
				rows.push(row);
			}

			const preserveExternalStockCell = stockWord !== null
				&& preservedExternalCellIndices.has(cellIndex)
				&& isBlankTileRows(rows);
			if (preserveExternalStockCell) {
				words.push(stockWord);
				continue;
			}

			const signature = buildTileSignature(rows);
			const isBlankTile = isBlankTileRows(rows);

			if (isBlankTile) {
				words.push(0);
				continue;
			}
			if (tileIndexBySignature.has(signature)) {
				words.push(tileIndexBySignature.get(signature));
				continue;
			}

			const generatedLocalIndex = allocateGeneratedLocalIndex();
			ensureTileIndex(generatedLocalIndex, rows);
			const generatedWord = generatedLocalIndex & MINIMAP_TILE_INDEX_MASK;
			words.push(generatedWord);
		}
	}

	return reduceCourseSelectTileBudget(tiles, words, maxTileCount, reservedLocalTileIndices);
}

function buildGeneratedMinimapAssetsFromPreviews(preview, stockPreview, previewSlug = '', options = {}) {
	let assetPreview = preview;
	const generated = buildTilesAndWordsFromPreview(assetPreview, stockPreview, previewSlug, options);
	const tiles = generated.tiles.slice();
	const words = generated.words.slice();
	while (tiles.length > 0 && isBlankTileRows(tiles[tiles.length - 1])) tiles.pop();
	const maxWord = words.reduce((max, word) => Math.max(max, word & 0xFFFF), 0);
	const bitWidth = Math.max(1, Math.ceil(Math.log2(Math.max(2, maxWord + 1))));
	return {
		preview,
		tiles,
		words,
		tile_bytes: Buffer.from(encodeTinyGraphics(tiles)),
		map_bytes: Buffer.from(encodeLiteralTilemap(words, bitWidth)),
	};
}

function buildGeneratedMinimapAssets(track) {
	const cacheKey = buildAssetsCacheKey(track);
	const cached = generatedAssetsCache.get(track);
	if (cached && cached.key === cacheKey) return cached.value;
	const previewProjection = getPreviewProjection(track);
	let preview = buildAssetPreview(track, previewProjection || buildGeneratedMinimapPreview(track));
	const previewSlug = resolvePreviewSlug(track);
	const stockPreview = previewProjection ? null : getMinimapPreview(previewSlug);
	const reservedLocalTileIndices = stockPreview
		? getCourseSelectReservedLocalTileIndices(track?.index, stockPreview.tiles.length)
		: new Set();
	const result = buildGeneratedMinimapAssetsFromPreviews(preview, stockPreview, previewSlug, {
		startMarkerPixels: Array.isArray(preview.start_marker_pixels) ? preview.start_marker_pixels : null,
		maxTileCount: isRuntimeSafeRandomized(track) ? COURSE_SELECT_PREVIEW_TILE_BUDGET : undefined,
		reservedLocalTileIndices,
	});
	generatedAssetsCache.set(track, { key: cacheKey, value: result });
	return result;
}

function buildGeneratedMinimapLabelStem(track) {
	const index = String(track.index).padStart(2, '0');
	const name = sanitizeLabelFragment(track.name || track.slug || `Track_${index}`);
	return `Generated_Minimap_Track_${index}_${name}`;
}

function buildGeneratedMinimapLabelMap(tracks) {
	const map = new Map();
	for (const track of tracks || []) {
		const stem = buildGeneratedMinimapLabelStem(track);
		map.set(track.index, {
			tiles: `${stem}_tiles`,
			map: `${stem}_map`,
		});
	}
	return map;
}

function buildGeneratedMinimapAssetsAsm(tracks) {
	const lines = [];
	const labelsByTrackIndex = buildGeneratedMinimapLabelMap(tracks);

	for (const track of tracks || []) {
		const labels = labelsByTrackIndex.get(track.index);
		const assets = buildGeneratedMinimapAssets(track);
		lines.push(`; ${track.name}`);
		lines.push(`${labels.tiles}:`);
		lines.push(...formatDcB(assets.tile_bytes));
		lines.push(`${labels.map}:`);
		lines.push(...formatDcB(assets.map_bytes));
	}

	return {
		content: lines.join('\n') + (lines.length ? '\n' : ''),
		labelsByTrackIndex,
	};
}

module.exports = {
	sanitizeLabelFragment,
	formatDcB,
	buildTilesAndWordsFromPreview,
	resolvePreservedExternalCellIndexSet,
	buildGeneratedMinimapAssetsFromPreviews,
	buildGeneratedMinimapAssets,
	COURSE_SELECT_PREVIEW_TILE_BUDGET,
	buildAssetPreview,
	emitLegalContourPreview,
	applyStockOccupancyMask,
	buildGeneratedMinimapLabelStem,
	buildGeneratedMinimapLabelMap,
	buildGeneratedMinimapAssetsAsm,
};
