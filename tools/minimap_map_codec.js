'use strict';

const { getMinimapPreview } = require('./lib/minimap_preview');

function decodeMapWords(slug) {
	return getMinimapPreview(slug).words.slice();
}

class BitWriter {
	constructor() {
		this.bytes = [];
		this.currentByte = 0;
		this.bitCount = 0;
	}

	write(value, count) {
		for (let i = count - 1; i >= 0; i--) {
			this.currentByte = ((this.currentByte << 1) | ((value >>> i) & 1)) & 0xFF;
			this.bitCount += 1;
			if (this.bitCount === 8) {
				this.bytes.push(this.currentByte);
				this.currentByte = 0;
				this.bitCount = 0;
			}
		}
	}

	finish() {
		if (this.bitCount > 0) {
			this.bytes.push((this.currentByte << (8 - this.bitCount)) & 0xFF);
		}
		if (this.bytes.length & 1) this.bytes.push(0x00);
		return Uint8Array.from(this.bytes);
	}
}

function encodeLiteralTilemap(words, bitWidth = 6) {
	const header = [
		bitWidth & 0xFF,
		0x00,
		0x00, 0x00,
		0x00, 0x00,
	];
	const writer = new BitWriter();

	function emitControl(opcode, repeat) {
		const control = ((opcode & 0x07) << 4) | (repeat & 0x0F);
		writer.write(control, 7);
	}

	let index = 0;
	while (index < words.length) {
		const run = Math.min(15, words.length - index);
		emitControl(7, run - 1);
		for (let i = 0; i < run; i++) {
			const word = words[index + i] & 0xFFFF;
			writer.write(word & ((1 << bitWidth) - 1), bitWidth);
		}
		index += run;
	}

	emitControl(7, 0x0F);
	return Uint8Array.from([...header, ...writer.finish()]);
}

function encodeCompactTilemap(words, bitWidth = 6) {
	const header = [
		bitWidth & 0xFF,
		0x00,
		0x00, 0x00,
		0x00, 0x00,
	];
	const writer = new BitWriter();
	let index = 0;
	let incrValue = 0;

	function emitControl(opcode, repeat) {
		const control = ((opcode & 0x07) << 4) | (repeat & 0x0F);
		if (control < 0x40) {
			writer.write(control << 1, 6);
		} else {
			writer.write(control, 7);
		}
	}

	while (index < words.length) {
		if (words[index] === 0) {
			let run = 1;
			while (index + run < words.length && words[index + run] === 0 && run < 16) run += 1;
			emitControl(2, run - 1);
			index += run;
			continue;
		}

		if (words[index] === incrValue) {
			let run = 1;
			while (index + run < words.length && words[index + run] === (incrValue + run) && run < 16) run += 1;
			emitControl(0, run - 1);
			incrValue += run;
			index += run;
			continue;
		}

		let run = 1;
		while (index + run < words.length && run < 15) {
			const next = words[index + run];
			if (next === 0) break;
			if (next === (words[index + run - 1] + 1) && words[index] === incrValue) break;
			run += 1;
		}
		emitControl(7, run - 1);
		for (let i = 0; i < run; i++) {
			writer.write(words[index + i] & ((1 << bitWidth) - 1), bitWidth);
		}
		index += run;
	}

	emitControl(7, 0x0F);
	return Uint8Array.from([...header, ...writer.finish()]);
}

module.exports = {
	decodeMapWords,
	encodeLiteralTilemap,
	encodeCompactTilemap,
};
