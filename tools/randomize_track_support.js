'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const { REPO_ROOT } = require('./lib/rom');
const { validateAllTracks } = require('./minimap_validate');
const { buildGeneratedTrackBlock, GENERATED_MINIMAP_DATA_FILE } = require('./generate_track_data_asm');
const { buildAsm: buildGeneratedMinimapMapAsm } = require('./write_generated_minimap_assets');

const TOOLS_DIR = path.join(REPO_ROOT, 'tools');

function parseLstSymbolMapFromText(text) {
	const map = new Map();
	for (const line of text.split(/\r?\n/)) {
		const match = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (match) map.set(match[2], parseInt(match[1], 16));
	}
	return map;
}

function loadBaselineSymbolMap() {
	const maps = [];
	const lstPath = path.join(REPO_ROOT, 'smgp_head.lst');
	if (fs.existsSync(lstPath)) {
		maps.push(parseLstSymbolMapFromText(fs.readFileSync(lstPath, 'utf8')));
	}
	const jsonPath = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');
	if (fs.existsSync(jsonPath)) {
		const json = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
		const symbols = json && typeof json === 'object' ? json.symbols : null;
		if (symbols && typeof symbols === 'object') {
			const map = new Map();
			for (const [name, value] of Object.entries(symbols)) {
				if (typeof value !== 'string') continue;
				map.set(name, parseInt(value.replace(/^0x/i, ''), 16));
			}
			maps.push(map);
		}
	}
	if (maps.length === 0) return null;
	const merged = new Map();
	for (const map of maps) {
		for (const [name, value] of map.entries()) {
			if (!merged.has(name)) merged.set(name, value);
		}
	}
	return merged;
}

function getBaselineTrackBlockLayout() {
	const symbolMap = loadBaselineSymbolMap();
	if (!symbolMap) return null;
	const start = symbolMap.get('San_Marino_curve_data');
	const blob = symbolMap.get('Monaco_arcade_post_sign_tileset_blob');
	if (start === undefined || blob === undefined || blob < start) return null;
	const blobPath = path.join(REPO_ROOT, 'data', 'tracks', 'monaco_arcade', 'post_sign_tileset_blob.bin');
	if (!fs.existsSync(blobPath)) return null;
	return {
		blobRelative: blob - start,
		fullSize: (blob - start) + fs.statSync(blobPath).size,
	};
}

function measureGeneratedTrackBlockLayout() {
	const generatedPath = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
	if (!fs.existsSync(generatedPath)) return null;
	const text = fs.readFileSync(generatedPath, 'utf8');
	let total = 0;
	let blobStart = null;
	for (const line of text.split(/\r?\n/)) {
		if (/^\s*Monaco_arcade_post_sign_tileset_blob:/i.test(line)) {
			blobStart = total;
			continue;
		}
		const incbin = line.match(/^\s*incbin\s+\"([^\"]+)\"/i);
		if (incbin) {
			const binPath = path.join(REPO_ROOT, incbin[1]);
			if (fs.existsSync(binPath)) total += fs.statSync(binPath).size;
			continue;
		}
		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) total += parseInt(dcb[1], 10);
	}
	return { blobStart, fullSize: total };
}

function writeGeneratedTrackBlockPreservingBaseline(options = {}) {
	const includeGeneratedMinimapData = options.includeGeneratedMinimapData !== false;
	const generatedTrackAsm = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
	const baseline = getBaselineTrackBlockLayout();
	fs.writeFileSync(generatedTrackAsm, buildGeneratedTrackBlock({ includeGeneratedMinimapData }), 'utf8');
	if (!baseline) return { padBytes: 0, preBlobPadBytes: 0 };
	const current = measureGeneratedTrackBlockLayout();
	if (!current) return { padBytes: 0, preBlobPadBytes: 0 };
	const preBlobPadBytes = current.blobStart === null ? 0 : Math.max(0, baseline.blobRelative - current.blobStart);
	const padBytes = Math.max(0, baseline.fullSize - current.fullSize - preBlobPadBytes);
	if (preBlobPadBytes > 0 || padBytes > 0) {
		fs.writeFileSync(generatedTrackAsm, buildGeneratedTrackBlock({ preBlobPadBytes, padBytes, includeGeneratedMinimapData }), 'utf8');
	}
	return { padBytes, preBlobPadBytes };
}

function writeGeneratedMinimapAssetsFile(tracks) {
	const outputPath = path.join(REPO_ROOT, GENERATED_MINIMAP_DATA_FILE);
	fs.mkdirSync(path.dirname(outputPath), { recursive: true });
	fs.writeFileSync(outputPath, buildGeneratedMinimapMapAsm(tracks), 'utf8');
	return outputPath;
}

function runNodeTool(scriptName, args) {
	let stdout = '';
	let stderr = '';
	let exitCode = 0;
	const scriptPath = path.join(TOOLS_DIR, scriptName);
	try {
		stdout = execFileSync(process.execPath, [scriptPath, ...args], {
			cwd: REPO_ROOT,
			encoding: 'utf8',
			stdio: ['ignore', 'pipe', 'pipe'],
		});
	} catch (err) {
		stdout = err.stdout || '';
		stderr = err.stderr || '';
		exitCode = err.status || 1;
	}
	return {
		ok: exitCode === 0,
		output: stdout + stderr,
		exitCode,
	};
}

function patchGeneratedMinimapRom(romPath, inputPath, options = {}) {
	const allowRootMutation = options.allowRootMutation === true;
	const steps = [
		{
			label: 'tiles',
			script: 'patch_all_track_minimap_assets_rom.js',
			args: ['--rom', romPath, '--input', inputPath],
		},
		{
			label: 'raw maps',
			script: 'patch_all_track_minimap_raw_maps_rom.js',
			args: ['--rom', romPath, '--input', inputPath],
		},
		{
			label: 'marker path',
			script: 'patch_generated_minimap_pos_rom.js',
			args: ['--all', '--rom', romPath, '--input', inputPath],
		},
	];
	if (allowRootMutation) {
		for (const step of steps) step.args.push('--allow-root-mutation');
	}

	const results = [];
	for (const step of steps) {
		const result = runNodeTool(step.script, step.args);
		results.push({ ...step, ...result });
		if (!result.ok) {
			return {
				ok: false,
				steps: results,
			};
		}
	}

	return {
		ok: true,
		steps: results,
	};
}

function validateGeneratedMinimaps(selectedTracks) {
	const report = validateAllTracks({ tracks: selectedTracks });
	const failures = [];
	for (const entry of report.tracks) {
		if (entry.flags.candidate_marker_offroad) {
			failures.push(`[${entry.track.slug}] candidate marker alignment failed (${entry.metrics.candidate_marker_mean_distance}, ${entry.metrics.candidate_marker_hit_percent}%)`);
		}
	}
	return { report, failures };
}

module.exports = {
	parseLstSymbolMapFromText,
	loadBaselineSymbolMap,
	getBaselineTrackBlockLayout,
	measureGeneratedTrackBlockLayout,
	writeGeneratedTrackBlockPreservingBaseline,
	writeGeneratedMinimapAssetsFile,
	patchGeneratedMinimapRom,
	validateGeneratedMinimaps,
};
