#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const { loadTracksData } = require('../lib/minimap_analysis');
const { getTracks } = require('../randomizer/track_model');
const { getTrackPreviewTilemapEntryBytes } = require('../lib/course_select_preview_tiles');
const {
	buildPreviewRawMap,
	planRawMapPatchLayout,
	PREVIEW_MAP_JSR_ADDR,
} = require('../patch_all_track_minimap_raw_maps_rom');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const ASM68K_PATH = path.join(REPO_ROOT, 'asm68k.exe');
const VERIFY_CMD = 'powershell';
const VERIFY_ARGS = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '& .\\verify.bat'];
const RANDOMIZE_SEED = 'SMGP-1-01-20260416';
const TRACK_PREVIEW_TILEMAP_ROM_ADDR = 0x00032228;
const TRACK_PREVIEW_TILEMAP_STRIDE = 0x3B;

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed += 1;
	} catch (error) {
		failed += 1;
		console.error(`FAIL: ${name}`);
		console.error(`  ${error.message}`);
	}
}

function runNode(args, cwd = REPO_ROOT) {
	return spawnSync(process.execPath, args, {
		cwd,
		encoding: 'utf8',
		stdio: ['ignore', 'pipe', 'pipe'],
	});
}

function runVerify() {
	return spawnSync(VERIFY_CMD, VERIFY_ARGS, {
		cwd: REPO_ROOT,
		encoding: 'utf8',
		stdio: ['ignore', 'pipe', 'pipe'],
	});
}

function makeTempRomCopy() {
	const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-minimap-runtime-'));
	const romPath = path.join(tmpDir, 'randomized.bin');
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'randomize.js'),
		RANDOMIZE_SEED,
		'--output',
		romPath,
	]);
	if (result.status !== 0) {
		throw new Error(`randomize.js failed:\n${(result.stdout || '') + (result.stderr || '')}`.trim());
	}
	return { tmpDir, romPath };
}

function cleanupTempDir(tmpDir) {
	fs.rmSync(tmpDir, { recursive: true, force: true });
}

console.log('Section: runtime minimap patch flow');

test('raw-map patch layout matches appended preview blocks and hook target in randomized ROM', () => {
	const { tmpDir, romPath } = makeTempRomCopy();
	try {
		const sourceRom = fs.readFileSync(romPath);
		const tracks = getTracks(loadTracksData()).slice().sort((a, b) => a.index - b.index);
		const layout = planRawMapPatchLayout(tracks, sourceRom.length, ASM68K_PATH, {
			sourceRom,
		});
		const patchResult = runNode([
			path.join(REPO_ROOT, 'tools', 'patch_all_track_minimap_raw_maps_rom.js'),
			'--rom',
			romPath,
		]);
		if (patchResult.status !== 0) {
			throw new Error(`patch_all_track_minimap_raw_maps_rom.js failed:\n${(patchResult.stdout || '') + (patchResult.stderr || '')}`.trim());
		}

		const patchedRom = fs.readFileSync(romPath);
		assert.strictEqual(patchedRom.readUInt16BE(PREVIEW_MAP_JSR_ADDR), 0x4EB9, 'preview hook opcode should be JSR absolute long');
		assert.strictEqual(patchedRom.readUInt32BE(PREVIEW_MAP_JSR_ADDR + 2), layout.previewHelperAddr, 'preview hook target should match planned helper address');

		for (const track of tracks) {
			const expected = buildPreviewRawMap(track);
			const actualAddr = layout.previewRawMapPtrs[track.index];
			const actual = patchedRom.subarray(actualAddr, actualAddr + expected.length);
			assert.strictEqual(actual.length, expected.length, `${track.slug} raw map length mismatch`);
			assert.deepStrictEqual(actual, expected, `${track.slug} appended preview raw map bytes diverged from generated raw map`);
		}
	} finally {
		cleanupTempDir(tmpDir);
	}
});

test('canonical root tree still passes verify.bat', () => {
	const result = runVerify();
	if (result.status !== 0) {
		throw new Error(`verify.bat failed:\n${(result.stdout || '') + (result.stderr || '')}`.trim());
	}
});

test('workspace-safe randomized ROM keeps stock course-select overlay entries intact', () => {
	const { tmpDir, romPath } = makeTempRomCopy();
	try {
		const rom = fs.readFileSync(romPath);
		const tracks = getTracks(loadTracksData()).slice().sort((a, b) => a.index - b.index);
		for (const track of tracks) {
			if (track.index < 0 || track.index >= 16) continue;
			const start = TRACK_PREVIEW_TILEMAP_ROM_ADDR + (track.index * TRACK_PREVIEW_TILEMAP_STRIDE);
			const entry = rom.subarray(start, start + TRACK_PREVIEW_TILEMAP_STRIDE);
			assert.strictEqual(entry.length, TRACK_PREVIEW_TILEMAP_STRIDE, `${track.slug} overlay entry length mismatch`);
			assert.deepStrictEqual(Array.from(entry), Array.from(getTrackPreviewTilemapEntryBytes(track.index)), `${track.slug} overlay entry diverged from stock gameplay data`);
			assert.ok(entry.includes(0xFB), `${track.slug} expected stock overlay stream to retain base-change commands`);
		}
	} finally {
		cleanupTempDir(tmpDir);
	}
});

console.log(`Passed: ${passed}`);
if (failed > 0) {
	console.log(`Failed: ${failed}`);
	process.exit(1);
}
