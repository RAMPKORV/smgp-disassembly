#!/usr/bin/env node
// tools/tests/test_rle.js
//
// TEST-003 (JS port): Unit tests for RLE encode/decode codec functions.
//
// Mirrors test_rle.py with equivalent coverage:
//   A. Curve RLE: decodeCurveRle / encodeCurveRle / decompressCurve
//   B. Visual slope RLE: decodeSlopeRle / encodeSlopeRle / decompressSlope
//   C. Physical slope RLE: decodePhysSlopeRle / encodePhysSlopeRle / decompressPhysSlope
//   D. All 19 ROM tracks: encode(decode(original)) == original + decompressed lengths

'use strict';

const assert = require('assert');
const fs     = require('fs');
const path   = require('path');

const {
  TRACKS,
  decodeCurveRle, decompressCurve,
  decodeSlopeRle, decompressSlope,
  decodePhysSlopeRle, decompressPhysSlope,
} = require('../extract_track_data');

const {
  encodeCurveRle, encodeSlopeRle, encodePhysSlopeRle,
} = require('../inject_track_data');

const { REPO_ROOT } = require('../lib/rom');

const DATA_TRACKS = path.join(REPO_ROOT, 'data', 'tracks');

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

// ---------------------------------------------------------------------------
// Binary builder helpers (mirrors Python test_rle.py helpers)
// ---------------------------------------------------------------------------

/** 3-byte straight curve RLE record */
function curveStraight(length) {
  return Buffer.from([(length >> 8) & 0xFF, length & 0xFF, 0x00]);
}

/** 5-byte curve RLE record */
function curveCurve(length, curveByte, bgDisp) {
  const buf = Buffer.alloc(5);
  buf[0] = (length >> 8) & 0xFF;
  buf[1] = length & 0xFF;
  buf[2] = curveByte & 0xFF;
  buf.writeInt16BE(bgDisp, 3);
  return buf;
}

/** 2-byte curve terminator */
function curveTerm(secondByte = 0x00) {
  return Buffer.from([0xFF, secondByte]);
}

/** 3-byte flat slope RLE record */
function slopeFlat(length) {
  return Buffer.from([(length >> 8) & 0xFF, length & 0xFF, 0x00]);
}

/** 4-byte slope RLE record */
function slopeSlope(length, slopeByte, bgVertDisp) {
  const buf = Buffer.alloc(4);
  buf[0] = (length >> 8) & 0xFF;
  buf[1] = length & 0xFF;
  buf[2] = slopeByte & 0xFF;
  buf.writeInt8(bgVertDisp, 3);
  return buf;
}

/** Slope terminator: 0xFF followed by optional extra bytes */
function slopeTerm(...extraBytes) {
  return Buffer.from([0xFF, ...extraBytes]);
}

/** Build complete slope binary: signed header + body + terminator */
function slopeStream(initialBgDisp, bodyBuf, termBuf) {
  const header = Buffer.alloc(1);
  header.writeInt8(initialBgDisp, 0);
  return Buffer.concat([header, bodyBuf, termBuf]);
}

/** 3-byte physical slope segment (b0 < 0x80) */
function physSeg(length, physByte) {
  const buf = Buffer.alloc(3);
  buf[0] = (length >> 8) & 0xFF;
  buf[1] = length & 0xFF;
  buf.writeInt8(physByte, 2);
  return buf;
}

/** 3-byte physical slope terminator (b0 >= 0x80) */
function physTerm(length, physByte) {
  const b0 = ((length >> 8) & 0xFF) | 0x80;
  const buf = Buffer.alloc(3);
  buf[0] = b0;
  buf[1] = length & 0xFF;
  buf.writeInt8(physByte, 2);
  return buf;
}

// ---------------------------------------------------------------------------
// Section A: Curve RLE
// ---------------------------------------------------------------------------
console.log('\nSection A: Curve RLE — synthetic data');

test('curve_straight_only: segment count and types', () => {
  const raw = Buffer.concat([curveStraight(100), curveStraight(200), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs.length, 3);
  assert.strictEqual(segs[0].type, 'straight');
  assert.strictEqual(segs[0].length, 100);
  assert.strictEqual(segs[1].type, 'straight');
  assert.strictEqual(segs[1].length, 200);
  assert.strictEqual(segs[2].type, 'terminator');
});

test('curve_straight_only: roundtrip', () => {
  const raw = Buffer.concat([curveStraight(100), curveStraight(200), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_curve_only: segment count and fields', () => {
  const raw = Buffer.concat([
    curveCurve(50, 0x01, 0),
    curveCurve(30, 0x7F, 100),
    curveCurve(20, 0x80, -100),
    curveTerm(),
  ]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs.length, 4);
  assert.strictEqual(segs[0].type, 'curve');
  assert.strictEqual(segs[0].curve_byte, 0x01);
  assert.strictEqual(segs[0].bg_disp, 0);
  assert.strictEqual(segs[1].bg_disp, 100);
  assert.strictEqual(segs[2].bg_disp, -100);
});

test('curve_curve_only: roundtrip', () => {
  const raw = Buffer.concat([
    curveCurve(50, 0x01, 0),
    curveCurve(30, 0x7F, 100),
    curveCurve(20, 0x80, -100),
    curveTerm(),
  ]);
  const segs = decodeCurveRle(raw);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_mixed: types', () => {
  const raw = Buffer.concat([
    curveStraight(10),
    curveCurve(5, 0x10, 50),
    curveStraight(20),
    curveCurve(8, 0xFE, -200),
    curveTerm(0x00),
  ]);
  const segs = decodeCurveRle(raw);
  const types = segs.map(s => s.type);
  assert.deepStrictEqual(types, ['straight', 'curve', 'straight', 'curve', 'terminator']);
});

test('curve_mixed: roundtrip', () => {
  const raw = Buffer.concat([
    curveStraight(10),
    curveCurve(5, 0x10, 50),
    curveStraight(20),
    curveCurve(8, 0xFE, -200),
    curveTerm(0x00),
  ]);
  const segs = decodeCurveRle(raw);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_multibyte_length: len_hi != 0', () => {
  const bigLen = 0x0200;
  const raw = Buffer.concat([curveStraight(bigLen), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs[0].length, bigLen);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_max_length: 0x7FFF', () => {
  const maxLen = 0x7FFF;
  const raw = Buffer.concat([curveStraight(maxLen), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs[0].length, maxLen);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_negative_bg_disp: -1', () => {
  const raw = Buffer.concat([curveCurve(10, 0x05, -1), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs[0].bg_disp, -1);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_negative_bg_disp: -128', () => {
  const raw = Buffer.concat([curveCurve(10, 0x05, -128), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs[0].bg_disp, -128);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_negative_bg_disp: -256', () => {
  const raw = Buffer.concat([curveCurve(10, 0x05, -256), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs[0].bg_disp, -256);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_negative_bg_disp: -32768', () => {
  const raw = Buffer.concat([curveCurve(10, 0x05, -32768), curveTerm()]);
  const segs = decodeCurveRle(raw);
  assert.strictEqual(segs[0].bg_disp, -32768);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_term_with_trailing_byte: _raw preserved', () => {
  const raw = Buffer.concat([curveStraight(5), curveTerm(0x42)]);
  const segs = decodeCurveRle(raw);
  const term = segs[segs.length - 1];
  assert.strictEqual(term.type, 'terminator');
  assert.deepStrictEqual(term._raw, [0xFF, 0x42]);
  assert.ok(encodeCurveRle(segs).equals(raw));
});

test('curve_decompressed_length: sum of segment lengths + 1 terminator', () => {
  const raw = Buffer.concat([
    curveStraight(10),
    curveCurve(5, 0x01, 0),
    curveStraight(15),
    curveTerm(),
  ]);
  const segs = decodeCurveRle(raw);
  const flat = decompressCurve(segs);
  assert.strictEqual(flat.length, 31); // 10 + 5 + 15 = 30 content + 1 sentinel
});

test('curve_decompress_content: correct flat bytes', () => {
  const raw = Buffer.concat([curveStraight(3), curveCurve(2, 0x07, 0), curveTerm()]);
  const segs = decodeCurveRle(raw);
  const flat = decompressCurve(segs);
  assert.deepStrictEqual(flat, [0x00, 0x00, 0x00, 0x07, 0x07, 0xFF]);
});

// ---------------------------------------------------------------------------
// Section B: Visual slope RLE
// ---------------------------------------------------------------------------
console.log('\nSection B: Visual slope RLE — synthetic data');

test('slope_flat_only: segment types and lengths', () => {
  const body = Buffer.concat([slopeFlat(100), slopeFlat(200)]);
  const raw = slopeStream(0, body, slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, 0);
  const types = segments.map(s => s.type);
  assert.deepStrictEqual(types, ['flat', 'flat', 'terminator']);
  assert.strictEqual(segments[0].length, 100);
  assert.strictEqual(segments[1].length, 200);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_slope_only: fields and roundtrip', () => {
  const body = Buffer.concat([slopeSlope(50, 0x01, 2), slopeSlope(30, 0x02, -3)]);
  const raw = slopeStream(5, body, slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, 5);
  assert.strictEqual(segments[0].slope_byte, 0x01);
  assert.strictEqual(segments[0].bg_vert_disp, 2);
  assert.strictEqual(segments[1].bg_vert_disp, -3);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_mixed: types and roundtrip', () => {
  const body = Buffer.concat([slopeFlat(10), slopeSlope(5, 0x03, 1), slopeFlat(20)]);
  const raw = slopeStream(-10, body, slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, -10);
  const types = segments.map(s => s.type);
  assert.deepStrictEqual(types, ['flat', 'slope', 'flat', 'terminator']);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_negative_initial_bg: -128', () => {
  const raw = slopeStream(-128, slopeFlat(5), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, -128);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_negative_initial_bg: -1', () => {
  const raw = slopeStream(-1, slopeFlat(5), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, -1);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_negative_initial_bg: -50', () => {
  const raw = slopeStream(-50, slopeFlat(5), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, -50);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_positive_initial_bg: 0', () => {
  const raw = slopeStream(0, slopeFlat(5), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, 0);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_positive_initial_bg: 1', () => {
  const raw = slopeStream(1, slopeFlat(5), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, 1);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_positive_initial_bg: 127', () => {
  const raw = slopeStream(127, slopeFlat(5), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(initialBgDisp, 127);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_multibyte_length: 0x0100', () => {
  const bigLen = 0x0100;
  const raw = slopeStream(0, slopeFlat(bigLen), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(segments[0].length, bigLen);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_negative_bg_vert: -128', () => {
  const raw = slopeStream(0, slopeSlope(10, 0x01, -128), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(segments[0].bg_vert_disp, -128);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_negative_bg_vert: -1', () => {
  const raw = slopeStream(0, slopeSlope(10, 0x01, -1), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(segments[0].bg_vert_disp, -1);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_negative_bg_vert: -64', () => {
  const raw = slopeStream(0, slopeSlope(10, 0x01, -64), slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  assert.strictEqual(segments[0].bg_vert_disp, -64);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_term_with_trailing_byte: _raw preserved', () => {
  const raw = slopeStream(0, slopeFlat(5), slopeTerm(0x00));
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  const term = segments[segments.length - 1];
  assert.strictEqual(term.type, 'terminator');
  assert.deepStrictEqual(term._raw, [0xFF, 0x00]);
  assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(raw));
});

test('slope_decompressed_length: sum + 1 sentinel', () => {
  const body = Buffer.concat([slopeFlat(10), slopeSlope(5, 0x01, 1), slopeFlat(15)]);
  const raw = slopeStream(0, body, slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  const flat = decompressSlope(segments);
  assert.strictEqual(flat.length, 31); // 10 + 5 + 15 + 1 sentinel
});

test('slope_decompress_content: correct flat bytes', () => {
  const body = Buffer.concat([slopeFlat(3), slopeSlope(2, 0x04, 0)]);
  const raw = slopeStream(0, body, slopeTerm());
  const { initialBgDisp, segments } = decodeSlopeRle(raw);
  const flat = decompressSlope(segments);
  assert.deepStrictEqual(flat, [0x00, 0x00, 0x00, 0x04, 0x04, 0xFF]);
});

// ---------------------------------------------------------------------------
// Section C: Physical slope RLE
// ---------------------------------------------------------------------------
console.log('\nSection C: Physical slope RLE — synthetic data');

test('phys_segments_only: types and fields', () => {
  const raw = Buffer.concat([physSeg(100, 0), physSeg(50, 1), physSeg(50, -1), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  const types = segs.map(s => s.type);
  assert.deepStrictEqual(types, ['segment', 'segment', 'segment', 'terminator']);
  assert.strictEqual(segs[0].length, 100);
  assert.strictEqual(segs[1].phys_byte, 1);
  assert.strictEqual(segs[2].phys_byte, -1);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_all_flat: correct count and phys_byte', () => {
  const raw = Buffer.concat([physSeg(200, 0), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs.length, 2);
  assert.strictEqual(segs[0].phys_byte, 0);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_negative_phys_byte: -1', () => {
  const raw = Buffer.concat([physSeg(10, -1), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].phys_byte, -1);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_negative_phys_byte: -2', () => {
  const raw = Buffer.concat([physSeg(10, -2), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].phys_byte, -2);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_negative_phys_byte: -128', () => {
  const raw = Buffer.concat([physSeg(10, -128), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].phys_byte, -128);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_positive_phys_byte: 1', () => {
  const raw = Buffer.concat([physSeg(10, 1), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].phys_byte, 1);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_positive_phys_byte: 2', () => {
  const raw = Buffer.concat([physSeg(10, 2), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].phys_byte, 2);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_positive_phys_byte: 127', () => {
  const raw = Buffer.concat([physSeg(10, 127), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].phys_byte, 127);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_multibyte_length: 0x0100', () => {
  const bigLen = 0x0100;
  const raw = Buffer.concat([physSeg(bigLen, 0), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  assert.strictEqual(segs[0].length, bigLen);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_terminator_high_bit: b0 of terminator has bit 7 set', () => {
  const raw = Buffer.concat([physSeg(10, 0), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  const reEncoded = encodePhysSlopeRle(segs);
  const termB0 = reEncoded[reEncoded.length - 3];
  assert.ok((termB0 & 0x80) !== 0, `terminator b0 ${termB0.toString(16)} does not have high bit set`);
});

test('phys_single_byte_trailing_terminator: _raw preserved', () => {
  // Simulate monaco_arcade_prelim case: segments + single 0xFF trailing byte
  const raw = Buffer.concat([physSeg(50, 0), Buffer.from([0xFF])]);
  const segs = decodePhysSlopeRle(raw);
  const term = segs[segs.length - 1];
  assert.strictEqual(term.type, 'terminator');
  assert.deepStrictEqual(term._raw, [0xFF]);
  assert.ok(encodePhysSlopeRle(segs).equals(raw));
});

test('phys_decompress_length: sum of non-terminator segment lengths', () => {
  const raw = Buffer.concat([physSeg(100, 0), physSeg(50, 1), physSeg(50, -1), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  const flat = decompressPhysSlope(segs);
  assert.strictEqual(flat.length, 200); // 100 + 50 + 50; terminator not expanded
});

test('phys_decompress_content: correct flat signed bytes', () => {
  const raw = Buffer.concat([physSeg(3, 1), physSeg(2, -1), physTerm(0, 0)]);
  const segs = decodePhysSlopeRle(raw);
  const flat = decompressPhysSlope(segs);
  assert.deepStrictEqual(flat, [1, 1, 1, -1, -1]);
});

// ---------------------------------------------------------------------------
// Section D: All 19 ROM tracks — encode(decode(original)) == original
// ---------------------------------------------------------------------------
console.log('\nSection D: ROM tracks — encode(decode(original)) == original');

if (!fs.existsSync(DATA_TRACKS)) {
  console.warn(`[D skipped — data/tracks/ not found at ${DATA_TRACKS}]`);
} else {
  for (const trackMeta of TRACKS) {
    const { slug, track_length } = trackMeta;
    const trackDir = path.join(DATA_TRACKS, slug);

    // Curve RLE roundtrip
    test(`rom_curve_roundtrip[${slug}]`, () => {
      const original = fs.readFileSync(path.join(trackDir, 'curve_data.bin'));
      const segs = decodeCurveRle(original);
      assert.ok(encodeCurveRle(segs).equals(original), 'curve roundtrip mismatch');
    });

    // Slope RLE roundtrip
    test(`rom_slope_roundtrip[${slug}]`, () => {
      const original = fs.readFileSync(path.join(trackDir, 'slope_data.bin'));
      const { initialBgDisp, segments } = decodeSlopeRle(original);
      assert.ok(encodeSlopeRle(initialBgDisp, segments).equals(original), 'slope roundtrip mismatch');
    });

    // Physical slope RLE roundtrip
    test(`rom_phys_slope_roundtrip[${slug}]`, () => {
      const original = fs.readFileSync(path.join(trackDir, 'phys_slope_data.bin'));
      const segs = decodePhysSlopeRle(original);
      assert.ok(encodePhysSlopeRle(segs).equals(original), 'phys_slope roundtrip mismatch');
    });

    // Decompressed curve length = track_length / 4 (content steps, excluding sentinel)
    test(`rom_curve_decomp_len[${slug}]`, () => {
      const original = fs.readFileSync(path.join(trackDir, 'curve_data.bin'));
      const segs = decodeCurveRle(original);
      const flat = decompressCurve(segs);
      assert.strictEqual(flat.length - 1, track_length >> 2,
        `expected ${track_length >> 2} content steps, got ${flat.length - 1}`);
    });

    // Decompressed slope length = track_length / 4
    test(`rom_slope_decomp_len[${slug}]`, () => {
      const original = fs.readFileSync(path.join(trackDir, 'slope_data.bin'));
      const { initialBgDisp, segments } = decodeSlopeRle(original);
      const flat = decompressSlope(segments);
      assert.strictEqual(flat.length - 1, track_length >> 2,
        `expected ${track_length >> 2} content steps, got ${flat.length - 1}`);
    });

    // Decompressed physical slope length = track_length / 4 (no sentinel in phys)
    test(`rom_phys_decomp_len[${slug}]`, () => {
      const original = fs.readFileSync(path.join(trackDir, 'phys_slope_data.bin'));
      const segs = decodePhysSlopeRle(original);
      const flat = decompressPhysSlope(segs);
      assert.strictEqual(flat.length, track_length >> 2,
        `expected ${track_length >> 2} content steps, got ${flat.length}`);
    });
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
