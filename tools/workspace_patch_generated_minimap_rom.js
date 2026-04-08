#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const { parseArgs, die, info } = require('./lib/cli');

function ensureFile(filePath, label) {
	if (!fs.existsSync(filePath)) die(`${label} not found: ${filePath}`);
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--all'],
		options: ['--workspace', '--rom', '--lst', '--runtime-asm'],
	});

	const workspaceArg = args.options['--workspace'];
	if (!workspaceArg) die('missing required option: --workspace');
	const workspacePath = path.resolve(workspaceArg);
	ensureFile(workspacePath, 'workspace');

	const romPath = path.resolve(args.options['--rom'] || path.join(workspacePath, 'out.bin'));
	const workspaceTracksJson = path.join(workspacePath, 'tools', 'data', 'tracks.json');
	ensureFile(romPath, 'workspace rom');
	ensureFile(workspaceTracksJson, 'workspace tracks json');

	const runtimeGenTool = path.join(process.cwd(), 'tools', 'generate_minimap_preview_runtime.js');
	const posTool = path.join(process.cwd(), 'tools', 'patch_generated_minimap_pos_rom.js');
	const allTrackTool = path.join(process.cwd(), 'tools', 'patch_all_track_minimap_assets_rom.js');
	const rawMapTool = path.join(process.cwd(), 'tools', 'patch_all_track_minimap_raw_maps_rom.js');
	ensureFile(runtimeGenTool, 'source preview runtime generator');
	ensureFile(posTool, 'source minimap_pos patch tool');
	ensureFile(allTrackTool, 'source all-track minimap patch tool');
	ensureFile(rawMapTool, 'source all-track raw minimap map patch tool');

	execFileSync('node', [allTrackTool, '--rom', romPath, '--input', workspaceTracksJson], {
		cwd: process.cwd(),
		stdio: 'inherit',
	});
	execFileSync('node', [rawMapTool, '--rom', romPath, '--input', workspaceTracksJson], {
		cwd: process.cwd(),
		stdio: 'inherit',
	});
	execFileSync('node', [posTool, '--all', '--rom', romPath, '--input', workspaceTracksJson], {
		cwd: process.cwd(),
		stdio: 'inherit',
	});

	info(`Patched generated minimap tiles + raw maps + minimap_pos into ${path.relative(process.cwd(), romPath)}`);
}

main();
