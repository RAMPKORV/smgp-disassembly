#!/usr/bin/env node
'use strict';

const assert = require('assert');
const childProcess = require('child_process');

const MODULE_PATH = require.resolve('../lib/canonical_build');

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

function withMockedModule(mockSpawnSync, fn) {
	const originalSpawnSync = childProcess.spawnSync;
	delete require.cache[MODULE_PATH];
	childProcess.spawnSync = mockSpawnSync;
	const canonicalBuild = require('../lib/canonical_build');
	try {
		fn(canonicalBuild);
	} finally {
		childProcess.spawnSync = originalSpawnSync;
		delete require.cache[MODULE_PATH];
	}
}

console.log('Section A: canonical build runner');

test('runCanonicalBuild uses approved PowerShell invocation', () => {
	let recorded = null;
	withMockedModule((command, args, options) => {
		recorded = { command, args, options };
		return { status: 0, stdout: 'ok', stderr: '' };
	}, ({ runCanonicalBuild }) => {
		const result = runCanonicalBuild('E:\\repo');
		assert.strictEqual(result.ok, true);
	});
	assert.deepStrictEqual(recorded, {
		command: 'powershell',
		args: ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '& .\\build.bat'],
		options: {
			cwd: 'E:\\repo',
			encoding: 'utf8',
			stdio: 'pipe',
		},
	});
});

test('runCanonicalVerify returns structured failure results', () => {
	withMockedModule(() => ({ status: 1, stdout: 'out', stderr: 'err' }), ({ runCanonicalVerify }) => {
		const result = runCanonicalVerify('E:\\repo', { stdio: 'inherit' });
		assert.deepStrictEqual(result, {
			ok: false,
			status: 1,
			output: 'outerr',
			command: '& .\\verify.bat',
			scriptName: 'verify.bat',
		});
	});
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
