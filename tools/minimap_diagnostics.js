#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const {
  TRACKS_JSON,
  loadTracksData,
  findTrack,
  analyzeTrackMinimap,
  analyzeAllTracks,
} = require('./lib/minimap_analysis');

function formatSummaryLine(entry) {
  const track = entry.track;
  const metrics = entry.metrics;
  const status = metrics.significant_mismatch ? 'WARN' : 'OK  ';
  return `${status} [${String(track.index).padStart(2, '0')}] ${track.name.padEnd(22)} match=${metrics.match_percent.toFixed(2).padStart(6)}% transform=${metrics.transform.padEnd(10)} mean=${metrics.symmetric_mean_distance.toFixed(3)}`;
}

function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['--json', '--write-json', '--verbose'],
    options: ['--track', '--out', '--input'],
  });

  const inputPath = args.options['--input']
    ? path.resolve(process.cwd(), args.options['--input'])
    : TRACKS_JSON;
  const outPath = args.options['--out']
    ? path.resolve(process.cwd(), args.options['--out'])
    : path.join(process.cwd(), 'tools', 'index', 'minimap_diagnostics.json');
  const trackArg = args.options['--track'];
  const jsonOnly = args.flags['--json'];
  const writeJson = args.flags['--write-json'];
  const verbose = args.flags['--verbose'];

  if (!fs.existsSync(inputPath)) {
    die(`tracks JSON not found: ${inputPath}`);
  }

  const tracksData = loadTracksData(inputPath);

  if (trackArg) {
    const track = findTrack(trackArg, tracksData);
    if (!track) {
      die(`track not found: ${trackArg}`);
    }

    const analysis = analyzeTrackMinimap(track);
    if (jsonOnly) {
      process.stdout.write(JSON.stringify(analysis, null, 2) + '\n');
      return;
    }

    info(formatSummaryLine(analysis));
    info(`  canonical points : ${analysis.canonical.points.length}`);
    info(`  preview pixels   : ${analysis.preview.occupied_points.length}`);
    info(`  warning          : ${analysis.metrics.significant_mismatch ? 'significant mismatch' : 'within threshold'}`);
    if (verbose) {
      info(`  preview->map mean: ${analysis.metrics.preview_to_canonical_mean}`);
      info(`  map->preview mean: ${analysis.metrics.canonical_to_preview_mean}`);
      info(`  normalized error : ${analysis.metrics.normalized_error}`);
      info(`  sign markers     : ${analysis.signs.length}`);
    }
    return;
  }

  const report = analyzeAllTracks(tracksData);
  if (writeJson) {
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(report, null, 2) + '\n', 'utf8');
  }

  if (jsonOnly) {
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
    return;
  }

  info(`Tracks analyzed           : ${report.track_count}`);
  info(`Average match percent     : ${report.average_match_percent.toFixed(2)}%`);
  info(`Significant mismatches    : ${report.significant_mismatch_count}`);
  info(`Tile usage groups         : ${report.preview_tile_usage_groups.length}`);
  if (writeJson) {
    info(`JSON report written       : ${path.relative(process.cwd(), outPath)}`);
  }
  info('');

  for (const entry of report.tracks) {
    info(formatSummaryLine(entry));
  }
}

main();
