#!/usr/bin/env node
// tools/tests/test_roundtrip.js
//
// TEST-001 (JS port): Round-trip tests for the extract→inject pipeline.
//
// Verifies that:
//   1. Every encode/decode function is lossless for all 19 track binary files
//      (decode then re-encode produces byte-identical output).
//   2. Running the injector on the current tracks.json produces no changed files
//      (no-op round-trip: extract→inject leaves data/tracks/ untouched).
//   3. Decompressed lengths match track_length / 4.
//   4. Terminators and required structural fields are present.
//   5. tracks.json exists and has the expected shape.

'use strict';

const assert = require('assert');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');

const {
  TRACKS,
  decodeCurveRle,   decompressCurve,
  decodeSlopeRle,   decompressSlope,
  decodePhysSlopeRle, decompressPhysSlope,
  parseSignData,
  parseSignTileset,
  parseMinimapPos,
} = require('../extract_track_data');

const {
  encodeCurveRle, encodeSlopeRle, encodePhysSlopeRle,
  encodeSignData, encodeSignTileset, encodeMinimapPos,
  injectTrack,
} = require('../inject_track_data');

const { REPO_ROOT } = require('../lib/rom');

const DATA_TRACKS = path.join(REPO_ROOT, 'data', 'tracks');
const TRACKS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');

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

function loadBin(slug, filename) {
  return fs.readFileSync(path.join(DATA_TRACKS, slug, filename));
}

// ---------------------------------------------------------------------------
// 1. Curve RLE encode/decode round-trip
// ---------------------------------------------------------------------------
function testCurveRleRoundtrip(trackMeta) {
  const { slug, name } = trackMeta;
  const original = loadBin(slug, 'curve_data.bin');

  test(`curve_rle_roundtrip[${name}]`, () => {
    const segments   = decodeCurveRle(original);
    const reEncoded  = encodeCurveRle(segments);
    assert.ok(original.equals(reEncoded),
      `re-encoded differs from original (got ${reEncoded.length} bytes, expected ${original.length})`);
  });

  test(`curve_rle_has_terminator[${name}]`, () => {
    const segments = decodeCurveRle(original);
    const types = new Set(segments.map(s => s.type));
    assert.ok(types.has('terminator'), 'curve_rle segments missing terminator');
  });
}

// ---------------------------------------------------------------------------
// 2. Visual slope RLE encode/decode round-trip
// ---------------------------------------------------------------------------
function testSlopeRleRoundtrip(trackMeta) {
  const { slug, name } = trackMeta;
  const original = loadBin(slug, 'slope_data.bin');

  test(`slope_rle_roundtrip[${name}]`, () => {
    const { initialBgDisp, segments } = decodeSlopeRle(original);
    const reEncoded = encodeSlopeRle(initialBgDisp, segments);
    assert.ok(original.equals(reEncoded),
      `re-encoded differs from original (got ${reEncoded.length} bytes, expected ${original.length})`);
  });

  test(`slope_rle_header[${name}]`, () => {
    const { initialBgDisp, segments } = decodeSlopeRle(original);
    const reEncoded = encodeSlopeRle(initialBgDisp, segments);
    // Header byte (signed) must match initialBgDisp
    const headerGot = reEncoded.readInt8(0);
    assert.strictEqual(headerGot, initialBgDisp,
      `header byte ${headerGot} !== expected ${initialBgDisp}`);
  });
}

// ---------------------------------------------------------------------------
// 3. Physical slope RLE encode/decode round-trip
// ---------------------------------------------------------------------------
function testPhysSlopeRleRoundtrip(trackMeta) {
  const { slug, name } = trackMeta;
  const original = loadBin(slug, 'phys_slope_data.bin');

  test(`phys_slope_rle_roundtrip[${name}]`, () => {
    const segments  = decodePhysSlopeRle(original);
    const reEncoded = encodePhysSlopeRle(segments);
    assert.ok(original.equals(reEncoded),
      `re-encoded differs from original (got ${reEncoded.length} bytes, expected ${original.length})`);
  });

  test(`phys_slope_has_terminator[${name}]`, () => {
    const segments    = decodePhysSlopeRle(original);
    const terminators = segments.filter(s => s.type === 'terminator');
    assert.ok(terminators.length >= 1, 'phys_slope segments missing terminator');
  });
}

// ---------------------------------------------------------------------------
// 4. Sign data encode/decode round-trip
// ---------------------------------------------------------------------------
function testSignDataRoundtrip(trackMeta) {
  const { slug, name } = trackMeta;
  const original = loadBin(slug, 'sign_data.bin');

  test(`sign_data_roundtrip[${name}]`, () => {
    const records   = parseSignData(original);
    const reEncoded = encodeSignData(records);
    assert.ok(original.equals(reEncoded),
      `re-encoded differs from original (got ${reEncoded.length} bytes, expected ${original.length})`);
  });
}

// ---------------------------------------------------------------------------
// 5. Sign tileset encode/decode round-trip
// ---------------------------------------------------------------------------
function testSignTilesetRoundtrip(trackMeta) {
  const { slug, name } = trackMeta;
  const original = loadBin(slug, 'sign_tileset.bin');

  test(`sign_tileset_roundtrip[${name}]`, () => {
    const { records, trailingBytes } = parseSignTileset(original);
    const reEncoded = encodeSignTileset(records, trailingBytes);
    assert.ok(original.equals(reEncoded),
      `re-encoded differs from original (got ${reEncoded.length} bytes, expected ${original.length})`);
  });
}

// ---------------------------------------------------------------------------
// 6. Minimap position encode/decode round-trip
// ---------------------------------------------------------------------------
function testMinimapPosRoundtrip(trackMeta) {
  const { slug, name } = trackMeta;
  const original = loadBin(slug, 'minimap_pos.bin');

  test(`minimap_pos_roundtrip[${name}]`, () => {
    const { pairs, trailingBytes } = parseMinimapPos(original);
    const reEncoded = encodeMinimapPos(pairs, trailingBytes);
    assert.ok(original.equals(reEncoded),
      `re-encoded differs from original (got ${reEncoded.length} bytes, expected ${original.length})`);
  });
}

// ---------------------------------------------------------------------------
// 7. Full inject no-op test
// ---------------------------------------------------------------------------
function testFullInjectNoop() {
  test('full_inject_noop[all 19 tracks, 114 files]', () => {
    assert.ok(fs.existsSync(TRACKS_JSON), `tracks.json not found: ${TRACKS_JSON}`);

    const jsonData = JSON.parse(fs.readFileSync(TRACKS_JSON, 'utf8'));
    const tracks   = jsonData.tracks;

    // Use a temp dir to avoid touching real data/tracks/
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp_roundtrip_'));
    try {
      // Copy data/tracks/ into tmp
      const seenSlugs = new Set();
      for (const track of tracks) {
        const { slug } = track;
        if (seenSlugs.has(slug)) continue;
        seenSlugs.add(slug);
        const srcDir = path.join(DATA_TRACKS, slug);
        const dstDir = path.join(tmp, slug);
        if (fs.existsSync(srcDir)) {
          copyDirSync(srcDir, dstDir);
        } else {
          fs.mkdirSync(dstDir, { recursive: true });
        }
      }

      const mismatches = [];
      for (const track of tracks) {
        const results = injectTrack(track, tmp, /* dryRun= */ false, /* verbose= */ false);
        for (const [filename, { changed }] of Object.entries(results)) {
          if (changed) {
            mismatches.push(`${track.slug}/${filename}`);
          }
        }
      }

      assert.strictEqual(mismatches.length, 0,
        `Injected files differ from originals:\n  ${mismatches.join('\n  ')}`);
    } finally {
      rmDirSync(tmp);
    }
  });
}

function copyDirSync(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src)) {
    const srcPath = path.join(src, entry);
    const dstPath = path.join(dst, entry);
    const stat = fs.statSync(srcPath);
    if (stat.isDirectory()) {
      copyDirSync(srcPath, dstPath);
    } else {
      fs.copyFileSync(srcPath, dstPath);
    }
  }
}

function rmDirSync(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir)) {
    const p = path.join(dir, entry);
    const stat = fs.statSync(p);
    if (stat.isDirectory()) rmDirSync(p);
    else fs.unlinkSync(p);
  }
  fs.rmdirSync(dir);
}

// ---------------------------------------------------------------------------
// 8. Curve decompressed length == track_length / 4
// ---------------------------------------------------------------------------
function testCurveDecompressedLength(trackMeta) {
  const { slug, name, track_length } = trackMeta;
  const expectedSteps = track_length / 4;

  test(`curve_decompressed_length[${name}]`, () => {
    const original     = loadBin(slug, 'curve_data.bin');
    const segments     = decodeCurveRle(original);
    const decompressed = decompressCurve(segments);
    // Last element is 0xFF terminator sentinel; content steps = length - 1
    const contentSteps = decompressed.length - 1;
    assert.strictEqual(contentSteps, expectedSteps,
      `got ${contentSteps} steps, expected ${expectedSteps}`);
  });
}

// ---------------------------------------------------------------------------
// 9. Slope decompressed length == track_length / 4
// ---------------------------------------------------------------------------
function testSlopeDecompressedLength(trackMeta) {
  const { slug, name, track_length } = trackMeta;
  const expectedSteps = track_length / 4;

  test(`slope_decompressed_length[${name}]`, () => {
    const original              = loadBin(slug, 'slope_data.bin');
    const { segments }          = decodeSlopeRle(original);
    const decompressed          = decompressSlope(segments);
    const contentSteps          = decompressed.length - 1;
    assert.strictEqual(contentSteps, expectedSteps,
      `got ${contentSteps} steps, expected ${expectedSteps}`);
  });
}

// ---------------------------------------------------------------------------
// 10. Physical slope decompressed length == track_length / 4
// ---------------------------------------------------------------------------
function testPhysDecompressedLength(trackMeta) {
  const { slug, name, track_length } = trackMeta;
  const expectedSteps = track_length / 4;

  test(`phys_decompressed_length[${name}]`, () => {
    const original     = loadBin(slug, 'phys_slope_data.bin');
    const segments     = decodePhysSlopeRle(original);
    const decompressed = decompressPhysSlope(segments);
    assert.strictEqual(decompressed.length, expectedSteps,
      `got ${decompressed.length} steps, expected ${expectedSteps}`);
  });
}

// ---------------------------------------------------------------------------
// 11. Sign data terminator check (last two bytes == 0xFF 0xFF)
// ---------------------------------------------------------------------------
function testSignDataTerminator(trackMeta) {
  const { slug, name } = trackMeta;

  test(`sign_data_terminator[${name}]`, () => {
    const original = loadBin(slug, 'sign_data.bin');
    assert.ok(original.length >= 2,
      'sign_data.bin is too short (< 2 bytes)');
    const lastTwo = original.slice(-2);
    assert.ok(lastTwo.equals(Buffer.from([0xFF, 0xFF])),
      `sign_data.bin does not end with 0xFF 0xFF (ends with ${lastTwo.toString('hex')})`);
  });
}

// ---------------------------------------------------------------------------
// 12. tracks.json exists and has the expected shape
// ---------------------------------------------------------------------------
function testTracksJsonStructure() {
  test('tracks_json_exists', () => {
    assert.ok(fs.existsSync(TRACKS_JSON), `tracks.json not found: ${TRACKS_JSON}`);
  });

  if (!fs.existsSync(TRACKS_JSON)) return;

  const data = JSON.parse(fs.readFileSync(TRACKS_JSON, 'utf8'));

  test('tracks_json_has_meta',   () => assert.ok('_meta'  in data, 'missing _meta key'));
  test('tracks_json_has_tracks', () => assert.ok('tracks' in data, 'missing tracks key'));
  test('tracks_json_count', () => {
    const count = (data.tracks || []).length;
    assert.strictEqual(count, 19, `expected 19 tracks, got ${count}`);
  });

  const requiredFields = [
    'index', 'name', 'slug', 'track_length',
    'curve_rle_segments', 'slope_rle_segments', 'phys_slope_rle_segments',
    'sign_data', 'sign_tileset', 'minimap_pos',
    'slope_initial_bg_disp', 'curve_decompressed', 'slope_decompressed',
    'phys_slope_decompressed',
  ];

  for (const track of (data.tracks || [])) {
    for (const field of requiredFields) {
      test(`tracks_json_field[${track.slug || '?'}].${field}`, () => {
        assert.ok(field in track,
          `track ${track.slug || '?'} missing field '${field}'`);
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

// JSON structure (independent of per-track binary data)
testTracksJsonStructure();

// Per-track tests
for (const trackMeta of TRACKS) {
  const trackDir = path.join(DATA_TRACKS, trackMeta.slug);
  if (!fs.existsSync(trackDir)) {
    test(`data_dir_exists[${trackMeta.slug}]`, () => {
      throw new Error(`data/tracks/${trackMeta.slug}/ directory not found`);
    });
    continue;
  }

  testCurveRleRoundtrip(trackMeta);
  testSlopeRleRoundtrip(trackMeta);
  testPhysSlopeRleRoundtrip(trackMeta);
  testSignDataRoundtrip(trackMeta);
  testSignTilesetRoundtrip(trackMeta);
  testMinimapPosRoundtrip(trackMeta);
  testCurveDecompressedLength(trackMeta);
  testSlopeDecompressedLength(trackMeta);
  testPhysDecompressedLength(trackMeta);
  testSignDataTerminator(trackMeta);
}

// Full inject no-op test
testFullInjectNoop();

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
if (require.main === module) {
  console.log(`Results: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

module.exports = { passed, failed };
