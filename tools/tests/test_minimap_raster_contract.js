#!/usr/bin/env node
'use strict';

const assert = require('assert');
const {
	convexCornerShelfRoadMaskPreview,
	straightWallShelfRoadMaskPreview,
	lowerSideResidueRoadMaskPreview,
} = require('./minimap_synthetic_fixtures');
const { renderStyledPixelsFromRoadMask } = require('../lib/minimap_raster');
const { buildAssetPreview } = require('../lib/generated_minimap_assets');

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed++;
	} catch (err) {
		failed++;
		console.error(`FAIL: ${name}`);
		console.error(`  ${err.message}`);
	}
}

function renderFromRoadPreview(preview) {
	return renderStyledPixelsFromRoadMask(Uint8Array.from(preview.road_pixels), preview.width, preview.height).pixels;
}

function countNonZeroInRect(pixels, width, x0, y0, x1, y1) {
	let count = 0;
	for (let y = y0; y <= y1; y++) {
		for (let x = x0; x <= x1; x++) {
			if (pixels[(y * width) + x]) count += 1;
		}
	}
	return count;
}

function countValueInRect(pixels, width, x0, y0, x1, y1, value) {
	let count = 0;
	for (let y = y0; y <= y1; y++) {
		for (let x = x0; x <= x1; x++) {
			if (pixels[(y * width) + x] === value) count += 1;
		}
	}
	return count;
}

console.log('Section A: minimap raster contract');

test('synthetic convex corner does not keep a fat rectangular shelf above the vertical wall', () => {
	const preview = convexCornerShelfRoadMaskPreview();
	const pixels = renderFromRoadPreview(preview);
	assert.strictEqual(countValueInRect(pixels, preview.width, 22, 11, 29, 12, 1), 0, 'convex corner should not emit a top rectangular black shelf band');
});

test('synthetic straight wall does not emit a rectangular side shelf detached from the bend transition', () => {
	const preview = straightWallShelfRoadMaskPreview();
	const pixels = renderFromRoadPreview(preview);
	assert.strictEqual(countValueInRect(pixels, preview.width, 24, 21, 25, 30, 1), 0, 'straight wall should not grow an extra right-side black shelf column through the inner run');
});

test('asset preview removes lower-side residue that remains outside the main road body', () => {
	const preview = lowerSideResidueRoadMaskPreview();
	const rebuilt = buildAssetPreview({ slug: 'synthetic_lower_residue' }, preview);
	assert.strictEqual(countNonZeroInRect(rebuilt.pixels, rebuilt.width, 16, 37, 18, 40), 0, 'lower-side residue should be removed from the rebuilt asset preview');
});

if (failed > 0) {
	console.error(`\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total`);
	process.exit(1);
}

console.log(`\nResults: ${passed} passed, 0 failed, ${passed} total`);
