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
	simpleRightCurveTrack,
	simpleLeftCurveTrack,
	repeatedRightCurveTrack,
	createBlankTile,
	createPreview,
	stampTile,
	createStockPreview,
	sparsePreview,
	degeneratePreview,
	wraparoundUnsafeTrack,
};
