#!/usr/bin/env node
// tools/inject_track_data.js
//
// EXTR-002 (JS port): Track data injector — tools/data/tracks.json -> data/tracks/ binaries
//
// Reads tools/data/tracks.json, re-encodes all track data streams, and writes
// the binary files back to data/tracks/<slug>/*.bin.
//
// Usage:
//   node tools/inject_track_data.js [--input tools/data/tracks.json]
//                                    [--datadir data/tracks]
//                                    [--dry-run] [-v]
//                                    [--tracks SLUG [SLUG ...]]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT } = require('./lib/rom');
const {
	getTracks,
	getTrackMinimapPairs,
	getTrackMinimapTrailing,
	getTrackSignData,
	getTrackSignTileset,
	getTrackSignTilesetTrailing,
	requireInjectableTrackShape,
	requireTracksDataShape,
} = require('./randomizer/track_model');

// ---------------------------------------------------------------------------
// Curve RLE encoder
// ---------------------------------------------------------------------------
/**
 * Encode curve RLE segments to a Buffer.
 * @param {Array} segments
 * @returns {Buffer}
 */
function encodeCurveRle(segments) {
  const parts = [];
  for (const seg of segments) {
    if (seg.type === 'straight') {
      const { length } = seg;
      parts.push(Buffer.from([(length >> 8) & 0xFF, length & 0xFF, 0x00]));
    } else if (seg.type === 'curve') {
      const { length, curve_byte, bg_disp } = seg;
      const buf = Buffer.alloc(5);
      buf[0] = (length >> 8) & 0xFF;
      buf[1] = length & 0xFF;
      buf[2] = curve_byte & 0xFF;
      buf.writeInt16BE(bg_disp, 3);
      parts.push(buf);
    } else if (seg.type === 'terminator') {
      if (seg._raw) {
        parts.push(Buffer.from(seg._raw));
      } else {
        parts.push(Buffer.from([0xFF, (seg.length || 0) & 0xFF]));
      }
    } else {
      throw new Error(`Unknown curve segment type: ${seg.type}`);
    }
  }
  return Buffer.concat(parts);
}

// ---------------------------------------------------------------------------
// Visual slope RLE encoder
// ---------------------------------------------------------------------------
/**
 * Encode visual slope RLE to a Buffer.
 * @param {number} initialBgDisp  signed byte
 * @param {Array}  segments
 * @returns {Buffer}
 */
function encodeSlopeRle(initialBgDisp, segments) {
  const parts = [];
  // Header byte: initial vertical BG displacement (signed -> unsigned byte)
  const headerBuf = Buffer.alloc(1);
  headerBuf.writeInt8(initialBgDisp, 0);
  parts.push(headerBuf);
  for (const seg of segments) {
    if (seg.type === 'flat') {
      const { length } = seg;
      parts.push(Buffer.from([(length >> 8) & 0xFF, length & 0xFF, 0x00]));
    } else if (seg.type === 'slope') {
      const { length, slope_byte, bg_vert_disp } = seg;
      const buf = Buffer.alloc(4);
      buf[0] = (length >> 8) & 0xFF;
      buf[1] = length & 0xFF;
      buf[2] = slope_byte & 0xFF;
      buf.writeInt8(bg_vert_disp, 3);
      parts.push(buf);
    } else if (seg.type === 'terminator') {
      if (seg._raw) {
        parts.push(Buffer.from(seg._raw));
      } else {
        parts.push(Buffer.from([0xFF]));
      }
    } else {
      throw new Error(`Unknown slope segment type: ${seg.type}`);
    }
  }
  return Buffer.concat(parts);
}

// ---------------------------------------------------------------------------
// Physical slope RLE encoder
// ---------------------------------------------------------------------------
/**
 * Encode physical slope RLE to a Buffer.
 * @param {Array} segments
 * @returns {Buffer}
 */
function encodePhysSlopeRle(segments) {
  const parts = [];
  for (const seg of segments) {
    if (seg.type === 'segment') {
      const { length, phys_byte } = seg;
      const buf = Buffer.alloc(3);
      buf[0] = (length >> 8) & 0xFF;
      buf[1] = length & 0xFF;
      buf.writeInt8(phys_byte, 2);
      parts.push(buf);
    } else if (seg.type === 'terminator') {
      if (seg._raw) {
        parts.push(Buffer.from(seg._raw));
      } else {
        // Reconstruct: ensure high bit is set in b0
        const { length, phys_byte } = seg;
        const b0 = ((length >> 8) & 0xFF) | 0x80;
        const b1 = length & 0xFF;
        const buf = Buffer.alloc(3);
        buf[0] = b0;
        buf[1] = b1;
        buf.writeInt8(phys_byte, 2);
        parts.push(buf);
      }
    } else {
      throw new Error(`Unknown phys_slope segment type: ${seg.type}`);
    }
  }
  return Buffer.concat(parts);
}

// ---------------------------------------------------------------------------
// Sign data encoder
// ---------------------------------------------------------------------------
/**
 * Encode sign data records to a Buffer.
 * @param {Array} records  [{distance, count, sign_id}, ...]
 * @returns {Buffer}
 */
function encodeSignData(records) {
  const parts = [];
  for (const rec of records) {
    const buf = Buffer.alloc(4);
    buf.writeUInt16BE(rec.distance, 0);
    buf[2] = rec.count & 0xFF;
    buf[3] = rec.sign_id & 0xFF;
    parts.push(buf);
  }
  parts.push(Buffer.from([0xFF, 0xFF]));
  return Buffer.concat(parts);
}

// ---------------------------------------------------------------------------
// Sign tileset encoder
// ---------------------------------------------------------------------------
/**
 * Encode sign tileset records to a Buffer.
 * @param {Array} records         [{distance, tileset_offset}, ...]
 * @param {number[]} [trailingBytes]
 * @returns {Buffer}
 */
function encodeSignTileset(records, trailingBytes = null) {
  const parts = [];
  for (const rec of records) {
    const buf = Buffer.alloc(4);
    buf.writeUInt16BE(rec.distance, 0);
    buf.writeUInt16BE(rec.tileset_offset, 2);
    parts.push(buf);
  }
  parts.push(Buffer.from([0xFF, 0xFF]));
  if (trailingBytes && trailingBytes.length > 0) {
    parts.push(Buffer.from(trailingBytes));
  }
  return Buffer.concat(parts);
}

// ---------------------------------------------------------------------------
// Minimap position encoder
// ---------------------------------------------------------------------------
/**
 * Encode minimap position pairs to a Buffer.
 * @param {Array}    pairs          [[x, y], ...]  signed bytes
 * @param {number[]} [trailingBytes]
 * @returns {Buffer}
 */
function encodeMinimapPos(pairs, trailingBytes = null) {
  const parts = [];
  for (const pair of pairs) {
    const buf = Buffer.alloc(2);
    buf.writeInt8(pair[0], 0);
    buf.writeInt8(pair[1], 1);
    parts.push(buf);
  }
  if (trailingBytes && trailingBytes.length > 0) {
    parts.push(Buffer.from(trailingBytes));
  }
  return Buffer.concat(parts);
}

// ---------------------------------------------------------------------------
// Single-track injector
// ---------------------------------------------------------------------------
/**
 * Re-encode and write all binary files for one track.
 * Returns a map of filename -> { oldSize, newSize, changed }.
 * @param {object} track
 * @param {string} dataDir
 * @param {boolean} dryRun
 * @param {boolean} verbose
 * @returns {object}
 */
function injectTrack(track, dataDir, dryRun = false, verbose = false) {
  requireInjectableTrackShape(track);
  const slug     = track.slug;
  const trackDir = path.join(dataDir, slug);

  const curveBytes   = encodeCurveRle(track.curve_rle_segments);
  const slopeBytes   = encodeSlopeRle(track.slope_initial_bg_disp, track.slope_rle_segments);
  const physBytes    = encodePhysSlopeRle(track.phys_slope_rle_segments);
  const signBytes    = encodeSignData(getTrackSignData(track));
  const tilesetBytes = encodeSignTileset(getTrackSignTileset(track), getTrackSignTilesetTrailing(track));
  const minimapBytes = encodeMinimapPos(getTrackMinimapPairs(track), getTrackMinimapTrailing(track));

  const files = {
    'curve_data.bin':      curveBytes,
    'slope_data.bin':      slopeBytes,
    'phys_slope_data.bin': physBytes,
    'sign_data.bin':       signBytes,
    'sign_tileset.bin':    tilesetBytes,
    'minimap_pos.bin':     minimapBytes,
  };

  const results = {};
  for (const [filename, newData] of Object.entries(files)) {
    const filePath = path.join(trackDir, filename);
    let oldSize = 0;
    let oldBytes = null;
    let changed = true;
    const writeData = newData;
    if (fs.existsSync(filePath)) {
      oldBytes = fs.readFileSync(filePath);
      oldSize = oldBytes.length;
      changed = !oldBytes.equals(writeData);
    }

    results[filename] = {
      oldSize,
      newSize: writeData.length,
      encodedSize: newData.length,
      changed,
    };

    if (verbose) {
      if (changed) {
        if (oldSize !== writeData.length) {
          info(`    ${filename}: ${oldSize} -> ${writeData.length} bytes (CHANGED SIZE)`);
        } else {
          info(`    ${filename}: ${writeData.length} bytes (content changed)`);
        }
      } else {
        info(`    ${filename}: ${writeData.length} bytes (no change)`);
      }
    }

    if (!dryRun) {
      fs.mkdirSync(trackDir, { recursive: true });
      fs.writeFileSync(filePath, writeData);
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--dry-run', '--verbose', '-v'],
    options: ['--input', '--datadir', '--tracks'],
  });

  const dryRun   = args.flags['--dry-run'];
  const verbose  = args.flags['--verbose'] || args.flags['-v'];
  const inputArg  = args.options['--input']   || 'tools/data/tracks.json';
  const dataDirArg = args.options['--datadir'] || 'data/tracks';
  const tracksArg  = args.options['--tracks'];

  const inputPath = path.resolve(REPO_ROOT, inputArg);
  const dataDir   = path.resolve(REPO_ROOT, dataDirArg);

  if (!fs.existsSync(inputPath)) die(`input JSON not found: ${inputPath}`);

  const jsonData = requireTracksDataShape(JSON.parse(fs.readFileSync(inputPath, 'utf8')));
  let tracks = getTracks(jsonData);

  // --tracks accepts space-separated slugs as a single string (from CLI)
  if (tracksArg) {
    const filterSlugs = new Set(tracksArg.split(/\s+/).filter(Boolean));
    tracks = tracks.filter(t => filterSlugs.has(t.slug));
    if (tracks.length === 0) die(`no tracks matched slugs: ${tracksArg}`);
  }

  if (dryRun) {
    info(`DRY RUN: would inject ${tracks.length} tracks into ${dataDir}`);
  } else {
    info(`Injecting ${tracks.length} tracks into ${dataDir} ...`);
  }

  let totalChanged = 0;
  let totalSizeChanges = 0;
  const errors = [];

  for (const track of tracks) {
    const slug = track.slug;
    if (verbose) info(`  Track ${String(track.index).padStart(2)}: ${track.name} (${slug})`);

    let results;
    try {
      results = injectTrack(track, dataDir, dryRun, verbose);
    } catch (err) {
      errors.push([slug, err]);
      process.stderr.write(`  ERROR: ${slug}: ${err.message}\n`);
      continue;
    }

    for (const { oldSize, newSize, changed } of Object.values(results)) {
      if (changed) totalChanged++;
      if (oldSize !== newSize) totalSizeChanges++;
    }
  }

  if (errors.length > 0) {
    process.stderr.write(`\n${errors.length} track(s) had errors:\n`);
    for (const [slug, err] of errors) {
      process.stderr.write(`  ${slug}: ${err.message}\n`);
    }
    process.exit(1);
  }

  if (dryRun) {
    if (totalChanged === 0) {
      info('No files would change (no-op round-trip verified).');
    } else {
      info(`${totalChanged} file(s) would change (${totalSizeChanges} with size changes).`);
    }
  } else {
    if (totalChanged === 0) {
      info('No files changed (no-op round-trip verified).');
    } else {
      info(`${totalChanged} file(s) updated (${totalSizeChanges} with size changes).`);
    }
    info('Done. Run verify.bat to confirm bit-perfect build.');
  }
}

if (require.main === module) main();

module.exports = {
  encodeCurveRle, encodeSlopeRle, encodePhysSlopeRle,
  encodeSignData, encodeSignTileset, encodeMinimapPos,
  injectTrack,
};
