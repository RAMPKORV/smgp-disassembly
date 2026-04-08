#!/usr/bin/env node
// tools/editor/track_editor.js
//
// NODE-005: Track editor CLI (JS port of tools/editor/track_editor.py)
//
// Argument-driven CLI for editing Super Monaco GP track data.  All edits
// operate on tools/data/tracks.json (the structured edit layer), run the
// track validator before saving, then inject the modified binaries to
// data/tracks/ via inject_track_data.js.
//
// The editor NEVER touches src/*.asm files directly.
// The inject step writes data/tracks/<slug>/*.bin; the assembler picks them
// up via incbin directives in src/road_and_track_data.asm.  Run verify.bat
// after inject to confirm the build is still bit-perfect (only relevant when
// editing an unmodified ROM — see docs/modding_architecture.md).
//
// Usage:
//   node tools/editor/track_editor.js list
//   node tools/editor/track_editor.js show TRACK [--section curves|slopes|signs|minimap|all]
//   node tools/editor/track_editor.js set-field TRACK FIELD VALUE
//   node tools/editor/track_editor.js set-curve TRACK INDEX [--length N] [--type straight|left|right] [--sharpness N] [--bg-disp N]
//   node tools/editor/track_editor.js add-curve TRACK [--after INDEX] --type straight|left|right --length N [--sharpness N] [--bg-disp N]
//   node tools/editor/track_editor.js del-curve TRACK INDEX
//   node tools/editor/track_editor.js set-slope TRACK INDEX [--length N] [--type flat|down|up] [--sharpness N] [--bg-vert-disp N]
//   node tools/editor/track_editor.js add-slope TRACK [--after INDEX] --type flat|down|up --length N [--sharpness N] [--bg-vert-disp N]
//   node tools/editor/track_editor.js del-slope TRACK INDEX
//   node tools/editor/track_editor.js set-sign TRACK INDEX [--distance N] [--count N] [--sign-id N]
//   node tools/editor/track_editor.js add-sign TRACK [--after INDEX] --distance N --count N --sign-id N
//   node tools/editor/track_editor.js del-sign TRACK INDEX
//   node tools/editor/track_editor.js validate [TRACK]
//   node tools/editor/track_editor.js inject [TRACK] [--dry-run] [--no-validate]
//
// TRACK argument: track index (0-18), name substring match (case-insensitive),
//                 or slug (e.g. "san_marino", "monaco_arcade").

'use strict';

const fs   = require('fs');
const path = require('path');

const TOOLS_DIR   = path.resolve(__dirname, '..');
const REPO_ROOT   = path.resolve(TOOLS_DIR, '..');
const TRACKS_JSON = path.join(TOOLS_DIR, 'data', 'tracks.json');
const DATA_TRACKS = path.join(REPO_ROOT, 'data', 'tracks');

const { injectTrack } = require('../inject_track_data');

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------
function out(msg)  { process.stdout.write(msg + '\n'); }
function err(msg)  { process.stderr.write('ERROR: ' + msg + '\n'); }
function warn(msg) { process.stderr.write('WARNING: ' + msg + '\n'); }
function die(msg)  { err(msg); process.exit(1); }

// ---------------------------------------------------------------------------
// JSON load / save
// ---------------------------------------------------------------------------
function loadTracksJson(jsonPath) {
  jsonPath = jsonPath || TRACKS_JSON;
  if (!fs.existsSync(jsonPath)) {
    die(`tracks.json not found: ${jsonPath}\n  Run: node tools/extract_track_data.js`);
  }
  return JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
}

function saveTracksJson(data, jsonPath) {
  jsonPath = jsonPath || TRACKS_JSON;
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// ---------------------------------------------------------------------------
// Track validation (inline — mirrors track_validator.py)
// ---------------------------------------------------------------------------
function validateTrack(track) {
  const errors = [];
  const name = track.name || track.slug || String(track.index);

  // track_length
  const tlen = track.track_length;
  if (!Number.isInteger(tlen) || tlen <= 0 || tlen % 64 !== 0 || tlen < 64 || tlen > 8192) {
    errors.push({ track_name: name, field: 'track_length', message: `${tlen}: must be positive multiple of 64, range 64-8192` });
  }

  // curve_rle_segments
  const curveSegs = track.curve_rle_segments || [];
  const curveData = curveSegs.filter(s => s.type !== 'terminator');
  const curveTerm = curveSegs.filter(s => s.type === 'terminator');
  if (curveTerm.length !== 1) {
    errors.push({ track_name: name, field: 'curve_rle_segments', message: `expected exactly 1 terminator, got ${curveTerm.length}` });
  } else if (curveTerm[0] !== curveSegs[curveSegs.length - 1]) {
    errors.push({ track_name: name, field: 'curve_rle_segments', message: 'terminator must be the last segment' });
  }
  const curveTotal = curveData.reduce((s, seg) => s + (seg.length || 0), 0);
  const expectedCurveLen = Math.floor(tlen / 4);
  if (curveTotal !== expectedCurveLen) {
    errors.push({ track_name: name, field: 'curve_rle_segments', message: `total length ${curveTotal} != track_length/4 (${expectedCurveLen})` });
  }
  for (const seg of curveData) {
    const cb = seg.curve_byte;
    if (seg.type === 'straight') {
      if (cb !== 0) errors.push({ track_name: name, field: 'curve_rle_segments', message: `straight segment has curve_byte=${cb}, expected 0` });
    } else if (seg.type === 'curve') {
      if (!((cb >= 0x01 && cb <= 0x2F) || (cb >= 0x41 && cb <= 0x6F))) {
        errors.push({ track_name: name, field: 'curve_rle_segments', message: `invalid curve_byte ${cb}` });
      }
    }
  }

  // slope_rle_segments
  const slopeSegs = track.slope_rle_segments || [];
  const slopeData = slopeSegs.filter(s => s.type !== 'terminator');
  const slopeTerm = slopeSegs.filter(s => s.type === 'terminator');
  if (slopeTerm.length !== 1) {
    errors.push({ track_name: name, field: 'slope_rle_segments', message: `expected exactly 1 terminator, got ${slopeTerm.length}` });
  }
  const slopeTotal = slopeData.reduce((s, seg) => s + (seg.length || 0), 0);
  if (slopeTotal !== expectedCurveLen) {
    errors.push({ track_name: name, field: 'slope_rle_segments', message: `total length ${slopeTotal} != track_length/4 (${expectedCurveLen})` });
  }

  // phys_slope_rle_segments
  const physSegs = track.phys_slope_rle_segments || [];
  const physData = physSegs.filter(s => s.type !== 'terminator');
  const physTerm = physSegs.filter(s => s.type === 'terminator');
  if (physTerm.length !== 1) {
    errors.push({ track_name: name, field: 'phys_slope_rle_segments', message: `expected exactly 1 terminator, got ${physTerm.length}` });
  }
  for (const seg of physData) {
    if (![-1, 0, 1].includes(seg.phys_byte)) {
      errors.push({ track_name: name, field: 'phys_slope_rle_segments', message: `invalid phys_byte ${seg.phys_byte}: must be -1, 0, or +1` });
    }
  }

  // sign_data
  const signs = track.sign_data || [];
  let prevDist = -1;
  for (let i = 0; i < signs.length; i++) {
    const rec = signs[i];
    if (rec.distance <= prevDist) {
      errors.push({ track_name: name, field: 'sign_data', message: `sign_data[${i}].distance=${rec.distance} not strictly ascending (prev=${prevDist})` });
    }
    if (rec.distance < 0 || rec.distance >= tlen) {
      errors.push({ track_name: name, field: 'sign_data', message: `sign_data[${i}].distance=${rec.distance} out of range [0, ${tlen - 1}]` });
    }
    if (!Number.isInteger(rec.sign_id) || rec.sign_id < 0 || rec.sign_id > 255) {
      errors.push({ track_name: name, field: 'sign_data', message: `sign_data[${i}].sign_id=${rec.sign_id}: must be 0-255` });
    }
    prevDist = rec.distance;
  }

  // sign_tileset
  const tileset = track.sign_tileset || [];
  let prevTsDist = -1;
  for (let i = 0; i < tileset.length; i++) {
    const rec = tileset[i];
    if (rec.distance < prevTsDist) {
      errors.push({ track_name: name, field: 'sign_tileset', message: `sign_tileset[${i}].distance not non-decreasing` });
    }
    if (rec.tileset_offset % 8 !== 0 || rec.tileset_offset < 0 || rec.tileset_offset > 88) {
      errors.push({ track_name: name, field: 'sign_tileset', message: `sign_tileset[${i}].tileset_offset=${rec.tileset_offset}: must be multiple of 8 in range 0-88` });
    }
    prevTsDist = rec.distance;
  }

  // minimap_pos
  const mm = track.minimap_pos || [];
  const expectedMM = tlen >> 6;
  if (mm.length !== expectedMM) {
    errors.push({ track_name: name, field: 'minimap_pos', message: `minimap_pos has ${mm.length} pairs, expected ${expectedMM} (track_length>>6)` });
  }
  for (let i = 0; i < mm.length; i++) {
    for (const coord of mm[i]) {
      if (!Number.isInteger(coord) || coord < -128 || coord > 127) {
        errors.push({ track_name: name, field: 'minimap_pos', message: `minimap_pos[${i}] coord ${coord} out of signed byte range` });
      }
    }
  }

  return errors;
}

function validateTracks(trackList) {
  const all = [];
  for (const t of trackList) {
    for (const e of validateTrack(t)) all.push(e);
  }
  return all;
}

// ---------------------------------------------------------------------------
// Track resolution
// ---------------------------------------------------------------------------
function resolveTrack(tracks, spec) {
  // Integer index
  const idx = parseInt(spec, 10);
  if (!isNaN(idx) && String(idx) === String(spec)) {
    const t = tracks.find(t => t.index === idx);
    if (!t) die(`No track with index ${idx}`);
    return t;
  }
  const specLower = spec.toLowerCase();
  // Exact slug match
  const bySlug = tracks.find(t => (t.slug || '').toLowerCase() === specLower);
  if (bySlug) return bySlug;
  // Name substring match
  const matches = tracks.filter(t => (t.name || '').toLowerCase().includes(specLower));
  if (matches.length === 1) return matches[0];
  if (matches.length > 1) {
    const names = matches.map(t => `[${t.index}] ${t.name}`).join(', ');
    die(`Ambiguous TRACK ${JSON.stringify(spec)} — matches: ${names}`);
  }
  die(`No track matching ${JSON.stringify(spec)}`);
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------
function curveByteDesc(cb) {
  if (cb === 0x00) return 'straight';
  if (cb >= 0x01 && cb <= 0x2F) return `left  sharpness=${cb}`;
  if (cb >= 0x41 && cb <= 0x6F) return `right sharpness=${cb & 0x2F}`;
  if (cb === 0xFF) return 'terminator';
  return `INVALID (0x${cb.toString(16).toUpperCase().padStart(2, '0')})`;
}

function slopeByteDesc(sb) {
  if (sb === 0x00) return 'flat';
  if (sb >= 0x01 && sb <= 0x2F) return `down  sharpness=${sb}`;
  if (sb >= 0x41 && sb <= 0x6F) return `up    sharpness=${sb & 0x2F}`;
  if (sb === 0xFF) return 'terminator';
  return `INVALID (0x${sb.toString(16).toUpperCase().padStart(2, '0')})`;
}

function fmtSteering(v) {
  return `${v} (0x${v.toString(16).toUpperCase().padStart(4, '0')})`;
}

// ---------------------------------------------------------------------------
// list command
// ---------------------------------------------------------------------------
function cmdList(tracks) {
  out(`${'Idx'.padStart(3)}  ${'Name'.padEnd(30)}  ${'Length'.padStart(6)}  ${'Curves'.padStart(6)}  ${'Signs'.padStart(5)}  ${'Horizon'.padStart(7)}`);
  out('-'.repeat(72));
  for (const t of tracks) {
    const nCurves = (t.curve_rle_segments || []).filter(s => s.type !== 'terminator').length;
    out(`${String(t.index).padStart(3)}  ${(t.name || '').padEnd(30)}  ${String(t.track_length).padStart(6)}  ${String(nCurves).padStart(6)}  ${String((t.sign_data || []).length).padStart(5)}  ${String(t.horizon_override || 0).padStart(7)}`);
  }
}

// ---------------------------------------------------------------------------
// show command
// ---------------------------------------------------------------------------
function cmdShow(track, section) {
  const t = track;
  section = (section || 'all').toLowerCase();

  out(`Track [${t.index}] ${t.name}  (slug: ${t.slug})`);
  out('');

  if (section === 'all' || section === 'info') {
    out('  SCALAR FIELDS');
    out(`    track_length      : ${t.track_length}`);
    out(`    horizon_override  : ${t.horizon_override || 0}`);
    out(`    steering_straight : ${fmtSteering(t.steering_straight || 0x002B)}`);
    out(`    steering_curve    : ${fmtSteering(t.steering_curve || 0x002B)}`);
    out(`    lap_targets_name  : ${t.lap_targets_name || '?'}`);
    out(`    slope_initial_bg  : ${t.slope_initial_bg_disp || 0}`);
    out('');
  }

  if (section === 'all' || section === 'curves') {
    const segs = t.curve_rle_segments || [];
    const dataSegs = segs.filter(s => s.type !== 'terminator');
    const totalSteps = dataSegs.reduce((s, seg) => s + seg.length, 0);
    out(`  CURVE SEGMENTS  (${dataSegs.length} data segments, ${totalSteps} total steps = track_length//4 = ${t.track_length >> 2})`);
    out(`  ${'Idx'.padStart(4)}  ${'Type'.padEnd(12)}  ${'Length'.padStart(6)}  ${'CurveByte'.padStart(9)}  ${'BgDisp'.padStart(8)}  Description`);
    out('  ' + '-'.repeat(65));
    segs.forEach((seg, i) => {
      if (seg.type === 'terminator') {
        out(`  ${String(i).padStart(4)}  ${'terminator'.padEnd(12)}  ${'--'.padStart(6)}  ${'0xFF'.padStart(9)}  ${'--'.padStart(8)}  lap-wrap sentinel`);
      } else if (seg.type === 'straight') {
        out(`  ${String(i).padStart(4)}  ${'straight'.padEnd(12)}  ${String(seg.length).padStart(6)}  ${'0'.padStart(9)}  ${'--'.padStart(8)}  straight`);
      } else {
        const cb = seg.curve_byte;
        const cbHex = '0x' + cb.toString(16).padStart(2, '0');
        out(`  ${String(i).padStart(4)}  ${'curve'.padEnd(12)}  ${String(seg.length).padStart(6)}  ${cbHex.padStart(9)}  ${String(seg.bg_disp || 0).padStart(8)}  ${curveByteDesc(cb)}`);
      }
    });
    out('');
  }

  if (section === 'all' || section === 'slopes') {
    const segs = t.slope_rle_segments || [];
    const init = t.slope_initial_bg_disp || 0;
    const dataSegs = segs.filter(s => s.type !== 'terminator');
    const totalSteps = dataSegs.reduce((s, seg) => s + seg.length, 0);
    out(`  SLOPE SEGMENTS  (initial_bg_disp=${init}, ${dataSegs.length} data segments, ${totalSteps} total steps)`);
    out(`  ${'Idx'.padStart(4)}  ${'Type'.padEnd(12)}  ${'Length'.padStart(6)}  ${'SlopeByte'.padStart(9)}  ${'BgVertDisp'.padStart(10)}  Description`);
    out('  ' + '-'.repeat(70));
    segs.forEach((seg, i) => {
      if (seg.type === 'terminator') {
        out(`  ${String(i).padStart(4)}  ${'terminator'.padEnd(12)}  ${'--'.padStart(6)}  ${'0xFF'.padStart(9)}  ${'--'.padStart(10)}  end-of-stream`);
      } else if (seg.type === 'flat') {
        out(`  ${String(i).padStart(4)}  ${'flat'.padEnd(12)}  ${String(seg.length).padStart(6)}  ${'0'.padStart(9)}  ${String(seg.bg_vert_disp || 0).padStart(10)}  flat`);
      } else {
        const sb = seg.slope_byte;
        const sbHex = '0x' + sb.toString(16).padStart(2, '0');
        out(`  ${String(i).padStart(4)}  ${'slope'.padEnd(12)}  ${String(seg.length).padStart(6)}  ${sbHex.padStart(9)}  ${String(seg.bg_vert_disp || 0).padStart(10)}  ${slopeByteDesc(sb)}`);
      }
    });
    out('');
  }

  if (section === 'all' || section === 'signs') {
    const signs   = t.sign_data || [];
    const tileset = t.sign_tileset || [];
    out(`  SIGN DATA  (${signs.length} records)`);
    if (signs.length > 0) {
      out(`  ${'Idx'.padStart(4)}  ${'Distance'.padStart(8)}  ${'Count'.padStart(5)}  ${'SignID'.padStart(6)}`);
      out('  ' + '-'.repeat(30));
      signs.forEach((rec, i) => {
        out(`  ${String(i).padStart(4)}  ${String(rec.distance).padStart(8)}  ${String(rec.count).padStart(5)}  ${String(rec.sign_id).padStart(6)}`);
      });
    }
    out('');
    out(`  SIGN TILESET  (${tileset.length} change records)`);
    if (tileset.length > 0) {
      out(`  ${'Idx'.padStart(4)}  ${'Distance'.padStart(8)}  ${'TilesetOffset'.padStart(13)}`);
      out('  ' + '-'.repeat(30));
      tileset.forEach((rec, i) => {
        out(`  ${String(i).padStart(4)}  ${String(rec.distance).padStart(8)}  ${String(rec.tileset_offset).padStart(13)}`);
      });
    }
    out('');
  }

  if (section === 'all' || section === 'minimap') {
    const mm = t.minimap_pos || [];
    const expected = t.track_length >> 6;
    out(`  MINIMAP  (${mm.length} pairs, expected ${expected} = track_length>>6)`);
    if (mm.length > 0) {
      for (let row = 0; row < mm.length; row += 8) {
        const chunk = mm.slice(row, row + 8);
        const pairsStr = chunk.map(p => `(${String(p[0]).padStart(4)},${String(p[1]).padStart(4)})`).join('  ');
        out(`  [${String(row).padStart(3)}]  ${pairsStr}`);
      }
    }
    out('');
  }
}

// ---------------------------------------------------------------------------
// set-field command
// ---------------------------------------------------------------------------
const SCALAR_FIELDS = {
  track_length:       'positive int multiple of 64, range 64-8192',
  horizon_override:   '0 or 1',
  steering_straight:  'e.g. 43 (0x2B) or 0x002B',
  steering_curve:     'e.g. 43 (0x2B), 46 (0x2E)',
};

function parseIntArg(str) {
  str = str.trim();
  if (str.startsWith('0x') || str.startsWith('0X')) return parseInt(str, 16);
  return parseInt(str, 10);
}

function cmdSetField(track, field, valueStr) {
  if (!Object.prototype.hasOwnProperty.call(SCALAR_FIELDS, field)) {
    die(`Unknown field ${JSON.stringify(field)}. Editable fields: ${Object.keys(SCALAR_FIELDS).join(', ')}`);
  }
  const value = parseIntArg(valueStr);
  if (isNaN(value)) die(`Cannot parse ${JSON.stringify(valueStr)} as integer`);

  if (field === 'track_length') {
    if (value <= 0 || value % 64 !== 0 || value < 64 || value > 8192) {
      die(`track_length ${value} invalid — ${SCALAR_FIELDS[field]}`);
    }
  } else if (field === 'horizon_override') {
    if (value !== 0 && value !== 1) die(`horizon_override must be 0 or 1`);
  }

  const old = track[field];
  track[field] = value;
  out(`  ${field}: ${old} -> ${value}`);
}

// ---------------------------------------------------------------------------
// Curve segment helpers
// ---------------------------------------------------------------------------
function makeCurveSegment(segType, length, sharpness, bgDisp) {
  if (length <= 0) die(`segment length must be positive, got ${length}`);
  if (segType === 'straight') {
    return { type: 'straight', length, curve_byte: 0 };
  }
  if (sharpness === null || sharpness === undefined) sharpness = 20;
  sharpness = Math.max(1, Math.min(47, Math.trunc(sharpness)));
  if (bgDisp === null || bgDisp === undefined) bgDisp = 100;
  if (bgDisp < -32768 || bgDisp > 32767) die(`bg_disp ${bgDisp} out of signed 16-bit range`);

  let curveByte;
  if (segType === 'left') {
    curveByte = Math.max(0x01, Math.min(0x2F, sharpness));
  } else if (segType === 'right') {
    curveByte = Math.max(0x41, Math.min(0x6F, 0x40 | sharpness));
  } else {
    die(`curve type must be straight|left|right, got ${JSON.stringify(segType)}`);
  }
  return { type: 'curve', length, curve_byte: curveByte, bg_disp: bgDisp };
}

function getCurveTerminator(track) {
  const segs = track.curve_rle_segments || [];
  const term = segs.find(s => s.type === 'terminator');
  return term || { type: 'terminator', curve_byte: 0xFF, length: 0, _raw: [0xFF, 0x00] };
}

function cmdSetCurve(track, index, segType, length, sharpness, bgDisp) {
  const segs     = track.curve_rle_segments || [];
  const dataSegs = segs.filter(s => s.type !== 'terminator');
  const termSeg  = getCurveTerminator(track);

  if (index < 0 || index >= dataSegs.length) {
    die(`Curve segment index ${index} out of range [0, ${dataSegs.length - 1}]`);
  }

  const seg = dataSegs[index];
  const oldType = seg.curve_byte === 0 ? 'straight' : (seg.curve_byte <= 0x2F ? 'left' : 'right');

  if (segType !== null && segType !== undefined) {
    const newLen = length !== null && length !== undefined ? length : seg.length;
    dataSegs[index] = makeCurveSegment(segType, newLen, sharpness, bgDisp);
    out(`  Curve segment ${index}: type changed ${oldType} -> ${segType}`);
  } else {
    let s = Object.assign({}, seg);
    if (length !== null && length !== undefined) {
      if (length <= 0) die(`length must be positive`);
      s.length = length;
      out(`  Curve segment ${index}: length -> ${length}`);
    }
    if (sharpness !== null && sharpness !== undefined) {
      const cb = s.curve_byte;
      if (cb === 0) {
        warn(`segment ${index} is a straight — sharpness ignored`);
      } else if (cb <= 0x2F) {
        s.curve_byte = Math.max(0x01, Math.min(0x2F, Math.trunc(sharpness)));
        out(`  Curve segment ${index}: sharpness -> ${sharpness} (curve_byte=0x${s.curve_byte.toString(16)})`);
      } else {
        s.curve_byte = 0x40 | Math.max(0x01, Math.min(0x2F, Math.trunc(sharpness)));
        out(`  Curve segment ${index}: sharpness -> ${sharpness} (curve_byte=0x${s.curve_byte.toString(16)})`);
      }
    }
    if (bgDisp !== null && bgDisp !== undefined) {
      s.bg_disp = Math.trunc(bgDisp);
      out(`  Curve segment ${index}: bg_disp -> ${bgDisp}`);
    }
    dataSegs[index] = s;
  }
  track.curve_rle_segments = [...dataSegs, termSeg];
}

function cmdAddCurve(track, after, segType, length, sharpness, bgDisp) {
  const segs     = track.curve_rle_segments || [];
  const dataSegs = segs.filter(s => s.type !== 'terminator');
  const termSeg  = getCurveTerminator(track);
  const newSeg   = makeCurveSegment(segType, length, sharpness, bgDisp);

  if (after === null || after === undefined) {
    dataSegs.push(newSeg);
    out(`  Added ${segType} curve segment (len=${length}) at end (index ${dataSegs.length - 1})`);
  } else {
    if (after < 0 || after >= dataSegs.length) {
      die(`--after index ${after} out of range [0, ${dataSegs.length - 1}]`);
    }
    dataSegs.splice(after + 1, 0, newSeg);
    out(`  Inserted ${segType} curve segment (len=${length}) after index ${after} (new index ${after + 1})`);
  }
  track.curve_rle_segments = [...dataSegs, termSeg];
}

function cmdDelCurve(track, index) {
  const segs     = track.curve_rle_segments || [];
  const dataSegs = segs.filter(s => s.type !== 'terminator');
  const termSeg  = getCurveTerminator(track);

  if (dataSegs.length <= 1) die('Cannot delete the last data segment (track must have at least one)');
  if (index < 0 || index >= dataSegs.length) {
    die(`Curve segment index ${index} out of range [0, ${dataSegs.length - 1}]`);
  }

  const removed = dataSegs.splice(index, 1)[0];
  out(`  Deleted curve segment ${index}: type=${removed.type} length=${removed.length}`);
  track.curve_rle_segments = [...dataSegs, termSeg];
}

// ---------------------------------------------------------------------------
// Slope segment helpers
// ---------------------------------------------------------------------------
function makeSlopeSegment(segType, length, sharpness, bgVertDisp) {
  if (length <= 0) die(`segment length must be positive, got ${length}`);
  if (segType === 'flat') {
    return { type: 'flat', length, slope_byte: 0, bg_vert_disp: 0 };
  }
  if (sharpness === null || sharpness === undefined) sharpness = 40;
  sharpness = Math.max(1, Math.min(47, Math.trunc(sharpness)));

  let slopeByte;
  if (segType === 'down') {
    slopeByte = Math.max(0x01, Math.min(0x2F, sharpness));
    if (bgVertDisp === null || bgVertDisp === undefined) bgVertDisp = -32;
  } else if (segType === 'up') {
    slopeByte = Math.max(0x41, Math.min(0x6F, 0x40 | sharpness));
    if (bgVertDisp === null || bgVertDisp === undefined) bgVertDisp = 112;
  } else {
    die(`slope type must be flat|down|up, got ${JSON.stringify(segType)}`);
  }
  if (bgVertDisp < -128 || bgVertDisp > 127) die(`bg_vert_disp ${bgVertDisp} out of signed byte range`);
  return { type: 'slope', length, slope_byte: slopeByte, bg_vert_disp: bgVertDisp };
}

function getSlopeTerminator(track) {
  const segs = track.slope_rle_segments || [];
  const term = segs.find(s => s.type === 'terminator');
  return term || { type: 'terminator', length: 0, slope_byte: 0xFF, _raw: [0xFF] };
}

function cmdSetSlope(track, index, segType, length, sharpness, bgVertDisp) {
  const segs     = track.slope_rle_segments || [];
  const dataSegs = segs.filter(s => s.type !== 'terminator');
  const termSeg  = getSlopeTerminator(track);

  if (index < 0 || index >= dataSegs.length) {
    die(`Slope segment index ${index} out of range [0, ${dataSegs.length - 1}]`);
  }

  const seg = dataSegs[index];
  const oldType = (seg.slope_byte || 0) === 0 ? 'flat' : ((seg.slope_byte || 0) <= 0x2F ? 'down' : 'up');

  if (segType !== null && segType !== undefined) {
    const newLen = length !== null && length !== undefined ? length : seg.length;
    dataSegs[index] = makeSlopeSegment(segType, newLen, sharpness, bgVertDisp);
    out(`  Slope segment ${index}: type changed ${oldType} -> ${segType}`);
  } else {
    let s = Object.assign({}, seg);
    if (length !== null && length !== undefined) {
      if (length <= 0) die(`length must be positive`);
      s.length = length;
      out(`  Slope segment ${index}: length -> ${length}`);
    }
    if (sharpness !== null && sharpness !== undefined) {
      const sb = s.slope_byte || 0;
      if (sb === 0) {
        warn(`segment ${index} is flat — sharpness ignored`);
      } else if (sb <= 0x2F) {
        s.slope_byte = Math.max(0x01, Math.min(0x2F, Math.trunc(sharpness)));
      } else {
        s.slope_byte = 0x40 | Math.max(0x01, Math.min(0x2F, Math.trunc(sharpness)));
      }
      out(`  Slope segment ${index}: sharpness -> ${sharpness}`);
    }
    if (bgVertDisp !== null && bgVertDisp !== undefined) {
      s.bg_vert_disp = Math.trunc(bgVertDisp);
      out(`  Slope segment ${index}: bg_vert_disp -> ${bgVertDisp}`);
    }
    dataSegs[index] = s;
  }
  track.slope_rle_segments = [...dataSegs, termSeg];
}

function cmdAddSlope(track, after, segType, length, sharpness, bgVertDisp) {
  const segs     = track.slope_rle_segments || [];
  const dataSegs = segs.filter(s => s.type !== 'terminator');
  const termSeg  = getSlopeTerminator(track);
  const newSeg   = makeSlopeSegment(segType, length, sharpness, bgVertDisp);

  if (after === null || after === undefined) {
    dataSegs.push(newSeg);
    out(`  Added ${segType} slope segment (len=${length}) at end (index ${dataSegs.length - 1})`);
  } else {
    if (after < 0 || after >= dataSegs.length) {
      die(`--after index ${after} out of range [0, ${dataSegs.length - 1}]`);
    }
    dataSegs.splice(after + 1, 0, newSeg);
    out(`  Inserted ${segType} slope segment (len=${length}) after index ${after} (new index ${after + 1})`);
  }
  track.slope_rle_segments = [...dataSegs, termSeg];
}

function cmdDelSlope(track, index) {
  const segs     = track.slope_rle_segments || [];
  const dataSegs = segs.filter(s => s.type !== 'terminator');
  const termSeg  = getSlopeTerminator(track);

  if (dataSegs.length <= 1) die('Cannot delete the last data segment');
  if (index < 0 || index >= dataSegs.length) {
    die(`Slope segment index ${index} out of range [0, ${dataSegs.length - 1}]`);
  }

  const removed = dataSegs.splice(index, 1)[0];
  out(`  Deleted slope segment ${index}: type=${removed.type} length=${removed.length}`);
  track.slope_rle_segments = [...dataSegs, termSeg];
}

// ---------------------------------------------------------------------------
// Sign record helpers
// ---------------------------------------------------------------------------
function cmdSetSign(track, index, distance, count, signId) {
  const signs = track.sign_data || [];
  if (index < 0 || index >= signs.length) {
    die(`Sign index ${index} out of range [0, ${signs.length - 1}]`);
  }

  const rec = Object.assign({}, signs[index]);
  if (distance !== null && distance !== undefined) {
    if (distance < 0 || distance >= track.track_length) {
      die(`distance ${distance} out of range [0, ${track.track_length - 1}]`);
    }
    rec.distance = distance;
    out(`  Sign ${index}: distance -> ${distance}`);
  }
  if (count !== null && count !== undefined) {
    if (count <= 0) die(`count must be positive`);
    rec.count = count;
    out(`  Sign ${index}: count -> ${count}`);
  }
  if (signId !== null && signId !== undefined) {
    if (signId < 0 || signId > 255) die(`sign_id must be 0-255`);
    rec.sign_id = signId;
    out(`  Sign ${index}: sign_id -> ${signId}`);
  }

  signs[index] = rec;
  track.sign_data = signs;
}

function cmdAddSign(track, after, distance, count, signId) {
  if (distance < 0 || distance >= track.track_length) {
    die(`distance ${distance} out of range [0, ${track.track_length - 1}]`);
  }
  if (count <= 0) die(`count must be positive`);
  if (signId < 0 || signId > 255) die(`sign_id must be 0-255`);

  const signs = [...(track.sign_data || [])];
  const rec = { distance, count, sign_id: signId };

  if (after === null || after === undefined) {
    signs.push(rec);
    out(`  Added sign record at end (index ${signs.length - 1}): dist=${distance} count=${count} id=${signId}`);
  } else {
    if (after < 0 || after >= signs.length) die(`--after ${after} out of range`);
    signs.splice(after + 1, 0, rec);
    out(`  Inserted sign record at index ${after + 1}: dist=${distance} count=${count} id=${signId}`);
  }
  track.sign_data = signs;
}

function cmdDelSign(track, index) {
  const signs = [...(track.sign_data || [])];
  if (index < 0 || index >= signs.length) {
    die(`Sign index ${index} out of range [0, ${signs.length - 1}]`);
  }
  const removed = signs.splice(index, 1)[0];
  out(`  Deleted sign ${index}: dist=${removed.distance} id=${removed.sign_id}`);
  track.sign_data = signs;
}

// ---------------------------------------------------------------------------
// Validate command
// ---------------------------------------------------------------------------
function cmdValidate(tracksData, trackSpec, verbose) {
  const tracks = tracksData.tracks;
  const targetList = trackSpec ? [resolveTrack(tracks, trackSpec)] : tracks;
  const errors = validateTracks(targetList);

  if (errors.length === 0) {
    if (verbose) out(`  All ${targetList.length} track(s) VALID.`);
    return true;
  }

  for (const e of errors) {
    out(`  FAIL [${e.track_name}] ${e.field}: ${e.message}`);
  }
  out(`\n  ${errors.length} validation error(s) found.`);
  return false;
}

// ---------------------------------------------------------------------------
// Inject command
// ---------------------------------------------------------------------------
function cmdInject(tracksData, trackSpec, dataDir, dryRun, noValidate, verbose) {
  dataDir = dataDir || DATA_TRACKS;
  const tracks = tracksData.tracks;
  const targetList = trackSpec ? [resolveTrack(tracks, trackSpec)] : tracks;

  if (!noValidate) {
    const errors = validateTracks(targetList);
    if (errors.length > 0) {
      out('Validation FAILED — inject aborted:');
      for (const e of errors) out(`  [${e.track_name}] ${e.field}: ${e.message}`);
      return false;
    }
  }

  let anyChanged = false;
  for (const t of targetList) {
    const report = injectTrack(t, dataDir, dryRun, verbose);
    for (const [fname, { oldSize, newSize, changed }] of Object.entries(report)) {
      if (changed) {
        const tag = dryRun ? 'DRY-RUN' : 'WROTE';
        out(`  ${tag}: ${t.slug}/${fname}  ${oldSize} -> ${newSize} bytes`);
        anyChanged = true;
      }
    }
  }

  if (!anyChanged) {
    out('  No binary files changed (data already up to date).');
  } else if (!dryRun) {
    out(`\n  Injected ${targetList.length} track(s) to ${dataDir}`);
    out('  Run: cmd /c verify.bat   (to verify unmodified ROM is still bit-perfect)');
  } else {
    out('\n  Dry-run complete — no files written.');
  }
  return true;
}

// ---------------------------------------------------------------------------
// Argument parsing (manual — no external libraries)
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const args = { command: null, positional: [], opts: {} };
  let i = 0;
  const peek = () => argv[i];
  const take = () => argv[i++];

  // First positional is the command
  if (i < argv.length && !argv[i].startsWith('--')) {
    args.command = take();
  }

  while (i < argv.length) {
    const arg = peek();
    if (!arg.startsWith('--')) {
      args.positional.push(take());
      continue;
    }
    // --flag or --opt VALUE
    const key = arg.slice(2); // strip '--'
    if (arg === '--dry-run' || arg === '--no-validate' || arg === '--verbose' || arg === '-v') {
      args.opts[key.replace('-', '_').replace('-', '_')] = true;
      i++;
      continue;
    }
    // --section, --type, --length, --sharpness, --bg-disp, --bg-vert-disp,
    // --after, --distance, --count, --sign-id, --tracks-json, --data-dir, etc.
    i++;
    if (i < argv.length && !argv[i].startsWith('--')) {
      args.opts[key] = take();
    } else {
      args.opts[key] = true;
    }
  }
  return args;
}

function getOpt(opts, key, defaultVal) {
  if (Object.prototype.hasOwnProperty.call(opts, key)) return opts[key];
  return defaultVal;
}

function getOptInt(opts, key, defaultVal) {
  const v = getOpt(opts, key, null);
  if (v === null || v === undefined) return defaultVal;
  const n = parseInt(v, 10);
  if (isNaN(n)) die(`--${key} requires an integer, got ${JSON.stringify(v)}`);
  return n;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  const argv    = process.argv.slice(2);
  const parsed  = parseArgs(argv);
  const cmd     = parsed.command;
  const pos     = parsed.positional;
  const opts    = parsed.opts;

  const tracksJsonPath = getOpt(opts, 'tracks-json', null) || TRACKS_JSON;
  const dataDirArg     = getOpt(opts, 'data-dir', null) || DATA_TRACKS;
  const verbose        = !!(opts['verbose'] || opts['v']);

  if (!cmd) {
    out('Usage: node tools/editor/track_editor.js <command> [args]');
    out('Commands: list, show, set-field, set-curve, add-curve, del-curve,');
    out('          set-slope, add-slope, del-slope, set-sign, add-sign, del-sign,');
    out('          validate, inject');
    process.exit(0);
  }

  const tracksData = loadTracksJson(tracksJsonPath);
  const tracks     = tracksData.tracks;

  // -----------------------------------------------------------------------
  if (cmd === 'list') {
    cmdList(tracks);
    return;
  }

  // -----------------------------------------------------------------------
  if (cmd === 'show') {
    if (!pos[0]) die('show requires TRACK argument');
    const track = resolveTrack(tracks, pos[0]);
    const section = getOpt(opts, 'section', 'all');
    cmdShow(track, section);
    return;
  }

  // -----------------------------------------------------------------------
  if (cmd === 'validate') {
    const ok = cmdValidate(tracksData, pos[0] || null, true);
    process.exit(ok ? 0 : 1);
  }

  // -----------------------------------------------------------------------
  if (cmd === 'inject') {
    const trackSpec   = pos[0] || null;
    const dryRun      = !!(opts['dry-run'] || opts['dry_run']);
    const noValidate  = !!(opts['no-validate'] || opts['no_validate']);
    const ok = cmdInject(tracksData, trackSpec, dataDirArg, dryRun, noValidate, verbose);
    process.exit(ok ? 0 : 1);
  }

  // -----------------------------------------------------------------------
  // Mutation commands — all require TRACK as pos[0]
  const MUTATION_CMDS = new Set([
    'set-field', 'set-curve', 'add-curve', 'del-curve',
    'set-slope', 'add-slope', 'del-slope',
    'set-sign',  'add-sign',  'del-sign',
  ]);

  if (!MUTATION_CMDS.has(cmd)) die(`Unknown command: ${cmd}`);

  if (!pos[0]) die(`${cmd} requires TRACK argument`);
  const track = resolveTrack(tracks, pos[0]);
  out(`Editing track [${track.index}] ${track.name}`);

  // -----------------------------------------------------------------------
  if (cmd === 'set-field') {
    if (!pos[1]) die('set-field requires FIELD argument');
    if (!pos[2]) die('set-field requires VALUE argument');
    cmdSetField(track, pos[1], pos[2]);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'set-curve') {
    const index    = parseInt(pos[1], 10);
    if (isNaN(index)) die('set-curve requires INDEX argument (integer)');
    const segType  = getOpt(opts, 'type', null);
    const length   = getOptInt(opts, 'length', null);
    const sharpness = getOptInt(opts, 'sharpness', null);
    const bgDisp   = getOptInt(opts, 'bg-disp', null);
    cmdSetCurve(track, index, segType, length, sharpness, bgDisp);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'add-curve') {
    const segType = getOpt(opts, 'type', null);
    if (!segType) die('add-curve requires --type straight|left|right');
    const length = getOptInt(opts, 'length', null);
    if (length === null) die('add-curve requires --length N');
    const after    = getOptInt(opts, 'after', null);
    const sharpness = getOptInt(opts, 'sharpness', null);
    const bgDisp   = getOptInt(opts, 'bg-disp', null);
    cmdAddCurve(track, after, segType, length, sharpness, bgDisp);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'del-curve') {
    const index = parseInt(pos[1], 10);
    if (isNaN(index)) die('del-curve requires INDEX argument (integer)');
    cmdDelCurve(track, index);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'set-slope') {
    const index    = parseInt(pos[1], 10);
    if (isNaN(index)) die('set-slope requires INDEX argument (integer)');
    const segType  = getOpt(opts, 'type', null);
    const length   = getOptInt(opts, 'length', null);
    const sharpness = getOptInt(opts, 'sharpness', null);
    const bgVertDisp = getOptInt(opts, 'bg-vert-disp', null);
    cmdSetSlope(track, index, segType, length, sharpness, bgVertDisp);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'add-slope') {
    const segType = getOpt(opts, 'type', null);
    if (!segType) die('add-slope requires --type flat|down|up');
    const length = getOptInt(opts, 'length', null);
    if (length === null) die('add-slope requires --length N');
    const after    = getOptInt(opts, 'after', null);
    const sharpness = getOptInt(opts, 'sharpness', null);
    const bgVertDisp = getOptInt(opts, 'bg-vert-disp', null);
    cmdAddSlope(track, after, segType, length, sharpness, bgVertDisp);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'del-slope') {
    const index = parseInt(pos[1], 10);
    if (isNaN(index)) die('del-slope requires INDEX argument (integer)');
    cmdDelSlope(track, index);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'set-sign') {
    const index    = parseInt(pos[1], 10);
    if (isNaN(index)) die('set-sign requires INDEX argument (integer)');
    const distance = getOptInt(opts, 'distance', null);
    const count    = getOptInt(opts, 'count', null);
    const signId   = getOptInt(opts, 'sign-id', null);
    cmdSetSign(track, index, distance, count, signId);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'add-sign') {
    const distance = getOptInt(opts, 'distance', null);
    if (distance === null) die('add-sign requires --distance N');
    const count = getOptInt(opts, 'count', null);
    if (count === null) die('add-sign requires --count N');
    const signId = getOptInt(opts, 'sign-id', null);
    if (signId === null) die('add-sign requires --sign-id N');
    const after = getOptInt(opts, 'after', null);
    cmdAddSign(track, after, distance, count, signId);
  }

  // -----------------------------------------------------------------------
  else if (cmd === 'del-sign') {
    const index = parseInt(pos[1], 10);
    if (isNaN(index)) die('del-sign requires INDEX argument (integer)');
    cmdDelSign(track, index);
  }

  // Validate after mutation
  out('');
  const errors = validateTrack(track);
  if (errors.length > 0) {
    out('WARNING: Track has validation errors after edit:');
    for (const e of errors) out(`  [${e.track_name}] ${e.field}: ${e.message}`);
    out('');
    out('  tracks.json NOT saved. Fix the errors and retry.');
    process.exit(1);
  }

  saveTracksJson(tracksData, tracksJsonPath);
  out(`  Saved: ${tracksJsonPath}`);
  out('');
  out('  To inject to data/tracks/ and rebuild:');
  out(`    node tools/editor/track_editor.js inject ${track.slug}`);
  out('    cmd /c verify.bat');
}

if (require.main === module) {
  main();
}

module.exports = {
  resolveTrack,
  validateTrack,
  validateTracks,
  cmdList,
  cmdShow,
  cmdSetField,
  cmdSetCurve,
  cmdAddCurve,
  cmdDelCurve,
  cmdSetSlope,
  cmdAddSlope,
  cmdDelSlope,
  cmdSetSign,
  cmdAddSign,
  cmdDelSign,
  cmdValidate,
  cmdInject,
  loadTracksJson,
  saveTracksJson,
};
