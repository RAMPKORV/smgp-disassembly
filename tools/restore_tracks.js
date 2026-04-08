#!/usr/bin/env node
// tools/restore_tracks.js
//
// Restores the original track, team, and championship data after in-root randomization.
//
// This script:
//   1. Restores tools/data/tracks.json from tracks.orig.json (if present)
//   2. Re-injects the original track binaries into data/tracks/
//   3. Restores src/track_config_data.asm from track_config_data.orig.asm (if present)
//   4. Restores tools/data/teams.json from teams.orig.json (if present)
//   5. Re-injects the original team data into out.bin (if present)
//   6. Restores tools/data/championship.json from championship.orig.json (if present)
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
const { execFileSync } = require('child_process');
const { parseArgs }    = require('./lib/cli');
const { REPO_ROOT }    = require('./lib/rom');
const { injectTrack }            = require('./inject_track_data');
const { injectTeamData }         = require('./inject_team_data');
const { injectChampionshipData } = require('./inject_championship_data');
const { buildSyncedTrackConfig } = require('./sync_track_config');
const { buildGeneratedTrackBlock, GENERATED_MINIMAP_DATA_FILE } = require('./generate_track_data_asm');
const { buildAsm: buildGeneratedMinimapMapAsm } = require('./write_generated_minimap_assets');

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
// Main
// ---------------------------------------------------------------------------
function main() {
  const args   = parseArgs(process.argv.slice(2), {
    flags:   ['--verify', '--verbose', '-v'],
    options: [],
  });
  const verify  = args.flags['--verify'];
  const verbose = args.flags['--verbose'] || args.flags['-v'];

  // Step 1: restore tracks.json from backup
  if (fs.existsSync(TRACKS_ORIG)) {
    fs.copyFileSync(TRACKS_ORIG, TRACKS_JSON);
    fs.unlinkSync(TRACKS_ORIG);
    console.log('Restored: tools/data/tracks.json  (from tracks.orig.json)');
  } else {
    console.log('No tracks.orig.json backup found — tracks.json may already be original.');
  }

  // Step 2: re-inject original track data into data/tracks/
  if (!fs.existsSync(TRACKS_JSON)) {
    process.stderr.write(`ERROR: tracks.json not found: ${TRACKS_JSON}\n`);
    process.exit(1);
  }

  const tracksData = JSON.parse(fs.readFileSync(TRACKS_JSON, 'utf8'));
  console.log('Re-injecting original track binaries into data/tracks/ ...');
  const dataDir = path.join(REPO_ROOT, 'data', 'tracks');
  let totalChanged = 0;
  for (const track of tracksData.tracks) {
    const results = injectTrack(track, dataDir, false, verbose);
    totalChanged += Object.values(results).filter(r => r.changed).length;
  }
  console.log(`  ${totalChanged} file(s) restored.`);

  const generatedTrackAsm = path.join(REPO_ROOT, 'src', 'road_and_track_data_generated.asm');
  fs.writeFileSync(generatedTrackAsm, buildGeneratedTrackBlock(), 'utf8');
  console.log('Regenerated: src/road_and_track_data_generated.asm');

	const generatedMinimapAsm = path.join(REPO_ROOT, GENERATED_MINIMAP_DATA_FILE);
	fs.mkdirSync(path.dirname(generatedMinimapAsm), { recursive: true });
	fs.writeFileSync(generatedMinimapAsm, buildGeneratedMinimapMapAsm(tracksData.tracks), 'utf8');
	console.log(`Regenerated: ${path.relative(REPO_ROOT, generatedMinimapAsm)}`);

  // Step 3: restore track_config_data.asm from backup
  if (fs.existsSync(ART_CONFIG_ORIG)) {
    fs.copyFileSync(ART_CONFIG_ORIG, ART_CONFIG_ASM);
    fs.unlinkSync(ART_CONFIG_ORIG);
    console.log('Restored: src/track_config_data.asm  (from track_config_data.orig.asm)');
  } else {
    const trackConfigLines = fs.readFileSync(ART_CONFIG_ASM, 'utf8').split(/(?<=\n)/);
    const syncResult = buildSyncedTrackConfig(trackConfigLines, tracksData);
    fs.writeFileSync(ART_CONFIG_ASM, syncResult.content, 'utf8');
    console.log(`Synced: src/track_config_data.asm  (${syncResult.changed} Track_data length line(s) updated from tracks.json)`);
  }

  // Step 4: restore teams.json from backup
  if (fs.existsSync(TEAMS_ORIG)) {
    fs.copyFileSync(TEAMS_ORIG, TEAMS_JSON);
    fs.unlinkSync(TEAMS_ORIG);
    console.log('Restored: tools/data/teams.json  (from teams.orig.json)');
  } else {
    console.log('No teams.orig.json backup found — teams.json may already be original.');
  }

  // Step 5: re-inject original team data into out.bin (if it exists)
  const romPath = path.join(REPO_ROOT, 'out.bin');
  if (fs.existsSync(TEAMS_JSON) && fs.existsSync(romPath)) {
    console.log('Re-injecting original team data into out.bin ...');
    const changed = injectTeamData(TEAMS_JSON, romPath, false, verbose);
    console.log(`  ${changed} byte(s) changed.`);
  } else if (!fs.existsSync(romPath)) {
    console.log('out.bin not found — skipping team data injection (build first).');
  }

  // Step 6: restore championship.json from backup
  if (fs.existsSync(CHAMP_ORIG)) {
    fs.copyFileSync(CHAMP_ORIG, CHAMP_JSON);
    fs.unlinkSync(CHAMP_ORIG);
    console.log('Restored: tools/data/championship.json  (from championship.orig.json)');
  } else {
    console.log('No championship.orig.json backup found — championship.json may already be original.');
  }

  // Step 7: re-inject original championship data into out.bin (if it exists)
  if (fs.existsSync(CHAMP_JSON) && fs.existsSync(romPath)) {
    console.log('Re-injecting original championship data into out.bin ...');
    const changed = injectChampionshipData(CHAMP_JSON, romPath, false, verbose);
    console.log(`  ${changed} byte(s) changed.`);
  } else if (!fs.existsSync(romPath)) {
    console.log('out.bin not found — skipping championship data injection (build first).');
  }

  // Step 8: optional verify
  if (verify) {
    console.log('\nRunning verify.bat ...');
    try {
      execFileSync('cmd', ['/c', 'verify.bat'], {
        cwd:   REPO_ROOT,
        stdio: 'inherit',
      });
      console.log('Verified bit-perfect.');
    } catch (_) {
      process.stderr.write('ERROR: verify.bat failed.\n');
      process.exit(1);
    }
  } else {
    console.log('\nDone.  Run  cmd /c verify.bat  to confirm bit-perfect ROM.');
  }
}

main();
