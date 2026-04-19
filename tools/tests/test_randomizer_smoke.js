#!/usr/bin/env node
// tools/tests/test_randomizer_smoke.js
//
// TEST-009: End-to-end randomizer smoke test.
//
// Section A: Generate + validate all 19 tracks using a representative seed.
//            38 per-track tests (2 per track: no validation errors, correct
//            minimap pair count) + 1 aggregate test = 39 tests.
//
// Section B: Inject randomized binaries into an isolated temp data/tracks/ copy.
//            20 tests: 19 (one per track: all 6 binary files written) + 1
//            (no original data/tracks/ files were modified).
//
// Section C: Build a randomized ROM via the isolated hack workspace flow
//            (only runs without --no-build).
//            12 tests: workspace created, hack builder ran, exit code 0,
//            output ROM written, workspace ROM present, expected ROM growth,
//            ROM end header matches actual size, log written, root-tree safety,
//            and workspace determinism.
//
// Usage:
//   node tools/tests/test_randomizer_smoke.js             # fast mode
//   node tools/tests/test_randomizer_smoke.js --with-build # include Section C
//   node tools/tests/test_randomizer_smoke.js --no-build   # skip Section C explicitly

'use strict';

const assert       = require('assert');
const crypto       = require('crypto');
const fs           = require('fs');
const os           = require('os');
const path         = require('path');
const { spawnSync } = require('child_process');

const { REPO_ROOT }      = require('../lib/rom.js');
const trackRandomizer    = require('../randomizer/track_randomizer.js');
const { getTrackMinimapPairs, getTracks, requireTracksDataShape } = require('../randomizer/track_model.js');
const { validateTrack, validateTracks } = require('../randomizer/track_validator.js');
const { injectTrack }    = require('../inject_track_data.js');
const { readTrackEntryAddresses } = require('../generated_minimap_runtime.js');
const { buildTrackAssetBytes } = require('../patch_all_track_minimap_assets_rom.js');
const { buildPreviewRawMap } = require('../patch_all_track_minimap_raw_maps_rom.js');
const { encodeMinimapPos } = require('../inject_track_data.js');
const { buildGeneratedMinimapPosPairs } = require('../lib/generated_minimap_pos.js');
const { deepCopy, loadTracksJson } = require('./randomizer_test_utils.js');

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

function sha256File(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function snapshotExistingFiles(filePaths) {
  return filePaths.map(filePath => ({
    filePath,
    exists: fs.existsSync(filePath),
    hash: fs.existsSync(filePath) ? sha256File(filePath) : null,
  }));
}

function assertBufferContains(haystack, needle, label) {
	const offset = haystack.indexOf(needle);
	assert.ok(offset >= 0, `missing ${label}`);
	return offset;
}

// ---------------------------------------------------------------------------
// Parse build-mode flags
// ---------------------------------------------------------------------------
const WITH_BUILD = process.argv.includes('--with-build');
const NO_BUILD = process.argv.includes('--no-build') || !WITH_BUILD;

// ---------------------------------------------------------------------------
// Section A: Generate + validate all 19 tracks using a representative seed
// ---------------------------------------------------------------------------
console.log('Section A: generate + validate all 19 tracks with representative seed');

const FIXED_SEED_STR = 'SMGP-1-01-42';
const WORKSPACE_SEED_STR = 'SMGP-1-01-12345';
const [, , FIXED_SEED_INT] = trackRandomizer.parseSeed(FIXED_SEED_STR);

// Load real tracks.json and deep-clone so we don't mutate the on-disk version
const realTracksData = loadTracksJson();
const tracksData = requireTracksDataShape(deepCopy(realTracksData));

// Randomize all 19 tracks in-place on the clone
trackRandomizer.randomizeTracks(tracksData, FIXED_SEED_INT, null, false);

const randomizedTracks = getTracks(tracksData);
const allErrors = validateTracks(randomizedTracks);

// 2 tests per track (19 tracks = 38 tests) + 1 aggregate
for (const track of randomizedTracks) {
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
    const actual   = getTrackMinimapPairs(track).length;
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
for (const track of randomizedTracks) {
  try {
    injectTrack(track, tmpTracksDir, false, false);
  } catch (err) {
    injectErrors.push([track.slug, err]);
  }
}

// 19 per-track tests (one per track: all 6 bin files exist after inject)
for (const track of randomizedTracks) {
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
console.log(`Section C: assemble ROM in isolated workspace (${NO_BUILD ? 'SKIPPED - fast mode/--no-build' : 'running'})`);

if (!NO_BUILD) {
  const tmpRootDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-smoke-ws-'));
  const tmpWsDir = path.join(tmpRootDir, 'workspace');
  const tmpRomPath = path.join(tmpRootDir, 'randomized.bin');
  const tmpRootDir2 = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-smoke-ws-'));
  const tmpWsDir2 = path.join(tmpRootDir2, 'workspace');
  const tmpRomPath2 = path.join(tmpRootDir2, 'randomized.bin');
  const hackWorkdirScript = path.join(REPO_ROOT, 'tools', 'hack_workdir.js');
  const rootSentinelPaths = [
    path.join(REPO_ROOT, 'tools', 'data', 'tracks.json'),
    path.join(REPO_ROOT, 'src', 'track_config_data.asm'),
    path.join(REPO_ROOT, 'src', 'road_and_track_data.asm'),
    path.join(REPO_ROOT, 'data', 'tracks', 'san_marino', 'curve_data.bin'),
    path.join(REPO_ROOT, 'data', 'tracks', 'monaco_arcade', 'minimap_pos.bin'),
  ];
  const rootSentinelSnapshot = snapshotExistingFiles(rootSentinelPaths);

  test('Section C: isolated workspace was created', () => {
    assert.ok(fs.existsSync(tmpRootDir), 'temp root dir does not exist');
  });

  const buildResult = spawnSync('node', [hackWorkdirScript, WORKSPACE_SEED_STR, '--workspace', tmpWsDir, '--output', tmpRomPath, '--keep'], {
    cwd:      REPO_ROOT,
    encoding: 'utf8',
    timeout:  120000,
  });

  const buildOutput = (buildResult.stdout || '') + (buildResult.stderr || '');
  const buildResult2 = spawnSync('node', [hackWorkdirScript, WORKSPACE_SEED_STR, '--workspace', tmpWsDir2, '--output', tmpRomPath2, '--keep'], {
    cwd:      REPO_ROOT,
    encoding: 'utf8',
    timeout:  120000,
  });
  const buildOutput2 = (buildResult2.stdout || '') + (buildResult2.stderr || '');

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

  test('Section C: out.bin size is at least the canonical ROM size', () => {
    const romPath = tmpRomPath;
    assert.ok(fs.existsSync(romPath), 'out.bin not found in workspace after build');
    const actualSize = fs.statSync(romPath).size;
    assert.ok(actualSize >= EXPECTED_ROM_SIZE,
      `out.bin size=${actualSize}, expected at least ${EXPECTED_ROM_SIZE}`);
  });

  test('Section C: ROMEndLoc matches actual workspace ROM size', () => {
    const romPath = tmpRomPath;
    const rom = fs.readFileSync(romPath);
    const romEnd = rom.readUInt32BE(0x1A4);
    assert.strictEqual(romEnd, rom.length - 1,
      `ROMEndLoc=0x${romEnd.toString(16)}, expected 0x${(rom.length - 1).toString(16)}`);
  });

  test('Section C: randomizer log was written in workspace', () => {
    assert.ok(fs.existsSync(path.join(tmpWsDir, 'randomizer.log')),
      'randomizer.log not found in workspace after build');
  });

  test('Section C: workspace build reports timing breakdown', () => {
    assert.ok(buildOutput.includes('Timing:'), `expected timing line in output:\n${buildOutput}`);
  });

	test('Section C: workspace ROM contains generated minimap tile payload for a randomized track', () => {
		const wsRomPath = path.join(tmpWsDir, 'out.bin');
		const wsTracksPath = path.join(tmpWsDir, 'tools', 'data', 'tracks.json');
		const rom = fs.readFileSync(wsRomPath);
		const workspaceTracks = requireTracksDataShape(JSON.parse(fs.readFileSync(wsTracksPath, 'utf8')));
		const track = getTracks(workspaceTracks).find(entry => entry.slug === 'san_marino');
		assert.ok(track, 'missing san_marino in workspace tracks.json');
		const assets = buildTrackAssetBytes(track);
		const { minimapTilesAddr } = readTrackEntryAddresses(rom, track.index);
		assert.ok(minimapTilesAddr >= EXPECTED_ROM_SIZE, `expected appended minimap tiles pointer, got 0x${minimapTilesAddr.toString(16)}`);
		assert.strictEqual(rom.subarray(minimapTilesAddr, minimapTilesAddr + assets.tileBytes.length).compare(assets.tileBytes), 0, 'workspace ROM minimap tile payload mismatch');
	});

	test('Section C: workspace ROM contains generated raw preview map payload for a randomized track', () => {
		const wsRomPath = path.join(tmpWsDir, 'out.bin');
		const wsTracksPath = path.join(tmpWsDir, 'tools', 'data', 'tracks.json');
		const rom = fs.readFileSync(wsRomPath);
		const workspaceTracks = requireTracksDataShape(JSON.parse(fs.readFileSync(wsTracksPath, 'utf8')));
		const track = getTracks(workspaceTracks).find(entry => entry.slug === 'san_marino');
		assert.ok(track, 'missing san_marino in workspace tracks.json');
		const rawPreviewMap = buildPreviewRawMap(track);
		const offset = assertBufferContains(rom, rawPreviewMap, 'generated raw preview map');
		assert.ok(offset >= EXPECTED_ROM_SIZE, `expected appended raw preview map, got 0x${offset.toString(16)}`);
	});

	test('Section C: workspace ROM contains generated minimap_pos payload for a randomized track', () => {
		const wsRomPath = path.join(tmpWsDir, 'out.bin');
		const wsTracksPath = path.join(tmpWsDir, 'tools', 'data', 'tracks.json');
		const rom = fs.readFileSync(wsRomPath);
		const workspaceTracks = requireTracksDataShape(JSON.parse(fs.readFileSync(wsTracksPath, 'utf8')));
		const track = getTracks(workspaceTracks).find(entry => entry.slug === 'san_marino');
		assert.ok(track, 'missing san_marino in workspace tracks.json');
		const expected = Buffer.from(encodeMinimapPos(buildGeneratedMinimapPosPairs(track), Array.isArray(track.minimap_pos_trailing) ? track.minimap_pos_trailing : []));
		const entryAddr = 0x0000F872 + (track.index * 0x48);
		const minimapPosAddr = rom.readUInt32BE(entryAddr + 0x2C);
		assert.strictEqual(rom.subarray(minimapPosAddr, minimapPosAddr + expected.length).compare(expected), 0, 'workspace ROM minimap_pos payload mismatch');
	});

	test('Section C: workspace ROM records minimap patch phase in log output', () => {
		assert.ok(buildOutput.includes('Patching generated minimap data into workspace ROM ...'), `expected minimap patch phase in output:\n${buildOutput}`);
		assert.ok(buildOutput.includes('Expanded workspace ROM size:'), `expected expanded ROM size report in output:\n${buildOutput}`);
	});

  test('Section C: root-tree sentinel files remain unchanged', () => {
    for (const entry of rootSentinelSnapshot) {
      assert.strictEqual(fs.existsSync(entry.filePath), entry.exists, `${entry.filePath} existence changed`);
      if (entry.exists) {
        assert.strictEqual(sha256File(entry.filePath), entry.hash, `${entry.filePath} hash changed`);
      }
    }
  });

  test('Section C: second workspace build exit code is 0', () => {
    assert.strictEqual(buildResult2.status, 0,
      `exit code ${buildResult2.status}\noutput:\n${buildOutput2.slice(0, 500)}`);
  });

  test('Section C: workspace builds produce identical ROM hashes', () => {
    assert.ok(fs.existsSync(tmpRomPath), `missing first ROM: ${tmpRomPath}`);
    assert.ok(fs.existsSync(tmpRomPath2), `missing second ROM: ${tmpRomPath2}`);
    assert.strictEqual(sha256File(tmpRomPath), sha256File(tmpRomPath2));
  });

  test('Section C: workspace builds produce identical randomized track JSON', () => {
    const first = path.join(tmpWsDir, 'tools', 'data', 'tracks.json');
    const second = path.join(tmpWsDir2, 'tools', 'data', 'tracks.json');
    assert.ok(fs.existsSync(first), `missing first randomized tracks.json: ${first}`);
    assert.ok(fs.existsSync(second), `missing second randomized tracks.json: ${second}`);
    assert.strictEqual(sha256File(first), sha256File(second));
  });

  // Cleanup workspace
  fs.rmSync(tmpRootDir, { recursive: true, force: true });
  fs.rmSync(tmpRootDir2, { recursive: true, force: true });
} else {
  // Skip tests but keep counts honest — just record them as "not run"
  console.log('  (Section C skipped - fast mode/--no-build; build tests not run)');
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
	console.log('(Section C skipped: build tests not included in total; use --with-build to run them)');
}
if (failed > 0) process.exit(1);
