#!/usr/bin/env node
// tools/restore_tracks.js
//
// Restores the original track, team, and championship data after in-root randomization.
//
// This script:
//   1. Restores tracked inputs from an explicit in-root checkpoint (if present)
//      or falls back to legacy *.orig.* backups
//   2. Re-injects the original track binaries into data/tracks/
//   3. Restores src/track_config_data.asm if a checkpoint/backup is present
//   4. Restores tools/data/teams.json if a checkpoint/backup is present
//   5. Re-injects the original team data into out.bin (if present)
//   6. Restores tools/data/championship.json if a checkpoint/backup is present
//   7. Re-injects the original championship data into out.bin (if present)
//   8. Optionally runs verify.bat to confirm bit-perfect ROM
//
// Usage:
//   node tools/restore_tracks.js [--verify] [-v]
//
// Note: master should normally use workspace-only randomized builds via
// tools/hack_workdir.js / tools/randomize.js default mode, so this script is
// mainly a debugging escape hatch for explicit --in-root runs.

'use strict';

const fs               = require('fs');
const path             = require('path');
const { parseArgs, printJson, printUsage }    = require('./lib/cli');
const { REPO_ROOT }    = require('./lib/rom');
const { runCanonicalVerify } = require('./lib/canonical_build');
const { listLegacyBackupFiles, readCheckpointManifest, restoreCheckpoint } = require('./lib/in_root_checkpoint');
const { injectTrack }            = require('./inject_track_data');
const { injectTeamData }         = require('./inject_team_data');
const { injectChampionshipData } = require('./inject_championship_data');
const { buildSyncedTrackConfig } = require('./sync_track_config');
const { buildGeneratedTrackBlock, GENERATED_MINIMAP_DATA_FILE } = require('./generate_track_data_asm');
const { buildAsm: buildGeneratedMinimapMapAsm } = require('./write_generated_minimap_assets');
const { getTracks, requireTracksDataShape } = require('./randomizer/track_model');

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
const USAGE_TEXT = [
	'Usage: node tools/restore_tracks.js [options]',
	'',
	'Options:',
	'  --verify           Run canonical verify after restoring data',
	'  --json             Emit a machine-readable summary',
	'  --verbose, -v      Show additional inject output',
	'  --help, -h         Show this help text',
].join('\n');

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  const args   = parseArgs(process.argv.slice(2), {
	flags:   ['--verify', '--json', '--verbose', '-v', '--help', '-h'],
    options: [],
  });
  const verify  = args.flags['--verify'];
  const jsonOut = args.flags['--json'];
  const verbose = args.flags['--verbose'] || args.flags['-v'];
	const log = jsonOut ? () => {} : console.log;
	const summary = {
		tool: 'restore_tracks',
		mode: 'restore',
		verifyRequested: verify,
		checkpointManifest: 'missing',
		checkpointRestoredFiles: [],
		legacyBackupFiles: [],
		tracksJsonBackup: 'missing',
		teamsJsonBackup: 'missing',
		championshipJsonBackup: 'missing',
		trackConfigBackup: 'missing',
		trackFilesRestored: 0,
		generatedFiles: [],
		teamBytesChanged: null,
		championshipBytesChanged: null,
		verify: {
			ran: false,
			ok: null,
			status: null,
		},
	};

	function fail(message, extra = {}) {
		if (jsonOut) {
			printJson(Object.assign({}, summary, extra, {
				ok: false,
				error: message,
			}));
		} else {
			process.stderr.write(`ERROR: ${message}\n`);
		}
		process.exit(1);
	}

	if (args.flags['--help'] || args.flags['-h']) {
		printUsage(USAGE_TEXT);
		return;
	}

	const checkpointManifest = readCheckpointManifest(REPO_ROOT);
	if (checkpointManifest) {
		summary.checkpointManifest = 'present';
		const restored = restoreCheckpoint({ repoRoot: REPO_ROOT, cleanup: true });
		summary.checkpointRestoredFiles = restored.restoredFiles;
		if (restored.restoredFiles.includes(path.relative(REPO_ROOT, TRACKS_JSON))) summary.tracksJsonBackup = 'restored';
		if (restored.restoredFiles.includes(path.relative(REPO_ROOT, TEAMS_JSON))) summary.teamsJsonBackup = 'restored';
		if (restored.restoredFiles.includes(path.relative(REPO_ROOT, CHAMP_JSON))) summary.championshipJsonBackup = 'restored';
		if (restored.restoredFiles.includes(path.relative(REPO_ROOT, ART_CONFIG_ASM))) summary.trackConfigBackup = 'restored';
		log(`Restored in-root checkpoint: ${path.relative(REPO_ROOT, restored.checkpointDir)}`);
	}
	summary.legacyBackupFiles = listLegacyBackupFiles(REPO_ROOT).map(filePath => path.relative(REPO_ROOT, filePath));

  // Step 1: restore tracks.json from backup
  if (summary.tracksJsonBackup !== 'restored' && fs.existsSync(TRACKS_ORIG)) {
    fs.copyFileSync(TRACKS_ORIG, TRACKS_JSON);
    fs.unlinkSync(TRACKS_ORIG);
		summary.tracksJsonBackup = 'restored';
		log('Restored: tools/data/tracks.json  (from tracks.orig.json)');
	} else if (summary.tracksJsonBackup !== 'restored') {
		log('No tracks.orig.json backup found — tracks.json may already be original.');
  }

  // Step 2: re-inject original track data into data/tracks/
  if (!fs.existsSync(TRACKS_JSON)) {
		fail(`tracks.json not found: ${TRACKS_JSON}`);
  }

	const tracksData = requireTracksDataShape(JSON.parse(fs.readFileSync(TRACKS_JSON, 'utf8')));
	const tracks = getTracks(tracksData);
	log('Re-injecting original track binaries into data/tracks/ ...');
	const dataDir = path.join(REPO_ROOT, 'data', 'tracks');
	let totalChanged = 0;
	for (const track of tracks) {
		const results = injectTrack(track, dataDir, false, verbose);
		totalChanged += Object.values(results).filter(r => r.changed).length;
	}
	summary.trackFilesRestored = totalChanged;
	log(`  ${totalChanged} file(s) restored.`);

  const generatedTrackAsm = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
  fs.writeFileSync(generatedTrackAsm, buildGeneratedTrackBlock(), 'utf8');
	summary.generatedFiles.push(path.relative(REPO_ROOT, generatedTrackAsm));
	log('Regenerated: src/road_and_track_data_generated.asm');

	const generatedMinimapAsm = path.join(REPO_ROOT, GENERATED_MINIMAP_DATA_FILE);
	fs.mkdirSync(path.dirname(generatedMinimapAsm), { recursive: true });
	fs.writeFileSync(generatedMinimapAsm, buildGeneratedMinimapMapAsm(tracks), 'utf8');
	summary.generatedFiles.push(path.relative(REPO_ROOT, generatedMinimapAsm));
	log(`Regenerated: ${path.relative(REPO_ROOT, generatedMinimapAsm)}`);

  // Step 3: restore track_config_data.asm from backup
  if (summary.trackConfigBackup !== 'restored' && fs.existsSync(ART_CONFIG_ORIG)) {
    fs.copyFileSync(ART_CONFIG_ORIG, ART_CONFIG_ASM);
    fs.unlinkSync(ART_CONFIG_ORIG);
		summary.trackConfigBackup = 'restored';
		log('Restored: src/track_config_data.asm  (from track_config_data.orig.asm)');
	} else if (summary.trackConfigBackup !== 'restored') {
    const trackConfigLines = fs.readFileSync(ART_CONFIG_ASM, 'utf8').split(/(?<=\n)/);
    const syncResult = buildSyncedTrackConfig(trackConfigLines, tracksData);
    fs.writeFileSync(ART_CONFIG_ASM, syncResult.content, 'utf8');
		summary.trackConfigBackup = 'synced';
		log(`Synced: src/track_config_data.asm  (${syncResult.changed} Track_data length line(s) updated from tracks.json)`);
  }

  // Step 4: restore teams.json from backup
  if (summary.teamsJsonBackup !== 'restored' && fs.existsSync(TEAMS_ORIG)) {
    fs.copyFileSync(TEAMS_ORIG, TEAMS_JSON);
    fs.unlinkSync(TEAMS_ORIG);
		summary.teamsJsonBackup = 'restored';
		log('Restored: tools/data/teams.json  (from teams.orig.json)');
	} else if (summary.teamsJsonBackup !== 'restored') {
		log('No teams.orig.json backup found — teams.json may already be original.');
  }

  // Step 5: re-inject original team data into out.bin (if it exists)
  const romPath = path.join(REPO_ROOT, 'out.bin');
  if (fs.existsSync(TEAMS_JSON) && fs.existsSync(romPath)) {
		log('Re-injecting original team data into out.bin ...');
    const changed = injectTeamData(TEAMS_JSON, romPath, false, verbose);
		summary.teamBytesChanged = changed;
		log(`  ${changed} byte(s) changed.`);
  } else if (!fs.existsSync(romPath)) {
		log('out.bin not found — skipping team data injection (build first).');
  }

  // Step 6: restore championship.json from backup
  if (summary.championshipJsonBackup !== 'restored' && fs.existsSync(CHAMP_ORIG)) {
    fs.copyFileSync(CHAMP_ORIG, CHAMP_JSON);
    fs.unlinkSync(CHAMP_ORIG);
		summary.championshipJsonBackup = 'restored';
		log('Restored: tools/data/championship.json  (from championship.orig.json)');
	} else if (summary.championshipJsonBackup !== 'restored') {
		log('No championship.orig.json backup found — championship.json may already be original.');
  }

  // Step 7: re-inject original championship data into out.bin (if it exists)
  if (fs.existsSync(CHAMP_JSON) && fs.existsSync(romPath)) {
		log('Re-injecting original championship data into out.bin ...');
    const changed = injectChampionshipData(CHAMP_JSON, romPath, false, verbose);
		summary.championshipBytesChanged = changed;
		log(`  ${changed} byte(s) changed.`);
  } else if (!fs.existsSync(romPath)) {
		log('out.bin not found — skipping championship data injection (build first).');
  }

  // Step 8: optional verify
  if (verify) {
		log('\nRunning verify.bat ...');
		const result = jsonOut
			? runCanonicalVerify(REPO_ROOT)
			: runCanonicalVerify(REPO_ROOT, { stdio: 'inherit' });
		summary.verify = {
			ran: true,
			ok: result.ok,
			status: result.status,
		};
    if (result.ok) {
			log('Verified bit-perfect.');
    } else {
			if (jsonOut && result.output) summary.verify.output = result.output;
			fail('verify.bat failed.', { verify: summary.verify });
    }
  } else {
		log('\nDone.  Run  powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\\verify.bat"  to confirm bit-perfect ROM.');
  }

	if (jsonOut) {
		summary.legacyBackupFiles = listLegacyBackupFiles(REPO_ROOT).map(filePath => path.relative(REPO_ROOT, filePath));
		printJson(Object.assign({}, summary, { ok: true }));
	}
}

main();
