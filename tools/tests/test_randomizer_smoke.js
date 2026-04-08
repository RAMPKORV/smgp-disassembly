#!/usr/bin/env node
// tools/tests/test_randomizer_smoke.js
//
// TEST-009: End-to-end randomizer smoke test.
//
// Section A: Generate + validate all 19 tracks using a fixed seed.
//            38 per-track tests (2 per track: no validation errors, correct
//            minimap pair count) + 1 aggregate test = 39 tests.
//
// Section B: Inject randomized binaries into an isolated temp data/tracks/ copy.
//            20 tests: 19 (one per track: all 6 binary files written) + 1
//            (no original data/tracks/ files were modified).
//
// Section C: Build a randomized ROM via the isolated hack workspace flow
//            (only runs without --no-build).
//            8 tests: workspace created, hack builder ran, exit code 0,
//            output ROM written, workspace ROM present, correct ROM size,
//            ROM end header padded correctly, log written.
//
// Usage:
//   node tools/tests/test_randomizer_smoke.js            # all sections
//   node tools/tests/test_randomizer_smoke.js --no-build # skip Section C

'use strict';

const assert       = require('assert');
const fs           = require('fs');
const os           = require('os');
const path         = require('path');
const { spawnSync } = require('child_process');

const { readJson }       = require('../lib/json.js');
const { REPO_ROOT }      = require('../lib/rom.js');
const trackRandomizer    = require('../randomizer/track_randomizer.js');
const { validateTrack, validateTracks } = require('../randomizer/track_validator.js');
const { injectTrack }    = require('../inject_track_data.js');

const EXPECTED_ROM_SIZE = 524288;

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------
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
// Parse --no-build flag
// ---------------------------------------------------------------------------
const NO_BUILD = process.argv.includes('--no-build');

// ---------------------------------------------------------------------------
// Section A: Generate + validate all 19 tracks using a fixed seed
// ---------------------------------------------------------------------------
console.log('Section A: generate + validate all 19 tracks with fixed seed');

const FIXED_SEED_STR = 'SMGP-1-01-42';
const WORKSPACE_SEED_STR = 'SMGP-1-01-12345';
const [, , FIXED_SEED_INT] = trackRandomizer.parseSeed(FIXED_SEED_STR);

// Load real tracks.json and deep-clone so we don't mutate the on-disk version
const realTracksData = readJson(path.join(REPO_ROOT, 'tools', 'data', 'tracks.json'));
// Deep clone via JSON round-trip so we operate on a fresh copy
const tracksData = JSON.parse(JSON.stringify(realTracksData));

// Randomize all 19 tracks in-place on the clone
trackRandomizer.randomizeTracks(tracksData, FIXED_SEED_INT, null, false);

const allErrors = validateTracks(tracksData.tracks);

// 2 tests per track (19 tracks = 38 tests) + 1 aggregate
for (const track of tracksData.tracks) {
  const trackName = track.name || track.slug || '?';
  const trackErrors = validateTrack(track);

  test(`track "${trackName}": no validation errors`, () => {
    if (trackErrors.length > 0) {
      const msgs = trackErrors.map(e => `${e.field}: ${e.message}`).join('; ');
      throw new Error(`${trackErrors.length} error(s): ${msgs}`);
    }
  });

  test(`track "${trackName}": minimap pair count == track_length>>6`, () => {
    const expected = track.track_length >> 6;
    const actual   = Array.isArray(track.minimap_pos) ? track.minimap_pos.length : -1;
    assert.strictEqual(actual, expected,
      `minimap_pos.length=${actual}, expected track_length(${track.track_length})>>6=${expected}`);
  });
}

test('all 19 tracks pass validation in aggregate', () => {
  if (allErrors.length > 0) {
    const msgs = allErrors.slice(0, 5).map(e => e.toString()).join('; ');
    throw new Error(`${allErrors.length} aggregate error(s): ${msgs}`);
  }
});

// ---------------------------------------------------------------------------
// Section B: inject randomized binaries into an isolated temp data/tracks/ copy
// ---------------------------------------------------------------------------
console.log('Section B: inject randomized binaries into isolated temp data/tracks/');

const tmpDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-smoke-data-'));
const tmpTracksDir = path.join(tmpDataDir, 'tracks');

// Copy the original data/tracks/ tree into the temp dir so injectTrack has
// a stable base to overwrite (without touching the real data/tracks/).
const realTracksDir = path.join(REPO_ROOT, 'data', 'tracks');

function copyDirRecursive(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, dstPath);
    } else {
      fs.copyFileSync(srcPath, dstPath);
    }
  }
}

copyDirRecursive(realTracksDir, tmpTracksDir);

// Track which slugs are championship tracks (not prelims, which may lack all 6 bin files)
const BINARY_FILES = [
  'curve_data.bin', 'slope_data.bin', 'phys_slope_data.bin',
  'sign_data.bin', 'sign_tileset.bin', 'minimap_pos.bin',
];

// Record original mtimes for a few original tracks to verify they were NOT touched
const originalMtimes = {};
for (const entry of fs.readdirSync(realTracksDir, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const slug = entry.name;
  const trackDir = path.join(realTracksDir, slug);
  originalMtimes[slug] = {};
  for (const fname of BINARY_FILES) {
    const fp = path.join(trackDir, fname);
    if (fs.existsSync(fp)) {
      originalMtimes[slug][fname] = fs.statSync(fp).mtimeMs;
    }
  }
}

// Inject all 19 randomized tracks into the isolated copy
const injectErrors = [];
for (const track of tracksData.tracks) {
  try {
    injectTrack(track, tmpTracksDir, false, false);
  } catch (err) {
    injectErrors.push([track.slug, err]);
  }
}

// 19 per-track tests (one per track: all 6 bin files exist after inject)
for (const track of tracksData.tracks) {
  const slug = track.slug;
  const trackDir = path.join(tmpTracksDir, slug);

  test(`inject track "${track.name || slug}": all 6 binary files written`, () => {
    assert.ok(injectErrors.every(([s]) => s !== slug),
      `injectTrack threw for "${slug}"`);
    for (const fname of BINARY_FILES) {
      const fp = path.join(trackDir, fname);
      assert.ok(fs.existsSync(fp), `${fname} not found in ${trackDir}`);
      assert.ok(fs.statSync(fp).size > 0, `${fname} is empty in ${trackDir}`);
    }
  });
}

// 1 test: original data/tracks/ files were NOT modified
test('original data/tracks/ files were not modified by inject', () => {
  for (const [slug, files] of Object.entries(originalMtimes)) {
    for (const [fname, origMtime] of Object.entries(files)) {
      const fp = path.join(realTracksDir, slug, fname);
      if (fs.existsSync(fp)) {
        const nowMtime = fs.statSync(fp).mtimeMs;
        assert.strictEqual(nowMtime, origMtime,
          `${slug}/${fname} was modified (mtime changed from ${origMtime} to ${nowMtime})`);
      }
    }
  }
});

// ---------------------------------------------------------------------------
// Section C: assemble ROM in an isolated temp workspace
// ---------------------------------------------------------------------------
console.log(`Section C: assemble ROM in isolated workspace (${NO_BUILD ? 'SKIPPED — --no-build' : 'running'})`);

if (!NO_BUILD) {
  const tmpRootDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-smoke-ws-'));
  const tmpWsDir = path.join(tmpRootDir, 'workspace');
  const tmpRomPath = path.join(tmpRootDir, 'randomized.bin');
  const hackWorkdirScript = path.join(REPO_ROOT, 'tools', 'hack_workdir.js');

  test('Section C: isolated workspace was created', () => {
    assert.ok(fs.existsSync(tmpRootDir), 'temp root dir does not exist');
  });

  const buildResult = spawnSync('node', [hackWorkdirScript, WORKSPACE_SEED_STR, '--workspace', tmpWsDir, '--output', tmpRomPath, '--keep'], {
    cwd:      REPO_ROOT,
    encoding: 'utf8',
    timeout:  120000,
  });

  const buildOutput = (buildResult.stdout || '') + (buildResult.stderr || '');

  test('Section C: hack workspace builder ran (no spawnSync error)', () => {
    assert.ok(buildResult.error === undefined,
      `spawnSync error: ${buildResult.error}`);
  });

  test('Section C: hack workspace builder exit code is 0', () => {
    assert.strictEqual(buildResult.status, 0,
      `exit code ${buildResult.status}\noutput:\n${buildOutput.slice(0, 500)}`);
  });

  test('Section C: output ROM was written by hack workspace flow', () => {
    assert.ok(fs.existsSync(tmpRomPath),
      `output ROM not found: ${tmpRomPath}`);
  });

  test('Section C: out.bin is present in workspace', () => {
    assert.ok(fs.existsSync(path.join(tmpWsDir, 'out.bin')),
      'out.bin not found in workspace after build');
  });

  test('Section C: out.bin size is exactly 524288 bytes', () => {
    const romPath = tmpRomPath;
    assert.ok(fs.existsSync(romPath), 'out.bin not found in workspace after build');
    const actualSize = fs.statSync(romPath).size;
    assert.strictEqual(actualSize, EXPECTED_ROM_SIZE,
      `out.bin size=${actualSize}, expected ${EXPECTED_ROM_SIZE}`);
  });

  test('Section C: ROMEndLoc matches padded ROM size', () => {
    const romPath = tmpRomPath;
    const rom = fs.readFileSync(romPath);
    const romEnd = rom.readUInt32BE(0x1A4);
    assert.strictEqual(romEnd, EXPECTED_ROM_SIZE - 1,
      `ROMEndLoc=0x${romEnd.toString(16)}, expected 0x${(EXPECTED_ROM_SIZE - 1).toString(16)}`);
  });

  test('Section C: randomizer log was written in workspace', () => {
    assert.ok(fs.existsSync(path.join(tmpWsDir, 'randomizer.log')),
      'randomizer.log not found in workspace after build');
  });

  // Cleanup workspace
  fs.rmSync(tmpRootDir, { recursive: true, force: true });
} else {
  // Skip tests but keep counts honest — just record them as "not run"
  console.log('  (Section C skipped — 8 build tests not run)');
}

// ---------------------------------------------------------------------------
// Cleanup temp dirs
// ---------------------------------------------------------------------------
fs.rmSync(tmpDataDir, { recursive: true, force: true });

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (NO_BUILD) {
  console.log('(Section C skipped: 8 build tests not included in total)');
}
if (failed > 0) process.exit(1);
