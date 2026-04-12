'use strict';

const fs = require('fs');
const path = require('path');
const { createCheckpointSession } = require('./lib/in_root_checkpoint');

function backupOnce(srcPath, backupPath, label, options = {}) {
	const checkpointSession = options.checkpointSession || null;
	if (checkpointSession) {
		const entry = checkpointSession.checkpointFile(srcPath, label);
		console.log(`Checkpointed ${label}: ${entry.relativePath}`);
		return entry;
	}
	if (!fs.existsSync(backupPath)) {
		fs.copyFileSync(srcPath, backupPath);
		console.log(`Backed up ${label}: ${path.basename(backupPath)}`);
	}
	return null;
}

function writeJsonFile(filePath, data) {
	fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
	console.log(`Written: ${path.basename(filePath)}`);
}

function patchRomIfPresent(romPath, label, patcher) {
	if (!fs.existsSync(romPath)) {
		console.log(`  NOTE: ${path.basename(romPath)} not found - build first, then re-run inject.`);
		return null;
	}
	console.log(`  Patching ${path.basename(romPath)} ...`);
	const changed = patcher();
	console.log(`  ${changed} byte(s) changed in ROM.`);
	return changed;
}

function createInRootCheckpointSession(options = {}) {
	const { repoRoot, ...metadata } = options;
	return createCheckpointSession({ repoRoot, metadata });
}

module.exports = {
	backupOnce,
	writeJsonFile,
	patchRomIfPresent,
	createInRootCheckpointSession,
};
