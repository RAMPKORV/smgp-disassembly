#!/usr/bin/env node
// tools/tests/test_track_data_generation.js
//
// Tests for generated road_and_track_data include content.

'use strict';

const assert = require('assert');

const { buildGeneratedTrackBlock, TRACK_LAYOUT, FILE_SPECS, MONACO_ARCADE_TRAILING_PAD_BYTES } = require('../generate_track_data_asm.js');

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

test('generated block excludes generated minimap include by default', () => {
  assert.ok(!content.includes('Generated_minimap_preview_data:'), 'unexpected generated minimap include in default block');
});

test('generated block includes generated minimap include when requested', () => {
  assert.ok(contentWithGeneratedMinimap.includes('Generated_minimap_preview_data:'), 'missing generated minimap include label');
  assert.ok(contentWithGeneratedMinimap.includes('data/tracks/generated_minimap_data.asm'), 'missing generated minimap include path');
});

console.log(`\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total`);
if (failed > 0) process.exit(1);
