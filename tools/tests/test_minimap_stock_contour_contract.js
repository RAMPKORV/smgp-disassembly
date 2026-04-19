#!/usr/bin/env node
'use strict';

const assert = require('assert');

const { loadTracksJson } = require('./randomizer_test_utils');
const { getTracks } = require('../randomizer/track_model');
const { resolvePreviewSlug } = require('../lib/minimap_analysis');
const { getMinimapPreview } = require('../lib/minimap_preview');

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed += 1;
	} catch (err) {
		failed += 1;
		console.error(`FAIL: ${name}`);
		console.error(`  ${err.message}`);
	}
}

function getStockPreviewSlugs() {
	return Array.from(new Set(getTracks(loadTracksJson()).map(resolvePreviewSlug)));
}

function collectOccupiedCells(preview) {
	const cells = [];
	for (let tileY = 0; tileY < 11; tileY++) {
		for (let tileX = 0; tileX < 7; tileX++) {
			let count = 0;
			let touchesLeft = false;
			let touchesRight = false;
			let touchesTop = false;
			let touchesBottom = false;
			for (let y = 0; y < 8; y++) {
				for (let x = 0; x < 8; x++) {
					const px = (tileX * 8) + x;
					const py = (tileY * 8) + y;
					if (!preview.pixels[(py * preview.width) + px]) continue;
					count += 1;
					if (x === 0) touchesLeft = true;
					if (x === 7) touchesRight = true;
					if (y === 0) touchesTop = true;
					if (y === 7) touchesBottom = true;
				}
			}
			if (!count) continue;
			cells.push({
				tileX,
				tileY,
				count,
				edgeMask: `${Number(touchesLeft)}${Number(touchesRight)}${Number(touchesTop)}${Number(touchesBottom)}`,
			});
		}
	}
	return cells;
}

function buildCellSignature(preview, tileX, tileY) {
	const rows = [];
	for (let y = 0; y < 8; y++) {
		let row = '';
		for (let x = 0; x < 8; x++) {
			const px = (tileX * 8) + x;
			const py = (tileY * 8) + y;
			row += preview.pixels[(py * preview.width) + px] ? '1' : '0';
		}
		rows.push(row);
	}
	return rows.join('/');
}

console.log('Section A: stock minimap contour contract');

test('stock previews use only dense occupied tile cells', () => {
	for (const slug of getStockPreviewSlugs()) {
		const preview = getMinimapPreview(slug);
		for (const cell of collectOccupiedCells(preview)) {
			assert.ok(cell.count >= 32, `${slug} has sparse occupied stock cell at (${cell.tileX},${cell.tileY}) with ${cell.count} pixels`);
		}
	}
});

test('stock occupied tile cells always touch left, right, and top edges', () => {
	for (const slug of getStockPreviewSlugs()) {
		const preview = getMinimapPreview(slug);
		for (const cell of collectOccupiedCells(preview)) {
			assert.ok(cell.edgeMask === '1110' || cell.edgeMask === '1111', `${slug} has non-stock cell edge mask ${cell.edgeMask} at (${cell.tileX},${cell.tileY})`);
		}
	}
});

test('stock occupied tile vocabulary stays small and explicit', () => {
	const signatures = new Set();
	for (const slug of getStockPreviewSlugs()) {
		const preview = getMinimapPreview(slug);
		for (const cell of collectOccupiedCells(preview)) signatures.add(buildCellSignature(preview, cell.tileX, cell.tileY));
	}
	assert.strictEqual(signatures.size, 12, `expected 12 stock occupied-cell signatures, got ${signatures.size}`);
});

test('stock previews include full bottom-edge cells, but never left/right/top-only variants', () => {
	let fullEdgeCells = 0;
	for (const slug of getStockPreviewSlugs()) {
		const preview = getMinimapPreview(slug);
		for (const cell of collectOccupiedCells(preview)) {
			if (cell.edgeMask === '1111') fullEdgeCells += 1;
		}
	}
	assert.ok(fullEdgeCells > 0, 'expected at least one stock cell touching all four edges');
	});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
