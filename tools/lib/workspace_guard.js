'use strict';

const path = require('path');

const { REPO_ROOT } = require('./rom');

function normalizePath(filePath) {
	const resolved = path.resolve(filePath);
	return process.platform === 'win32' ? resolved.toLowerCase() : resolved;
}

function pathsEqual(aPath, bPath) {
	return normalizePath(aPath) === normalizePath(bPath);
}

function isWithinPath(parentPath, childPath) {
	const relative = path.relative(path.resolve(parentPath), path.resolve(childPath));
	return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function assertWorkspacePath(workspacePath, options = {}) {
	if (!options.allowRootMutation && pathsEqual(workspacePath, REPO_ROOT)) {
		throw new Error('workspace path resolves to the repo root; refusing to mutate root tree without --allow-root-mutation');
	}
}

function assertWorkspaceContainsTarget(workspacePath, targetPath, label, options = {}) {
	assertWorkspacePath(workspacePath, options);
	if (!isWithinPath(workspacePath, targetPath)) {
		throw new Error(`${label} must stay inside the selected workspace: ${targetPath}`);
	}
}

function assertSafeRomPath(romPath, options = {}) {
	const rootRomPath = path.join(REPO_ROOT, 'out.bin');
	if (!options.allowRootMutation && pathsEqual(romPath, rootRomPath)) {
		throw new Error('refusing to patch repo-root out.bin without --allow-root-mutation');
	}
}

module.exports = {
	normalizePath,
	pathsEqual,
	isWithinPath,
	assertWorkspacePath,
	assertWorkspaceContainsTarget,
	assertSafeRomPath,
};
