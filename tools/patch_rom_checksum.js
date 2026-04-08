'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_ROM = path.join(REPO_ROOT, 'out.bin');
const CHECKSUM_OFFSET = 0x018E;
const CHECKSUM_START = 0x0200;

function computeRomChecksum(buffer) {
  let sum = 0;
  for (let offset = CHECKSUM_START; offset + 1 < buffer.length; offset += 2) {
    sum = (sum + buffer.readUInt16BE(offset)) & 0xFFFF;
  }
  return sum;
}

function patchRomChecksum(romPath) {
  const targetPath = path.resolve(REPO_ROOT, romPath || 'out.bin');
  if (!fs.existsSync(targetPath)) {
    throw new Error(`ROM file not found: ${targetPath}`);
  }

  const buffer = fs.readFileSync(targetPath);
  if (buffer.length <= CHECKSUM_OFFSET + 1) {
    throw new Error(`ROM file too small to patch checksum: ${targetPath}`);
  }

  const oldChecksum = buffer.readUInt16BE(CHECKSUM_OFFSET);
  const newChecksum = computeRomChecksum(buffer);
  buffer.writeUInt16BE(newChecksum, CHECKSUM_OFFSET);
  fs.writeFileSync(targetPath, buffer);

  return {
    romPath: targetPath,
    oldChecksum,
    newChecksum,
    changed: oldChecksum !== newChecksum,
  };
}

function formatWord(value) {
  return `$${value.toString(16).toUpperCase().padStart(4, '0')}`;
}

function main() {
  try {
    const result = patchRomChecksum(process.argv[2] || DEFAULT_ROM);
    process.stdout.write(`ROM checksum ${result.changed ? 'updated' : 'verified'} for ${path.basename(result.romPath)}\n`);
    process.stdout.write(`  old: ${formatWord(result.oldChecksum)}\n`);
    process.stdout.write(`  new: ${formatWord(result.newChecksum)}\n`);
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  CHECKSUM_OFFSET,
  CHECKSUM_START,
  computeRomChecksum,
  patchRomChecksum,
};
