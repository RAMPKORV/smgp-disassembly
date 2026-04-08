#!/usr/bin/env node
// tools/tests/test_lib.js
//
// Tests for the shared Node.js tooling library (tools/lib/).
// Covers: binary read/write helpers, json read/write, fs helpers, cli arg parsing.

'use strict';

const assert = require('assert');
const path = require('path');
const os = require('os');
const fs = require('fs');

const binary = require('../lib/binary.js');
const jsonLib = require('../lib/json.js');
const fsLib = require('../lib/fs.js');
const cliLib = require('../lib/cli.js');
const romLib = require('../lib/rom.js');

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
// Section A: binary.js
// ---------------------------------------------------------------------------
console.log('Section A: binary.js');

test('readU32BE reads big-endian 32-bit unsigned int', () => {
  const buf = Buffer.from([0x00, 0x07, 0x50, 0x00]);
  assert.strictEqual(binary.readU32BE(buf, 0), 0x00075000);
});

test('readU16BE reads big-endian 16-bit unsigned int', () => {
  const buf = Buffer.from([0xC0, 0x04]);
  assert.strictEqual(binary.readU16BE(buf, 0), 0xC004);
});

test('readS16BE reads big-endian 16-bit signed int (positive)', () => {
  const buf = Buffer.from([0x00, 0x20]);
  assert.strictEqual(binary.readS16BE(buf, 0), 32);
});

test('readS16BE reads big-endian 16-bit signed int (negative)', () => {
  const buf = Buffer.from([0xFF, 0xE0]);
  assert.strictEqual(binary.readS16BE(buf, 0), -32);
});

test('readU8 reads unsigned byte', () => {
  const buf = Buffer.from([0xFF]);
  assert.strictEqual(binary.readU8(buf, 0), 255);
});

test('readS8 reads signed byte (negative)', () => {
  const buf = Buffer.from([0x80]);
  assert.strictEqual(binary.readS8(buf, 0), -128);
});

test('readS8 reads signed byte (positive)', () => {
  const buf = Buffer.from([0x7F]);
  assert.strictEqual(binary.readS8(buf, 0), 127);
});

test('writeU32BE round-trips', () => {
  const buf = Buffer.alloc(4);
  binary.writeU32BE(buf, 0, 0x00075000);
  assert.strictEqual(binary.readU32BE(buf, 0), 0x00075000);
});

test('writeU16BE round-trips', () => {
  const buf = Buffer.alloc(2);
  binary.writeU16BE(buf, 0, 0xC004);
  assert.strictEqual(binary.readU16BE(buf, 0), 0xC004);
});

test('writeU8 round-trips', () => {
  const buf = Buffer.alloc(1);
  binary.writeU8(buf, 0, 0xAB);
  assert.strictEqual(binary.readU8(buf, 0), 0xAB);
});

test('hex formats with uppercase and 0x prefix', () => {
  assert.strictEqual(binary.hex(0x75000), '0x075000');
  assert.strictEqual(binary.hex(0xFFFF, 4), '0xFFFF');
});

test('hexLower formats with lowercase and 0x prefix', () => {
  assert.strictEqual(binary.hexLower(0xABCDEF), '0xabcdef');
});

test('parseHex parses 0x-prefixed string', () => {
  assert.strictEqual(binary.parseHex('0x75000'), 0x75000);
  assert.strictEqual(binary.parseHex('0x00FF0000'), 0xFF0000);
});

test('parseHex parses bare hex string', () => {
  assert.strictEqual(binary.parseHex('FF9100'), 0xFF9100);
});

// ---------------------------------------------------------------------------
// Section B: json.js
// ---------------------------------------------------------------------------
console.log('Section B: json.js');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-test-'));

test('writeJson creates file with 2-space indent and trailing newline', () => {
  const outPath = path.join(tmpDir, 'test.json');
  jsonLib.writeJson(outPath, { foo: 42, bar: [1, 2, 3] });
  const text = fs.readFileSync(outPath, 'utf8');
  assert.ok(text.endsWith('\n'), 'missing trailing newline');
  const parsed = JSON.parse(text);
  assert.strictEqual(parsed.foo, 42);
  assert.deepStrictEqual(parsed.bar, [1, 2, 3]);
});

test('readJson reads back what writeJson wrote', () => {
  const outPath = path.join(tmpDir, 'test2.json');
  const original = { a: 1, b: 'hello', c: null };
  jsonLib.writeJson(outPath, original);
  const readBack = jsonLib.readJson(outPath);
  assert.deepStrictEqual(readBack, original);
});

test('writeJson creates parent directories', () => {
  const outPath = path.join(tmpDir, 'nested', 'dir', 'test.json');
  jsonLib.writeJson(outPath, { nested: true });
  assert.ok(fs.existsSync(outPath));
});

test('updateJson applies transform and saves', () => {
  const outPath = path.join(tmpDir, 'update.json');
  jsonLib.writeJson(outPath, { count: 5 });
  jsonLib.updateJson(outPath, v => ({ ...v, count: v.count + 1 }));
  const result = jsonLib.readJson(outPath);
  assert.strictEqual(result.count, 6);
});

// ---------------------------------------------------------------------------
// Section C: fs.js
// ---------------------------------------------------------------------------
console.log('Section C: fs.js');

test('ensureDir creates nested directories', () => {
  const dirPath = path.join(tmpDir, 'a', 'b', 'c');
  fsLib.ensureDir(dirPath);
  assert.ok(fs.existsSync(dirPath));
});

test('writeBytes / readBytes round-trips', () => {
  const filePath = path.join(tmpDir, 'bytes.bin');
  const data = Buffer.from([0xDE, 0xAD, 0xBE, 0xEF]);
  fsLib.writeBytes(filePath, data);
  const back = fsLib.readBytes(filePath);
  assert.deepStrictEqual(back, data);
});

test('writeText / readText round-trips', () => {
  const filePath = path.join(tmpDir, 'text.txt');
  fsLib.writeText(filePath, 'hello world\n');
  assert.strictEqual(fsLib.readText(filePath), 'hello world\n');
});

test('exists returns true for existing file', () => {
  const filePath = path.join(tmpDir, 'bytes.bin');
  assert.ok(fsLib.exists(filePath));
});

test('exists returns false for missing file', () => {
  assert.ok(!fsLib.exists(path.join(tmpDir, 'no_such_file_xyz.bin')));
});

test('copyFile copies file correctly', () => {
  const src = path.join(tmpDir, 'bytes.bin');
  const dest = path.join(tmpDir, 'copy', 'bytes_copy.bin');
  fsLib.copyFile(src, dest);
  assert.deepStrictEqual(fsLib.readBytes(dest), fsLib.readBytes(src));
});

test('listFiles returns sorted file paths with extension filter', () => {
  const dir = path.join(tmpDir, 'listtest');
  fsLib.ensureDir(dir);
  fs.writeFileSync(path.join(dir, 'b.bin'), '');
  fs.writeFileSync(path.join(dir, 'a.bin'), '');
  fs.writeFileSync(path.join(dir, 'c.txt'), '');
  const bins = fsLib.listFiles(dir, '.bin');
  assert.strictEqual(bins.length, 2);
  assert.ok(bins[0].endsWith('a.bin'));
  assert.ok(bins[1].endsWith('b.bin'));
});

test('listFilesRecursive finds files in subdirectories', () => {
  const dir = path.join(tmpDir, 'recursive');
  fsLib.ensureDir(path.join(dir, 'sub'));
  fs.writeFileSync(path.join(dir, 'top.asm'), '');
  fs.writeFileSync(path.join(dir, 'sub', 'inner.asm'), '');
  const asms = fsLib.listFilesRecursive(dir, '.asm');
  assert.strictEqual(asms.length, 2);
});

// ---------------------------------------------------------------------------
// Section D: cli.js
// ---------------------------------------------------------------------------
console.log('Section D: cli.js');

test('parseArgs parses boolean flags', () => {
  const r = cliLib.parseArgs(['--dry-run', '--verbose'], {
    flags: ['--dry-run', '--verbose'],
  });
  assert.strictEqual(r.flags['--dry-run'], true);
  assert.strictEqual(r.flags['--verbose'], true);
});

test('parseArgs flags default to false', () => {
  const r = cliLib.parseArgs([], {
    flags: ['--dry-run'],
  });
  assert.strictEqual(r.flags['--dry-run'], false);
});

test('parseArgs parses value options', () => {
  const r = cliLib.parseArgs(['--out', '/tmp/foo.bin'], {
    options: ['--out'],
  });
  assert.strictEqual(r.options['--out'], '/tmp/foo.bin');
});

test('parseArgs options default to null', () => {
  const r = cliLib.parseArgs([], {
    options: ['--rom'],
  });
  assert.strictEqual(r.options['--rom'], null);
});

test('parseArgs collects positional arguments', () => {
  const r = cliLib.parseArgs(['San_Marino', 'set-field', '--dry-run'], {
    flags: ['--dry-run'],
    options: [],
  });
  assert.deepStrictEqual(r.positional, ['San_Marino', 'set-field']);
  assert.strictEqual(r.flags['--dry-run'], true);
});

test('parseArgs handles mixed flags, options, and positional', () => {
  const r = cliLib.parseArgs(['show', '--rom', 'orig.bin', '--verbose'], {
    flags: ['--verbose'],
    options: ['--rom'],
  });
  assert.deepStrictEqual(r.positional, ['show']);
  assert.strictEqual(r.options['--rom'], 'orig.bin');
  assert.strictEqual(r.flags['--verbose'], true);
});

// ---------------------------------------------------------------------------
// Section E: rom.js constants
// ---------------------------------------------------------------------------
console.log('Section E: rom.js constants');

test('ROM_SIZE is 524288 bytes', () => {
  assert.strictEqual(romLib.ROM_SIZE, 524288);
});

test('REPO_ROOT points to a directory containing smgp.asm', () => {
  const smgpAsmPath = path.join(romLib.REPO_ROOT, 'smgp.asm');
  assert.ok(fs.existsSync(smgpAsmPath), `smgp.asm not found at ${smgpAsmPath}`);
});

test('DEFAULT_ROM_PATH is inside REPO_ROOT', () => {
  assert.ok(romLib.DEFAULT_ROM_PATH.startsWith(romLib.REPO_ROOT));
});

// ---------------------------------------------------------------------------
// Cleanup and summary
// ---------------------------------------------------------------------------
fs.rmSync(tmpDir, { recursive: true, force: true });

const total = passed + failed;
console.log(`\nResults: ${passed} passed, ${failed} failed, ${total} total`);
if (failed > 0) process.exit(1);
