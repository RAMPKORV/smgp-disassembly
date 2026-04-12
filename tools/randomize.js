#!/usr/bin/env node
// tools/randomize.js
//
// RAND-010: Unified randomizer CLI entry point.
//
// Accepts a seed string, parses flag bits, runs selected randomizer modules.
// On master, the safe/default path is workspace-only: randomized ROMs are built
// via tools/hack_workdir.js so the root source tree remains canonical.
// An explicit in-root mode is still available for debugging only.
//
// Seed format:  SMGP-<version>-<flags_hex>-<decimal_seed>
//   e.g.  SMGP-1-01-12345
//
// Flag bits:
//   0x01  RAND_TRACKS      Randomize track curve/slope/sign/minimap data
//   0x02  RAND_CONFIG      Randomize track art/config (bg art, road/sideline styles,
//                           palette, horizon flag, steering)
//   0x04  RAND_TEAMS       Randomize team/car stats
//   0x08  RAND_AI          Randomize AI parameters
//   0x10  RAND_CHAMPIONSHIP Randomize race order
//   0x20  RAND_SIGNS       Randomize sign IDs only (subset of RAND_TRACKS) [not yet]
//
// Usage:
//   node tools/randomize.js SMGP-1-01-12345                 # workspace-safe default
//   node tools/randomize.js SMGP-1-01-12345 --output build/roms/latest_randomized.bin
//   node tools/randomize.js SMGP-1-03-12345    # tracks + art config
//   node tools/randomize.js SMGP-1-01-12345 --dry-run
//   node tools/randomize.js SMGP-1-01-12345 --tracks san_marino france
//   node tools/randomize.js SMGP-1-01-12345 --no-build --verbose
//   node tools/randomize.js SMGP-1-01-12345 --in-root      # debugging only
//   node tools/randomize.js SMGP-1-01-12345 --workspace-build

'use strict';

const path = require('path');
const { execFileSync } = require('child_process');

const { REPO_ROOT }  = require('./lib/rom');
const { parseArgs, die, printUsage } = require('./lib/cli');
const { assertNoActiveCheckpointArtifacts } = require('./lib/in_root_checkpoint');
const { buildRandomizePlan } = require('./randomizer_plan');
const { runRootBuildFlow } = require('./randomize_build');
const { createInRootCheckpointSession } = require('./randomize_actions');
const {
	runTracksModule,
	runConfigModule,
	runTeamsModule,
	runAiModule,
	runChampionshipModule,
} = require('./randomize_modules');

function runWorkspaceDefault(argv) {
	const workspaceScript = path.join(REPO_ROOT, 'tools', 'hack_workdir.js');
	const forwarded = Array.from(argv);
	if (!forwarded.includes('--output') && !forwarded.some(arg => arg.startsWith('--output='))) {
		forwarded.push('--output', path.join('build', 'roms', 'latest_randomized.bin'));
	}
	if (!forwarded.includes('--force')) {
		forwarded.push('--force');
	}
	try {
		execFileSync(process.execPath, [workspaceScript, ...forwarded], {
			cwd: REPO_ROOT,
			stdio: 'inherit',
		});
	} catch (error) {
		process.exit(error.status || 1);
	}
	process.exit(0);
}

const {
	FLAG_TRACKS,
	FLAG_SIGNS,
} = require('./randomizer/track_randomizer');

const USAGE_TEXT = [
	'Usage: node tools/randomize.js [seed] [options]',
	'',
	'Safe default:',
	'  node tools/randomize.js SMGP-1-01-12345',
	'',
	'Options:',
	'  --dry-run          Show the planned workspace-safe run without building',
	'  --tracks <list>    Restrict track randomization to selected slugs',
	'  --input <path>     Use an alternate tracks JSON input',
	'  --no-build         Skip the in-root ROM build step',
	'  --in-root          Run the randomizer in the repo root (debug only)',
	'  --workspace-build  Internal flag used by workspace builds',
	'  --json             Forward machine-readable dry-run output in workspace-safe mode',
	'  --verbose, -v      Show additional progress output',
	'  --help, -h         Show this help text',
].join('\n');

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
	const rawArgv = process.argv.slice(2);
	if (rawArgv.includes('--help') || rawArgv.includes('-h')) {
		printUsage(USAGE_TEXT);
		return;
	}
	if (rawArgv.includes('--json') && !rawArgv.includes('--dry-run')) {
		die('--json currently requires --dry-run in tools/randomize.js.');
	}
	const shouldUseWorkspaceDefault = rawArgv.length > 0
		&& !rawArgv.includes('--in-root')
		&& !rawArgv.includes('--workspace-build')
		&& !rawArgv.includes('--help')
		&& !rawArgv.includes('-h');
	if (shouldUseWorkspaceDefault) {
		runWorkspaceDefault(rawArgv);
	}

  const args = parseArgs(process.argv.slice(2), {
	flags:   ['--dry-run', '--no-build', '--workspace-build', '--in-root', '--json', '--verbose', '-v', '--help', '-h'],
    options: ['--tracks', '--input'],
  });

  const dryRun         = args.flags['--dry-run'];
  const noBuild        = args.flags['--no-build'];
  const workspaceBuild = args.flags['--workspace-build'];
  const jsonOut        = args.flags['--json'];
  const verbose        = args.flags['--verbose'] || args.flags['-v'];
  const build          = !noBuild && !workspaceBuild;

	if (jsonOut && (args.flags['--in-root'] || workspaceBuild)) {
		die('--json is only supported for workspace-safe default mode. Omit --in-root/--workspace-build.');
	}

	const positional = args.positional || [];
  let plan;
  try {
    plan = buildRandomizePlan({
      seedStr: positional[0] || 'SMGP-1-01-12345',
      inputArg: args.options['--input'] || null,
      tracksArg: args.options['--tracks'] || null,
    });
  } catch (err) {
	die(err.message);
  }

	const { seedStr, version, flags, seedInt, inputPath, trackSlugs } = plan;
	let checkpointSession = null;
	if (args.flags['--in-root'] && !dryRun && flags !== 0) {
		assertNoActiveCheckpointArtifacts(REPO_ROOT);
		checkpointSession = createInRootCheckpointSession({
			seed: seedStr,
			argv: rawArgv,
		});
		console.log(`Checkpoint: ${path.relative(REPO_ROOT, checkpointSession.manifestPath)}`);
	}

  console.log(`Seed    : ${seedStr}`);
  console.log(`Version : ${version}`);
  console.log(`Flags   : 0x${flags.toString(16).toUpperCase().padStart(2, '0')}  (${plan.flagSummary})`);
  console.log(`Seed int: ${seedInt}`);

  runTracksModule({
    flags,
    inputPath,
    trackSlugs,
    randomizedTrackCount: plan.randomizedTrackCount,
    seedInt,
    verbose,
    dryRun,
		checkpointSession,
  });

	runConfigModule({ flags, seedInt, verbose, dryRun, checkpointSession });
	runTeamsModule({ flags, seedInt, verbose, dryRun, checkpointSession });
	runAiModule({ flags, seedInt, verbose, dryRun, checkpointSession });
	runChampionshipModule({ flags, seedInt, verbose, dryRun, checkpointSession });

  // Unimplemented flags: warn if set
  if (flags & FLAG_SIGNS) {
    console.log('  NOTE: RAND_SIGNS (0x20) flag set but not yet implemented — skipped.');
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  if (dryRun) {
    console.log('\nDone (dry run — ROM not built).');
    return;
  }

	if (build) {
		const buildResult = runRootBuildFlow({
			rootDir: REPO_ROOT,
			trackFlagsEnabled: (flags & FLAG_TRACKS) !== 0,
			inputPath,
			allowRootMutation: args.flags['--in-root'],
		});
    if (!buildResult.ok) {
      if (buildResult.stage === 'minimap') {
        process.stderr.write('ERROR: generated minimap ROM patch FAILED.\n');
      } else {
        process.stderr.write('ERROR: build.bat FAILED.\n');
      }
      process.exit(1);
    }
  } else if (workspaceBuild) {
    console.log('\n[BUILD] Skipped (--workspace-build).');
    console.log('  Workspace parent tool will assemble the ROM after source updates.');
	} else {
	    console.log('\n[BUILD] Skipped (--no-build).');
	    console.log('  Run: powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\\build.bat"  to assemble the ROM.');
	    if (flags & FLAG_TRACKS) {
	      console.log('  NOTE: Generated minimap marker-path patches are only applied when a ROM is built.');
	    }
	  }

	console.log(`\nDone.  Seed: ${seedStr}`);
	if (checkpointSession) console.log('  NOTE: Run  node tools/restore_tracks.js  to restore the original ROM and clear the in-root checkpoint.');
	else console.log('  NOTE: Run  node tools/restore_tracks.js  to restore the original ROM.');
}

main();
