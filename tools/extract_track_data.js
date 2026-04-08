#!/usr/bin/env node
// tools/extract_track_data.js
//
// EXTR-001 (JS port): Track data extractor — data/tracks/ binaries -> tools/data/tracks.json
//
// Reads the per-track binary files already extracted to data/tracks/ by
// tools/extract_track_blobs.py (task EXTR-000), decodes all RLE streams and
// structured records, and emits a rich JSON file at tools/data/tracks.json.
//
// Usage:
//   node tools/extract_track_data.js [--datadir data/tracks] [--out tools/data/tracks.json] [-v]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info, warn } = require('./lib/cli');
const { REPO_ROOT } = require('./lib/rom');

// ---------------------------------------------------------------------------
// Track metadata table (order matches Track_data in track_config_data.asm)
// ---------------------------------------------------------------------------
const TRACKS = [
  { index: 0,  name: 'San Marino',             slug: 'san_marino',
    track_length: 7040, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x00, lap_targets_name: 'San_Marino_lap_targets' },
  { index: 1,  name: 'Brazil',                 slug: 'brazil',
    track_length: 6976, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x08, lap_targets_name: 'Brazil_lap_targets' },
  { index: 2,  name: 'France',                 slug: 'france',
    track_length: 6144, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x10, lap_targets_name: 'France_lap_targets' },
  { index: 3,  name: 'Hungary',                slug: 'hungary',
    track_length: 6464, horizon_override: 0,
    steering_straight: 0x002C, steering_curve: 0x002E,
    lap_record_ptr_offset: 0x18, lap_targets_name: 'Hungary_lap_targets' },
  { index: 4,  name: 'West Germany',           slug: 'west_germany',
    track_length: 7488, horizon_override: 1,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x20, lap_targets_name: 'West_Germany_lap_targets' },
  { index: 5,  name: 'USA',                    slug: 'usa',
    track_length: 7168, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x28,
    // Note: USA track uses Canada_lap_targets in ROM (intentional)
    lap_targets_name: 'Canada_lap_targets' },
  { index: 6,  name: 'Canada',                 slug: 'canada',
    track_length: 6720, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x30,
    // Note: Canada track uses Great_Britain_lap_targets in ROM (intentional)
    lap_targets_name: 'Great_Britain_lap_targets' },
  { index: 7,  name: 'Great Britain',          slug: 'great_britain',
    track_length: 6912, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x38,
    // Note: Great Britain track uses Italy_lap_targets in ROM (intentional)
    lap_targets_name: 'Italy_lap_targets' },
  { index: 8,  name: 'Italy',                  slug: 'italy',
    track_length: 7616, horizon_override: 1,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x40,
    // Note: Italy track uses Spain_lap_targets in ROM (intentional)
    lap_targets_name: 'Spain_lap_targets' },
  { index: 9,  name: 'Portugal',               slug: 'portugal',
    track_length: 6592, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x48,
    // Note: Portugal track uses Mexico_lap_targets in ROM (intentional)
    lap_targets_name: 'Mexico_lap_targets' },
  { index: 10, name: 'Spain',                  slug: 'spain',
    track_length: 6784, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x50,
    // Note: Spain track uses Japan_lap_targets in ROM (intentional)
    lap_targets_name: 'Japan_lap_targets' },
  { index: 11, name: 'Mexico',                 slug: 'mexico',
    track_length: 6848, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x58,
    // Note: Mexico track uses Australia_lap_targets in ROM (intentional)
    lap_targets_name: 'Australia_lap_targets' },
  { index: 12, name: 'Japan',                  slug: 'japan',
    track_length: 7552, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x60,
    // Note: Japan track uses Portugal_lap_targets in ROM (intentional)
    lap_targets_name: 'Portugal_lap_targets' },
  { index: 13, name: 'Belgium',                slug: 'belgium',
    track_length: 7744, horizon_override: 1,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x68, lap_targets_name: 'Belgium_lap_targets' },
  { index: 14, name: 'Australia',              slug: 'australia',
    track_length: 6080, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x70,
    // Note: Australia track uses Usa_lap_targets in ROM (intentional)
    lap_targets_name: 'Usa_lap_targets' },
  { index: 15, name: 'Monaco',                 slug: 'monaco',
    track_length: 6144, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x78, lap_targets_name: 'Monaco_lap_targets' },
  { index: 16, name: 'Monaco (Arcade Prelim)', slug: 'monaco_arcade_prelim',
    track_length: 3392, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x80, lap_targets_name: 'Monaco_arcade_lap_targets' },
  { index: 17, name: 'Monaco (Arcade Main)',   slug: 'monaco_arcade',
    track_length: 7616, horizon_override: 0,
    steering_straight: 0x002B, steering_curve: 0x002B,
    lap_record_ptr_offset: 0x88, lap_targets_name: 'Monaco_arcade_lap_targets' },
  { index: 18, name: 'Monaco (Arcade Wet)',    slug: 'monaco_arcade',
    track_length: 7616, horizon_override: 0,
    steering_straight: 0x002F, steering_curve: 0x0038,
    lap_record_ptr_offset: 0x88, // shares Monaco Arcade main's record slot
    lap_targets_name: 'Monaco_arcade_lap_targets' },
];

// Lap targets data parsed from track_config_data.asm (15 x 3-byte BCD + $99,$00,$00 + $00 pad)
// Each entry: [min_bcd, sec_bcd, centisec_bcd]  (14 real entries + sentinel)
const LAP_TARGETS = {
  San_Marino_lap_targets: [
    [0x00,0x47,0x50],[0x00,0x47,0x65],[0x00,0x47,0x86],[0x00,0x48,0x55],
    [0x00,0x49,0x75],[0x00,0x50,0x51],[0x00,0x52,0x36],[0x00,0x53,0x12],
    [0x00,0x54,0x23],[0x00,0x55,0x45],[0x00,0x56,0x28],[0x00,0x57,0x11],
    [0x00,0x57,0x82],[0x00,0x59,0x55],
  ],
  Brazil_lap_targets: [
    [0x00,0x47,0x93],[0x00,0x48,0x10],[0x00,0x48,0x32],[0x00,0x49,0x01],
    [0x00,0x50,0x22],[0x00,0x51,0x84],[0x00,0x53,0x62],[0x00,0x54,0x74],
    [0x00,0x55,0x97],[0x00,0x57,0x31],[0x00,0x59,0x14],[0x01,0x01,0x02],
    [0x01,0x02,0x88],[0x01,0x04,0x75],
  ],
  France_lap_targets: [
    [0x00,0x41,0x15],[0x00,0x41,0x28],[0x00,0x41,0x47],[0x00,0x41,0x76],
    [0x00,0x42,0x97],[0x00,0x44,0x03],[0x00,0x45,0x20],[0x00,0x46,0x11],
    [0x00,0x47,0x09],[0x00,0x48,0x48],[0x00,0x49,0x32],[0x00,0x50,0x25],
    [0x00,0x51,0x42],[0x00,0x53,0x25],
  ],
  Hungary_lap_targets: [
    [0x00,0x45,0x55],[0x00,0x45,0x69],[0x00,0x45,0x90],[0x00,0x46,0x57],
    [0x00,0x47,0x72],[0x00,0x48,0x91],[0x00,0x50,0x04],[0x00,0x51,0x29],
    [0x00,0x52,0x22],[0x00,0x52,0x87],[0x00,0x54,0x36],[0x00,0x54,0x67],
    [0x00,0x55,0x79],[0x00,0x58,0x00],
  ],
  West_Germany_lap_targets: [
    [0x00,0x50,0x75],[0x00,0x50,0x91],[0x00,0x51,0x13],[0x00,0x51,0x62],
    [0x00,0x52,0x50],[0x00,0x53,0x55],[0x00,0x54,0x71],[0x00,0x55,0x84],
    [0x00,0x56,0x97],[0x00,0x58,0x02],[0x00,0x59,0x14],[0x01,0x00,0x25],
    [0x01,0x01,0x38],[0x01,0x02,0x40],
  ],
  Canada_lap_targets: [
    [0x00,0x48,0x90],[0x00,0x49,0x06],[0x00,0x49,0x27],[0x00,0x49,0x61],
    [0x00,0x50,0x71],[0x00,0x51,0x77],[0x00,0x52,0x86],[0x00,0x53,0x97],
    [0x00,0x55,0x16],[0x00,0x56,0x33],[0x00,0x57,0x24],[0x00,0x58,0x22],
    [0x01,0x00,0x36],[0x01,0x02,0x65],
  ],
  Great_Britain_lap_targets: [
    [0x00,0x45,0x90],[0x00,0x46,0x04],[0x00,0x46,0x25],[0x00,0x46,0x59],
    [0x00,0x47,0x62],[0x00,0x48,0x92],[0x00,0x49,0x84],[0x00,0x51,0x08],
    [0x00,0x52,0x21],[0x00,0x53,0x43],[0x00,0x54,0x62],[0x00,0x55,0x76],
    [0x00,0x57,0x47],[0x00,0x59,0x45],
  ],
  Italy_lap_targets: [
    [0x00,0x47,0x45],[0x00,0x47,0x60],[0x00,0x47,0x81],[0x00,0x48,0x14],
    [0x00,0x48,0x64],[0x00,0x48,0x86],[0x00,0x49,0x21],[0x00,0x49,0x69],
    [0x00,0x50,0x25],[0x00,0x50,0x64],[0x00,0x52,0x31],[0x00,0x53,0x07],
    [0x00,0x54,0x18],[0x00,0x55,0x25],
  ],
  Spain_lap_targets: [
    [0x00,0x51,0x35],[0x00,0x51,0x51],[0x00,0x51,0x74],[0x00,0x52,0x09],
    [0x00,0x52,0x83],[0x00,0x53,0x24],[0x00,0x53,0x76],[0x00,0x54,0x78],
    [0x00,0x55,0x87],[0x00,0x57,0x01],[0x00,0x57,0x74],[0x00,0x58,0x56],
    [0x00,0x59,0x86],[0x01,0x01,0x00],
  ],
  Mexico_lap_targets: [
    [0x00,0x44,0x80],[0x00,0x44,0x94],[0x00,0x45,0x14],[0x00,0x45,0x80],
    [0x00,0x46,0x50],[0x00,0x47,0x70],[0x00,0x48,0x81],[0x00,0x49,0x85],
    [0x00,0x51,0x16],[0x00,0x52,0x23],[0x00,0x53,0x75],[0x00,0x55,0x47],
    [0x00,0x57,0x36],[0x00,0x59,0x40],
  ],
  Japan_lap_targets: [
    [0x00,0x47,0x45],[0x00,0x47,0x60],[0x00,0x47,0x81],[0x00,0x48,0x50],
    [0x00,0x49,0x69],[0x00,0x50,0x80],[0x00,0x52,0x11],[0x00,0x53,0x73],
    [0x00,0x54,0x94],[0x00,0x57,0x28],[0x00,0x59,0x31],[0x01,0x01,0x10],
    [0x01,0x03,0x02],[0x01,0x04,0x95],
  ],
  Portugal_lap_targets: [
    [0x00,0x52,0x95],[0x00,0x53,0x11],[0x00,0x53,0x35],[0x00,0x53,0x74],
    [0x00,0x54,0x86],[0x00,0x55,0x71],[0x00,0x56,0x92],[0x00,0x58,0x50],
    [0x01,0x00,0x61],[0x01,0x02,0x90],[0x01,0x05,0x25],[0x01,0x07,0x18],
    [0x01,0x09,0x42],[0x01,0x11,0x60],
  ],
  Belgium_lap_targets: [
    [0x00,0x52,0x80],[0x00,0x52,0x96],[0x00,0x53,0x20],[0x00,0x53,0x58],
    [0x00,0x53,0x96],[0x00,0x55,0x27],[0x00,0x55,0x93],[0x00,0x57,0x03],
    [0x00,0x58,0x97],[0x01,0x00,0x20],[0x01,0x01,0x54],[0x01,0x03,0x63],
    [0x01,0x05,0x77],[0x01,0x09,0x00],
  ],
  Usa_lap_targets: [
    [0x00,0x41,0x50],[0x00,0x41,0x66],[0x00,0x41,0x83],[0x00,0x42,0x51],
    [0x00,0x43,0x66],[0x00,0x44,0x73],[0x00,0x45,0x94],[0x00,0x47,0x13],
    [0x00,0x48,0x20],[0x00,0x49,0x49],[0x00,0x50,0x54],[0x00,0x52,0x57],
    [0x00,0x54,0x62],[0x00,0x56,0x65],
  ],
  Australia_lap_targets: [
    [0x00,0x46,0x20],[0x00,0x46,0x36],[0x00,0x46,0x55],[0x00,0x46,0x87],
    [0x00,0x47,0x58],[0x00,0x48,0x69],[0x00,0x49,0x76],[0x00,0x50,0x92],
    [0x00,0x52,0x05],[0x00,0x53,0x19],[0x00,0x54,0x23],[0x00,0x55,0x41],
    [0x00,0x56,0x19],[0x00,0x57,0x30],
  ],
  Monaco_lap_targets: [
    [0x00,0x45,0x20],[0x00,0x45,0x36],[0x00,0x45,0x55],[0x00,0x46,0x71],
    [0x00,0x47,0x89],[0x00,0x48,0x92],[0x00,0x50,0x08],[0x00,0x51,0x22],
    [0x00,0x52,0x39],[0x00,0x53,0x58],[0x00,0x55,0x86],[0x00,0x58,0x05],
    [0x01,0x00,0x16],[0x01,0x02,0x35],
  ],
  Monaco_arcade_lap_targets: [
    [0x00,0x32,0x00],[0x00,0x32,0x18],[0x00,0x32,0x43],[0x00,0x32,0x70],
    [0x00,0x32,0x85],[0x00,0x33,0x46],[0x00,0x33,0x73],[0x00,0x34,0x16],
    [0x00,0x34,0x75],[0x00,0x35,0x42],[0x00,0x35,0x91],[0x00,0x36,0x72],
    [0x00,0x38,0x88],[0x00,0x40,0x41],
  ],
};

// ---------------------------------------------------------------------------
// Curve RLE decoder
// ---------------------------------------------------------------------------
/**
 * Decode curve RLE binary to a list of segment objects.
 * Key: third byte (curve_byte) determines record size.
 *   0x00 -> straight (3 bytes)
 *   !0x00 -> curve (5 bytes)
 *   First byte == 0xFF -> terminator
 * @param {Buffer} data
 * @returns {Array}
 */
function decodeCurveRle(data) {
  const segments = [];
  let i = 0;
  const n = data.length;
  while (i < n) {
    const b0 = data[i];
    if (b0 === 0xFF) {
      // Terminator: 0xFF optionally followed by one more byte.
      if (i + 1 < n) {
        const b1 = data[i + 1];
        segments.push({ type: 'terminator', curve_byte: 0xFF, length: b1, _raw: [0xFF, b1] });
        i += 2;
      } else {
        segments.push({ type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF] });
        i += 1;
      }
      break;
    }
    if (i + 2 >= n) break;
    const b1 = data[i + 1];
    const b2 = data[i + 2];
    const length = (b0 << 8) | b1;
    if (b2 === 0x00) {
      segments.push({ type: 'straight', length, curve_byte: 0 });
      i += 3;
    } else {
      if (i + 4 >= n) break;
      const b3 = data[i + 3];
      const b4 = data[i + 4];
      // signed 16-bit big-endian
      let bgDisp = (b3 << 8) | b4;
      if (bgDisp >= 0x8000) bgDisp -= 0x10000;
      segments.push({ type: 'curve', length, curve_byte: b2, bg_disp: bgDisp });
      i += 5;
    }
  }
  return segments;
}

/**
 * Expand decoded curve segments into a flat array of curve bytes.
 * @param {Array} segments
 * @returns {number[]}
 */
function decompressCurve(segments) {
  const result = [];
  for (const seg of segments) {
    if (seg.type === 'straight' || seg.type === 'curve') {
      for (let j = 0; j < seg.length; j++) result.push(seg.curve_byte);
    } else if (seg.type === 'terminator') {
      result.push(seg.curve_byte); // 0xFF
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Visual slope RLE decoder
// ---------------------------------------------------------------------------
/**
 * Decode visual slope RLE binary.
 * Returns { initialBgDisp, segments }
 * @param {Buffer} data
 * @returns {{ initialBgDisp: number, segments: Array }}
 */
function decodeSlopeRle(data) {
  if (data.length < 1) return { initialBgDisp: 0, segments: [] };
  // Read header byte as signed
  let initialBgDisp = data[0];
  if (initialBgDisp >= 0x80) initialBgDisp -= 0x100;
  const segments = [];
  let i = 1;
  const n = data.length;
  while (i < n) {
    const b0 = data[i];
    if (b0 === 0xFF) {
      const raw = (i + 1 < n) ? [0xFF, data[i + 1]] : [0xFF];
      segments.push({ type: 'terminator', length: 0, slope_byte: 0xFF, _raw: raw });
      i += raw.length;
      break;
    }
    if (i + 2 >= n) break;
    const b1 = data[i + 1];
    const b2 = data[i + 2];
    const length = (b0 << 8) | b1;
    if (b2 === 0x00) {
      segments.push({ type: 'flat', length, slope_byte: 0, bg_vert_disp: 0 });
      i += 3;
    } else {
      if (i + 3 >= n) break;
      const b3 = data[i + 3];
      let bgVertDisp = b3;
      if (bgVertDisp >= 0x80) bgVertDisp -= 0x100;
      segments.push({ type: 'slope', length, slope_byte: b2, bg_vert_disp: bgVertDisp });
      i += 4;
    }
  }
  return { initialBgDisp, segments };
}

/**
 * Expand decoded slope segments into a flat array of slope bytes.
 * @param {Array} segments
 * @returns {number[]}
 */
function decompressSlope(segments) {
  const result = [];
  for (const seg of segments) {
    if (seg.type === 'flat' || seg.type === 'slope') {
      for (let j = 0; j < seg.length; j++) result.push(seg.slope_byte);
    } else if (seg.type === 'terminator') {
      result.push(seg.slope_byte); // 0xFF
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Physical slope RLE decoder
// ---------------------------------------------------------------------------
/**
 * Decode physical slope RLE binary.
 * No header; segments are 3 bytes; high bit in first byte = terminator.
 * @param {Buffer} data
 * @returns {Array}
 */
function decodePhysSlopeRle(data) {
  const segments = [];
  let i = 0;
  const n = data.length;
  while (i < n) {
    const remaining = n - i;
    if (remaining < 3) {
      // Fewer than 3 bytes left — raw trailing blob (e.g. monaco_arcade_prelim)
      segments.push({ type: 'terminator', length: 0, phys_byte: 0, _raw: Array.from(data.slice(i)) });
      break;
    }
    const b0 = data[i];
    const b1 = data[i + 1];
    const b2 = data[i + 2];
    const length = (b0 << 8) | b1;
    let physByte = b2;
    if (physByte >= 0x80) physByte -= 0x100;
    if (b0 >= 0x80) {
      // Terminator record: consume but do not expand
      segments.push({ type: 'terminator', length, phys_byte: physByte, _raw: [b0, b1, b2] });
      i += 3;
      break;
    }
    segments.push({ type: 'segment', length, phys_byte: physByte });
    i += 3;
  }
  return segments;
}

/**
 * Expand physical slope segments into a flat array of signed bytes.
 * @param {Array} segments
 * @returns {number[]}
 */
function decompressPhysSlope(segments) {
  const result = [];
  for (const seg of segments) {
    if (seg.type === 'segment') {
      for (let j = 0; j < seg.length; j++) result.push(seg.phys_byte);
    }
    // terminator is not expanded
  }
  return result;
}

// ---------------------------------------------------------------------------
// Sign data parser
// ---------------------------------------------------------------------------
/**
 * Parse sign data binary.
 * Format: 4 bytes per record: distance.w (big-endian), count.b, sign_id.b
 * Terminated by 0xFFFF distance word.
 * @param {Buffer} data
 * @returns {Array}
 */
function parseSignData(data) {
  const records = [];
  let i = 0;
  const n = data.length;
  while (i + 3 < n) {
    const dist = (data[i] << 8) | data[i + 1];
    if (dist === 0xFFFF) break;
    const count  = data[i + 2];
    const signId = data[i + 3];
    records.push({ distance: dist, count, sign_id: signId });
    i += 4;
  }
  return records;
}

// ---------------------------------------------------------------------------
// Sign tileset parser
// ---------------------------------------------------------------------------
/**
 * Parse sign tileset binary.
 * Format: 4 bytes per entry: distance.w, tileset_offset.w
 * Terminated by 0xFFFF.
 * Returns { records, trailingBytes }
 * @param {Buffer} data
 * @returns {{ records: Array, trailingBytes: number[] }}
 */
function parseSignTileset(data) {
  const records = [];
  let i = 0;
  const n = data.length;
  while (i + 1 < n) {
    const dist = (data[i] << 8) | data[i + 1];
    if (dist === 0xFFFF) {
      const termEnd = i + 2;
      const trailingBytes = termEnd < n ? Array.from(data.slice(termEnd)) : [];
      return { records, trailingBytes };
    }
    if (i + 3 >= n) break;
    const tilesetOffset = (data[i + 2] << 8) | data[i + 3];
    records.push({ distance: dist, tileset_offset: tilesetOffset });
    i += 4;
  }
  return { records, trailingBytes: [] };
}

// ---------------------------------------------------------------------------
// Minimap position parser
// ---------------------------------------------------------------------------
/**
 * Parse minimap position binary.
 * Format: flat array of (x, y) signed byte pairs; no terminator.
 * Returns { pairs, trailingBytes }
 * @param {Buffer} data
 * @returns {{ pairs: Array, trailingBytes: number[] }}
 */
function parseMinimapPos(data) {
  const n = data.length;
  const pairCount = Math.floor(n / 2);
  const pairs = [];
  for (let i = 0; i < pairCount; i++) {
    let x = data[i * 2];
    let y = data[i * 2 + 1];
    if (x >= 0x80) x -= 0x100;
    if (y >= 0x80) y -= 0x100;
    pairs.push([x, y]);
  }
  const trailingBytes = (n % 2 !== 0) ? [data[pairCount * 2]] : [];
  return { pairs, trailingBytes };
}

// ---------------------------------------------------------------------------
// Main extractor
// ---------------------------------------------------------------------------
/**
 * Extract all data for one track into a JSON-serializable object.
 * @param {object} trackMeta
 * @param {string} dataDir
 * @param {boolean} verbose
 * @returns {object}
 */
function extractTrack(trackMeta, dataDir, verbose = false) {
  const slug = trackMeta.slug;
  const trackDir = path.join(dataDir, slug);

  function readBin(filename) {
    const p = path.join(trackDir, filename);
    if (!fs.existsSync(p)) return null;
    return fs.readFileSync(p);
  }

  const curveBin   = readBin('curve_data.bin');
  const slopeBin   = readBin('slope_data.bin');
  const physBin    = readBin('phys_slope_data.bin');
  const signBin    = readBin('sign_data.bin');
  const tilesetBin = readBin('sign_tileset.bin');
  const minimapBin = readBin('minimap_pos.bin');

  const missingFiles = [
    ['curve_data.bin', curveBin],
    ['slope_data.bin', slopeBin],
    ['phys_slope_data.bin', physBin],
    ['sign_data.bin', signBin],
    ['sign_tileset.bin', tilesetBin],
    ['minimap_pos.bin', minimapBin],
  ].filter(([, b]) => b === null).map(([name]) => name);

  if (missingFiles.length > 0) {
    warn(`${slug}: missing files: ${missingFiles.join(', ')}`);
  }

  // Decode curve data
  const curveSegments    = curveBin ? decodeCurveRle(curveBin) : [];
  const curveDecompressed = decompressCurve(curveSegments);

  // Decode visual slope data
  let slopeInitialBg = 0;
  let slopeSegments = [];
  let slopeDecompressed = [];
  if (slopeBin) {
    const r = decodeSlopeRle(slopeBin);
    slopeInitialBg    = r.initialBgDisp;
    slopeSegments     = r.segments;
    slopeDecompressed = decompressSlope(slopeSegments);
  }

  // Decode physical slope data
  const physSegments    = physBin ? decodePhysSlopeRle(physBin) : [];
  const physDecompressed = decompressPhysSlope(physSegments);

  // Parse sign data
  const signRecords = signBin ? parseSignData(signBin) : [];

  // Parse sign tileset
  let tilesetRecords = [];
  let tilesetTrailing = [];
  if (tilesetBin) {
    const r = parseSignTileset(tilesetBin);
    tilesetRecords  = r.records;
    tilesetTrailing = r.trailingBytes;
  }

  // Parse minimap positions
  let minimapPairs    = [];
  let minimapTrailing = [];
  if (minimapBin) {
    const r = parseMinimapPos(minimapBin);
    minimapPairs    = r.pairs;
    minimapTrailing = r.trailingBytes;
  }

  // Lap targets
  const lapTargetsData = LAP_TARGETS[trackMeta.lap_targets_name] || [];

  if (verbose) {
    let msg = `  ${slug}: curve=${curveDecompressed.length} steps, ` +
      `slope=${slopeDecompressed.length}, phys=${physDecompressed.length}, ` +
      `signs=${signRecords.length}, tilesets=${tilesetRecords.length}, ` +
      `minimap=${minimapPairs.length} pairs`;
    if (minimapTrailing.length > 0) msg += `, minimap_trailing=${JSON.stringify(minimapTrailing)}`;
    if (tilesetTrailing.length > 0) msg += `, tileset_trailing=${JSON.stringify(tilesetTrailing)}`;
    info(msg);
  }

  return {
    index:                  trackMeta.index,
    name:                   trackMeta.name,
    slug:                   trackMeta.slug,
    track_length:           trackMeta.track_length,
    horizon_override:       trackMeta.horizon_override,
    steering_straight:      trackMeta.steering_straight,
    steering_curve:         trackMeta.steering_curve,
    lap_record_ptr_offset:  trackMeta.lap_record_ptr_offset,
    lap_targets_name:       trackMeta.lap_targets_name,
    lap_targets:            lapTargetsData,
    files: {
      curve_data:      `${slug}/curve_data.bin`,
      slope_data:      `${slug}/slope_data.bin`,
      phys_slope_data: `${slug}/phys_slope_data.bin`,
      sign_data:       `${slug}/sign_data.bin`,
      sign_tileset:    `${slug}/sign_tileset.bin`,
      minimap_pos:     `${slug}/minimap_pos.bin`,
    },
    curve_rle_segments:      curveSegments,
    curve_decompressed:      curveDecompressed,
    slope_initial_bg_disp:   slopeInitialBg,
    slope_rle_segments:      slopeSegments,
    slope_decompressed:      slopeDecompressed,
    phys_slope_rle_segments: physSegments,
    phys_slope_decompressed: physDecompressed,
    sign_data:               signRecords,
    sign_tileset:            tilesetRecords,
    sign_tileset_trailing:   tilesetTrailing,
    minimap_pos:             minimapPairs,
    minimap_pos_trailing:    minimapTrailing,
  };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--verbose', '-v'],
    options: ['--datadir', '--out'],
  });

  const verbose  = args.flags['--verbose'] || args.flags['-v'];
  const dataDirArg = args.options['--datadir'] || 'data/tracks';
  const outArg     = args.options['--out']     || 'tools/data/tracks.json';

  const dataDir = path.resolve(REPO_ROOT, dataDirArg);
  const outPath = path.resolve(REPO_ROOT, outArg);

  if (!fs.existsSync(dataDir) || !fs.statSync(dataDir).isDirectory()) {
    die(`data directory not found: ${dataDir}`);
  }

  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  info(`Extracting ${TRACKS.length} tracks from ${dataDir} ...`);
  const tracksJson = [];
  for (const trackMeta of TRACKS) {
    if (verbose) info(`  Track ${String(trackMeta.index).padStart(2)}: ${trackMeta.name}`);
    tracksJson.push(extractTrack(trackMeta, dataDir, verbose));
  }

  const output = {
    _meta: {
      description:     'Super Monaco GP track data — extracted from data/tracks/ binaries',
      generated_by:    'tools/extract_track_data.js (EXTR-001)',
      track_count:     tracksJson.length,
      format_version:  1,
    },
    tracks: tracksJson,
  };

  fs.writeFileSync(outPath, JSON.stringify(output, null, 2));
  info(`Written: ${outPath}`);
  info(`  ${tracksJson.length} tracks extracted.`);
}

if (require.main === module) main();

module.exports = {
  TRACKS, LAP_TARGETS,
  decodeCurveRle, decompressCurve,
  decodeSlopeRle, decompressSlope,
  decodePhysSlopeRle, decompressPhysSlope,
  parseSignData, parseSignTileset, parseMinimapPos,
  extractTrack,
};
