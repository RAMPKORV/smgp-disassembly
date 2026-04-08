#!/usr/bin/env node
// tools/inject_game_data.js
//
// Unified game-data injector: calls individual injectors to patch ROM/data files.
//
// Flags:
//   --tracks        Inject track data from tools/data/tracks.json -> data/tracks/
//   --teams         Inject team data from tools/data/teams.json -> out.bin
//   --championship  Inject championship data from tools/data/championship.json -> out.bin
//   --all           Inject all three (default if no flag given)
//   --dry-run       Compute changes but do not write any files
//   --rom <path>    ROM binary to patch (default: out.bin, for teams/championship)
//   -v / --verbose  Verbose output
//
// Usage:
//   node tools/inject_game_data.js [--tracks] [--teams] [--championship]
//                                  [--all] [--dry-run] [--rom out.bin] [-v]

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

  const verbose  = args.flags['--verbose'] || args.flags['-v'];
  const dryRun   = args.flags['--dry-run'];
  const romArg   = args.options['--rom'] || 'out.bin';
  const romPath  = path.resolve(REPO_ROOT, romArg);

  const anySubset = args.flags['--tracks'] || args.flags['--teams'] || args.flags['--championship'];
  const runTracks = args.flags['--tracks']       || args.flags['--all'] || !anySubset;
  const runTeams  = args.flags['--teams']        || args.flags['--all'] || !anySubset;
  const runChamp  = args.flags['--championship'] || args.flags['--all'] || !anySubset;

  if (runTracks) {
    const { injectTrack } = require('./inject_track_data');
    const jsonPath = path.resolve(REPO_ROOT, 'tools', 'data', 'tracks.json');
    const dataDir  = path.resolve(REPO_ROOT, 'data', 'tracks');

    if (!fs.existsSync(jsonPath)) die(`tracks JSON not found: ${jsonPath}`);

    const jsonData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const tracks = jsonData.tracks || [];
    info(`Injecting ${tracks.length} tracks${dryRun ? ' (dry-run)' : ''} ...`);

    let totalChanged = 0;
    let totalSizeChanges = 0;
    const errors = [];

    for (const track of tracks) {
      try {
        const results = injectTrack(track, dataDir, dryRun, verbose);
        for (const { oldSize, newSize, changed } of Object.values(results)) {
          if (changed) totalChanged++;
          if (oldSize !== newSize) totalSizeChanges++;
        }
      } catch (err) {
        errors.push([track.slug, err]);
        process.stderr.write(`  ERROR: ${track.slug}: ${err.message}\n`);
      }
    }

    if (errors.length > 0) {
      process.stderr.write(`${errors.length} track(s) had errors.\n`);
      process.exit(1);
    }

    if (totalChanged === 0) {
      info('Tracks: no files changed (no-op round-trip).');
    } else {
      info(`Tracks: ${totalChanged} file(s) updated (${totalSizeChanges} with size changes).`);
    }
  }

  if (runTeams) {
    const { injectTeamData } = require('./inject_team_data');
    const jsonPath = path.resolve(REPO_ROOT, 'tools', 'data', 'teams.json');

    if (!fs.existsSync(jsonPath)) die(`teams JSON not found: ${jsonPath}`);
    if (!fs.existsSync(romPath))  die(`ROM not found: ${romPath}`);

    info(`Injecting team data into ${romPath}${dryRun ? ' (dry-run)' : ''} ...`);
    const changed = injectTeamData(jsonPath, romPath, dryRun, verbose);

    if (changed === 0) {
      info('Teams: 0 bytes changed (no-op round-trip).');
    } else {
      info(`Teams: ${changed} bytes changed.`);
    }
  }

  if (runChamp) {
    const { injectChampionshipData } = require('./inject_championship_data');
    const jsonPath = path.resolve(REPO_ROOT, 'tools', 'data', 'championship.json');

    if (!fs.existsSync(jsonPath)) die(`championship JSON not found: ${jsonPath}`);
    if (!fs.existsSync(romPath))  die(`ROM not found: ${romPath}`);

    info(`Injecting championship data into ${romPath}${dryRun ? ' (dry-run)' : ''} ...`);
    const changed = injectChampionshipData(jsonPath, romPath, dryRun, verbose);

    if (changed === 0) {
      info('Championship: 0 bytes changed (no-op round-trip).');
    } else {
      info(`Championship: ${changed} bytes changed.`);
    }
  }

  if (!dryRun) {
    info('Done. Run verify.bat to confirm bit-perfect build.');
  } else {
    info('Dry-run complete.');
  }
}
