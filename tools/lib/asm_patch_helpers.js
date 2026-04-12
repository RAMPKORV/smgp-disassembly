'use strict';

const { writeU16BE, writeU32BE } = require('./binary');

const ROM_END_OFFSET = 0x01A4;

function writeWordBE(buffer, offset, value) {
	writeU16BE(buffer, offset, value);
}

function writeLongBE(buffer, offset, value) {
	writeU32BE(buffer, offset, value);
}

function alignEven(value) {
	return (value + 1) & ~1;
}

function encodeJsrAbsoluteLong(address) {
	const out = Buffer.alloc(6);
	writeWordBE(out, 0, 0x4EB9);
	writeLongBE(out, 2, address);
	return out;
}

function patchRomEnd(buffer, romEndOffset = ROM_END_OFFSET) {
	writeLongBE(buffer, romEndOffset, buffer.length - 1);
}

function formatHexByte(value) {
	return `$${(value & 0xFF).toString(16).toUpperCase().padStart(2, '0')}`;
}

function formatHexLong(value) {
	return `$${(value >>> 0).toString(16).toUpperCase().padStart(8, '0')}`;
}

function formatDcB(bytes, chunkSize = 32) {
	const lines = [];
	for (let i = 0; i < bytes.length; i += chunkSize) {
		const chunk = bytes.slice(i, i + chunkSize);
		lines.push(`\tdc.b\t${Array.from(chunk).map(formatHexByte).join(', ')}`);
	}
	return lines;
}

function formatDcL(values, chunkSize = 4) {
	const lines = [];
	for (let i = 0; i < values.length; i += chunkSize) {
		lines.push(`\tdc.l\t${values.slice(i, i + chunkSize).map(formatHexLong).join(', ')}`);
	}
	return lines;
}

module.exports = {
	ROM_END_OFFSET,
	writeWordBE,
	writeLongBE,
	alignEven,
	encodeJsrAbsoluteLong,
	patchRomEnd,
	formatHexByte,
	formatHexLong,
	formatDcB,
	formatDcL,
};
