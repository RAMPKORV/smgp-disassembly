// tools/lib/binary.js
//
// Low-level binary read helpers for working with Motorola 68000 ROM buffers.
// All multi-byte reads are big-endian (Motorola convention).
//
// All offsets are byte offsets from the start of the Buffer.

'use strict';

/**
 * Read an unsigned 32-bit big-endian integer from buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @returns {number}
 */
function readU32BE(buf, offset) {
  return buf.readUInt32BE(offset);
}

/**
 * Read an unsigned 16-bit big-endian integer from buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @returns {number}
 */
function readU16BE(buf, offset) {
  return buf.readUInt16BE(offset);
}

/**
 * Read a signed 16-bit big-endian integer from buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @returns {number}
 */
function readS16BE(buf, offset) {
  return buf.readInt16BE(offset);
}

/**
 * Read an unsigned 8-bit integer from buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @returns {number}
 */
function readU8(buf, offset) {
  return buf.readUInt8(offset);
}

/**
 * Read a signed 8-bit integer from buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @returns {number}
 */
function readS8(buf, offset) {
  return buf.readInt8(offset);
}

/**
 * Write an unsigned 32-bit big-endian integer into buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @param {number} value
 */
function writeU32BE(buf, offset, value) {
  buf.writeUInt32BE(value >>> 0, offset);
}

/**
 * Write an unsigned 16-bit big-endian integer into buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @param {number} value
 */
function writeU16BE(buf, offset, value) {
  buf.writeUInt16BE(value & 0xFFFF, offset);
}

/**
 * Write an unsigned 8-bit integer into buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @param {number} value
 */
function writeU8(buf, offset, value) {
  buf.writeUInt8(value & 0xFF, offset);
}

/**
 * Write a signed 8-bit integer into buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @param {number} value
 */
function writeS8(buf, offset, value) {
  buf.writeInt8(value, offset);
}

/**
 * Write a signed 16-bit big-endian integer into buf at offset.
 * @param {Buffer} buf
 * @param {number} offset
 * @param {number} value
 */
function writeS16BE(buf, offset, value) {
  buf.writeInt16BE(value, offset);
}

/**
 * Format a number as a zero-padded hex string with '0x' prefix.
 * @param {number} value
 * @param {number} [digits=6] - number of hex digits (not counting '0x')
 * @returns {string}
 */
function hex(value, digits = 6) {
  return '0x' + value.toString(16).toUpperCase().padStart(digits, '0');
}

/**
 * Format a number as a lowercase hex string with '0x' prefix.
 * @param {number} value
 * @param {number} [digits=6]
 * @returns {string}
 */
function hexLower(value, digits = 6) {
  return '0x' + value.toString(16).padStart(digits, '0');
}

/**
 * Parse a hex string (with or without '0x' prefix) to an integer.
 * @param {string} s
 * @returns {number}
 */
function parseHex(s) {
  return parseInt(s.replace(/^0x/i, ''), 16);
}

module.exports = {
  readU32BE,
  readU16BE,
  readS16BE,
  readU8,
  readS8,
  writeU32BE,
  writeU16BE,
  writeS16BE,
  writeU8,
  writeS8,
  hex,
  hexLower,
  parseHex,
};
