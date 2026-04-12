#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { backupOnce, createInRootCheckpointSession, patchRomIfPresent, writeJsonFile } = require('../randomize_actions');

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

console.log('Section A: randomize actions');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-randomize-actions-'));

test('backupOnce copies file only once', () => {
	const src = path.join(tmpDir, 'source.json');
	const backup = path.join(tmpDir, 'backup.json');
	fs.writeFileSync(src, '{"a":1}', 'utf8');
	backupOnce(src, backup, 'test');
	fs.writeFileSync(src, '{"a":2}', 'utf8');
	backupOnce(src, backup, 'test');
	assert.strictEqual(fs.readFileSync(backup, 'utf8'), '{"a":1}');
});

test('backupOnce checkpoints file when checkpoint session is present', () => {
	const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-randomize-actions-checkpoint-'));
	const src = path.join(repoRoot, 'tools', 'data', 'source.json');
	const backup = path.join(repoRoot, 'tools', 'data', 'backup.json');
	fs.mkdirSync(path.dirname(src), { recursive: true });
	fs.writeFileSync(src, '{"a":1}', 'utf8');
	const session = createInRootCheckpointSession({ seed: 'TEST', repoRoot });
	const entry = backupOnce(src, backup, 'test', { checkpointSession: session });
	assert.ok(entry, 'expected checkpoint entry');
	assert.strictEqual(fs.existsSync(backup), false, 'legacy backup should not be written when checkpointing');
	fs.rmSync(path.join(repoRoot, 'build'), { recursive: true, force: true });
	fs.rmSync(repoRoot, { recursive: true, force: true });
});

test('writeJsonFile writes formatted JSON', () => {
	const out = path.join(tmpDir, 'written.json');
	writeJsonFile(out, { hello: 'world' });
	assert.ok(fs.readFileSync(out, 'utf8').includes('"hello": "world"'));
});

test('patchRomIfPresent skips missing ROM cleanly', () => {
	const romPath = path.join(tmpDir, 'missing.bin');
	const result = patchRomIfPresent(romPath, 'test', () => 123);
	assert.strictEqual(result, null);
});

test('patchRomIfPresent runs patcher when ROM exists', () => {
	const romPath = path.join(tmpDir, 'present.bin');
	fs.writeFileSync(romPath, Buffer.alloc(4));
	let called = false;
	const result = patchRomIfPresent(romPath, 'test', () => {
		called = true;
		return 7;
	});
	assert.strictEqual(called, true);
	assert.strictEqual(result, 7);
});

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
