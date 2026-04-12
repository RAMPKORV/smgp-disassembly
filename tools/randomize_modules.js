'use strict';

const fs = require('fs');
const path = require('path');

const { REPO_ROOT } = require('./lib/rom');
const { backupOnce, patchRomIfPresent, writeJsonFile } = require('./randomize_actions');
const { getTracks, requireTracksDataShape } = require('./randomizer/track_model');
const {
	patchGeneratedMinimapRom,
	validateGeneratedMinimaps,
	writeGeneratedMinimapAssetsFile,
	writeGeneratedTrackBlockPreservingBaseline,
} = require('./randomize_track_support');
const { injectTrack } = require('./inject_track_data');
const { injectTeamData } = require('./inject_team_data');
const { injectChampionshipData } = require('./inject_championship_data');
const { buildSyncedTrackConfig } = require('./sync_track_config');
const {
	FLAG_TRACKS,
	FLAG_TRACK_CONFIG,
	FLAG_TEAMS,
	FLAG_AI,
	FLAG_CHAMPIONSHIP,
	randomizeTracks,
	randomizeArtConfig,
	injectArtConfig,
} = require('./randomizer/track_randomizer');
const { validateTracks } = require('./randomizer/track_validator');
const { randomizeTeams, randomizeAi, validateTeams } = require('./randomizer/team_randomizer');
const { randomizeChampionship, validateChampionship } = require('./randomizer/championship_randomizer');

const TOOLS_DIR = path.join(REPO_ROOT, 'tools');
const TEAMS_JSON = path.join(TOOLS_DIR, 'data', 'teams.json');
const CHAMP_JSON = path.join(TOOLS_DIR, 'data', 'championship.json');
const ART_CONFIG_ASM = path.join(REPO_ROOT, 'src', 'track_config_data.asm');

function exitWithMissingJson(label, filePath) {
	process.stderr.write(`ERROR: ${label} JSON not found: ${filePath}\n`);
	process.exit(1);
}

function exitWithValidationFailures(header, errors) {
	console.log(`\n${header}: ${errors.length} error(s):`);
	for (const error of errors) console.log(`  ${error}`);
	process.exit(1);
}

function runTracksModule(context) {
	const { flags, inputPath, trackSlugs, randomizedTrackCount, seedInt, verbose, dryRun, checkpointSession = null } = context;
	if (!(flags & FLAG_TRACKS)) {
		console.log('\n[RAND_TRACKS] flag not set - skipping track randomization.');
		return;
	}
	if (!fs.existsSync(inputPath)) {
		exitWithMissingJson('tracks', inputPath);
	}

	const tracksData = requireTracksDataShape(JSON.parse(fs.readFileSync(inputPath, 'utf8')));
	const allTracks = getTracks(tracksData);
	const targetTracks = allTracks.filter(track => trackSlugs === null || trackSlugs.has(track.slug));
	const nTracks = randomizedTrackCount !== null ? randomizedTrackCount : targetTracks.length;
	console.log(`\n[RAND_TRACKS] Randomizing ${nTracks} track(s) ...`);

	randomizeTracks(tracksData, seedInt, trackSlugs, verbose);

	const errors = validateTracks(targetTracks);
	if (errors.length > 0) {
		exitWithValidationFailures('Validation FAILED', errors);
	}
	console.log(`Validation passed (${targetTracks.length} track(s)).`);

	const minimapValidation = validateGeneratedMinimaps(targetTracks);
	if (minimapValidation.failures.length > 0) {
		console.log(`\nGenerated minimap validation FAILED: ${minimapValidation.failures.length} issue(s):`);
		for (const failure of minimapValidation.failures) console.log(`  ${failure}`);
		process.exit(1);
	}
	console.log(`Generated minimap validation passed (${targetTracks.length} track(s)).`);

	if (dryRun) {
		console.log('\nDRY RUN - skipping inject and build.');
		return;
	}

	backupOnce(inputPath, inputPath, 'tracks json', { checkpointSession });
	writeJsonFile(inputPath, tracksData);

	const trackConfigLines = fs.readFileSync(ART_CONFIG_ASM, 'utf8').split(/(?<=\n)/);
	const syncResult = buildSyncedTrackConfig(trackConfigLines, tracksData);
	fs.writeFileSync(ART_CONFIG_ASM, syncResult.content, 'utf8');
	console.log(`Synced Track_data metadata in ${path.basename(ART_CONFIG_ASM)} (${syncResult.changed} line(s) changed).`);

	console.log('\n[INJECT] Writing data/tracks/ binaries ...');
	const dataDir = path.join(REPO_ROOT, 'data', 'tracks');
	let totalChanged = 0;
	for (const track of targetTracks) {
		const results = injectTrack(track, dataDir, false, verbose);
		totalChanged += Object.values(results).filter(result => result.changed).length;
	}
	console.log(`  ${totalChanged} file(s) updated.`);

	const generatedMinimapAsm = writeGeneratedMinimapAssetsFile(allTracks);
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

function runConfigModule(context) {
	const { flags, seedInt, verbose, dryRun, checkpointSession = null } = context;
	if (!(flags & FLAG_TRACK_CONFIG)) {
		console.log('\n[RAND_CONFIG] flag not set - skipping art/config shuffle.');
		return;
	}

	console.log('\n[RAND_CONFIG] Shuffling art/config assignment for 16 championship tracks ...');
	const artAssignment = randomizeArtConfig(seedInt, verbose);
	if (dryRun) {
		console.log('  DRY RUN - not rewriting track_config_data.asm.');
		return;
	}

	backupOnce(ART_CONFIG_ASM, ART_CONFIG_ASM, 'track config ASM', { checkpointSession });
	injectArtConfig(artAssignment, REPO_ROOT, false, verbose);
	console.log('  Art assignment written to src/track_config_data.asm.');
}

function runTeamsModule(context) {
	const { flags, seedInt, verbose, dryRun, checkpointSession = null } = context;
	if (!(flags & FLAG_TEAMS)) {
		console.log('\n[RAND_TEAMS] flag not set - skipping team stats randomization.');
		return;
	}
	if (!fs.existsSync(TEAMS_JSON)) {
		exitWithMissingJson('teams', TEAMS_JSON);
	}

	const teamsData = JSON.parse(fs.readFileSync(TEAMS_JSON, 'utf8'));
	console.log('\n[RAND_TEAMS] Randomizing team car stats ...');
	randomizeTeams(teamsData, seedInt, verbose);

	const teamErrors = validateTeams(teamsData);
	if (teamErrors.length > 0) {
		exitWithValidationFailures('Team validation FAILED', teamErrors);
	}
	console.log('Team validation passed.');

	if (dryRun) {
		console.log('  DRY RUN - not writing teams.json or patching ROM.');
		return;
	}

	backupOnce(TEAMS_JSON, TEAMS_JSON, 'teams json', { checkpointSession });
	writeJsonFile(TEAMS_JSON, teamsData);
	const romPath = path.join(REPO_ROOT, 'out.bin');
	patchRomIfPresent(romPath, 'team data', () => injectTeamData(TEAMS_JSON, romPath, false, verbose));
}

function runAiModule(context) {
	const { flags, seedInt, verbose, dryRun, checkpointSession = null } = context;
	if (!(flags & FLAG_AI)) {
		console.log('\n[RAND_AI] flag not set - skipping AI parameter randomization.');
		return;
	}
	if (!fs.existsSync(TEAMS_JSON)) {
		exitWithMissingJson('teams', TEAMS_JSON);
	}

	const teamsData = JSON.parse(fs.readFileSync(TEAMS_JSON, 'utf8'));
	console.log('\n[RAND_AI] Randomizing AI parameters ...');
	randomizeAi(teamsData, seedInt, verbose);

	const aiErrors = validateTeams(teamsData);
	if (aiErrors.length > 0) {
		exitWithValidationFailures('AI validation FAILED', aiErrors);
	}
	console.log('AI validation passed.');

	if (dryRun) {
		console.log('  DRY RUN - not writing teams.json or patching ROM.');
		return;
	}

	backupOnce(TEAMS_JSON, TEAMS_JSON, 'teams json', { checkpointSession });
	writeJsonFile(TEAMS_JSON, teamsData);
	const romPath = path.join(REPO_ROOT, 'out.bin');
	patchRomIfPresent(romPath, 'AI data', () => injectTeamData(TEAMS_JSON, romPath, false, verbose));
}

function runChampionshipModule(context) {
	const { flags, seedInt, verbose, dryRun, checkpointSession = null } = context;
	if (!(flags & FLAG_CHAMPIONSHIP)) {
		console.log('\n[RAND_CHAMPIONSHIP] flag not set - skipping championship randomization.');
		return;
	}
	if (!fs.existsSync(CHAMP_JSON)) {
		exitWithMissingJson('championship', CHAMP_JSON);
	}

	const champData = JSON.parse(fs.readFileSync(CHAMP_JSON, 'utf8'));
	console.log('\n[RAND_CHAMPIONSHIP] Randomizing championship progression ...');
	randomizeChampionship(champData, seedInt, verbose);

	const champErrors = validateChampionship(champData);
	if (champErrors.length > 0) {
		exitWithValidationFailures('Championship validation FAILED', champErrors);
	}
	console.log('Championship validation passed.');

	if (dryRun) {
		console.log('  DRY RUN - not writing championship.json or patching ROM.');
		return;
	}

	backupOnce(CHAMP_JSON, CHAMP_JSON, 'championship json', { checkpointSession });
	writeJsonFile(CHAMP_JSON, champData);
	const romPath = path.join(REPO_ROOT, 'out.bin');
	patchRomIfPresent(romPath, 'championship data', () => injectChampionshipData(CHAMP_JSON, romPath, false, verbose));
}

module.exports = {
	runTracksModule,
	runConfigModule,
	runTeamsModule,
	runAiModule,
	runChampionshipModule,
	patchGeneratedMinimapRom,
};
