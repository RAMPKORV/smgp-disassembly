'use strict';

const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('./rom');

const CHECKPOINT_RELATIVE_DIR = path.join('build', 'checkpoints', 'in_root_debug');

function isWithinPath(parentPath, childPath) {
	const relative = path.relative(path.resolve(parentPath), path.resolve(childPath));
	return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function getCheckpointPaths(repoRoot = REPO_ROOT) {
	const checkpointDir = path.join(repoRoot, CHECKPOINT_RELATIVE_DIR);
	return {
		repoRoot,
		checkpointDir,
		manifestPath: path.join(checkpointDir, 'manifest.json'),
		filesDir: path.join(checkpointDir, 'files'),
	};
}

function readCheckpointManifest(repoRoot = REPO_ROOT) {
	const paths = getCheckpointPaths(repoRoot);
	if (!fs.existsSync(paths.manifestPath)) return null;
	return JSON.parse(fs.readFileSync(paths.manifestPath, 'utf8'));
}

function writeCheckpointManifest(manifest, repoRoot = REPO_ROOT) {
	const paths = getCheckpointPaths(repoRoot);
	fs.mkdirSync(paths.checkpointDir, { recursive: true });
	fs.writeFileSync(paths.manifestPath, JSON.stringify(manifest, null, 2), 'utf8');
	return paths.manifestPath;
}

function startCheckpoint(metadata = {}, repoRoot = REPO_ROOT) {
	const existing = readCheckpointManifest(repoRoot);
	if (existing) return existing;
	const manifest = {
		tool: 'randomize',
		mode: 'in_root_debug',
		createdAt: new Date().toISOString(),
		metadata,
		files: [],
	};
	writeCheckpointManifest(manifest, repoRoot);
	return manifest;
}

function checkpointFile(srcPath, label, options = {}) {
	const repoRoot = options.repoRoot || REPO_ROOT;
	const absoluteSrcPath = path.resolve(srcPath);
	if (!isWithinPath(repoRoot, absoluteSrcPath)) {
		throw new Error(`checkpoint target must stay inside repo root: ${absoluteSrcPath}`);
	}
	if (!fs.existsSync(absoluteSrcPath)) {
		throw new Error(`checkpoint source not found: ${absoluteSrcPath}`);
	}
	const relativePath = path.relative(repoRoot, absoluteSrcPath);
	const paths = getCheckpointPaths(repoRoot);
	const manifest = startCheckpoint(options.metadata || {}, repoRoot);
	const existing = manifest.files.find(entry => entry.relativePath === relativePath);
	if (existing) return existing;

	const backupPath = path.join(paths.filesDir, relativePath);
	fs.mkdirSync(path.dirname(backupPath), { recursive: true });
	fs.copyFileSync(absoluteSrcPath, backupPath);

	const entry = {
		relativePath,
		backupRelativePath: path.relative(repoRoot, backupPath),
		label,
		createdAt: new Date().toISOString(),
	};
	manifest.files.push(entry);
	writeCheckpointManifest(manifest, repoRoot);
	return entry;
}

function restoreCheckpoint(options = {}) {
	const repoRoot = options.repoRoot || REPO_ROOT;
	const cleanup = options.cleanup !== false;
	const manifest = readCheckpointManifest(repoRoot);
	if (!manifest) {
		return {
			manifest: null,
			restoredFiles: [],
			checkpointDir: getCheckpointPaths(repoRoot).checkpointDir,
		};
	}

	const restoredFiles = [];
	for (const entry of manifest.files || []) {
		const targetPath = path.join(repoRoot, entry.relativePath);
		const backupPath = path.join(repoRoot, entry.backupRelativePath);
		if (!fs.existsSync(backupPath)) {
			throw new Error(`checkpoint backup missing for ${entry.relativePath}: ${backupPath}`);
		}
		fs.mkdirSync(path.dirname(targetPath), { recursive: true });
		fs.copyFileSync(backupPath, targetPath);
		restoredFiles.push(entry.relativePath);
	}

	if (cleanup) clearCheckpoint(repoRoot);
	return {
		manifest,
		restoredFiles,
		checkpointDir: getCheckpointPaths(repoRoot).checkpointDir,
	};
}

function clearCheckpoint(repoRoot = REPO_ROOT) {
	const paths = getCheckpointPaths(repoRoot);
	fs.rmSync(paths.checkpointDir, { recursive: true, force: true });
	return paths.checkpointDir;
}

function listLegacyBackupFiles(repoRoot = REPO_ROOT) {
	const candidates = [
		path.join(repoRoot, 'tools', 'data', 'tracks.orig.json'),
		path.join(repoRoot, 'tools', 'data', 'teams.orig.json'),
		path.join(repoRoot, 'tools', 'data', 'championship.orig.json'),
		path.join(repoRoot, 'src', 'track_config_data.orig.asm'),
	];
	return candidates.filter(filePath => fs.existsSync(filePath));
}

function assertNoActiveCheckpointArtifacts(repoRoot = REPO_ROOT) {
	const manifest = readCheckpointManifest(repoRoot);
	if (manifest) {
		const paths = getCheckpointPaths(repoRoot);
		throw new Error(
			`an in-root debug checkpoint is already active: ${paths.manifestPath}\n` +
			'Run node tools/restore_tracks.js before starting another --in-root session.'
		);
	}
	const legacyBackups = listLegacyBackupFiles(repoRoot);
	if (legacyBackups.length > 0) {
		throw new Error(
			'legacy in-root backup files are still present:\n' +
			legacyBackups.map(filePath => `  ${filePath}`).join('\n') + '\n' +
			'Run node tools/restore_tracks.js before starting another --in-root session.'
		);
	}
}

function createCheckpointSession(options = {}) {
	const repoRoot = options.repoRoot || REPO_ROOT;
	const metadata = options.metadata || {};
	const manifest = startCheckpoint(metadata, repoRoot);
	return {
		repoRoot,
		manifestPath: getCheckpointPaths(repoRoot).manifestPath,
		manifest,
		checkpointFile(srcPath, label) {
			return checkpointFile(srcPath, label, { repoRoot, metadata });
		},
	};
}

module.exports = {
	CHECKPOINT_RELATIVE_DIR,
	getCheckpointPaths,
	readCheckpointManifest,
	writeCheckpointManifest,
	startCheckpoint,
	checkpointFile,
	restoreCheckpoint,
	clearCheckpoint,
	listLegacyBackupFiles,
	assertNoActiveCheckpointArtifacts,
	createCheckpointSession,
	isWithinPath,
};
