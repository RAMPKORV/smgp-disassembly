'use strict';

const fs = require('fs');
const path = require('path');

const { runCanonicalBuild } = require('./lib/canonical_build');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { patchGeneratedMinimapRom } = require('./randomize_track_support');

function buildSucceededFromResult(status, output) {
	if (status !== 0) return false;
	return String(output || '').includes('0 error(s)');
}

function runBuild(workDir) {
	const result = runCanonicalBuild(workDir);
	const output = result.output;
	return {
		success: buildSucceededFromResult(result.status, output),
		output,
	};
}

function logOutput(output, prefix = '  ') {
	for (const line of String(output || '').split('\n')) {
		if (line.trim()) console.log(`${prefix}${line}`);
	}
}

function patchChecksumAndMeasureRom(romPath) {
	if (!fs.existsSync(romPath)) return null;
	const checksum = patchRomChecksum(romPath);
	const size = fs.statSync(romPath).size;
	return { checksum, size };
}

function runRootBuildFlow(options) {
	const {
		rootDir,
		trackFlagsEnabled,
		inputPath,
		allowRootMutation = false,
	} = options;

	console.log('\n[BUILD] Running build.bat ...');
	const buildResult = runBuild(rootDir);
	logOutput(buildResult.output, '  ');
	if (!buildResult.success) {
		return {
			ok: false,
			stage: 'build',
			output: buildResult.output,
		};
	}

	console.log('Build succeeded - out.bin ready.');
	const romPath = path.join(rootDir, 'out.bin');
	const romInfo = patchChecksumAndMeasureRom(romPath);
	if (!romInfo) {
		return {
			ok: true,
			output: buildResult.output,
			romPath,
			romInfo: null,
			minimapPatch: null,
		};
	}

	console.log(`  Header checksum ${romInfo.checksum.changed ? 'patched' : 'verified'}: $${romInfo.checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${romInfo.checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);

	let minimapPatch = null;
	if (trackFlagsEnabled) {
		console.log('\n[MINIMAP] Applying generated minimap ROM patches ...');
		console.log('  NOTE: Generated minimap assets are now appended/relocated for randomized ROM builds; ROM size may grow beyond 512 KiB.');
		minimapPatch = patchGeneratedMinimapRom(romPath, inputPath, { allowRootMutation });
		for (const step of minimapPatch.steps) {
			console.log(`  ${step.label}: ${step.ok ? 'OK' : 'FAILED'}`);
			logOutput(step.output, '    ');
		}
		if (!minimapPatch.ok) {
			return {
				ok: false,
				stage: 'minimap',
				output: buildResult.output,
				romPath,
				romInfo,
				minimapPatch,
			};
		}
		romInfo.size = fs.statSync(romPath).size;
	}

	console.log(`  ROM size: ${romInfo.size.toLocaleString()} bytes (${Math.floor(romInfo.size / 1024)} KB)`);
	return {
		ok: true,
		output: buildResult.output,
		romPath,
		romInfo,
		minimapPatch,
	};
}

module.exports = {
	buildSucceededFromResult,
	runBuild,
	logOutput,
	patchChecksumAndMeasureRom,
	runRootBuildFlow,
};
