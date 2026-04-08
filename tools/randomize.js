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

const fs            = require('fs');
const path          = require('path');
const { execFileSync } = require('child_process');

const { REPO_ROOT }  = require('./lib/rom');
const { parseArgs, die } = require('./lib/cli');
const { patchRomChecksum } = require('./patch_rom_checksum');

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

const { injectTrack }            = require('./inject_track_data');
const { injectTeamData }         = require('./inject_team_data');
const { injectChampionshipData } = require('./inject_championship_data');
const { buildSyncedTrackConfig, TRACK_NAMES } = require('./sync_track_config');
const { buildGeneratedTrackBlock, GENERATED_MINIMAP_DATA_FILE } = require('./generate_track_data_asm');
const { buildGeneratedMinimapAssetsAsm } = require('./lib/generated_minimap_assets');
const { buildAsm: buildGeneratedMinimapMapAsm } = require('./write_generated_minimap_assets');

const {
  parseSeed,
  FLAG_TRACKS, FLAG_TRACK_CONFIG, FLAG_TEAMS, FLAG_AI,
  FLAG_CHAMPIONSHIP, FLAG_SIGNS,
  randomizeTracks, randomizeArtConfig, injectArtConfig,
} = require('./randomizer/track_randomizer');

const { validateTracks }       = require('./randomizer/track_validator');
const { randomizeTeams, randomizeAi, validateTeams } = require('./randomizer/team_randomizer');
const { randomizeChampionship, validateChampionship } = require('./randomizer/championship_randomizer');
const { validateAllTracks }    = require('./minimap_validate');

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const TOOLS_DIR       = path.join(REPO_ROOT, 'tools');
const TRACKS_JSON     = path.join(TOOLS_DIR, 'data', 'tracks.json');
const TRACKS_ORIG     = path.join(TOOLS_DIR, 'data', 'tracks.orig.json');
const TEAMS_JSON      = path.join(TOOLS_DIR, 'data', 'teams.json');
const TEAMS_ORIG      = path.join(TOOLS_DIR, 'data', 'teams.orig.json');
const CHAMP_JSON      = path.join(TOOLS_DIR, 'data', 'championship.json');
const CHAMP_ORIG      = path.join(TOOLS_DIR, 'data', 'championship.orig.json');
const ART_CONFIG_ASM  = path.join(REPO_ROOT, 'src', 'track_config_data.asm');
const ART_CONFIG_ORIG = path.join(REPO_ROOT, 'src', 'track_config_data.orig.asm');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function parseLstSymbolMapFromText(text) {
	const map = new Map();
	for (const line of text.split(/\r?\n/)) {
		const m = line.match(/^([0-9A-F]{8})\s+.*?\b([A-Za-z_][A-Za-z0-9_]*):\s*$/);
		if (m) map.set(m[2], parseInt(m[1], 16));
	}
	return map;
}

function loadBaselineSymbolMap() {
	const maps = [];
	const lstPath = path.join(REPO_ROOT, 'smgp_head.lst');
	if (fs.existsSync(lstPath)) {
		maps.push(parseLstSymbolMapFromText(fs.readFileSync(lstPath, 'utf8')));
	}
	const jsonPath = path.join(REPO_ROOT, 'tools', 'index', 'symbol_map.json');
	if (fs.existsSync(jsonPath)) {
		const json = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
		const symbols = json && typeof json === 'object' ? json.symbols : null;
		if (symbols && typeof symbols === 'object') {
			const map = new Map();
			for (const [name, value] of Object.entries(symbols)) {
				if (typeof value !== 'string') continue;
				map.set(name, parseInt(value.replace(/^0x/i, ''), 16));
			}
			maps.push(map);
		}
	}
	if (maps.length === 0) return null;
	const merged = new Map();
	for (const map of maps) {
		for (const [name, value] of map.entries()) {
			if (!merged.has(name)) merged.set(name, value);
		}
	}
	return merged;
}

function getBaselineTrackBlockLayout() {
	const symbolMap = loadBaselineSymbolMap();
	if (!symbolMap) return null;
	const start = symbolMap.get('San_Marino_curve_data');
	const blob = symbolMap.get('Monaco_arcade_post_sign_tileset_blob');
	if (start === undefined || blob === undefined || blob < start) return null;
	const blobPath = path.join(REPO_ROOT, 'data', 'tracks', 'monaco_arcade', 'post_sign_tileset_blob.bin');
	if (!fs.existsSync(blobPath)) return null;
	return {
		blobRelative: blob - start,
		fullSize: (blob - start) + fs.statSync(blobPath).size,
	};
}

function measureGeneratedTrackBlockLayout() {
	const generatedPath = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
	if (!fs.existsSync(generatedPath)) return null;
	const text = fs.readFileSync(generatedPath, 'utf8');
	let total = 0;
	let blobStart = null;
	for (const line of text.split(/\r?\n/)) {
		if (/^\s*Monaco_arcade_post_sign_tileset_blob:/i.test(line)) {
			blobStart = total;
			continue;
		}
		const incbin = line.match(/^\s*incbin\s+\"([^\"]+)\"/i);
		if (incbin) {
			const binPath = path.join(REPO_ROOT, incbin[1]);
			if (fs.existsSync(binPath)) total += fs.statSync(binPath).size;
			continue;
		}
		const dcb = line.match(/^\s*dcb\.b\s+(\d+)\s*,/i);
		if (dcb) total += parseInt(dcb[1], 10);
	}
	return { blobStart, fullSize: total };
}

function writeGeneratedTrackBlockPreservingBaseline(options = {}) {
	const includeGeneratedMinimapData = options.includeGeneratedMinimapData !== false;
	const generatedTrackAsm = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
	const baseline = getBaselineTrackBlockLayout();
	fs.writeFileSync(generatedTrackAsm, buildGeneratedTrackBlock({ includeGeneratedMinimapData }), 'utf8');
	if (!baseline) return { padBytes: 0, preBlobPadBytes: 0 };
	const current = measureGeneratedTrackBlockLayout();
	if (!current) return { padBytes: 0, preBlobPadBytes: 0 };
	const preBlobPadBytes = current.blobStart === null ? 0 : Math.max(0, baseline.blobRelative - current.blobStart);
	const padBytes = Math.max(0, baseline.fullSize - current.fullSize - preBlobPadBytes);
	if (preBlobPadBytes > 0 || padBytes > 0) {
		fs.writeFileSync(generatedTrackAsm, buildGeneratedTrackBlock({ preBlobPadBytes, padBytes, includeGeneratedMinimapData }), 'utf8');
	}
	return { padBytes, preBlobPadBytes };
}

function writeGeneratedMinimapAssetsFile(tracks) {
	const outputPath = path.join(REPO_ROOT, GENERATED_MINIMAP_DATA_FILE);
	fs.mkdirSync(path.dirname(outputPath), { recursive: true });
	fs.writeFileSync(outputPath, buildGeneratedMinimapMapAsm(tracks), 'utf8');
	return outputPath;
}

function flagSummary(flags) {
  const names = [];
  if (flags & FLAG_TRACKS)       names.push('TRACKS');
  if (flags & FLAG_TRACK_CONFIG) names.push('CONFIG');
  if (flags & FLAG_TEAMS)        names.push('TEAMS');
  if (flags & FLAG_AI)           names.push('AI');
  if (flags & FLAG_CHAMPIONSHIP) names.push('CHAMPIONSHIP');
  if (flags & FLAG_SIGNS)        names.push('SIGNS');
  return names.length > 0 ? names.join(', ') : '(none)';
}

function runBuild() {
  let stdout = '';
  let stderr = '';
  let exitCode = 0;
  try {
    stdout = execFileSync('cmd', ['/c', 'build.bat'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (err) {
    stdout = err.stdout || '';
    stderr = err.stderr || '';
    exitCode = err.status || 1;
  }
  const combined = stdout + stderr;
  if (exitCode !== 0) return [false, combined];
  if (combined.includes('0 error(s)')) return [true, combined];
  return [false, combined];
}

function runNodeTool(scriptName, args) {
  let stdout = '';
  let stderr = '';
  let exitCode = 0;
  const scriptPath = path.join(TOOLS_DIR, scriptName);
  try {
    stdout = execFileSync(process.execPath, [scriptPath, ...args], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (err) {
    stdout = err.stdout || '';
    stderr = err.stderr || '';
    exitCode = err.status || 1;
  }
  return {
    ok: exitCode === 0,
    output: stdout + stderr,
    exitCode,
  };
}

function patchGeneratedMinimapRom(romPath, inputPath) {
	const steps = [
		{
			label: 'tiles',
			script: 'patch_all_track_minimap_assets_rom.js',
			args: ['--rom', romPath, '--input', inputPath],
		},
		{
			label: 'raw maps',
			script: 'patch_all_track_minimap_raw_maps_rom.js',
			args: ['--rom', romPath, '--input', inputPath],
		},
    {
      label: 'marker path',
      script: 'patch_generated_minimap_pos_rom.js',
      args: ['--all', '--rom', romPath, '--input', inputPath],
    },
  ];

  const results = [];
  for (const step of steps) {
    const result = runNodeTool(step.script, step.args);
    results.push({ ...step, ...result });
    if (!result.ok) {
      return {
        ok: false,
        steps: results,
      };
    }
  }

  return {
    ok: true,
    steps: results,
  };
}

function validateGeneratedMinimaps(tracksData, selectedTracks) {
	const report = validateAllTracks({ tracks: selectedTracks });
	const failures = [];
	for (const entry of report.tracks) {
		if (entry.flags.candidate_marker_offroad) {
			failures.push(`[${entry.track.slug}] candidate marker alignment failed (${entry.metrics.candidate_marker_mean_distance}, ${entry.metrics.candidate_marker_hit_percent}%)`);
		}
	}
	return { report, failures };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
	const rawArgv = process.argv.slice(2);
	const shouldUseWorkspaceDefault = rawArgv.length > 0
		&& !rawArgv.includes('--in-root')
		&& !rawArgv.includes('--workspace-build')
		&& !rawArgv.includes('--help')
		&& !rawArgv.includes('-h');
	if (shouldUseWorkspaceDefault) {
		runWorkspaceDefault(rawArgv);
	}

  const args = parseArgs(process.argv.slice(2), {
    flags:   ['--dry-run', '--no-build', '--workspace-build', '--in-root', '--verbose', '-v'],
    options: ['--tracks', '--input'],
  });

  const dryRun         = args.flags['--dry-run'];
  const noBuild        = args.flags['--no-build'];
  const workspaceBuild = args.flags['--workspace-build'];
  const verbose        = args.flags['--verbose'] || args.flags['-v'];
  const build          = !noBuild && !workspaceBuild;

  const positional = args.positional || [];
  const seedStr = positional[0] || 'SMGP-1-01-12345';

  // Parse seed
  let version, flags, seedInt;
  try {
    [version, flags, seedInt] = parseSeed(seedStr);
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    process.exit(1);
  }

  console.log(`Seed    : ${seedStr}`);
  console.log(`Version : ${version}`);
  console.log(`Flags   : 0x${flags.toString(16).toUpperCase().padStart(2, '0')}  (${flagSummary(flags)})`);
  console.log(`Seed int: ${seedInt}`);

  // Resolve input tracks JSON
  const inputArg  = args.options['--input'] || null;
  const inputPath = inputArg
    ? path.resolve(REPO_ROOT, inputArg)
    : TRACKS_JSON;

  const tracksArg = args.options['--tracks'] || null;
  const trackSlugs = tracksArg ? new Set(tracksArg.split(/\s+/).filter(Boolean)) : null;

  // -------------------------------------------------------------------------
  // RAND_TRACKS (0x01)
  // -------------------------------------------------------------------------
  if (flags & FLAG_TRACKS) {
    if (!fs.existsSync(inputPath)) {
      process.stderr.write(`ERROR: tracks JSON not found: ${inputPath}\n`);
      process.exit(1);
    }
    const tracksData = JSON.parse(fs.readFileSync(inputPath, 'utf8'));

    const nTracks = tracksData.tracks.filter(
      t => trackSlugs === null || trackSlugs.has(t.slug)
    ).length;
    console.log(`\n[RAND_TRACKS] Randomizing ${nTracks} track(s) ...`);

    randomizeTracks(tracksData, seedInt, trackSlugs, verbose);

    // Validate
    const targetTracks = tracksData.tracks.filter(
      t => trackSlugs === null || trackSlugs.has(t.slug)
    );
	    const errors = validateTracks(targetTracks);
	    if (errors.length > 0) {
	      console.log(`\nValidation FAILED: ${errors.length} error(s):`);
	      for (const e of errors) console.log(`  ${e}`);
	      process.exit(1);
	    }
	    console.log(`Validation passed (${targetTracks.length} track(s)).`);

		const minimapValidation = validateGeneratedMinimaps(tracksData, targetTracks);
		if (minimapValidation.failures.length > 0) {
			console.log(`\nGenerated minimap validation FAILED: ${minimapValidation.failures.length} issue(s):`);
			for (const failure of minimapValidation.failures) console.log(`  ${failure}`);
			process.exit(1);
		}
		console.log(`Generated minimap validation passed (${targetTracks.length} track(s)).`);

	    if (dryRun) {
	      console.log('\nDRY RUN — skipping inject and build.');
    } else {
      // Back up original tracks.json before overwriting
      if (!fs.existsSync(TRACKS_ORIG)) {
        fs.copyFileSync(inputPath, TRACKS_ORIG);
        console.log(`Backed up original JSON: ${path.basename(TRACKS_ORIG)}`);
      }

      // Write randomized tracks.json
      fs.writeFileSync(inputPath, JSON.stringify(tracksData, null, 2), 'utf8');
      console.log(`Written: ${path.basename(inputPath)}`);

      // Sync Track_data metadata (track length, etc.) from JSON into ASM
      const trackConfigLines = fs.readFileSync(ART_CONFIG_ASM, 'utf8').split(/(?<=\n)/);
      const syncResult = buildSyncedTrackConfig(trackConfigLines, tracksData);
      fs.writeFileSync(ART_CONFIG_ASM, syncResult.content, 'utf8');
      console.log(`Synced Track_data metadata in ${path.basename(ART_CONFIG_ASM)} (${syncResult.changed} line(s) changed).`);

      // Inject modified tracks into data/tracks/
      console.log('\n[INJECT] Writing data/tracks/ binaries ...');
      const dataDir = path.join(REPO_ROOT, 'data', 'tracks');
      let totalChanged = 0;
	      for (const track of targetTracks) {
	        const results = injectTrack(track, dataDir, false, verbose);
	        totalChanged += Object.values(results).filter(r => r.changed).length;
	      }
	      console.log(`  ${totalChanged} file(s) updated.`);

	      const generatedMinimapAsm = writeGeneratedMinimapAssetsFile(tracksData.tracks);
	      console.log(`Generated: ${path.relative(REPO_ROOT, generatedMinimapAsm)}`);

	      const generatedTrackAsm = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
	      const layout = writeGeneratedTrackBlockPreservingBaseline({
	        includeGeneratedMinimapData: false,
	      });
      const padSummary = (layout.padBytes > 0 || layout.preBlobPadBytes > 0)
        ? ` (pre-blob pad ${layout.preBlobPadBytes}, end pad ${layout.padBytes})`
        : '';
      console.log(`Generated: ${path.basename(generatedTrackAsm)}${padSummary}`);
    }
  } else {
    console.log('\n[RAND_TRACKS] flag not set — skipping track randomization.');
  }

  // -------------------------------------------------------------------------
  // RAND_CONFIG (0x02)
  // -------------------------------------------------------------------------
  if (flags & FLAG_TRACK_CONFIG) {
    console.log('\n[RAND_CONFIG] Shuffling art/config assignment for 16 championship tracks ...');
    const artAssignment = randomizeArtConfig(seedInt, verbose);

    if (dryRun) {
      console.log('  DRY RUN — not rewriting track_config_data.asm.');
    } else {
      // Back up original track_config_data.asm before overwriting
      if (!fs.existsSync(ART_CONFIG_ORIG)) {
        fs.copyFileSync(ART_CONFIG_ASM, ART_CONFIG_ORIG);
        console.log(`  Backed up: ${path.basename(ART_CONFIG_ORIG)}`);
      }

      injectArtConfig(artAssignment, REPO_ROOT, false, verbose);
      console.log('  Art assignment written to src/track_config_data.asm.');
    }
  } else {
    console.log('\n[RAND_CONFIG] flag not set — skipping art/config shuffle.');
  }

  // -------------------------------------------------------------------------
  // RAND_TEAMS (0x04)
  // -------------------------------------------------------------------------
  if (flags & FLAG_TEAMS) {
    if (!fs.existsSync(TEAMS_JSON)) {
      process.stderr.write(`ERROR: teams JSON not found: ${TEAMS_JSON}\n`);
      process.exit(1);
    }
    let teamsData = JSON.parse(fs.readFileSync(TEAMS_JSON, 'utf8'));

    console.log('\n[RAND_TEAMS] Randomizing team car stats ...');
    randomizeTeams(teamsData, seedInt, verbose);

    const teamErrors = validateTeams(teamsData);
    if (teamErrors.length > 0) {
      console.log(`\nTeam validation FAILED: ${teamErrors.length} error(s):`);
      for (const e of teamErrors) console.log(`  ${e}`);
      process.exit(1);
    }
    console.log('Team validation passed.');

    if (dryRun) {
      console.log('  DRY RUN — not writing teams.json or patching ROM.');
    } else {
      // Back up original teams.json
      if (!fs.existsSync(TEAMS_ORIG)) {
        fs.copyFileSync(TEAMS_JSON, TEAMS_ORIG);
        console.log(`  Backed up original JSON: ${path.basename(TEAMS_ORIG)}`);
      }

      fs.writeFileSync(TEAMS_JSON, JSON.stringify(teamsData, null, 2), 'utf8');
      console.log(`  Written: ${path.basename(TEAMS_JSON)}`);

      const romPath = path.join(REPO_ROOT, 'out.bin');
      if (fs.existsSync(romPath)) {
        console.log(`  Patching ${path.basename(romPath)} ...`);
        const changed = injectTeamData(TEAMS_JSON, romPath, false, verbose);
        console.log(`  ${changed} byte(s) changed in ROM.`);
      } else {
        console.log(`  NOTE: ${path.basename(romPath)} not found — build first, then re-run inject.`);
      }
    }
  } else {
    console.log('\n[RAND_TEAMS] flag not set — skipping team stats randomization.');
  }

  // -------------------------------------------------------------------------
  // RAND_AI (0x08)
  // -------------------------------------------------------------------------
  if (flags & FLAG_AI) {
    if (!fs.existsSync(TEAMS_JSON)) {
      process.stderr.write(`ERROR: teams JSON not found: ${TEAMS_JSON}\n`);
      process.exit(1);
    }

    // Load fresh (or already-modified by FLAG_TEAMS) teams data
    let teamsDataAi = JSON.parse(fs.readFileSync(TEAMS_JSON, 'utf8'));

    console.log('\n[RAND_AI] Randomizing AI parameters ...');
    randomizeAi(teamsDataAi, seedInt, verbose);

    const aiErrors = validateTeams(teamsDataAi);
    if (aiErrors.length > 0) {
      console.log(`\nAI validation FAILED: ${aiErrors.length} error(s):`);
      for (const e of aiErrors) console.log(`  ${e}`);
      process.exit(1);
    }
    console.log('AI validation passed.');

    if (dryRun) {
      console.log('  DRY RUN — not writing teams.json or patching ROM.');
    } else {
      // Back up only if not already done by FLAG_TEAMS
      if (!fs.existsSync(TEAMS_ORIG)) {
        fs.copyFileSync(TEAMS_JSON, TEAMS_ORIG);
        console.log(`  Backed up original JSON: ${path.basename(TEAMS_ORIG)}`);
      }

      fs.writeFileSync(TEAMS_JSON, JSON.stringify(teamsDataAi, null, 2), 'utf8');
      console.log(`  Written: ${path.basename(TEAMS_JSON)}`);

      const romPath = path.join(REPO_ROOT, 'out.bin');
      if (fs.existsSync(romPath)) {
        console.log(`  Patching ${path.basename(romPath)} ...`);
        const changed = injectTeamData(TEAMS_JSON, romPath, false, verbose);
        console.log(`  ${changed} byte(s) changed in ROM.`);
      } else {
        console.log(`  NOTE: ${path.basename(romPath)} not found — build first, then re-run inject.`);
      }
    }
  } else {
    console.log('\n[RAND_AI] flag not set — skipping AI parameter randomization.');
  }

  // -------------------------------------------------------------------------
  // RAND_CHAMPIONSHIP (0x10)
  // -------------------------------------------------------------------------
  if (flags & FLAG_CHAMPIONSHIP) {
    if (!fs.existsSync(CHAMP_JSON)) {
      process.stderr.write(`ERROR: championship JSON not found: ${CHAMP_JSON}\n`);
      process.exit(1);
    }
    let champData = JSON.parse(fs.readFileSync(CHAMP_JSON, 'utf8'));

    console.log('\n[RAND_CHAMPIONSHIP] Randomizing championship progression ...');
    randomizeChampionship(champData, seedInt, verbose);

    const champErrors = validateChampionship(champData);
    if (champErrors.length > 0) {
      console.log(`\nChampionship validation FAILED: ${champErrors.length} error(s):`);
      for (const e of champErrors) console.log(`  ${e}`);
      process.exit(1);
    }
    console.log('Championship validation passed.');

    if (dryRun) {
      console.log('  DRY RUN — not writing championship.json or patching ROM.');
    } else {
      // Back up original championship.json
      if (!fs.existsSync(CHAMP_ORIG)) {
        fs.copyFileSync(CHAMP_JSON, CHAMP_ORIG);
        console.log(`  Backed up original JSON: ${path.basename(CHAMP_ORIG)}`);
      }

      fs.writeFileSync(CHAMP_JSON, JSON.stringify(champData, null, 2), 'utf8');
      console.log(`  Written: ${path.basename(CHAMP_JSON)}`);

      const romPath = path.join(REPO_ROOT, 'out.bin');
      if (fs.existsSync(romPath)) {
        console.log(`  Patching ${path.basename(romPath)} ...`);
        const changed = injectChampionshipData(CHAMP_JSON, romPath, false, verbose);
        console.log(`  ${changed} byte(s) changed in ROM.`);
      } else {
        console.log(`  NOTE: ${path.basename(romPath)} not found — build first, then re-run inject.`);
      }
    }
  } else {
    console.log('\n[RAND_CHAMPIONSHIP] flag not set — skipping championship randomization.');
  }

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
    console.log('\n[BUILD] Running build.bat ...');
    const [ok, output] = runBuild();
    for (const line of output.split('\n')) {
      if (line.trim()) console.log(`  ${line}`);
    }
    if (ok) {
      console.log('Build succeeded — out.bin ready.');
      const romPath = path.join(REPO_ROOT, 'out.bin');
      if (fs.existsSync(romPath)) {
        const checksum = patchRomChecksum(romPath);
        console.log(`  Header checksum ${checksum.changed ? 'patched' : 'verified'}: $${checksum.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> $${checksum.newChecksum.toString(16).toUpperCase().padStart(4, '0')}`);
	        if (flags & FLAG_TRACKS) {
	          console.log('\n[MINIMAP] Applying generated minimap ROM patches ...');
	          console.log('  NOTE: Generated minimap assets are now appended/relocated for randomized ROM builds; ROM size may grow beyond 512 KiB.');
	          const minimapPatch = patchGeneratedMinimapRom(romPath, inputPath);
	          for (const step of minimapPatch.steps) {
	            console.log(`  ${step.label}: ${step.ok ? 'OK' : 'FAILED'}`);
            for (const line of step.output.split('\n')) {
              if (line.trim()) console.log(`    ${line}`);
            }
          }
          if (!minimapPatch.ok) {
            process.stderr.write('ERROR: generated minimap ROM patch FAILED.\n');
            process.exit(1);
          }
        }
        const size = fs.statSync(romPath).size;
        console.log(`  ROM size: ${size.toLocaleString()} bytes (${Math.floor(size / 1024)} KB)`);
      }
    } else {
      process.stderr.write('ERROR: build.bat FAILED.\n');
      process.exit(1);
    }
  } else if (workspaceBuild) {
    console.log('\n[BUILD] Skipped (--workspace-build).');
    console.log('  Workspace parent tool will assemble the ROM after source updates.');
  } else {
	    console.log('\n[BUILD] Skipped (--no-build).');
	    console.log('  Run: cmd /c build.bat  to assemble the ROM.');
	    if (flags & FLAG_TRACKS) {
	      console.log('  NOTE: Generated minimap marker-path patches are only applied when a ROM is built.');
	    }
	  }

  console.log(`\nDone.  Seed: ${seedStr}`);
  console.log('  NOTE: Run  node tools/restore_tracks.js  to restore the original ROM.');
}

main();
