#!/usr/bin/env node
// tools/tests/test_hack_workdir.js
//
// Tests for the hack_workdir.js workspace system (TEST-008).
// Covers: seed validation, workspace directory structure produced by
// copyBuildFiles, --dry-run behaviour, --list output, and CLI error paths.
//
// Uses a synthetic tmpdir approach so no real assembler invocation occurs.

'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const { REPO_ROOT } = require('../lib/rom.js');
const { copyBuildFiles, ensureWorkspaceTemplate } = require('../hack_workdir.js');

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

const SEED_RE = /^SMGP-(\d+)-([0-9A-Fa-f]+)-(\d+)$/;

function validateSeed(seedStr) {
	const m = SEED_RE.exec(seedStr);
	if (!m) {
		throw new Error(
			`Invalid seed format: ${JSON.stringify(seedStr)}\n` +
			'Expected: SMGP-<version>-<flags_hex>-<decimal>  e.g. SMGP-1-01-12345'
		);
	}
	const version = parseInt(m[1], 10);
	const flags = parseInt(m[2], 16);
	const seedInt = parseInt(m[3], 10);
	return [version, flags, seedInt];
}

console.log('Section A: validateSeed - valid inputs');

test('parses minimal seed SMGP-1-01-0', () => {
	const [v, f, s] = validateSeed('SMGP-1-01-0');
	assert.strictEqual(v, 1);
	assert.strictEqual(f, 0x01);
	assert.strictEqual(s, 0);
});

test('parses typical seed SMGP-1-01-12345', () => {
	const [v, f, s] = validateSeed('SMGP-1-01-12345');
	assert.strictEqual(v, 1);
	assert.strictEqual(f, 0x01);
	assert.strictEqual(s, 12345);
});

test('parses multi-digit version SMGP-2-FF-99999', () => {
	const [v, f, s] = validateSeed('SMGP-2-FF-99999');
	assert.strictEqual(v, 2);
	assert.strictEqual(f, 0xFF);
	assert.strictEqual(s, 99999);
});

test('parses uppercase hex flags SMGP-1-AB-500', () => {
	const [v, f, s] = validateSeed('SMGP-1-AB-500');
	assert.strictEqual(v, 1);
	assert.strictEqual(f, 0xAB);
	assert.strictEqual(s, 500);
});

test('parses lowercase hex flags SMGP-1-ab-500', () => {
	const [v, f, s] = validateSeed('SMGP-1-ab-500');
	assert.strictEqual(v, 1);
	assert.strictEqual(f, 0xAB);
	assert.strictEqual(s, 500);
});

test('parses large seed integer', () => {
	const [, , s] = validateSeed('SMGP-1-00-4294967295');
	assert.strictEqual(s, 4294967295);
});

test('returns array of exactly 3 elements', () => {
	const result = validateSeed('SMGP-1-01-42');
	assert.strictEqual(result.length, 3);
});

console.log('Section B: validateSeed - invalid inputs');

test('throws on empty string', () => {
	assert.throws(() => validateSeed(''), /Invalid seed format/);
});

test('throws on missing SMGP- prefix', () => {
	assert.throws(() => validateSeed('1-01-12345'), /Invalid seed format/);
});

test('throws on wrong prefix casing (smgp-1-01-12345)', () => {
	assert.throws(() => validateSeed('smgp-1-01-12345'), /Invalid seed format/);
});

test('throws on only 3 segments (SMGP-1-01)', () => {
	assert.throws(() => validateSeed('SMGP-1-01'), /Invalid seed format/);
});

test('throws on extra segment (SMGP-1-01-12345-extra)', () => {
	assert.throws(() => validateSeed('SMGP-1-01-12345-extra'), /Invalid seed format/);
});

test('throws on non-numeric version (SMGP-X-01-12345)', () => {
	assert.throws(() => validateSeed('SMGP-X-01-12345'), /Invalid seed format/);
});

test('throws on invalid hex in flags (SMGP-1-GG-12345)', () => {
	assert.throws(() => validateSeed('SMGP-1-GG-12345'), /Invalid seed format/);
});

test('throws on negative decimal (SMGP-1-01--5)', () => {
	assert.throws(() => validateSeed('SMGP-1-01--5'), /Invalid seed format/);
});

test('throws on whitespace-padded seed', () => {
	assert.throws(() => validateSeed(' SMGP-1-01-12345 '), /Invalid seed format/);
});

test('error message includes the offending string', () => {
	try {
		validateSeed('BAD-SEED');
		assert.fail('should have thrown');
	} catch (err) {
		assert.ok(err.message.includes('BAD-SEED'), 'error should contain the bad seed');
	}
});

console.log('Section C: copyBuildFiles - workspace structure');

const tmpRepo = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-wdtest-repo-'));
const tmpWs = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-wdtest-ws-'));

fs.writeFileSync(path.join(tmpRepo, 'smgp.asm'), '; smgp hub\n');
fs.writeFileSync(path.join(tmpRepo, 'macros.asm'), '; macros\n');
fs.writeFileSync(path.join(tmpRepo, 'constants.asm'), '; constants\n');
fs.writeFileSync(path.join(tmpRepo, 'build.bat'), '@echo off\n');
fs.writeFileSync(path.join(tmpRepo, 'asm68k.exe'), Buffer.from([0x4D, 0x5A]));
fs.mkdirSync(path.join(tmpRepo, 'src'));
fs.writeFileSync(path.join(tmpRepo, 'src', 'core.asm'), '; core\n');
fs.writeFileSync(path.join(tmpRepo, 'src', 'race.asm'), '; race\n');
fs.mkdirSync(path.join(tmpRepo, 'data', 'tracks'), { recursive: true });
fs.writeFileSync(path.join(tmpRepo, 'data', 'tracks', 'monaco.bin'), Buffer.alloc(4));
fs.mkdirSync(path.join(tmpRepo, 'tools', '__pycache__'), { recursive: true });
fs.writeFileSync(path.join(tmpRepo, 'tools', 'randomize.js'), '// randomize\n');
fs.writeFileSync(path.join(tmpRepo, 'tools', '__pycache__', 'old.pyc'), Buffer.alloc(4));

let helperCount = 0;
let helperError = null;
try {
	helperCount = copyBuildFiles(tmpRepo, tmpWs, false, { useWorkingTreeAsm: true });
} catch (err) {
	helperError = err;
}

test('copyBuildFiles completes without error', () => {
	assert.strictEqual(helperError, null, `helper failed: ${helperError && helperError.message}`);
});

test('copyBuildFiles reports non-zero file count', () => {
	assert.ok(helperCount > 0, `expected >0 files, got ${helperCount}`);
});

test('master randomize CLI defaults to workspace-safe help path', () => {
	const result = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'randomize.js'), 'SMGP-1-01-12345', '--dry-run'], {
		cwd: REPO_ROOT,
		encoding: 'utf8',
		timeout: 120000,
	});
	assert.strictEqual(result.status, 0, `randomize.js exited ${result.status}\n${result.stdout}\n${result.stderr}`);
	const output = (result.stdout || '') + (result.stderr || '');
	assert.ok(output.includes('Workspace :'), 'expected workspace-safe output banner');
	assert.ok(output.includes('DRY RUN'), 'expected dry-run workspace message');
	assert.ok(output.includes('latest_randomized.bin'), 'expected stable randomized output path');
});

test('workspace contains smgp.asm', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'smgp.asm')));
});

test('workspace contains macros.asm', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'macros.asm')));
});

test('workspace contains build.bat', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'build.bat')));
});

test('workspace contains asm68k.exe', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'asm68k.exe')));
});

test('workspace contains src/ directory', () => {
	assert.ok(fs.statSync(path.join(tmpWs, 'src')).isDirectory());
});

test('workspace contains src/core.asm', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'src', 'core.asm')));
});

test('workspace contains src/race.asm', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'src', 'race.asm')));
});

test('workspace contains data/tracks/ directory', () => {
	assert.ok(fs.statSync(path.join(tmpWs, 'data', 'tracks')).isDirectory());
});

test('workspace contains data/tracks/monaco.bin', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'data', 'tracks', 'monaco.bin')));
});

test('workspace contains tools/randomize.js', () => {
	assert.ok(fs.existsSync(path.join(tmpWs, 'tools', 'randomize.js')));
});

test('workspace does NOT contain tools/__pycache__/', () => {
	assert.ok(!fs.existsSync(path.join(tmpWs, 'tools', '__pycache__')));
});

test('workspace does NOT contain .pyc files', () => {
	function hasPyc(dir) {
		for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
			if (entry.name.endsWith('.pyc')) return true;
			if (entry.isDirectory() && hasPyc(path.join(dir, entry.name))) return true;
		}
		return false;
	}
	assert.ok(!hasPyc(tmpWs), 'found .pyc files in workspace');
});

console.log('Section D: --dry-run produces no workspace');

const dryRunSeed = 'SMGP-1-01-99999';
const dryRunWs = path.join(REPO_ROOT, 'build', 'workspaces', dryRunSeed);
if (fs.existsSync(dryRunWs)) fs.rmSync(dryRunWs, { recursive: true, force: true });

const dryResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), dryRunSeed, '--dry-run'], { encoding: 'utf8' });
const dryRunTracks = 'san_marino portugal';
const dryRunTracksResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), dryRunSeed, '--dry-run', '--tracks', dryRunTracks], { encoding: 'utf8' });
const dryRunRelativeOutput = 'build/roms/custom_test_randomized.bin';
const dryRunRelativeResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), dryRunSeed, '--dry-run', '--output', dryRunRelativeOutput], { encoding: 'utf8' });
const dryRunAbsoluteWorkspace = path.join(os.tmpdir(), 'smgp-hack-workdir-dryrun');
const dryRunAbsoluteOutput = path.join(os.tmpdir(), 'smgp-hack-workdir-output.bin');
const dryRunAbsoluteResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), dryRunSeed, '--dry-run', '--workspace', dryRunAbsoluteWorkspace, '--output', dryRunAbsoluteOutput], { encoding: 'utf8' });

const templateSeed = 'SMGP-1-01-99';
const templateBase = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-template-test-'));
const templateDir = path.join(templateBase, 'template');
const templateInfo1 = ensureWorkspaceTemplate(REPO_ROOT, false, { useWorkingTreeAsm: true, templateDir });
const templateInfo2 = ensureWorkspaceTemplate(REPO_ROOT, false, { useWorkingTreeAsm: true, templateDir });

test('--dry-run exits with code 0', () => {
	assert.strictEqual(dryResult.status, 0, `stderr: ${dryResult.stderr}`);
});

test('--dry-run prints DRY RUN message', () => {
	assert.ok((dryResult.stdout || '').includes('DRY RUN'), `expected "DRY RUN" in stdout: ${dryResult.stdout}`);
});

test('--dry-run does NOT create the workspace directory', () => {
	assert.ok(!fs.existsSync(dryRunWs), `workspace dir should not exist after --dry-run: ${dryRunWs}`);
});

test('--dry-run prints default output path for hack workspace builds', () => {
	assert.ok((dryResult.stdout || '').includes(path.join('build', 'roms', `out_${dryRunSeed}.bin`)), `expected default output path in stdout: ${dryResult.stdout}`);
});

test('--tracks affects default output filename suffix', () => {
	assert.strictEqual(dryRunTracksResult.status, 0, `stderr: ${dryRunTracksResult.stderr}`);
	assert.ok((dryRunTracksResult.stdout || '').includes(`out_${dryRunSeed}_san_marino_portugal.bin`), `expected tracks suffix in stdout: ${dryRunTracksResult.stdout}`);
});

test('relative --output resolves under repo root', () => {
	assert.strictEqual(dryRunRelativeResult.status, 0, `stderr: ${dryRunRelativeResult.stderr}`);
	assert.ok((dryRunRelativeResult.stdout || '').includes(path.join(REPO_ROOT, dryRunRelativeOutput)), `expected resolved repo-root output path in stdout: ${dryRunRelativeResult.stdout}`);
});

test('absolute --workspace and --output are preserved verbatim', () => {
	assert.strictEqual(dryRunAbsoluteResult.status, 0, `stderr: ${dryRunAbsoluteResult.stderr}`);
	const output = dryRunAbsoluteResult.stdout || '';
	assert.ok(output.includes(`Workspace : ${dryRunAbsoluteWorkspace}`), `missing workspace path in stdout: ${output}`);
	assert.ok(output.includes(`Output    : ${dryRunAbsoluteOutput}`), `missing output path in stdout: ${output}`);
});

test('workspace template cache is reused on subsequent runs', () => {
	assert.strictEqual(templateInfo1.reused, false, 'first template build should not reuse cache');
	assert.strictEqual(templateInfo2.reused, true, 'second template build should reuse cache');
});

console.log('Section E: --list output');

const listResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), '--list'], { encoding: 'utf8' });

test('--list exits with code 0', () => {
	assert.strictEqual(listResult.status, 0, `stderr: ${listResult.stderr}`);
});

test('--list produces some output', () => {
	const out = (listResult.stdout || '').trim();
	assert.ok(out.length > 0, 'expected non-empty output from --list');
});

console.log('Section F: CLI error paths');

const noArgsResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js')], { encoding: 'utf8' });
const invalidSeedResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), 'NOT-A-VALID-SEED'], { encoding: 'utf8' });
const invalidSeedShortResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), 'INVALID'], { encoding: 'utf8' });
const listAgainResult = spawnSync('node', [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), '--list'], { encoding: 'utf8' });

test('no args exits with code 1', () => {
	assert.strictEqual(noArgsResult.status, 1);
});

test('no args prints usage to stderr', () => {
	assert.ok((noArgsResult.stderr || '').includes('Usage:'), `expected Usage in stderr, got: ${noArgsResult.stderr}`);
});

test('invalid seed format exits with code 1', () => {
	assert.strictEqual(invalidSeedResult.status, 1);
});

test('invalid seed prints error to stderr', () => {
	assert.ok((invalidSeedShortResult.stderr || '').includes('ERROR') || (invalidSeedShortResult.stderr || '').includes('Invalid'), `expected error message in stderr, got: ${invalidSeedShortResult.stderr}`);
});

test('--list exits 0 (no workspace dir present)', () => {
	assert.strictEqual(listAgainResult.status, 0);
});

fs.rmSync(tmpRepo, { recursive: true, force: true });
fs.rmSync(tmpWs, { recursive: true, force: true });
fs.rmSync(templateBase, { recursive: true, force: true });

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
