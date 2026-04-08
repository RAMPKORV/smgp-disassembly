#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');

function ensureFile(filePath, label) {
	if (!fs.existsSync(filePath)) die(`${label} not found: ${filePath}`);
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--all'],
		options: ['--workspace', '--track', '--source-json'],
	});

	const workspaceArg = args.options['--workspace'];
	if (!workspaceArg) die('missing required option: --workspace');
	const workspacePath = path.resolve(workspaceArg);
	const sourceJson = path.resolve(args.options['--source-json'] || path.join(process.cwd(), 'tools', 'data', 'tracks.json'));

	ensureFile(workspacePath, 'workspace');
	ensureFile(sourceJson, 'source tracks json');

	const targetJson = path.join(workspacePath, 'tools', 'data', 'tracks.json');
	ensureFile(targetJson, 'workspace tracks json');
	const sourceToolPath = path.join(process.cwd(), 'tools', 'write_generated_minimap_pos.js');
	ensureFile(sourceToolPath, 'source generator tool');
	const workspaceGeneratorPath = path.join(workspacePath, 'tools', 'write_generated_minimap_pos.js');
	if (!fs.existsSync(workspaceGeneratorPath)) {
		fs.copyFileSync(sourceToolPath, workspaceGeneratorPath);
		info(`Copied ${path.relative(process.cwd(), sourceToolPath)} -> ${path.relative(process.cwd(), workspaceGeneratorPath)}`);
	}

	fs.copyFileSync(sourceJson, targetJson);
	info(`Copied ${path.relative(process.cwd(), sourceJson)} -> ${path.relative(process.cwd(), targetJson)}`);

	const { execFileSync } = require('child_process');
	if (args.flags['--all']) {
		const tracksData = JSON.parse(fs.readFileSync(sourceJson, 'utf8'));
		for (const track of tracksData.tracks || []) {
			const targetBin = path.join(workspacePath, 'data', 'tracks', track.slug, 'minimap_pos.bin');
			execFileSync('node', [
				sourceToolPath,
				'--track', track.slug,
				'--input', sourceJson,
				'--bin-out', targetBin,
			], {
				cwd: process.cwd(),
				stdio: 'inherit',
			});
		}
		info('Updated workspace minimap data for all tracks');
		return;
	}

	const trackSlug = args.options['--track'] || 'san_marino';
	const targetBin = path.join(workspacePath, 'data', 'tracks', trackSlug, 'minimap_pos.bin');
	execFileSync('node', [
		sourceToolPath,
		'--track', trackSlug,
		'--input', sourceJson,
		'--bin-out', targetBin,
	], {
		cwd: process.cwd(),
		stdio: 'inherit',
	});

	info(`Updated workspace minimap data for ${trackSlug}`);
}

main();
