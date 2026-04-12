#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const {
	assertNoActiveCheckpointArtifacts,
	clearCheckpoint,
	createCheckpointSession,
	listLegacyBackupFiles,
	readCheckpointManifest,
	restoreCheckpoint,
} = require('../lib/in_root_checkpoint');

const { REPO_ROOT } = require('../lib/rom');

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed++;
	} catch (err) {
		failed++;
		console.error(`FAIL: ${name}`);
		console.error(`  ${err.message}`);
	}
}

function runNode(args, options = {}) {
	return spawnSync('node', args, {
		cwd: options.cwd || REPO_ROOT,
		encoding: 'utf8',
		timeout: 120000,
	});
}

console.log('Section A: checkpoint helper lifecycle');

const tmpRepo = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-checkpoint-'));
fs.mkdirSync(path.join(tmpRepo, 'tools', 'data'), { recursive: true });
fs.mkdirSync(path.join(tmpRepo, 'src'), { recursive: true });
const tracksPath = path.join(tmpRepo, 'tools', 'data', 'tracks.json');
fs.writeFileSync(tracksPath, '{"tracks":[]}', 'utf8');
clearCheckpoint(tmpRepo);

test('checkpointFile writes manifest and snapshot copy', () => {
	const session = createCheckpointSession({ repoRoot: tmpRepo, metadata: { seed: 'TEST' } });
	const entry = session.checkpointFile(tracksPath, 'tracks json');
	const manifest = readCheckpointManifest(tmpRepo);
	assert.strictEqual(entry.relativePath, path.join('tools', 'data', 'tracks.json'));
	assert.ok(manifest, 'manifest should exist');
	assert.strictEqual(manifest.files.length, 1);
	const backupPath = path.join(tmpRepo, manifest.files[0].backupRelativePath);
	assert.strictEqual(fs.readFileSync(backupPath, 'utf8'), '{"tracks":[]}');
	clearCheckpoint(tmpRepo);
});

test('restoreCheckpoint restores original contents and clears checkpoint', () => {
	const session = createCheckpointSession({ repoRoot: tmpRepo, metadata: { seed: 'TEST2' } });
	session.checkpointFile(tracksPath, 'tracks json');
	fs.writeFileSync(tracksPath, '{"tracks":[1]}', 'utf8');
	const restored = restoreCheckpoint({ repoRoot: tmpRepo, cleanup: true });
	assert.ok(restored.restoredFiles.includes(path.join('tools', 'data', 'tracks.json')));
	assert.strictEqual(fs.readFileSync(tracksPath, 'utf8'), '{"tracks":[]}');
	assert.strictEqual(readCheckpointManifest(tmpRepo), null);
});

test('assertNoActiveCheckpointArtifacts rejects active checkpoint manifest', () => {
	createCheckpointSession({ repoRoot: tmpRepo, metadata: { seed: 'TEST3' } });
	assert.throws(() => assertNoActiveCheckpointArtifacts(tmpRepo), /already active/);
	clearCheckpoint(tmpRepo);
});

test('listLegacyBackupFiles reports known legacy backup names', () => {
	const legacyPath = path.join(tmpRepo, 'tools', 'data', 'tracks.orig.json');
	fs.writeFileSync(legacyPath, '{}', 'utf8');
	const legacy = listLegacyBackupFiles(tmpRepo);
	assert.ok(legacy.includes(legacyPath));
	fs.rmSync(legacyPath, { force: true });
});

console.log('Section B: restore CLI checkpoint summary');

test('restore_tracks --json reports no checkpoint in clean repo state', () => {
	const result = runNode([path.join(REPO_ROOT, 'tools', 'restore_tracks.js'), '--json']);
	assert.strictEqual(result.status, 0, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	const summary = JSON.parse(result.stdout || '{}');
	assert.strictEqual(summary.tool, 'restore_tracks');
	assert.ok(summary.checkpointManifest === 'missing' || summary.checkpointManifest === 'present');
	assert.ok(Array.isArray(summary.checkpointRestoredFiles), 'checkpointRestoredFiles should be an array');
	assert.ok(Array.isArray(summary.legacyBackupFiles), 'legacyBackupFiles should be an array');
	assert.strictEqual(summary.ok, true);
	assert.strictEqual(result.stderr || '', '');
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
