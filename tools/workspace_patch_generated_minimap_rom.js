#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const { parseArgs, die, info } = require('./lib/cli');
const { loadTracksData } = require('./lib/minimap_analysis');

function runNodeTool(toolPath, args) {
	execFileSync('node', [toolPath, ...args], {
		cwd: process.cwd(),
		stdio: 'inherit',
	});
}

function ensureFile(filePath, label) {
	if (!fs.existsSync(filePath)) die(`${label} not found: ${filePath}`);
}

function buildSelectedTracksInput(sourceJsonPath, trackArg) {
	if (!trackArg) return sourceJsonPath;
	const wanted = new Set(String(trackArg).split(',').map(value => value.trim()).filter(Boolean));
	if (wanted.size === 0) return sourceJsonPath;
	const tracksData = loadTracksData(sourceJsonPath);
	const selected = (tracksData.tracks || []).filter(track => wanted.has(track.slug));
	if (selected.length === 0) die(`no tracks matched --track=${trackArg}`);
	const tempPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-minimap-workspace-')), 'tracks.json');
	fs.writeFileSync(tempPath, JSON.stringify({ ...tracksData, tracks: selected }, null, 2));
	return tempPath;
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--all'],
		options: ['--workspace', '--rom', '--lst', '--runtime-asm', '--track'],
	});

	const workspaceArg = args.options['--workspace'];
	if (!workspaceArg) die('missing required option: --workspace');
	const workspacePath = path.resolve(workspaceArg);
	ensureFile(workspacePath, 'workspace');

	const romPath = path.resolve(args.options['--rom'] || path.join(workspacePath, 'out.bin'));
	const workspaceTracksJson = path.join(workspacePath, 'tools', 'data', 'tracks.json');
	ensureFile(romPath, 'workspace rom');
	ensureFile(workspaceTracksJson, 'workspace tracks json');
	const selectedInputJson = buildSelectedTracksInput(workspaceTracksJson, args.options['--track']);

	const tilesTool = path.join(process.cwd(), 'tools', 'patch_all_track_minimap_assets_rom.js');
	const rawMapTool = path.join(process.cwd(), 'tools', 'patch_all_track_minimap_raw_maps_rom.js');
	const minimapPosTool = path.join(process.cwd(), 'tools', 'patch_generated_minimap_pos_rom.js');
	ensureFile(tilesTool, 'source minimap asset patch tool');
	ensureFile(rawMapTool, 'source minimap raw-map patch tool');
	ensureFile(minimapPosTool, 'source minimap_pos patch tool');

	runNodeTool(tilesTool, [
		'--rom', romPath,
		'--input', selectedInputJson,
	]);

	runNodeTool(rawMapTool, [
		'--rom', romPath,
		'--input', selectedInputJson,
	]);

	const minimapPosArgs = ['--rom', romPath, '--input', selectedInputJson];
	if (args.options['--track']) minimapPosArgs.push('--track', String(args.options['--track']).split(',')[0].trim());
	else minimapPosArgs.push('--all');
	runNodeTool(minimapPosTool, minimapPosArgs);

	const tracksData = JSON.parse(fs.readFileSync(workspaceTracksJson, 'utf8'));
	const selectedTracksData = JSON.parse(fs.readFileSync(selectedInputJson, 'utf8'));
	const randomizedCount = Array.isArray(tracksData.tracks)
		? tracksData.tracks.filter(track => track && track._runtime_safe_randomized === true).length
		: 0;
	const patchedTrackCount = Array.isArray(selectedTracksData.tracks) ? selectedTracksData.tracks.length : 0;
	const romSize = fs.statSync(romPath).size;

	info(`Patched generated minimap assets into ${path.relative(process.cwd(), romPath)}`);
	info(`Tracks patched: ${patchedTrackCount}`);
	info(`Randomized tracks with generated minimap maps: ${randomizedCount}`);
	info(`Workspace ROM size after patch: ${romSize} bytes`);
}

main();
