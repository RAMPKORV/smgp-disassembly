#!/usr/bin/env node
// tools/sync_track_config.js
//
// Sync selected Track_data fields in src/track_config_data.asm from tools/data/tracks.json.
//
// Currently updates per-track:
//   - +$22 track length
//
// This keeps runtime Track_data metadata aligned with randomized / edited track JSON.

'use strict';

const fs = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { readJson } = require('./lib/json');
const { REPO_ROOT } = require('./lib/rom');

const ASM_PATH = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
const JSON_PATH = path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');
const LINES_PER_BLOCK = 20;

const TRACK_NAMES = [
  'San Marino',
  'Brazil',
  'France',
  'Hungary',
  'West Germany',
  'USA',
  'Canada',
  'Great Britain',
  'Italy',
  'Portugal',
  'Spain',
  'Mexico',
  'Japan',
  'Belgium',
  'Australia',
  'Monaco',
  'Monaco (Arcade preliminary)',
  'Monaco (Arcade main)',
  'Monaco (Arcade Wet Condition)',
];

function formatTrackLengthComment(trackName, length) {
  return `\tdc.w\t${length} ; track length`;
}

function findTrackBlocks(lines) {
  const blockStarts = {};
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    if (!stripped.startsWith(';')) continue;
    const candidate = stripped.slice(1).trim();
    if (TRACK_NAMES.includes(candidate)) {
      blockStarts[candidate] = i;
    }
  }
  return blockStarts;
}

function buildSyncedTrackConfig(lines, tracksJson) {
  const blockStarts = findTrackBlocks(lines);
  const missing = TRACK_NAMES.filter(name => !(name in blockStarts));
  if (missing.length > 0) {
    throw new Error(`Could not find Track_data block(s): ${missing.join(', ')}`);
  }
  if (!tracksJson || !Array.isArray(tracksJson.tracks) || tracksJson.tracks.length !== TRACK_NAMES.length) {
    throw new Error(`Expected ${TRACK_NAMES.length} tracks in tools/data/tracks.json`);
  }

  const newLines = lines.slice();
  let changed = 0;

  for (let index = 0; index < TRACK_NAMES.length; index++) {
    const trackName = TRACK_NAMES[index];
    const track = tracksJson.tracks[index];
    const blockStart = blockStarts[trackName];
    const lengthLineIndex = blockStart + 10;
    const newLine = formatTrackLengthComment(trackName, track.track_length) + '\n';
    if (newLines[lengthLineIndex] !== newLine) {
      newLines[lengthLineIndex] = newLine;
      changed++;
    }
  }

  return {
    content: newLines.join(''),
    changed,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['--dry-run', '--verbose', '-v'],
    options: ['--input', '--asm'],
  });

  const dryRun = args.flags['--dry-run'];
  const verbose = args.flags['--verbose'] || args.flags['-v'];
  const inputPath = path.resolve(REPO_ROOT, args.options['--input'] || 'tools/data/tracks.json');
  const asmPath = path.resolve(REPO_ROOT, args.options['--asm'] || 'src/track_config_data.asm');

  if (!fs.existsSync(inputPath)) die(`tracks JSON not found: ${inputPath}`);
  if (!fs.existsSync(asmPath)) die(`track config ASM not found: ${asmPath}`);

  const tracksJson = readJson(inputPath);
  const lines = fs.readFileSync(asmPath, 'utf8').split(/(?<=\n)/);
  const { content, changed } = buildSyncedTrackConfig(lines, tracksJson);

  if (dryRun) {
    info(`[dry-run] ${changed} Track_data length line(s) would change in ${path.relative(REPO_ROOT, asmPath)}`);
    return;
  }

  fs.writeFileSync(asmPath, content, 'utf8');
  if (verbose || changed > 0) {
    info(`Synced ${changed} Track_data length line(s) in ${path.relative(REPO_ROOT, asmPath)}`);
  }
}

if (require.main === module) main();

module.exports = {
  TRACK_NAMES,
  buildSyncedTrackConfig,
  findTrackBlocks,
};
