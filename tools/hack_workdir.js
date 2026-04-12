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
const { parseArgs, die, printJson, printUsage } = require('./lib/cli');
const { REPO_ROOT, ROM_SIZE }    = require('./lib/rom');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { runBuild } = require('./randomize_build');
const { getTracks, requireTracksDataShape } = require('./randomizer/track_model');
const { buildGeneratedTrackBlock, measureAsmDataLayout } = require('./generate_track_data_asm');

const MONACO_INLINE_BLOB_PAD_BYTES = 2399;

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const WORKSPACES = path.join(REPO_ROOT, 'build', 'workspaces');
const ROM_OUTPUTS = path.join(REPO_ROOT, 'build', 'roms');
const WORKSPACE_TEMPLATE_DIR = path.join(WORKSPACES, '_template');
const USAGE_TEXT = [
	'Usage: node tools/hack_workdir.js SMGP-<v>-<flags_hex>-<decimal> [options]',
	'       node tools/hack_workdir.js --list [--json]',
	'',
	'Options:',
	'  --output, -o <path>  Output ROM path',
	'  --workspace <path>   Override workspace directory',
	'  --tracks <list>      Restrict track randomization to selected slugs',
	'  --keep               Preserve the workspace on success',
	'  --force              Refresh an existing workspace in place',
	'  --dry-run            Show resolved paths without creating files',
	'  --json               Emit machine-readable output for --dry-run/--list',
	'  --use-working-tree   Use current ASM files as the workspace base (default)',
	'  --use-git-head       Use tracked HEAD ASM files as the workspace base',
	'  --verbose, -v        Show additional progress output',
	'  --help, -h           Show this help text',
].join('\n');

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
		'randomizer_plan.js',
		'randomize_actions.js',
		'randomize_track_support.js',
		'randomize_modules.js',
		'randomize_build.js',
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
		'write_generated_minimap_assets.js',
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

function removeDirContents(dirPath) {
	if (!fs.existsSync(dirPath) || !fs.statSync(dirPath).isDirectory()) return;
	for (const entry of fs.readdirSync(dirPath)) {
		fs.rmSync(path.join(dirPath, entry), { recursive: true, force: true });
	}
}

function copyWorkspaceTemplate(templateDir, wsDir, verbose) {
	fs.cpSync(templateDir, wsDir, { recursive: true });
	if (verbose) console.log(`  copy: template -> ${path.relative(REPO_ROOT, wsDir)}`);
	return true;
}

function refreshWorkspaceFromTemplate(templateDir, wsDir, verbose) {
	const mutablePaths = [
		['src'],
		['data', 'tracks'],
		['tools', 'data'],
	];
	for (const parts of mutablePaths) {
		const srcPath = path.join(templateDir, ...parts);
		const dstPath = path.join(wsDir, ...parts);
		if (!fs.existsSync(srcPath)) continue;
		fs.rmSync(dstPath, { recursive: true, force: true });
		fs.cpSync(srcPath, dstPath, { recursive: true });
	}
	for (const fileName of ['out.bin', 'smgp.lst', 'smgp_head.lst', 'randomizer.log']) {
		fs.rmSync(path.join(wsDir, fileName), { force: true });
	}
	if (verbose) console.log(`  refresh: mutable workspace inputs from template -> ${path.relative(REPO_ROOT, wsDir)}`);
}

function ensureWorkspaceTemplate(repoRoot, verbose, options = {}) {
	const useWorkingTreeAsm = options.useWorkingTreeAsm === true;
	const markerPath = path.join(WORKSPACE_TEMPLATE_DIR, '.template-ready.json');
	const desiredMarker = JSON.stringify({ asmBase: useWorkingTreeAsm ? 'working-tree' : 'git-head' });
	if (fs.existsSync(WORKSPACE_TEMPLATE_DIR) && fs.existsSync(markerPath)) {
		try {
			if (fs.readFileSync(markerPath, 'utf8').trim() === desiredMarker) return { reused: true };
		} catch (_) {
			// fall through to rebuild
		}
	}
	fs.mkdirSync(WORKSPACE_TEMPLATE_DIR, { recursive: true });
	removeDirContents(WORKSPACE_TEMPLATE_DIR);
	const fileCount = copyBuildFiles(repoRoot, WORKSPACE_TEMPLATE_DIR, verbose, options);
	fs.writeFileSync(markerPath, desiredMarker, 'utf8');
	return { reused: false, fileCount };
}

function loadRepoBaselineSymbolMap() {
	const merged = new Map();
	const lstPath = path.join(REPO_ROOT, 'smgp.lst');
	if (fs.existsSync(lstPath)) {
		for (const [name, value] of parseLstSymbolMapFromText(fs.readFileSync(lstPath, 'utf8')).entries()) {
			if (!merged.has(name)) merged.set(name, value);
		}
	}
	const jsonPath = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');
	if (fs.existsSync(jsonPath)) {
		const json = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
		const symbols = json && typeof json === 'object' ? json.symbols : null;
		if (symbols && typeof symbols === 'object') {
			for (const [name, value] of Object.entries(symbols)) {
				if (typeof value !== 'string' || merged.has(name)) continue;
				merged.set(name, parseInt(value.replace(/^0x/i, ''), 16));
			}
		}
	}
	return merged.size > 0 ? merged : null;
}

function loadWorkspaceBaselineSymbolMap(wsDir) {
	const baselinePath = path.join(wsDir, 'smgp_head.lst');
	if (!fs.existsSync(baselinePath)) return null;
	return parseLstSymbolMap(baselinePath);
}

function getBaselineSymbolMap(wsDir = null) {
	return (wsDir ? loadWorkspaceBaselineSymbolMap(wsDir) : null) || loadRepoBaselineSymbolMap();
}

function getHeadTrackBlockSize(wsDir = null) {
	const symbolMap = getBaselineSymbolMap(wsDir);
	if (!symbolMap) return null;
	const start = symbolMap.get('San_Marino_curve_data');
	const end = symbolMap.get('Monaco_arcade_post_sign_tileset_blob');
	if (start === undefined || end === undefined || end < start) return null;
	const blobBase = wsDir || REPO_ROOT;
	const blobPath = path.join(blobBase, 'data', 'tracks', 'monaco_arcade', 'post_sign_tileset_blob.bin');
	if (!fs.existsSync(blobPath)) return null;
	const blobSize = fs.statSync(blobPath).size;
	return (end - start) + blobSize;
}

function getHeadTrackBlockStart(wsDir = null) {
	const symbolMap = getBaselineSymbolMap(wsDir);
	if (!symbolMap) return null;
	return symbolMap.get('San_Marino_curve_data');
}

function getHeadMonacoBlobStart(wsDir = null) {
	const symbolMap = getBaselineSymbolMap(wsDir);
	if (!symbolMap) return null;
	return symbolMap.get('Monaco_arcade_post_sign_tileset_blob');
}

function getWorkspaceGeneratedMonacoBlobStart(wsDir) {
	const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
	if (!fs.existsSync(generatedPath)) return null;
	const text = fs.readFileSync(generatedPath, 'utf8');
	return measureAsmDataLayout(text, wsDir).blobStart;
}

function getWorkspaceGeneratedTrackBlockSize(wsDir) {
	const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
	if (!fs.existsSync(generatedPath)) return null;
	const text = fs.readFileSync(generatedPath, 'utf8');
	return measureAsmDataLayout(text, wsDir).total;
}

function padGeneratedTrackBlockToBaseline(wsDir, options = {}) {
	const includeGeneratedMinimapData = options.includeGeneratedMinimapData === true;
	const generatedPath = path.join(wsDir, 'src', 'road_and_track_data_generated.asm');
	fs.writeFileSync(generatedPath, buildGeneratedTrackBlock({ includeGeneratedMinimapData }), 'utf8');

	const baselineSize = getHeadTrackBlockSize(wsDir);
	const baselineStart = getHeadTrackBlockStart(wsDir);
	if (baselineSize === null) return 0;
	const baselineBlobStart = getHeadMonacoBlobStart(wsDir);
	let currentSize = getWorkspaceGeneratedTrackBlockSize(wsDir);
	const currentBlobStart = getWorkspaceGeneratedMonacoBlobStart(wsDir);
	if (currentSize === null) return 0;
	const baselineBlobRelative = baselineBlobStart !== null && baselineStart !== null
		? baselineBlobStart - baselineStart
		: null;
	const oversize = Math.max(0, currentSize - baselineSize);
	const inlineBlobPadBytes = Math.max(0, MONACO_INLINE_BLOB_PAD_BYTES - oversize);
	const adjustedBlobStart = currentBlobStart !== null ? currentBlobStart - oversize : currentBlobStart;
	const preBlobPadBytes = baselineBlobRelative !== null && adjustedBlobStart !== null
		? Math.max(0, baselineBlobRelative - adjustedBlobStart)
		: 0;
	const adjustedCurrentSize = currentSize - oversize;
	const padBytes = Math.max(0, baselineSize - adjustedCurrentSize - preBlobPadBytes);
	if (padBytes <= 0 && preBlobPadBytes <= 0 && inlineBlobPadBytes === MONACO_INLINE_BLOB_PAD_BYTES) return 0;
	fs.writeFileSync(generatedPath, buildGeneratedTrackBlock({ padBytes, preBlobPadBytes, includeGeneratedMinimapData, inlineBlobPadBytes }), 'utf8');
	currentSize = getWorkspaceGeneratedTrackBlockSize(wsDir);
	return currentSize === null ? 0 : (padBytes + preBlobPadBytes + (MONACO_INLINE_BLOB_PAD_BYTES - inlineBlobPadBytes));
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

function patchWorkspaceRomHeaderEnd(romPath) {
	const ROM_END_OFFSET = 0x1A4;
	const rom = fs.readFileSync(romPath);
	if (rom.length < ROM_END_OFFSET + 4) {
		throw new Error(`workspace ROM too small to patch ROM end header: ${rom.length}`);
	}
	const oldRomEnd = rom.readUInt32BE(ROM_END_OFFSET);
	const newRomEnd = rom.length - 1;
	if (oldRomEnd !== newRomEnd) {
		rom.writeUInt32BE(newRomEnd >>> 0, ROM_END_OFFSET);
		fs.writeFileSync(romPath, rom);
	}
	return {
		oldRomEnd,
		newRomEnd,
		changed: oldRomEnd !== newRomEnd,
	};
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

function normalizeCompatibilitySymbols(baseline, current) {
	const blobLabel = 'Monaco_arcade_post_sign_tileset_blob';
	const tilesetLabel = 'Monaco_arcade_sign_tileset';
	if (!baseline.has(blobLabel)) return;
	if (current.has(blobLabel)) return;
	if (!current.has(tilesetLabel) || !baseline.has(tilesetLabel)) return;
	const delta = baseline.get(blobLabel) - baseline.get(tilesetLabel);
	current.set(blobLabel, current.get(tilesetLabel) + delta);
}

function verifyWorkspaceAddressStability(wsDir) {
  const workspacePath = path.join(wsDir, 'smgp.lst');
  if (!fs.existsSync(workspacePath)) {
    return { ok: false, message: 'Missing workspace smgp.lst for address stability check.' };
  }
  const baseline = loadWorkspaceBaselineSymbolMap(wsDir) || loadRepoBaselineSymbolMap();
  if (!baseline) {
    return { ok: false, message: 'Missing baseline symbol map for address stability check.' };
  }

	const current = parseLstSymbolMap(workspacePath);
	normalizeCompatibilitySymbols(baseline, current);
	const trackBlockStart = baseline.get('San_Marino_curve_data');
	const trackBlockEnd = baseline.get('Monaco_arcade_post_sign_tileset_blob');
	const moved = [];
	const missing = [];

	for (const [label, oldAddr] of baseline.entries()) {
		if (!current.has(label)) {
			missing.push(label);
			continue;
		}
		const newAddr = current.get(label);
		if (newAddr === oldAddr) continue;
		const insideRandomizedTrackPayload = trackBlockStart !== undefined && trackBlockEnd !== undefined
			&& oldAddr >= trackBlockStart
			&& oldAddr < trackBlockEnd;
		if (!insideRandomizedTrackPayload) {
			moved.push([label, oldAddr, newAddr]);
		}
	}

	if (missing.length > 0 || moved.length > 0) {
		const lines = [];
		if (missing.length > 0) {
			lines.push(`Missing symbols: ${missing.length}`);
			for (const label of missing.slice(0, 20)) lines.push(`  MISSING ${label}`);
			if (missing.length > 20) lines.push(`  ... and ${missing.length - 20} more`);
		}
		if (moved.length > 0) {
			lines.push(`Moved non-track symbols: ${moved.length}`);
			for (const [label, oldAddr, newAddr] of moved.slice(0, 20)) {
				lines.push(`  MOVED ${label}: 0x${oldAddr.toString(16).toUpperCase().padStart(6, '0')} -> 0x${newAddr.toString(16).toUpperCase().padStart(6, '0')}`);
			}
			if (moved.length > 20) lines.push(`  ... and ${moved.length - 20} more`);
		}
		return { ok: false, message: lines.join('\n') };
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

	const tracksData = requireTracksDataShape(JSON.parse(fs.readFileSync(tracksOrigPath, 'utf8')));
	const injectorPath = path.resolve(wsDir, 'tools', 'inject_track_data.js');
	const syncPath = path.resolve(wsDir, 'tools', 'sync_track_config.js');
	const { injectTrack } = require(injectorPath);
	const { buildSyncedTrackConfig } = require(syncPath);
	const dataDir = path.join(wsDir, 'data', 'tracks');
	for (const track of getTracks(tracksData)) {
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

	for (const entry of fs.readdirSync(snapshotDir, { withFileTypes: true })) {
		if (!entry.isFile() || !entry.name.endsWith('.asm')) continue;
		fs.copyFileSync(path.join(snapshotDir, entry.name), path.join(wsDir, entry.name));
	}
	copyDirRecursive(path.join(snapshotDir, 'src'), path.join(wsDir, 'src'), false);
	copyDirRecursive(path.join(snapshotDir, 'data', 'tracks'), path.join(wsDir, 'data', 'tracks'), false);
	fs.copyFileSync(path.join(snapshotDir, 'tools', 'data', 'tracks.json'), path.join(wsDir, 'tools', 'data', 'tracks.json'));
	return snapshotDir;
}

function prepareWorkspaceCanonicalData(wsDir) {
	try {
		writeWorkspaceBaselineLst(wsDir);
		return { restoredFromBackup: false, restoredFromSnapshot: null };
	} catch (error) {
		const message = String(error && error.message);
		if (!/Workspace baseline ROM does not match orig\.bin/.test(message) && !/orig\.bin/.test(message)) {
			throw error;
		}
		const restored = restoreWorkspaceTracksFromBackup(wsDir);
		if (restored) {
			writeWorkspaceBaselineLst(wsDir);
			return { restoredFromBackup: true, restoredFromSnapshot: null };
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
		writeWorkspaceBaselineLst(wsDir);
		return { restoredFromBackup: false, restoredFromSnapshot: snapshotDir };
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
function getWorkspaceResult(logFile) {
	if (!fs.existsSync(logFile)) return null;
	for (const line of fs.readFileSync(logFile, 'utf8').split('\n')) {
		if (line.startsWith('Result')) {
			const match = /Result\s*:\s*(\S+)/.exec(line);
			return match ? match[1] : line.trim();
		}
	}
	return null;
}

function collectWorkspaceEntries() {
	if (!fs.existsSync(WORKSPACES) || !fs.statSync(WORKSPACES).isDirectory()) {
		return {
			tool: 'hack_workdir',
			workspacesDir: WORKSPACES,
			workspaces: [],
		};
	}
	const entries = fs.readdirSync(WORKSPACES).sort().map(name => {
		const ws = path.join(WORKSPACES, name);
		const logFile = path.join(ws, 'randomizer.log');
		const romFile = path.join(ws, 'out.bin');
		return {
			name,
			path: ws,
			rom: {
				exists: fs.existsSync(romFile),
				size: fs.existsSync(romFile) ? fs.statSync(romFile).size : null,
			},
			result: getWorkspaceResult(logFile),
		};
	});
	return {
		tool: 'hack_workdir',
		workspacesDir: WORKSPACES,
		workspaces: entries,
	};
}

function listWorkspaces(options = {}) {
	const summary = collectWorkspaceEntries();
	if (options.json) {
		printJson(summary);
		return summary;
	}
	if (!fs.existsSync(WORKSPACES) || !fs.statSync(WORKSPACES).isDirectory()) {
		console.log('No workspaces directory found.');
		return summary;
	}
	if (summary.workspaces.length === 0) {
		console.log('No workspaces found.');
		return summary;
	}
	console.log(`Workspaces in ${WORKSPACES}:`);
	for (const entry of summary.workspaces) {
		const romInfo = entry.rom.exists
			? `  ROM: ${entry.rom.size.toLocaleString()} bytes`
			: '  ROM: not found';
		const resultStr = entry.result ? `  Result: ${entry.result}` : '';
		console.log(`  ${entry.name}${romInfo}${resultStr}`);
	}
	return summary;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  const args = parseArgs(process.argv.slice(2), {
		flags:   ['--keep', '--dry-run', '--list', '--force', '--use-working-tree', '--use-git-head', '--json', '--verbose', '-v', '--help', '-h'],
    options: ['--output', '-o', '--workspace', '--tracks'],
  });

  const keep    = args.flags['--keep'];
  const dryRun  = args.flags['--dry-run'];
  const list    = args.flags['--list'];
  const force   = args.flags['--force'];
	const jsonOut = args.flags['--json'];
	const useWorkingTreeAsm = args.flags['--use-git-head'] ? false : true;
  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const outputArg    = args.options['--output'] || args.options['-o'] || null;
  const workspaceArg = args.options['--workspace'] || null;
  const tracksArg = args.options['--tracks'] || null;

	if (args.flags['--help'] || args.flags['-h']) {
		printUsage(USAGE_TEXT);
		return;
	}

	if (jsonOut && !dryRun && !list) {
		die('--json is currently supported only with --dry-run or --list.');
	}

  // --list
  if (list) {
		listWorkspaces({ json: jsonOut });
    return;
  }

  // Require seed
  const seedStr = (args.positional || [])[0];
  if (!seedStr) {
		printUsage(USAGE_TEXT, { stderr: true });
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

	if (!jsonOut) {
		console.log(`Seed      : ${seedStr}`);
		console.log(`Version   : ${version}`);
		console.log(`Flags     : 0x${flags.toString(16).toUpperCase().padStart(2, '0')}`);
		if (tracksArg) console.log(`Tracks    : ${tracksArg}`);
		console.log(`Workspace : ${wsDir}`);
		console.log(`Output    : ${outputPath}`);
		console.log(`ASM base  : ${useWorkingTreeAsm ? 'working tree' : 'git HEAD'}`);
	}

  if (dryRun) {
		if (jsonOut) {
			printJson({
				tool: 'hack_workdir',
				mode: 'dry_run',
				seed: seedStr,
				version,
				flags,
				tracks: tracksArg,
				workspace: wsDir,
				output: outputPath,
				asmBase: useWorkingTreeAsm ? 'working_tree' : 'git_head',
				keep,
				force,
			});
			return;
		}
		console.log('\nDRY RUN — no files will be created or modified.');
    return;
  }

  // Create workspaces base if needed
  fs.mkdirSync(WORKSPACES, { recursive: true });
  fs.mkdirSync(ROM_OUTPUTS, { recursive: true });

	// Handle existing workspace
	let refreshExistingWorkspace = false;
	if (fs.existsSync(wsDir)) {
		if (force) {
			console.log(`\nRefreshing existing workspace: ${wsDir}`);
			refreshExistingWorkspace = true;
		} else {
			process.stderr.write(`\nERROR: Workspace already exists: ${wsDir}\n`);
			process.stderr.write('Use --force to overwrite or --list to see existing workspaces.\n');
      process.exit(1);
    }
  }

	// Create workspace
	if (!refreshExistingWorkspace) fs.mkdirSync(wsDir, { recursive: true });
	console.log('\n[1/5] Creating workspace ...');

	// Copy build files
	console.log('[2/5] Copying build files ...');
	const templateInfo = ensureWorkspaceTemplate(REPO_ROOT, verbose, { useWorkingTreeAsm });
	if (refreshExistingWorkspace) refreshWorkspaceFromTemplate(WORKSPACE_TEMPLATE_DIR, wsDir, verbose);
	else copyWorkspaceTemplate(WORKSPACE_TEMPLATE_DIR, wsDir, verbose);
	const nFiles = templateInfo.fileCount || 0;
	if (templateInfo.reused) console.log('      Reused cached workspace template.');
	else console.log(`      Built workspace template (${nFiles} files).`);
	if (refreshExistingWorkspace) console.log('      Refreshed mutable workspace inputs only.');

	let baselineInfo;
	const timing = {
		copySecs: 0,
		canonicalSecs: 0,
		randomizerSecs: 0,
		buildSecs: 0,
		minimapPatchSecs: 0,
	};
	const copyStartedAt = Date.now();
	try {
		const afterCopy = Date.now();
		timing.copySecs = (afterCopy - copyStartedAt) / 1000;
		const canonicalStartedAt = Date.now();
		baselineInfo = prepareWorkspaceCanonicalData(wsDir);
		timing.canonicalSecs = (Date.now() - canonicalStartedAt) / 1000;
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
	timing.randomizerSecs = randElapsed;

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

	const includeGeneratedMinimapData = false;
	const postRandomizerPadBytes = padGeneratedTrackBlockToBaseline(wsDir, { includeGeneratedMinimapData });
	if (postRandomizerPadBytes > 0) {
		console.log(`      Re-padded generated track block by ${postRandomizerPadBytes} byte(s) after randomization.`);
	}
	const postMinimapPadBytes = padGeneratedTrackBlockToBaseline(wsDir, { includeGeneratedMinimapData });
	if (postMinimapPadBytes > 0) {
		console.log(`      Re-padded generated track block by ${postMinimapPadBytes} byte(s) after minimap preparation.`);
	}

  // Build (verification step — randomize.js already calls build.bat internally)
  console.log('[4/5] Building ROM ...');
  const t1 = Date.now();
	const { success: buildOk, output: buildOutput } = runBuild(wsDir);
	const buildElapsed = (Date.now() - t1) / 1000;
	timing.buildSecs = buildElapsed;
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
		const minimapPatchStartedAt = Date.now();
		const { success: minimapPatchOk, output: minimapPatchOutput } = patchWorkspaceGeneratedMinimap(wsDir, verbose, {
			tracks: tracksArg,
		});
		timing.minimapPatchSecs = (Date.now() - minimapPatchStartedAt) / 1000;
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
			const sizeAfterMinimapPatch = fs.statSync(wsRom).size;
			const romEndPatch = patchWorkspaceRomHeaderEnd(wsRom);
			if (romEndPatch.changed) {
				console.log(`      ROM end header patched for expanded workspace ROM: $${romEndPatch.oldRomEnd.toString(16).toUpperCase().padStart(8, '0')} -> $${romEndPatch.newRomEnd.toString(16).toUpperCase().padStart(8, '0')}`);
			}
			const checksum = patchRomChecksum(wsRom);
			console.log(`      Header checksum ${checksum.changed ? 'patched' : 'verified'} after minimap patch: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
			console.log(`      Expanded workspace ROM size: ${sizeAfterMinimapPatch.toLocaleString()} bytes (${Math.floor(sizeAfterMinimapPatch / 1024)} KB)`);
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
	console.log(`      Timing:  copy ${timing.copySecs.toFixed(1)}s, canonical ${timing.canonicalSecs.toFixed(1)}s, randomizer ${timing.randomizerSecs.toFixed(1)}s, build ${timing.buildSecs.toFixed(1)}s, minimap ${timing.minimapPatchSecs.toFixed(1)}s`);

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
