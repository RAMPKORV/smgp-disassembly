#!/usr/bin/env node
// tools/tests/test_track_data_generation.js
//
// Tests for generated road_and_track_data include content.

'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const { buildGeneratedTrackBlock, TRACK_LAYOUT, FILE_SPECS, MONACO_ARCADE_TRAILING_PAD_BYTES, measureAsmDataLayout } = require('../generate_track_data_asm.js');
const { REPO_ROOT } = require('../lib/rom');
const { buildAsm } = require('../write_generated_minimap_assets.js');

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

const content = buildGeneratedTrackBlock();
const contentWithGeneratedMinimap = buildGeneratedTrackBlock({ includeGeneratedMinimapData: true });

test('generated block includes every declared track prefix/file combination', () => {
  for (const track of TRACK_LAYOUT) {
    for (const spec of FILE_SPECS) {
      assert.ok(content.includes(`${track.prefix}_${spec.suffix}:`), `missing label ${track.prefix}_${spec.suffix}`);
      assert.ok(content.includes(`data/tracks/${track.slug}/${spec.file}`), `missing incbin path ${track.slug}/${spec.file}`);
    }
  }
});

test('generated block preserves Monaco arcade trailing blob', () => {
  assert.ok(content.includes('Monaco_arcade_post_sign_tileset_blob:'), 'missing Monaco arcade trailing blob label');
  assert.ok(content.includes(`\tdcb.b\t${MONACO_ARCADE_TRAILING_PAD_BYTES}, $00`), 'missing Monaco arcade compatibility pad');
  assert.ok(content.includes('data/tracks/monaco_arcade/post_sign_tileset_blob.bin'), 'missing Monaco arcade trailing blob incbin');
});

test('generated block places Monaco arcade blob label at canonical blob start', () => {
	const symbolMap = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json'), 'utf8')).symbols;
	const start = parseInt(symbolMap.San_Marino_curve_data, 16);
	const blob = parseInt(symbolMap.Monaco_arcade_post_sign_tileset_blob, 16);
	const expectedBlobRelative = blob - start;
	let total = 0;
	let blobStart = null;
	for (const line of content.split(/\r?\n/)) {
		if (/^\s*Monaco_arcade_post_sign_tileset_blob:/i.test(line)) {
			blobStart = total;
			continue;
		}
		const incbin = line.match(/^\s*incbin\s+"([^"]+)"/i);
		if (incbin) {
			const filePath = path.join(REPO_ROOT, incbin[1]);
			if (fs.existsSync(filePath)) total += fs.statSync(filePath).size;
			continue;
		}
		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) total += parseInt(dcb[1], 10);
	}
	assert.strictEqual(blobStart, expectedBlobRelative);
});

test('generated block excludes generated minimap include by default', () => {
  assert.ok(!content.includes('Generated_minimap_preview_data:'), 'unexpected generated minimap include in default block');
});

test('generated block includes generated minimap include when requested', () => {
  assert.ok(contentWithGeneratedMinimap.includes('Generated_minimap_preview_data:'), 'missing generated minimap include label');
  assert.ok(contentWithGeneratedMinimap.includes('data/tracks/generated_minimap_data.asm'), 'missing generated minimap include path');
});

test('workspace generated minimap assets stay compact enough for track-block slack', () => {
	const tracksData = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tools', 'data', 'tracks.json'), 'utf8'));
	const asm = buildAsm(tracksData.tracks);
	assert.ok(asm.includes('Generated_Minimap_Track_17_Monaco_Arcade_Main_map:'), 'missing generated map label');
	assert.ok(asm.includes('Generated_Minimap_Track_00_San_Marino_tiles:'), 'missing generated tiles label');
	assert.ok(Buffer.byteLength(asm, 'utf8') < 160000, 'generated minimap asm unexpectedly large');
});

test('generated minimap include measurement accounts for nested include data', () => {
	const asm = buildGeneratedTrackBlock({ includeGeneratedMinimapData: true, keepInlineBlobPadding: false });
	const layout = measureAsmDataLayout(asm, REPO_ROOT);
	assert.ok(layout.total > 8000, 'expected measured generated track block size');
	assert.ok(layout.blobStart > 8000, 'expected measured Monaco blob start');
});

console.log(`\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total`);
if (failed > 0) process.exit(1);
