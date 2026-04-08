#!/usr/bin/env node
// tools/extract_game_data.js
//
// Unified game-data extractor: calls individual extractors and writes JSON.
//
// Flags:
//   --tracks        Extract track data  -> tools/data/tracks.json
//   --teams         Extract team data   -> tools/data/teams.json
//   --championship  Extract championship data -> tools/data/championship.json
//   --all           Extract all three (default if no flag given)
//   --dry-run       Parse + validate only; do not write output files
//   --rom <path>    Source ROM (default: orig.bin)
//   -v / --verbose  Verbose output
//
// Usage:
//   node tools/extract_game_data.js [--tracks] [--teams] [--championship]
//                                   [--all] [--dry-run] [--rom orig.bin] [-v]

'use strict';

const fs   = require('fs');
const path = require('path');
const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT }            = require('./lib/rom');

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--tracks', '--teams', '--championship', '--all', '--dry-run', '--verbose', '-v'],
    options: ['--rom'],
  });

  const verbose      = args.flags['--verbose'] || args.flags['-v'];
  const dryRun       = args.flags['--dry-run'];
  const doTracks     = args.flags['--tracks']       || args.flags['--all'];
  const doTeams      = args.flags['--teams']        || args.flags['--all'];
  const doChamp      = args.flags['--championship'] || args.flags['--all'];
  const romArg       = args.options['--rom'] || 'orig.bin';
  const romPath      = path.resolve(REPO_ROOT, romArg);

  // If no subset flag given, do all
  const doAll = !args.flags['--tracks'] && !args.flags['--teams'] && !args.flags['--championship'];

  const runTracks = doTracks || doAll;
  const runTeams  = doTeams  || doAll;
  const runChamp  = doChamp  || doAll;

  if (!fs.existsSync(romPath)) die(`ROM not found: ${romPath}`);

  if (runTracks) {
    const { extractAllTracks } = require('./extract_track_data');
    const outPath = path.resolve(REPO_ROOT, 'tools', 'data', 'tracks.json');
    info(`Extracting track data from ${romPath} ...`);
    const data = extractAllTracks(romPath, verbose);
    if (!dryRun) {
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, JSON.stringify(data, null, 2));
      info(`Wrote: ${outPath}`);
    } else {
      info('  (dry-run: tracks.json not written)');
    }
  }

  if (runTeams) {
    const { extractTeamData } = require('./extract_team_data');
    const outPath = path.resolve(REPO_ROOT, 'tools', 'data', 'teams.json');
    info(`Extracting team data from ${romPath} ...`);
    const data = extractTeamData(romPath, verbose);
    if (!dryRun) {
      const output = {
        _meta: {
          description:    'Super Monaco GP team/car data — extracted from ROM binary',
          generated_by:   'tools/extract_game_data.js',
          format_version: 1,
        },
        ...data,
      };
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, JSON.stringify(output, null, 2));
      info(`Wrote: ${outPath}`);
    } else {
      info('  (dry-run: teams.json not written)');
    }
  }

  if (runChamp) {
    const { extractChampionshipData } = require('./extract_championship_data');
    const outPath = path.resolve(REPO_ROOT, 'tools', 'data', 'championship.json');
    info(`Extracting championship data from ${romPath} ...`);
    if (!dryRun) {
      extractChampionshipData(romPath, outPath, verbose);
      info(`Wrote: ${outPath}`);
    } else {
      info('  (dry-run: championship.json not written)');
    }
  }

  info('Done.');
}
