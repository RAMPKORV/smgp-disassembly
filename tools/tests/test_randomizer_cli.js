#!/usr/bin/env node
'use strict';

const assert = require('assert');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

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

function runNode(args) {
	return spawnSync('node', args, {
		cwd: REPO_ROOT,
		encoding: 'utf8',
		timeout: 120000,
	});
}

function parseJsonStdout(result) {
	assert.strictEqual(result.status, 0, `exit code ${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	return JSON.parse(result.stdout || '{}');
}

console.log('Section A: help output');

test('randomize.js --help exits 0 and prints usage', () => {
	const result = runNode([path.join(REPO_ROOT, 'tools', 'randomize.js'), '--help']);
	assert.strictEqual(result.status, 0, `stderr: ${result.stderr}`);
	assert.ok((result.stdout || '').includes('Usage: node tools/randomize.js'), `stdout:\n${result.stdout}`);
	assert.ok((result.stdout || '').includes('--json'), `stdout:\n${result.stdout}`);
});

test('hack_workdir.js --help exits 0 and prints usage', () => {
	const result = runNode([path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), '--help']);
	assert.strictEqual(result.status, 0, `stderr: ${result.stderr}`);
	assert.ok((result.stdout || '').includes('Usage: node tools/hack_workdir.js'), `stdout:\n${result.stdout}`);
	assert.ok((result.stdout || '').includes('--dry-run'), `stdout:\n${result.stdout}`);
});

test('restore_tracks.js --help exits 0 and prints usage', () => {
	const result = runNode([path.join(REPO_ROOT, 'tools', 'restore_tracks.js'), '--help']);
	assert.strictEqual(result.status, 0, `stderr: ${result.stderr}`);
	assert.ok((result.stdout || '').includes('Usage: node tools/restore_tracks.js'), `stdout:\n${result.stdout}`);
	assert.ok((result.stdout || '').includes('--verify'), `stdout:\n${result.stdout}`);
});

console.log('Section B: machine-readable dry-run/list output');

test('hack_workdir.js --dry-run --json outputs parseable summary', () => {
	const outputPath = path.join(os.tmpdir(), 'smgp-cli-dryrun.bin');
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'hack_workdir.js'),
		'SMGP-1-01-12345',
		'--dry-run',
		'--json',
		'--output', outputPath,
	]);
	const json = parseJsonStdout(result);
	assert.strictEqual(json.tool, 'hack_workdir');
	assert.strictEqual(json.mode, 'dry_run');
	assert.strictEqual(json.seed, 'SMGP-1-01-12345');
	assert.strictEqual(json.output, outputPath);
	assert.ok(typeof json.workspace === 'string' && json.workspace.length > 0, 'missing workspace path');
	assert.strictEqual(result.stderr || '', '');
});

test('randomize.js --dry-run --json forwards workspace-safe JSON output', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'randomize.js'),
		'SMGP-1-01-12345',
		'--dry-run',
		'--json',
	]);
	const json = parseJsonStdout(result);
	assert.strictEqual(json.tool, 'hack_workdir');
	assert.strictEqual(json.mode, 'dry_run');
	assert.strictEqual(json.seed, 'SMGP-1-01-12345');
	assert.ok(String(json.output || '').includes('latest_randomized.bin'), `unexpected output path: ${json.output}`);
	assert.strictEqual(result.stderr || '', '');
});

test('hack_workdir.js --list --json outputs workspace inventory object', () => {
	const result = runNode([path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), '--list', '--json']);
	const json = parseJsonStdout(result);
	assert.strictEqual(json.tool, 'hack_workdir');
	assert.ok(Array.isArray(json.workspaces), 'workspaces should be an array');
	assert.ok(typeof json.workspacesDir === 'string' && json.workspacesDir.length > 0, 'missing workspacesDir');
	assert.strictEqual(result.stderr || '', '');
});

console.log('Section C: JSON guardrails');

test('randomize.js rejects --json with --in-root mode', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'randomize.js'),
		'SMGP-1-01-12345',
		'--in-root',
		'--dry-run',
		'--json',
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('--json is only supported for workspace-safe default mode'), `stderr:\n${result.stderr}`);
});

test('randomize.js rejects --json without --dry-run', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'randomize.js'),
		'SMGP-1-01-12345',
		'--json',
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('--json currently requires --dry-run'), `stderr:\n${result.stderr}`);
});

test('hack_workdir.js rejects --json without --dry-run or --list', () => {
	const result = runNode([
		path.join(REPO_ROOT, 'tools', 'hack_workdir.js'),
		'SMGP-1-01-12345',
		'--json',
	]);
	assert.strictEqual(result.status, 1, `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
	assert.ok((result.stderr || '').includes('--json is currently supported only with --dry-run or --list'), `stderr:\n${result.stderr}`);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
