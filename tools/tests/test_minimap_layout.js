#!/usr/bin/env node
'use strict';

const assert = require('assert');

const {
	MINIMAP_PANEL_PX_H,
	MINIMAP_PANEL_PX_W,
	MAP_FIRST_CANVAS_MARGIN_PX,
	buildMapFirstCanvas,
} = require('../lib/minimap_layout');

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

console.log('Section A: minimap layout contract');

test('buildMapFirstCanvas uses minimap panel dimensions and default margin', () => {
	const canvas = buildMapFirstCanvas();
	assert.strictEqual(canvas.panel_width, MINIMAP_PANEL_PX_W);
	assert.strictEqual(canvas.panel_height, MINIMAP_PANEL_PX_H);
	assert.strictEqual(canvas.margin, MAP_FIRST_CANVAS_MARGIN_PX);
	assert.strictEqual(canvas.width, MINIMAP_PANEL_PX_W - (MAP_FIRST_CANVAS_MARGIN_PX * 2));
	assert.strictEqual(canvas.height, MINIMAP_PANEL_PX_H - (MAP_FIRST_CANVAS_MARGIN_PX * 2));
});

test('buildMapFirstCanvas clamps negative margin to zero', () => {
	const canvas = buildMapFirstCanvas(-4);
	assert.strictEqual(canvas.margin, 0);
	assert.strictEqual(canvas.width, MINIMAP_PANEL_PX_W);
	assert.strictEqual(canvas.height, MINIMAP_PANEL_PX_H);
	assert.strictEqual(canvas.x_min, 0);
	assert.strictEqual(canvas.y_min, 0);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
