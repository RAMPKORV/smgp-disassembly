#!/usr/bin/env node
// tools/hack_workdir.js
//
// RAND-011: Hack workspace system for safe randomized builds.
//
// Creates an isolated copy of the project in build/workspaces/<seed>/,
// runs the randomizer there, builds the ROM, and returns the randomized
// binary without modifying the original source tree.
//
// Usage:
//   node tools/hack_workdir.js SMGP-1-01-12345
//   node tools/hack_workdir.js SMGP-1-01-12345 --output my_rom.bin
//   node tools/hack_workdir.js SMGP-1-01-12345 --keep
//   node tools/hack_workdir.js SMGP-1-01-12345 --dry-run --verbose
//   node tools/hack_workdir.js --list
//
// Workflow:
//   1. Validate seed format (SMGP-<v>-<flags_hex>-<decimal>)
//   2. Create build/workspaces/<seed>/ under the repo root
//   3. Copy minimal build files into the workspace:
//        Top-level ASM files (smgp.asm, macros.asm, constants.asm, ...)
//        src/            (all ASM modules)
//        data/           (all extracted binary assets)
//        tools/          (JS tooling — randomize.js, inject scripts, randomizer/, ...)
//        asm68k.exe
//        build.bat
//   4. Run node tools/randomize.js <seed> inside the workspace
//   5. Build the randomized ROM via build.bat (verification step)
//   6. Copy out.bin to --output (default: build/roms/out_<seed>.bin)
//   7. Write randomizer.log inside the workspace
//   8. Optionally delete the workspace on success (default: keep)
//
// Exit codes:
//   0   success — randomized ROM written to --output
//   1   seed parse error, build failure, or randomizer error

'use strict';

const crypto           = require('crypto');
const fs               = require('fs');
const path             = require('path');
const { execFileSync, spawnSync } = require('child_process');
const { parseArgs, die } = require('./lib/cli');
const { REPO_ROOT, ROM_SIZE }    = require('./lib/rom');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { buildGeneratedTrackBlock } = require('./generate_track_data_asm');

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const WORKSPACES = path.join(REPO_ROOT, 'build', 'workspaces');
const ROM_OUTPUTS = path.join(REPO_ROOT, 'build', 'roms');

// ---------------------------------------------------------------------------
// Seed validation
// ---------------------------------------------------------------------------
const SEED_RE = /^SMGP-(\d+)-([0-9A-Fa-f]+)-(\d+)$/;

function validateSeed(seedStr) {
  const m = SEED_RE.exec(seedStr);
  if (!m) {
    throw new Error(
      `Invalid seed format: ${JSON.stringify(seedStr)}\n` +
      'Expected: SMGP-<version>-<flags_hex>-<decimal>  e.g. SMGP-1-01-12345'
    );
  }
  const version  = parseInt(m[1], 10);
  const flags    = parseInt(m[2], 16);
  const seedInt  = parseInt(m[3], 10);
  return [version, flags, seedInt];
}

// ---------------------------------------------------------------------------
// File copy helpers
// ---------------------------------------------------------------------------

/**
 * Recursively copy a directory, skipping __pycache__ dirs and .pyc files.
 */
function copyDirRecursive(src, dst, verbose) {
  fs.mkdirSync(dst, { recursive: true });
  let count = 0;
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    // Skip Python bytecode artifacts
    if (entry.name === '__pycache__' || entry.name.endsWith('.pyc')) continue;
    if (entry.name === 'workspaces' && path.basename(src) === 'build') continue;
    if (entry.name === 'roms' && path.basename(src) === 'build') continue;
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      count += copyDirRecursive(srcPath, dstPath, verbose);
    } else {
      fs.copyFileSync(srcPath, dstPath);
      if (verbose) console.log(`  copy: ${path.relative(REPO_ROOT, srcPath)}`);
      count++;
    }
  }
  return count;
}

function copySelectedToolFiles(repoRoot, wsDir, verbose) {
	let totalFiles = 0;
	const toolFiles = [
		'randomize.js',
		'patch_rom_checksum.js',
		'patch_preview_minimap_raw_rom.js',
		'patch_generated_minimap_rom.js',
		'patch_generated_minimap_pos_rom.js',
		'workspace_patch_generated_minimap_rom.js',
		'patch_all_track_minimap_assets_rom.js',
		'patch_all_track_minimap_raw_maps_rom.js',
		'inject_track_data.js',
		'inject_team_data.js',
		'inject_championship_data.js',
		'sync_track_config.js',
		'generate_track_data_asm.js',
		'generate_minimap_preview_runtime.js',
		'generated_minimap_runtime.js',
		'minimap_graphics_codec.js',
		'minimap_map_codec.js',
		'minimap_validate.js',
		'write_generated_minimap_pos.js',
		'workspace_apply_generated_minimap.js',
	];
	const toolDirs = [
		'data',
		'lib',
		'randomizer',
	];

	for (const relFile of toolFiles) {
		const srcPath = path.join(repoRoot, 'tools', relFile);
		if (!fs.existsSync(srcPath) || !fs.statSync(srcPath).isFile()) continue;
		fs.mkdirSync(path.join(wsDir, 'tools'), { recursive: true });
		fs.copyFileSync(srcPath, path.join(wsDir, 'tools', relFile));
		if (verbose) console.log(`  copy: tools/${relFile}`);
		totalFiles++;
	}

	for (const relDir of toolDirs) {
		const srcDir = path.join(repoRoot, 'tools', relDir);
		const dstDir = path.join(wsDir, 'tools', relDir);
		if (!fs.existsSync(srcDir) || !fs.statSync(srcDir).isDirectory()) continue;
		const n = copyDirRecursive(srcDir, dstDir, verbose);
		if (!verbose) console.log(`  copy: tools/${relDir}/ (${n} files)`);
		totalFiles += n;
	}

	return totalFiles;
}

function readTrackedFileFromHead(repoRoot, relPath) {
	const gitPath = relPath.split(path.sep).join('/');
	try {
		return execFileSync('git', ['show', `HEAD:${gitPath}`], {
			cwd: repoRoot,
			stdio: ['ignore', 'pipe', 'ignore'],
		});
	} catch (error) {
		return null;
	}
}

function copyFileWithAsmPreference(repoRoot, relPath, dstPath, preferHead, verbose) {
	fs.mkdirSync(path.dirname(dstPath), { recursive: true });

	if (preferHead) {
		const headContent = readTrackedFileFromHead(repoRoot, relPath);
		if (headContent !== null) {
			fs.writeFileSync(dstPath, headContent);
			if (verbose) console.log(`  copy: ${relPath} [HEAD]`);
			return true;
		}
	}

	const srcPath = path.join(repoRoot, relPath);
	fs.copyFileSync(srcPath, dstPath);
	if (verbose) console.log(`  copy: ${relPath}`);
	return false;
}

function copyDirRecursiveWithAsmPreference(repoRoot, relDir, dstDir, preferHead, verbose) {
	const srcDir = path.join(repoRoot, relDir);
	fs.mkdirSync(dstDir, { recursive: true });
	let count = 0;

	for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
		if (entry.name === '__pycache__' || entry.name.endsWith('.pyc')) continue;
		if (entry.name === 'workspaces' && path.basename(srcDir) === 'build') continue;
		if (entry.name === 'roms' && path.basename(srcDir) === 'build') continue;
		const relPath = path.join(relDir, entry.name);
		const dstPath = path.join(dstDir, entry.name);
		if (entry.isDirectory()) {
			count += copyDirRecursiveWithAsmPreference(repoRoot, relPath, dstPath, preferHead, verbose);
		} else {
			copyFileWithAsmPreference(repoRoot, relPath, dstPath, preferHead, verbose);
			count++;
		}
	}

	return count;
}

/**
 * Copy the minimal set of files needed for a standalone build into wsDir.
 * Returns total file count.
 */
function copyBuildFiles(repoRoot, wsDir, verbose, options = {}) {
	const useWorkingTreeAsm = options.useWorkingTreeAsm === true;
	const preferHeadAsm = !useWorkingTreeAsm;
  let totalFiles = 0;

  // 1. Top-level .asm files
  for (const fname of fs.readdirSync(repoRoot)) {
    if (!fname.endsWith('.asm')) continue;
    const src = path.join(repoRoot, fname);
    if (!fs.statSync(src).isFile()) continue;
		copyFileWithAsmPreference(repoRoot, fname, path.join(wsDir, fname), preferHeadAsm, verbose);
    totalFiles++;
  }

  // 2. src/ directory (recursive)
  const srcSrc = path.join(repoRoot, 'src');
  const srcDst = path.join(wsDir, 'src');
  if (fs.existsSync(srcSrc) && fs.statSync(srcSrc).isDirectory()) {
		const n = copyDirRecursiveWithAsmPreference(repoRoot, 'src', srcDst, preferHeadAsm, verbose);
    if (!verbose) console.log(`  copy: src/ (${n} files)`);
    totalFiles += n;
  }

  // 3. data/ directory (recursive)
  const dataSrc = path.join(repoRoot, 'data');
  const dataDst = path.join(wsDir, 'data');
  if (fs.existsSync(dataSrc) && fs.statSync(dataSrc).isDirectory()) {
    const n = copyDirRecursive(dataSrc, dataDst, verbose);
    if (!verbose) console.log(`  copy: data/ (${n} files)`);
    totalFiles += n;
  }

  // 4. Minimal tools/ subset needed for randomizer/build
  totalFiles += copySelectedToolFiles(repoRoot, wsDir, verbose);

  // 5. asm68k.exe
  const asmSrc = path.join(repoRoot, 'asm68k.exe');
  if (fs.existsSync(asmSrc) && fs.statSync(asmSrc).isFile()) {
    fs.copyFileSync(asmSrc, path.join(wsDir, 'asm68k.exe'));
    if (verbose) console.log('  copy: asm68k.exe');
    totalFiles++;
  }

  // 6. build.bat
  const buildSrc = path.join(repoRoot, 'build.bat');
  if (fs.existsSync(buildSrc) && fs.statSync(buildSrc).isFile()) {
    fs.copyFileSync(buildSrc, path.join(wsDir, 'build.bat'));
    if (verbose) console.log('  copy: build.bat');
    totalFiles++;
  }

  return totalFiles;
}

// ---------------------------------------------------------------------------
// Run helpers
// ---------------------------------------------------------------------------

/**
 * Run node tools/randomize.js <seed> inside the workspace.
 * Returns { success, output }.
 */
function runRandomizer(wsDir, seedStr, verbose, options = {}) {
  const randomizeScript = path.join('tools', 'randomize.js');
  const cmd  = ['node', randomizeScript, seedStr, '--workspace-build'];
  cmd.push('--input', path.join('tools', 'data', 'tracks.json'));
  if (options.tracks) cmd.push('--tracks', options.tracks);
  if (verbose) cmd.push('--verbose');

  const result = spawnSync(cmd[0], cmd.slice(1), {
    cwd:      wsDir,
    encoding: 'utf8',
  });
  const output  = (result.stdout || '') + (result.stderr || '');
  const success = result.status === 0;
  return { success, output };
}

function getHeadTrackBlockSize() {
  const lstPath = path.join(REPO_ROOT, 'smgp.lst');
  if (!fs.existsSync(lstPath)) return null;
  const text = fs.readFileSync(lstPath, 'utf8');
  const symbolMap = parseLstSymbolMapFromText(text);
  const start = symbolMap.get('San_Marino_curve_data');
  const end = symbolMap.get('Monaco_arcade_post_sign_tileset_blob');
	if (start === undefined || end === undefined || end < start) return null;
	const blobPath = path.join(REPO_ROOT, 'data', 'tracks', 'monaco_arcade', 'post_sign_tileset_blob.bin');
	if (!fs.existsSync(blobPath)) return null;
	const blobSize = fs.statSync(blobPath).size;
	return (end - start) + blobSize;
}

function getHeadTrackBlockStart() {
	const lstPath = path.join(REPO_ROOT, 'smgp.lst');
	if (!fs.existsSync(lstPath)) return null;
	const text = fs.readFileSync(lstPath, 'utf8');
	const symbolMap = parseLstSymbolMapFromText(text);
	return symbolMap.get('San_Marino_curve_data');
}

function getHeadMonacoBlobStart() {
	const lstPath = path.join(REPO_ROOT, 'smgp.lst');
	if (!fs.existsSync(lstPath)) return null;
	const text = fs.readFileSync(lstPath, 'utf8');
	const symbolMap = parseLstSymbolMapFromText(text);
	return symbolMap.get('Monaco_arcade_post_sign_tileset_blob');
}

function getWorkspaceGeneratedMonacoBlobStart(wsDir) {
	const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
	if (!fs.existsSync(generatedPath)) return null;
	const text = fs.readFileSync(generatedPath, 'utf8');
	let total = 0;
	for (const line of text.split(/\r?\n/)) {
		if (/^\s*Monaco_arcade_post_sign_tileset_blob:/i.test(line)) return total;
		const incbin = line.match(/^\s*incbin\s+"([^"]+)"/i);
		if (incbin) {
			const binPath = path.join(wsDir, incbin[1]);
			if (fs.existsSync(binPath)) total += fs.statSync(binPath).size;
			continue;
		}
		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) total += parseInt(dcb[1], 10);
	}
	return null;
}

function getWorkspaceGeneratedTrackBlockSize(wsDir) {
	const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
	if (!fs.existsSync(generatedPath)) return null;
	const text = fs.readFileSync(generatedPath, 'utf8');
	let total = 0;
	for (const line of text.split(/\r?\n/)) {
		const incbin = line.match(/^\s*incbin\s+"([^"]+)"/i);
		if (incbin) {
			const binPath = path.join(wsDir, incbin[1]);
			if (fs.existsSync(binPath)) total += fs.statSync(binPath).size;
			continue;
		}
		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) total += parseInt(dcb[1], 10);
	}
	return total;
}

function padGeneratedTrackBlockToBaseline(wsDir, options = {}) {
	const includeGeneratedMinimapData = options.includeGeneratedMinimapData === true;
	const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
	fs.writeFileSync(generatedPath, buildGeneratedTrackBlock({ includeGeneratedMinimapData }), 'utf8');

	const baselineSize = getHeadTrackBlockSize();
	const baselineStart = getHeadTrackBlockStart();
	if (baselineSize === null) return 0;
	const baselineBlobStart = getHeadMonacoBlobStart();
	let currentSize = getWorkspaceGeneratedTrackBlockSize(wsDir);
	const currentBlobStart = getWorkspaceGeneratedMonacoBlobStart(wsDir);
	if (currentSize === null) return 0;
	const baselineBlobRelative = baselineBlobStart !== null && baselineStart !== null
		? baselineBlobStart - baselineStart
		: null;
	const preBlobPadBytes = baselineBlobRelative !== null && currentBlobStart !== null
		? Math.max(0, baselineBlobRelative - currentBlobStart)
		: 0;
	const padBytes = Math.max(0, baselineSize - currentSize - preBlobPadBytes);
	if (padBytes <= 0 && preBlobPadBytes <= 0) return 0;
	fs.writeFileSync(generatedPath, buildGeneratedTrackBlock({ padBytes, preBlobPadBytes, includeGeneratedMinimapData }), 'utf8');
	currentSize = getWorkspaceGeneratedTrackBlockSize(wsDir);
	return currentSize === null ? 0 : (padBytes + preBlobPadBytes);
}

function applyWorkspaceHackOverlay(wsDir) {
  const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
  if (!fs.existsSync(generatedPath)) {
	  fs.writeFileSync(generatedPath, buildGeneratedTrackBlock({ includeGeneratedMinimapData: false }), 'utf8');
	}
  const padBytes = padGeneratedTrackBlockToBaseline(wsDir, { includeGeneratedMinimapData: false });

  const roadPath = path.join(wsDir, 'src', 'road_and_track_data.asm');

  const roadOld = fs.readFileSync(roadPath, 'utf8');
  const lines = roadOld.split(/\r?\n/);

	if (!roadOld.includes('include\t"src/road_and_track_data_generated.asm"')) {
		const startIndex = lines.findIndex(line => line.trim() === 'San_Marino_curve_data:');
		if (startIndex < 0) {
			throw new Error('Failed to find workspace road_and_track_data.asm track data start or existing generated include');
		}
		const prefixLines = lines.slice(0, startIndex);
		prefixLines.push('\tinclude\t"src/road_and_track_data_generated.asm"');
		prefixLines.push('\teven');
		const roadNew = prefixLines.join('\n') + '\n';
		fs.writeFileSync(roadPath, roadNew, 'utf8');
	}
	return { padBytes };
}

function normalizeWorkspaceRom(romPath) {
	const TARGET_ROM_SIZE = ROM_SIZE;
	const ROM_END_OFFSET = 0x1A4;
	const expectedRomEnd = TARGET_ROM_SIZE - 1;
	const rom = fs.readFileSync(romPath);

	if (rom.length > TARGET_ROM_SIZE) {
		throw new Error(
			`Workspace ROM exceeds fixed 512 KiB size: ${rom.length.toLocaleString()} bytes > ${TARGET_ROM_SIZE.toLocaleString()} bytes`
		);
	}

	const normalized = rom.length === TARGET_ROM_SIZE
		? Buffer.from(rom)
		: Buffer.concat([rom, Buffer.alloc(TARGET_ROM_SIZE - rom.length)]);

	normalized.writeUInt32BE(expectedRomEnd, ROM_END_OFFSET);
	fs.writeFileSync(romPath, normalized);

	return {
		oldSize: rom.length,
		newSize: normalized.length,
		romEnd: expectedRomEnd,
		padded: rom.length !== normalized.length,
	};
}

/**
 * Run build.bat in the workspace.
 * Returns { success, output }.
 * Success requires exit code 0 and '0 error(s)' in output.
 */
function runBuild(wsDir) {
  const result = spawnSync('cmd', ['/c', 'build.bat'], {
    cwd:      wsDir,
    encoding: 'utf8',
  });
  const output  = (result.stdout || '') + (result.stderr || '');
  if (result.status !== 0) return { success: false, output };
  if (output.includes('0 error(s)')) return { success: true, output };
  return { success: false, output };
}

function patchWorkspaceGeneratedMinimap(wsDir, verbose, options = {}) {
	const patchTool = path.join(REPO_ROOT, 'tools', 'workspace_patch_generated_minimap_rom.js');
	if (!fs.existsSync(patchTool)) {
		throw new Error(`workspace minimap patch tool not found: ${patchTool}`);
	}
	const cmd = ['node', patchTool, '--workspace', wsDir];
	if (options.tracks) cmd.push('--track', options.tracks);
	else cmd.push('--all');
	const result = spawnSync(cmd[0], cmd.slice(1), {
		cwd: REPO_ROOT,
		encoding: 'utf8',
	});
	const output = (result.stdout || '') + (result.stderr || '');
	const success = result.status === 0;
	return { success, output };
}

/**
 * Return the size of out.bin in the workspace, or null.
 */
function romSize(wsDir) {
  const romPath = path.join(wsDir, 'out.bin');
  if (fs.existsSync(romPath)) return fs.statSync(romPath).size;
  return null;
}

function sha256File(filePath) {
	const hash = crypto.createHash('sha256');
	hash.update(fs.readFileSync(filePath));
	return hash.digest('hex');
}

function compareBinaryFiles(aPath, bPath) {
	const a = fs.readFileSync(aPath);
	const b = fs.readFileSync(bPath);
	const minLength = Math.min(a.length, b.length);
	let firstDiff = -1;

	for (let i = 0; i < minLength; i++) {
		if (a[i] !== b[i]) {
			firstDiff = i;
			break;
		}
	}

	if (firstDiff < 0 && a.length !== b.length) {
		firstDiff = minLength;
	}

	return {
		equal: firstDiff < 0,
		firstDiff,
		sizeA: a.length,
		sizeB: b.length,
		hashA: sha256File(aPath),
		hashB: sha256File(bPath),
	};
}

function parseLstSymbolMapFromText(text) {
	const map = new Map();
	for (const line of text.split(/\r?\n/)) {
		const m = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (m) map.set(m[2], parseInt(m[1], 16));
	}
	return map;
}

function parseLstSymbolMap(lstPath) {
  return parseLstSymbolMapFromText(fs.readFileSync(lstPath, 'utf8'));
}

function verifyWorkspaceAddressStability(wsDir) {
  const baselinePath = path.join(wsDir, 'smgp_head.lst');
  const workspacePath = path.join(wsDir, 'smgp.lst');
  if (!fs.existsSync(baselinePath) || !fs.existsSync(workspacePath)) {
    return { ok: false, message: 'Missing smgp.lst for address stability check.' };
  }

  const baseline = parseLstSymbolMap(baselinePath);
  const workspace = parseLstSymbolMap(workspacePath);

	const relocationHazards = [
		// Add symbols here only when we have confirmed raw/non-relocating references
		// that still exist in source or opaque data. Current known source-level hazards
		// were converted to symbolic references, so downstream movement alone is not
		// treated as a hard failure.
	];

	const movedHazards = [];
	for (const name of relocationHazards) {
		const baseAddr = baseline.get(name);
		const wsAddr = workspace.get(name);
		if (baseAddr === undefined || wsAddr === undefined) {
			return {
				ok: false,
				message: `Missing relocation hazard symbol in smgp.lst: ${name}`,
			};
		}
		if (baseAddr !== wsAddr) {
			movedHazards.push({ name, baseAddr, wsAddr });
		}
	}

	if (movedHazards.length > 0) {
		const preview = movedHazards.map(entry =>
			`${entry.name}: 0x${entry.baseAddr.toString(16).toUpperCase()} -> 0x${entry.wsAddr.toString(16).toUpperCase()}`
		).join('\n');
		return {
			ok: false,
			moved: movedHazards,
			message:
				'Workspace build still moved symbol(s) that are known to have had raw ROM-address references.\n' +
				'Resolve or explicitly clear these confirmed relocation hazards before trusting the hack build.\n' +
				preview,
		};
	}

	return { ok: true, moved: [] };
}

function writeWorkspaceBaselineLst(wsDir) {
  const baselineBuild = runBuild(wsDir);
  if (!baselineBuild.success) {
    throw new Error(
      'Failed to build unmodified workspace baseline for address stability check.\n' +
      baselineBuild.output
    );
  }

  const srcPath = path.join(wsDir, 'smgp.lst');
  const dstPath = path.join(wsDir, 'smgp_head.lst');
  const outPath = path.join(wsDir, 'out.bin');
  if (!fs.existsSync(srcPath)) {
    throw new Error('Workspace baseline build did not produce smgp.lst');
  }
  if (!fs.existsSync(outPath)) {
    throw new Error('Workspace baseline build did not produce out.bin');
  }

	const normalized = normalizeWorkspaceRom(outPath);

  const canonicalRomPath = path.join(REPO_ROOT, 'orig.bin');
  if (fs.existsSync(canonicalRomPath)) {
		const compare = compareBinaryFiles(outPath, canonicalRomPath);
		if (!compare.equal) {
			const diffHex = compare.firstDiff >= 0
				? `0x${compare.firstDiff.toString(16).toUpperCase()}`
				: 'n/a';
			throw new Error(
				'Workspace baseline ROM does not match orig.bin before any hack overlay or randomization.\n' +
				'This means the copied workspace inputs are already non-canonical, so later black-screen/debug results are polluted.\n' +
				'The most likely cause is modified extracted assets under data/ and/or tools/data, or a remaining source mismatch between git HEAD and the verified working tree.\n' +
				`workspace normalization: ${normalized.oldSize.toLocaleString()} -> ${normalized.newSize.toLocaleString()} bytes\n` +
				`workspace out.bin: ${compare.sizeA.toLocaleString()} bytes, sha256 ${compare.hashA}\n` +
				`orig.bin:         ${compare.sizeB.toLocaleString()} bytes, sha256 ${compare.hashB}\n` +
				`first differing byte: ${diffHex}`
			);
		}
  }

  fs.copyFileSync(srcPath, dstPath);
  if (fs.existsSync(outPath)) fs.rmSync(outPath, { force: true });

  return dstPath;
}

function restoreWorkspaceTracksFromBackup(wsDir) {
	const tracksOrigPath = path.join(wsDir, 'tools', 'data', 'tracks.orig.json');
	const tracksPath = path.join(wsDir, 'tools', 'data', 'tracks.json');
	if (!fs.existsSync(tracksOrigPath)) return false;

	fs.copyFileSync(tracksOrigPath, tracksPath);

	const tracksData = JSON.parse(fs.readFileSync(tracksOrigPath, 'utf8'));
	const injectorPath = path.resolve(wsDir, 'tools', 'inject_track_data.js');
	const syncPath = path.resolve(wsDir, 'tools', 'sync_track_config.js');
	const { injectTrack } = require(injectorPath);
	const { buildSyncedTrackConfig } = require(syncPath);
	const dataDir = path.join(wsDir, 'data', 'tracks');
	for (const track of tracksData.tracks || []) {
		injectTrack(track, dataDir, false, false);
	}

	const trackConfigPath = path.join(wsDir, 'src', 'track_config_data.asm');
	const trackConfigLines = fs.readFileSync(trackConfigPath, 'utf8').split(/(?<=\n)/);
	const syncResult = buildSyncedTrackConfig(trackConfigLines, tracksData);
	fs.writeFileSync(trackConfigPath, syncResult.content, 'utf8');
	fs.writeFileSync(path.join(wsDir, 'src', 'road_and_track_data_generated.asm'), buildGeneratedTrackBlock({ includeGeneratedMinimapData: false }), 'utf8');
	return true;
}

function findCanonicalWorkspaceSnapshot(excludeDir = null) {
	const canonicalRomPath = path.join(REPO_ROOT, 'orig.bin');
	if (!fs.existsSync(canonicalRomPath)) return null;
	const canonicalHash = sha256File(canonicalRomPath);
	if (!fs.existsSync(WORKSPACES) || !fs.statSync(WORKSPACES).isDirectory()) return null;

	const entries = fs.readdirSync(WORKSPACES)
		.map(name => path.join(WORKSPACES, name))
		.filter(dir => dir !== excludeDir)
		.reverse();

	for (const dir of entries) {
		const outPath = path.join(dir, 'out.bin');
		const tracksPath = path.join(dir, 'tools', 'data', 'tracks.json');
		const dataDir = path.join(dir, 'data', 'tracks');
		if (!fs.existsSync(outPath) || !fs.existsSync(tracksPath) || !fs.existsSync(dataDir)) continue;
		try {
			if (sha256File(outPath) !== canonicalHash) continue;
			return dir;
		} catch (_) {
			continue;
		}
	}

	return null;
}

function restoreWorkspaceTracksFromCanonicalSnapshot(wsDir) {
	const snapshotDir = findCanonicalWorkspaceSnapshot(wsDir);
	if (!snapshotDir) return null;

	copyDirRecursive(path.join(snapshotDir, 'data', 'tracks'), path.join(wsDir, 'data', 'tracks'), false);
	fs.copyFileSync(path.join(snapshotDir, 'tools', 'data', 'tracks.json'), path.join(wsDir, 'tools', 'data', 'tracks.json'));
	const snapshotGenerated = path.join(snapshotDir, 'src', 'road_and_track_data_generated.asm');
	if (fs.existsSync(snapshotGenerated)) {
		fs.copyFileSync(snapshotGenerated, path.join(wsDir, 'src', 'road_and_track_data_generated.asm'));
	} else {
		fs.writeFileSync(path.join(wsDir, 'src', 'road_and_track_data_generated.asm'), buildGeneratedTrackBlock({ includeGeneratedMinimapData: false }), 'utf8');
	}
	return snapshotDir;
}

function prepareWorkspaceCanonicalData(wsDir) {
	try {
		return { restoredFromBackup: false, restoredFromSnapshot: null, baselineLst: writeWorkspaceBaselineLst(wsDir) };
	} catch (error) {
		const message = String(error && error.message);
		if (!/Workspace baseline ROM does not match orig\.bin/.test(message) && !/orig\.bin/.test(message)) {
			throw error;
		}
		const restored = restoreWorkspaceTracksFromBackup(wsDir);
		if (restored) {
			return { restoredFromBackup: true, restoredFromSnapshot: null, baselineLst: writeWorkspaceBaselineLst(wsDir) };
		}
		const snapshotDir = restoreWorkspaceTracksFromCanonicalSnapshot(wsDir);
		if (!snapshotDir) throw error;
		const followupBuild = runBuild(wsDir);
		if (!followupBuild.success) {
			throw new Error(
				'Failed to build workspace after restoring canonical track snapshot.\n' +
				followupBuild.output
			);
		}
		return { restoredFromBackup: false, restoredFromSnapshot: snapshotDir, baselineLst: writeWorkspaceBaselineLst(wsDir) };
	}
}

// ---------------------------------------------------------------------------
// Log writer
// ---------------------------------------------------------------------------
function writeLog(wsDir, seedStr, randOutput, buildOutput, success, elapsedSecs, outputPath) {
  const logPath = path.join(wsDir, 'randomizer.log');
  const ts      = new Date().toISOString().replace(/\.\d{3}Z$/, '');
  const size    = romSize(wsDir);
  const lines   = [
    'Super Monaco GP Randomizer Log',
    `Generated : ${ts}`,
    `Seed      : ${seedStr}`,
    `Elapsed   : ${elapsedSecs.toFixed(1)}s`,
    size !== null
      ? `ROM size  : ${size.toLocaleString()} bytes`
      : 'ROM size  : N/A',
    outputPath
      ? `Output    : ${outputPath}`
      : 'Output    : (not copied)',
    `Result    : ${success ? 'SUCCESS' : 'FAILED'}`,
    '',
    '--- Randomizer output ---',
    randOutput,
    '--- Build output ---',
    buildOutput,
  ];
  fs.writeFileSync(logPath, lines.join('\n'), 'utf8');
  return logPath;
}

// ---------------------------------------------------------------------------
// List workspaces
// ---------------------------------------------------------------------------
function listWorkspaces() {
  if (!fs.existsSync(WORKSPACES) || !fs.statSync(WORKSPACES).isDirectory()) {
    console.log('No workspaces directory found.');
    return;
  }
  const entries = fs.readdirSync(WORKSPACES).sort();
  if (entries.length === 0) {
    console.log('No workspaces found.');
    return;
  }
  console.log(`Workspaces in ${WORKSPACES}:`);
  for (const name of entries) {
    const ws      = path.join(WORKSPACES, name);
    const logFile = path.join(ws, 'randomizer.log');
    const romFile = path.join(ws, 'out.bin');
    const romInfo = fs.existsSync(romFile)
      ? `  ROM: ${fs.statSync(romFile).size.toLocaleString()} bytes`
      : '  ROM: not found';
    let resultStr = '';
    if (fs.existsSync(logFile)) {
      for (const line of fs.readFileSync(logFile, 'utf8').split('\n')) {
        if (line.startsWith('Result')) {
          resultStr = `  ${line.trim()}`;
          break;
        }
      }
    }
    console.log(`  ${name}${romInfo}${resultStr}`);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  const args = parseArgs(process.argv.slice(2), {
		flags:   ['--keep', '--dry-run', '--list', '--force', '--use-working-tree', '--use-git-head', '--verbose', '-v'],
    options: ['--output', '-o', '--workspace', '--tracks'],
  });

  const keep    = args.flags['--keep'];
  const dryRun  = args.flags['--dry-run'];
  const list    = args.flags['--list'];
  const force   = args.flags['--force'];
	const useWorkingTreeAsm = args.flags['--use-git-head'] ? false : true;
  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const outputArg    = args.options['--output'] || args.options['-o'] || null;
  const workspaceArg = args.options['--workspace'] || null;
  const tracksArg = args.options['--tracks'] || null;

  // --list
  if (list) {
    listWorkspaces();
    return;
  }

  // Require seed
  const seedStr = (args.positional || [])[0];
  if (!seedStr) {
    process.stderr.write(
      'Usage: node tools/hack_workdir.js SMGP-<v>-<flags_hex>-<decimal> [options]\n' +
      '       node tools/hack_workdir.js --list\n'
    );
    process.exit(1);
  }

  // Validate seed
  let version, flags, seedInt;
  try {
    [version, flags, seedInt] = validateSeed(seedStr);
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    process.exit(1);
  }

  // Resolve workspace directory
  const wsDir = workspaceArg || path.join(WORKSPACES, seedStr);

  // Resolve output path
  const safeSeed    = seedStr.replace(/[\\/]/g, '_');
  const safeTracks  = tracksArg
    ? `_${tracksArg.replace(/[^A-Za-z0-9._-]+/g, '_')}`
    : '';
  const defaultOut  = path.join(ROM_OUTPUTS, `out_${safeSeed}${safeTracks}.bin`);
  const outputPath  = outputArg
    ? (path.isAbsolute(outputArg) ? outputArg : path.join(REPO_ROOT, outputArg))
    : defaultOut;

  console.log(`Seed      : ${seedStr}`);
  console.log(`Version   : ${version}`);
  console.log(`Flags     : 0x${flags.toString(16).toUpperCase().padStart(2, '0')}`);
  if (tracksArg) console.log(`Tracks    : ${tracksArg}`);
  console.log(`Workspace : ${wsDir}`);
  console.log(`Output    : ${outputPath}`);
	console.log(`ASM base  : ${useWorkingTreeAsm ? 'working tree' : 'git HEAD'}`);

  if (dryRun) {
    console.log('\nDRY RUN — no files will be created or modified.');
    return;
  }

  // Create workspaces base if needed
  fs.mkdirSync(WORKSPACES, { recursive: true });
  fs.mkdirSync(ROM_OUTPUTS, { recursive: true });

  // Handle existing workspace
  if (fs.existsSync(wsDir)) {
    if (force) {
      console.log(`\nRemoving existing workspace: ${wsDir}`);
      fs.rmSync(wsDir, { recursive: true, force: true });
    } else {
      process.stderr.write(`\nERROR: Workspace already exists: ${wsDir}\n`);
      process.stderr.write('Use --force to overwrite or --list to see existing workspaces.\n');
      process.exit(1);
    }
  }

  // Create workspace
  fs.mkdirSync(wsDir, { recursive: true });
  console.log('\n[1/5] Creating workspace ...');

  // Copy build files
  console.log('[2/5] Copying build files ...');
	const nFiles = copyBuildFiles(REPO_ROOT, wsDir, verbose, { useWorkingTreeAsm });
  console.log(`      ${nFiles} files copied.`);

  let baselineInfo;
  try {
    baselineInfo = prepareWorkspaceCanonicalData(wsDir);
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    process.exit(1);
  }
	if (baselineInfo && baselineInfo.restoredFromBackup) {
		console.log('      Restored canonical track data from workspace backup before baseline build.');
	}
	if (baselineInfo && baselineInfo.restoredFromSnapshot) {
		console.log(`      Restored canonical track data from snapshot: ${baselineInfo.restoredFromSnapshot}`);
	}

  try {
    const overlay = applyWorkspaceHackOverlay(wsDir);
    if (verbose) console.log('      Applied workspace-only hack overlay.');
    if (overlay && overlay.padBytes > 0) console.log(`      Padded generated track block by ${overlay.padBytes} byte(s) to preserve downstream addresses.`);
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    process.exit(1);
  }

  // Run randomizer
  console.log(`[3/5] Running randomizer (seed: ${seedStr}) ...`);
  const t0 = Date.now();
  const { success: randOk, output: randOutput } = runRandomizer(wsDir, seedStr, verbose, {
		tracks: tracksArg,
	});
  const randElapsed = (Date.now() - t0) / 1000;

  if (verbose || !randOk) {
    for (const line of randOutput.split('\n')) {
      if (line.trim()) console.log(`      ${line}`);
    }
  }

  if (!randOk) {
    console.error(`\nERROR: Randomizer failed (after ${randElapsed.toFixed(1)}s).`);
    writeLog(wsDir, seedStr, randOutput, '', false, randElapsed, null);
    console.log(`Workspace preserved at: ${wsDir}`);
    process.exit(1);
  }

  console.log(`      Randomizer succeeded (${randElapsed.toFixed(1)}s).`);

	const postRandomizerPadBytes = padGeneratedTrackBlockToBaseline(wsDir, { includeGeneratedMinimapData: false });
	if (postRandomizerPadBytes > 0) {
		console.log(`      Re-padded generated track block by ${postRandomizerPadBytes} byte(s) after randomization.`);
	}

  // Build (verification step — randomize.js already calls build.bat internally)
  console.log('[4/5] Building ROM ...');
  const t1 = Date.now();
  const { success: buildOk, output: buildOutput } = runBuild(wsDir);
  const buildElapsed = (Date.now() - t1) / 1000;
  let finalBuildOutput = buildOutput;

  if (verbose || !buildOk) {
    for (const line of buildOutput.split('\n')) {
      if (line.trim()) console.log(`      ${line}`);
    }
  }

  const totalElapsed = randElapsed + buildElapsed;

  if (!buildOk) {
    console.error(`\nERROR: Build failed (after ${buildElapsed.toFixed(1)}s).`);
    writeLog(wsDir, seedStr, randOutput, buildOutput, false, totalElapsed, null);
    console.log(`Workspace preserved at: ${wsDir}`);
    process.exit(1);
  }

  const size = romSize(wsDir);
  const wsRom = path.join(wsDir, 'out.bin');
  if (fs.existsSync(wsRom)) {
		const normalized = normalizeWorkspaceRom(wsRom);
		if (normalized.padded) {
			console.log(`      ROM padded to fixed size: ${normalized.oldSize.toLocaleString()} -> ${normalized.newSize.toLocaleString()} bytes`);
		}
    const checksum = patchRomChecksum(wsRom);
    console.log(`      Header checksum ${checksum.changed ? 'patched' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
  }
  if (size !== null) {
    console.log(`      Build succeeded (${buildElapsed.toFixed(1)}s).  ROM: ${size.toLocaleString()} bytes (${Math.floor(size / 1024)} KB)`);
  } else {
    console.log(`      Build succeeded (${buildElapsed.toFixed(1)}s).`);
  }

  const stability = verifyWorkspaceAddressStability(wsDir);
  if (!stability.ok) {
    console.error(`\nERROR: ${stability.message}`);
    writeLog(wsDir, seedStr, randOutput, `${finalBuildOutput}\n\n[ADDRESS STABILITY CHECK]\n${stability.message}\n`, false, totalElapsed, null);
    console.log(`Workspace preserved at: ${wsDir}`);
    process.exit(1);
  }

	if (flags & 0x01) {
		console.log('      Patching generated minimap data into workspace ROM ...');
		const { success: minimapPatchOk, output: minimapPatchOutput } = patchWorkspaceGeneratedMinimap(wsDir, verbose, {
			tracks: tracksArg,
		});
		finalBuildOutput += `\n\n[GENERATED MINIMAP PATCH]\n${minimapPatchOutput}`;
		if (verbose || !minimapPatchOk) {
			for (const line of minimapPatchOutput.split('\n')) {
				if (line.trim()) console.log(`      ${line}`);
			}
		}
		if (!minimapPatchOk) {
			console.error('\nERROR: Generated minimap ROM patch failed.');
			writeLog(wsDir, seedStr, randOutput, finalBuildOutput, false, totalElapsed, null);
			console.log(`Workspace preserved at: ${wsDir}`);
			process.exit(1);
		}
		if (fs.existsSync(wsRom)) {
			const checksum = patchRomChecksum(wsRom);
			console.log(`      Header checksum ${checksum.changed ? 'patched' : 'verified'} after minimap patch: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
		}
	}

  // Copy output ROM
  console.log('[5/5] Copying ROM to output ...');
  if (fs.existsSync(wsRom)) {
    fs.copyFileSync(wsRom, outputPath);
    console.log(`      Written: ${outputPath}`);
  } else {
    process.stderr.write('ERROR: out.bin not found in workspace after build.\n');
    process.exit(1);
  }

  // Write log
  const logPath = writeLog(wsDir, seedStr, randOutput, finalBuildOutput, true, totalElapsed, outputPath);
  console.log(`      Log:     ${logPath}`);

  // Clean up workspace unless --keep
  if (!keep) {
    fs.rmSync(wsDir, { recursive: true, force: true });
    console.log('\nWorkspace removed (use --keep to retain).');
  } else {
    console.log(`\nWorkspace retained at: ${wsDir}`);
  }

  console.log(`\nDone.  Seed: ${seedStr}`);
  console.log(`       ROM:  ${outputPath}`);
  console.log(`       Time: ${totalElapsed.toFixed(1)}s`);
}

main();
