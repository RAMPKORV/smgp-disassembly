// tools/lib/fs.js
//
// Filesystem helpers: directory creation, file copying, listing, etc.
// Wraps Node's built-in fs/path modules with project-consistent conventions.

'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Ensure a directory exists, creating it and all parents if needed.
 * @param {string} dirPath
 */
function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

/**
 * Read all bytes from a file. Returns a Buffer.
 * @param {string} filePath
 * @returns {Buffer}
 */
function readBytes(filePath) {
  return fs.readFileSync(filePath);
}

/**
 * Write bytes (Buffer or Uint8Array) to a file.
 * Creates parent directories if needed.
 * @param {string} filePath
 * @param {Buffer|Uint8Array} data
 */
function writeBytes(filePath, data) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, data);
}

/**
 * Read a file as UTF-8 text.
 * @param {string} filePath
 * @returns {string}
 */
function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

/**
 * Write UTF-8 text to a file.
 * Creates parent directories if needed.
 * @param {string} filePath
 * @param {string} text
 */
function writeText(filePath, text) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, text, 'utf8');
}

/**
 * Check if a file or directory exists.
 * @param {string} filePath
 * @returns {boolean}
 */
function exists(filePath) {
  return fs.existsSync(filePath);
}

/**
 * Copy a file from src to dest.
 * Creates parent directories of dest if needed.
 * @param {string} src
 * @param {string} dest
 */
function copyFile(src, dest) {
  ensureDir(path.dirname(dest));
  fs.copyFileSync(src, dest);
}

/**
 * List all files in a directory matching an optional glob-like suffix filter.
 * Returns absolute paths sorted alphabetically.
 * @param {string} dirPath
 * @param {string} [ext] - optional file extension filter (e.g. '.bin')
 * @returns {string[]}
 */
function listFiles(dirPath, ext) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  const files = entries
    .filter(e => e.isFile())
    .map(e => path.join(dirPath, e.name))
    .filter(f => !ext || f.endsWith(ext))
    .sort();
  return files;
}

/**
 * Recursively list all files under dirPath with a given extension.
 * Returns absolute paths sorted alphabetically.
 * @param {string} dirPath
 * @param {string} ext - e.g. '.asm'
 * @returns {string[]}
 */
function listFilesRecursive(dirPath, ext) {
  const results = [];
  function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (!ext || full.endsWith(ext)) {
        results.push(full);
      }
    }
  }
  walk(dirPath);
  return results.sort();
}

module.exports = {
  ensureDir,
  readBytes,
  writeBytes,
  readText,
  writeText,
  exists,
  copyFile,
  listFiles,
  listFilesRecursive,
};
