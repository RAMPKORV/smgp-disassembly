'use strict';

function rectangleLoop() {
	return [[0, 0], [4, 0], [4, 4], [0, 4]];
}

function anticlockwiseRectangleLoop() {
	return [[0, 0], [0, 4], [4, 4], [4, 0]];
}

function zigzagLoop() {
	return [[0, 0], [4, 0], [1, 2], [4, 4], [0, 4], [3, 2]];
}

function previewSpaceRectangle() {
	return [[10, 10], [20, 10], [20, 20], [10, 20]];
}

function rightSideThicknessRectangleLoop() {
	return [[14, 14], [32, 14], [32, 32], [14, 32]];
}

function rightSideThicknessBendLoop() {
	return [[14, 14], [30, 14], [30, 24], [24, 24], [24, 32], [14, 32]];
}

function createRoadPreview(width = 56, height = 88) {
	return {
		width,
		height,
		pixels: Array.from({ length: width * height }, () => 0),
		road_pixels: Array.from({ length: width * height }, () => 0),
		start_marker_pixels: Array.from({ length: width * height }, () => 0),
	};
}

function convexCornerShelfRoadMaskPreview() {
	const preview = createRoadPreview();
	preview.centerline_points = [[24, 14], [31, 14], [31, 23], [28, 23], [28, 16], [24, 16]];
	fillRect(preview.road_pixels, preview.width, 24, 13, 31, 15);
	fillRect(preview.road_pixels, preview.width, 28, 16, 31, 23);
	preview.pixels = preview.road_pixels.slice();
	return preview;
}

function straightWallShelfRoadMaskPreview() {
	const preview = createRoadPreview();
	preview.centerline_points = [[16, 12], [23, 12], [23, 34], [20, 34], [20, 21], [16, 21]];
	fillRect(preview.road_pixels, preview.width, 16, 12, 23, 20);
	fillRect(preview.road_pixels, preview.width, 20, 21, 23, 34);
	preview.pixels = preview.road_pixels.slice();
	return preview;
}

function lowerSideResidueRoadMaskPreview() {
	const preview = createRoadPreview();
	preview.centerline_points = [[18, 18], [24, 18], [24, 36], [18, 36]];
	fillRect(preview.road_pixels, preview.width, 18, 18, 24, 24);
	fillRect(preview.road_pixels, preview.width, 18, 25, 21, 36);
	preview.pixels = preview.road_pixels.slice();
	preview.pixels[(38 * preview.width) + 17] = 1;
	preview.pixels[(39 * preview.width) + 17] = 1;
	return preview;
}

function simpleRightCurveTrack() {
	return {
		track_length: 32,
		curve_rle_segments: [{ type: 'curve', curve_byte: 0x45, length: 8 }],
	};
}

function simpleLeftCurveTrack() {
	return {
		track_length: 32,
		curve_rle_segments: [{ type: 'curve', curve_byte: 0x05, length: 8 }],
	};
}

function repeatedRightCurveTrack() {
	return {
		track_length: 64,
		curve_rle_segments: [
			{ type: 'curve', curve_byte: 0x45, length: 16 },
			{ type: 'curve', curve_byte: 0x45, length: 16 },
			{ type: 'curve', curve_byte: 0x45, length: 16 },
			{ type: 'curve', curve_byte: 0x45, length: 16 },
		],
	};
}

function createBlankTile(value = 0) {
	return Array.from({ length: 8 }, () => Array.from({ length: 8 }, () => value));
}

function createPreview(width = 56, height = 88) {
	return {
		width,
		height,
		pixels: Array.from({ length: width * height }, () => 0),
	};
}

function stampTile(preview, tileX, tileY, tileRows) {
	for (let y = 0; y < 8; y++) {
		for (let x = 0; x < 8; x++) {
			const px = (tileX * 8) + x;
			const py = (tileY * 8) + y;
			preview.pixels[(py * preview.width) + px] = tileRows[y][x];
		}
	}
}

function fillRect(buffer, width, x0, y0, x1, y1, value = 1) {
	for (let y = y0; y <= y1; y++) {
		for (let x = x0; x <= x1; x++) {
			buffer[(y * width) + x] = value;
		}
	}
}

function monacoOutlineBridgePreview() {
	const preview = createPreview();
	preview.centerline_points = [[24, 18], [29, 24], [29, 42], [18, 42], [18, 30]];
	preview.road_pixels = Array(preview.width * preview.height).fill(0);
	preview.start_marker_pixels = Array(preview.width * preview.height).fill(0);

	fillRect(preview.road_pixels, preview.width, 20, 18, 29, 19);
	fillRect(preview.road_pixels, preview.width, 28, 20, 29, 41);
	fillRect(preview.road_pixels, preview.width, 18, 28, 19, 41);
	fillRect(preview.road_pixels, preview.width, 18, 42, 27, 43);

	preview.pixels = preview.road_pixels.slice();
	fillRect(preview.pixels, preview.width, 19, 17, 30, 20);
	fillRect(preview.pixels, preview.width, 27, 19, 31, 42);
	fillRect(preview.pixels, preview.width, 16, 27, 20, 42);
	fillRect(preview.pixels, preview.width, 17, 41, 28, 44);

	fillRect(preview.pixels, preview.width, 32, 18, 32, 22);
	fillRect(preview.pixels, preview.width, 15, 34, 15, 38);
	fillRect(preview.pixels, preview.width, 32, 41, 32, 44);

	return preview;
}

function isolatedOutlineSpurPreview() {
	const preview = createPreview();
	preview.centerline_points = [[16, 16], [24, 16], [24, 24], [16, 24]];
	preview.road_pixels = Array(preview.width * preview.height).fill(0);
	preview.start_marker_pixels = Array(preview.width * preview.height).fill(0);

	fillRect(preview.road_pixels, preview.width, 16, 16, 23, 23);
	preview.pixels = preview.road_pixels.slice();
	fillRect(preview.pixels, preview.width, 24, 18, 24, 20);

	return preview;
}

function mixedCellOutlineSpurPreview() {
	const preview = createPreview();
	preview.centerline_points = [[16, 16], [24, 16], [24, 24], [16, 24]];
	preview.road_pixels = Array(preview.width * preview.height).fill(0);
	preview.start_marker_pixels = Array(preview.width * preview.height).fill(0);

	fillRect(preview.road_pixels, preview.width, 16, 16, 19, 23);
	preview.pixels = preview.road_pixels.slice();
	fillRect(preview.pixels, preview.width, 20, 18, 20, 20);

	return preview;
}

function narrowSeamBridgePreview() {
	const preview = createPreview();
	preview.centerline_points = [[16, 16], [24, 16], [24, 24], [16, 24]];
	preview.road_pixels = Array(preview.width * preview.height).fill(0);
	preview.start_marker_pixels = Array(preview.width * preview.height).fill(0);

	fillRect(preview.road_pixels, preview.width, 18, 18, 21, 21);
	preview.pixels = preview.road_pixels.slice();
	fillRect(preview.pixels, preview.width, 22, 19, 23, 19);
	fillRect(preview.pixels, preview.width, 24, 19, 24, 21);

	return preview;
}

function bottomAttachedStubWithOrphansPreview() {
	const preview = createPreview();
	preview.centerline_points = [[20, 20], [28, 20], [28, 38], [20, 38], [20, 28]];
	preview.road_pixels = Array(preview.width * preview.height).fill(0);
	preview.start_marker_pixels = Array(preview.width * preview.height).fill(0);

	fillRect(preview.road_pixels, preview.width, 20, 20, 27, 21);
	fillRect(preview.road_pixels, preview.width, 26, 22, 27, 37);
	fillRect(preview.road_pixels, preview.width, 20, 30, 21, 37);
	fillRect(preview.road_pixels, preview.width, 20, 36, 25, 37);

	preview.pixels = preview.road_pixels.slice();
	fillRect(preview.pixels, preview.width, 19, 19, 28, 22);
	fillRect(preview.pixels, preview.width, 25, 21, 29, 37);
	fillRect(preview.pixels, preview.width, 18, 29, 22, 37);
	fillRect(preview.pixels, preview.width, 19, 35, 26, 39);

	fillRect(preview.pixels, preview.width, 20, 40, 20, 43);
	preview.pixels[(42 * preview.width) + 12] = 1;
	preview.pixels[(42 * preview.width) + 28] = 1;

	return preview;
}

function createStockPreview(tileCount, previewTileCount = 77) {
	return {
		tiles: Array.from({ length: tileCount }, (_, index) => createBlankTile((index + 1) & 0x0F)),
		words: Array.from({ length: previewTileCount }, () => 0),
	};
}

function sparsePreview(width = 56, height = 88) {
	const preview = createPreview(width, height);
	preview.pixels[0] = 1;
	preview.pixels[(height - 1) * width + (width - 1)] = 1;
	return preview;
}

function degeneratePreview(width = 56, height = 88) {
	const preview = createPreview(width, height);
	for (let y = 0; y < height; y++) {
		preview.pixels[(y * width) + Math.floor(width / 2)] = 1;
	}
	return preview;
}

function wraparoundUnsafeTrack(trackLength = 4096) {
	const steps = trackLength / 4;
	return {
		name: 'Wraparound Unsafe',
		slug: 'wraparound_unsafe',
		index: 0,
		track_length: trackLength,
		slope_initial_bg_disp: 0,
		curve_rle_segments: [
			{ type: 'straight', length: steps, curve_byte: 0 },
			{ type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] },
		],
		slope_rle_segments: [
			{ type: 'flat', length: steps, slope_byte: 0, bg_vert_disp: 0 },
			{ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF, 0x00] },
		],
		phys_slope_rle_segments: [
			{ type: 'segment', length: steps, phys_byte: 0 },
			{ type: 'terminator', length: 0, phys_byte: 0, _raw: [0x80, 0x00, 0x00] },
		],
		sign_data: [{ distance: 64, count: 2, sign_id: 28 }],
		sign_tileset: [
			{ distance: 0, tileset_offset: 8 },
			{ distance: trackLength - 196, tileset_offset: 16 },
		],
		minimap_pos: Array.from({ length: trackLength >> 6 }, (_, index) => [index % 32, (index * 2) % 32]),
	};
}

module.exports = {
	rectangleLoop,
	anticlockwiseRectangleLoop,
	zigzagLoop,
	previewSpaceRectangle,
	rightSideThicknessRectangleLoop,
	rightSideThicknessBendLoop,
	createRoadPreview,
	convexCornerShelfRoadMaskPreview,
	straightWallShelfRoadMaskPreview,
	lowerSideResidueRoadMaskPreview,
	simpleRightCurveTrack,
	simpleLeftCurveTrack,
	repeatedRightCurveTrack,
	createBlankTile,
	createPreview,
	stampTile,
	fillRect,
	bottomAttachedStubWithOrphansPreview,
	mixedCellOutlineSpurPreview,
	narrowSeamBridgePreview,
	monacoOutlineBridgePreview,
	isolatedOutlineSpurPreview,
	createStockPreview,
	sparsePreview,
	degeneratePreview,
	wraparoundUnsafeTrack,
};
