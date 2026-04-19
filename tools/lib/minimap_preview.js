'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const HUD_AND_MINIMAP_ASM = path.join(REPO_ROOT, 'src', 'hud_and_minimap_data.asm');

const TRACK_LABELS = {
  san_marino: { tiles: 'Minimap_tiles_San_Marino', map: 'Minimap_map_San_Marino' },
  brazil: { tiles: 'Minimap_tiles_Brazil', map: 'Minimap_map_Brazil' },
  france: { tiles: 'Minimap_tiles_France', map: 'Minimap_map_France' },
  hungary: { tiles: 'Minimap_tiles_Hungary', map: 'Minimap_map_Hungary' },
  west_germany: { tiles: 'Minimap_tiles_West_Germany', map: 'Minimap_map_West_Germany' },
  usa: { tiles: 'Minimap_tiles_USA', map: 'Minimap_map_USA' },
  canada: { tiles: 'Minimap_tiles_Canada', map: 'Minimap_map_Canada' },
  great_britain: { tiles: 'Minimap_tiles_Great_Britain', map: 'Minimap_map_Great_Britain' },
  italy: { tiles: 'Minimap_tiles_Italy', map: 'Minimap_map_Italy' },
  portugal: { tiles: 'Minimap_tiles_Portugal', map: 'Minimap_map_Portugal' },
  spain: { tiles: 'Minimap_tiles_Spain', map: 'Minimap_map_Spain' },
  mexico: { tiles: 'Minimap_tiles_Mexico', map: 'Minimap_map_Mexico' },
  japan: { tiles: 'Minimap_tiles_Japan', map: 'Minimap_map_Japan' },
  belgium: { tiles: 'Minimap_tiles_Belgium', map: 'Minimap_map_Belgium' },
  australia: { tiles: 'Minimap_tiles_Australia', map: 'Minimap_map_Australia' },
  monaco: { tiles: 'Minimap_tiles_Monaco', map: 'Minimap_map_Monaco' },
  monaco_prelim: { tiles: 'Minimap_tiles_Monaco_prelim', map: 'Minimap_map_Monaco_prelim' },
  monaco_arcade: { tiles: 'Minimap_tiles_Monaco_arcade', map: 'Minimap_map_Monaco_arcade' },
  monaco_arcade_wet: { tiles: 'Minimap_tiles_Monaco_arcade', map: 'Minimap_map_Monaco_arcade' },
};

let asmCache = null;

function readAsm() {
  if (asmCache !== null) return asmCache;
  asmCache = fs.readFileSync(HUD_AND_MINIMAP_ASM, 'utf8');
  return asmCache;
}

function parseNumber(token) {
  const trimmed = token.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith('$')) return parseInt(trimmed.slice(1), 16);
  if (/^-?\d+$/.test(trimmed)) return parseInt(trimmed, 10);
  return null;
}

function parseLabelBytes(label) {
  const text = readAsm();
  const lines = text.split(/\r?\n/);
  const labelRegex = new RegExp(`^${label}:\\s*$`);
  const nextLabelRegex = /^[A-Za-z_][A-Za-z0-9_]*:\s*$/;
  const bytes = [];
  let inBlock = false;

  for (const line of lines) {
    if (!inBlock) {
      if (labelRegex.test(line.trim())) inBlock = true;
      continue;
    }
    if (nextLabelRegex.test(line.trim())) break;
    const commentFree = line.split(';')[0];
    const marker = commentFree.indexOf('dc.b');
    if (marker === -1) continue;
    const dataPart = commentFree.slice(marker + 4);
    for (const token of dataPart.split(',')) {
      const value = parseNumber(token);
      if (value !== null) bytes.push(value & 0xFF);
    }
  }

  if (bytes.length === 0) {
    throw new Error(`Could not parse bytes for label ${label}`);
  }
  return Uint8Array.from(bytes);
}

function buildGraphicsCodeTable(bytes, offset) {
  const table = new Uint16Array(256);
  let d0 = bytes[offset++];

  while (d0 !== 0xFF) {
    let d7 = d0 & 0xFFFF;
    while (true) {
      d0 = bytes[offset++];
      if (d0 >= 0x80) break;

      let d1 = d0 & 0x70;
      d7 = (d7 & 0x000F) | d1;
      d0 &= 0x0F;
      d1 = d0 << 8;
      d7 = (d7 | d1) & 0xFFFF;

      d1 = 8 - d0;
      if (d1 === 0) {
        d0 = bytes[offset++];
        table[d0 & 0xFF] = d7;
        continue;
      }

      d0 = bytes[offset++];
      d0 = (d0 << d1) & 0xFFFF;
      let d5 = ((1 << d1) - 1) & 0xFFFF;
      while (true) {
        table[d0 & 0xFF] = d7;
        d0 = (d0 + 1) & 0xFFFF;
        d5 = (d5 - 1) & 0xFFFF;
        if (d5 === 0xFFFF) break;
      }
    }
  }

  return { offset, table };
}

function decompressGraphics(bytes) {
  let offset = 0;
  let d2 = ((bytes[offset] << 8) | bytes[offset + 1]) & 0xFFFF;
  offset += 2;
  const xorMode = !!(d2 & 0x8000);
  d2 = (d2 << 1) & 0xFFFF;
	d2 = (d2 << 2) & 0xFFFF;
	let groupsRemaining = d2 & 0xFFFF;

  const { offset: afterTable, table } = buildGraphicsCodeTable(bytes, offset);
  offset = afterTable;

  let d5 = ((bytes[offset] << 8) | bytes[offset + 1]) & 0xFFFF;
  offset += 2;
  let d6 = 0x0010;
  let d3 = 8;
  let d4 = 0;
  let xorState = 0;
  const output = Buffer.alloc(groupsRemaining * 4);
  let outOffset = 0;

  function refillIfNeeded() {
    if (d6 < 9) {
      d6 += 8;
      d5 = ((d5 << 8) & 0xFFFF) | bytes[offset++];
    }
  }

  function emitNibble(nibble, repeatCountWord) {
    let repeatWord = repeatCountWord & 0xFFFF;
    while (true) {
      d4 = ((d4 << 4) | (nibble & 0x0F)) >>> 0;
      d3 -= 1;
      if (d3 === 0) {
        const value = xorMode ? (xorState ^ d4) >>> 0 : d4 >>> 0;
        xorState = value;
        output.writeUInt32BE(value >>> 0, outOffset);
        outOffset += 4;
        groupsRemaining = (groupsRemaining - 1) & 0xFFFF;
        if (groupsRemaining === 0) return true;
        d4 = 0;
        d3 = 8;
      }

      repeatWord = (repeatWord - 1) & 0xFFFF;
      if (repeatWord === 0xFFFF) break;
    }
    return false;
  }

  while (groupsRemaining > 0) {
    let d7 = (d6 - 8) & 0xFFFF;
    let d1 = (d5 >>> d7) & 0xFFFF;

    if (d1 >= 0xFC) {
      d6 = (d6 - 6) & 0xFFFF;
      refillIfNeeded();
      d6 = (d6 - 7) & 0xFFFF;
      d1 = (d5 >>> d6) & 0xFFFF;
      let d0 = d1 & 0x0070;
      d1 &= 0x000F;
      refillIfNeeded();
      d0 >>>= 4;
      if (emitNibble(d1, d0)) break;
      continue;
    }

    d1 &= 0x00FF;
    let d0 = table[d1] & 0xFFFF;
    const bitLength = d0 & 0x00FF;
    d6 = (d6 - bitLength) & 0xFFFF;
    refillIfNeeded();
    d1 = (d0 >> 8) & 0x00FF;
    d0 = d1 & 0x00F0;
    d1 &= 0x000F;
    d0 >>>= 4;
    if (emitNibble(d1, d0)) break;
  }

  return output;
}

function ror16(value, shift) {
  const s = shift & 15;
  const masked = value & 0xFFFF;
  return (((masked >>> s) | (masked << (16 - s))) & 0xFFFF) >>> 0;
}

function decodeFlipDescriptor(byteValue) {
  let d0 = byteValue & 0xFF;
  if (d0 & 0x80) d0 = d0 - 0x100;
  let d4 = d0 & 0xFFFFFFFF;
  d4 = ((d4 >>> 1) | ((d4 & 1) << 31)) >>> 0;
  const low = ror16(d4 & 0xFFFF, 1);
  d4 = (d4 & 0xFFFF0000) | low;
  return d4 >>> 0;
}

class TilemapBitReader {
  constructor(bytes, offset) {
    this.bytes = bytes;
    this.offset = offset;
    this.d5 = ((bytes[offset] << 8) | bytes[offset + 1]) & 0xFFFF;
    this.offset += 2;
    this.d6 = 0x0010;
  }

  refill(consumedBits) {
    this.d6 = (this.d6 - consumedBits) & 0xFFFF;
    if (this.d6 < 9) {
      this.d6 += 8;
      this.d5 = ((this.d5 << 8) & 0xFFFF) | this.bytes[this.offset++];
    }
  }
}

const BIT_MASK_TABLE = [
  0x0001, 0x0003, 0x0007, 0x000F, 0x001F,
  0x003F, 0x007F, 0x00FF, 0x01FF, 0x03FF,
  0x07FF, 0x0FFF, 0x1FFF, 0x3FFF, 0x7FFF, 0xFFFF,
];

function decodePackedTilemapEntry(reader, state) {
  let d3 = state.baseTile & 0xFFFF;
  let d4 = state.flipDescriptor >>> 0;

  d4 = (((d4 & 0xFFFF) << 16) | (d4 >>> 16)) >>> 0;
  if (d4 & 0x80000000) {
    reader.d6 = (reader.d6 - 1) & 0xFFFF;
    if (((reader.d5 >>> reader.d6) & 1) !== 0) d3 |= 0x1000;
  }

  d4 = (((d4 & 0xFFFF) << 16) | (d4 >>> 16)) >>> 0;
  if (d4 & 0x80000000) {
    reader.d6 = (reader.d6 - 1) & 0xFFFF;
    if (((reader.d5 >>> reader.d6) & 1) !== 0) d3 |= 0x0800;
  }

  let d1 = reader.d5 & 0xFFFF;
  let d7 = (reader.d6 - state.bitWidth) & 0xFFFF;
  if (d7 < 0x8000) {
    if (d7 !== 0) d1 = d1 >>> d7;
    d1 &= BIT_MASK_TABLE[state.bitWidth] || 0;
    d1 = (d1 + d3) & 0xFFFF;
    reader.refill(state.bitWidth);
    return d1;
  }

  reader.d6 = d7 & 0xFFFF;
  reader.d6 = (reader.d6 + 0x0010) & 0xFFFF;
  d7 = (-((d7 << 16) >> 16)) & 0xFFFF;
  d1 = (d1 << d7) & 0xFFFF;
  let extra = reader.bytes[reader.offset] & 0xFF;
  extra = (((extra << d7) | (extra >>> (8 - d7))) & 0xFF) >>> 0;
  extra &= BIT_MASK_TABLE[d7] || 0;
  d1 = (d1 + extra) & 0xFFFF;
  d1 &= BIT_MASK_TABLE[state.bitWidth] || 0;
  d1 = (d1 + d3) & 0xFFFF;
  reader.d5 = ((reader.bytes[reader.offset] << 8) | reader.bytes[reader.offset + 1]) & 0xFFFF;
  reader.offset += 2;
  return d1;
}

function decompressTilemap(bytes, width, height) {
  let offset = 0;
  const state = {
    bitWidth: bytes[offset++] & 0xFF,
    flipDescriptor: decodeFlipDescriptor(bytes[offset++] & 0xFF),
    incrValue: ((bytes[offset] << 8) | bytes[offset + 1]) & 0xFFFF,
    flatValue: ((bytes[offset + 2] << 8) | bytes[offset + 3]) & 0xFFFF,
  };
  state.baseTile = state.incrValue & 0xFFFF;
  offset += 4;

  const reader = new TilemapBitReader(bytes, offset);
  const words = [];

  while (true) {
    let d0 = 7;
    let d7 = (reader.d6 - d0) & 0xFFFF;
    let d1 = (reader.d5 >>> d7) & 0x007F;
    let d2 = d1 & 0xFFFF;
    if (d1 < 0x40) {
      d0 = 6;
      d2 = d2 >>> 1;
    }
    reader.refill(d0);
    d2 &= 0x000F;
    const opcode = d1 >>> 4;
    const repeat = d2;

    if (opcode === 0 || opcode === 1) {
      for (let i = 0; i <= repeat; i++) words.push((state.incrValue + i) & 0xFFFF);
      state.incrValue = (state.incrValue + repeat + 1) & 0xFFFF;
      state.baseTile = state.incrValue & 0xFFFF;
      continue;
    }

    if (opcode === 2 || opcode === 3) {
      for (let i = 0; i <= repeat; i++) words.push(state.flatValue);
      state.baseTile = state.flatValue & 0xFFFF;
      continue;
    }

    if (opcode === 4) {
      const value = decodePackedTilemapEntry(reader, state);
      for (let i = 0; i <= repeat; i++) words.push(value);
      state.baseTile = value & 0x07FF;
      continue;
    }

    if (opcode === 5) {
      let value = decodePackedTilemapEntry(reader, state);
      for (let i = 0; i <= repeat; i++) words.push((value + i) & 0xFFFF);
      state.baseTile = (value + repeat) & 0x07FF;
      continue;
    }

    if (opcode === 6) {
      let value = decodePackedTilemapEntry(reader, state);
      for (let i = 0; i <= repeat; i++) words.push((value - i) & 0xFFFF);
      state.baseTile = (value - repeat) & 0x07FF;
      continue;
    }

    if (repeat === 0x0F) break;
    for (let i = 0; i <= repeat; i++) {
      const value = decodePackedTilemapEntry(reader, state);
      words.push(value);
      state.baseTile = value & 0x07FF;
    }
  }

  return words.slice(0, width * height);
}

function decodeTiles(tileBytes) {
  const tiles = [];
  for (let offset = 0; offset + 31 < tileBytes.length; offset += 32) {
    const pixels = [];
    for (let row = 0; row < 8; row++) {
      const rowPixels = [];
      for (let column = 0; column < 4; column++) {
        const byte = tileBytes[offset + row * 4 + column];
        rowPixels.push((byte >> 4) & 0x0F, byte & 0x0F);
      }
      pixels.push(rowPixels);
    }
    tiles.push(pixels);
  }
  return tiles;
}

function renderMinimapPixels(tiles, words, width, height) {
  const pixelWidth = width * 8;
  const pixelHeight = height * 8;
  const pixels = new Uint8Array(pixelWidth * pixelHeight);

	for (let tileY = 0; tileY < height; tileY++) {
		for (let tileX = 0; tileX < width; tileX++) {
			const word = words[tileY * width + tileX] || 0;
			const rawTileIndex = word & 0x07FF;
			if (rawTileIndex === 0) continue;
			const runtimeTileIndex = rawTileIndex + 1;
			const localTileIndex = runtimeTileIndex - 2;
			if (localTileIndex < 0) continue;
			const tile = tiles[localTileIndex] || null;
			if (!tile) continue;
			const hFlip = !!(word & 0x0800);
			const vFlip = !!(word & 0x1000);
      for (let row = 0; row < 8; row++) {
        for (let column = 0; column < 8; column++) {
          const srcRow = vFlip ? 7 - row : row;
          const srcCol = hFlip ? 7 - column : column;
          const color = tile[srcRow][srcCol];
          const index = (tileY * 8 + row) * pixelWidth + (tileX * 8 + column);
          pixels[index] = color;
        }
      }
    }
  }

	return pixels;
}

function getUsedLocalTileIndices(words) {
	const used = new Set();
	for (const word of words) {
		const rawTileIndex = word & 0x07FF;
		if (rawTileIndex === 0) continue;
		const runtimeTileIndex = rawTileIndex + 1;
		const localTileIndex = runtimeTileIndex - 2;
		if (localTileIndex >= 0) used.add(localTileIndex);
	}
	return Array.from(used).sort((a, b) => a - b);
}

function getMinimapPreview(slug) {
  const labels = TRACK_LABELS[slug];
  if (!labels) {
    throw new Error(`No minimap labels known for slug: ${slug}`);
  }
  const tileBytes = parseLabelBytes(labels.tiles);
  const mapBytes = parseLabelBytes(labels.map);
  const tiles = decodeTiles(decompressGraphics(tileBytes));
  const words = decompressTilemap(mapBytes, 7, 11);
  const pixels = renderMinimapPixels(tiles, words, 7, 11);
  const usedLocalTileIndices = getUsedLocalTileIndices(words);

  return {
    slug,
    width: 56,
    height: 88,
    pixels: Array.from(pixels),
    words,
    tiles,
    tile_count: tiles.length,
    used_local_tile_indices: usedLocalTileIndices,
    used_local_tile_count: usedLocalTileIndices.length,
  };
}

module.exports = {
  getMinimapPreview,
	decompressGraphics,
	decompressTilemap,
	decodeTiles,
	renderMinimapPixels,
};
