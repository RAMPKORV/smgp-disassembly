'use strict';

function flattenTileLongwords(tiles) {
	const longs = [];
	for (const tile of tiles) {
		for (let row = 0; row < 8; row++) {
			let value = 0;
			for (let col = 0; col < 8; col++) {
				value = ((value << 4) | (tile[row][col] & 0x0F)) >>> 0;
			}
			longs.push(value >>> 0);
		}
	}
	return longs;
}

class BitWriter {
	constructor() {
		this.bytes = [];
		this.current = 0;
		this.bitCount = 0;
	}

	write(value, count) {
		for (let i = count - 1; i >= 0; i--) {
			this.current = ((this.current << 1) | ((value >>> i) & 1)) & 0xFF;
			this.bitCount += 1;
			if (this.bitCount === 8) {
				this.bytes.push(this.current);
				this.current = 0;
				this.bitCount = 0;
			}
		}
	}

	finish() {
		if (this.bitCount > 0) {
			this.bytes.push((this.current << (8 - this.bitCount)) & 0xFF);
		}
		return this.bytes;
	}
}

function emitNibbleRun(writer, nibble, count) {
	while (count > 0) {
		const chunk = Math.min(count, 8);
		writer.write(0x3F, 6); // %111111 = extended literal/run prefix ($FC-$FF family)
		writer.write((chunk - 1) & 0x07, 3);
		writer.write(nibble & 0x0F, 4);
		count -= chunk;
	}
}

function encodeTinyGraphics(tiles) {
	const longs = flattenTileLongwords(tiles);
	const bytes = [];
	const tileCount = tiles.length;
	bytes.push((tileCount >> 8) & 0x7F, tileCount & 0xFF);
	bytes.push(0xFF); // empty code table, rely only on extended literals below
	const writer = new BitWriter();

	for (const value of longs) {
		let lastNibble = null;
		let run = 0;
		for (let shift = 28; shift >= 0; shift -= 4) {
			const nibble = (value >>> shift) & 0x0F;
			if (lastNibble === null || nibble !== lastNibble) {
				if (lastNibble !== null) emitNibbleRun(writer, lastNibble, run);
				lastNibble = nibble;
				run = 1;
			} else {
				run += 1;
			}
		}
		if (lastNibble !== null) emitNibbleRun(writer, lastNibble, run);
	}

	return Uint8Array.from(bytes.concat(writer.finish()));
}

module.exports = {
	flattenTileLongwords,
	encodeTinyGraphics,
};
