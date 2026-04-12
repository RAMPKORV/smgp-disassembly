#!/usr/bin/env node
'use strict';

const assert = require('assert');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const { REPO_ROOT } = require('../lib/rom');
const {
	assertSafeRomPath,
	assertWorkspaceContainsTarget,
	assertWorkspacePath,
	isWithinPath,
	pathsEqual,
} = require('../lib/workspace_guard');

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

function runNode(args) {
	return spawnSync('node', args, {
		cwd: REPO_ROOT,
		encoding: 'utf8',
		timeout: 120000,
	});
}

console.log('Section A: workspace guard helpers');

test('pathsEqual treats identical paths as equal', () => {
	assert.strictEqual(pathsEqual(REPO_ROOT, path.resolve(REPO_ROOT)), true);
});

test('isWithinPath accepts nested workspace targets', () => {
	const workspace = path.join(REPO_ROOT, 'build', 'workspaces', 'guard-test');
	const target = path.join(workspace, 'out.bin');
	assert.strictEqual(isWithinPath(workspace, target), true);
});

test('assertWorkspacePath rejects repo root by default', () => {
	assert.throws(() => assertWorkspacePath(REPO_ROOT), /refusing to mutate root tree/);
});

test('assertSafeRomPath rejects repo-root out.bin by default', () => {
	assert.throws(() => assertSafeRomPath(path.join(REPO_ROOT, 'out.bin')), /refusing to patch repo-root out\.bin/);
});

test('assertWorkspaceContainsTarget rejects paths outside workspace', () => {
	const workspace = path.join(os.tmpdir(), 'smgp-guard-workspace');
	assert.throws(
		() => assertWorkspaceContainsTarget(workspace, path.join(REPO_ROOT, 'out.bin'), 'workspace rom'),
		/workspace rom must stay inside the selected workspace/
	);
});

console.log('Section B: CLI guardrails');

test('workspace patch tool rejects repo root workspace without override', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'workspace_patch_generated_minimap_rom.js'),
		'--workspace', REPO_ROOT,
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('refusing to mutate root tree'), `stderr:\n${result.stderr}`);
});

test('workspace apply tool rejects repo root workspace without override', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'workspace_apply_generated_minimap.js'),
		'--workspace', REPO_ROOT,
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('refusing to mutate root tree'), `stderr:\n${result.stderr}`);
});

test('asset patch tool rejects repo-root out.bin without override', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'patch_all_track_minimap_assets_rom.js'),
		'--rom', path.join(REPO_ROOT, 'out.bin'),
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('refusing to patch repo-root out.bin'), `stderr:\n${result.stderr}`);
});

test('raw-map patch tool rejects repo-root out.bin without override', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'patch_all_track_minimap_raw_maps_rom.js'),
		'--rom', path.join(REPO_ROOT, 'out.bin'),
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('refusing to patch repo-root out.bin'), `stderr:\n${result.stderr}`);
});

test('marker-path patch tool rejects repo-root out.bin without override', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'patch_generated_minimap_pos_rom.js'),
		'--rom', path.join(REPO_ROOT, 'out.bin'),
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('refusing to patch repo-root out.bin'), `stderr:\n${result.stderr}`);
});

test('legacy HUD patch tool rejects repo-root out.bin without override', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'patch_generated_minimap_rom.js'),
		'--rom', path.join(REPO_ROOT, 'out.bin'),
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('refusing to patch repo-root out.bin'), `stderr:\n${result.stderr}`);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
