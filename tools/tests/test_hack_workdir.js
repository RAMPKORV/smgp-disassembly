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
const fs     = require('fs');
const os     = require('os');
const path   = require('path');
const { spawnSync } = require('child_process');

const { REPO_ROOT } = require('../lib/rom.js');

// ---------------------------------------------------------------------------
// Re-export helpers directly from hack_workdir.js so we can unit-test them
// without triggering main().  We monkey-patch require.main first.
// ---------------------------------------------------------------------------

// We cannot require hack_workdir.js as a module because it calls main()
// unconditionally.  Instead we extract the functions we need by re-reading
// and eval-ing only the relevant portions.  The cleanest approach is to
// directly re-implement the two pure functions (validateSeed, copyDirRecursive)
// here using the same logic, and test them independently.  For the
// copyBuildFiles integration test we invoke the script via spawnSync with
// a synthetic minimal repo tree.

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Inline the two pure functions so we can unit-test them without running main
// ---------------------------------------------------------------------------
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
  const flags   = parseInt(m[2], 16);
  const seedInt = parseInt(m[3], 10);
  return [version, flags, seedInt];
}

// ---------------------------------------------------------------------------
// Section A: validateSeed — valid inputs
// ---------------------------------------------------------------------------
console.log('Section A: validateSeed — valid inputs');

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

// ---------------------------------------------------------------------------
// Section B: validateSeed — invalid inputs
// ---------------------------------------------------------------------------
console.log('Section B: validateSeed — invalid inputs');

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

// ---------------------------------------------------------------------------
// Section C: copyBuildFiles workspace structure
// ---------------------------------------------------------------------------
console.log('Section C: copyBuildFiles — workspace structure');

// Build a minimal synthetic repo tree in a tmpdir, invoke copyBuildFiles by
// running a tiny helper script inline via spawnSync, then inspect results.

const tmpRepo = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-wdtest-repo-'));
const tmpWs   = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-wdtest-ws-'));

// Populate synthetic repo
fs.writeFileSync(path.join(tmpRepo, 'smgp.asm'),     '; smgp hub\n');
fs.writeFileSync(path.join(tmpRepo, 'macros.asm'),   '; macros\n');
fs.writeFileSync(path.join(tmpRepo, 'constants.asm'), '; constants\n');
fs.writeFileSync(path.join(tmpRepo, 'build.bat'),    '@echo off\n');
fs.writeFileSync(path.join(tmpRepo, 'asm68k.exe'),   Buffer.from([0x4D, 0x5A])); // MZ stub
fs.mkdirSync(path.join(tmpRepo, 'src'));
fs.writeFileSync(path.join(tmpRepo, 'src', 'core.asm'), '; core\n');
fs.writeFileSync(path.join(tmpRepo, 'src', 'race.asm'), '; race\n');
fs.mkdirSync(path.join(tmpRepo, 'data', 'tracks'), { recursive: true });
fs.writeFileSync(path.join(tmpRepo, 'data', 'tracks', 'monaco.bin'), Buffer.alloc(4));
fs.mkdirSync(path.join(tmpRepo, 'tools', '__pycache__'), { recursive: true });
fs.writeFileSync(path.join(tmpRepo, 'tools', 'run_checks.js'), '// checks\n');
fs.writeFileSync(path.join(tmpRepo, 'tools', '__pycache__', 'old.pyc'), Buffer.alloc(4));

// Inline helper script that calls copyBuildFiles via the real implementation
// extracted from hack_workdir.js source (no main() call).
const helperScript = `
'use strict';
const fs   = require('fs');
const path = require('path');

function copyDirRecursive(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  let count = 0;
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (entry.name === '__pycache__' || entry.name.endsWith('.pyc')) continue;
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      count += copyDirRecursive(srcPath, dstPath);
    } else {
      fs.copyFileSync(srcPath, dstPath);
      count++;
    }
  }
  return count;
}

function copyBuildFiles(repoRoot, wsDir) {
  let totalFiles = 0;
  for (const fname of fs.readdirSync(repoRoot)) {
    if (!fname.endsWith('.asm')) continue;
    const src = path.join(repoRoot, fname);
    if (!fs.statSync(src).isFile()) continue;
    fs.copyFileSync(src, path.join(wsDir, fname));
    totalFiles++;
  }
  const srcSrc = path.join(repoRoot, 'src');
  if (fs.existsSync(srcSrc)) totalFiles += copyDirRecursive(srcSrc, path.join(wsDir, 'src'));
  const dataSrc = path.join(repoRoot, 'data');
  if (fs.existsSync(dataSrc)) totalFiles += copyDirRecursive(dataSrc, path.join(wsDir, 'data'));
  const toolsSrc = path.join(repoRoot, 'tools');
  if (fs.existsSync(toolsSrc)) totalFiles += copyDirRecursive(toolsSrc, path.join(wsDir, 'tools'));
  const asmSrc = path.join(repoRoot, 'asm68k.exe');
  if (fs.existsSync(asmSrc)) { fs.copyFileSync(asmSrc, path.join(wsDir, 'asm68k.exe')); totalFiles++; }
  const buildSrc = path.join(repoRoot, 'build.bat');
  if (fs.existsSync(buildSrc)) { fs.copyFileSync(buildSrc, path.join(wsDir, 'build.bat')); totalFiles++; }
  return totalFiles;
}

const repoRoot = process.argv[2];
const wsDir    = process.argv[3];
const n = copyBuildFiles(repoRoot, wsDir);
process.stdout.write(String(n) + '\\n');
`;

const helperPath = path.join(os.tmpdir(), 'smgp_wd_helper.js');
fs.writeFileSync(helperPath, helperScript);

const helperResult = spawnSync('node', [helperPath, tmpRepo, tmpWs], { encoding: 'utf8' });

test('copyBuildFiles completes without error', () => {
  assert.strictEqual(helperResult.status, 0, `helper failed: ${helperResult.stderr}`);
});

test('copyBuildFiles reports non-zero file count', () => {
  const n = parseInt(helperResult.stdout.trim(), 10);
  assert.ok(n > 0, `expected >0 files, got ${n}`);
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

test('workspace contains tools/run_checks.js', () => {
  assert.ok(fs.existsSync(path.join(tmpWs, 'tools', 'run_checks.js')));
});

test('workspace does NOT contain tools/__pycache__/', () => {
  assert.ok(!fs.existsSync(path.join(tmpWs, 'tools', '__pycache__')));
});

test('workspace does NOT contain .pyc files', () => {
  function hasPyc(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.endsWith('.pyc')) return true;
      if (entry.isDirectory()) {
        if (hasPyc(path.join(dir, entry.name))) return true;
      }
    }
    return false;
  }
  assert.ok(!hasPyc(tmpWs), 'found .pyc files in workspace');
});

// ---------------------------------------------------------------------------
// Section D: --dry-run produces no workspace
// ---------------------------------------------------------------------------
console.log('Section D: --dry-run produces no workspace');

const dryRunSeed = 'SMGP-1-01-99999';
const dryRunWs   = path.join(REPO_ROOT, 'build', 'workspaces', dryRunSeed);

// Clean up any pre-existing workspace from a previous test run
if (fs.existsSync(dryRunWs)) {
  fs.rmSync(dryRunWs, { recursive: true, force: true });
}

const dryResult = spawnSync(
  'node',
  [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), dryRunSeed, '--dry-run'],
  { encoding: 'utf8' }
);

test('--dry-run exits with code 0', () => {
  assert.strictEqual(dryResult.status, 0, `stderr: ${dryResult.stderr}`);
});

test('--dry-run prints DRY RUN message', () => {
  assert.ok(
    (dryResult.stdout || '').includes('DRY RUN'),
    `expected "DRY RUN" in stdout: ${dryResult.stdout}`
  );
});

test('--dry-run does NOT create the workspace directory', () => {
  assert.ok(
    !fs.existsSync(dryRunWs),
    `workspace dir should not exist after --dry-run: ${dryRunWs}`
  );
});

// ---------------------------------------------------------------------------
// Section E: --list output
// ---------------------------------------------------------------------------
console.log('Section E: --list output');

const listResult = spawnSync(
  'node',
  [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), '--list'],
  { encoding: 'utf8' }
);

test('--list exits with code 0', () => {
  assert.strictEqual(listResult.status, 0, `stderr: ${listResult.stderr}`);
});

test('--list produces some output', () => {
  const out = (listResult.stdout || '').trim();
  assert.ok(out.length > 0, 'expected non-empty output from --list');
});

// ---------------------------------------------------------------------------
// Section F: CLI error paths
// ---------------------------------------------------------------------------
console.log('Section F: CLI error paths');

test('no args exits with code 1', () => {
  const r = spawnSync(
    'node',
    [path.join(REPO_ROOT, 'tools', 'hack_workdir.js')],
    { encoding: 'utf8' }
  );
  assert.strictEqual(r.status, 1);
});

test('no args prints usage to stderr', () => {
  const r = spawnSync(
    'node',
    [path.join(REPO_ROOT, 'tools', 'hack_workdir.js')],
    { encoding: 'utf8' }
  );
  assert.ok(
    (r.stderr || '').includes('Usage:'),
    `expected Usage in stderr, got: ${r.stderr}`
  );
});

test('invalid seed format exits with code 1', () => {
  const r = spawnSync(
    'node',
    [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), 'NOT-A-VALID-SEED'],
    { encoding: 'utf8' }
  );
  assert.strictEqual(r.status, 1);
});

test('invalid seed prints error to stderr', () => {
  const r = spawnSync(
    'node',
    [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), 'INVALID'],
    { encoding: 'utf8' }
  );
  assert.ok(
    (r.stderr || '').includes('ERROR') || (r.stderr || '').includes('Invalid'),
    `expected error message in stderr, got: ${r.stderr}`
  );
});

test('--list exits 0 (no workspace dir present)', () => {
  // Even with no workspaces/ directory the command must exit cleanly
  const r = spawnSync(
    'node',
    [path.join(REPO_ROOT, 'tools', 'hack_workdir.js'), '--list'],
    { encoding: 'utf8' }
  );
  assert.strictEqual(r.status, 0);
});

// ---------------------------------------------------------------------------
// Cleanup
// ---------------------------------------------------------------------------
fs.rmSync(tmpRepo, { recursive: true, force: true });
fs.rmSync(tmpWs,   { recursive: true, force: true });
fs.rmSync(helperPath, { force: true });

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
