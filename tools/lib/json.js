// tools/lib/json.js
//
// JSON read/write helpers with consistent formatting.
// All JSON files in this project are written with 2-space indentation
// and a trailing newline, matching the existing tools/data/*.json style.

'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Read and parse a JSON file from disk.
 * @param {string} filePath
 * @returns {any}
 */
function readJson(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(text);
}

/**
 * Write a value as formatted JSON to disk.
 * Creates parent directories if needed.
 * @param {string} filePath
 * @param {any} value
 * @param {number} [indent=2]
 */
function writeJson(filePath, value, indent = 2) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const text = JSON.stringify(value, null, indent) + '\n';
  fs.writeFileSync(filePath, text, 'utf8');
}

/**
 * Read JSON from disk, apply a transform function, write back.
 * @param {string} filePath
 * @param {function} transformFn - receives the parsed value, returns the new value
 */
function updateJson(filePath, transformFn) {
  const value = readJson(filePath);
  const updated = transformFn(value);
  writeJson(filePath, updated);
}

module.exports = {
  readJson,
  writeJson,
  updateJson,
};
